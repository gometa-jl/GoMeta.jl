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

# --- the v0.4 registration-record SLOTS (the Stage-A T1 schema extension) ---------------------------
# IS: the DECLARED data slots the v0.4 record carries (the architecture chapter's sec 2.a, slots
#     (1)–(10)): the per-action settribute mapping · the capture declaration · the presence-typed
#     explicit default · the render-plane data · the vocabulary slot · constraint rows · contributed
#     condition atoms · identity/contract/requires · sugar rows · the schema-versioned provenance
#     group + the RESERVED permissions manifest.
# DOES: defines the slot types with their closed enum sets; every slot is NOTHING/EMPTY-defaulted so a
#     record declared in the v0.3.2 shape still constructs (the additive-extension law: old records
#     admit; nothing is silently defaulted to a VALUE — absence stays mechanically distinguishable
#     from every declared value, the G-DEF disjointness law).
# REASONING: the engine's three measured clean planes (apply, interpreter, absorb dispatch) are
#     registry-DATA-driven; the dirty planes (capture, defaults, render, vocabulary, diagnostics) were
#     hard-coded per Alterant. Moving what those planes need INTO the record as data is the cure's
#     substrate: Core keeps schema knowledge, never a particular Alterant's content. At T1 the slots
#     are CARRIED, not consumed — their consumers land with the per-plane cures (T4–T10), each proving
#     its slot flows by the D6 mutation probe.
# PURPOSE: one record, extended never replaced, that a registration can declare completely.

"""
    DomainRef(artifact, digest)

A digest-pinned reference to an artifact OUTSIDE the record (a vocabulary file, an imported
label set): `artifact` = the artifact's declared coordinate (a path or a name the loader
resolves), `digest` = the ALGORITHM-TAGGED content digest of the bytes, `"sha256:<64 lowercase
hex>"` — per-file SHA-256, tag in the value (the survey's discipline: a digest without its
algorithm is not comparable). The constructor refuses any other form LOUDLY (a mis-shaped pin
would otherwise register silently and never verify). Verification against the artifact's bytes
is the loader's act (typed `SRC_DIGEST_MISMATCH` at the confined loader places), never this
constructor's.
"""
struct DomainRef
    artifact::String
    digest::String
    function DomainRef(artifact::AbstractString, digest::AbstractString)
        occursin(r"^sha256:[0-9a-f]{64}$", digest) ||
            error("GoMeta registry: DomainRef digest ", repr(first(String(digest), 80)),
                " is not algorithm-tagged — the required form is \"sha256:<64 lowercase hex>\" ",
                "(the record shape law)")
        new(String(artifact), String(digest))
    end
end

## Slot (2): the capture declaration — HOW an Alterant's applied value becomes evals rows.
const _CAPTURE_SCHEMES        = (:per_key, :single, :per_field, :per_occurrence)
const _CAPTURE_MULTIPLICITIES = (:many, :one, :per_field)
"""
    CaptureDecl(instance_type, attr_scheme, multiplicity, mode_gate)

The declared capture row: `instance_type` = the Alterant instance type the capture walk keys on
(DECLARED, so the walk never hard-codes a store type); `attr_scheme` ∈ `(:per_key, :single,
:per_field, :per_occurrence)` = how attr names mint (`label_<key>` per set key · one `visib`-style
row · `id_<field>` per non-default field · one row per occurrence handle); `multiplicity` ∈
`(:many, :one, :per_field)`; `mode_gate` = the set mode that gates delivery (`:localOnly` for the
occurrence-keyed absorb-seam capture) or `nothing`.
"""
struct CaptureDecl
    instance_type::Type
    attr_scheme::Symbol
    multiplicity::Symbol
    mode_gate::Union{Nothing,Symbol}
end

## Slot (3): the presence-typed explicit default — undeclared is a TYPE, never a sentinel value.
"The explicit-default slot's abstract root: `NoDefault()` (undeclared) | `Declared(v)`."
abstract type DefaultSlot end
"The UNDECLARED default — mechanically distinct from every declared value (the G-DEF disjointness law)."
struct NoDefault <: DefaultSlot end
"A DECLARED default value for an action; `value` is the Alterant's own datum, Core never interprets it."
struct Declared{T} <: DefaultSlot
    value::T
end

