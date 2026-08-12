# src/state.jl — the per-call engine state, the immutable alterant registry, and the typed result type.
#
# IS: the state vocabulary of the GoMeta engine — the per-call `ProcessState` (delivered through a
#     `ScopedValue`, never held in a global), the immutable `AlterantRegistry` type behind
#     `DEFAULT_REGISTRY`, the meta-hierarchy and alterant-queue sub-states, the `PlugIn` inventory
#     unit, the public `GoMetaResult` (docs/public-api.md §1.1), and the `init_state` constructor that
#     sizes every container fresh for each call.
# DOES: declares `ConditionT` (the condition-representation alias: the closed interpreter's
#     bounded `ConditionAST`, plus the `FullEvalCondition` marker only the opt-in
#     `:full_eval_v1` extension can mint — README SECURITY; docs/public-api.md §3.2); the
#     meta-hierarchy level layout
#     (`NUM_MH_LEVELS = 12`: the file level, the depth window `1..maxDepthMH`, then the user / line /
#     default levels — the user level is the reserved slot that `GoMetaConfig.user_mh_profile`
#     seeds; docs/public-api.md §2); `PlugIn`; `AlterantRegistry` with
#     `num_alterants` / `num_alt_actions` (3 alterants / 7 actions at v0, incl. the Visib-action →
#     settribute-key map); `MetaHierarchyState`; `AlterantQueue`; `ProcessState`; `GoMetaResult`; the
#     `STATE` ScopedValue + `ctx()`; `init_state`; `snapshot_settribute!`; `get_state`.
# REASONING: every mutable container lives in one per-call `ProcessState`, so two concurrent
#     `goMeta` calls never share state. Conditions eval'd at apply time read it through a
#     `ScopedValue`; an unscoped read throws.
# Honest edges: `AlterantRegistry`'s `Dict`/`Vector` fields are mutable containers — `DEFAULT_REGISTRY`
#     is read-only by convention after construction, not by type; `accum_alt_idxs` must stay sorted
#     ascending (the apply phase's `insorted` membership test depends on it). The queue matrices are
#     sized `numAltActions × num_slots` as the per-slot upper bound; exceeding the per-slot capacity
#     (7 actions at v0) is refused at the enqueue guard (src/absorb/absorb_meta.jl) with
#     "GoMeta absorb: slot action capacity" (tests/unit/slot_overflow_tests.jl).
# PURPOSE: a reentrant, reset-safe, eval-compatible per-call state + the typed public surface.

using Base.ScopedValues

# --- the eval seam + the meta-hierarchy level layout -------------------------------------------------
"""
    ConditionAST

The closed-interpreter AST root type (defined HERE so the seam and its type live together —
the no-new-file arm). LIVE since the v0.2 flip: `condition.jl` builds the closed algebra
behind it (`parse_condition`/`evaluate`/`print_condition`); `root` carries the algebra's node
family (state atoms · query atoms · not/and/or in eager and short-circuit forms).
"""
struct ConditionAST
    root::Any
end

"""
    FullEvalCondition(text)

The MARKER for the `:full_eval_v1` OPT-IN mode (the dual-mode ruling): it carries condition text the
OPERATOR has explicitly asked to be EVALUATED (host parse + evaluation) because neither
safer intake rung could handle it. Not an equation with the pre-v0.2 engine — reach differs
from that engine in both directions; see the opt-in extension's header. This package holds the MARKER ONLY — the evaluation is registered from the
explicitly-included opt-in extension file, so no code path in `src/` can evaluate anything
and the no-eval gates stay armed for every default-configured run. Evaluating a marker with
no registered handler is a loud stable-message error, never a silent skip.
"""
struct FullEvalCondition
    text::String
end

const _FULL_EVAL_HANDLER = Ref{Union{Nothing,Function}}(nothing)

"Register the `:full_eval_v1` evaluation handler (called ONLY by the opt-in extension)."
register_full_eval_handler!(f::Function) = (_FULL_EVAL_HANDLER[] = f)

