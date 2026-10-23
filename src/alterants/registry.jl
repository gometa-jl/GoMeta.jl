# registry.jl — the alterant inventory: the vocabulary-gated setters, state accessors, the default registry
#
# IS: the register file of the alterant layer — two nested sub-modules plus a top-level tail. `module
#     Alterants`: the Labels Alterant's own file's include (`alterants-std/labels.jl`: the
#     vocabulary of 46 names read from the data file `data/alterants-std/labels-vocabulary.txt` through the user level's copy (since 0.4.3;
#     the hard-coded list of 39 before it) — with `setLabels`/`checkLabels`; the plain file and its loader were removed,
#     its digest pin, capture cache and scope law as well) + the toy
#     setters `setVisib`/`setId` over the `@namedElement` types `Visib` (Bool: hide/show/discard)
#     and `Id` (Int16: cell/parent/file). `module CnS`: the per-call state accessors `wipeAltActionSlots`/
#     `updateMetaHierarchy`/`getState`/`getAltState`. The tail builds the immutable `AlterantRegistry`
#     (type: src/state.jl) — `build_default_registry()` → `const DEFAULT_REGISTRY` (the former
#     `VISIB_TO_SETTRIBUTE` alias is retired; the generic `action_to_settribute` table was removed as well).
# DOES: declares the closed default inventory (4 alterants / 9 actions — the `ids` action since 0.4.0) in
#     DECLARATION order (labels=1, Visib=2, id=3, heading=4 — the live keys are :id / :heading) and PUBLISHES
#     it through the v0.4 lifecycle (Builder → validate → publish): the sorted action table, the parallel action→plugin index, the name→index Dicts,
#     the SORTED `accum_alt_idxs` (the apply-phase `insorted` consumer in apply.jl depends on the sort),
#     (the identity Visib-action→settribute-key map was removed). `setLabels` (the `:` labels action) checks every
#     label against the Labels Alterant's vocabulary (the run's — the base plus the run's own vocabulary statements, labels.jl `declareLabels!`); an unknown label is SKIPPED and reported
#     by a `:warning` diagnostic (`LABEL_NOT_APPLIED_UNKNOWN`, since 0.4.3 — the refusal naming the accepted set before it; the kept `Dict{Symbol,Bool}` method's still) (docs/public-api.md §3.4). `getState`/`getAltState` read the
#     per-call `ProcessState` via `ctx()` (a ScopedValue — no module-global state). `updateMetaHierarchy`/`wipeAltActionSlots` maintain the meta-hierarchy cursor + the slot
#     tensors on `ctx()` under the single-source `maxDepthMH`/`NUM_MH_LEVELS` consts (src/state.jl).
# REASONING: the inventory is deterministic BY CONSTRUCTION (declaration order, built once, read-only)
#     rather than hanging on any iteration order. A `{…}` condition is read by Julia's parser and evaluated by Julia
#     since 0.4.0 (the creator's design) — this registry supplies its VOCABULARY:
#     the settribute keys and the queryable actions (`queryable_action`, src/state.jl), read by the rewrite at absorb.
# EDGES (honest): the Labels Alterant's BASE vocabulary is the user level's vocabulary file (since 0.4.3 — created from the shipped data file
#     `data/alterants-std/labels-vocabulary.txt`: `label1`..`label5`, `doc`, the 33 pictograph names in the glued form `label` + pictograph, the
#     everyday names; byte-exact names, no normalization; before 0.4.3 a hard-coded list in `alterants-std/labels.jl`), and since 0.4.2 a run's
#     vocabulary statements at `#~0` or in the profile add names to it and remove names from it — since 0.4.3 PERSISTENTLY, the user file edited
#     and every change of a run that completes reported by an `:info` row (labels.jl `declareLabels!`, the record's `onRead`); an unknown label APPLIED is skipped and
#     reported by a `:warning` row; a label QUERIED answers false when unknown or unset — the original engine's checker, since 0.4.0
#     (the membership refusal of 0.3.2 and a write-only valve of the 0.4 development were removed). `setId` parses values into the Int16 domain; the value/arity walls
#     around these setters are Julia's own since 0.4.0 (the apply seam's guarded
#     refusal was removed; docs/public-api.md §3.4). Only the labels
#     row has a query getter (`checkLabels`); Visib/Id carry none — `cell`/`parent`/`file` as a
#     condition atom meets the usual unknown-condition-key refusal (the registry's rule; the
#     E-07 row was retired with the closed interpreter). `DEFAULT_REGISTRY` is a PUBLISHED value (the
#     SNAPSHOT door): its Dict/Vector fields stay mutable containers, but a mutation
#     by CONFORMING code through any of them is DETECTED at the entry door (`POST_SEAL_MUTATION`)
#     by the ONE structural deep-egal comparison against the publish-time snapshot (`===`-only
#     leaves — a former fingerprint `seal` was removed), never silently effective
#     (accident-grade: a callable's BEHAVIOR is not pinned by its identity, the snapshot's own
#     members are mutable — the disclosed mixed residue, docs §1.2 — and the door is an entry
#     check, not a lock over the run); the former `===` alias onto its write-back Dict is
#     retired.
# PURPOSE: the closed, deterministic alterant inventory + the state accessors the absorb/apply phases consume.

## Alterants — the label / Visib / Id inventory sub-module
module Alterants
#########################################################################################
#########################################################################################
import ..BLS as BLS
using ..BLS.NamedElements
using StaticArrays: SVector
## the Labels Alterant's read-time hook checks the PLACE of a vocabulary statement by the meta-hierarchy
## index the Engine hands it (`#~0` = the file slot, the user level, an inline metaSegment) — the structural consts have their single
## source in state.jl, included before this file (the pattern of `module CnS` below).
using ..GoMeta: fileMHIdx, userMHIdx, lineMHIdx
## the Labels Alterant's setter RETURNS `Diagnostic` rows (a plain name met by a withhold; a name outside the run's vocabulary) and its hook
## RETURNS them with the run state (a persisted vocabulary change) — the type is the Engine's (result.jl, included before this file); the
## Engine's one door (state.jl) delivers them with the place attached.
using ..GoMeta: Diagnostic
## the argument-edge class (src/arguments.jl): the Labels Alterant trims the lines of its vocabulary files with it and refuses a character of
## the class INSIDE a declared name or a file's name.
using ..GoMeta: is_argument_space

#########################################################################################
#########################################################################################
## Labels.jl for `alterant` `Labels`:

## The Labels Alterant has its OWN file since 0.4.0 (the creator's decision — the whitelist belongs in the Labels
## Alterant, "fixing a bug"): the vocabulary files' reader `base_vocabulary()` (the user level's copy of the shipped data file
## `data/alterants-std/labels-vocabulary.txt`, since 0.4.3 — the hard-coded list `LABELS_VOCABULARY` of 0.4.0 … 0.4.2 before it), `setLabels`
## (the check against the run's vocabulary — an unknown name reported, since 0.4.3; the original engine's refusal, GoMetaRetro Alterants.jl
## :73–:78, kept in the `Dict{Symbol,Bool}` method) and `checkLabels` (false for an unset or unknown name — the original engine's :87–:99)
## live in `alterants-std/labels.jl` (std-Alterant territory, never a Core literal — vocabulary_tests [10] scans around it).
## The plain file `labels_vocabulary.txt` of the 0.4 development and its loader were removed within it; the data file is 0.4.3's.
include(joinpath(@__DIR__, "..", "alterants-std", "labels.jl"))

#########################################################################################
#########################################################################################
## Visib.jl for `alterant` `Visib`:
@namedElement Visib Bool begin
    hide
    show
    discard
end

function setVisib(
    crntVisib::Visib,
    actionName::Symbol
)
    setElement(crntVisib, actionName => true)
end
function setVisib(
    crntVisib::Visib,
    actionName::SubString{String}
)
    setElement(crntVisib, Symbol(actionName) => true)
end

#########################################################################################
#########################################################################################
## Ids.jl for alterant `Id`:
# using .NamedElements
@namedElement Id Int16 begin
    cell
    parent
    file
end

function setId(
    crntId::Id,
    idName::Symbol,
    idValue
)
    setElement(crntId, idName => parse((eltype(Id)), string(idValue)))
end
function setId(
    crntId::Id,
    idName::SubString{String},
    idValue::SubString{String}
)
    setElement(crntId, Symbol(idName) => parse((eltype(Id)), idValue))
end

## `ids(c, p, f)` — the three fields at once, each set as the single action sets it (the creator's "#~ ids( c, p, f)"): the same `Int16` parse of each written value, in the order cell, parent, file. A wrong arity or a
## non-parsable value meets Julia's own error out of `goMeta`, as the three single actions' do: `ids(1, 2)` finds no
## method; the ONE-VALUE form reaches the single-value method above with `idName == :ids` — MEASURED.
function setId(
    crntId::Id,
    idName::Symbol,
    c, p, f
)
    ## the guard: a THREE-value SINGLE action — `cell(1, 2, 3)`, `parent` and `file` alike — reaches this
    ## method too and would otherwise set all three fields silently; its ArgumentError (the Alterant's own setter
    ## error; the wording provisional) is where an earlier state — no five-argument `setId` there — met Julia's MethodError (MEASURED)
    idName === :ids || throw(ArgumentError("setId: three values belong to the action `ids` alone (got `$(idName)`)"))
    setElement(crntId, :cell => parse((eltype(Id)), string(c)), :parent => parse((eltype(Id)), string(p)), :file => parse((eltype(Id)), string(f)))
end
function setId(
    crntId::Id,
    idName::SubString{String},
    c::SubString{String}, p::SubString{String}, f::SubString{String}
)
    setId(crntId, Symbol(idName), c, p, f)
end

#########################################################################################
## The Heading alterant: struct `Heading`, registry key `:heading`, action `head`
## (the publishing term — running head, head levels). Single-action inventory
## {head}; `title`/`subhead` stay unminted (mint-at-need; hyphen-free spelling if a
## compound ever mints). The store records captured headings and OWNS the corners
## via its validation seam: empty heading text meets the guarded refusal — a STANDING
## v0.2 semantic, not a transitional default (docs/public-api.md §3.4).
## NON-QUERYABLE (getAltInstance = nothing): a condition naming `head` meets the usual
## unknown-condition-key refusal (the registry's rule). A heading's own condition is Julia's, evaluated
## at the apply like every condition — a label test in it is legal since 0.4.0 (the
## loop's order: the labels of the levels above — the user level's among them — and those stated before the heading on its
## metaLine are seen, those after it are not, WITH OR WITHOUT a fed profile since 0.4.1 (before, in 0.4.0, a fed profile made the user
## level the loop's first slot and a metaBlock's own labels were collected before its heading was decided — MEASURED
## before and after)).
mutable struct Heading
    entries::Vector{Tuple{String,Union{Nothing,Int}}}   # (text, explicit level | nothing ⇒ derived)
end
Heading() = Heading(Tuple{String,Union{Nothing,Int}}[])

## The Heading VALIDATION seam: the empty-`""` corner routes HERE from both surfaces
## (the enqueue carve-out in absorbMeta calls it at absorb time, so the refusal is
## condition-independent; the setters call it too as the store's own guard). The
## refusal is a STANDING v0.2 semantic (relaxing it later is a compatible
## widening — the reverse would not be). Level-range validation is also
## validation-owned: an EXPLICIT level must land in the level vocabulary
## (`_heading_validate_level` below); DERIVED levels are in-vocabulary by
## construction.
## The validator honors the documented
## handover contract `(text) -> Bool` — `return true` on acceptance (the former `&&`
## one-liner RETURNED `false` on every non-empty text, the short-circuit value, harmless
## only while the result was discarded); the empty-text refusal keeps its
## byte-exact engine-prefixed message and passes through the validate envelope
## verbatim (the pass-through law). `setHead`'s own calls ignore the return.
function _heading_validate_text(t)
    isempty(String(t)) && error("GoMeta absorb: empty heading text — an empty ",
        "heading is refused at v0.2 (a standing decision; ",
        "see docs/public-api.md §3.4)")
    return true
end

## Explicit-level window guard: an EXPLICIT heading level must land in the
## level vocabulary — the structural `#~`-digit window 0..8 or the documented
## inline constant 10 (`head_10`). Anything else refuses HERE with the §3.4
## stable-message family (the empty-text precedent). DERIVED levels are
## engine-produced and in-vocabulary by construction.
_heading_validate_level(lvl::Int) =
    (0 <= lvl <= 8 || lvl == 10) || error("GoMeta absorb: explicit heading level ", lvl,
        " is outside the level vocabulary — the structural window 0..8 or the ",
        "inline constant 10 (see docs/public-api.md §3.4)")

## The setHead METHOD PAIR: the DERIVING method is the default — the quoted-first
## sugar lowers to it and the level derives from placement (the MetaContext record;
## the level fact rides the head evals row's ATTR NAME `head_<level>` — the
## attr-fold; stored in NO Component) — and the EXPLICIT sibling takes the level
## per call. The explicit level arrives as Symbol text (`Symbol("2")`: the literal
## floor keeps the integer space RESERVED out of the args wall) and is parsed
## here — the setId precedent; a non-parseable level is `parse`'s own ArgumentError (the seam's
## guarded refusal was removed within the 0.4 development).
function setHead(crntHeading::Heading, actionName::Symbol, headingText::AbstractString)
    _heading_validate_text(headingText)
    push!(crntHeading.entries, (String(headingText), nothing))
    return nothing
end
function setHead(crntHeading::Heading, actionName::Symbol, headingText::AbstractString,
                 levelValue)
    _heading_validate_text(headingText)
    lvl = parse(Int, string(levelValue))
    _heading_validate_level(lvl)   # refuse out-of-window explicit levels (0..8 or 10)
    push!(crntHeading.entries, (String(headingText), lvl))
    return nothing
