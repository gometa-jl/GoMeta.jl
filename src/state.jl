# src/state.jl — the per-call engine state, the immutable alterant registry, and the typed delivered object.
#
# IS: the state vocabulary of the GoMeta engine — the per-call `ProcessState` (delivered through a
#     `ScopedValue`, never held in a global), the immutable `AlterantRegistry` type behind
#     `DEFAULT_REGISTRY`, the meta-hierarchy and alterant-queue sub-states, the `PlugIn` inventory
#     unit, the public `GoMetaDelivery` (docs/public-api.md §1.1), and the `init_state` constructor that
#     sizes every container fresh for each call.
# DOES: declares `ConditionT` (the condition-representation alias: the closed interpreter's
#     bounded `ConditionAST`, plus the `FullEvalCondition` marker only the opt-in
#     `:full_eval_v1` extension can mint — README SECURITY; docs/public-api.md §3.2); the
#     meta-hierarchy level layout
#     (`NUM_MH_LEVELS = 12`: the file level, the depth window `1..maxDepthMH`, then the user / line /
#     fallBack levels — the user level is the reserved slot that `GoMetaConfig.user_mh_profile`
#     seeds; docs/public-api.md §2); `PlugIn`; `AlterantRegistry` with
#     `num_alterants` / `num_alt_actions` (4 alterants / 8 actions since the heading registration,
#     incl. the generic action → settribute write-back table); `MetaHierarchyState`; `AlterantQueue`;
#     `ProcessState`; `GoMetaDelivery`; the `STATE` ScopedValue + `ctx()`; `init_state`;
#     `snapshot_settribute!`; `get_state`; the v0.4 record SLOTS + the registration LIFECYCLE types.
# REASONING: every mutable container lives in one per-call `ProcessState`, so two concurrent
#     `goMeta` calls never share state. Conditions eval'd at apply time read it through a
#     `ScopedValue`; an unscoped read throws.
# Honest edges: `AlterantRegistry`'s `Dict`/`Vector` fields are mutable containers — a PUBLISHED
#     registry is sealed, not frozen by type: a mutation through any container (declared record,
#     derived table, callable identity or the fingerprint) BY CONFORMING CODE is DETECTED at the
#     entry door (`POST_SEAL_MUTATION`, v0.4 T2-bis — the ONE structural deep-egal comparison
#     against the publish-time `_snapshot` baseline, `===`-only leaves, firing at the first
#     divergent path), never silently effective — accident-grade, within the disclosed bounds
#     (callable behavior ≠ identity; the snapshot's own members are mutable — the mixed B-2
#     residue; the entry check is not a lock; docs/public-api.md §1.2's honest-bound block);
#     the construction capability is token-gated so no POSITIONAL or accidental construction by
#     conforming code carries a seal (accident-grade: any loaded module can reach the token — B-2);
#     `accum_alt_idxs` must stay sorted
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

"The unified meta-hierarchy level count (`= maxDepthMH + 3 = fallBackMHIdx`): the file level, the
authorable depth window, and the user / line / fallBack levels — 12 at v0. The level formerly named 'default'
is `fallBack` since stage 2's commit 3 (his word, R-V04B-55 (3)): the word 'default' is the Alterant's declared VALUE."
const NUM_MH_LEVELS = 12

const maxDepthMH = length(BLS.depthLevelsMH)   # 9 — `depthLevelsMH` incl. `:depth0`
@assert maxDepthMH + 3 == NUM_MH_LEVELS "NUM_MH_LEVELS ($NUM_MH_LEVELS) must equal maxDepthMH+3 ($(maxDepthMH+3)) — the meta-hierarchy sizing invariant"

"The meta-hierarchy index layout: the file level, the depth window `1..maxDepthMH`,
then the user / line / fallBack levels (`fallBackMHIdx == NUM_MH_LEVELS`) — the fallBack level is consulted LAST by
the apply (R-V04B-55 (3); his §196 (iv)); today no feed occupies it (the `metaLevel` Alterant comes after the branch)."
const fileMHIdx    = 1
const userMHIdx    = maxDepthMH + 1   # 10
const lineMHIdx    = maxDepthMH + 2   # 11
const fallBackMHIdx = maxDepthMH + 3   # 12 == NUM_MH_LEVELS — the fallBack level (R-V04B-55 (3)), consulted LAST by the apply

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
        # (the crx-t3t4s A1 cure) each input is READ ONCE — validating the supplied
        # AbstractString and converting it SEPARATELY for storage let a stateful
        # user string validate one content and store another (a stored digest could
        # then violate the anchored grammar). The converted `d` is what the regex
        # sees AND what `new` stores.
        a = String(artifact)
        d = String(digest)
        occursin(r"\Asha256:[0-9a-f]{64}\z", d) ||   # absolute anchors: `$` would admit a trailing newline (cure batch 3)
            error("GoMeta registry: DomainRef digest ", repr(first(d, 80)),
                " is not algorithm-tagged — the required form is \"sha256:<64 lowercase hex>\" ",
                "(the record shape law)")
        new(a, d)
    end
end