"""The condition type alias — the interpreter seam: the closed, bounded, no-eval
`ConditionAST`, PLUS the `FullEvalCondition` marker produced by the OPT-IN
`:full_eval_v1` intake mode. The union is the queue's carried type; the marker can only be
minted by the explicitly-loaded opt-in extension, so a default-configured run carries
`ConditionAST` exclusively. The alias is the single seam a future representation change
would ride."""
const ConditionT = Union{ConditionAST,FullEvalCondition}

"The unified meta-hierarchy level count (`= maxDepthMH + 3 = defaultMHIdx`): the file level, the
authorable depth window, and the user / line / default levels — 12 at v0."
const NUM_MH_LEVELS = 12

const maxDepthMH = length(BLS.depthLevelsMH)   # 9 — `depthLevelsMH` incl. `:depth0`
@assert maxDepthMH + 3 == NUM_MH_LEVELS "NUM_MH_LEVELS ($NUM_MH_LEVELS) must equal maxDepthMH+3 ($(maxDepthMH+3)) — the meta-hierarchy sizing invariant"

"The meta-hierarchy index layout: the file level, the depth window `1..maxDepthMH`,
then the user / line / default levels (`defaultMHIdx == NUM_MH_LEVELS`)."
const fileMHIdx    = 1
const userMHIdx    = maxDepthMH + 1   # 10
const lineMHIdx    = maxDepthMH + 2   # 11
const defaultMHIdx = maxDepthMH + 3   # 12 == NUM_MH_LEVELS

# --- the immutable alterant inventory ----------------------------------------------------------------
"""
    PlugIn

The inventory unit for one alterant (`Labels` / `Visib` / `Id` / `Heading`): its name, set-mode
(`:accumulate` — the inheritance backtrack COLLECTS every applicable value · `:mutExclusive` — the
backtrack stops at the FIRST applicable value · `:mutExclusivePerField` — first-wins per FIELD of a
compound · `:localOnly` — the value applies ONCE, where it stands: never enqueued, never visited by
the backtrack, delivered at the absorb seam), the alterant-instance constructor type, the setter/getter, and the (always-`nothing` at
v0) precedence tuple. A fixed-size-array-free inventory unit, built into the registry by
`build_default_registry`. `precedencesTuple` is sized by `NUM_MH_LEVELS`,
the unified meta-hierarchy level count.
"""
struct PlugIn
    altName::Symbol
    setMode::Symbol
    altConstructor::Type
    setAltInstance::Function
    getAltInstance::Union{Nothing,Function}
    precedencesTuple::Union{Nothing,NTuple{NUM_MH_LEVELS,Symbol}}
end

"""
    ActionOverload

ONE row of the DECLARED registration record (v0.2 registration build, the reflection-memo
bindings): a per-overload declaration the registration-time REFLECTION CROSS-CHECK
verifies against the executable method table (verify-not-derive — the memo verdict).
Fields: `sig_types` — the method signature's argument types AFTER the function
type (store · action name · literal slots), stated as the METHOD declares them;
`kinds` — the GRAMMAR-level literal kind per literal slot (`:symbol` | `:string`;
structural slots excluded), parallel to the literal tail of `sig_types`;
`kind_sources` — `:declared` | `:reflected` per kind (the memo's shrinking-surface
tag: `:reflected` where the signature slot is typed enough to carry the kind);
`vararg_kind` — a trailing `Vararg` literal kind or `nothing`; `return_type` — the
DECLARED return type (never compiler inference — the ad-2/ad-5 determinism law;
the id-5 value-algebra refusal reads it); `effect` (`:set` — the v0.2 closed
effect set); `queryable`; `applicability` (`:context_free` | `:context_required`);
`phase` (`:apply` | `:absorb` — mode-derived, the localOnly delta); `grammar` —
`false` marks an INTERNAL row (the probe-surfaced inherited shapes, declared so the
implemented-but-undeclared diagnostic stays armed for FUTURE drift).
"""
struct ActionOverload
    sig_types::Vector{Type}
    kinds::Vector{Symbol}
    kind_sources::Vector{Symbol}
    vararg_kind::Union{Nothing,Symbol}
    return_type::Type
    effect::Symbol
    queryable::Bool
    applicability::Symbol
    phase::Symbol
    grammar::Bool