end
end

## CnS.jl - "Constants and State"
module CnS

#########################################################################################
########### Imports #####################################################################
import ..BLS as BLS
import StaticArrays: SVector
# The slot tensors + queue matrices below are plain `Vector`/`Array` — no fixed-size-array dependency.
# They are sized once at construction, mutated in place and NEVER resized, and they are rebuilt fresh
# for every call as `ProcessState` fields, so a fixed-length container type would buy nothing here.
using ..Alterants
# The per-call-state accessors come from the parent `GoMeta` module, so the `getState`/`getAltState`/
# `updateMetaHierarchy`/`wipeAltActionSlots` bodies below reach the ScopedValue-delivered `ProcessState`
# (`ctx()`) and the pure `get_state` settribute reader. state.jl (which defines both) is included BEFORE
# registry.jl, so this import resolves at load; the nested-submodule `import ..Parent: name` idiom is
# empirically confirmed on Julia 1.12.5.
import ..GoMeta: ctx, get_state
## The structural meta-hierarchy index consts have a SINGLE source, state.jl. `updateMetaHierarchy` (the
## only consumer inside this sub-module) reaches `maxDepthMH` + `NUM_MH_LEVELS` through this import;
## state.jl is included BEFORE registry.jl, so it resolves at load.
using ..GoMeta: maxDepthMH, NUM_MH_LEVELS

#########################################################################################
########### Exports #####################################################################
export getState
#########################################################################################
########### Constants & Co. #############################################################

########### Constants AFTER `BLS` BEFORE `Alterant(s)` ##################################
# The structural meta-hierarchy index consts are NOT per-call state, and they have a SINGLE source,
# state.jl: `NUM_MH_LEVELS = 12` + `maxDepthMH`(=length(BLS.depthLevelsMH)=9) / `fileMHIdx`(=1) /
# `userMHIdx`(=maxDepthMH+1=10) / `lineMHIdx`(=maxDepthMH+2=11) / `fallBackMHIdx`(=maxDepthMH+3=12),
# guarded there by `@assert maxDepthMH+3==NUM_MH_LEVELS`. The only consumer inside this sub-module
# (`updateMetaHierarchy`) imports `maxDepthMH` + `NUM_MH_LEVELS` from the parent (the import above);
# the external consumers (walk.jl / apply.jl, both in the parent module) reference them unqualified.
#########################################################################################
## DESIGN NOTE (why one const carries both the level count and the slot count): `NUM_MH_LEVELS` is the
## count of all available/possible meta-hierarchy levels; the slot count was conceived as POSSIBLY
## larger — storing metaData at an already-used level WITHOUT overwriting the previous one (e.g.
## siblings: store the latest `Block` at a used level and re-assign the previous one without clobber).
## At v0 the two are EQUAL (both 12), so one const carries both roles (state.jl's `init_state` sizes
## `n_slot = NUM_MH_LEVELS`); re-opening this layout is deferred at v0.

########### Constants AFTER `Alterant(s)` (and `BLS`) ###################################
function wipeAltActionSlots(fromIdx::Int, toIdx::Int)
    # The slot tensors (`st.mh.slots` / `st.mh.count_actions_per_slot` / `st.mh.slot_occupied` /
    # `st.mh.slot_has_accum`) and the per-slot queue matrices (`st.queue.conditions` / `st.queue.args`,
    # plain values, no `Ref` wrappers) all live on the per-call `ProcessState`, reached via `ctx()` —
    # there is no module-global slot state to wipe.
    local st = ctx()
    local crntSlot::Int8
    for idx ∈ fromIdx:toIdx
        if st.mh.slots[idx] != 0
            crntSlot = st.mh.slots[idx]
            st.mh.slots[idx] = 0
            if st.mh.count_actions_per_slot[crntSlot] != 0
                for actionIdx ∈ 1:st.mh.count_actions_per_slot[crntSlot]
                    ## Clear the per-slot condition/args entries (a per-call GC nicety); the queue
                    ## holds plain values, so `nothing` is stored directly:
                    st.queue.conditions[actionIdx, crntSlot] = nothing
                    st.queue.args[actionIdx, crntSlot] = nothing
                    st.queue.decided_by[actionIdx, crntSlot] = nothing   # the origin references, like the single-index wipe
                    st.queue.applied_to[actionIdx, crntSlot] = nothing   # the applied Component's key, wiped with its slot
                end
                st.mh.count_actions_per_slot[crntSlot] = 0
            end
            st.mh.slot_occupied[crntSlot] = false
            st.mh.slot_has_accum[crntSlot] = false
        end
    end
end

function wipeAltActionSlots(idx::Int)
    # Single-index wipe — same as the 2-arg method above, reading/writing the per-call slot tensors
    # and queue matrices on `ctx()`.
    local st = ctx()
    if st.mh.slots[idx] != 0
        crntSlot = st.mh.slots[idx]
        st.mh.slots[idx] = 0
        if st.mh.count_actions_per_slot[crntSlot] != 0
            for actionIdx ∈ 1:st.mh.count_actions_per_slot[crntSlot]
                st.queue.conditions[actionIdx, crntSlot] = nothing
                st.queue.args[actionIdx, crntSlot] = nothing
                st.queue.decided_by[actionIdx, crntSlot] = nothing
                st.queue.applied_to[actionIdx, crntSlot] = nothing
            end
            st.mh.count_actions_per_slot[crntSlot] = 0
        end
        st.mh.slot_occupied[crntSlot] = false
        st.mh.slot_has_accum[crntSlot] = false
    end
end

function updateMetaHierarchy(newMHIdx::Int)
    # The meta-hierarchy cursors (`st.crnt_idx` / `st.crnt_depth_idx` / `st.first_parent_idx`) and the
    # slot tensors (`st.mh.slots` / `st.mh.slot_occupied`) live on the per-call `ProcessState` reached
    # via `ctx()`, so every cursor write here is a plain mutable-field assignment on `st` — no module
    # globals. The structural consts (`maxDepthMH` / `NUM_MH_LEVELS`) resolve to state.jl, their single
    # source.
    local st = ctx()
    if newMHIdx < maxDepthMH + 1
        if newMHIdx <= st.crnt_depth_idx
            wipeAltActionSlots(newMHIdx, st.crnt_depth_idx)
        else
            st.first_parent_idx = st.crnt_depth_idx
        end
        st.crnt_depth_idx = newMHIdx
    elseif newMHIdx < NUM_MH_LEVELS + 1
        wipeAltActionSlots(newMHIdx)
    elseif newMHIdx > NUM_MH_LEVELS
        error("updateMetaHierarchy(): NUM_MH_LEVELS < newMHIdx i.e.: out of range !!!")
    end
    st.crnt_idx = newMHIdx
    ## the slot pool is finite (`NUM_MH_LEVELS` slots); the walk allocates at most one slot per live level, so no input
    ## exhausts it — a former guarded refusal was removed (the original engine's
    ## bare `findfirst`): an exhausted pool is Julia's own error at the Int8 store below
    free = findfirst(isequal(false), st.mh.slot_occupied)
    st.mh.slots[st.crnt_idx] = free
    st.mh.slot_occupied[free] = true

end

function getState(stateKey::Symbol)
    # Reads the per-call settribute snapshot via `ctx()`: `get_state(ctx().snapshot, key)` is the pure
    # reader form of `BLS.getElement(ctx().snapshot, key)`. THE condition's settribute read: a re-written
    # condition calls `getState(:key)` by BARE name (`using .CnS: getState, getAltState` in module GoMeta,
    # where `Core.eval` runs it — the original engine's form, CnS.jl :252–:256) and reaches the per-call state through
    # the module-level ScopedValue. Writing goes the other way: the parent helper
    # `snapshot_settribute!(ctx(), component)` refreshes the snapshot, so this accessor is read-only.
    return get_state(ctx().snapshot, stateKey)
end

function getAltState(
    altInd::Int8,
    altActionName::Symbol,
    args::Vararg{Symbol}
)
    # The per-call working alterant-instance dict and the alterant inventory are both read off `ctx()`;
    # `st` is hoisted once for type-stable field reads. Module-level for the same reason as `getState`
    # above (the re-written condition calls it by BARE name — the rewrite spells the plugin index and the
    # action as `getAltState(Int8(p), Symbol("…"), args…)`). `altInd` is the declaration-order plugin
    # index (it comes from the registry's action-to-plugin table); `st.working[altInd]` is the instance
    # the apply phase constructed under that SAME index, so the lookup is internally consistent.
    local st = ctx()
    if altInd ∈ keys(st.working)
        ## the bare call, as the original engine's (CnS.jl :267–:275): a former query-seam envelope was removed, as was
        ## the closed interpreter's own envelope (CB_QUERY_THROW / RES_RETURN_TYPE)
        ## with the interpreter — THE one query site since: a getter's throw propagates raw out of
        ## the goMeta call, a non-Bool return reaches the condition as it is (Julia's own TypeError where a Bool is needed)
        return st.registry.plugins[altInd].getAltInstance(st.working[altInd], altActionName, args...)
    else
        return false
    end
end

end # module CnS

#########################################################################################
########### The deterministic alterant registry #########################################
#########################################################################################
# IS: the declaration-order build of the immutable `AlterantRegistry` (type: src/state.jl). This is
#     top-level `GoMeta` code (registry.jl is `include`d after state.jl, and GoMeta does NOT
#     `using .Alterants`), so `Alterant` here is unambiguously state.jl's record type — the module `Alterants` (plural)
#     holds the shipped Alterants' code, not the record.
# DOES: `build_default_registry()` constructs FRESH top-level `Alterant` instances in DECLARATION order
#     (labels=1, Visib=2, id=3, heading=4 — the live keys are :id / :heading), derives the sorted action
#     table + the parallel `action_to_plugin` index
#     + the `Dict` lookups + the SORTED `accum_alt_idxs` (the `action_to_settribute` table was removed)
#     through the CHECKED owner
#     fill (a duplicate action name resolves FIRST-wins — the clash law that refused it was removed), and returns
#     `const DEFAULT_REGISTRY`.
# REASONING: alterant/action indices are fixed by declaration order, never by `Dict` iteration order —
#     those indices are baked into the eval'd condition strings.
# PURPOSE: a deterministic-by-construction, immutable, read-only alterant inventory for the pipeline.