## Slot (4): render-plane data — effect rows + declared resolve order + the materialize flag.
const _EFFECT_ROW_KINDS = (:drop, :mark, :pass)
"""
    EffectRow(kind, payload)

One render effect: `kind` ∈ `(:drop, :mark, :pass)` — the content is dropped from the render ·
marked (the writer-side marker rides `payload`, an opaque per-flavor datum Core never indexes —
the record-carried carriage) · passed through. `payload` is `nothing` unless `kind === :mark`.
"""
struct EffectRow
    kind::Symbol
    payload::Any
end
"""
    RenderDecl(effects, resolve_order, materialize)

The render-plane declaration: `effects` = action → `EffectRow` pairs in declaration order;
`resolve_order` = the declared grain resolve order (e.g. `[:Line, :Block]` — the Line-over-Block
arm) or `nothing`; `materialize` = whether the resolved verdict is written back into the
component's settribute (the generic write-back gate).
"""
struct RenderDecl
    effects::Vector{Pair{Symbol,EffectRow}}
    resolve_order::Union{Nothing,Vector{Symbol}}
    materialize::Bool
end

## Slot (5): the vocabulary slot — inline names+flags, or a digest-pinned artifact reference.
"The vocabulary slot's abstract root: `InlineVocabulary` | `VocabularyRef`."
abstract type VocabularySlot end
"""
    InlineVocabulary(names, flags)

An inline closed vocabulary: `names` (Symbol, byte-exact), `flags` per name — `(query = Bool,)`
(`query = false` = a write-only name the query plane refuses: the sized valve, declared and
disclosed rather than discovered).
"""
struct InlineVocabulary <: VocabularySlot
    names::Vector{Symbol}
    flags::Dict{Symbol,NamedTuple{(:query,),Tuple{Bool}}}
end
"""
    VocabularyRef(ref)

A vocabulary owned OUTSIDE Core: the `DomainRef` to the artifact that carries the names AND
their per-name flags (content custody stays the Alterant's; the digest is ENFORCED at load).
"""
struct VocabularyRef <: VocabularySlot
    ref::DomainRef
end

## Slot (6): constraint rows — compiled at publication into both refusal planes.
"A mutual-exclusion constraint over the named actions (one applied value among them per unit)."
struct MutEx
    actions::Vector{Symbol}
end

## Slot (7): contributed condition atoms — NAME-addressed, never order-addressed.
"""
    ConditionAtom(name, print_spelling, evaluate)

A condition atom the Alterant contributes: looked up BY NAME (the registration-order class of
defect cannot arise), printed with its declared `print_spelling`, evaluated by `evaluate` (an
Alterant callable) or `nothing` for a state-only atom.
"""
struct ConditionAtom
    name::Symbol
    print_spelling::String
    evaluate::Union{Nothing,Function}
end

## Slot (9): sugar rows — a surface pattern lowering to an action, mode-gated.
"A declared sugar row: surface `pattern` → `action`, delivered only under `mode_gate` (or always)."
struct SugarRow
    pattern::Symbol
    action::Symbol
    mode_gate::Union{Nothing,Symbol}
end

## Slot (10): the schema-versioned PROVENANCE group + the RESERVED permissions manifest.
const _ACQUISITION_MODES = (:shipped, :pinned_by_user, :first_use)
"""
    SignatureRecord(; algorithm, key_id, signature)

RESERVED (Rung 2): a signature over the package digest — fields nothing-defaulted; verification
is a LATER feature (keys pinned at config); the record only carries the declaration room.
"""
struct SignatureRecord
    algorithm::Union{Nothing,String}
    key_id::Union{Nothing,String}
    signature::Union{Nothing,String}
end
SignatureRecord(; algorithm = nothing, key_id = nothing, signature = nothing) =
    SignatureRecord(algorithm, key_id, signature)
"""
    PermissionManifest(; seam, ambient)

RESERVED (Rung 2): DECLARED permissions — `seam` rows (the registration-surface capability
vocabulary) and `ambient` rows (`:file_read`-class ambient authority). Declarations are
displayed and diffed, NEVER enforced in-process (the honest bound: no in-process arrangement
confines a loaded module).
"""
struct PermissionManifest
    seam::Vector{Symbol}
    ambient::Vector{Symbol}