end

"""
    ActionSpec

The DECLARED per-action registration record: action `name` + `spelling` tag
(`:identifier` | `:operator` — a CLOSED spelling inventory, both kinds under
identical collision checks; the hyphen class can never mint) + the owning
`plugin` index + the per-overload rows + the CAPABILITIES (`accepts_string_slot`
— 0 = no String literal slot; N = the accepting literal-slot position, retiring
the former name literals at the absorb seams) + `sugar_candidacy` (`:none` |
`:activated` — the grant register, CLOSED AT TWO grants: the Labels colon + the
quoted-first heading; `:candidate` raises the loud unactivated-candidacy
diagnostic at registration) + the `validate` slot (Alterant-owned handover
validation; `nothing` when absent) + the RESERVED `keyed_slot` (`nothing` at
v0.2).
"""
struct ActionSpec
    name::Symbol
    spelling::Symbol
    plugin::Int8
    overloads::Vector{ActionOverload}
    accepts_string_slot::Int
    sugar_candidacy::Symbol
    validate::Union{Nothing,Function}
    keyed_slot::Union{Nothing,Tuple{Symbol,Symbol}}
end

"""
    AlterantRegistry

The immutable, DETERMINISTIC alterant inventory — built ONCE by `build_default_registry()` into
`const DEFAULT_REGISTRY`; the registration order is fixed by declaration, never by `Dict` iteration order.
Fields (declaration-order indices: `labels=1, Visib=2, id=3, heading=4` — the live keys are `:id` / `:heading`):
- `plugins` — the alterants in declaration order.
- `sorted_alt_actions` — the action names, sorted.
- `action_to_plugin` — action-index → plugin-index (parallel to `sorted_alt_actions`).
- `action_index` — action-name → action-index.
- `alt_index` — alt-name → plugin-index.
- `accum_alt_idxs` / `mutex_alt_idxs` — the `:accumulate`-mode and `:mutExclusive`-mode plugin index
  sets, BOTH **sorted ascending** — the LIVE apply-phase `insorted` consumers in
  `detAltValuesForSetOfSlots` (apply.jl) DEPEND on the sort (the accumulate-pass gate and the
  within-slot first-applicable stop); `:mutExclusivePerField` plugins — the `id` compound, whose
  fields fill independently — deliberately sit in NEITHER set. `build_default_registry` MUST sort
  both.
- `visib_to_settribute` — a Visib action (e.g. `:hide`) → its `ComponentSettribute` key.

REASONING: `DEFAULT_REGISTRY` is read-only after construction: its `Dict`/`Vector` fields are mutable
containers, and mutating any of them post-construction breaks the determinism guarantee.
"""
struct AlterantRegistry
    plugins::Vector{PlugIn}
    sorted_alt_actions::Vector{Symbol}
    action_to_plugin::Vector{Int8}
    action_index::Dict{Symbol,Int8}
    alt_index::Dict{Symbol,Int8}
    accum_alt_idxs::Vector{Int8}
    mutex_alt_idxs::Vector{Int8}
    visib_to_settribute::Dict{Symbol,Symbol}
    # v0.2 registration build: the DECLARED registration record — one ActionSpec per
    # registered action, DECLARATION order (the parallel derived tables above stay
    # the hot-path lookups; the record is the authority the cross-check verified).
    # `spec_index`: action name → index into `action_specs`.
    action_specs::Vector{ActionSpec}
    spec_index::Dict{Symbol,Int}
end
"The number of registered alterants (4 since CH-3 step 9; 3 before the heading registration)."
num_alterants(r::AlterantRegistry) = length(r.plugins)
"The number of registered alterant actions (8 since CH-3 step 9; 7 before the heading registration)."
num_alt_actions(r::AlterantRegistry) = length(r.sorted_alt_actions)