"""
    default_registry_builder() -> RegistryBuilder

IS: the v0 alterant inventory's DECLARATIONS in DECLARATION order — the DEFAULT BUILDER: fresh top-level `Alterant`
instances (the `state.jl` record type) for `labels` / `Visib` / `Id` / `Heading` (the live keys `:labels`, `:Visib`, `:id`,
`:heading`; the heading alterant — its names: alterant `Heading`, action `head`) + the per-action records,
returned as an UNVALIDATED `RegistryBuilder`.

DOES: builds the four records in the keyword form, each with its declared default and its capture row — `labels`
(`:accumulate`; `Alterants.LabelsInstance` (since 0.4.2) — the applied labels, the run's vocabulary and the names withheld at the Component (the withhold `:-x`, since 0.4.3), iterating as the former bare `Dict{Symbol,Bool}` did (labels.jl); a plain `:x` met by a withhold, and a name outside the run's vocabulary under any verb, apply nothing and are reported through the setter's returned `:warning` diagnostics, delivered by the apply loop's door with the place attached; setter `setLabels`, getter `checkLabels`; the read-time hook `onRead = Alterants.declareLabels!` — the vocabulary statements consumed at the read, a persisted change of the user level's vocabulary file reported through the hook's returned `:info` row; the setter's and the checker's kept `Dict{Symbol,Bool}` methods serve a custom registration with `altConstructor = Dict{Symbol,Bool}` and NO hook — with a hook, a minted run state reaches `Dict{Symbol,Bool}(run)` and is Julia's own error (apply.jl `_freshInstance`; labels.jl); default the EMPTY SET; capture
`:per_key`, stem `:label`), `Visib` (`:mutExclusive`; default `:show`; `:single`, stem `:visib`), `id`
(`:mutExclusivePerField`; default the ZERO compound; `:per_field`, stem `:id`) and `heading` (`:localOnly` —
queued like every action, applied by the apply loop's one rule for this mode ONLY at the Component the statement is applied
to (the metaBlock for a metaLine's statement, the Line for a trailing metaSegment);
default `nothing`; `:per_entry`, stem `:head`) — and the nine `ActionSpec` records: `:` (plugin 1), `hide` / `show` / `discard` (2),
`cell` / `parent` / `file` / `ids` (3) and `head` (4; `accepts_string_slot = 1`, `validate = Alterants._heading_validate_text`).
The plugin index IS the position here. `publish` runs the remaining check (the domain probe; a former
vocabulary check, a validation chain and the Heading's mode-gate
laws were removed within the 0.4 development), derives the tables (a duplicate action name resolving first-wins), and takes the publish-time snapshot;
`DEFAULT_REGISTRY` is that published value, consumed READ-ONLY. Pure — no module-load side-effects.

REASONING: the inventory is deterministic BY CONSTRUCTION — declaration order fixes every index, never a `Dict`
iteration order; the declarations are DATA, the hot-path tables derived from them by `publish`, never hand-supplied
(a clash law with its disposition switch and the per-overload rows were removed; the original engine registered an
action by its name).

PURPOSE: the one declaration site of the shipped inventory — the base `build_default_registry` publishes and
`RegistryBuilder(DEFAULT_REGISTRY)` extends.
"""
function default_registry_builder()
    # The closed v0 inventory, in DECLARATION order (deterministic, unlike Dict-iteration
    # order). Plugin index = position here.
    plugins = Alterant[
        ## Every DEFAULT record DECLARES its capture row (the registration-driven
        ## capture plane; the stems are DECLARED — byte-compatibility never rides the
        ## derived fallback) — the three former positional declarations (0.3.2's) migrated
        ## to the keyword form to carry `capture =`.
        Alterant(; altName = :labels, setMode = :accumulate, altConstructor = Alterants.LabelsInstance,   # the instance carries the run's vocabulary (labels.jl)
                   setAltInstance = Alterants.setLabels, getAltInstance = Alterants.checkLabels,
                   default = Declared(Symbol[]),   # Labels' declared default is the EMPTY SET (the creator's decision, provisional) — the answer's shape, a sorted Vector{Symbol}
                   capture = CaptureDecl(:per_key; attr_stem = :label),
                   onRead = Alterants.declareLabels!),   # the vocabulary statements `:++x` / `:--x` consumed at the read
        Alterant(; altName = :Visib, setMode = :mutExclusive, altConstructor = Alterants.Visib,
                   setAltInstance = Alterants.setVisib,
                   default = Declared(:show),   # Visib's ONE declared default is 'show' (the creator's decision)
                   capture = CaptureDecl(:single; attr_stem = :visib)),
        Alterant(; altName = :id, setMode = :mutExclusivePerField, altConstructor = Alterants.Id,
                   setAltInstance = Alterants.setId,
                   default = Declared((cell = Int16(0), parent = Int16(0), file = Int16(0))),   # Id's declared default is the ZERO compound — every recorded field zero, in the answer's NamedTuple shape
                   capture = CaptureDecl(:per_field; attr_stem = :id)),
        # The Heading. setMode `:localOnly` — the creator's set mode: the value applies ONLY at the
        # Component the statement is applied to — the metaBlock for a metaLine's statement, the Line for a Code Line's
        # trailing metaSegment — and every other Component that meets it on a shared level
        # passes over it. The Heading goes through EXACTLY the same process as any
        # other Alterant (the creator's decision): queued like every action, decided by the apply loop's one
        # rule for this mode (apply.jl), recorded by the one capture walk (`:per_entry`: one row per heading occurrence,
        # the level in the attr name — the outline model). Deliberately in NEITHER derived set below.
        Alterant(; altName = :heading, setMode = :localOnly, altConstructor = Alterants.Heading,
                   setAltInstance = Alterants.setHead,
                   default = Declared(nothing),   # Heading's declared default is NONE — no heading, delivered as `nothing` with the source `:default`
                   capture = CaptureDecl(:per_entry; attr_stem = :head)),
    ]

    # THE DECLARED REGISTRATION RECORD (since v0.2) — one ActionSpec per action, declaration
    # order (the parallel derived tables below stay the hot-path lookups). The per-overload rows were removed within the 0.4
    # development with the spelling tag, the sugar-candidacy register and the reserved keyed slot (
    # the original engine registered an action by its name and let Julia dispatch
    # do the rest): the setters' methods are the actions' forms; the keyword form is the one form.
    action_specs = ActionSpec[
        # Labels `:(:)` — the operator-token action; the colon sugar is one of the two activated
        # sugars (closed at two); queryable via checkLabels.
        ActionSpec(; name = Symbol(":"), plugin = Int8(1)),
        # Visib hide/show/discard — zero literal slots (the action name selects); NON-queryable at v0.2
        # (getAltInstance=nothing). A declared write-back settribute key was removed within the 0.4
        # development:
        # the Engine's answer is `evaluatedAltValue`; nothing writes a flag into the BLS Components.
        ActionSpec(; name = :hide, plugin = Int8(2)),
        ActionSpec(; name = :show, plugin = Int8(2)),
        ActionSpec(; name = :discard, plugin = Int8(2)),
        # Id cell/parent/file — ONE literal slot each (the setter parses the Symbol text); NON-queryable
        # (experimental). `ids` — THREE literal slots: the three fields cell, parent, file at once, each set as the single
        # action sets it (the creator's "#~ ids( c, p, f)"; its faults Julia's own errors, as the single actions'
        # are). A meta-hierarchy slot's capacity is SLOT_CAPACITY (state.jl), DECOUPLED from this count.
        ActionSpec(; name = :cell, plugin = Int8(3)),
        ActionSpec(; name = :parent, plugin = Int8(3)),
        ActionSpec(; name = :file, plugin = Int8(3)),
        ActionSpec(; name = :ids, plugin = Int8(3)),
        # head — the single Heading action; its two forms (deriving / explicit) are the setter's methods — the deriving
        # form takes its level at the enqueue (absorb_meta.jl). accepts_string_slot = 1 (the capability
        # that retired the wall's name literal); the quoted-first sugar is the second activated sugar; the
        # validate slot carries the Heading-owned empty-text refusal (the handover-validation slot).
        ActionSpec(; name = :head, plugin = Int8(4), accepts_string_slot = 1, validate = Alterants._heading_validate_text),
    ]

    # The registration (a former validation chain
    # and the clash law with its disposition switch were removed; the original engine registered unchecked): the declarations
    # above are the DEFAULT BUILDER; `publish` runs the remaining check (`_validate_registration`: the domain
    # probe — a former vocabulary check and the Heading's mode-gate laws were removed), then `_derive_tables` derives the hot-path
    # tables (the sorted action table, the parallel action→plugin index, the name→index Dicts, the SORTED
    # accumulate/mutExclusive index sets the apply-phase `insorted` consumers depend on — a duplicate action
    # name resolving first-wins; the `action_to_settribute` table was removed) from the
    # declarations only, never hand-supplied; `:mutExclusivePerField` (the `id` compound) sits in NEITHER
    # mode set by design (its per-field semantics are deferred).
    return RegistryBuilder(plugins, action_specs)
end

"""
    build_default_registry() -> AlterantRegistry

IS: the v0 alterant inventory, PUBLISHED — the one-line composition `publish(default_registry_builder())`.

DOES: returns a published `AlterantRegistry` carrying its publish-time snapshot: the remaining check (the domain probe —
a former vocabulary check and the mode-gate laws were removed —, inside `publish`) run before the object exists, the
derived tables come from the declarations, and the publish-time snapshot is taken. Every call builds a FRESH value (the
tests publish their own). Pure — no module-load side-effects beyond the const it feeds.

REASONING: the shipped inventory goes through the SAME lifecycle a third-party registration goes through (Builder →
validate → publish) — no second construction route for the default.

PURPOSE: the builder of `const DEFAULT_REGISTRY` (the tail of this file).
"""
build_default_registry() = publish(default_registry_builder())

## The canonical TEXT of a declared slot: deterministic, module-unqualified, callables by NAME, containers
## element-wise in declaration order, and BOUNDARY-UNAMBIGUOUS (no element boundary can be re-cut) — NOT globally
## injective. This family has ONE caller — the validate walk's canonical Dict-entry
## ORDER (`_walk_dict_entries` below; a deterministic first-failure): the registration digest it fed, with
## the `seal` fingerprint that digest minted, were removed — one key-text path
## stays for the kept door. Its residual collision classes — module-unqualified type names; the name-folded designated
## callables; function-valued type parameters; untagged parameter categories (`Val{M.T}` ≡ `Val{true}`); un-encoded
## container parameters (`Any[1]` ≡ `Int[1]`) — were FINGERPRINT-only, each caught at the door by the snapshot's `===`
## leaf compare; for a key ORDER a collision means two keys sort as equal texts — the sort is stable. The former (iv)/(v) hard-stop classes are
## CLOSED (`String`-only values; every type-bearing field probed at validate under the node
## budget); non-DataType type nodes encode STRUCTURALLY (never `string`) — a TypeVar only as a DataType parameter or a UnionAll's variable: met as another TypeVar's bound, a Union member or a Vararg element type it throws `_UnencodableSlot` and `_walk_dict_entries` takes that Dict's live iteration order
## (the first encoding joined elements with delimiters, so `[Symbol("a,b")]` and
## `[:a, :b]` folded identically — every element, every string leaf and every component is now
## LENGTH-PREFIXED, netstring-style `<bytes>:<text>`, so no boundary can be re-cut).
_ns(s::String)::String = string(sizeof(s), ":", s)
_nsv(parts)::String = join((_ns(String(p)) for p in parts), ",")
_slot_text(x::Nothing)::String = "-"
_slot_text(x::Symbol)::String = string("y", _ns(String(x)))
# CONCRETE `String` ONLY, matching
# `_domain_leaf`'s own String-only law: the former `::AbstractString` arm ran the
# EXTENSIBLE `String(x)` on a caller-owned string subtype (measured: a stateful
# specialization threw at validate, raw, through the ordering prepass). A non-String
# AbstractString value now falls to the `_UnencodableSlot` fallback — the coded
# refusal, zero caller code run — exactly where the domain law always placed it.
_slot_text(x::String)::String = string("s", _ns(x))
_slot_text(x::Bool)::String = x ? "T" : "F"
# The CONCRETE numeric type is part of the value (`Int8(1)` ≠ `Int64(1)`), and a
# vector is not a tuple — distinct tags, so a same-display substitution changes the text.
# THE ENCODABLE DOMAIN IS CLOSED. Numbers: the machine integers by decimal text,
# the machine floats BIT-EXACTLY (display text collapses distinct NaN payloads), Complex and
# Rational STRUCTURALLY over their parts; any other Number — and any value of a type without an
# encoder below — is UNENCODABLE and REFUSED at validation (`REG_PROTOCOL`), never folded by a
# lossy fallback (the former `typeof`+`repr` fallback let a stable-`repr` mutation hide).
struct _UnencodableSlot <: Exception; T::Type; end
_slot_text(x::Union{Int8,Int16,Int32,Int64,Int128,UInt8,UInt16,UInt32,UInt64,UInt128})::String =
    string("n", _nsv((_type_text(typeof(x)), string(x))))
_slot_text(x::Float64)::String = string("n", _nsv((_type_text(typeof(x)), string(reinterpret(UInt64, x); base = 16))))
_slot_text(x::Float32)::String = string("n", _nsv((_type_text(typeof(x)), string(reinterpret(UInt32, x); base = 16))))
_slot_text(x::Float16)::String = string("n", _nsv((_type_text(typeof(x)), string(reinterpret(UInt16, x); base = 16))))
# getfield parts here too — the encoder repeated the extensible
# real/imag/numerator/denominator dispatches; output byte-identical for legal values
_slot_text(x::Complex)::String = string("c", _nsv((_type_text(typeof(x)), _slot_text(getfield(x, :re)), _slot_text(getfield(x, :im)))))
_slot_text(x::Rational)::String = string("r", _nsv((_type_text(typeof(x)), _slot_text(getfield(x, :num)), _slot_text(getfield(x, :den)))))
_slot_text(x::Number)::String = throw(_UnencodableSlot(typeof(x)))
_slot_text(x::VersionNumber)::String = string("v", _ns(string(x)))
_slot_text(x::Type)::String = string("t", _ns(_type_text(x)))
# DATA SLOTS HOLD DATA: a `Function` encodes by NAME only in the DESIGNATED callable
# fields (setter/getter/validate — each a snapshot leaf the door compares by `===`);
# inside a declared DATA value (`Declared.value`, any container in it) a
# same-named function from another module would be invisible to the key text (as to the former fingerprint it fed) AND, were it not
# refused, indistinguishable in the text, so a function there is UNENCODABLE (refused at
# validation; the snapshot door would separately fire on the identity move).
const _IN_DATA = Base.ScopedValues.ScopedValue{Bool}(false)
# The STRUCTURAL callable name — `nameof` is extensible, and a
# Function can legitimately appear as an isbits TYPE PARAMETER of a declared signature
# (`Store{tag}` — measured: reflection's param render dispatched a pirated `nameof`
# raw out of validate). `_callable_text` reads TypeName fields only; for an ordinary
# named function the text is IDENTICAL to the old `nameof` render (suite-asserted);
# a closure's text differs — the same benign exotic-registrant text class already
# disclosed.
_slot_text(f::Function)::String =
    _IN_DATA[] ? throw(_UnencodableSlot(typeof(f))) : string("f", _ns(_callable_text(f)))
# CYCLE-aware container encoding: a published mutable container mutated into a
# cycle (`push!(v, v)`) must be REFUSED at the door as a mutation, never recursed into a
# StackOverflowError. The visiting set is task-local per top-level encode.
const _SLOT_VISITING = Base.ScopedValues.ScopedValue{Union{Nothing,Base.IdSet{Any}}}(nothing)
struct _CyclicSlot <: Exception; end
function _slot_container(open::String, close::String, v)
    vis = _SLOT_VISITING[]
    if vis === nothing
        return Base.ScopedValues.with(_SLOT_VISITING => Base.IdSet{Any}()) do
            _slot_container(open, close, v)
        end
    end
    v in vis && throw(_CyclicSlot())
    push!(vis, v)
    try
        return string(open, _nsv(_slot_text(e) for e in v), close)
    finally
        delete!(vis, v)
    end