end
PermissionManifest(; seam = Symbol[], ambient = Symbol[]) = PermissionManifest(seam, ambient)
"""
    Provenance(; sec_schema = v"1.0.0", sources = DomainRef[], policy_id = nothing, …)

The schema-versioned provenance group (the security frame's field UNION, all additive, all
nothing/empty-defaulted — the ONE non-nothing member is `sec_schema`, the group's own schema
version, so later rungs land as versioned additions never breaks). Live at v0.4.0 (Rung 0):
`sources` (the per-source `DomainRef` pins, digest-ENFORCED for label-set imports) and
`policy_id` (the vocabulary-policy identity the publication mints). RESERVED, records-not-
enforces: `package_digest` · `artifact_manifest` · `signatures` + `signer` · `source_identity`
(a non-name coordinate) · `acquisition_mode` ∈ `(:shipped, :pinned_by_user, :first_use)` ·
`artifact_version` · `not_before` · `load_act` (the resolved coordinate + digest as loaded) ·
`declared_capabilities` (displayed, diffed, never enforced).
"""
struct Provenance
    sec_schema::VersionNumber
    sources::Vector{DomainRef}
    policy_id::Union{Nothing,String}
    package_digest::Union{Nothing,String}
    artifact_manifest::Union{Nothing,String}
    signatures::Vector{SignatureRecord}
    signer::Union{Nothing,String}
    source_identity::Union{Nothing,String}
    acquisition_mode::Union{Nothing,Symbol}
    artifact_version::Union{Nothing,VersionNumber}
    not_before::Union{Nothing,String}
    load_act::Union{Nothing,String}
    declared_capabilities::Vector{Symbol}
end
Provenance(; sec_schema = v"1.0.0", sources = DomainRef[], policy_id = nothing,
             package_digest = nothing, artifact_manifest = nothing,
             signatures = SignatureRecord[], signer = nothing, source_identity = nothing,
             acquisition_mode = nothing, artifact_version = nothing, not_before = nothing,
             load_act = nothing, declared_capabilities = Symbol[]) =
    Provenance(sec_schema, sources, policy_id, package_digest, artifact_manifest, signatures,
               signer, source_identity, acquisition_mode, artifact_version, not_before,
               load_act, declared_capabilities)

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
    # --- the v0.4 declared slots (T1; all nothing/empty-defaulted; carried at T1, consumed T4–T10) ---
    capture::Union{Nothing,CaptureDecl}            # slot (2): the capture declaration
    render::Union{Nothing,RenderDecl}              # slot (4): render-plane data
    vocabulary::Union{Nothing,VocabularySlot}      # slot (5): inline table or a DomainRef artifact
    constraints::Vector{MutEx}                     # slot (6): constraint rows
    atoms::Vector{ConditionAtom}                   # slot (7): contributed condition atoms, name-addressed
    contract_version::Union{Nothing,VersionNumber} # slot (8): the contract version the record targets
    requires::Tuple{Vararg{Symbol}}                # slot (8): required capabilities — any uninterpreted
                                                   #   token refuses WHOLE-record at the gate (T2)
    sugar::Vector{SugarRow}                        # slot (9): sugar rows (surface pattern → action)
    provenance::Provenance                         # slot (10): the schema-versioned provenance group
    permissions::Union{Nothing,PermissionManifest} # slot (10): RESERVED permissions (Rung 2, inert)
end
"The v0.3.2 positional shape still constructs — the additive-extension law (old records admit)."
PlugIn(altName::Symbol, setMode::Symbol, altConstructor::Type, setAltInstance::Function,
       getAltInstance::Union{Nothing,Function},
       precedencesTuple::Union{Nothing,NTuple{NUM_MH_LEVELS,Symbol}}) =
    PlugIn(altName, setMode, altConstructor, setAltInstance, getAltInstance, precedencesTuple,
           nothing, nothing, nothing, MutEx[], ConditionAtom[], nothing, (), SugarRow[],
           Provenance(), nothing)