# --- the per-call mutable state ----------------------------------------------------------------------
"""
    MetaHierarchyState

The per-call meta-hierarchy slot tensors:
`slots` (length `NUM_MH_LEVELS`), `slot_occupied` / `slot_has_accum` (dense `Vector{Bool}`, deliberately
not `BitVector`s), and `count_actions_per_slot`. All plain `Vector`/`Array`, sized once by `init_state`.
"""
struct MetaHierarchyState
    slots::Vector{Int8}
    slot_occupied::Vector{Bool}
    slot_has_accum::Vector{Bool}
    count_actions_per_slot::Vector{Int8}
end

"""
    AlterantArgT

The action-argument LITERAL FLOOR: an enqueued argument is a `Symbol` (every bare token,
INCLUDING numeric text — `Symbol("7")`; the integer space is deliberately not an arm of
this union, so numeric arguments keep their exact fates at the `_invoke_set` argument
seam) or a `String` (the CONTENT of a well-formed quoted token). The String kind exists in
the lane while NO metaLine grammar accepts it yet — a quoted argument meets a typed
refusal at `absorbMeta`'s enqueue seam (dispatch alone cannot hold that law: the built-in
setters keep an untyped value slot that would parse `cell("7")`). Exactly
`Union{Symbol,String}`.
"""
const AlterantArgT = Union{Symbol,String}

"""
    AlterantQueue

The per-call enqueue tensors: `queued`
(`2 × numAltActions × num_slots`), `conditions`, and `args`.
`conditions` carries `ConditionT` (the closed interpreter's parsed condition, plus the
opt-in full-eval marker — see that alias's docstring); `args` carries tuples over the
argument literal floor `AlterantArgT` (`Symbol` | `String` — see that type's docstring).
Both matrices are indexed `[row, slot_index]`: dim-1 is the per-slot enqueue ROW counter
(`1..count_actions_per_slot[slot]` — the sequential order in which actions were absorbed into that slot,
NOT a registry action index; the matrices are merely SIZED `numAltActions × num_slots` as the per-slot
upper bound), dim-2 = slot, parallel to `queued[:, row, slot]`. The apply phase MUST index `[row, slot]`
consistently (a row/slot transposition would corrupt the queue).
"""
struct AlterantQueue
    queued::Array{Int8,3}
    conditions::Matrix{Union{Nothing,ConditionT}}
    args::Matrix{Union{Nothing,Tuple{Vararg{AlterantArgT}}}}
end

"""
    MetaContext

The v0.2 CH-3 context record — **{grain, depth, application level, occurrence handle}**,
a PURE function of the parse, published at the walk→absorb handover (`applyAbsorbFn`
builds it from the component + the post-update MH cursor and sets `st.meta_context`) and
stored in NO Component (the evaluation-free-tree law). Consumers at this step:
the quoted-first heading recognizer's APPLICABILITY check (the userMH feed NULLS the
record before its absorb call — no document line exists there — so a derived-context
heading through that surface meets a TYPED applicability refusal, never fabrication)
and the head verdict row's level (the attr-fold: the level rides the attr NAME
`head_<level>`; no fabricated rows, no record-schema change). `level` is the
application level — the RAW MH-ladder index the walk set for this component (a
Segment-attached metaLine inherits the metaLine's `lineMHIdx`, so the inheritance
law holds by construction); the RECORDED level is normalized to ladder−1 — the
author's own `#~`-digit vocabulary — at the enqueue materialization seam (the documented
level vocabulary; the record itself stays pure from parse). `handle` is the
serialized occurrence key (`key_bytes`); under localOnly delivery it is
LOAD-BEARING as the heading row's key.
"""
struct MetaContext
    grain::Symbol            # :Block | :Line | :Segment
    depth::Int               # the component's own MH depth marker — 0 at v0.2: the walk's
                             # handover sites are Line/Segment-grain only (no Block-grain
                             # applyAbsorbFn call site exists), so the Block arm is defensive;
                             # the field is the record's designed shape (delta-review trued)
    level::Int               # the APPLICATION level — the MH-ladder index at absorb time
    handle::Vector{UInt8}    # occurrence-key bytes (pure from parse)