end
# CONCRETE containers only: a range, a view or a user AbstractVector/AbstractDict
# would fold content-only (`1:3` ≡ `[1,2,3]` — an undisclosed collision) and sits outside the
# domain copier's closed rebuild classes (`deepcopy` is never dispatched anywhere) —
# outside the closed domain, refused.
_slot_text(v::Vector)::String = _slot_container("[", "]", v)
_slot_text(v::Tuple)::String = string("<", _nsv(_slot_text(e) for e in v), ">")
_slot_text(p::Pair)::String = string("(", _nsv((_slot_text(p.first), _slot_text(p.second))), ")")
# Dicts are cycle-guarded like vectors and CANONICAL: entries sorted by their
# ENCODED text (a `string`-keyed sort left `:x` vs `"x"` in iteration order — non-deterministic).
function _slot_text(d::Dict)::String
    vis = _SLOT_VISITING[]
    if vis === nothing
        return Base.ScopedValues.with(_SLOT_VISITING => Base.IdSet{Any}()) do
            _slot_text(d)
        end
    end
    d in vis && throw(_CyclicSlot())
    push!(vis, d)
    try
        entries = [string(_ns(_slot_text(k)), _ns(_slot_text(v))) for (k, v) in d]
        return string("{", _nsv(sort!(entries)), "}")
    finally
        delete!(vis, d)
    end
end
_slot_text(nt::NamedTuple)::String =
    string("N", _nsv(string(_ns(String(k)), _ns(_slot_text(getfield(nt, k)))) for k in keys(nt)))
_slot_text(x::NoDefault)::String = "NoDefault"
_slot_text(x::Declared)::String =
    Base.ScopedValues.with(_IN_DATA => true) do; string("Declared", _ns(_slot_text(x.value))) end
_slot_text(x::CaptureDecl)::String =   # the stem joined a former seal's fold (the fold was removed); the instance type, the multiplicity and the mode gate were removed from the row within the 0.4 development
    string("Capture", _nsv((String(x.attr_scheme), _slot_text(x.attr_stem))))
# NO opaque fallback: a value of a type without an encoder is UNENCODABLE — refused
# at validation as `REG_PROTOCOL`; a value type admitted later gets its own encoder then.
_slot_text(x)::String = throw(_UnencodableSlot(typeof(x)))

## ————————————————————————————————————————————————————————————————————————————————————————
## THE ONE DOMAIN + the three walks: ONE leaf
## predicate (`_domain_leaf`) is the law for `validate` (the domain walk), the domain COPIER
## `_domain_copy` (publish stages 1+2 and the contained `RegistryBuilder(published)` route)
## and the deep-egal COMPARATOR `_deep_egal` (the one-check door). Leaves are carried BY
## REFERENCE and compared by `===` ONLY; containers are REBUILT at their exact concrete
## types and walked element-/field-wise; everything else is outside the domain. All three
## walks are ITERATIVE — explicit work stacks, no native recursion anywhere, probe frames
## included.

"The enumerated machine-scalar run of the closed value domain (**Bool IS in** —
`Bool <: Integer`, the Bool arm of the encoder)."
const _MACHINE_REAL = Union{Bool, Int8, Int16, Int32, Int64, Int128,
                            UInt8, UInt16, UInt32, UInt64, UInt128,
                            Float16, Float32, Float64}
const _MACHINE_INT = Union{Bool, Int8, Int16, Int32, Int64, Int128,
                           UInt8, UInt16, UInt32, UInt64, UInt128}

# the parts-recursive numeric arm, matching the encoder exactly:
# `Complex`/`Rational` OF the machine run, parts-recursively — `Complex{Rational{Int64}}`,
# `Complex{Bool}` and `Rational{Bool}` admit; `BigInt` parts fall to the else-arm exactly
# as today. Bounded: Complex parts are `<:Real`, so the recursion depth is ≤ 2.
# The Complex/Rational PARTS read via `getfield` — `real`/`imag`/
# `numerator` are EXTENSIBLE generics, and a legitimate specialization on
# `Complex{TheirReal}` executed (and threw) from the domain predicate BEFORE any guard
# (measured). Field reads are byte-identical for every legal value (`real(z)` IS
# `z.re`), so nothing legal moves.
_numeric_leaf(x)::Bool = x isa _MACHINE_REAL ||
    (x isa Rational && getfield(x, :num) isa _MACHINE_INT) ||
    (x isa Complex && _numeric_leaf(getfield(x, :re)) && _numeric_leaf(getfield(x, :im)))

"""
    _domain_leaf(x) -> Bool

IS: THE ONE leaf predicate of the closed value domain — enumerated, never `isbits`
(which would admit `Char`, enums and opaque isbits structs the domain refuses).

DOES: answers true for `Function` · `Type` · `Symbol` · `Nothing` · `String` (VALUES are `String`-only — a non-`String`
`AbstractString` value is OUTSIDE the domain; `AbstractString` stays a legal `Type` leaf) · `VersionNumber` · the
machine scalars (`_MACHINE_REAL`, Bool included) · `Complex`/`Rational` of those, parts-recursively (`_numeric_leaf`,
`getfield` reads — no extensible generic runs); false for everything else. Leaves are carried by reference by the
copier and compared by `===` only by the comparator (bitwise on isbits — NaN payloads and signed zero stay detected;
`String` content-egal; `VersionNumber` field-wise egal; `Function`/`Type`/`Symbol` by identity). Position rules (a
`Function` only in a designated callable field, never inside declared data — DATA WINS) live in the walks, not here.
Its readers: the validate walk (`_domain_slot_probe!`, `_type_budget_check`), the copier `_domain_copy` and the
comparator `_egal_cmp`.

REASONING: one enumerated predicate is the law for all three walks — `validate`, the copier and the door — so the
domain cannot drift between them, and nothing a registrant can extend is dispatched to decide membership.

PURPOSE: the membership test of a declared value, shared by the registration's probe, copy and door.
"""
_domain_leaf(x)::Bool =
    x isa Function || x isa Type || x isa Symbol || x === nothing || x isa String ||
    x isa VersionNumber || _numeric_leaf(x)

## the per-record explicit field lists — 9/4 (the read-time hook `onRead`, a designated callable field, the ninth Alterant-record field; the four action fields of 0.4.0: the settribute slot, the action's default slot and the overload rows were removed within the 0.4 development, the Alterant's default slot added), each asserted against the compiler at
## load; the two record structs are POSITION-RESTRICTED walker
## containers (elements of `plugins`/`action_specs`; a third, `ActionOverload` inside the overloads slot, was removed within the 0.4
## development) and are REFUSED anywhere else, declared data included.
const _WALK_PLUGIN_FIELDS = (:altName, :setMode, :altConstructor, :setAltInstance,
    :getAltInstance, :precedencesTuple, :default, :capture, :onRead)
@assert _WALK_PLUGIN_FIELDS == fieldnames(Alterant)
const _WALK_ACTION_FIELDS = (:name, :plugin, :accepts_string_slot, :validate)   # the former settribute slot was removed
@assert _WALK_ACTION_FIELDS == fieldnames(ActionSpec)

"The 3 record-reachable slot-struct types (walked field-wise GENERICALLY; rebuilt
positionally at `typeof(x)`; two vocabulary slot types, nine carried declarations and a security frame of the 0.4 development
were removed)."
const _SLOT_STRUCTS = (CaptureDecl, NoDefault, Declared)
const _SLOT_STRUCT_UNION = Union{CaptureDecl, NoDefault, Declared}
const _RECORD_STRUCT_UNION = Union{Alterant, ActionSpec}

# a VALUE-domain container at any position (the record structs are position-restricted and
# handled by the walks' `rk` class, never by this predicate); CONCRETE classes only —
# `Vector`/`Dict` are the concrete Base types, so ranges/views/user containers fall through
_value_container(x)::Bool = x isa Vector || x isa Dict || x isa Tuple || x isa Pair ||
                            x isa NamedTuple || x isa _SLOT_STRUCT_UNION

"Predicate 2's totality bound (THE BUDGET LAW): the node budget of the
iterative type-parameter walk. A budget-PASSING type has a whole parameter TREE of ≤ this
many nodes, so every text-encoder recursion over it is depth-bounded, with NO catch (catching
`StackOverflowError` is shape-dependent at the Julia semantics (measured) — and
is never a design premise). The MINT it bounded — a former seal's digest — was removed;
the bound stays as the domain's declared closure, bounding the key-order text."
const _TYPE_BUDGET = 256

# the ITERATIVE budgeted type walk: EVERY child type node is descended — `DataType`
# parameters, `UnionAll` var/body, `Union` a/b, `TypeVar` lb/ub, `Vararg` T/N (measured:
# a UnionAll wrapping a deep body would count as ONE node under a counted-not-
# descended reading, yet `string()` on it recurses to a StackOverflowError at the mint —
# so the walk descends everything). A NON-type value parameter is leaf-checked (the
# `Val{'c'}` refusal).
# EVERY type-graph read below is `getfield` — property syntax
# lowers through the EXTENSIBLE `getproperty`, and a registered
# `Base.getproperty(::Type{Theirs}, ::Symbol)` specialization threw out of the budget
# walk BEFORE any gate it feeds (measured). `getfield`/`isa`/`isdefined` are builtins.
function _type_budget_check(t)
    stack = Any[t]
    seen = 0
    while !isempty(stack)
        x = pop!(stack)
        seen += 1
        seen > _TYPE_BUDGET && return (:over_budget, Nothing)
        if x isa DataType
            for p in getfield(x, :parameters)
                push!(stack, p)
            end
        elseif x isa UnionAll
            push!(stack, getfield(x, :var))
            push!(stack, getfield(x, :body))
        elseif x isa Union
            push!(stack, getfield(x, :a))
            push!(stack, getfield(x, :b))
        elseif x isa TypeVar
            push!(stack, getfield(x, :lb))
            push!(stack, getfield(x, :ub))
        elseif x isa Core.TypeofVararg
            isdefined(x, :T) && push!(stack, getfield(x, :T))
            isdefined(x, :N) && push!(stack, getfield(x, :N))
        elseif !(x isa Type) && !_domain_leaf(x)
            return (:bad_param, typeof(x))
        end
    end
    return (:ok, Nothing)
end

# the Dict-ORDER budget (the determinism clause:
# a deep VALUE key with a shallow type — a `Vector{Any}` nest — evades the TYPE
# budget alone, and the ordering's `_slot_text` call would recurse unboundedly; so the
# ordering qualification counts the key's VALUE nodes and, at type nodes, their parameter
# trees, ALL against the same `_TYPE_BUDGET`): a budget-passing key bounds `_slot_text`'s
# recursion depth, so the two typed encoder exceptions are the only possible escapes under
# the catch below. Total on cycles too — a cyclic key overruns the budget and falls back.
function _key_order_budget(k)::Bool
    stack = Any[k]
    seen = 0
    while !isempty(stack)
        x = pop!(stack)
        seen += 1
        seen > _TYPE_BUDGET && return false
        if x isa Function
            # A Function ANYWHERE in a key graph fails the order
            # budget outright — the prepass then never encodes the key (live iteration
            # order; the WALK refuses it coded), so no user method executes even
            # contained (measured: the pirated nameof ran TWICE under the old catch)
            return false
        elseif x isa Type || x isa TypeVar || x isa Core.TypeofVararg
            # getfield-only type-graph reads — see _type_budget_check
            if x isa DataType
                for p in getfield(x, :parameters)
                    push!(stack, p)
                end
            elseif x isa UnionAll
                push!(stack, getfield(x, :var))
                push!(stack, getfield(x, :body))
            elseif x isa Union
                push!(stack, getfield(x, :a))
                push!(stack, getfield(x, :b))
            elseif x isa TypeVar
                push!(stack, getfield(x, :lb))
                push!(stack, getfield(x, :ub))
            elseif x isa Core.TypeofVararg
                isdefined(x, :T) && push!(stack, getfield(x, :T))
                isdefined(x, :N) && push!(stack, getfield(x, :N))
            end
        elseif x isa Vector
            for i in 1:length(x)
                isassigned(x, i) || return false                  # the undefined-element guard: no undef read
                push!(stack, x[i])
            end
        elseif x isa Tuple || x isa NamedTuple
            for e in x
                push!(stack, e)
            end
        elseif x isa Dict
            for (k2, v2) in x
                push!(stack, k2)
                push!(stack, v2)
            end
        elseif x isa Pair
            push!(stack, x.first)
            push!(stack, x.second)
        elseif x isa _SLOT_STRUCT_UNION || x isa _RECORD_STRUCT_UNION
            for f in fieldnames(typeof(x))
                push!(stack, getfield(x, f))
            end
        end
    end
    return true
end

# canonical Dict entry order for the VALIDATE walk (deterministic first-failure):
# entries sorted by the encoded key text where EVERY key passes the
# order budget and encodes; ANY over-budget or unencodable key sends the whole Dict to the
# live iteration order (within-run stable). Entries are collected
# by ITERATION — no Dict lookup, so no user `hash`/`isequal` can throw out of `validate`.
function _walk_dict_entries(d::Dict)
    entries = Any[kv for kv in d]
    texts = Vector{Any}(nothing, length(entries))
    for (i, kv) in enumerate(entries)
        k = kv.first
        if _key_order_budget(k)
            texts[i] = try
                _slot_text(k)
            catch e
                # With Function keys blocked at the
                # ORDER BUDGET (no user method can execute) and the encoder family
                # structural, the only expected throw classes here are the encoder's
                # own — anything else is an ENGINE defect and rethrows loudly.
                (e isa _UnencodableSlot || e isa _CyclicSlot) || rethrow()
                nothing
            end
        end
        texts[i] === nothing && return entries
    end
    return entries[sortperm(String[t for t in texts])]
end

"internal walk marker: the bracketed visiting-set removal + per-slot done-cache entry."
struct _PopVisit
    v::Any
end

function _emit_cyclic!(diags, label, ctx, slot)
    push!(diags, Diagnostic(:REG_PROTOCOL, :error, string(
        "GoMeta registry: ", label, " ", repr(ctx), " slot ", slot, " declares a CYCLIC container — a ",
        "declared value must encode canonically (the record shape law)"), ctx))
    return nothing
