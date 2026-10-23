# src/state.jl — the per-call engine state, the immutable alterant registry, and the typed delivered object.
#
# IS: the state vocabulary of the GoMeta engine — the per-call `ProcessState` (delivered through a
#     `ScopedValue`, never held in a global), the immutable `AlterantRegistry` type behind
#     `DEFAULT_REGISTRY`, the meta-hierarchy and alterant-queue sub-states, the `Alterant` inventory
#     unit, the public `GoMetaDelivery` (docs/public-api.md §1.1), and the `init_state` constructor that
#     sizes every container fresh for each call.
# DOES: declares the meta-hierarchy level layout
#     (`NUM_MH_LEVELS = 12`: the file level, the depth window `1..maxDepthMH`, then the user / line /
#     fallBack levels — the user level is the reserved slot that `GoMetaConfig.user_mh_profile`
#     seeds; docs/public-api.md §2); `Alterant`; `AlterantRegistry` with
#     `num_alterants` / `num_alt_actions` (4 alterants / 9 actions since 0.4.0;
#     a generic action → settribute write-back table was removed); `MetaHierarchyState`; `AlterantQueue`;
#     `ProcessState`; `GoMetaDelivery`; the `STATE` ScopedValue + `ctx()`; `init_state`;
#     `snapshot_settribute!`; `get_state`; the v0.4 record SLOTS + the registration LIFECYCLE types.
# REASONING: every mutable container lives in one per-call `ProcessState`, so two concurrent
#     `goMeta` calls never share state. Conditions eval'd at apply time read it through a
#     `ScopedValue`; an unscoped read throws.
# Honest edges: `AlterantRegistry`'s `Dict`/`Vector` fields are mutable containers — a PUBLISHED
#     registry is published, not frozen by type: a mutation through any container (declared record,
#     derived table or callable identity) BY CONFORMING CODE is DETECTED at the
#     entry door (`POST_SEAL_MUTATION` — the ONE structural deep-egal comparison
#     against the publish-time `_snapshot` baseline, `===`-only leaves, firing at the first
#     divergent path), never silently effective — accident-grade, within the disclosed bounds
#     (callable behavior ≠ identity; the snapshot's own members are mutable — the mixed
#     residue; the entry check is not a lock; docs/public-api.md §1.2's honest-bound block);
#     the construction capability is token-gated so no POSITIONAL or accidental construction by
#     conforming code carries a publish-time snapshot (accident-grade: any loaded module can reach the token);
#     `accum_alt_idxs` must stay sorted
#     ascending (the apply phase's `insorted` membership test depends on it). The queue matrices are
#     sized `SLOT_CAPACITY × num_slots` as the per-slot upper bound (8 — the named capacity, DECOUPLED from the registered count, 9); a further action meets GoMeta's own message "GoMeta absorb: more than 8
#     actions in one meta-hierarchy slot …" BEFORE the enqueue write (the slot bound in src/absorb/absorb_meta.jl — the creator's
#     decision: a fixed size, raised by hand when an example needs it; for a while within the 0.4 development,
#     after the v0.2 capacity guard's removal, a further action met Julia's own BoundsError; tests/unit/slot_overflow_tests.jl pins
#     the boundary and the ninth).
# PURPOSE: a reentrant, reset-safe, eval-compatible per-call state + the typed public surface.

using Base.ScopedValues

# --- the condition's carried type + the meta-hierarchy level layout ----------------------------------------
## A `{…}` condition is carried as Julia's own `Expr` since 0.4.0 (the creator's design): the absorb seam re-writes the GoMeta-specific parts of the body to Julia text, `Meta.parse` reads it
## once (src/absorb/absorb_meta.jl, `parseConditions`), and Julia evaluates the stored `Expr` at apply (src/alterants/apply.jl) —
## as the original engine did (GoMetaRetro AbsorbMeta.jl :270, goMetaAddOns.jl :37). The closed interpreter's `ConditionAST`, the
## opt-in marker `FullEvalCondition` with its handler seam and the alias `ConditionT` were removed with the interpreter.