end

"""
    UserContext

The profile-feed surface's own recordable identity (the user-context build): `handle` =
the minted user-context key bytes (`user_context_key(config.namespace, region_ordinal)`,
serialized); `content` = the fed profile's verbatim UTF-8 bytes (the minted row's
fingerprint column — the analogue of the document rule that a heading row carries its
metaLine's bytes). Constructed by the feed routine immediately before its absorb call and
RESTORED-to-prior in a `finally` right after (the stack-disciplined bracket); the
document-side `meta_context` stays `nothing` on the feed, so the deriving-form refusal
holds by construction. Immutable; per-call config inputs only.
"""
struct UserContext
    handle::Vector{UInt8}
    content::Vector{UInt8}
end

"""
    ProcessState

The per-call, mutable, threaded-via-`ctx()`, NEVER-global engine state. Wraps the parse state,
the config, the (immutable) registry, the meta-hierarchy + queue sub-states, the transient per-slot
alterant-instance dict (`working`), the `verdicts` (captured
before slot wipe → altValues_evals), the current-settribute `snapshot`,
the accumulating `diagnostics`, the three mutable meta-hierarchy cursors, and the per-component
`meta_context` record (see `MetaContext`). Constructed only by `init_state`; delivered per-call via the `STATE` ScopedValue, read through `ctx()`.
"""
mutable struct ProcessState
    parse::BLS.ParseState
    config::GoMetaConfig
    registry::AlterantRegistry
    mh::MetaHierarchyState
    queue::AlterantQueue
    working::Dict{Int8,Any}
    verdicts::EvalStore
    snapshot::BLS.ComponentSettribute
    diagnostics::Vector{Diagnostic}
    crnt_depth_idx::Int
    first_parent_idx::Int
    crnt_idx::Int
    meta_context::Union{Nothing,MetaContext}   # v0.2 CH-3 step 9 (see MetaContext above)
    meta_content::Vector{UInt8}                # v0.2 CH-3 localOnly delivery: the CURRENT
                                               # metaLine component's verbatim content bytes
                                               # (`cell_content_bytes`), published at the
                                               # walk handover BESIDE `meta_context` and
                                               # consumed by the absorb-seam heading
                                               # delivery as the minted row's fingerprint
                                               # column. EMPTY on the userMH surface (the
                                               # feed nulls it with the record; the feed's
                                               # OWN fingerprint rides UserContext.content).
                                               # A per-call scratch — deliberately NOT a
                                               # MetaContext field (the record's ratified
                                               # shape is {grain, depth, level, handle}).
    user_context::Union{Nothing,UserContext}   # the user-context build: non-nothing ONLY
                                               # inside the feed routine's bracket (set
                                               # before its absorb call, restored-to-prior
                                               # in the finally) — never set on the
                                               # document walk; the capture's second
                                               # (handle, content) source.
end

"""
    GoMetaResult(state, status, diagnostics, verdicts)

The public output of `goMeta(bytes; config) -> GoMetaResult` (docs/public-api.md §1.1): the per-call `state`,
the `status` (`PROCESS_OK` ⇒ no error diagnostics), the `diagnostics`, and the `verdicts`. Defined AFTER
`ProcessState` (its first field). `outputs(result)` surfaces `(blsStructure_bytes, render_bytes)`
(docs/CANONICAL-OUTPUT.md); `altValues_evals(result)` reads `verdicts`.
The `state` field is INTERNAL and semver-UNSTABLE at v0 — depend only on `status`, `diagnostics`,
`GoMeta.outputs(result)`, and `altValues_evals(result)`; a future release may narrow or remove it.
"""
struct GoMetaResult
    state::ProcessState
    status::ProcessStatus
    diagnostics::Vector{Diagnostic}
    verdicts::EvalStore
end