end
function _emit_unencodable!(diags, label, ctx, slot, T)
    # the offending TYPE renders through the
    # structural zero-dispatch helper — interpolating `T` ran `show`, and a throwing
    # user `show(::IO, ::Type{Theirs})` broke the never-throws chain at the very row
    # refusing their value (measured).
    push!(diags, Diagnostic(:REG_PROTOCOL, :error, string(
        "GoMeta registry: ", label, " ", repr(ctx), " slot ", slot, " declares a value of type ",
        _ctor_type_name(T),
        " which has no canonical encoder — outside the closed encodable domain (the record shape law: ",
        "concrete data only; a Function belongs in a designated callable field, never in a value)"), ctx))
    return nothing
end
function _emit_overbudget!(diags, label, ctx, slot)
    push!(diags, Diagnostic(:REG_PROTOCOL, :error, string(
        "GoMeta registry: ", label, " ", repr(ctx), " slot ", slot, " declares a type that ",
        "exceeds the type-encoder budget (", _TYPE_BUDGET, " nodes — the domain walk's totality bound)"), ctx))
    return nothing
end
function _emit_undef!(diags, label, ctx, slot)
    push!(diags, Diagnostic(:REG_PROTOCOL, :error, string(
        "GoMeta registry: ", label, " ", repr(ctx), " slot ", slot, " declares a container with an ",
        "UNDEFINED element — a declared value must be fully constructed (the record shape law)"), ctx))
    return nothing
end

# ONE (record, slot) probe of the validate walk: the iterative
# two-predicate walk, emitting AT MOST ONE slot-named row — the FIRST failure on the
# deterministic traversal (fields in listed order · Vector/Tuple by index · Pair
# first/second · NamedTuple by name order · Dict per `_walk_dict_entries`). Work items are
# `(value, pos, des)`: `pos` ∈ (:structural, :data) — flipped at the ONE DATA locus
# `Declared.value` and never flipped back (DATA WINS — a Function nested in data is refused);
# `des` = the value sits in a designated callable field (`setAltInstance`/`getAltInstance`/`onRead`/
# `validate`). (The `rk` rank that admitted `ActionOverload` rows inside the overloads slot was removed with them
# — a record struct inside a declared slot is unencodable.)
# Cycle-guarded (visiting `IdSet`, push!/delete! bracketed) with a per-slot DONE-cache on
# the mutable containers; `validate` NEVER throws.
function _domain_slot_probe!(diags::Vector{Diagnostic}, label::String, ctx, slot::Symbol,
                             x, des0::Bool)
    visiting = Base.IdSet{Any}()
    done = Base.IdSet{Any}()
    work = Any[(x, :structural, des0)]
    while !isempty(work)
        item = pop!(work)
        if item isa _PopVisit
            delete!(visiting, item.v)
            push!(done, item.v)
            continue
        end
        (v, pos, des) = item
        if v isa _RECORD_STRUCT_UNION
            return _emit_unencodable!(diags, label, ctx, slot, typeof(v))   # a record struct inside a declared slot (the formerly admitted overload rows were removed)
        elseif v isa Vector || v isa Dict
            v in visiting && return _emit_cyclic!(diags, label, ctx, slot)
            v in done && continue
            push!(visiting, v)
            push!(work, _PopVisit(v))
            if v isa Vector
                for i in 1:length(v)                              # the undefined-element guard
                    isassigned(v, i) || return _emit_undef!(diags, label, ctx, slot)
                end
                for i in length(v):-1:1
                    push!(work, (v[i], pos, false))
                end
            else
                entries = _walk_dict_entries(v)
                for i in length(entries):-1:1
                    push!(work, (entries[i].second, pos, false))
                    push!(work, (entries[i].first, pos, false))
                end
            end
        elseif v isa Declared
            push!(work, (v.value, :data, false))
        elseif v isa _SLOT_STRUCT_UNION
            flds = fieldnames(typeof(v))
            for i in length(flds):-1:1
                push!(work, (getfield(v, flds[i]), pos, false))
            end
        elseif v isa Tuple || v isa NamedTuple
            vals = v isa Tuple ? v : values(v)
            for i in length(vals):-1:1
                push!(work, (vals[i], pos, false))
            end
        elseif v isa Pair
            push!(work, (v.second, pos, false))
            push!(work, (v.first, pos, false))
        elseif v isa Function
            (des && pos === :structural) ||
                return _emit_unencodable!(diags, label, ctx, slot, typeof(v))
        elseif v isa Type
            verdict, badT = _type_budget_check(v)
            verdict === :over_budget && return _emit_overbudget!(diags, label, ctx, slot)
            verdict === :bad_param && return _emit_unencodable!(diags, label, ctx, slot, badT)
        elseif _domain_leaf(v)
            # an in-domain leaf — nothing further to check
        else
            return _emit_unencodable!(diags, label, ctx, slot, typeof(v))
        end
    end
    return nothing
end

# The TOTAL, ZERO-DISPATCH ctor-type renderer. The onion,
# each layer measured: `nameof` covers only DataType/UnionAll (the raw
# MethodError); `string(::Type)` dispatches `show` over Union members (the hostile-show
# class); `nameof` is ITSELF an extensible generic (`Base.nameof(::Type{T})` piracy)
# and throws on a UnionAll whose body is a Union. This form uses
# ONLY builtins — `===`/`isa`/`getfield` — plus Base string ops on concrete Base types:
# the Union walk over `.a`/`.b`, the UnionAll unwrap over `.body`, TypeVar leaves by
# their `.name`, DataType leaves via `.name.name` (TypeName field reads). NO generic a
# registrant can extend runs (the snapshot door's own no-dispatch law). `@nospecialize` +
# the untyped signature: a Union member can BE a TypeVar, which
# is not a `Type`.
function _ctor_type_name(@nospecialize T)
    T === Union{} && return "Union{}"
    T isa Core.TypeVar && return String(getfield(T, :name))
    if T isa Union
        parts = String[]
        U = T
        while U isa Union
            push!(parts, _ctor_type_name(getfield(U, :a)))
            U = getfield(U, :b)
        end
        push!(parts, _ctor_type_name(U))
        return string("Union{", join(parts, ", "), "}")
    end
    U = T
    while U isa UnionAll
        U = getfield(U, :body)                      # structural unwrap — never nameof
    end
    U isa Union && return _ctor_type_name(U)        # a UnionAll wrapping a Union body
    U isa Core.TypeVar && return String(getfield(U, :name))
    return String(getfield(getfield(U, :name), :name))   # DataType: TypeName reads
end

# The zero-dispatch CALLABLE display: interpolating a
# caller-supplied function value runs `show` on its own singleton type, and `nameof` is
# extensible (a legitimate specialization can throw through a diagnostic). TypeName
# field reads only; the leading `#` of a function's singleton-type name is stripped so
# an ordinary function displays as before (`boom_set`, not `#boom_set`).
function _callable_text(@nospecialize f)
    nm = String(getfield(getfield(typeof(f), :name), :name))
    return startswith(nm, "#") ? nm[2:end] : nm
end

"""
    _encodability_collect!(diags, plugins, action_specs) -> nothing

IS: the DOMAIN probe (the record shape law's one remaining row) — replacing
an earlier `_slot_text` probe: the ONE walk with TWO predicates over EVERY record field (plugin × 9 — the ninth `onRead`, the read-time hook; spec × 4 —
the four `ActionSpec` fields of 0.4.0, the settribute slot removed; the overload
rows once walked within removed as well).

DOES: calls `_domain_slot_probe!` once per (record, slot) — every `_WALK_PLUGIN_FIELDS` slot of every `Alterant`, the
designated flag set for `setAltInstance` / `getAltInstance` / `onRead` (the ninth field, since 0.4.2); every `_WALK_ACTION_FIELDS` slot of every `ActionSpec`,
designated for `validate`: predicate 1 = membership AT POSITION (leaves via `_domain_leaf`; the value-domain containers;
the record structs only at their structural positions — inside a declared slot one is unencodable; a `Function` only
in the designated callable fields and never inside declared data; `String`-only string values; no undefined container
element; no cycle); predicate 2 = the type-encoder BUDGET (`_TYPE_BUDGET`) over every admitted `Type` leaf's parameter
tree (a former seal's mint it kept safe was removed; the bound stays as the domain's declared
closure). At most ONE slot-named `REG_PROTOCOL` row per (record, slot), in deterministic order; full collection across
slots and records; `validate` never throws. Returns `nothing`; one caller, `_validate_registration`.

REASONING: every declared value is probed at validate, so the publish copier and the door's walk meet in-domain,
acyclic values only, and a registrant's own methods never run inside the registration's checks.

PURPOSE: the first of the remaining checks — the record shape law, enforced before any value is published.
"""
function _encodability_collect!(diags::Vector{Diagnostic}, plugins::Vector{Alterant}, action_specs::Vector{ActionSpec})
    for p in plugins
        for slot in _WALK_PLUGIN_FIELDS
            _domain_slot_probe!(diags, "alterant", p.altName, slot, getfield(p, slot),
                                slot === :setAltInstance || slot === :getAltInstance || slot === :onRead)   # onRead designated
        end
    end
    for s in action_specs
        for slot in _WALK_ACTION_FIELDS
            _domain_slot_probe!(diags, "action", s.name, slot, getfield(s, slot), slot === :validate)
        end
    end
    return nothing
end

"internal: a value outside the copyable domain met by `_domain_copy` — the offending type
+ the typed segment path to it."
struct _OutsideDomain <: Exception
    T::Type
    path::Vector{Any}
end
"internal: a cycle met by `_domain_copy` on the contained route (path to the revisited
container). Named beside `_OutsideDomain` — both convert to
the coded refusal, never escape a public constructor."
struct _CyclicValue <: Exception
    path::Vector{Any}
end
"internal: a USER method (`hash`/`isequal`/`convert`) thrown while a
rebuilt `Dict` was being filled — the one rebuild step that dispatches user-extensible
code. Converted to a coded refusal at both public copy boundaries, never leaked raw."
struct _RebuildFailed <: Exception
    T::Type
end
"internal: an UNDEFINED container element met by a walk — a
`resize!`-widened published Vector, or an undef-slot declared vector. Refused coded at
validate and the contained route; a divergence at the door."
struct _UndefSlot <: Exception end