"The keyword form: every v0.4 slot addressable by name; unnamed slots take their nothing/empty default."
PlugIn(; altName::Symbol, setMode::Symbol, altConstructor::Type, setAltInstance::Function,
         getAltInstance::Union{Nothing,Function} = nothing,
         precedencesTuple::Union{Nothing,NTuple{NUM_MH_LEVELS,Symbol}} = nothing,
         capture = nothing, render = nothing, vocabulary = nothing,
         constraints = MutEx[], atoms = ConditionAtom[], contract_version = nothing,
         requires::Tuple{Vararg{Symbol}} = (), sugar = SugarRow[],
         provenance::Provenance = Provenance(), permissions = nothing) =
    PlugIn(altName, setMode, altConstructor, setAltInstance, getAltInstance, precedencesTuple,
           capture, render, vocabulary, constraints, atoms, contract_version, requires, sugar,
           provenance, permissions)

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
    # --- the v0.4 declared per-action slots (T1) ---
    default::DefaultSlot              # slot (3): the explicit default — `NoDefault()` = undeclared
    settribute::Union{Nothing,Symbol} # slot (1): the settribute key this action's applied verdict
                                      #   writes back to (`nothing` = no write-back); the registry's
                                      #   generic `action_to_settribute` table is DERIVED from these
end
"The v0.3.2 positional shape still constructs (default `NoDefault()`, no write-back key)."
ActionSpec(name::Symbol, spelling::Symbol, plugin::Int8, overloads::Vector{ActionOverload},
           accepts_string_slot::Int, sugar_candidacy::Symbol, validate::Union{Nothing,Function},
           keyed_slot::Union{Nothing,Tuple{Symbol,Symbol}}) =
    ActionSpec(name, spelling, plugin, overloads, accepts_string_slot, sugar_candidacy, validate,
               keyed_slot, NoDefault(), nothing)
"The keyword form of the per-action record."
ActionSpec(; name::Symbol, spelling::Symbol, plugin::Int8, overloads::Vector{ActionOverload},
             accepts_string_slot::Int = 0, sugar_candidacy::Symbol = :none, validate = nothing,
             keyed_slot = nothing, default::DefaultSlot = NoDefault(), settribute = nothing) =
    ActionSpec(name, spelling, plugin, overloads, accepts_string_slot, sugar_candidacy, validate,
               keyed_slot, default, settribute)

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
- `action_to_settribute` — the GENERIC action → `ComponentSettribute`-key write-back table, DERIVED
  from the declared per-action `settribute` slots (v0.4 T1; formerly the Alterant-named
  `visib_to_settribute` — the rename is a registered breaking change with no forwarding window).

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
    action_to_settribute::Dict{Symbol,Symbol}   # v0.4 T1: generic, derived from declarations
    # v0.2 registration build: the DECLARED registration record — one ActionSpec per
    # registered action, DECLARATION order (the parallel derived tables above stay
    # the hot-path lookups; the record is the authority the cross-check verified).
    # `spec_index`: action name → index into `action_specs`.
    action_specs::Vector{ActionSpec}
    spec_index::Dict{Symbol,Int}
    # v0.4 T2 — THE SEAL (HC-9): minted ONLY by `publish`; `nothing` = an UNPUBLISHED value (the
    # gated route-U construction), which the `goMeta` door refuses typed. The seal is the
    # algorithm-tagged registration digest over every declared slot + the declared source digests
    # + policy_id; the door recomputes it — a post-publication mutation of any container fires
    # `POST_SEAL_MUTATION` (accident-grade integrity, never security-grade).
    seal::Union{Nothing,String}