## Slot (2): the capture declaration — HOW an Alterant's applied value becomes evals rows.
const _CAPTURE_MODE_GATES = (nothing, :localOnly)   # v0.4 T5: the closed gate set (the scheme and multiplicity sets left with their enum checks at stage 5's E4)
"""
    CaptureDecl(instance_type, attr_scheme, multiplicity, mode_gate[, attr_stem]; attr_stem = nothing)

IS: the declared capture row of an Alterant — slot (2) of its registration record: HOW the Alterant's applied
value becomes evals rows.

DOES: The declared capture row (CONSUMED by the capture walk since v0.4 T5 — the registration-
driven re-home of the retired alt-name ladder): `instance_type` = the Alterant instance
type the walk keys on (the identity law that required it `===` the record's own `altConstructor` left at
stage 5's E4; a mismatch floors `WARN_CAPTURE_UNREADABLE` at the walk);
`attr_scheme` ∈ `(:per_key, :single, :per_field, :per_occurrence)` = how attr names mint
(`<stem>_<key>` per admitted Dict entry · one `<stem>` row for a NamedElements-shaped
single evals row · `<stem>_<field>` per non-default numeric field · one presence row per
occurrence handle); `multiplicity` ∈ `(:many, :one, :per_field)` (CARRIED at v0.4 —
its consumer is the T11 catalogue); `mode_gate` ∈ `(nothing, :localOnly)` — `:localOnly`
delivers at the absorb seam keyed to the carrying Component's occurrence handle (the metaBlock
a whole-line metaLine forms — R-V04B-50; the Segment of an inline one), and tier 1
enforces the BIDIRECTIONAL coherence with the record's `setMode`; `attr_stem` = the
declared attr name stem (`nothing` ⇒ the derived fallback `lowercase(String(altName))`
— the shipped four DECLARE theirs explicitly; byte-compatibility never rides a
derivation). A PLAIN 5-field struct — NO inner constructor that changes the positional
signature (the domain copier rebuilds slot structs POSITIONALLY over all fields at the
exact concrete type, src/alterants/registry.jl; an inner ctor of another arity would
break the rebuild of `DEFAULT_REGISTRY`) — with ONE outer compatibility method (the
PlugIn precedent below).

REASONING: the capture walk is registration-driven (v0.4 T5) — keyed on the declared instance type, never an
alt-name ladder — and the struct is plain (no inner constructor) because the domain copier rebuilds
slot structs positionally.

PURPOSE: the row `captureEvals!` reads to mint an Alterant's evals rows, and the row tier 1 validates for
coherence with the record's `setMode`.
"""
struct CaptureDecl
    instance_type::Type
    attr_scheme::Symbol
    multiplicity::Symbol
    mode_gate::Union{Nothing,Symbol}
    attr_stem::Union{Nothing,Symbol}    # v0.4 T5 (additive; LAST — the positional law)
end
CaptureDecl(instance_type::Type, attr_scheme::Symbol, multiplicity::Symbol,
            mode_gate::Union{Nothing,Symbol};
            attr_stem::Union{Nothing,Symbol} = nothing) =
    CaptureDecl(instance_type, attr_scheme, multiplicity, mode_gate, attr_stem)

## Slot (3): the presence-typed explicit default — undeclared is a TYPE, never a sentinel value. Since stage 2's
## commit 3 the slot is the ALTERANT's (one default per Alterant, declared as data — R-V04B-51 (1)–(2); R-V04B-55 (1));
## the per-action slot of T1 GAVE WAY at commit 3-ii (a clean cut, R-V04B-61).
"The explicit-default slot's abstract root: `NoDefault()` (undeclared) | `Declared(v)`."
abstract type DefaultSlot end
"The UNDECLARED default — mechanically distinct from every declared value (the G-DEF disjointness law)."
struct NoDefault <: DefaultSlot end
"A DECLARED default value — an Alterant's since stage 2's commit 3 (R-V04B-51 (1)); `value` is the Alterant's own datum, Core never interprets it."
struct Declared{T} <: DefaultSlot
    value::T
end

## Slot (4): render-plane data — effect rows + declared resolve order + the materialize flag.
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

IS: the render-plane declaration of an Alterant — its declared effects per action, its grain resolve order, and
whether the resolved value is written back into the component's settribute.

DOES: The render-plane declaration: `effects` = action → `EffectRow` pairs in declaration order;
`resolve_order` = the declared grain resolve order (e.g. `[:Line, :Block]` — the Line-over-Block
arm) or `nothing`; `materialize` = whether the resolved value is written back into the
component's settribute (the generic write-back gate).