"a Dict-key path segment carrying the LIVE key value; two `_Key`s are egal iff their
carried values are `===` (field-wise tuple egal — the property oracle's segment law)."
struct _Key
    k::Any
end

# one in-flight container of the iterative post-order copier
mutable struct _CopyFrame
    src::Any
    cls::Symbol              # :vector | :dict | :tuple | :namedtuple | :pair | :struct | :record
    fpos::Symbol             # this container's own position class
    seg::Any                 # the segment from the parent to THIS container (nothing at a root)
    kids::Vector{Any}
    kpos::Vector{Symbol}
    kdes::Vector{Bool}
    krk::Vector{UInt8}
    ksegs::Vector{Any}
    out::Vector{Any}
    i::Int
end

function _copy_rebuild(fr::_CopyFrame)
    v = fr.src
    if fr.cls === :vector
        T = typeof(v)
        out = T(undef, length(fr.out))
        for (i, c) in enumerate(fr.out)
            out[i] = c
        end
        return out
    elseif fr.cls === :dict
        T = typeof(v)
        out = T()
        n = length(fr.out) ÷ 2
        sizehint!(out, n)
        for j in 1:n
            k = fr.out[2j - 1]
            # the fill dispatches hash/isequal (copy-side only, never the door); a USER
            # method throwing here is contained coded, never leaked raw
            try
                out[k] = fr.out[2j]
            catch e
                e isa InterruptException && rethrow()
                throw(_RebuildFailed(typeof(k)))
            end
        end
        return out
    elseif fr.cls === :tuple
        return (fr.out...,)                    # element types are reproduced exactly, so typeof is too
    elseif fr.cls === :namedtuple
        return typeof(v)((fr.out...,))
    elseif fr.cls === :pair
        return typeof(v)(fr.out[1], fr.out[2])
    else                                       # :struct | :record — positional at the EXACT concrete type
        return typeof(v)(fr.out...)
    end
end

"""
    _domain_copy(x, memo::IdDict{Any,Any}; visiting = nothing, pos = :structural, rk = 0x02)

IS: THE DOMAIN COPIER (NOT `Base.deepcopy` — `deepcopy_internal` is never dispatched, a capturing
closure/callable struct keeps its identity) — the one copy every published value and every preloaded builder goes
through.

DOES: returns a copy of `x`: leaves BY REFERENCE; containers, slot structs and (at structural positions) record structs
REBUILT at their EXACT concrete types (`T = typeof(v)` — THE TYPE LAW; a `Vector`/`Dict` is constructed AS `T` and
filled, never by an inferred comprehension — `_copy_rebuild`); the else-arm throws the internal `_OutsideDomain`; an
undefined `Vector` element throws `_UndefSlot`; a user `hash`/`isequal` thrown at a `Dict` fill is converted to
`_RebuildFailed` (the one rebuild step that dispatches user code). ITERATIVE — an explicit `_CopyFrame` stack with
post-order rebuild, no native recursion. The `memo` is ALWAYS caller-supplied — ONE per copy stage/route, over EVERY
container class (immutables included: `IdDict` egal-keying makes the reuse sound), so sharing is preserved WITHIN a
stage and the copy is linear in the stage's distinct containers. `visiting !== nothing` selects the CONTAINED route
(`RegistryBuilder(published)` through `_copy_published_records` — the one route that meets UNVALIDATED values): the
on-stack cycle guard rides beside the memo, the memo is keyed by `(source, position-class)`, and §1's POSITION rules
are ENFORCED (a `Function` in data or outside a designated field, or a record struct outside its structural position,
throws `_OutsideDomain`); cycles throw `_CyclicValue`. Both carry the path. On the publish route (`visiting ===
nothing`, `publish`'s two stages) the copy is TYPE-based — `validate` has already run, so every value is in-domain and
acyclic. The internal exceptions never leave the public routes: `_route2_refuse` converts all four on the contained
route, `publish`'s copy wrapper the two its route can meet (`_RebuildFailed`, `_UndefSlot`) — each to a coded
`RegistrationRefused`.

REASONING: a later mutation of the builder cannot reach a published registry and vice versa, and no user type can
specialize the copy — the type law and the by-reference leaves keep the copy exact without dispatching anything a
registrant can extend.

PURPOSE: the copy behind publication and behind the preload of a builder from a published value.
"""
function _domain_copy(x, memo::IdDict{Any,Any};
                      visiting::Union{Nothing,Base.IdSet{Any}} = nothing,
                      pos::Symbol = :structural, rk::UInt8 = 0x02)
    contained = visiting !== nothing
    frames = _CopyFrame[]

    pathto(extra) = begin
        p = Any[]
        for f in frames
            f.seg === nothing || push!(p, f.seg)
        end
        extra === nothing || push!(p, extra)
        p
    end

    # step: leaf/memo-hit -> (true, value); container -> pushes a frame, (false, nothing)
    step(v, vpos, vdes, vrk, seg) = begin
        if v isa Function
            contained && (vpos === :data || !vdes) &&
                throw(_OutsideDomain(typeof(v), pathto(seg)))
            return (true, v)
        end
        if v isa _RECORD_STRUCT_UNION
            contained && !(vrk === 0x01 && vpos === :structural) &&
                throw(_OutsideDomain(typeof(v), pathto(seg)))
            mk = contained ? (v, vpos) : v
            haskey(memo, mk) && return (true, memo[mk])
            flds = v isa Alterant ? _WALK_PLUGIN_FIELDS : _WALK_ACTION_FIELDS
            n = length(flds)
            fr = _CopyFrame(v, :record, vpos, seg, Vector{Any}(undef, n), fill(vpos, n),
                            fill(false, n), fill(0x00, n), Vector{Any}(undef, n),
                            Vector{Any}(undef, n), 1)
            for (i, f) in enumerate(flds)
                fr.kids[i] = getfield(v, f)
                fr.ksegs[i] = f
            end
            if v isa Alterant
                fr.kdes[4] = true            # setAltInstance
                fr.kdes[5] = true            # getAltInstance
                fr.kdes[9] = true            # onRead (the ninth field, designated)
            elseif v isa ActionSpec
                fr.kdes[4] = true            # validate
            end
            push!(frames, fr)
            return (false, nothing)
        end
        if v isa Vector || v isa Dict
            mk = contained ? (v, vpos) : v
            haskey(memo, mk) && return (true, memo[mk])
            if contained
                v in visiting && throw(_CyclicValue(pathto(seg)))
                push!(visiting, v)
            end
            if v isa Vector
                n = length(v)
                kidrk = vrk === 0x02 ? 0x01 : 0x00
                fr = _CopyFrame(v, :vector, vpos, seg, Vector{Any}(undef, n), fill(vpos, n),
                                fill(false, n), fill(kidrk, n), Vector{Any}(undef, n),
                                Vector{Any}(undef, n), 1)
                for i in 1:n
                    isassigned(v, i) || throw(_UndefSlot())   # the undefined-element guard
                    fr.kids[i] = v[i]
                    fr.ksegs[i] = i
                end
            else
                n = 2 * length(v)
                fr = _CopyFrame(v, :dict, vpos, seg, Vector{Any}(undef, n), fill(vpos, n),
                                fill(false, n), fill(0x00, n), Vector{Any}(undef, n),
                                Vector{Any}(undef, n), 1)
                i = 1
                for (k2, v2) in v
                    fr.kids[i] = k2
                    fr.ksegs[i] = _Key(k2)
                    fr.kids[i + 1] = v2
                    fr.ksegs[i + 1] = _Key(k2)
                    i += 2
                end
            end
            push!(frames, fr)
            return (false, nothing)
        end
        if v isa Tuple || v isa NamedTuple || v isa Pair || v isa _SLOT_STRUCT_UNION
            mk = contained ? (v, vpos) : v
            haskey(memo, mk) && return (true, memo[mk])
            if v isa Tuple || v isa NamedTuple
                vals = v isa Tuple ? v : values(v)
                names = v isa Tuple ? nothing : fieldnames(typeof(v))
                n = length(vals)
                fr = _CopyFrame(v, v isa Tuple ? :tuple : :namedtuple, vpos, seg,
                                Vector{Any}(undef, n), fill(vpos, n), fill(false, n),
                                fill(0x00, n), Vector{Any}(undef, n), Vector{Any}(undef, n), 1)
                for i in 1:n
                    fr.kids[i] = vals[i]
                    fr.ksegs[i] = names === nothing ? i : names[i]
                end
            elseif v isa Pair
                fr = _CopyFrame(v, :pair, vpos, seg, Any[v.first, v.second],
                                Symbol[vpos, vpos], Bool[false, false], UInt8[0x00, 0x00],
                                Any[:first, :second], Vector{Any}(undef, 2), 1)
            else
                flds = fieldnames(typeof(v))
                n = length(flds)
                fr = _CopyFrame(v, :struct, vpos, seg, Vector{Any}(undef, n), fill(vpos, n),
                                fill(false, n), fill(0x00, n), Vector{Any}(undef, n),
                                Vector{Any}(undef, n), 1)
                for (i, f) in enumerate(flds)
                    fr.kids[i] = getfield(v, f)
                    fr.ksegs[i] = f
                end
                if v isa Declared
                    fr.kpos[1] = :data
                end
            end
            push!(frames, fr)
            return (false, nothing)
        end
        _domain_leaf(v) && return (true, v)
        throw(_OutsideDomain(typeof(v), pathto(seg)))
    end

    ok, val = step(x, pos, false, rk, nothing)
    ok && return val
    while true
        fr = frames[end]
        if fr.i <= length(fr.kids)
            i = fr.i
            ok2, v2 = step(fr.kids[i], fr.kpos[i], fr.kdes[i], fr.krk[i], fr.ksegs[i])
            if ok2
                fr.out[i] = v2
                fr.i += 1
            end
            continue
        end
        built = _copy_rebuild(fr)
        if contained && (fr.cls === :vector || fr.cls === :dict)
            delete!(visiting, fr.src)
        end
        memo[contained ? (fr.src, fr.fpos) : fr.src] = built
        pop!(frames)
        isempty(frames) && return built
        parent = frames[end]
        parent.out[parent.i] = built
        parent.i += 1
    end
end

## ————— the deep-egal COMPARATOR: ONE explicit machine — work-stack
## frames; a Dict entry-probe is a PROBE FRAME on the same stack carrying its overlay
## guard segment + backtracking state; NO native probe recursion. GUARD: a
## `Base.IdSet{Any}` of `(live, snap)` tuples per segment — the spine plus one overlay per
## active probe; a probe's guard view = the EFFECTIVE guard (the spine ∪ every enclosing
## overlay); a pair anywhere in it returns equal (coinductive — termination on tandem
## cycles at any depth); an overlay is DISCARDED on rejection and on acceptance MERGES
## into the ENCLOSING segment. There is NO outcome memo (a simplification —
## degenerate nested duplicate-equal-key rejected-twin towers are exponential-in-depth by
## disclosure). The door dispatches NO user-extensible method anywhere —
## no `hash`, no `isequal`, no `==`, no user `show` (rendering included): Dicts are
## compared by the ONE-PATH structural ENTRY-MATCHING law — every snapshot entry must
## match a not-yet-consumed live entry with `_deep_egal`-equal stored KEY AND VALUE
## (greedy over entries is maximum: entry-equality is a product of two partial
## equivalences).

"the first divergence of the deep-egal walk: the typed segment path (`Symbol` field ·
`Int` index · `_Key`) + the reason (:typeof | :size | :leaf | :outside_domain | :key_set
| :entry)."
struct _Divergence
    path::Vector{Any}
    reason::Symbol
end

struct _EgalTask
    a::Any                   # live
    b::Any                   # snapshot
    path::Any                # linked (parentnode, seg); nothing at a root
    pos::Symbol
    des::Bool
    rk::UInt8
end

mutable struct _EgalDict
    lk::Vector{Any}; lv::Vector{Any}      # live entries, iteration order
    sk::Vector{Any}; sv::Vector{Any}      # snapshot entries
    consumed::Vector{Bool}
    si::Int                               # current snapshot entry
    stage::Symbol                         # :keys | :values
    ci::Int                               # keys: live index last probed; values: index into matched
    matched::Vector{Int}                  # key-matched live indices, counted over ALL entries
    path::Any
    pos::Symbol
    ws_base::Int
    probe_state::Int8                     # 0 = none · 1 = pending/succeeded · -1 = failed
end

struct _EgalProbe
    frame::_EgalDict
    ws_base::Int
end

function _egal_guard!(guards::Vector{Base.IdSet{Any}}, a, b)::Bool
    p = (a, b)
    for g in guards
        p in g && return true
    end
    push!(guards[end], p)
    return false
end

function _linked_to_vec(p)
    segs = Any[]
    while p !== nothing
        push!(segs, p[2])
        p = p[1]
    end
    reverse!(segs)
    return segs
end

# compare one task; returns nothing (children pushed / equal) or (linkedpath, reason)
function _egal_cmp(t::_EgalTask, work, guards)
    a = t.a
    b = t.b
    if a isa _RECORD_STRUCT_UNION || b isa _RECORD_STRUCT_UNION
        (t.rk === 0x01 && t.pos === :structural) || return (t.path, :outside_domain)
        (a isa _RECORD_STRUCT_UNION && b isa _RECORD_STRUCT_UNION &&
            typeof(a) === typeof(b)) || return (t.path, :typeof)
        _egal_guard!(guards, a, b) && return nothing
        flds = a isa Alterant ? _WALK_PLUGIN_FIELDS : _WALK_ACTION_FIELDS
        for i in length(flds):-1:1
            f = flds[i]
            des = (a isa Alterant && (f === :setAltInstance || f === :getAltInstance || f === :onRead)) ||   # onRead designated
                  (a isa ActionSpec && f === :validate)
            push!(work, _EgalTask(getfield(a, f), getfield(b, f), (t.path, f), t.pos, des, 0x00))
        end
        return nothing
    end
    if _value_container(a) || _value_container(b)
        typeof(a) === typeof(b) || return (t.path, :typeof)
        _egal_guard!(guards, a, b) && return nothing
        if a isa Vector
            length(a) == length(b) || return (t.path, :size)
            kidrk = t.rk === 0x02 ? 0x01 : 0x00
            for i in length(a):-1:1
                # an UNDEFINED element (a resize!-widened live vector)
                # never reads: assignment-state divergence FIRES at the element path; a
                # conforming snapshot has no undef slot, so both-undef only means equal
                la = isassigned(a, i)
                lb = isassigned(b, i)
                if !(la && lb)
                    la === lb || return ((t.path, i), :leaf)
                    continue
                end
                push!(work, _EgalTask(a[i], b[i], (t.path, i), t.pos, false, kidrk))
            end
        elseif a isa Dict
            length(a) == length(b) || return (t.path, :size)
            lk = Any[]; lv = Any[]
            for (k, v) in a
                push!(lk, k); push!(lv, v)
            end
            sk = Any[]; sv = Any[]
            for (k, v) in b
                push!(sk, k); push!(sv, v)
            end
            push!(work, _EgalDict(lk, lv, sk, sv, fill(false, length(lk)), 1, :keys, 0,
                                  Int[], t.path, t.pos, 0, Int8(0)))
        elseif a isa Tuple
            length(a) == length(b) || return (t.path, :size)
            for i in length(a):-1:1
                push!(work, _EgalTask(a[i], b[i], (t.path, i), t.pos, false, 0x00))
            end
        elseif a isa NamedTuple
            flds = fieldnames(typeof(a))
            for i in length(flds):-1:1
                f = flds[i]
                push!(work, _EgalTask(getfield(a, f), getfield(b, f), (t.path, f), t.pos, false, 0x00))
            end
        elseif a isa Pair
            push!(work, _EgalTask(a.second, b.second, (t.path, :second), t.pos, false, 0x00))
            push!(work, _EgalTask(a.first, b.first, (t.path, :first), t.pos, false, 0x00))
        else                                     # slot struct — generic, with the data flips
            flds = fieldnames(typeof(a))
            for i in length(flds):-1:1
                f = flds[i]
                pos2 = (a isa Declared && f === :value) ? :data : t.pos
                des2 = false                               # no slot struct carries a designated callable
                push!(work, _EgalTask(getfield(a, f), getfield(b, f), (t.path, f), pos2, des2, 0x00))
            end
        end
        return nothing
    end
    # leaves — the outside-domain test PRECEDES the `===` compare; the position rules bind
    # the outside-domain arm (a Function in data or outside a designated field, either side)
    aok = _domain_leaf(a) && !(a isa Function && (t.pos === :data || !t.des))
    bok = _domain_leaf(b) && !(b isa Function && (t.pos === :data || !t.des))
    (aok && bok) || return (t.path, :outside_domain)
    return a === b ? nothing : (t.path, :leaf)
end

function _egal_probe!(fr::_EgalDict, work, guards, probes, task::_EgalTask)
    push!(work, fr)
    fr.ws_base = length(work)
    push!(guards, Base.IdSet{Any}())
    push!(probes, _EgalProbe(fr, fr.ws_base))
    fr.probe_state = Int8(1)
    push!(work, task)
    return nothing