end
"""
    AlterantRegistry(plugins, sorted_alt_actions, action_to_plugin, action_index, alt_index,
                     accum_alt_idxs, mutex_alt_idxs, action_to_settribute, action_specs, spec_index)

ROUTE U — positional construction from hand-built tables — is GATED at v0.4.0 (the route-U cure:
every public construction route runs the ONE validation chain; removal = v0.5): the full chain runs
over `(plugins, action_specs)` AND the hand-built derived tables must equal the tables derived from
the declarations (`REG_DERIVED_TABLES`); any error-severity defect throws `RegistrationRefused`
with EVERY collected diagnostic. A conforming construction yields an UNSEALED registry (`seal ===
nothing`) — the `goMeta` door refuses it typed, naming the sanctioned path (`RegistryBuilder →
validate → publish`); route U therefore dies at the entry too (R-V04-34's STRICT door).
"""
function AlterantRegistry(plugins::Vector{PlugIn}, sorted_alt_actions::Vector{Symbol},
                          action_to_plugin::Vector{Int8}, action_index::Dict{Symbol,Int8},
                          alt_index::Dict{Symbol,Int8}, accum_alt_idxs::Vector{Int8},
                          mutex_alt_idxs::Vector{Int8}, action_to_settribute::Dict{Symbol,Symbol},
                          action_specs::Vector{ActionSpec}, spec_index::Dict{Symbol,Int})
    diags = _validate_registration(plugins, action_specs)
    if !any(d -> d.severity === :error, diags)
        derived = _derive_tables(plugins, action_specs)
        derived.sorted_alt_actions == sorted_alt_actions &&
            derived.action_to_plugin == action_to_plugin &&
            derived.action_index == action_index &&
            derived.alt_index == alt_index &&
            derived.accum_alt_idxs == accum_alt_idxs &&
            derived.mutex_alt_idxs == mutex_alt_idxs &&
            derived.action_to_settribute == action_to_settribute &&
            derived.spec_index == spec_index ||
            push!(diags, Diagnostic(:REG_DERIVED_TABLES, :error,
                "GoMeta registry: positional construction supplied derived tables that do not " *
                "match the tables derived from the declared record (route U is GATED at v0.4.0; " *
                "build via RegistryBuilder → validate → publish)"))
    end
    any(d -> d.severity === :error, diags) && throw(RegistrationRefused(diags))
    return AlterantRegistry(plugins, sorted_alt_actions, action_to_plugin, action_index, alt_index,
                            accum_alt_idxs, mutex_alt_idxs, action_to_settribute, action_specs,
                            spec_index, nothing)
end
"""
    _unchecked_registry(plugins, …, spec_index) -> AlterantRegistry   (INTERNAL, test seam)

Constructs an UNSEALED registry with NO validation — the ONE bypass, kept so the runtime walls
downstream of registration (the `_invoke_set` return/drift guards) can be witnessed on DELIBERATELY
drifted shapes the gated routes refuse by design. Never `public`, never a consumer route; the door
refuses its values like any unsealed one.
"""
_unchecked_registry(plugins::Vector{PlugIn}, sorted_alt_actions::Vector{Symbol},
                    action_to_plugin::Vector{Int8}, action_index::Dict{Symbol,Int8},
                    alt_index::Dict{Symbol,Int8}, accum_alt_idxs::Vector{Int8},
                    mutex_alt_idxs::Vector{Int8}, action_to_settribute::Dict{Symbol,Symbol},
                    action_specs::Vector{ActionSpec}, spec_index::Dict{Symbol,Int}) =
    AlterantRegistry(plugins, sorted_alt_actions, action_to_plugin, action_index, alt_index,
                     accum_alt_idxs, mutex_alt_idxs, action_to_settribute, action_specs,
                     spec_index, nothing)
"The number of registered alterants (4 since CH-3 step 9; 3 before the heading registration)."
num_alterants(r::AlterantRegistry) = length(r.plugins)

# --- the v0.4 registration LIFECYCLE types (T2): Builder → validated → PUBLISHED ------------------
"""
    RegistryBuilder()

The MUTABLE declaration site of a registry: `register!(builder, plugin, specs...)` appends an
Alterant registration record + its action records in declaration order. Nothing is checked at
registration time — `validate(builder)` collects EVERY defect as typed diagnostics (full collection
before the one terminal outcome), and `publish(builder)` refuses on any error, else COPIES every
container into an immutable, SEALED `AlterantRegistry` (the only route that mints a seal).
"""
mutable struct RegistryBuilder
    plugins::Vector{PlugIn}
    action_specs::Vector{ActionSpec}
end
RegistryBuilder() = RegistryBuilder(PlugIn[], ActionSpec[])
"Append one Alterant registration record + its action records (declaration order = plugin index)."
function register!(b::RegistryBuilder, plugin::PlugIn, specs::ActionSpec...)
    push!(b.plugins, plugin)
    append!(b.action_specs, collect(specs))
    return b
end

"""
    RegistrationRefused(diagnostics)

The typed refusal of a registration: thrown by `publish` (and by the gated positional route) with
EVERY collected error/warning diagnostic — never the first one only. Catch it, read
`.diagnostics` (stable `code`s), fix the record, re-validate.
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