# --- the swappable delivery seam -------------------------------------------------
"""
    const STATE :: ScopedValue{ProcessState}

The per-call state binding — NO default, so an unscoped read THROWS (fail-loud, supporting the total typed
surface). `goMeta` opens `with(STATE => init_state(…)) do … end`; every state-bearing
function reaches it through `ctx()`. This is THE swap point: `ctx()` is the only accessor, so a benchmark
could flip the delivery (ScopedValue ⇄ threaded arg) by changing `ctx()` alone.
"""
const STATE = ScopedValue{ProcessState}()

"The per-call state accessor (the swap seam). Hot loops hoist `local st = ctx()` once per function; the
eval'd `getState`/`getAltState` reach `ctx()` with zero change to the generated condition strings."
@inline ctx() = STATE[]

# --- construction (the reset-safe constructor) + the settribute helpers ------------------------------
"""
    init_state(parse_state, config, registry) -> ProcessState

Build a FRESH `ProcessState`, sizing every container ONCE from `registry` + `NUM_MH_LEVELS`. Every
per-field init is performed here, so each call is independent — no tensor or cursor carries over:
`slots = zeros(Int8, NUM_MH_LEVELS)`; the `slot_*`/`count_*` per-slot vectors `fill(false,·)`/`zeros(Int8,·)`;
`queued = zeros(Int8, 2, nAct, nSlot)`; `conditions`/`args` matrices filled with `nothing`; `working` an
empty `Dict`; `verdicts` empty; `snapshot` a FRESH `ComponentSettribute` (its `array` is COPIED into by
`snapshot_settribute!`, never aliased); the three cursors all `fileMHIdx` (= 1).
`num_slots == NUM_MH_LEVELS`.
"""
function init_state(parse_state::BLS.ParseState, config::GoMetaConfig, registry::AlterantRegistry)
    n_act  = num_alt_actions(registry)   # 8 since CH-3 step 9 (was 7; the head action joined)
    n_slot = NUM_MH_LEVELS               # 12
    mh = MetaHierarchyState(
        zeros(Int8, NUM_MH_LEVELS),      # slots
        fill(false, n_slot),             # slot_occupied  (dense Vector{Bool}, NOT a BitVector)
        fill(false, n_slot),             # slot_has_accum
        zeros(Int8, n_slot),             # count_actions_per_slot
    )
    queue = AlterantQueue(
        zeros(Int8, 2, n_act, n_slot),                                                     # queued
        fill!(Matrix{Union{Nothing,ConditionT}}(undef, n_act, n_slot), nothing),           # conditions
        fill!(Matrix{Union{Nothing,Tuple{Vararg{AlterantArgT}}}}(undef, n_act, n_slot), nothing),# args
    )
    return ProcessState(
        parse_state, config, registry, mh, queue,
        Dict{Int8,Any}(),            # working
        EvalStore(),              # verdicts
        BLS.ComponentSettribute(),   # snapshot — FRESH (array copied-into, not aliased)
        Diagnostic[],                # diagnostics
        fileMHIdx, fileMHIdx, fileMHIdx,   # crnt_depth_idx / first_parent_idx / crnt_idx
        nothing,                     # meta_context — published per component at the walk handover (step 9)
        UInt8[],                     # meta_content — published beside meta_context (localOnly delivery)
        nothing,                     # user_context — set only inside the feed routine's bracket
    )
end

"""
    snapshot_settribute!(st, component) -> ComponentSettribute

Copy `component`'s settribute bytes INTO `st.snapshot` IN PLACE. The destination array is the
per-call `snapshot`'s own array (copied into, never aliased), so a second `goMeta` call starts from
a fresh snapshot.
"""
function snapshot_settribute!(st::ProcessState, component::T) where {T<:BLS.Component}
    st.snapshot.array[:] .= component.componentSettribute.array[:]
    return st.snapshot
end

"""
    get_state(snapshot, key) -> Bool

Read a settribute flag from a settribute snapshot (the pure helper behind the de-globalized `getState`). `get_state(ctx().snapshot, key)` is what the eval'd `getState(:key)` resolves to — the reader resolves through `ctx()`.
"""
get_state(snapshot::BLS.ComponentSettribute, key::Symbol) = BLS.getElement(snapshot, key)