end

# one step of a Dict frame: resolve a pending probe, then advance the entry-matching
# machine. Returns nothing (probe launched / dict equal) or (linkedpath, reason).
function _egal_dict_step(fr::_EgalDict, work, guards, probes)
    n = length(fr.lk)
    if fr.probe_state != 0
        ok = fr.probe_state == Int8(1)
        if ok                                    # the probe drained without divergence: ACCEPT —
            seg = pop!(guards)                   # its overlay MERGES into the enclosing segment
            union!(guards[end], seg)
            pop!(probes)
        end                                      # (on failure the unwinder discarded overlay + record)
        fr.probe_state = Int8(0)
        if fr.stage === :keys
            ok && push!(fr.matched, fr.ci)
        elseif ok
            fr.consumed[fr.matched[fr.ci]] = true
            fr.si += 1
            fr.stage = :keys
            fr.ci = 0
            empty!(fr.matched)
        end
    end
    while true
        fr.si > length(fr.sk) && return nothing  # every snapshot entry matched — the pair is equal
        if fr.stage === :keys
            fr.ci += 1
            if fr.ci <= n
                _egal_probe!(fr, work, guards, probes,
                             _EgalTask(fr.lk[fr.ci], fr.sk[fr.si], nothing, fr.pos, false, 0x00))
                return nothing
            end
            isempty(fr.matched) && return (fr.path, :key_set)   # no key-match at all ⇒ CONTAINER
            fr.stage = :values
            fr.ci = 0
        else
            fr.ci += 1
            while fr.ci <= length(fr.matched) && fr.consumed[fr.matched[fr.ci]]
                fr.ci += 1
            end
            if fr.ci <= length(fr.matched)
                _egal_probe!(fr, work, guards, probes,
                             _EgalTask(fr.lv[fr.matched[fr.ci]], fr.sv[fr.si], nothing, fr.pos, false, 0x00))
                return nothing
            end
            # no unconsumed key-matched entry's value matched: EXACTLY ONE key-matched live
            # entry (over ALL, consumed included) with a failing value ⇒ that entry's ELEMENT
            # path; every other no-entry-match outcome (the duplicate-equal-key class) ⇒ the
            # CONTAINER path
            if length(fr.matched) == 1 && !fr.consumed[fr.matched[1]]
                return ((fr.path, _Key(fr.lk[fr.matched[1]])), :entry)
            end
            return (fr.path, :entry)
        end
    end
end

"""
    _deep_egal(live, snap) -> Union{Nothing, _Divergence}

IS: the deep-egal COMPARATOR of the snapshot door — ONE explicit machine over a work stack,
no native recursion.

DOES: returns the first divergent typed-segment path with its reason (`_Divergence`: `:typeof` | `:size` | `:leaf` |
`:outside_domain` | `:key_set` | `:entry`), or `nothing` when the pair is content-structurally equal.
Container-type-FIRST dispatch (`_egal_cmp`): record structs at their structural position, then the value-domain
containers, then leaves; per-class gates (`typeof` → size → element-wise; an undefined `Vector` element compares by
its assignment state); leaves by `===` ONLY, after the outside-domain test with the position rules; alias topology is
NOT significant (the pair guard makes shared DAGs and even both-sided cycles terminate); Dicts by the one-path
structural entry-matching law (`_egal_dict_step`: every snapshot entry must match a not-yet-consumed live entry with
equal key AND value; a probe's guard overlay merges on acceptance, is discarded on rejection; no outcome memo). A
fresh spine guard per call. The door dispatches NO user-extensible method — no `hash`, `isequal`, `==` or user `show`.
Its callers: `_registry_door_check` (per `_SNAPSHOT_FIELDS` field) and the snapshot property tests.

REASONING: the live fields against the publish-time snapshot, by content and structure alone, is the ONE check that
detects a post-publication mutation by conforming code without running anything a registrant can extend.

PURPOSE: the comparison behind the door's `POST_SEAL_MUTATION` row.
"""
function _deep_egal(live, snap)
    guards = Base.IdSet{Any}[Base.IdSet{Any}()]
    probes = _EgalProbe[]
    work = Any[_EgalTask(live, snap, nothing, :structural, false, 0x02)]
    while !isempty(work)
        t = pop!(work)
        d = t isa _EgalDict ? _egal_dict_step(t, work, guards, probes) :
                              _egal_cmp(t, work, guards)
        d === nothing && continue
        isempty(probes) && return _Divergence(_linked_to_vec(d[1]), d[2])
        pr = pop!(probes)                        # the innermost probe FAILS: candidate rejected
        resize!(work, pr.ws_base)                # its frame is back on top
        pop!(guards)                             # overlay DISCARDED — with every pair merged
        pr.frame.probe_state = Int8(-1)          # into it by nested accepted probes
    end
    return nothing
end

## non-dispatching diagnostic rendering (measured): a
## Base-owned leaf key renders by `repr` (its `show` is Base-owned; a user method on a
## Base-owned type is piracy, outside conforming code — the disclosed boundary);
## `Type`/`Function` keys render as fixed category text; container/struct keys via
## `nameof(typeof(k))`. The door dispatches NO user-extensible method — rendering included.
_render_key(k)::String =
    (k === nothing || k isa Symbol || k isa String || k isa VersionNumber || _numeric_leaf(k)) ?
        repr(k) :
    k isa Type ? "<Type key>" :
    k isa Function ? "<Function key>" :
    string("<", String(nameof(typeof(k))), " key>")

"render a typed segment path for a diagnostic message (rendering is one-way — the
property oracle compares SEGMENTS, never rendered strings)."
function _render_path(segs::Vector{Any})::String
    io = IOBuffer()
    for (i, s) in enumerate(segs)
        if s isa Symbol
            i == 1 ? print(io, s) : print(io, ".", s)
        elseif s isa Int
            print(io, "[", s, "]")
        elseif s isa _Key
            print(io, "[", _render_key(s.k), "]")
        else
            print(io, "[?]")
        end
    end
    return String(take!(io))
end

"the §3 disjointness assert: no MUTABLE container (`Vector`/`Dict`) is shared between the
live field values and the snapshot (designated leaves ARE shared by reference — by design;
immutable rebuilt containers are fresh by construction of the stage-2 copy). A bare
runtime `@assert` — the witnesses carry the testable part."
function _assert_snapshot_disjoint(live::NamedTuple, snap::NamedTuple)
    collect_mutables(root) = begin
        out = Base.IdSet{Any}()
        stack = Any[root]
        while !isempty(stack)
            v = pop!(stack)
            if v isa Vector || v isa Dict
                v in out && continue
                push!(out, v)
                if v isa Vector
                    for i in 1:length(v)
                        isassigned(v, i) && push!(stack, v[i])    # the undefined-element guard
                    end
                else
                    for (k, v2) in v
                        push!(stack, k)
                        push!(stack, v2)
                    end
                end
            elseif v isa Tuple || v isa NamedTuple
                for e in v
                    push!(stack, e)
                end
            elseif v isa Pair
                push!(stack, v.first)
                push!(stack, v.second)
            elseif v isa _SLOT_STRUCT_UNION || v isa _RECORD_STRUCT_UNION
                for f in fieldnames(typeof(v))
                    push!(stack, getfield(v, f))
                end
            end
        end
        out
    end
    l = collect_mutables(live)
    s = collect_mutables(snap)
    @assert all(x -> !(x in s), l) "GoMeta registry: the publish snapshot shares a mutable container with the live value (the disjointness law)"
    return nothing
end

# a type NAME for the contained route's messages — category text via `nameof`, never a
# dispatched `show`; `nameof` is itself extensible (:1045) — a registrant's own `Base.nameof(::Type{Theirs})` runs here (register M-L2-3)
_domain_type_name(T::Type)::String = String(nameof(T))

function _route2_refuse(r::AlterantRegistry, e, field::Symbol)
    # the two path-less internal classes convert coded too
    if e isa _RebuildFailed || e isa _UndefSlot
        throw(RegistrationRefused([Diagnostic(:REG_PROTOCOL, :error, string(
            "GoMeta registry: RegistryBuilder(published) could not copy field ", field, " (",
            e isa _RebuildFailed ?
                string("a user method thrown while rebuilding a Dict keyed by ", _domain_type_name(e.T)) :
                "an UNDEFINED container element — the published value was mutated after publication",
            ") — the record shape law"), field)]))
    end
    (e isa _OutsideDomain || e isa _CyclicValue) || rethrow()
    p = Any[field]
    append!(p, e.path)
    ptext = _render_path(p)
    recs = field === :plugins ? r.plugins : r.action_specs
    recname = "?"
    slotname = "?"
    if length(p) >= 2 && p[2] isa Int && 1 <= p[2] <= length(recs)
        rec = recs[p[2]]
        recname = String(rec isa Alterant ? rec.altName : rec.name)
        length(p) >= 3 && p[3] isa Symbol && (slotname = String(p[3]))
    end
    msg = if e isa _CyclicValue
        string("GoMeta registry: RegistryBuilder(published) met a CYCLIC container at ", ptext,
               " (record ", repr(recname), ", slot ", slotname, ") — the published value was ",
               "mutated after publication; a declared value must be acyclic (the record shape law)")
    elseif e.T <: Function || e.T <: Alterant || e.T <: ActionSpec
        string("GoMeta registry: RegistryBuilder(published) met a value of type ",
               _domain_type_name(e.T), " at ", ptext, " (record ", repr(recname), ", slot ",
               slotname, ") that violates the position rule — a Function is legal only in a ",
               "designated callable field and a record struct only at its structural registry ",
               "position, never inside declared data")
    else
        string("GoMeta registry: RegistryBuilder(published) met a value of type ",
               _domain_type_name(e.T), " at ", ptext, " (record ", repr(recname), ", slot ",
               slotname, ") — outside the closed copyable domain (the record shape law: ",
               "concrete data only)")
    end
    throw(RegistrationRefused([Diagnostic(:REG_PROTOCOL, :error, msg, ptext)]))
end

"the CONTAINED preload copy behind `RegistryBuilder(published)`:
ONE route memo across both per-field calls; no internal exception and no unbounded
recursion leaves the public constructor."
function _copy_published_records(r::AlterantRegistry)
    memo = IdDict{Any,Any}()
    vis = Base.IdSet{Any}()
    plugins = try
        _domain_copy(r.plugins, memo; visiting = vis, pos = :structural, rk = 0x02)
    catch e
        _route2_refuse(r, e, :plugins)
    end
    specs = try
        _domain_copy(r.action_specs, memo; visiting = vis, pos = :structural, rk = 0x02)
    catch e
        _route2_refuse(r, e, :action_specs)
    end
    return (plugins, specs)
end

# The slot text's type serialization (the digest it served was removed): module-UNQUALIFIED (stable across load contexts) but
# parameter-FAITHFUL (`Dict{Symbol,Bool}` ≠ `Dict{Symbol,Int}` — a real drift class a bare
# `nameof` would collapse). A NON-type parameter is a VALUE and folds type-tagged
# through `_slot_text` (`Val{Int8(1)}` ≠ `Val{Int64(1)}`, `Val{:x}` ≠ `Val{1}`; a parameter value
# outside the closed domain is unencodable); TypeVar / Vararg parameters keep their text. NOTE
# (recorded limits): UnionAll / Union nodes encode STRUCTURALLY below (never
# `string`), a TypeVar only as a DataType parameter or a UnionAll's variable (as another TypeVar's bound, a Union member or a Vararg element type it throws `_UnencodableSlot` at the end of `_type_text` — the Dict's live-order fallback); two SAME-NAMED types from DIFFERENT modules collide as one identity (the
# unqualified choice's deliberate trade — dispatch treats them as distinct; a second
# type-contributing module is the revisit trigger). No shipped record row reaches these — extend
# consciously.
function _type_text(t)::String
    t === Any && return "Any"
    if t isa DataType
        # `nameof` is an EXTENSIBLE generic — a legitimate
        # `Base.nameof(::Type{Theirs})` specialization could throw through the
        # encoder. The getfield form is OUTPUT-IDENTICAL (`nameof(t::DataType)` IS
        # `t.name.name` — measured across the type ladder, incl. function types), so no
        # text moved; `getfield` is a builtin — no user method can run.
        nm = getfield(getfield(t, :name), :name)
        isempty(getfield(t, :parameters)) && return String(nm)
        return string(nm, "{", join((_type_param_text(p) for p in getfield(t, :parameters)), ","), "}")
    end
    # the Bottom, UnionAll and Union nodes encode STRUCTURALLY (a bare TypeVar has no arm — the throw below) — `string()` on a
    # UnionAll/Union/TypeVar dispatches `show`, and a user's own display method on its own
    # admitted type (legitimate specialization, not piracy) could throw out of the mint. The
    # structural text dispatches nothing (`nameof`/`Symbol` reads only) and stays
    # module-unqualified. Recursion is bounded: every minted type passed predicate 2's
    # descending node budget, so the tree has ≤ `_TYPE_BUDGET` nodes.
    t === Union{} && return "Bottom"
    # getfield-only reads here too — property syntax on a
    # caller-owned type object dispatches the extensible `getproperty`
    t isa UnionAll && return string("where(", _typevar_text(getfield(t, :var)), ",",
                                    _type_text(getfield(t, :body)), ")")
    t isa Union && return string("union(", _type_text(getfield(t, :a)), ",",
                                 _type_text(getfield(t, :b)), ")")
    throw(_UnencodableSlot(typeof(t)))   # reached by an admitted `Type` leaf through a TypeVar in a bound / Union-member / Vararg position — caught at `_walk_dict_entries`