"The unified meta-hierarchy level count (`= maxDepthMH + 3 = fallBackMHIdx`): the file level, the
authorable depth window, and the user / line / fallBack levels — 12 at v0. The level formerly named 'default'
is `fallBack` (the creator's word): the word 'default' is the Alterant's declared VALUE."
const NUM_MH_LEVELS = 12

"The per-slot CAPACITY of the alterant queue — the number of actions one meta-hierarchy slot holds: 8, a NAMED CONSTANT, DECOUPLED
from the registered action count (the creator's decision; the registered count is 9
with the `ids` action) — the slot limit is the matrix size he chose to start with,
increased by hand (hard coded) if 8 proves too small — the size raised by hand when an example asks.
Before, the size was the registered action
count (`num_alt_actions(registry)`, as the original engine's `numAltActions` sized its queue tensor — GoMetaRetro src/CnS.jl :135–:136): a sizing
of the code, not the creator's sentence. A further action in a slot meets the absorb's refusal (absorb_meta.jl: \"more than 8
actions in one meta-hierarchy slot\"); the slower overflow buffer is a later design."
const SLOT_CAPACITY = 8

const maxDepthMH = length(BLS.depthLevelsMH)   # 9 — `depthLevelsMH` incl. `:depth0`
@assert maxDepthMH + 3 == NUM_MH_LEVELS "NUM_MH_LEVELS ($NUM_MH_LEVELS) must equal maxDepthMH+3 ($(maxDepthMH+3)) — the meta-hierarchy sizing invariant"

"The meta-hierarchy index layout: the file level, the depth window `1..maxDepthMH`,
then the user / line / fallBack levels (`fallBackMHIdx == NUM_MH_LEVELS`) — the fallBack level is consulted LAST by
the apply (the creator's rule); today no feed occupies it (the `metaLevel` Alterant is a later version's)."
const fileMHIdx    = 1
const userMHIdx    = maxDepthMH + 1   # 10
const lineMHIdx    = maxDepthMH + 2   # 11
const fallBackMHIdx = maxDepthMH + 3   # 12 == NUM_MH_LEVELS — the fallBack level, consulted LAST by the apply

# --- the v0.4 registration-record SLOTS ---------------------------------------------------
# IS: the DECLARED data slots the v0.4 record carries (slots
#     (1)–(3) of a ten-slot design): the per-action settribute mapping (removed within the 0.4 development) · the capture declaration · the presence-typed
#     explicit default. The other seven — the render-plane data, the constraint rows, the contributed condition
#     atoms, the identity/contract/requires, the sugar rows, the schema-versioned provenance group and the RESERVED
#     permissions manifest — were removed within the 0.4 development.
#     The creator's later decision removed them: permission levels and hash
#     checks come LATER; a basic framework BEFORE HARDENING; no unnecessary clutter.
# DOES: defines the slot types with their closed enum sets; every slot is NOTHING/EMPTY-defaulted (the
#     v0.3.2 positional constructors that admitted old records were removed within the 0.4 development;
#     nothing is silently defaulted to a VALUE — absence stays mechanically distinguishable
#     from every declared value, the disjointness law).
# REASONING: the engine's measured clean planes (apply, absorb dispatch) are
#     registry-DATA-driven; the dirty planes (capture, defaults, render, diagnostics) were
#     hard-coded per Alterant. Moving what those planes need INTO the record as data is the
#     substrate: Core keeps schema knowledge, never a particular Alterant's content. Both slots are consumed:
#     the capture declaration by the capture walk, the default by the answer function.
# PURPOSE: one record, extended never replaced, that a registration can declare completely.

## Slot (2): the capture declaration — HOW an Alterant's applied value becomes evals rows.
"""
    CaptureDecl(attr_scheme[, attr_stem]; attr_stem = nothing)

IS: the declared capture row of an Alterant — slot (2) of its registration record: HOW the Alterant's applied
value becomes evals rows.

DOES: The declared capture row (CONSUMED by the capture walk since 0.4.0 — the registration-driven re-home of the
retired alt-name ladder): `attr_scheme` ∈ `(:per_key, :single, :per_field, :per_entry)` = how attr names mint
(`<stem>_<key>` per Dict entry · one `<stem>` row for a NamedElements-shaped single evals row · `<stem>_<field>` per
non-default numeric field · one row per entry `(text, level)` of a Heading-shaped store — `<stem>_<level>`, a repeat at
the same level `<stem>_<level>_<k>`, the text the value); `attr_stem` = the declared attr name stem (`nothing` ⇒ the
derived fallback `lowercase(String(altName))`, `_capture_stem` below — the shipped four DECLARE theirs explicitly). The
walk reads the store's shape from the record's own `altConstructor`. EVERY Alterant's rows are minted by the one walk
`captureEvals!` at the two apply sites — the Heading's too (the creator's decision: the same
process as any other Alterant; the former `mode_gate` field, its closed set, the mode-gate laws and the `:per_occurrence`
presence scheme of the separate delivery were removed with it). A PLAIN 2-field struct — NO inner constructor that
changes the positional signature (the domain copier rebuilds slot structs POSITIONALLY over all fields at the exact concrete
type, src/alterants/registry.jl) — with ONE outer one-positional method, the row's own keyword-default form.

REASONING: the capture walk is registration-driven — never an alt-name ladder — and the struct is plain
(no inner constructor) because the domain copier rebuilds slot structs positionally.

PURPOSE: the row `captureEvals!` reads to mint an Alterant's evals rows.
"""
struct CaptureDecl
    attr_scheme::Symbol
    attr_stem::Union{Nothing,Symbol}    # additive; LAST — the positional law
end
CaptureDecl(attr_scheme::Symbol; attr_stem::Union{Nothing,Symbol} = nothing) =
    CaptureDecl(attr_scheme, attr_stem)
"The attr-name stem a plugin's rows mint under: the declared `attr_stem`, or the derived fallback `lowercase(String(altName))` —
ONE derivation for the capture walk, the answer function and the scan (four former copies folded)."
_capture_stem(p) = p.capture.attr_stem === nothing ? Symbol(lowercase(String(p.altName))) : p.capture.attr_stem

## Slot (3): the presence-typed explicit default — undeclared is a TYPE, never a sentinel value. The
## slot is the ALTERANT's (one default per Alterant, declared as data);
## an earlier per-action slot GAVE WAY to it (a clean cut).
"The explicit-default slot's abstract root: `NoDefault()` (undeclared) | `Declared(v)`."
abstract type DefaultSlot end
"The UNDECLARED default — mechanically distinct from every declared value (the disjointness law)."
struct NoDefault <: DefaultSlot end
"A DECLARED default value — an Alterant's; `value` is the Alterant's own datum, Core never interprets it."
struct Declared{T} <: DefaultSlot
    value::T
end

# --- the immutable alterant inventory ----------------------------------------------------------------
"""
    Alterant

IS: the registration record of ONE Alterant — the inventory unit the registry holds for `Labels` / `Visib` / `Id` / `Heading` and for
    any Alterant an Extension registers through the lifecycle (docs/public-api.md §1.2). The original engine's `struct PlugIn`
    (GoMetaRetro `src/Alterants.jl`) carries the name `Alterant` since v0.4 — the creator prefers NOT to
    call the record 'PlugIn' anymore, the name clashing with another kind of PlugIn he has in mind; the public alias
    `PlugIn` was REMOVED before 0.4.0 (a clean cut; its row in docs/public-api.md
    §6). The FIELD NAMES are the original engine's and stay.
DOES: carries the Alterant's name (`altName`); its set-mode (`setMode` — `:accumulate`: the inheritance backtrack COLLECTS every
    applicable value · `:mutExclusive`: the backtrack stops at the FIRST applicable value · `:mutExclusivePerField`: the `Id`
    compound — the per-FIELD first-wins semantics its name promises are DEFERRED (the registry's note: the mode sits in neither
    set-mode table by design); at v0.4 the nearest statement sets the compound as a WHOLE (an unset field is not inherited from an
    outer slot) and within one slot the LAST row of a field wins (MEASURED; `tests/authored/006_id_compound.toml`,
    a draft awaiting the creator's decision — the contract narrowed, no Engine change) ·
    `:localOnly`: the value applies ONLY at the Component the statement is applied to — queued like every action, decided by the
    apply loop's one rule for this mode (apply.jl), every other Component passing over it; the Heading's, the creator's set mode);
    the alterant-instance constructor type (`altConstructor`); the setter and the query getter (`setAltInstance`,
    `getAltInstance` — the getter `nothing` for an Alterant that answers no query); the precedence tuple (`precedencesTuple`, always
    `nothing` at v0; sized by `NUM_MH_LEVELS`, the unified meta-hierarchy level count); the Alterant's ONE declared default value
    (`default` — `NoDefault()` | `Declared(v)`: Visib's is `:show`; delivered by the answer function
    with the source "default"); and the capture declaration (`capture` — `nothing` | a `CaptureDecl`:
    the row that makes the Alterant's applied state mint evals rows); and the read-time hook (`onRead` — `nothing` | a function
    `(run, mhIdx, actionName, args, hasCondition) -> nothing | Vector{Diagnostic} | run′ | (run′, Vector{Diagnostic})`, called by `absorbMeta`
    for the Alterant's statements with arguments before the slot bound — ONE GRAMMAR for every Alterant: `nothing` = not the hook's, the
    statement enqueued as stated; a `Vector{Diagnostic}` ALONE = the rows delivered through the door with the read-time place and the
    statement enqueued as stated; any other value = CONSUMED as the Alterant's per-run state, the statement's processing ending; a tuple
    `(state, Vector{Diagnostic})` = consumed AND the rows delivered); and THE DOOR (since 0.4.3): a callable's return may carry a vector of
    diagnostics — the setter's at the apply, the hook's at the read — delivered by the ONE function `_deliver_diagnostics!` (below) with the
    place the Engine knows at that moment merged into each row's context, the severity copied, anything else ignored (no record field). The keyword form below defaults every optional slot;
    `build_default_registry` builds the four shipped records.
REASONING: one immutable record per Alterant, declared as DATA and read by the apply plane through the registry's derived tables — the original
    engine's form (one record per Alterant, registered as data); no fixed-size array inside it.
PURPOSE: the unit of the Alterant inventory — what `register!` accepts and what the registry's tables are derived from.
"""
struct Alterant
    altName::Symbol
    setMode::Symbol
    altConstructor::Type
    setAltInstance::Function
    getAltInstance::Union{Nothing,Function}
    precedencesTuple::Union{Nothing,NTuple{NUM_MH_LEVELS,Symbol}}
    default::DefaultSlot                           # slot (3) at the ALTERANT: its ONE declared default value —
                                                   #   `NoDefault()` undeclared | `Declared(v)`;
                                                   #   delivered by the answer function with the source "default" —
                                                   #   Visib declares `:show`; Labels `Symbol[]`, Heading `nothing`, Id the zero compound — the creator's decision, PROVISIONAL (the values may change once used on real examples)
    # --- the capture declaration (the seven other declared slots of an earlier design were removed) ---
    capture::Union{Nothing,CaptureDecl}            # slot (2): the capture declaration
    onRead::Union{Nothing,Function}                # THE READ-TIME HOOK — `nothing` for every Alterant
                                                   #   but one that declares it; called by `absorbMeta` for the Alterant's statements WITH
                                                   #   arguments, BEFORE the slot bound, as `onRead(run, mhIdx, actionName, args, hasCondition)`:
                                                   #   `nothing` = not the hook's (enqueued as stated); a `Vector{Diagnostic}` ALONE = the rows
                                                   #   delivered through the door with the read-time place, the statement enqueued as stated; any
                                                   #   other value = CONSUMED at the read and stored as the Alterant's per-run state
                                                   #   (`ProcessState.alt_run`), the statement's processing ends; a tuple `(state, Vector{Diagnostic})`
                                                   #   = consumed AND the rows delivered (the one grammar, for every Alterant). A designated callable
                                                   #   field (the registry's four loci), appended LAST (the copier rebuilds the record positionally).
                                                   #   The Labels Alterant's hook: labels.jl `declareLabels!` (the vocabulary statements; a
                                                   #   persisted change's `:info` row returned with the run state).
end
"The keyword form: the two declared slots and the read-time hook addressable by name; an unnamed slot takes its nothing/undeclared default."
Alterant(; altName::Symbol, setMode::Symbol, altConstructor::Type, setAltInstance::Function,
           getAltInstance::Union{Nothing,Function} = nothing,
           precedencesTuple::Union{Nothing,NTuple{NUM_MH_LEVELS,Symbol}} = nothing,
           default::DefaultSlot = NoDefault(), capture = nothing, onRead = nothing) =
    Alterant(altName, setMode, altConstructor, setAltInstance, getAltInstance, precedencesTuple, default, capture, onRead)

"""
    ActionSpec

IS: the DECLARED per-action registration record — one row per registered action of an Alterant, held by the registry
in declaration order (`action_specs`) and appended with its Alterant by `register!`.

DOES: carries the action `name`, the owning `plugin` index (`Int8` — the Alterant's declaration-order index, which
`register!` checks) and the CAPABILITIES: `accepts_string_slot` — 0 = no String literal slot; N = the accepting
literal-slot position, retiring the former name literals at the absorb seams — and the `validate` slot (Alterant-owned
handover validation; `nothing` when absent). The enqueue seam reads both from the record for EVERY action: a String
argument in any position but the declared one refuses (`_string_slot_check`), and the declared
`validate` runs AT THE READ on the String text of that slot (`absorbMeta`, src/absorb/absorb_meta.jl — one seam for every action since
the Heading's separate path was removed; the shipped actions but `head` declare none).
The shipped records: `:` for Labels; `hide` / `show` / `discard` for Visib; `cell` / `parent` / `file` / `ids` for Id; `head`
for the Heading — the one record with a String slot (`accepts_string_slot = 1`) and a validator. The declared
`settribute` write-back key was removed from the record within the 0.4 development (the
original engine wrote the Visib flag into the Component directly (its GoMeta.jl :103–:110), and v0.4 writes
nothing back: the Engine's answer is `evaluatedAltValue`). The per-overload rows
(`ActionOverload`) were removed from the record with the `spelling` tag, the `sugar_candidacy`
grant register and the reserved `keyed_slot` (the original engine registered an action by its
name and let Julia dispatch do the rest): the setter's methods ARE the action's forms. The v0.3.2 positional
constructor was removed with them (clean cuts, no leftovers of an older version); the keyword
form below is the one form.

REASONING: an action is registered by its name and its Alterant — the original engine registered by name and let Julia dispatch do
the rest; what the absorb seam must know beyond the name — the String slot, the validator — rides the record as data,
never as a name literal in the seam.

PURPOSE: the row `register!` binds to its Alterant, `_derive_tables` derives the action tables from, and the absorb
seam consults for the String-slot law and the handover validation.
"""
struct ActionSpec
    name::Symbol
    plugin::Int8
    accepts_string_slot::Int
    validate::Union{Nothing,Function}
    # (a former slot (1), the per-action settribute write-back key, was removed within the 0.4 development)
end
"The keyword form of the per-action record — the one form."
ActionSpec(; name::Symbol, plugin::Int8, accepts_string_slot::Int = 0, validate = nothing) =
    ActionSpec(name, plugin, accepts_string_slot, validate)

"""
    _SealToken

IS: the construction capability of `AlterantRegistry` (never `public`), held by the lifecycle — the empty struct whose
value is the first argument of the type's ONE inner constructor.

DOES: its presence as the first argument suppresses the generated all-fields constructor: no positional form carries a
publish-time snapshot (the word "seal" names the snapshot MECHANISM; a former fingerprint field
was removed). Its two callers under `src/`: `publish` (src/alterants/registry.jl — the snapshot taken) and
the gated positional route below (the snapshot `nothing`). An ACCIDENT-grade guard: Julia has no access control, so
any loaded module can call `GoMeta._SealToken()`; such a caller sits outside the trust model (the security frame's
bound). See the constructor's note.

REASONING: the guard removes the construction classes CONFORMING code produces by accident — a positional or
all-fields call carrying a snapshot — and claims nothing against a module that reaches for the token.

PURPOSE: the token the registry lifecycle hands to the type's one constructor, so that a published value comes from
`publish` alone for conforming callers.
"""
struct _SealToken end

"""
    _SNAPSHOT_FIELDS

IS: the tuple of the nine registry field names the snapshot door walks: the declared record
(`plugins`, `action_specs`) + the seven derived tables.

DOES: names the fields `publish` copies a second time into the `_snapshot` baseline (a `NamedTuple` over this tuple,
src/alterants/registry.jl) and the fields `_registry_door_check` compares, one by one, against that baseline at the
`goMeta` entry. A published `seal` fingerprint string was removed from the tuple (the
fingerprint's one consumer, the grammar profile, went with it; the door never read the value, it compares the fields
below). The `_snapshot` field itself is NEVER walked (no recursion into the baseline).

REASONING: one field-name tuple is the single source for the snapshot's construction and the door's comparison, so
the two cannot drift apart and no per-table keyword binding exists at either site.

PURPOSE: the field list behind the registry's post-publication mutation detection (`POST_SEAL_MUTATION`).
"""
const _SNAPSHOT_FIELDS = (:plugins, :sorted_alt_actions, :action_to_plugin, :action_index,
                          :alt_index, :accum_alt_idxs, :mutex_alt_idxs,
                          :action_specs, :spec_index)

"""
    AlterantRegistry

IS: the immutable, DETERMINISTIC alterant inventory — the declared registration record (`plugins`, `action_specs`)
with its derived lookup tables and its publish-time snapshot baseline; built ONCE by `build_default_registry()` into
`const DEFAULT_REGISTRY` through the lifecycle `RegistryBuilder → validate → publish`; the registration order is fixed
by declaration, never by `Dict` iteration order.

DOES: holds the fields below (declaration-order indices: `labels=1, Visib=2, id=3, heading=4` — the live keys are
`:id` / `:heading`):
- `plugins` — the Alterants' records in declaration order.
- `sorted_alt_actions` — the action names, sorted.
- `action_to_plugin` — action-index → plugin-index (parallel to `sorted_alt_actions`).
- `action_index` — action-name → action-index.
- `alt_index` — alt-name → plugin-index.
- `accum_alt_idxs` / `mutex_alt_idxs` — the `:accumulate`-mode and `:mutExclusive`-mode plugin index
  sets, BOTH **sorted ascending** — the LIVE apply-phase `insorted` consumers in
  `detAltValuesForSetOfSlots` (apply.jl) DEPEND on the sort (the accumulate-pass gate and the
  within-slot first-applicable stop); `:mutExclusivePerField` plugins — the `id` compound, whose
  fields fill independently — deliberately sit in NEITHER set. `_derive_tables` sorts both (`sort!`) on
  every route — `build_default_registry` reaches it through `publish`.
- `action_specs` — the DECLARED registration record: one `ActionSpec` per registered action, DECLARATION order (the
  parallel derived tables above stay the hot-path lookups; the record is the authority — the author's statement since
  0.4.0); `spec_index` — action name → index into `action_specs`.
- `_snapshot` — the baseline: a deep domain-copy of the nine `_SNAPSHOT_FIELDS` values taken
  at publish (a former seal field and the settribute table were removed before 0.4.0);
  `nothing` on an unpublished value; the underscore is deliberate — an integrity baseline is not a
  plain member of a package-public struct.
- (a generic action → settribute write-back table was removed within the 0.4 development;
  it had been read by nothing since the write-back's removal.)

The ONE constructor is token-gated (`_SealToken`): the seven derived tables enter BY NAME as ONE `NamedTuple` argument,
destructured by field name there — the one reviewed destructuring site, so the two same-typed groups
(`action_index` / `alt_index`; `action_to_plugin` / `accum_alt_idxs` / `mutex_alt_idxs`) cannot be swapped by a
caller. The `goMeta` door (`_registry_door_check`) refuses an unpublished value (`REG_UNPUBLISHED`)
and compares the live fields against `_snapshot` by the ONE structural deep-egal walk (`===`-only leaves), firing
`POST_SEAL_MUTATION` at the first divergent path. The counts: `num_alterants` / `num_alt_actions` (4 / 9 since 0.4.0; 4 / 8 since the
heading registration).

REASONING: `DEFAULT_REGISTRY` is read-only after construction: its `Dict`/`Vector` fields are mutable
containers, and mutating any of them post-construction breaks the determinism guarantee. A mutation through any
container by CONFORMING code is DETECTED at the entry door, never silently effective — accident-grade, within the
disclosed bounds (a callable's behaviour is not pinned by its identity; the snapshot's own members are mutable — the
disclosed residue; the entry check is not a lock).

PURPOSE: the alterant inventory every run reads from `ProcessState.registry` (`init_state`), the vocabulary the
condition rewrite reads (`queryable_action`), and the published value an Extension extends through
`RegistryBuilder(published)`.
"""
struct AlterantRegistry
    plugins::Vector{Alterant}
    sorted_alt_actions::Vector{Symbol}
    action_to_plugin::Vector{Int8}
    action_index::Dict{Symbol,Int8}
    alt_index::Dict{Symbol,Int8}
    accum_alt_idxs::Vector{Int8}
    mutex_alt_idxs::Vector{Int8}
    # The DECLARED registration record (since v0.2) — one ActionSpec per
    # registered action, DECLARATION order (the parallel derived tables above stay
    # the hot-path lookups; the record is the authority — the author's statement).
    # `spec_index`: action name → index into `action_specs`.
    action_specs::Vector{ActionSpec}
    spec_index::Dict{Symbol,Int}
    # THE SNAPSHOT BASELINE: a deep domain-copy of the nine
    # `_SNAPSHOT_FIELDS` values taken at publish (leaves — callables/Types/Symbols/Strings/
    # VersionNumbers/numbers — carried by reference; containers rebuilt at their exact concrete
    # types). The door compares the live fields against it by the ONE structural deep-egal walk
    # (`===`-only leaves) and fires `POST_SEAL_MUTATION` at the first divergent path — replacing
    # the retired seal re-mint + derived-table re-derivation + callable-identity compare
    # (accident-grade integrity, never security-grade; the entry check is not a lock; the
    # snapshot's own members are mutable — the disclosed residue). `nothing` on
    # unsealed values; the underscore is deliberate — an integrity baseline is not a plain
    # member of a package-public struct.
    _snapshot::Union{Nothing,NamedTuple}
    # THE ONE CONSTRUCTOR, token-gated. What the token IS and IS NOT (the honest
    # bound): it removes the generated all-fields constructor so no POSITIONAL or ACCIDENTAL
    # construction can carry a snapshot — the route-U and mutation classes conforming code produces.
    # It is NOT an unforgeable capability: Julia has no access control, `GoMeta._SealToken()` is
    # callable by any loaded code, and a caller who reaches for it can
    # construct an unvalidated published value — that caller is a loaded module with full process
    # authority, OUTSIDE the trust model by the security frame's bound ("no in-process
    # arrangement in Julia constrains a loaded module"). Every integrity claim of this type is
    # accident-grade: coded refusal of post-seal mutation by CONFORMING code, never security-grade.
    # THE FORM: the seven derived tables enter BY NAME as ONE NamedTuple
    # argument, destructured by field name HERE — the one reviewed destructuring site. No
    # hand-written table binding exists at any snapshot-carrying call site, so the two
    # same-typed groups (`action_index`/`alt_index`; `action_to_plugin`/`accum_alt_idxs`/
    # `mutex_alt_idxs`) cannot be swapped by a caller.
    function AlterantRegistry(::_SealToken, plugins::Vector{Alterant},
                              action_specs::Vector{ActionSpec}, t::NamedTuple,
                              snapshot::Union{Nothing,NamedTuple})
        new(plugins, t.sorted_alt_actions, t.action_to_plugin, t.action_index, t.alt_index,
            t.accum_alt_idxs, t.mutex_alt_idxs, action_specs,
            t.spec_index, snapshot)
    end
end
"""
    AlterantRegistry(plugins, sorted_alt_actions, action_to_plugin, action_index, alt_index,
                     accum_alt_idxs, mutex_alt_idxs, action_specs, spec_index)

IS: ROUTE U — the positional construction of a registry from hand-built tables — GATED at v0.4.0 (every public
construction route runs the remaining checks; removal = v0.5).

DOES: runs the remaining checks over `(plugins, action_specs)` (`_validate_registration`) AND derives the tables from
the declarations (`_derive_tables`); the hand-built derived tables must equal the derived ones — each of the seven
compared by `==` — else a `REG_DERIVED_TABLES` diagnostic is collected ALONGSIDE the others (full collection); any
error-severity defect throws `RegistrationRefused` with EVERY collected diagnostic. A `_derive_tables` failure always
co-occurs with an error diagnostic, thrown first; were that ever false, the route refuses coded with its own
`REG_DERIVED_TABLES` row rather than reaching the token form. A conforming construction yields an
UNPUBLISHED registry (`_snapshot === nothing`) whose tables are the DERIVED objects (`==`-equal to the caller's,
distinct identity — recorded, not silent; no pin reads their identity) — the `goMeta` door refuses it coded, naming
the sanctioned path (`RegistryBuilder → validate → publish`); route U therefore dies at the entry too (the
STRICT door). No positional form accepts a snapshot: for conforming callers, published values come from `publish`
(the honest bound: the token form is reachable by any loaded module — accident-grade).

REASONING: a hand-built table can disagree with the declared record; deriving the tables from the record alone and
refusing on any difference keeps the record the authority, and the missing snapshot keeps the value out of `goMeta`.

PURPOSE: the gated public positional route — every construction runs the checks, and only `publish` yields a value
the door admits.
"""
function AlterantRegistry(plugins::Vector{Alterant}, sorted_alt_actions::Vector{Symbol},
                          action_to_plugin::Vector{Int8}, action_index::Dict{Symbol,Int8},
                          alt_index::Dict{Symbol,Int8}, accum_alt_idxs::Vector{Int8},
                          mutex_alt_idxs::Vector{Int8},
                          action_specs::Vector{ActionSpec}, spec_index::Dict{Symbol,Int})
    diags = _validate_registration(plugins, action_specs)
    derived = try _derive_tables(plugins, action_specs) catch; nothing end   # a structurally broken
    if derived !== nothing                                                  # record already reported
        derived.sorted_alt_actions == sorted_alt_actions &&
            derived.action_to_plugin == action_to_plugin &&
            derived.action_index == action_index &&
            derived.alt_index == alt_index &&
            derived.accum_alt_idxs == accum_alt_idxs &&
            derived.mutex_alt_idxs == mutex_alt_idxs &&
            derived.spec_index == spec_index ||
            push!(diags, Diagnostic(:REG_DERIVED_TABLES, :error,
                "GoMeta registry: positional construction supplied derived tables that do not " *
                "match the tables derived from the declared record (route U is GATED at v0.4.0; " *
                "build via RegistryBuilder → validate → publish)"))
    end
    any(d -> d.severity === :error, diags) && throw(RegistrationRefused(diags))
    # `derived === nothing` is unreachable here — a `_derive_tables` failure
    # always co-occurs with an error diagnostic, thrown above. Were the invariant ever false,
    # route U refuses coded before the token form rather than passing `t === nothing`.
    derived === nothing && throw(RegistrationRefused([Diagnostic(:REG_DERIVED_TABLES, :error,
        "GoMeta registry: positional construction could not derive tables from the declared " *
        "record (route U is GATED at v0.4.0; build via RegistryBuilder → validate → publish)")]))
    # the constructed value's tables are `derived`'s objects (`==`-equal to the caller's,
    # distinct identity — recorded, not silent; no pin reads their identity)
    return AlterantRegistry(_SealToken(), plugins, action_specs, derived, nothing)
end
"The number of registered alterants (4 since the heading registration; 3 before it)."
num_alterants(r::AlterantRegistry) = length(r.plugins)

# --- the v0.4 registration LIFECYCLE types: Builder → validated → PUBLISHED ------------------
"""
    RegistryBuilder()

IS: the MUTABLE declaration site of a registry — two vectors, `plugins` and `action_specs`, both empty from this
constructor; the first step of the lifecycle `RegistryBuilder → validate → publish`.

DOES: `register!(builder, plugin, specs...)` appends an Alterant registration record + its action records in
declaration order. `register!` performs its two IMMEDIATE refusals (throwing `RegistrationRefused`): the records must
name the plugin index being appended (`REG_PROTOCOL`), and the Int8 slot pool (127 plugins, 127 actions) must not
overflow (`REG_SLOT_EXHAUSTED`); every other check is DEFERRED to `validate(builder)`, which collects EVERY defect as
coded diagnostics (full collection before the one terminal outcome, never throwing), and `publish(builder)` refuses
on any error, else DEEP-copies every container into a SEALED — published, the snapshot taken — `AlterantRegistry`
(the sanctioned route to a sealed value; `next_plugin_index(builder)` gives the index the next record must name).
`default_registry_builder()` returns the four shipped Alterants with their nine action records in one
(src/alterants/registry.jl); `RegistryBuilder(published)` preloads one from a published value.

REASONING: declaring is mutable and checking is deferred so that a whole record is collected before one terminal
outcome; the published value is a separate, copied object, so a later mutation of the builder cannot reach it.

PURPOSE: where an Extension declares its Alterant and its actions before `validate` and `publish`.
"""
mutable struct RegistryBuilder
    plugins::Vector{Alterant}
    action_specs::Vector{ActionSpec}
end
RegistryBuilder() = RegistryBuilder(Alterant[], ActionSpec[])
"""
    next_plugin_index(builder) -> Int8

IS: the declaration-order index the NEXT `register!`ed record must name — `length(builder.plugins) + 1`.

DOES: returns that index typed `Int8`, so it passes straight into `ActionSpec(; plugin = …)`; at capacity (127
plugins already) it throws the lifecycle's coded `REG_SLOT_EXHAUSTED` refusal (a `RegistrationRefused` carrying one
diagnostic) instead of an unusable 128. Reads the builder, writes nothing.

REASONING: `register!` refuses a record naming another index, so the author needs the index before writing the
record; the Int8 pool's end is named here, before an overflowing value could be typed.

PURPOSE: the index an Extension writes into its `ActionSpec`s before `register!` (package-public,
docs/public-api.md §1.2).
"""
function next_plugin_index(b::RegistryBuilder)::Int8
    n = length(b.plugins) + 1
    n > typemax(Int8) && throw(RegistrationRefused([Diagnostic(:REG_SLOT_EXHAUSTED, :error, string(
        "GoMeta registry: next_plugin_index — the builder already holds ", Int(typemax(Int8)),
        " alterants (the Int8 slot pool); no further index exists"), nothing)]))
    return Int8(n)
end
"""
    RegistryBuilder(published::AlterantRegistry) -> RegistryBuilder

IS: a builder PRELOADED with a published registry's declarations — the documented way to extend the built-in inventory
(`RegistryBuilder(DEFAULT_REGISTRY)`), then `register!` the new Alterant at `next_plugin_index`.

DOES: copies `plugins` and `action_specs` by the domain copier `_domain_copy` (`_copy_published_records`,
src/alterants/registry.jl — one memo across both fields): nothing mutable shared with the published value; leaves
carried by reference; `deepcopy` is never dispatched. This is the ONE route that meets UNVALIDATED values (the input
may carry a post-publication cycle, an out-of-domain value, or a position-rule offense), so the copy is CONTAINED:
a cycle, an outside-domain value, or a `Function`/record struct outside its lawful position
converts to a coded `RegistrationRefused` (`REG_PROTOCOL`) whose message names the offending type and the path — as
do the copier's two path-less classes (a user method thrown at a Dict rebuild; an undefined container element); any
other exception is rethrown (`_route2_refuse`). No internal exception and no unbounded recursion leaves this public
constructor. The derived tables are not copied: `publish` derives them again from the declarations.

REASONING: an Extension extends the shipped inventory by adding to a copy of its declarations, never by touching the
published value; a published value mutated after publication into a cycle, an outside-domain value or a position-rule offense is met here with a coded refusal, not a raw exception; an in-domain edit is copied — the door, not this constructor, compares against the snapshot.

PURPOSE: the extension route of the lifecycle — from `DEFAULT_REGISTRY` to a builder an Extension registers into.
"""
RegistryBuilder(r::AlterantRegistry) = RegistryBuilder(_copy_published_records(r)...)

"""
    register!(builder, plugin, specs...) -> builder

IS: the append of one Alterant registration record + ITS action records to a builder, in declaration order.

DOES: the plugin takes the next declaration-order index `i` (`length(builder.plugins) + 1`), and every supplied
`ActionSpec` MUST name `plugin == i` — a record naming another index would pass validation against that other
Alterant's setter and leave the appended one silently actionless, so the mismatch refuses HERE,
loudly, as `REG_PROTOCOL` (the message lists the offending action names); the Int8 slot pool refuses
`REG_SLOT_EXHAUSTED` at the 128th PLUGIN append AND when the appended action records would exceed 127 ACTIONS.
The pool checks run before the index check; each refusal is a `RegistrationRefused` carrying one
diagnostic whose `context` is the Alterant's `altName`. On success it pushes the record, appends the specs and
returns the builder; nothing else is checked here — the remaining checks are `validate`'s.

REASONING: the record shape law — a record belongs to the Alterant it is registered with — is cheapest to hold at the
append, where the index is known; the Int8 index space bounds both pools.

PURPOSE: the append route of the lifecycle (package-public, docs/public-api.md §1.2) — the shipped four enter
`default_registry_builder`'s vectors directly, and `RegistryBuilder(published)` preloads a builder from a published
value.
"""
function register!(b::RegistryBuilder, plugin::Alterant, specs::ActionSpec...)
    n = length(b.plugins) + 1
    n > typemax(Int8) && throw(RegistrationRefused([Diagnostic(:REG_SLOT_EXHAUSTED, :error, string(
        "GoMeta registry: register! — appending alterant ", repr(plugin.altName), " would be plugin ",
        n, ", beyond the slot pool of ", Int(typemax(Int8)), " (the Int8 index space)"), plugin.altName)]))
    na = length(b.action_specs) + length(specs)
    na > typemax(Int8) && throw(RegistrationRefused([Diagnostic(:REG_SLOT_EXHAUSTED, :error, string(
        "GoMeta registry: register! — appending ", length(specs), " action record(s) with alterant ",
        repr(plugin.altName), " would make ", na, " actions, beyond the slot pool of ",
        Int(typemax(Int8)), " (the Int8 index space)"), plugin.altName)]))   # the ACTION pool too
    idx = Int8(n)
    bad = [s.name for s in specs if s.plugin != idx]
    isempty(bad) || throw(RegistrationRefused([Diagnostic(:REG_PROTOCOL, :error, string(
        "GoMeta registry: register! — action record(s) ", bad, " do not name the plugin index ", idx,
        " of the alterant ", repr(plugin.altName), " just appended (a record must belong to the ",
        "alterant it is registered with; the record shape law)"), plugin.altName)]))
    push!(b.plugins, plugin)
    append!(b.action_specs, collect(specs))
    return b
end

"""
    RegistrationRefused(diagnostics)

IS: the coded refusal of a registration — an `Exception` carrying `diagnostics::Vector{Diagnostic}`.

DOES: thrown by `publish` (and by the gated positional route) with EVERY collected error/warning diagnostic — never
the first one only — and by `register!` / `next_plugin_index` for their two IMMEDIATE checks (the plugin-index
binding `REG_PROTOCOL`; the plugin/action pool overflow `REG_SLOT_EXHAUSTED`); also by `RegistryBuilder(published)`
when the contained copy meets a value the record shape law refuses (`REG_PROTOCOL`), and by `publish` when its own
copy fails (`REG_PROTOCOL`). `Base.showerror` prints the error count, the total count and one line per diagnostic
(`[severity] code — message`). Catch it, read `.diagnostics` (stable `code`s), fix the record, re-validate.

REASONING: a registration's defects are reported whole, as rows with stable codes, so an author fixes the
record once rather than meeting one defect per attempt.

PURPOSE: the one package-public exception type of the registration lifecycle (docs/public-api.md §1.2).
"""
struct RegistrationRefused <: Exception
    diagnostics::Vector{Diagnostic}
end
function Base.showerror(io::IO, e::RegistrationRefused)
    n = count(d -> d.severity === :error, e.diagnostics)
    print(io, "RegistrationRefused: ", n, " error diagnostic(s) (", length(e.diagnostics), " total):")
    for d in e.diagnostics
        print(io, "\n  [", d.severity, "] ", d.code, " — ", d.message)
    end
end
"The number of registered alterant actions (9 since 0.4.0; 8 from the heading registration until then; 7 before it) — not the queue's per-slot capacity, which is `SLOT_CAPACITY`."
num_alt_actions(r::AlterantRegistry) = length(r.sorted_alt_actions)
"""
    queryable_action(r::AlterantRegistry, key::Symbol) -> Bool

IS: the registry's ONE vocabulary rule for a bare name inside a `{…}` condition:
TRUE iff `key` is a registered action of an Alterant that ANSWERS queries (its record declares
`getAltInstance`).

DOES: tests `insorted(key, r.sorted_alt_actions)` and, only then, whether the owning record's `getAltInstance` is
not `nothing` (the lookup through `action_index` and `action_to_plugin` runs only for a registered name). A
condition's bare name is a settribute key, or a queryable action, or it meets the usual unknown-key refusal — the
creator's rule delivered by this one function (the three Visib names, no longer settribute keys, are the actions of a
getter-less Alterant — as are Id's and the Heading's; Labels' `:` is the one queryable action among the shipped
nine). The caller is the rewrite's `_cond_target` (src/absorb/absorb_meta.jl), which spells a queryable action as
`getAltState(Int8(p), Symbol("key"), …)`.

REASONING: the rule is the registry's, not a condition reader's: it outlived the closed interpreter (removed within
the 0.4 development) and is the vocabulary test of the rewrite that replaced it (`_rewrite_condition`,
src/absorb/absorb_meta.jl — where the original engine's reader tested `insorted(key, sortedAltActionsSVec)`).

PURPOSE: what a bare name in a condition may be, decided from the registration record alone.
"""
queryable_action(r::AlterantRegistry, key::Symbol)::Bool =
    insorted(key, r.sorted_alt_actions) && r.plugins[r.action_to_plugin[r.action_index[key]]].getAltInstance !== nothing

# --- the per-call mutable state ----------------------------------------------------------------------
"""
    MetaHierarchyState

IS: the per-call meta-hierarchy slot tensors — `slots` (length `NUM_MH_LEVELS`), `slot_occupied` / `slot_has_accum`
(dense `Vector{Bool}`, deliberately not `BitVector`s), and `count_actions_per_slot`.

DOES: `slots[level]` holds the slot number a meta-hierarchy level occupies, 0 for none; the other three are indexed
by slot: `slot_occupied[slot]` whether the slot is allocated, `slot_has_accum[slot]` whether an action of an
`:accumulate` Alterant was enqueued into it, `count_actions_per_slot[slot]` the enqueue row count (the queue
matrices' dim-1). `updateMetaHierarchy` allocates the first unoccupied slot for the current level and wipes the
levels the cursor re-enters (`wipeAltActionSlots` — the slot's queue rows, its flags, its `slots` entry);
`absorbMeta` reads the current level's slot, increments its count and sets its accumulate flag; the apply reads
`slots` and `slot_occupied` to collect the eligible slots in priority order (src/alterants/registry.jl,
src/absorb/absorb_meta.jl, src/alterants/apply.jl). All plain `Vector`/`Array`, sized once by `init_state`.

REASONING: the level → slot indirection is the design note's (src/alterants/registry.jl): the slot count was
conceived as possibly larger than the level count — meta stored at an already-used level without overwriting the
previous one; at v0 the two are equal (12), so one const carries both.

PURPOSE: the per-call bookkeeping of which meta-hierarchy level holds which enqueued actions, read by the absorb walk
and the apply.
"""
struct MetaHierarchyState
    slots::Vector{Int8}
    slot_occupied::Vector{Bool}
    slot_has_accum::Vector{Bool}
    count_actions_per_slot::Vector{Int8}
end

"""
    AlterantArgT

IS: the action-argument LITERAL FLOOR — exactly `Union{Symbol,String}` — the element type of an enqueued argument
tuple (`AlterantQueue.args`) and of the tuple a setter receives.

DOES: an enqueued argument is a `Symbol` (every bare token, INCLUDING numeric text — `Symbol("7")`; the integer
space is deliberately not an arm of this union, so numeric arguments keep their exact fates at the setter, which
parses them itself) or a `String` (the CONTENT of a well-formed quoted token — `_coerce_arg_token`,
src/absorb/absorb_meta.jl, the one coercion point). ONE grammar accepts the String kind — the Heading action's TEXT
slot (`accepts_string_slot = 1`, the quoted-first sugar); every slot a record does not declare refuses a quoted argument
at `absorbMeta`'s enqueue seam (`_string_slot_check`) — each
refusal an `ErrorException` raised by `error` ("GoMeta absorb: string argument not accepted — …"; the file's own
word for its refusals: without a code, its coded conversion deferred). Dispatch alone cannot hold that law: the built-in
setters keep an untyped value slot that would parse `cell("7")`.
The heading's text slot is the one slot a shipped record declares for a String.

REASONING: the floor is exactly Symbol | String so that every bare token stays the Symbol it always became and a
quoted token is a String only where a record declares the slot; the integer space is reserved.

PURPOSE: the type the absorb seam coerces argument tokens to and the setters are called with.
"""
const AlterantArgT = Union{Symbol,String}

"""
    AlterantQueue

IS: the per-call enqueue tensors: `queued` (`2 × SLOT_CAPACITY × num_slots`), `conditions`, `args`, `decided_by`
and `applied_to`.

DOES: `queued[1, row, slot]` holds the declaration-order plugin index and `queued[2, row, slot]` the action index
(into `sorted_alt_actions`) of the enqueued action; `conditions` carries the condition as Julia's `Expr` (what
`Meta.parse` returned for the re-written body — the absorb seam's `parseConditions`; evaluated by `Core.eval` at
apply), `nothing` for an action without `{}`; `args` carries tuples over the argument literal floor `AlterantArgT`
(`Symbol` | `String` — see that type's docstring), `nothing` for no arguments; `decided_by` carries per enqueued
action the `key_bytes` handle of the Component that STATED it (the carrying Component's handle published at the walk
handover — the metaBlock a whole-line metaLine forms, the Segment of an inline one; on the userMH feed the
minted user-context handle), carried through the apply into the stored row's provenance field; `applied_to` carries per
enqueued action the `key_bytes` of the Component the statement is APPLIED TO (the walk's `MetaContext.applied`: the metaBlock
for a metaLine's statement, a comment-split metaLine included; the Line with the Segment as the key's origin for
an inline metaSegment; `nothing` on the userMH feed) — the referent of the apply loop's one rule for the set mode
`localOnly`. All four matrices
are indexed `[row, slot_index]`: dim-1 is the per-slot enqueue ROW counter (`1..count_actions_per_slot[slot]` — the
sequential order in which actions were absorbed into that slot, NOT a registry action index; the matrices are merely
SIZED `SLOT_CAPACITY × num_slots` as the per-slot upper bound — 8, decoupled from the registered action count), dim-2 = slot, parallel to `queued[:, row, slot]`.
The apply phase MUST index `[row, slot]` consistently (a row/slot transposition would corrupt the queue). Written by
`absorbMeta` (src/absorb/absorb_meta.jl), read by `detAltValuesForSetOfSlots` (src/alterants/apply.jl), wiped per
slot by `wipeAltActionSlots`. Sized once by `init_state`.

REASONING: the queue holds the absorbed statements as values — the `Expr`, the tuple, the handle — in source order
per slot, so the apply can evaluate each condition against the Component it applies to and record which statement
decided the value (provenance MEASURED at the enqueue, never inferred).

PURPOSE: the hand-over from the absorb walk to the apply — what was stated, under which condition, with which
arguments, by which Component.
"""
struct AlterantQueue
    queued::Array{Int8,3}
    conditions::Matrix{Union{Nothing,Expr}}
    args::Matrix{Union{Nothing,Tuple{Vararg{AlterantArgT}}}}
    decided_by::Matrix{Union{Nothing,Vector{UInt8}}}
    applied_to::Matrix{Union{Nothing,Vector{UInt8}}}   # the applied Component's key — the referent of the localOnly rule
end

"""
    MetaContext

IS: the context record — {grain, depth, application level, occurrence handle, applied key} — published at the
walk→absorb handover for the current component (its handle the carrying Component's; its applied key the
Component the statement is applied to).

DOES: The context record — **{grain, depth, application level, occurrence handle, applied key}**,
derived from the parse and the run's configured namespace (`st.config.namespace` keys the handle —
nothing else of the configuration enters), published at the walk→absorb handover (`applyAbsorbFn`
builds it from the component + the post-update MH cursor and sets `st.meta_context`) and
stored in NO Component (the evaluation-free-tree law). Its consumers:
the enqueue's two provenance columns (`decided_by` ← `handle`, `applied_to` ← `applied`) and the deriving head form's
level (the attr-fold: the level rides the attr NAME `head_<level>`; no fabricated rows, no record-schema change; the
userMH feed NULLS the record before its absorb call — no document line exists there — and a heading fed through that
surface meets the one refusal, its wording the creator's). `level` is the
application level — the RAW MH-ladder index the walk set for this component (a
Segment-attached metaLine inherits the metaLine's `lineMHIdx`, so the inheritance
law holds by construction); the RECORDED level is normalized to ladder−1 — the
author's own `#~`-digit vocabulary — at the enqueue materialization seam (the documented
level vocabulary; the record itself stays as derived — from the parse and the configured
namespace, mutated by nothing). `handle` is the carrier's
serialized occurrence key (`key_bytes`) — every row's DECIDING STATEMENT; `applied` is the key of the
Component the statement is APPLIED TO — the referent of the apply loop's rule for the set mode
`localOnly`.

REASONING: derived from the parse and the configured namespace, stored in no Component (the evaluation-free-tree
law), so a consumer reads a record rather than a mutated BLS Component tree.

PURPOSE: the consumers' record: the enqueue's provenance columns and the deriving head form's level (the attr-fold).
"""
struct MetaContext
    grain::Symbol            # :Block | :Line | :Segment
    depth::Int               # the component's own MH depth marker — 0 at v0.2: the walk's
                             # handover sites are Line/Segment-grain only (no Block-grain
                             # applyAbsorbFn call site exists), so the Block arm is defensive;
                             # the field is the record's designed shape
    level::Int               # the APPLICATION level — the MH-ladder index at absorb time
    handle::Vector{UInt8}    # the CARRIER's occurrence-key bytes (from the parse and the configured
                             # namespace) — every row's deciding statement
    applied::Vector{UInt8}   # the occurrence-key bytes of the Component the
                             # statement is APPLIED TO — the metaBlock for a metaLine's statement, the LINE
                             # for a Code Line's trailing metaSegment, keyed as the apply path keys it (the Line with the Segment as
                             # the key's origin), the metaBlock for the statement Segment of a metaLine split by a trailing comment —
                             # the referent of the localOnly rule (the queue's `applied_to`); differs from `handle` only for an inline metaSegment of a Code Line
end

"""
    UserContext

IS: the profile-feed surface's own recordable identity (the user-context build): one field, `handle` = the minted
user-context key bytes (`user_context_key(config.namespace, region_ordinal)`, serialized by `key_bytes`; the
ordinal 1 at v0 — one feed, one region).

DOES: constructed by the feed routine (`feed_user_mh!`, src/GoMeta.jl) immediately before its absorb call and
RESTORED-to-prior in a `finally` right after (the stack-disciplined bracket); the document-side `meta_context` stays
`nothing` on the feed. Read at the absorb seam as the enqueued
action's `decided_by` handle when no document context exists, and as the trigger of the one refusal a heading in the
profile feed meets (the wording the creator's: no Component of the file levels to be local to). The fed
profile's bytes are NOT carried on the record (the row has no piece in the
tree — its derived fifth column is empty, by the creator's decision). Immutable; per-call
config inputs only.

REASONING: the feed has no document Component behind it, so its statements need an identity of their own to be
recorded against — minted from the per-call configuration, deterministic, and present only inside the feed's bracket.

PURPOSE: the handle a fed profile's rows and provenance carry (`USER_CONTEXT_GRAIN`, src/occurrence.jl).
"""
struct UserContext
    handle::Vector{UInt8}
end

"""
    ProcessState

IS: the per-call, mutable, threaded-via-`ctx()`, NEVER-global engine state of one run.

DOES: The per-call, mutable, threaded-via-`ctx()`, NEVER-global engine state. Wraps the parse state,
the config, the (immutable) registry, the meta-hierarchy + queue sub-states, the transient per-slot
alterant-instance dict (`working`) with its provenance sibling `working_origin` (per Alterant the handles of the
statements the apply applied, in application order), the `evals` (the evals rows captured
before the slot wipe → readAltValuesEvals), the current-settribute `snapshot`,
the accumulating `diagnostics`, the three mutable meta-hierarchy cursors, and the per-component
`meta_context` record (see `MetaContext`). Constructed only by `init_state`; delivered per-call via the `STATE` ScopedValue, read through `ctx()`.

REASONING: one fresh state per call, delivered through the `STATE` ScopedValue, so two concurrent calls never
share state and nothing carries over between runs.

PURPOSE: the working memory of a run — the parse, the config, the registry, the meta-hierarchy and queue
sub-states, the transient `working` dict, the `evals` store, the snapshot, the diagnostics, the cursors and the
per-component context — constructed only by `init_state`.
"""
mutable struct ProcessState
    parse::BLS.ParseState
    config::GoMetaConfig
    registry::AlterantRegistry
    mh::MetaHierarchyState
    queue::AlterantQueue
    working::Dict{Int8,Any}
    working_origin::Dict{Int8,Vector{Vector{UInt8}}}   # the provenance: per Alterant the handles of the
                                                       # statements the apply APPLIED, in application order; rebuilt with `working`
    evals::EvalStore
    snapshot::BLS.ComponentSettribute
    diagnostics::Vector{Diagnostic}
    crnt_depth_idx::Int
    first_parent_idx::Int
    crnt_idx::Int
    meta_context::Union{Nothing,MetaContext}   # the context record (see MetaContext above)
    user_context::Union{Nothing,UserContext}   # the user-context build: non-nothing ONLY
                                               # inside the feed routine's bracket (set
                                               # before its absorb call, restored-to-prior
                                               # in the finally) — never set on the
                                               # document walk; read at the absorb seam as
                                               # a fed action's `decided_by` handle and as the trigger of the one refusal a `localOnly` statement meets in the feed (no capture reads it).
    alt_run::Vector{Any}                       # ONE cell per registered Alterant — its PER-RUN state,
                                               # `nothing` at `init_state` and until the Alterant's read-time hook (`onRead`) consumes a statement
                                               # and returns the state; read by the apply's instance constructor (`_freshInstance`) — the
                                               # constructor is given the state where one was minted, called bare otherwise; dies with the call
                                               # (the reset-safe law). The Labels Alterant's: the run's vocabulary (labels.jl `LabelsVocabulary`).
end

"""
    _deliver_diagnostics!(st, ds::Vector{Diagnostic}, place::NamedTuple)

THE ONE DOOR (since 0.4.3): an Alterant's callable may RETURN a vector of diagnostics — the setter's at the apply, the read-time hook's at the
read — and the Engine delivers them on the run's `diagnostics`, the PLACE it knows at that moment merged into each row's context: at the apply
the applying Component's key, the stating statement's handle and the Alterant's statements applied at that Component so far (`cell`,
`stated_by`, `statements` — apply.jl builds it); at the read the stating statement's handle, the meta-hierarchy index the hook received and
the statement's text (`stated_by`, `level`, `statement` — absorb_meta.jl builds it). A named-tuple context is merged (the place's keys
winning where a name collides), a `nothing` context replaced by the place alone, any other context kept under `alterant_context`; the
severity is copied, never decided (the status rule reads `:error` alone). The one test at every call site is `isa Vector{Diagnostic}` —
a vector typed `Any` or of a subtype is ignored like any other value. For EVERY Alterant: the hook and the setter are registration fields
any Alterant may declare, and none must use the door (the creator's law on the Engine's facilities).
"""
@noinline function _deliver_diagnostics!(st::ProcessState, ds::Vector{Diagnostic}, place::NamedTuple)
    for d in ds
        ctx = d.context
        merged = ctx isa NamedTuple ? merge(ctx, place) : ctx === nothing ? place : merge((alterant_context = ctx,), place)
        push!(st.diagnostics, Diagnostic(d.code, d.severity, d.message, merged))
    end
    return nothing
end

"""
    GoMetaDelivery(blsComponentTree, altValues_evals, status, diagnostics)

IS: the ONE object a GoMeta run hands back — the delivery of `goMeta(bytes; config, registry)` — with its FOUR public
parts, read by name (the creator's decisions of 2026-09-15/16 on the content,
the shape and the name; docs/public-api.md §1.1, §2):

- `blsComponentTree::BLS.ParseState` — the BLS Component tree the run was evaluated over, provided by BLS itself;
  it reaches an Extension as the part `blsComponentTree`, not through any function of the GoMeta Engine; an Extension
  travels it with BLS's own public functions (the creator's decision). FIRST in
  the field order — his pipeline order.
- `altValues_evals::EvalStore` — the data container of the evaluated Alterant values: one final evals row per
  handle and attribute, as the run recorded them; the reader over it is `readAltValuesEvals`.
- `status::ProcessStatus` — `PROCESS_OK` (no error-severity diagnostic) or `PROCESS_ERROR` (at least one;
  non-OK ⇒ non-empty diagnostics).
- `diagnostics::Vector{Diagnostic}` — the run's coded diagnostics: every row the run recorded, `:error` and
  `:warning` alike; empty when it recorded none; a `PROCESS_OK` run may carry `:warning` rows (since 0.4.3) — the Labels Alterant's `LABEL_NOT_APPLIED_WITHHELD`, a plain `:x` met by a withhold, returned by the setter and delivered by the apply loop's door with the place in its context — so `PROCESS_OK` means no `:error` row, not an empty vector (the entry door's fail-closed `PROCESS_ERROR` delivery, `_entryErrorDelivery` in src/GoMeta.jl, carries its `:error` rows).

DOES: carries these four and NOTHING internal — the per-call working state (`ProcessState`) never leaves the
core. The parts are plain fields, in the creator's pipeline order: `d.blsComponentTree`, `d.altValues_evals`,
`d.status`, `d.diagnostics`. The BLS Component tree is the SAME object the run read (`init_state` keeps the parse state by
identity; the Engine writes nothing into it), and it is MUTABLE:
every reader of one delivery shares that one object — a discipline, not a copy. On a fail-closed run (`PROCESS_ERROR`
before any parse of that call — a registry refused at the entry door, `REG_UNPUBLISHED` / `POST_SEAL_MUTATION`, the ONE entry refusal since 0.4.0; an unknown `flavor_tag` throws at `flavor_for` instead) the tree is a container
built from EMPTY bytes and the store is empty.

REASONING: the creator's design — `altValues_evals` and the BLS Component tree are "BY FAR the two MOST
IMPORTANT DATA CONTAINERS produced during the GoMeta process" (the creator's words, 2026-09-11); it is "NOW VERY
IMPORTANT to RESTRICT THAT INTERFACE TO A MINIMUM in order to MAXIMIZE OUR FLEXIBILITY IN IMPROVING GoMeta"
(his words, 2026-09-11); the content: his decision — altValues_evals, the BLS
Component tree, the status and the diagnostics, nothing else; the shape his decision —
one named object, the four parts public by name, no hand-over function; the name `GoMetaDelivery` his
("object's names such as 'result' are NOT DESCRIPTIVE" — his words). The working state is the
Engine's own and its shape is not part of the delivered surface, so it is not delivered at all rather than
delivered and declared unstable (the creator's decision of 2026-09-15).

PURPOSE: what every Extension, development tool and test consumes from a run — and the reference object of
v0.4 for the GoMetaRetro line ("The final GoMeta v0.4 must produce a GoMetaDelivery which we can use as a
reference" — his words, 2026-09-17). The one `Base.show` method prints one line in the field order — the source-line count of
`blsComponentTree`, the row count of `altValues_evals`, the status, the diagnostics count — never the tree or the
rows.
"""
struct GoMetaDelivery
    blsComponentTree::BLS.ParseState     # the creator's pipeline order: the tree first
    altValues_evals::EvalStore
    status::ProcessStatus
    diagnostics::Vector{Diagnostic}
end

function Base.show(io::IO, d::GoMetaDelivery)
    print(io, "GoMetaDelivery(blsComponentTree: BLS.ParseState over ", length(d.blsComponentTree.collectedLines), " source lines",
          "; altValues_evals: ", length(d.altValues_evals.records), " evals rows",
          "; ", d.status,
          "; diagnostics: ", length(d.diagnostics), ")")
end

# --- the swappable delivery seam -------------------------------------------------
"""
    const STATE :: ScopedValue{ProcessState}

IS: the per-call state binding — a `ScopedValue` with NO default, so an unscoped read THROWS (fail-loud, supporting
the total typed surface).

DOES: `goMeta` opens `with(STATE => init_state(…)) do … end` around the feed, the absorb walk and the apply; every
state-bearing function reaches it through `ctx()` (`STATE[]`), the only accessor — the re-written conditions'
bare-name `getState` / `getAltState` among them (`Core.eval` in module GoMeta). This is THE swap point: a benchmark
could flip the delivery (ScopedValue ⇄ threaded arg) by changing `ctx()` alone.

REASONING: one fresh state per call, delivered through a dynamic scope rather than a global, so two concurrent calls
never share state and a condition evaluated by Julia reaches this call's state without a threaded argument.

PURPOSE: the delivery seam of the per-call `ProcessState`.
"""
const STATE = ScopedValue{ProcessState}()

"The per-call state accessor (the swap seam). Hot loops hoist `local st = ctx()` once per function; the
eval'd `getState`/`getAltState` reach `ctx()` with zero change to the generated condition strings."
@inline ctx() = STATE[]

# --- construction (the reset-safe constructor) + the settribute helpers ------------------------------
"""
    init_state(parse_state, config, registry) -> ProcessState

IS: the constructor of a FRESH `ProcessState`, sized once per call from `SLOT_CAPACITY` and `NUM_MH_LEVELS` (the registry's action count sized the queue before 0.4.0).

DOES: Build a FRESH `ProcessState`, sizing every container ONCE from `SLOT_CAPACITY` + `NUM_MH_LEVELS` (the registry is carried, never a size). Every
per-field init is performed here, so each call is independent — no tensor or cursor carries over:
`slots = zeros(Int8, NUM_MH_LEVELS)`; the `slot_*`/`count_*` per-slot vectors `fill(false,·)`/`zeros(Int8,·)`;
`queued = zeros(Int8, 2, nAct, nSlot)`; `conditions`/`args`/`decided_by`/`applied_to` matrices filled with `nothing`; `working` and `working_origin`
empty `Dict`s; `evals` empty; `snapshot` a FRESH `ComponentSettribute` (its `array` is COPIED into by
`snapshot_settribute!`, never aliased); the three cursors all `fileMHIdx` (= 1).
`num_slots == NUM_MH_LEVELS`.

REASONING: every per-field init is performed here so that each call is independent — no tensor or cursor
carries over (the reset-safe law).

PURPOSE: the reset-safe start of every run, the only route to a `ProcessState`.
"""
function init_state(parse_state::BLS.ParseState, config::GoMetaConfig, registry::AlterantRegistry)
    n_act  = SLOT_CAPACITY               # the per-slot capacity, 8 — DECOUPLED from num_alt_actions (9 since the `ids` action); before 0.4.0 the registered count
    n_slot = NUM_MH_LEVELS               # 12
    mh = MetaHierarchyState(
        zeros(Int8, NUM_MH_LEVELS),      # slots
        fill(false, n_slot),             # slot_occupied  (dense Vector{Bool}, NOT a BitVector)
        fill(false, n_slot),             # slot_has_accum
        zeros(Int8, n_slot),             # count_actions_per_slot
    )
    queue = AlterantQueue(
        zeros(Int8, 2, n_act, n_slot),                                                     # queued
        fill!(Matrix{Union{Nothing,Expr}}(undef, n_act, n_slot), nothing),                 # conditions
        fill!(Matrix{Union{Nothing,Tuple{Vararg{AlterantArgT}}}}(undef, n_act, n_slot), nothing),# args
        fill!(Matrix{Union{Nothing,Vector{UInt8}}}(undef, n_act, n_slot), nothing),               # decided_by
        fill!(Matrix{Union{Nothing,Vector{UInt8}}}(undef, n_act, n_slot), nothing),               # applied_to
    )
    return ProcessState(
        parse_state, config, registry, mh, queue,
        Dict{Int8,Any}(),            # working
        Dict{Int8,Vector{Vector{UInt8}}}(),   # working_origin
        EvalStore(),              # evals
        BLS.ComponentSettribute(),   # snapshot — FRESH (array copied-into, not aliased)
        Diagnostic[],                # diagnostics
        fileMHIdx, fileMHIdx, fileMHIdx,   # crnt_depth_idx / first_parent_idx / crnt_idx
        nothing,                     # meta_context — published per component at the walk handover
        nothing,                     # user_context — set only inside the feed routine's bracket
        Any[nothing for _ in 1:num_alterants(registry)],   # alt_run: every cell `nothing` until a hook mints one
    )
end

"""
    snapshot_settribute!(st, component) -> ComponentSettribute

IS: the refresh of the per-call settribute snapshot — the copy of one Component's settribute bytes into
`st.snapshot`.

DOES: copies `component.componentSettribute.array` INTO `st.snapshot.array` IN PLACE (`.=`) and returns
`st.snapshot`. The destination array is the per-call `snapshot`'s own array (copied into, never aliased), so a
second `goMeta` call starts from a fresh snapshot. Called at the walk → absorb handover (`applyAbsorbFn`,
src/absorb/walk.jl) for the current Component and at the two apply overloads (src/alterants/apply.jl — the Block
itself; a Segment's parent Line); read by the conditions' `getState` through `get_state`.

REASONING: a condition reads settribute flags through the snapshot rather than the Component, so the apply's state
lives in the per-call `ProcessState` and no module global is touched.

PURPOSE: what `getState(:key)` in a condition answers from.
"""
function snapshot_settribute!(st::ProcessState, component::T) where {T<:BLS.Component}
    st.snapshot.array[:] .= component.componentSettribute.array[:]
    return st.snapshot
end

"""
    get_state(snapshot, key) -> Bool

IS: the pure reader of one settribute flag from a settribute snapshot (the helper behind the de-globalized
`getState`).

DOES: returns `BLS.getElement(snapshot, key)` — the `Bool` at the key's position of the `ComponentSettribute`
record; the rewrite emits a `getState` call only for a declared key (`keys(BLS.ComponentSettribute)`, the settribute
keys). `get_state(ctx().snapshot, key)` is what the eval'd `getState(:key)` resolves to — the reader `CnS.getState`
(src/alterants/registry.jl) resolves through `ctx()`.

REASONING: the read is a pure function of a snapshot and a key, so the per-call state enters only at the one caller.

PURPOSE: the settribute read of a condition.
"""
get_state(snapshot::BLS.ComponentSettribute, key::Symbol) = BLS.getElement(snapshot, key)