REASONING: the render-plane data travel in the record as declarations rather than hard-wired per Alterant; at T1 the
slot is CARRIED, not consumed (the record's law above): no plane reads `materialize` — only the seal's text form encodes
it (`_slot_text`, `alterants/registry.jl`); the apply's write-back table `action_to_settribute` is derived from
`ActionSpec.settribute` (`alterants/registry.jl`), and the built-in Visib declares no `RenderDecl` (`render` defaults to `nothing`).

PURPOSE: the declaration a render-plane consumer would read — read by no plane today; the declarations stay until the
owner's word (R-V04B-42 (2); the census before stage 5) — the Visib write-back it would gate is removed at stage 3 (R-V04B-42).
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

## Slot (6): constraint rows — VALIDATED (ownership + shape) and SEALED at publication (T2); their
## compilation into the two refusal planes lands with the planes' cures (T5 capture / T6 render).
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
    Alterant

The registration-record type for one alterant — RENAMED from `PlugIn` at v0.4 (R-V04B-5);
`const PlugIn = Alterant` is a PUBLIC deprecation alias for the whole 0.4.x family (both
names `public`; the record's FIELD NAMES are NOT renamed at v0.4 — keyword constructors
are public; alias removal + field-name normalization = v0.5).

The inventory unit for one alterant (`Labels` / `Visib` / `Id` / `Heading`): its name, set-mode
(`:accumulate` — the inheritance backtrack COLLECTS every applicable value · `:mutExclusive` — the
backtrack stops at the FIRST applicable value · `:mutExclusivePerField` — the `Id` compound; the per-FIELD
first-wins semantics its name promises are DEFERRED (the registry's note: the mode sits in neither set-mode table by
design) — at v0.4 the nearest statement sets the compound as a WHOLE (an unset field is not inherited from an outer
slot) and within one slot the LAST row of a field wins (MEASURED at stage 2's commit 7, `tests/authored/006_id_compound.toml`
a draft put to the owner; card 8 "next"; the CrossReview set REAL-1 R1 #1 — the contract narrowed, no Engine change)
· `:localOnly` — the value applies ONCE, where it stands: never enqueued, never visited by
the backtrack, delivered at the absorb seam), the alterant-instance constructor type, the setter/getter, the (always-`nothing` at
v0) precedence tuple and — since stage 2's commit 3 — the Alterant's ONE declared default value (`default`,
R-V04B-51 (1)–(2): Visib's is `:show`; delivered by the answer function with the source "default"). A fixed-size-array-free inventory unit, built into the registry by
`build_default_registry`. `precedencesTuple` is sized by `NUM_MH_LEVELS`,
the unified meta-hierarchy level count.
"""
struct Alterant
    altName::Symbol
    setMode::Symbol
    altConstructor::Type
    setAltInstance::Function
    getAltInstance::Union{Nothing,Function}
    precedencesTuple::Union{Nothing,NTuple{NUM_MH_LEVELS,Symbol}}
    default::DefaultSlot                           # slot (3) at the ALTERANT: its ONE declared default value (R-V04B-51 (1)–(2);
                                                   #   R-V04B-55 (1)) — `NoDefault()` undeclared | `Declared(v)`; stage 2's commit 3;
                                                   #   delivered by the answer function with the source "default" (R-V04B-55 (2)) —
                                                   #   Visib declares `:show`; Labels, Heading and Id await the owner's word
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
"The PUBLIC deprecation alias of the v0.4 `PlugIn` → `Alterant` rename (R-V04B-5) — stands
for the whole 0.4.x family; removal = v0.5 (register row V05-3)."
const PlugIn = Alterant
"The v0.3.2 positional shape still constructs — the additive-extension law (old records admit)."
PlugIn(altName::Symbol, setMode::Symbol, altConstructor::Type, setAltInstance::Function,
       getAltInstance::Union{Nothing,Function},
       precedencesTuple::Union{Nothing,NTuple{NUM_MH_LEVELS,Symbol}}) =
    PlugIn(altName, setMode, altConstructor, setAltInstance, getAltInstance, precedencesTuple,
           NoDefault(), nothing, nothing, nothing, MutEx[], ConditionAtom[], nothing, (), SugarRow[],
           Provenance(), nothing)
"The keyword form: every v0.4 slot addressable by name; unnamed slots take their nothing/empty default."
PlugIn(; altName::Symbol, setMode::Symbol, altConstructor::Type, setAltInstance::Function,
         getAltInstance::Union{Nothing,Function} = nothing,
         precedencesTuple::Union{Nothing,NTuple{NUM_MH_LEVELS,Symbol}} = nothing,
         default::DefaultSlot = NoDefault(),
         capture = nothing, render = nothing, vocabulary = nothing,
         constraints = MutEx[], atoms = ConditionAtom[], contract_version = nothing,
         requires::Tuple{Vararg{Symbol}} = (), sugar = SugarRow[],
         provenance::Provenance = Provenance(), permissions = nothing) =
    PlugIn(altName, setMode, altConstructor, setAltInstance, getAltInstance, precedencesTuple,
           default, capture, render, vocabulary, constraints, atoms, contract_version, requires, sugar,
           provenance, permissions)

"""
    ActionOverload

IS: ONE row of the DECLARED registration record — a per-overload declaration of an action's method signature,
literal kinds, return type, effect, queryability, applicability and phase.

DOES: ONE row of the DECLARED registration record (v0.2 registration build, the reflection-memo
bindings): a per-overload declaration of the action's method signature, stated by the
author (the registration-time reflection cross-check that verified it against the executable
method table left at stage 5's E4).
Fields: `sig_types` — the method signature's argument types AFTER the function
type (store · action name · literal slots), stated as the METHOD declares them;
`kinds` — the GRAMMAR-level literal kind per literal slot (`:symbol` | `:string`;
structural slots excluded), parallel to the literal tail of `sig_types`;
`kind_sources` — `:declared` | `:reflected` per kind (the memo's shrinking-surface
tag: `:reflected` where the signature slot is typed enough to carry the kind);
`vararg_kind` — a trailing `Vararg` literal kind or `nothing`; `return_type` — the
DECLARED return type (never compiler inference — the ad-2/ad-5 determinism law;
the live seam's return-type guard reads it); `effect` (`:set` — the v0.2 closed
effect set); `queryable`; `applicability` (`:context_free` | `:context_required`);
`phase` (`:apply` | `:absorb` — mode-derived, the localOnly delta); `grammar` —
`false` marks an INTERNAL row (the probe-surfaced inherited shapes, declared for the
implemented-but-undeclared diagnostic of the time — the reflection cross-check left at stage 5's E4).

REASONING: the record is a declaration a reader can check — stated by the author, never derived from the
compiler (the determinism law).

PURPOSE: the row the grammar, the domain probe and the live seam's return-type guard read.
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
"The keyword form (v0.4 T2, cure batch 2 — the documented defaults exist): only `sig_types` is required."
ActionOverload(; sig_types::Vector{Type}, kinds::Vector{Symbol} = Symbol[],
                 kind_sources::Vector{Symbol} = Symbol[:declared for _ in kinds],
                 vararg_kind = nothing, return_type::Type = Nothing, effect::Symbol = :set,
                 queryable::Bool = false, applicability::Symbol = :context_free,
                 phase::Symbol = :apply, grammar::Bool = true) =
    ActionOverload(sig_types, kinds, kind_sources, vararg_kind, return_type, effect, queryable,
                   applicability, phase, grammar)

"""
    ActionSpec

The DECLARED per-action registration record: action `name` + `spelling` tag
(`:identifier` | `:operator` — a CLOSED spelling inventory; the hyphen class can never
mint; the collision checks over both kinds left at stage 5's E4) + the owning
`plugin` index + the per-overload rows + the CAPABILITIES (`accepts_string_slot`
— 0 = no String literal slot; N = the accepting literal-slot position, retiring
the former name literals at the absorb seams) + `sugar_candidacy` (`:none` |
`:activated` — the grant register, CLOSED AT TWO grants: the Labels colon + the
quoted-first heading; a `:candidate` registers unchecked since stage 5's E4 — the
unactivated-candidacy diagnostic left) + the `validate` slot (Alterant-owned handover
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
    # --- the v0.4 declared per-action slot (T1; the per-action default of T1 GAVE WAY to the Alterant's at stage 2's commit 3-ii) ---
    settribute::Union{Nothing,Symbol} # slot (1): the settribute key this action's applied value
                                      #   writes back to (`nothing` = no write-back); the registry's
                                      #   generic `action_to_settribute` table is DERIVED from these
end
"The v0.3.2 positional shape still constructs (no write-back key)."
ActionSpec(name::Symbol, spelling::Symbol, plugin::Int8, overloads::Vector{ActionOverload},
           accepts_string_slot::Int, sugar_candidacy::Symbol, validate::Union{Nothing,Function},
           keyed_slot::Union{Nothing,Tuple{Symbol,Symbol}}) =
    ActionSpec(name, spelling, plugin, overloads, accepts_string_slot, sugar_candidacy, validate,
               keyed_slot, nothing)
"The keyword form of the per-action record."
ActionSpec(; name::Symbol, spelling::Symbol, plugin::Int8, overloads::Vector{ActionOverload},
             accepts_string_slot::Int = 0, sugar_candidacy::Symbol = :none, validate = nothing,
             keyed_slot = nothing, settribute = nothing) =
    ActionSpec(name, spelling, plugin, overloads, accepts_string_slot, sugar_candidacy, validate,
               keyed_slot, settribute)

"""
    _SealToken

The construction capability of `AlterantRegistry` (never `public`), held by the lifecycle. It
suppresses the generated all-fields constructor (no positional form carries a seal) — an
ACCIDENT-grade guard: Julia has no access control, so any loaded module can call
`GoMeta._SealToken()`; such a caller sits outside the trust model (the security frame's bound
B-2). See the constructor's note.
"""
struct _SealToken end

"""
    _SNAPSHOT_FIELDS

The registry fields the T2-bis snapshot door walks (T2BIS-DESIGN §1): the declared record
(`plugins`, `action_specs`) + the eight derived tables + the published `seal` fingerprint
string. The `_snapshot` field itself is NEVER walked (no recursion into the baseline). A
seal-only divergence fires at path `seal` — what the retired re-mint used to catch.
"""
const _SNAPSHOT_FIELDS = (:plugins, :sorted_alt_actions, :action_to_plugin, :action_index,
                          :alt_index, :accum_alt_idxs, :mutex_alt_idxs, :action_to_settribute,
                          :action_specs, :spec_index, :seal)

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
    # the hot-path lookups; the record is the authority — the author's statement since stage 5's E4).
    # `spec_index`: action name → index into `action_specs`.
    action_specs::Vector{ActionSpec}
    spec_index::Dict{Symbol,Int}
    # v0.4 T2/T2-bis — THE SEAL FIELD keeps the registration FINGERPRINT (HC-9), minted by the
    # sanctioned route `publish` (the only SUPPORTED one; not the only POSSIBLE one in-process —
    # see the constructor note); `nothing` = an UNPUBLISHED value (the gated route-U
    # construction), which the `goMeta` door refuses typed. Since T2-bis the fingerprint is a
    # LOSSY CACHE KEY, never an identity and never the door's mechanism (T2BIS-DESIGN §12: the
    # ruling's word "seal" names the snapshot MECHANISM below; this field keeps the digest) —
    # the algorithm-tagged registration digest over every declared slot + the declared source
    # digests + policy_id, with its disclosed collisions (docs/public-api.md §1.2).
    seal::Union{Nothing,String}
    # v0.4 T2-bis (R-V04B-4 (c+)) — THE SNAPSHOT BASELINE: a deep domain-copy of the eleven
    # `_SNAPSHOT_FIELDS` values taken at publish (leaves — callables/Types/Symbols/Strings/
    # VersionNumbers/numbers — carried by reference; containers rebuilt at their exact concrete
    # types). The door compares the live fields against it by the ONE structural deep-egal walk
    # (`===`-only leaves) and fires `POST_SEAL_MUTATION` at the first divergent path — replacing
    # the retired seal re-mint + derived-table re-derivation + callable-identity compare
    # (accident-grade integrity, never security-grade; the entry check is not a lock; the
    # snapshot's own members are mutable — the B-2 residue, T2BIS-DESIGN §11). `nothing` on
    # unsealed values; the underscore is deliberate — an integrity baseline is not a plain
    # member of a package-public struct.
    _snapshot::Union{Nothing,NamedTuple}
    # THE ONE CONSTRUCTOR, token-gated. What the token IS and IS NOT (cure batch 2, the honest
    # bound): it removes the generated all-fields constructor so no POSITIONAL or ACCIDENTAL
    # construction can carry a seal — the route-U and mutation classes conforming code produces.
    # It is NOT an unforgeable capability: Julia has no access control, `GoMeta._SealToken()` is
    # callable by any loaded code, and a caller who reaches for it (and for `_mint_seal`) can
    # construct an unvalidated sealed value — that caller is a loaded module with full process
    # authority, OUTSIDE the trust model by the security frame's bound B-2 ("no in-process
    # arrangement in Julia constrains a loaded module"). Every integrity claim of this type is
    # accident-grade: typed refusal of post-seal mutation by CONFORMING code, never security-grade.
    # T2-bis FORM (T2BIS-DESIGN §5): the eight derived tables enter BY NAME as ONE NamedTuple
    # argument, destructured by field name HERE — the one reviewed destructuring site. No
    # hand-written table binding exists at any seal/snapshot-carrying call site, so the two
    # same-typed groups (`action_index`/`alt_index`; `action_to_plugin`/`accum_alt_idxs`/
    # `mutex_alt_idxs`) cannot be swapped by a caller.
    function AlterantRegistry(::_SealToken, plugins::Vector{PlugIn},
                              action_specs::Vector{ActionSpec}, t::NamedTuple,
                              seal::Union{Nothing,String}, snapshot::Union{Nothing,NamedTuple})
        new(plugins, t.sorted_alt_actions, t.action_to_plugin, t.action_index, t.alt_index,
            t.accum_alt_idxs, t.mutex_alt_idxs, t.action_to_settribute, action_specs,
            t.spec_index, seal, snapshot)
    end
end
"""
    AlterantRegistry(plugins, sorted_alt_actions, action_to_plugin, action_index, alt_index,
                     accum_alt_idxs, mutex_alt_idxs, action_to_settribute, action_specs, spec_index)

ROUTE U — positional construction from hand-built tables — is GATED at v0.4.0 (the route-U cure:
every public construction route runs the remaining checks; removal = v0.5): they run over
`(plugins, action_specs)` AND the hand-built derived tables must equal the tables derived from
the declarations (`REG_DERIVED_TABLES`, collected ALONGSIDE their diagnostics — full
collection); any error-severity defect throws `RegistrationRefused` with EVERY collected
diagnostic. A conforming construction yields an UNSEALED registry (`seal === nothing`) — the
`goMeta` door refuses it typed, naming the sanctioned path (`RegistryBuilder → validate →
publish`); route U therefore dies at the entry too (R-V04-34's STRICT door). No positional form
accepts a seal: for conforming callers, sealed values come from `publish` (the honest bound: the
token form is reachable by any loaded module — accident-grade, B-2).
"""
function AlterantRegistry(plugins::Vector{PlugIn}, sorted_alt_actions::Vector{Symbol},
                          action_to_plugin::Vector{Int8}, action_index::Dict{Symbol,Int8},
                          alt_index::Dict{Symbol,Int8}, accum_alt_idxs::Vector{Int8},
                          mutex_alt_idxs::Vector{Int8}, action_to_settribute::Dict{Symbol,Symbol},
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
            derived.action_to_settribute == action_to_settribute &&
            derived.spec_index == spec_index ||
            push!(diags, Diagnostic(:REG_DERIVED_TABLES, :error,
                "GoMeta registry: positional construction supplied derived tables that do not " *
                "match the tables derived from the declared record (route U is GATED at v0.4.0; " *
                "build via RegistryBuilder → validate → publish)"))
    end
    any(d -> d.severity === :error, diags) && throw(RegistrationRefused(diags))
    # T2-bis (§15 (8)): `derived === nothing` is unreachable here — a `_derive_tables` failure
    # always co-occurs with an error diagnostic, thrown above. Were the invariant ever false,
    # route U refuses TYPED before the token form rather than passing `t === nothing`.
    derived === nothing && throw(RegistrationRefused([Diagnostic(:REG_DERIVED_TABLES, :error,
        "GoMeta registry: positional construction could not derive tables from the declared " *
        "record (route U is GATED at v0.4.0; build via RegistryBuilder → validate → publish)")]))
    # the constructed value's tables are `derived`'s objects (`==`-equal to the caller's,
    # distinct identity — recorded, not silent; no pin reads their identity)
    return AlterantRegistry(_SealToken(), plugins, action_specs, derived, nothing, nothing)
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
    # the explicitly written NamedTuple from POSITIONAL arguments is ADMITTED here (T2BIS-DESIGN
    # §5): the by-name ban is scoped to seal/snapshot-CARRYING construction, and this seam
    # constructs with `nothing, nothing` — a binding swap could only affect the deliberately-
    # drifted-shape witnesses it exists to feed.
    AlterantRegistry(_SealToken(), plugins, action_specs,
                     (sorted_alt_actions = sorted_alt_actions, action_to_plugin = action_to_plugin,
                      action_index = action_index, alt_index = alt_index,
                      accum_alt_idxs = accum_alt_idxs, mutex_alt_idxs = mutex_alt_idxs,
                      action_to_settribute = action_to_settribute, spec_index = spec_index),
                     nothing, nothing)
"The number of registered alterants (4 since CH-3 step 9; 3 before the heading registration)."
num_alterants(r::AlterantRegistry) = length(r.plugins)

# --- the v0.4 registration LIFECYCLE types (T2): Builder → validated → PUBLISHED ------------------
"""
    RegistryBuilder()

The MUTABLE declaration site of a registry: `register!(builder, plugin, specs...)` appends an
Alterant registration record + its action records in declaration order. `register!` performs
exactly TWO immediate checks (throwing `RegistrationRefused`): the records must name the plugin
index being appended, and the Int8 slot pool (127 plugins, 127 actions) must not overflow; every
other check is DEFERRED to `validate(builder)`, which collects EVERY defect as typed diagnostics
(full collection before the one terminal outcome, never throwing), and `publish(builder)` refuses
on any error, else DEEP-copies every container into a SEALED `AlterantRegistry` (the sanctioned
route to a sealed value; `next_plugin_index(builder)` gives the index the next record must name).
"""
mutable struct RegistryBuilder
    plugins::Vector{PlugIn}
    action_specs::Vector{ActionSpec}
end
RegistryBuilder() = RegistryBuilder(PlugIn[], ActionSpec[])
"""
    next_plugin_index(builder) -> Int8

The declaration-order index the NEXT `register!`ed record must name (`length(builder.plugins) +
1`), typed `Int8` so it passes straight into `ActionSpec(; plugin = …)`; at capacity (127 plugins
already) it throws the lifecycle's typed `REG_SLOT_EXHAUSTED` refusal instead of an unusable 128.
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

A builder PRELOADED with a published registry's declarations (copied by the domain copier
`_domain_copy` — nothing mutable shared with the published value; leaves carried by reference;
`deepcopy` is never dispatched): the documented way to extend the built-in inventory
(`RegistryBuilder(DEFAULT_REGISTRY)`), then `register!` the new Alterant at `next_plugin_index`.
This is the ONE route that meets UNVALIDATED values (the input may carry a post-publication
cycle, an out-of-domain value, or a position-rule offense), so the copy is CONTAINED
(T2BIS-DESIGN §3 route 2): a cycle, an outside-domain value, or a `Function`/record struct
outside its lawful position converts to a typed `RegistrationRefused` (`REG_PROTOCOL`) whose
message names the offending type and the path — no internal exception and no unbounded
recursion leaves this public constructor.
"""
RegistryBuilder(r::AlterantRegistry) = RegistryBuilder(_copy_published_records(r)...)

"""
    register!(builder, plugin, specs...) -> builder

Append one Alterant registration record + ITS action records: the plugin takes the next
declaration-order index `i`, and every supplied `ActionSpec` MUST name `plugin == i` — a record
naming another index would pass validation against that other Alterant's setter and leave the
appended one silently actionless (cure batch 1), so the mismatch refuses HERE, loudly, as
`REG_PROTOCOL`; the Int8 slot pool refuses `REG_SLOT_EXHAUSTED` at the 128th PLUGIN append AND
when the appended action records would exceed 127 ACTIONS (cure batch 2).
"""
function register!(b::RegistryBuilder, plugin::PlugIn, specs::ActionSpec...)
    n = length(b.plugins) + 1
    n > typemax(Int8) && throw(RegistrationRefused([Diagnostic(:REG_SLOT_EXHAUSTED, :error, string(
        "GoMeta registry: register! — appending alterant ", repr(plugin.altName), " would be plugin ",
        n, ", beyond the slot pool of ", Int(typemax(Int8)), " (the Int8 index space)"), plugin.altName)]))
    na = length(b.action_specs) + length(specs)
    na > typemax(Int8) && throw(RegistrationRefused([Diagnostic(:REG_SLOT_EXHAUSTED, :error, string(
        "GoMeta registry: register! — appending ", length(specs), " action record(s) with alterant ",
        repr(plugin.altName), " would make ", na, " actions, beyond the slot pool of ",
        Int(typemax(Int8)), " (the Int8 index space)"), plugin.altName)]))   # (cure batch 2: the ACTION pool too)
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

The typed refusal of a registration: thrown by `publish` (and by the gated positional route) with
EVERY collected error/warning diagnostic — never the first one only — and by `register!` /
`next_plugin_index` for their two IMMEDIATE checks (the plugin-index binding `REG_PROTOCOL`; the
plugin/action pool overflow `REG_SLOT_EXHAUSTED`). Catch it, read `.diagnostics` (stable
`code`s), fix the record, re-validate.
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
seam) or a `String` (the CONTENT of a well-formed quoted token). ONE grammar accepts the String
kind — the Heading action's TEXT slot (`accepts_string_slot = 1`, the quoted-first sugar); every
other slot of every action refuses a quoted argument with a typed refusal at `absorbMeta`'s
enqueue seam (dispatch alone cannot hold that law: the built-in setters keep an untyped value
slot that would parse `cell("7")`). *(This docstring said "NO metaLine grammar accepts it yet"
— stale since the heading registration; corrected at v0.4 T2 on a CrossReview finding.)*
Exactly `Union{Symbol,String}`.
"""
const AlterantArgT = Union{Symbol,String}

"""
    AlterantQueue

The per-call enqueue tensors: `queued`
(`2 × numAltActions × num_slots`), `conditions`, `args` and — since stage 2's commit 2 of the v0.4 build
(R-V04B-35 (d)) — `decided_by`: per enqueued action the `key_bytes` handle of the Component that STATED it
(the carrying Component's handle published at the walk handover — the metaBlock a whole-line metaLine forms,
the Segment of an inline one, R-V04B-50; on the userMH feed the minted user-context handle), carried through
the apply into the stored row's provenance field.
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
    decided_by::Matrix{Union{Nothing,Vector{UInt8}}}
end

"""
    MetaContext

IS: the v0.2 CH-3 context record — {grain, depth, application level, occurrence handle, applied key} — published at the
walk→absorb handover for the current component (its handle the carrying Component's — R-V04B-50; its applied key the
Component the statement is applied to — R-V04B-98).

DOES: The v0.2 CH-3 context record — **{grain, depth, application level, occurrence handle, applied key}**,
derived from the parse and the run's configured namespace (`st.config.namespace` keys the handle —
nothing else of the configuration enters), published at the walk→absorb handover (`applyAbsorbFn`
builds it from the component + the post-update MH cursor and sets `st.meta_context`) and
stored in NO Component (the evaluation-free-tree law). Consumers at this step:
the quoted-first heading recognizer's APPLICABILITY check (the userMH feed NULLS the
record before its absorb call — no document line exists there — so a derived-context
heading through that surface meets a TYPED applicability refusal, never fabrication)
and the head evals row's level (the attr-fold: the level rides the attr NAME
`head_<level>`; no fabricated rows, no record-schema change). `level` is the
application level — the RAW MH-ladder index the walk set for this component (a
Segment-attached metaLine inherits the metaLine's `lineMHIdx`, so the inheritance
law holds by construction); the RECORDED level is normalized to ladder−1 — the
author's own `#~`-digit vocabulary — at the enqueue materialization seam (the documented
level vocabulary; the record itself stays as derived — from the parse and the configured
namespace, mutated by nothing). `handle` is the carrier's
serialized occurrence key (`key_bytes`) — under localOnly delivery the heading row's DECIDING STATEMENT; `applied` is the key of the
Component the statement is APPLIED TO (R-V04B-98; stage 5's E1) — under localOnly delivery LOAD-BEARING as the heading row's KEY.

REASONING: derived from the parse and the configured namespace, stored in no Component (the evaluation-free-tree
law), so a consumer reads a record rather than a mutated BLS Component tree.

PURPOSE: the consumers' record: the quoted-first heading recognizer's applicability check, the head evals row's
level (the attr-fold) and, under localOnly delivery, the heading row's key.
"""
struct MetaContext
    grain::Symbol            # :Block | :Line | :Segment
    depth::Int               # the component's own MH depth marker — 0 at v0.2: the walk's
                             # handover sites are Line/Segment-grain only (no Block-grain
                             # applyAbsorbFn call site exists), so the Block arm is defensive;
                             # the field is the record's designed shape (delta-review trued)
    level::Int               # the APPLICATION level — the MH-ladder index at absorb time
    handle::Vector{UInt8}    # the CARRIER's occurrence-key bytes (from the parse and the configured
                             # namespace) — the heading row's deciding statement
    applied::Vector{UInt8}   # R-V04B-98 (stage 5's E1; his §309 with his §286 (ii)): the occurrence-key bytes of the Component the
                             # statement is APPLIED TO — the metaBlock for a metaLine's statement (his §286 (i); R-V04B-50), the LINE
                             # for a Code Line's trailing metaSegment, keyed as the apply path keys it (the Line with the Segment as
                             # the key's origin), the metaBlock for the statement Segment of a metaLine split by a trailing comment —
                             # the heading row's KEY under localOnly delivery; differs from `handle` only for an inline metaSegment of a Code Line
end

"""
    UserContext

The profile-feed surface's own recordable identity (the user-context build): `handle` =
the minted user-context key bytes (`user_context_key(config.namespace, region_ordinal)`,
serialized). The fed profile's bytes are NOT carried on the record since stage 2's commit 9b (R-V04B-43 (1); the
row has no piece in the tree — its derived fifth column is empty: R-V04B-43 (4), his word OWNER-WORDS §277, R-V04B-90). Constructed by the feed routine immediately before its absorb call and
RESTORED-to-prior in a `finally` right after (the stack-disciplined bracket); the
document-side `meta_context` stays `nothing` on the feed, so the deriving-form refusal
holds by construction. Immutable; per-call config inputs only.
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
statements the apply applied, in application order — R-V04B-35 (d), stage 2's commit 2), the `evals` (the evals rows captured
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
    working_origin::Dict{Int8,Vector{Vector{UInt8}}}   # stage 2's commit 2 (R-V04B-35 (d)): per Alterant the handles of the
                                                       # statements the apply APPLIED, in application order; rebuilt with `working`
    evals::EvalStore
    snapshot::BLS.ComponentSettribute
    diagnostics::Vector{Diagnostic}
    crnt_depth_idx::Int
    first_parent_idx::Int
    crnt_idx::Int
    meta_context::Union{Nothing,MetaContext}   # v0.2 CH-3 step 9 (see MetaContext above)
    user_context::Union{Nothing,UserContext}   # the user-context build: non-nothing ONLY
                                               # inside the feed routine's bracket (set
                                               # before its absorb call, restored-to-prior
                                               # in the finally) — never set on the
                                               # document walk; the capture's second
                                               # (handle, content) source.
end

"""
    GoMetaDelivery(blsComponentTree, altValues_evals, status, diagnostics)

IS: the ONE object a GoMeta run hands back — the delivery of `goMeta(bytes; config, registry)` and of the
seam `run_absorb_apply!` — with its FOUR public parts, read by name (the owner's rulings R-V04B-28 the content,
R-V04B-29 the shape, R-V04B-30 the name, 2026-09-15/16; docs/public-api.md §1.1, §2):

- `blsComponentTree::BLS.ParseState` — the BLS Component tree the run was evaluated over, provided by BLS itself;
  it reaches an Extension as the part `blsComponentTree`, not through any function of the GoMeta Engine; an Extension
  travels it with BLS's own public functions (R-V04B-29; R-V04B-45; the owner's sentence — R-V04B-75 (8)). FIRST in
  the field order — his pipeline order (§242; R-V04B-71; his word on row 44, R-V04B-89).
- `altValues_evals::EvalStore` — the data container of the evaluated Alterant values: one final evals row per
  handle and attribute, as the run recorded them; the reader over it is `readAltValuesEvals`.
- `status::ProcessStatus` — `PROCESS_OK` (no error-severity diagnostic) or `PROCESS_ERROR` (at least one;
  non-OK ⇒ non-empty diagnostics).
- `diagnostics::Vector{Diagnostic}` — the run's typed diagnostics: every row the run recorded, `:error` and
  `:warning` alike; empty when it recorded none (a `PROCESS_OK` run may still carry `:warning` rows —
  `PROCESS_OK` means no `:error` row).

DOES: carries these four and NOTHING internal — the per-call working state (`ProcessState`) never leaves the
core (R-V04B-28). The parts are plain fields, in his pipeline order (R-V04B-89): `d.blsComponentTree`, `d.altValues_evals`,
`d.status`, `d.diagnostics`. The BLS Component tree is the SAME object the run wrote into (`init_state` keeps the caller's
parse state by identity; the apply writes its Visib settributes back into it), and it is MUTABLE: every reader
of one delivery shares that one object, and a caller that injected its own parse state through the seam holds
it too — a discipline, not a copy. On a fail-closed run (`PROCESS_ERROR` before any parse of that call — an
invalid config or a refused registry, refused at the entry before any absorb or apply work; or an injected
parse state the seam ledger refuses — the caller's own state, which an earlier or concurrent call may have
written into) the tree is a container built from EMPTY bytes — never the injected state — and the store is
empty.

REASONING: his words and his selections — `altValues_evals` and the BLS Component tree are "BY FAR the two MOST
IMPORTANT DATA CONTAINERS produced during the GoMeta process" (the owner's words, 2026-09-11); it is "NOW VERY
IMPORTANT to RESTRICT THAT INTERFACE TO A MINIMUM in order to MAXIMIZE OUR FLEXIBILITY IN IMPROVING GoMeta"
(his words, 2026-09-11); the content: his selection of the label F1 put to him — "altValues_evals, the BLS
Component tree, the status and the diagnostics; nothing else" (the label's wording the session's) — anchored by
his own "I meant four parts" (R-V04B-28, 2026-09-15); the shape: his "(iii) stands" (R-V04B-29, 2026-09-16) on
the label put — "One named object, the four parts public by name, no hand-over function" (its wording the
session's); the name `GoMetaDelivery` his pick (R-V04B-30, 2026-09-16) and his own typing (2026-09-17),
"object's names such as 'result' are NOT DESCRIPTIVE" (his words, 2026-09-15). The working state is the
Engine's own and its shape is not part of the delivered surface, so it is not delivered at all rather than
delivered and declared unstable (his order of 2026-09-15: "I HAD ENOUGH OF INTERIM. NO MORE.").

PURPOSE: what every Extension, development tool and test consumes from a run — and the reference object of
v0.4 for the GoMetaRetro line ("The final GoMeta v0.4 must produce a GoMetaDelivery which we can use as a
reference" — his words, 2026-09-17). The one `Base.show` method prints one line in the field order — the source-line count of
`blsComponentTree`, the row count of `altValues_evals`, the status, the diagnostics count — never the tree or the
rows.
"""
struct GoMetaDelivery
    blsComponentTree::BLS.ParseState     # his pipeline order (R-V04B-89, row 44): the tree first
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

IS: the constructor of a FRESH `ProcessState`, sized once per call from the registry and `NUM_MH_LEVELS`.

DOES: Build a FRESH `ProcessState`, sizing every container ONCE from `registry` + `NUM_MH_LEVELS`. Every
per-field init is performed here, so each call is independent — no tensor or cursor carries over:
`slots = zeros(Int8, NUM_MH_LEVELS)`; the `slot_*`/`count_*` per-slot vectors `fill(false,·)`/`zeros(Int8,·)`;
`queued = zeros(Int8, 2, nAct, nSlot)`; `conditions`/`args`/`decided_by` matrices filled with `nothing`; `working` and `working_origin`
empty `Dict`s; `evals` empty; `snapshot` a FRESH `ComponentSettribute` (its `array` is COPIED into by
`snapshot_settribute!`, never aliased); the three cursors all `fileMHIdx` (= 1).
`num_slots == NUM_MH_LEVELS`.

REASONING: every per-field init is performed here so that each call is independent — no tensor or cursor
carries over (the reset-safe law).

PURPOSE: the reset-safe start of every run, the only route to a `ProcessState`.
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
        fill!(Matrix{Union{Nothing,Vector{UInt8}}}(undef, n_act, n_slot), nothing),               # decided_by (R-V04B-35 (d))
    )
    return ProcessState(
        parse_state, config, registry, mh, queue,
        Dict{Int8,Any}(),            # working
        Dict{Int8,Vector{Vector{UInt8}}}(),   # working_origin (R-V04B-35 (d))
        EvalStore(),              # evals
        BLS.ComponentSettribute(),   # snapshot — FRESH (array copied-into, not aliased)
        Diagnostic[],                # diagnostics
        fileMHIdx, fileMHIdx, fileMHIdx,   # crnt_depth_idx / first_parent_idx / crnt_idx
        nothing,                     # meta_context — published per component at the walk handover (step 9)
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