end
_typevar_text(v::TypeVar)::String =
    string("tv(", String(getfield(v, :name)), ",", _type_text(getfield(v, :lb)), ",",
           _type_text(getfield(v, :ub)), ")")
_type_param_text(p)::String =
    p isa TypeVar ? _typevar_text(p) :
    p isa Core.TypeofVararg ? string("va(", isdefined(p, :T) ? _type_text(getfield(p, :T)) : "-", ",",
                                     isdefined(p, :N) ? _type_param_text(getfield(p, :N)) : "-", ")") :
    p isa Type ? _type_text(p) : _slot_text(p)

## The registration's remaining checks at `validate` (a former validation chain
## was removed: the original engine registered unchecked and failed at dispatch): the DOMAIN PROBE (the one domain definition
## shared by `validate`, `publish`'s copier and the door's walker; `publish` relies on it); a former vocabulary check and the Heading's four mode-gate laws
## were removed within the 0.4 development. Then the derived
## tables + the publish-time snapshot + the lifecycle (a former seal's mint was removed).
"""
    _validate_registration(plugins, action_specs) -> Vector{Diagnostic}

IS: the registration's remaining checks at `validate` (a former validation
chain was removed: the original engine registered unchecked and failed at dispatch).

DOES: runs the domain probe over every declared field (`_encodability_collect!`; a former vocabulary
check and the capture mode-gate laws of the Heading's separate path were removed)
into one fresh `Diagnostic` vector and returns it. FULL collection: every defect is
reported; the caller decides the terminal outcome (error present ⇒ refuse). Two callers: `validate(builder)` and the
gated positional `AlterantRegistry` constructor (route U, src/state.jl).

REASONING: one chain, collecting rather than throwing, so a registrant sees every defect at once and `publish` and
route U refuse on the same evidence.

PURPOSE: the one definition of what a registration must satisfy before it is published.
"""
function _validate_registration(plugins::Vector{Alterant}, action_specs::Vector{ActionSpec})
    diags = Diagnostic[]
    _encodability_collect!(diags, plugins, action_specs)   # the domain probe
    return diags
end

"The derived hot-path tables, computed from the DECLARED record only (never hand-supplied)."
function _derive_tables(plugins::Vector{Alterant}, action_specs::Vector{ActionSpec})
    owner_of_action = Dict{Symbol,Int8}()
    for spec in action_specs
        haskey(owner_of_action, spec.name) || (owner_of_action[spec.name] = spec.plugin)   # first-wins
    end
    sorted_alt_actions = sort!(collect(keys(owner_of_action)))
    spec_index = Dict{Symbol,Int}()
    for (i, s) in enumerate(action_specs)
        haskey(spec_index, s.name) || (spec_index[s.name] = i)   # first-wins, as owner_of_action above (the original engine's Dict assignment was last-wins)
    end
    return (
        sorted_alt_actions   = sorted_alt_actions,
        action_to_plugin     = Int8[owner_of_action[a] for a in sorted_alt_actions],
        action_index         = Dict{Symbol,Int8}(a => Int8(i) for (i, a) in enumerate(sorted_alt_actions)),
        alt_index            = Dict{Symbol,Int8}(p.altName => Int8(i) for (i, p) in enumerate(plugins)),
        accum_alt_idxs       = sort!(Int8[i for (i, p) in enumerate(plugins) if p.setMode === :accumulate]),
        mutex_alt_idxs       = sort!(Int8[i for (i, p) in enumerate(plugins) if p.setMode === :mutExclusive]),
        spec_index           = spec_index,
    )
end

"""
    validate(builder::RegistryBuilder) -> Vector{Diagnostic}

IS: the lifecycle's VALIDATE step (Builder → validate → publish; package-public, docs/public-api.md §1.2) over a
builder's declarations.

DOES: Run the remaining check (the domain probe — a former vocabulary check and the mode-gate laws of the
Heading's separate path were removed) over
the builder's declarations (`plugins` and `action_specs`, through `_validate_registration`) and return EVERY
diagnostic (deterministic order; no remaining check warns) — never throws. Empty ⇒ publishable.
`publish` calls it first; a caller wanting the diagnostics as data calls it itself.

REASONING: full collection before the one terminal outcome — the defects as data, the refusal `publish`'s.

PURPOSE: the registrant's own check of a declaration before publishing it.
"""
validate(b::RegistryBuilder) = _validate_registration(b.plugins, b.action_specs)

"""
    publish(builder::RegistryBuilder) -> AlterantRegistry

IS: the lifecycle's PUBLISH step — the SANCTIONED route to a SEALED registry, the only SUPPORTED one for conforming
callers (not the only possible one in-process: the construction token and this file's helpers are reachable by any
loaded module, the accident-grade bound recorded at `_SealToken`).

DOES: refuses (throws `RegistrationRefused` carrying every diagnostic) if `validate` reports any error; proceeds on
warnings, each emitted by `@warn` at publication (never swallowed; none is minted today). Atomic
COPY-publication, two stages, each by the domain copier `_domain_copy` — callables/Types/Symbols/Strings/
VersionNumbers/numbers carried BY REFERENCE, containers and slot structs REBUILT at their exact concrete types,
sharing preserved within each copy stage; `deepcopy_internal` is never dispatched, so no user type can specialize the
copy (a later mutation of the builder cannot reach a published registry, and vice versa). STAGE 1: the builder's
`plugins` and `action_specs` copied under ONE memo; the derived tables (`_derive_tables`) computed from those copies —
the derived tables come from the declarations alone. STAGE 2: the `_snapshot` baseline — a SECOND, disjoint domain
copy of all nine `_SNAPSHOT_FIELDS` (eleven at one point of the 0.4 development — a `seal` fingerprint field and the
settribute table were removed before 0.4.0) under a SEPARATE memo, built mechanically over the
field-name tuple; the disjointness asserted (`_assert_snapshot_disjoint`); the value constructed through the
token-gated constructor `AlterantRegistry(_SealToken(), …)`. A copy that cannot complete — a user `hash`/`isequal`
thrown at a `Dict` rebuild, an undefined container element — converts to a coded `RegistrationRefused`
(`REG_PROTOCOL`), never a raw exception. The published value's containers are READ-ONLY by contract — a mutation
through them is detected at the door (`POST_SEAL_MUTATION`) by the structural deep-egal comparison against the
snapshot, never silently effective — for conforming code (the disclosed bounds apply, docs/public-api.md §1.2).

REASONING: validate first, then copy, so the copy is type-based over in-domain, acyclic values; two memos so live and
snapshot share no mutable container — the door's comparison then has a baseline nothing conforming code can reach
through the live fields.

PURPOSE: the one route to a published value — what `goMeta`'s door accepts and what `DEFAULT_REGISTRY` is.
"""
function publish(b::RegistryBuilder)
    diags = validate(b)
    any(d -> d.severity === :error, diags) && throw(RegistrationRefused(diags))
    # Warnings are NEVER swallowed by the sanctioned route: every warning
    # diagnostic is emitted at publication (0.3.2's load-time @warn behavior kept); a caller
    # wanting them as data calls `validate` first.
    for d in diags
        d.severity === :warning && @warn d.message
    end
    # The publication's STAGE 1: the LIVE field values by the domain copier — validate
    # has run, so every value is in-domain and acyclic (predicate ground per field: validate
    # reaches `plugins`/`action_specs`; the derived tables are grounded in their concrete
    # declared types + their construction from the already-copied record) — ONE stage-1 memo.
    # the ONE remaining escape class — a USER `hash`/`isequal`
    # thrown at a Dict rebuild fill, or an undefined element racing in after validate —
    # converts to the coded refusal here, never a raw exception out of `publish`.
    copyc = (x, m) -> try
        _domain_copy(x, m)
    catch e
        (e isa _RebuildFailed || e isa _UndefSlot) || rethrow()
        throw(RegistrationRefused([Diagnostic(:REG_PROTOCOL, :error, string("GoMeta registry: the ",
            "declared record could not be copied for publication (", e isa _RebuildFailed ?
            string("a user method thrown while rebuilding a Dict keyed by ", _domain_type_name(e.T)) :
            "an UNDEFINED container element", ") — the record shape law"), nothing)]))
    end
    m1 = IdDict{Any,Any}()
    plugins = copyc(b.plugins, m1)
    specs   = copyc(b.action_specs, m1)
    t = _derive_tables(plugins, specs)
    # The publication's STAGE 2: the SNAPSHOT — built MECHANICALLY over the field-name tuple (no per-table
    # keyword binding anywhere); ONE second-stage memo, SEPARATE from the first stage's, so live and snapshot
    # share no mutable container (the disjointness assert below). (A former seal's mint and its catch were removed
    # with the fingerprint's one consumer, the grammar profile.)
    base = (; plugins = plugins, action_specs = specs, t...)
    snapshot = let m2 = IdDict{Any,Any}()
        NamedTuple{_SNAPSHOT_FIELDS}(map(k -> copyc(base[k], m2), _SNAPSHOT_FIELDS))
    end
    _assert_snapshot_disjoint(base, snapshot)
    return AlterantRegistry(_SealToken(), plugins, specs, t, snapshot)
end

"""
    _registry_door_check(registry) -> Vector{Diagnostic}

IS: the STRICT door of `goMeta` — the published-only entry — in its ONE-CHECK form:
the ONE entry refusal since 0.4.0.

DOES: returns the door's diagnostics, empty when the registry passes. An UNPUBLISHED registry (`_snapshot === nothing`)
refuses coded — one `REG_UNPUBLISHED` error row naming the sanctioned path (RegistryBuilder → validate → publish); else
the nine `_SNAPSHOT_FIELDS` are compared field-by-field against the
publish-time snapshot by the ONE structural deep-egal walk (`_deep_egal`: `===`-only leaves; no
`hash`/`isequal`/`==`/user `show` dispatched anywhere, rendering included) and the FIRST divergent path fires exactly
one `POST_SEAL_MUTATION` row (the loop breaks at the first; the path rendered by `_render_path` as the row's message
and context) — the real freeze gate, accident-grade: coded refusal of post-seal mutation by conforming code.
Its one Engine caller is `goMeta`, before the parse: a non-empty return becomes the fail-closed `PROCESS_ERROR`
delivery (`_entryErrorDelivery`). The retired seal re-mint, derived-table re-derivation and callable-identity compare
lose no detection for conforming code (the field lists being COMPLETE): re-derivation is deterministic, so it never
catches what the snapshot cannot; the same-typed table swap is excluded by the by-name construction; every callable
identity — altConstructor, the setters/getters, `spec.validate` — is a snapshot leaf compared by `===`.

REASONING: one check at the entry, against a baseline the publication took, dispatching nothing a registrant can
extend — the honest bound: an entry check, not a lock over the run; the snapshot's own members are mutable.

PURPOSE: that a run reads only a registry whose declarations are the ones that were validated and published.
"""
function _registry_door_check(registry::AlterantRegistry)
    diags = Diagnostic[]
    if registry._snapshot === nothing
        push!(diags, Diagnostic(:REG_UNPUBLISHED, :error, string("GoMeta registry: the registry passed ",
            "to goMeta is not published — the v0.4 door accepts ONLY published (validated + sealed) ",
            "registries; build it via RegistryBuilder → validate → publish (GoMeta.publish) and pass ",
            "the published value"), nothing))
        return diags
    end
    snap = registry._snapshot
    for f in _SNAPSHOT_FIELDS
        d = _deep_egal(getfield(registry, f), snap[f])
        d === nothing && continue
        path = Any[f]
        append!(path, d.path)
        ptext = _render_path(path)
        push!(diags, Diagnostic(:POST_SEAL_MUTATION, :error, string("GoMeta registry: the ",
            "published registry was MUTATED after publication — at ", ptext, " the live value ",
            "no longer matches the published snapshot; re-publication is the sanctioned ",
            "change path"), ptext))
        break
    end
    return diags
end

"""
    const DEFAULT_REGISTRY :: AlterantRegistry

IS: the v0 default alterant inventory — the PUBLISHED value `build_default_registry()` returns, built ONCE at load and
READ-ONLY thereafter; a package-public name (docs/public-api.md §1.2).

DOES: serves as the default of `goMeta`'s `registry` keyword and as the base a third party extends
(`RegistryBuilder(DEFAULT_REGISTRY)`, then `register!`). Mutating any of its `Dict`/`Vector` fields destroys the
determinism the registry exists to provide, so treat it as frozen: a mutation through them by conforming code is
DETECTED at the entry door (`POST_SEAL_MUTATION`, against its publish-time snapshot), never silently effective. It is
threaded into `ProcessState` via `init_state(parse_state, config, DEFAULT_REGISTRY)`, and the absorb/apply phases read
it from there (`ctx().registry`) rather than from a module global.

REASONING: one deterministic inventory, published through the same lifecycle every registration goes through, held as
a const and read per call through the state — no module-global mutable inventory (the `===` alias onto its
write-back Dict retired).

PURPOSE: the Alterant inventory of a run that names none — the four shipped Alterants and their nine actions.
"""
const DEFAULT_REGISTRY = build_default_registry()

## The `VISIB_TO_SETTRIBUTE` convenience alias is RETIRED (a registered breaking change,
## no forwarding window): it was the SAME `Dict` object as the registry's map (`===`, not a copy),
## i.e. a mutable alias onto the "immutable" inventory — the measured post-publication-mutation
## class the freeze/publication seal closes. The former write-back at both grains read the
## PER-CALL `action_to_settribute` table (derived from the declared per-action settribute slots)
## until the write-back's removal; the table, read by nothing since, was removed as well within the 0.4 development.
## Neither the alias nor the table was ever
## in the `export`/`public` surface (docs/public-api.md §1), so no consumer contract moves.
