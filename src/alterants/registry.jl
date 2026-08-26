# registry.jl — the alterant inventory: the vocabulary-gated setters, state accessors, the default registry
#
# IS: the register file of the alterant layer — two nested sub-modules plus a top-level tail. `module
#     Alterants`: the std vocabulary loader include (v0.4 T4 — the closed label whitelist now lives as
#     the `alterants-std/labels_vocabulary.txt` ARTIFACT, digest-pinned on the labels record) + the toy
#     setters `setLabels`/`checkLabels`/`setVisib`/`setId` over the `@namedElement` types `Visib` (Bool: hide/show/discard)
#     and `Id` (Int16: cell/parent/file). `module CnS`: the per-call state accessors `wipeAltActionSlots`/
#     `updateMetaHierarchy`/`getState`/`getAltState`. The tail builds the immutable `AlterantRegistry`
#     (type: src/state.jl) — `build_default_registry()` → `const DEFAULT_REGISTRY` (v0.4 T1: the former
#     `VISIB_TO_SETTRIBUTE` alias is retired; the write-back table is the generic `action_to_settribute`).
# DOES: declares the closed default inventory (4 alterants / 8 actions since the heading registration) in
#     DECLARATION order (labels=1, Visib=2, id=3, heading=4 — the live keys are :id / :heading) and PUBLISHES
#     it through the v0.4 lifecycle (Builder → validate → publish): the sorted action table, the parallel action→plugin index, the name→index Dicts,
#     the SORTED `accum_alt_idxs` (the apply-phase `insorted` consumer in apply.jl depends on the sort),
#     and the identity Visib-action→settribute-key map. `setLabels` (the `:` labels action) checks every
#     label against the whitelist; an unknown label raises the stable "GoMeta apply: unknown label"
#     refusal, which names the accepted set (docs/public-api.md §3.4). `getState`/`getAltState` read the
#     per-call `ProcessState` via `ctx()` (a ScopedValue — no module-global state). `updateMetaHierarchy`/`wipeAltActionSlots` maintain the meta-hierarchy cursor + the slot
#     tensors on `ctx()` under the single-source `maxDepthMH`/`NUM_MH_LEVELS` consts (src/state.jl).
# REASONING: the inventory is deterministic BY CONSTRUCTION (declaration order, built once, read-only)
#     rather than hanging on any iteration order. The closed condition interpreter
#     (README SECURITY; docs/public-api.md §3.2) is the package's condition surface; the opt-in
#     `:full_eval_v1` extension mode is its one documented replaceable arm.
# EDGES (honest): the label whitelist is closed and fixed — the corpus-documented labels
#     :label1..:label5 plus (since 0.3.0) a fixed pictograph vocabulary (byte-exact names, no
#     normalization); an unknown label meets the stable refusal that
#     names the accepted set. `setId` parses values into the Int16 domain; the value/arity walls
#     around these setters are guarded at the apply seam by the stable "GoMeta apply: invalid arguments"
#     refusal (docs/public-api.md §3.4; tests/unit/arg_guard_tests.jl). Only the labels
#     row has a query getter (`checkLabels`); Visib/Id carry none — `cell`/`parent`/`file` as a
#     condition atom is the deferred E-07 row. `DEFAULT_REGISTRY` is a PUBLISHED, SEALED value (v0.4
#     T2; the T2-bis SNAPSHOT door): its Dict/Vector fields stay mutable containers, but a mutation
#     by CONFORMING code through any of them is DETECTED at the entry door (`POST_SEAL_MUTATION`)
#     by the ONE structural deep-egal comparison against the publish-time snapshot (`===`-only
#     leaves; the fingerprint `seal` is a lossy CACHE KEY with its disclosed collisions —
#     docs/public-api.md §1.2 — never the door's mechanism), never silently effective
#     (accident-grade: a callable's BEHAVIOR is not pinned by its identity, the snapshot's own
#     members are mutable — the disclosed mixed residue, docs §1.2 — and the door is an entry
#     check, not a lock over the run — B-2); the former `===` alias onto its write-back Dict is
#     retired (v0.4 T1).
# PURPOSE: the closed, deterministic alterant inventory + the state accessors the absorb/apply phases consume.

## Alterants — the label / Visib / Id inventory sub-module
module Alterants
#########################################################################################
#########################################################################################
import ..BLS as BLS
using ..BLS.NamedElements
using StaticArrays: SVector

#########################################################################################
#########################################################################################
## Labels.jl for `alterant` `Labels`:

## v0.4 T4 (R-V04B-6 (a); the ruled BUG-FIX, R-V04-20/29): the label vocabulary is NO
## LONGER a Core literal — it is the CONTENT of the Labels record's declared vocabulary
## artifact under `src/alterants-std/` (custody = the Labels lane's, R-LBL-4), loaded by
## the std file below (capture at load; the declared-vs-captured digest re-verify is
## `_vocabulary_collect!`'s publication act, R-V04-37). The former `goMetaLabels` +
## `sortedSetOfLabelsSVec` literals are DELETED; membership reads ride the SCOPE LAW
## (`_vocabulary_for_action` — the invoked action's owning record's declared vocabulary
## inside an engine scope; the shipped vocabulary outside any scope).
include(joinpath(@__DIR__, "..", "alterants-std", "labels_vocabulary.jl"))

function setLabels(
    crntLabels::Dict{Symbol,Bool}, # The Alterant here.
    actionName::Symbol,
    labels::Vararg{Symbol} # 
)

    if actionName == :(:)
        ## §4.8 guard (v0.3.1, "fixed WITHIN THE Labels Alterant"): a lone ':'
        ## (or ':()') reaches this setter with ZERO labels — the vacuous loop below then stored
        ## nothing, minted no evals row, and the author's mistyped label vanished SILENTLY
        ## (probe m_lone_colon). The Alterant verifies its own input: an empty label list
        ## refuses loudly. error() (not ArgumentError) deliberately: the setter seam displays
        ## an ErrorException's message verbatim (the unknown-label mechanics below), while an
        ## ArgumentError's message is discarded to its type name at the seam's conversion.
        isempty(labels) && error("GoMeta apply: empty label list — the labels action ':' ",
            "names no label; v0 requires at least one label (e.g. ':label1'); ",
            "see docs/public-api.md §3.4")
        ## v0.4 T4: membership via the SCOPE LAW; the ∈-scan over `names` is
        ## ORDER-INDEPENDENT (the C4E-4 law — never `insorted` over declaration order);
        ## a record declaring NO vocabulary has NO membership gate (T4-DESIGN §9-4);
        ## the refusal renders a SORTED display copy
        local vocab = _vocabulary_for_action(actionName)
        for label ∈ labels
            if vocab === nothing || label ∈ vocab.names
                crntLabels[label] = true
            else
                error("GoMeta apply: unknown label ", repr(first(String(label), 40)),
                    " — not in v0's closed label whitelist (the declared vocabulary = ",
                    sort(copy(vocab.names)), "); see docs/public-api.md §3.4")
            end
        end
    else
        error("GoMeta internal invariant violated: setLabels called with actionName = ",
            actionName, " != :(:) — please report this (not reachable from any v0 input)")
    end
end

function checkLabels(
    crntLabels::Dict{Symbol,Bool}, # The Alterant here.
    actionName::Symbol,
    labels::Vararg{Symbol}
)
    ## §4.8 twin guard (v0.3.1, with the setLabels guard above): the word-less
    ## label query ':()' reached this checker with ZERO labels and returned a vacuous TRUE —
    ## a wrong-verdict class (the K5/K6 family). The K2 pin that held the misapply at its old
    ## fate ("so it cannot drift silently") is flipped by name in the same change. The corpus
    ## sweep (v0.3.1) found no input depending on the vacuous form.
    isempty(labels) && error("GoMeta apply: empty label query — ':()' names no label to ",
        "check; v0 requires at least one label (e.g. ':(:label1)'); ",
        "see docs/public-api.md §3.4")
    ## v0.4 T4: the condition-side guards ride the SCOPE LAW, in the FIXED branch order
    ## (crx C9): membership (unknown-label) FIRST, then the R-V04-36 write-only valve,
    ## then the store lookup. A record declaring NO vocabulary has neither guard.
    ## (the T4-milestone-set C1 cure) TWO PASSES at the CALL grain: EVERY supplied label
    ## is validated (membership + valve) BEFORE any presence verdict — the interleaved
    ## per-label form returned `false` on an earlier unset member without ever validating
    ## a later write-only (or unknown) label, bypassing both refusal contracts.
    local vocab = _vocabulary_for_action(actionName)
    if vocab !== nothing
        for label ∈ labels
            ## a label outside the declared vocabulary refuses loudly (the SAME contract
            ## as setLabels' guard), never a silent `false` — a query for an unknown
            ## label is a vocabulary error, not an unset label
            if label ∉ vocab.names
                error("GoMeta apply: unknown label ", repr(first(String(label), 40)),
                    " — not in v0's closed label whitelist (the declared vocabulary = ",
                    sort(copy(vocab.names)), "); see docs/public-api.md §3.4")
            end
            ## the declared write-only valve (R-V04-36): a member flagged `query = false`
            ## is set-only — the query plane refuses it typed-prose
            if !get(vocab.flags, label, (query = true,)).query
                error("GoMeta apply: label ", repr(first(String(label), 40)),
                    " is declared write-only (query = false) — set-only in this ",
                    "vocabulary (the declared valve; see docs/public-api.md §3.4)")
            end
        end
    end
    for label ∈ labels
        if label ∉ keys(crntLabels)
            return false
        end
    end
    return true
end

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

#########################################################################################
## The Heading alterant: struct `Heading`, registry key `:heading`, action `head`
## (the publishing term — running head, head levels). Single-action inventory
## {head}; `title`/`subhead` stay unminted (mint-at-need; hyphen-free spelling if a
## compound ever mints). The store records captured headings and OWNS the corners
## via its validation seam: empty heading text meets the typed refusal — a STANDING
## v0.2 semantic, not a transitional default (docs/public-api.md §3.4).
## NON-QUERYABLE at v0.2 (getAltInstance = nothing): under localOnly delivery a
## condition naming `head` evaluates FALSE (the plugin never enters the working
## set; the membership test fails closed — the queued-era query-seam crash class is
## unreachable here). In a HEADING's own condition, query atoms refuse entirely
## (see `_absorb_local_only!`).
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
## v0.4 T3 (T3-DESIGN §3's companion cure): the validator now honors the documented
## handover contract `(text) -> Bool` — `return true` on acceptance (the former `&&`
## one-liner RETURNED `false` on every non-empty text, the short-circuit value, harmless
## only while the result was discarded); the ratified empty-text refusal keeps its
## byte-exact engine-prefixed message and passes through the T3 validate envelope
## verbatim (the pass-through law). `setHead`'s own calls ignore the return.
function _heading_validate_text(t)
    isempty(String(t)) && error("GoMeta absorb: empty heading text — an empty ",
        "heading is refused at v0.2 (a ratified standing decision; ",
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
## the level fact rides the head verdict row's ATTR NAME `head_<level>` — the
## attr-fold; stored in NO Component) — and the EXPLICIT sibling takes the level
## per call. The explicit level arrives as Symbol text (`Symbol("2")`: the literal
## floor keeps the integer space RESERVED out of the args wall) and is parsed
## here — the setId precedent; a non-parseable level meets the `_invoke_set`
## invalid-arguments refusal.
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

########### Constants AFTER `BLS` BEFORE `PlugIn(s)` ####################################
# The structural meta-hierarchy index consts are NOT per-call state, and they have a SINGLE source,
# state.jl: `NUM_MH_LEVELS = 12` + `maxDepthMH`(=length(BLS.depthLevelsMH)=9) / `fileMHIdx`(=1) /
# `userMHIdx`(=maxDepthMH+1=10) / `lineMHIdx`(=maxDepthMH+2=11) / `defaultMHIdx`(=maxDepthMH+3=12),
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

########### Constants AFTER `PlugIn(s)` (and `BLS`) #####################################
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
    ## v0.4 T2 (r-21, W5A-DA-1): the slot pool is finite (`NUM_MH_LEVELS` slots); when every slot is
    ## occupied `findfirst` returns `nothing` and the Int8 store below would raise a RAW MethodError —
    ## the uncontained/silent-displacement class C1 forbids. Guarded refusal in the absorb-capacity
    ## style (stable message; the GRAIN-COORDINATE conversion rides the diagnostics catalogue).
    free = findfirst(isequal(false), st.mh.slot_occupied)
    free === nothing && error("GoMeta absorb: meta-hierarchy slot pool exhausted (",
        length(st.mh.slot_occupied), " slots, all occupied) at level ", newMHIdx,
        " — guarded refusal; no slot is displaced or aliased (see docs/public-api.md §3.4)")
    st.mh.slots[st.crnt_idx] = free
    st.mh.slot_occupied[free] = true

end

function getState(stateKey::Symbol)
    # Reads the per-call settribute snapshot via `ctx()`: `get_state(ctx().snapshot, key)` is the pure
    # reader form of `BLS.getElement(ctx().snapshot, key)`. In a default-configured run the closed
    # condition interpreter reads the snapshot directly (README SECURITY; docs/public-api.md §3.2);
    # this accessor stays module-level for the opt-in `:full_eval_v1` extension mode, whose
    # host-evaluated condition text calls `getState(:key)` by BARE name through the module-level
    # ScopedValue. Writing goes the other way: the parent helper
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
    # above (the opt-in mode's host-evaluated text calls it by BARE name; the closed interpreter
    # dispatches query atoms through the registry instead). `altInd` is the declaration-order plugin
    # index (it comes from the registry's action-to-plugin table); `st.working[altInd]` is the instance
    # the apply phase constructed under that SAME index, so the lookup is internally consistent.
    local st = ctx()
    if altInd ∈ keys(st.working)
        ## v0.4 T3 — the SAME query-seam envelope as the closed interpreter's
        ## (`_eval_node(::CondQueryAtom)`): the query CROSSING is the cure unit, and this
        ## is its second live call site (the opt-in modes' host-evaluated bare name).
        ## Engine lookups hoisted; contain-all-typed; the "GoMeta "-prefix pass-through;
        ## the `-> Bool` return guard (T3-DESIGN §2).
        local plug = st.registry.plugins[altInd]
        local inst = st.working[altInd]
        local ret = try
            plug.getAltInstance(inst, altActionName, args...)
        catch e
            e isa InterruptException && rethrow()
            (e isa ErrorException && startswith(e.msg, "GoMeta ")) && rethrow()
            error("GoMeta apply: alterant query checker threw (CB_QUERY_THROW): ",
                String(nameof(typeof(e))), " on action ",
                repr(first(String(altActionName), 40)),
                " — the checker contract is total over its declared signature ",
                "(see docs/public-api.md §3.4)")
        end
        ret isa Bool || error("GoMeta apply: alterant query checker returned ",
            String(nameof(typeof(ret))), " (RES_RETURN_TYPE) on action ",
            repr(first(String(altActionName), 40)),
            " — the getter contract is `(instance, actionName, args...) -> Bool` ",
            "(see docs/public-api.md §3.4)")
        return ret
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
#     `using .Alterants`), so `PlugIn` here is unambiguously the state.jl definition — NOT
#     `Alterants.PlugIn`.
# DOES: `build_default_registry()` constructs FRESH top-level `PlugIn` instances in DECLARATION order
#     (labels=1, Visib=2, id=3, heading=4 — the live keys are :id / :heading), derives the sorted action
#     table + the parallel `action_to_plugin` index
#     + the `Dict` lookups + the SORTED `accum_alt_idxs` + the generic `action_to_settribute` table
#     (DERIVED from the declared per-action `settribute` slots — v0.4 T1) through the CHECKED owner
#     fill (a duplicate action name refuses at load — no silent last-writer-wins), and returns
#     `const DEFAULT_REGISTRY`.
# REASONING: alterant/action indices are fixed by declaration order, never by `Dict` iteration order —
#     those indices are baked into the eval'd condition strings.
# PURPOSE: a deterministic-by-construction, immutable, read-only alterant inventory for the pipeline.

"""
    default_registry_builder() -> RegistryBuilder

The v0 alterant inventory's DECLARATIONS in DECLARATION order: fresh top-level `PlugIn` instances for
`labels` / `Visib` / `Id` / `Heading` (the heading alterant — its names are RATIFIED: alterant
`Heading`, action `head`) in the `state.jl` type + the per-action records, returned as an
UNVALIDATED `RegistryBuilder`. `publish` runs the ONE chain (the clash law — a duplicate action
name refuses, naming both owners, never silent last-writer-wins; the record shape law; the
reflection cross-check — declared ≡ executable, both directions; the value algebra; the
reachability refusal; the candidacy diagnostic), derives the tables, and seals; `DEFAULT_REGISTRY`
is that published value, consumed READ-ONLY. Pure — no module-load side-effects.
"""
function default_registry_builder()
    # The closed v0 inventory, in DECLARATION order (deterministic, unlike Dict-iteration
    # order). Plugin index = position here.
    plugins = PlugIn[
        ## v0.4 T4: the labels record DECLARES its vocabulary (the digest-pinned artifact
        ## — the DECLARED literal, never the captured value; `_vocabulary_collect!` makes
        ## them agree or refuses at publication) + the POLICY identity (independent of the
        ## content digest — the R-FODT-17 referent PAIR; the lane bumps it on a policy move)
        ## v0.4 T5: every DEFAULT record DECLARES its capture row (the registration-driven
        ## capture plane; the stems are DECLARED — byte-compatibility never rides the
        ## derived fallback) — the three former legacy 6-positional declarations migrated
        ## to the keyword form to carry `capture =`.
        PlugIn(; altName = :labels, setMode = :accumulate, altConstructor = Dict{Symbol,Bool},
                 setAltInstance = Alterants.setLabels, getAltInstance = Alterants.checkLabels,
                 capture = CaptureDecl(Dict{Symbol,Bool}, :per_key, :many, nothing; attr_stem = :label),
                 vocabulary = VocabularyRef(DomainRef("alterants-std/labels_vocabulary.txt",
                                                      Alterants.LABELS_VOCABULARY_DECLARED_DIGEST)),
                 provenance = Provenance(; policy_id = "gometa-labels/v0-closed@1")),
        PlugIn(; altName = :Visib, setMode = :mutExclusive, altConstructor = Alterants.Visib,
                 setAltInstance = Alterants.setVisib,
                 capture = CaptureDecl(Alterants.Visib, :single, :one, nothing; attr_stem = :visib)),
        PlugIn(; altName = :id, setMode = :mutExclusivePerField, altConstructor = Alterants.Id,
                 setAltInstance = Alterants.setId,
                 capture = CaptureDecl(Alterants.Id, :per_field, :per_field, nothing; attr_stem = :id)),
        # The Heading plugin. setMode `:localOnly` — the THIRD inheritance mode:
        # a localOnly alterant's value applies ONCE, WHERE IT STANDS — its
        # actions NEVER ENQUEUE into the slot tensors, so the inheritance
        # backtrack (both apply passes) never visits them; delivery happens at
        # the absorb seam, keyed to the metaLine's own occurrence handle (the
        # outline model: one row per heading occurrence, document order
        # recoverable from handles). Deliberately in NEITHER derived set below.
        PlugIn(; altName = :heading, setMode = :localOnly, altConstructor = Alterants.Heading,
                 setAltInstance = Alterants.setHead,
                 capture = CaptureDecl(Alterants.Heading, :per_occurrence, :many, :localOnly; attr_stem = :head)),
    ]

    # v0.2 registration build: THE DECLARED REGISTRATION RECORD — one ActionSpec per action,
    # declaration order (the reflection-memo bindings; the parallel derived tables below
    # stay the hot-path lookups). Internal (grammar=false) rows declare the
    # probe-surfaced INHERITED setter shapes so the implemented-but-undeclared
    # diagnostic stays armed for FUTURE drift; they attach to the plugin's first
    # action (the cross-check walks methods per SETTER, pooling every spec that
    # shares it). Return types are DECLARED (never inference) and verified by the
    # dispatch-boundary tests.
    _ov(sig, kinds, srcs; vk=nothing, rt=Nothing, q=false, app=:context_free,
        ph=:apply, gr=true) =
        ActionOverload(sig, kinds, srcs, vk, rt, :set, q, app, ph, gr)
    action_specs = ActionSpec[
        # Labels `:(:)` — the OPERATOR-token spelling (ad-4); the colon sugar is one
        # of the two ACTIVATED grants (x-8, closed at two). Queryable via checkLabels.
        ActionSpec(Symbol(":"), :operator, Int8(1),
            [_ov(Type[Dict{Symbol,Bool}, Symbol], Symbol[], Symbol[];
                 vk=:symbol, rt=Nothing, q=true)],
            0, :activated, nothing, nothing),
        # Visib hide/show/discard — zero literal slots (the action name selects);
        # NON-queryable at v0.2 (getAltInstance=nothing; the I20 class). The inherited
        # SubString feed shape is the internal row on :hide.
        # v0.4 T1: the write-back settribute key is DECLARED per action (slot (1)) — identity to
        # the action name at v0.4.0, exactly the v0.3.2 map; the registry's generic
        # `action_to_settribute` table derives from these declarations below, so Core no longer
        # knows "plugin 2 is Visib" anywhere in this constructor.
        ActionSpec(:hide, :identifier, Int8(2),
            [_ov(Type[Alterants.Visib, Symbol], Symbol[], Symbol[]; rt=Bool),
             _ov(Type[Alterants.Visib, SubString{String}], Symbol[], Symbol[];
                 rt=Bool, gr=false)],
            0, :none, nothing, nothing, NoDefault(), :hide),
        ActionSpec(:show, :identifier, Int8(2),
            [_ov(Type[Alterants.Visib, Symbol], Symbol[], Symbol[]; rt=Bool)],
            0, :none, nothing, nothing, NoDefault(), :show),
        ActionSpec(:discard, :identifier, Int8(2),
            [_ov(Type[Alterants.Visib, Symbol], Symbol[], Symbol[]; rt=Bool)],
            0, :none, nothing, nothing, NoDefault(), :discard),
        # Id cell/parent/file — ONE literal slot, kind :symbol DECLARED (the setter
        # slot is `Any` — the untyped-slot class the reflection memo tags; reflection
        # cannot carry this kind). NON-queryable (experimental, I21). The inherited
        # SubString pair shape is the internal row on :cell.
        ActionSpec(:cell, :identifier, Int8(3),
            [_ov(Type[Alterants.Id, Symbol, Any], Symbol[:symbol],
                 Symbol[:declared]; rt=Int16),
             _ov(Type[Alterants.Id, SubString{String}, SubString{String}],
                 Symbol[], Symbol[]; rt=Int16, gr=false)],
            0, :none, nothing, nothing),
        ActionSpec(:parent, :identifier, Int8(3),
            [_ov(Type[Alterants.Id, Symbol, Any], Symbol[:symbol],
                 Symbol[:declared]; rt=Int16)],
            0, :none, nothing, nothing),
        ActionSpec(:file, :identifier, Int8(3),
            [_ov(Type[Alterants.Id, Symbol, Any], Symbol[:symbol],
                 Symbol[:declared]; rt=Int16)],
            0, :none, nothing, nothing),
        # head — the single Heading action. TWO grammar overloads: deriving
        # (context-REQUIRED; the sugar's lowering target) and explicit
        # (context-free). Both deliver at the ABSORB seam (the
        # localOnly phase). The text slot's :string kind is REFLECTED (the
        # signature carries AbstractString); the level slot's :symbol kind is
        # DECLARED (untyped slot, parsed setId-style). accepts_string_slot = 1
        # (the capability that retired the wall's name literal); the quoted-first
        # sugar is the second ACTIVATED grant; the validate slot carries the
        # Heading-owned empty-text refusal (the handover-validation slot).
        ActionSpec(:head, :identifier, Int8(4),
            [_ov(Type[Alterants.Heading, Symbol, AbstractString],
                 Symbol[:string], Symbol[:reflected];
                 rt=Nothing, app=:context_required, ph=:absorb),
             _ov(Type[Alterants.Heading, Symbol, AbstractString, Any],
                 Symbol[:string, :symbol], Symbol[:reflected, :declared];
                 rt=Nothing, ph=:absorb)],
            1, :activated, Alterants._heading_validate_text, nothing),
    ]

    # THE CLASH LAW (the registration build; replaces the interim uniqueness assert): the
    # collision CHECK always fires; the terminal disposition sits behind the
    # ONE-LINE SWITCH `_CLASH_DISPOSITION` with BOTH arms built and tested. ad-6
    # (refusal-vs-warning) is the OWNER's confirmation — presented at this step's
    # close, deferred owner-owed; arm R (refusal) is the LIVE arm, continuous with
    # the interim assert's refusal shape. Then the registration-time CHECK CHAIN
    # (each fail-closed BEFORE the registry object exists — the ATOMICITY law: no
    # partial registry is ever observable): the reflection cross-check (a)/(b)/(c)
    # (the memo verify-not-derive verdict) · the value-algebra refusal (id-5) · the
    # reachability refusal · the unactivated-candidacy diagnostic (x-8).
    # v0.4 T2 — the declarations above are the DEFAULT BUILDER; the chain (the clash law + the
    # record shape law + the reflection cross-check + the value algebra + the reachability
    # refusal + the candidacy diagnostic, each fail-closed BEFORE the registry object exists —
    # the ATOMICITY law) now runs inside `publish` as the ONE validation chain
    # (`_validate_registration`); the derived hot-path tables (the sorted action table, the
    # parallel action→plugin index, the name→index Dicts, the SORTED accumulate/mutExclusive
    # index sets the apply-phase `insorted` consumers depend on, the generic
    # `action_to_settribute` write-back table) come from `_derive_tables` — declarations only,
    # never hand-supplied; `:mutExclusivePerField` (the `id` compound) sits in NEITHER mode set
    # by design (its per-field semantics are deferred).
    return RegistryBuilder(plugins, action_specs)
end

"""
    build_default_registry() -> AlterantRegistry

The v0 alterant inventory, PUBLISHED: `publish(default_registry_builder())` — the ONE validation
chain (`_register_actions!` clash law · `_record_wellformed_check` · `_reflection_cross_check` ·
`_value_algebra_check` · `_reachability_check` · `_candidacy_check`, all inside `publish`) runs
fail-closed before the object exists, the derived tables come from the declarations, and the seal
is minted. Pure — no module-load side-effects beyond the const it feeds.
"""
build_default_registry() = publish(default_registry_builder())

## THE CLASH DISPOSITION SWITCH (the registration build): `:refuse` = arm R (load-time refusal — the
## LIVE arm, promotion-framed per the architecture, continuous with the interim
## assert's shape) · `:warn` = arm W (ratified warning + remedy + deterministic
## FIRST-writer-wins). BOTH arms are built and tested; flipping is this one line.
## The disposition itself is ad-6 — the OWNER's owed confirmation, presented at
## the registration build's close (deferred owner-owed).
const _CLASH_DISPOSITION = :refuse

"""
    _register_actions!(owner_of_action, action_specs; disposition) -> owner_of_action

The clash law (successor of the interim uniqueness assert): assigns each
declared action its owning plugin index in declaration order. The collision CHECK
always fires and names BOTH owners; the terminal disposition is the caller's
`disposition` (default `_CLASH_DISPOSITION`): `:refuse` throws the typed load-time
refusal; `:warn` emits the ratified warning WITH the remedy and keeps the FIRST
writer (deterministic — never last-writer-wins). Identical over both spelling
kinds (ad-4: the operator token `:(:)` collides exactly like an identifier).
"""
function _register_actions!(owner_of_action::Dict{Symbol,Int8},
                            action_specs::Vector{ActionSpec};
                            disposition::Symbol = _CLASH_DISPOSITION)
    diags = Diagnostic[]
    _register_actions_collect!(diags, owner_of_action, action_specs; disposition = disposition)
    _throw_first(diags)
    return owner_of_action
end

## v0.4 T2 — THE ACCUMULATING FORMS. Every chain check has a `_*_collect!(diags, …)` form that
## records EVERY defect as a typed `Diagnostic` (stable `code`, the SAME message text the throwing
## form used) and never throws — the full-collection-then-terminal law (R-FODT-16): a registration
## with three defects reports three, in deterministic order (check order × declaration order).
## The throwing forms above/below are thin wrappers (`_throw_first`) kept for their callers.
"Replay collected diagnostics as the legacy throw-on-first behavior (warnings via @warn, the first error thrown)."
function _throw_first(diags::Vector{Diagnostic})
    for d in diags
        d.severity === :warning && @warn d.message
        d.severity === :error && error(d.message)
    end
    return nothing
end

function _register_actions_collect!(diags::Vector{Diagnostic}, owner_of_action::Dict{Symbol,Int8},
                                    action_specs::Vector{ActionSpec};
                                    disposition::Symbol = _CLASH_DISPOSITION)
    for spec in action_specs
        if haskey(owner_of_action, spec.name)
            msg = string("GoMeta registry: duplicate alterant action name ",
                repr(spec.name), " — already owned by plugin index ",
                owner_of_action[spec.name], ", re-declared by plugin index ",
                spec.plugin, " (the clash law; disposition = ", disposition, ")")
            if disposition === :refuse
                push!(diags, Diagnostic(:REG_DUPLICATE_ACTION, :error, string(msg,
                    "; the registration REFUSES at load — remedy: rename ",
                    "one action or retire one declaration (no action ever ",
                    "registers through silent last-writer-wins)"), spec.name))
            else
                push!(diags, Diagnostic(:REG_DUPLICATE_ACTION, :warning, string(msg,
                    "; keeping the FIRST declaration ",
                    "(deterministic first-writer-wins) — remedy: rename one ",
                    "action or retire one declaration"), spec.name))
            end
            continue
        end
        owner_of_action[spec.name] = spec.plugin
    end
    return owner_of_action
end

"""
    _first_wins_spec_index(action_specs) -> Dict{Symbol,Int}

FIRST-writer-wins name→index construction, matching the clash law's
`:warn`-arm survivor (a naive Dict comprehension would keep the LAST
colliding spec, so under `:warn` the dispatch tables and the capability
consult would read DIFFERENT declarations; under the live `:refuse` arm
duplicates never reach this point, and first-wins is correct under BOTH
arms). Extracted so the arm-consistency property is directly witnessed.
"""
function _first_wins_spec_index(action_specs::Vector{ActionSpec})
    spec_index = Dict{Symbol,Int}()
    for (i, s) in enumerate(action_specs)
        haskey(spec_index, s.name) || (spec_index[s.name] = i)
    end
    return spec_index
end

## The closed serializable RETURN-TYPE algebra (id-5): a declared return type
## outside this set refuses at registration (the value-algebra law). Grown only by
## a conscious registry edit.
const _CLOSED_RETURN_TYPES = Type[Nothing, Bool, Int16]

## The record's CLOSED ENUM sets (the wellformed check below): every tag field is
## validated at registration, so a typo registers loudly, never silently.
const _SPELLING_KINDS  = (:identifier, :operator)
const _LITERAL_KINDS   = (:symbol, :string, :raw)     # :raw = internal-row bytes
const _KIND_SOURCES    = (:declared, :reflected)
const _EFFECT_KINDS    = (:set,)
const _APPLICABILITIES = (:context_free, :context_required)
const _PHASES          = (:apply, :absorb)
const _CANDIDACIES     = (:none, :candidate, :activated)

"""
    _record_wellformed_check(action_specs, plugins) -> nothing

The record's own shape law (a mis-spelled tag would otherwise register
silently, against the loud posture): every enum-tagged field must sit in its
closed set; the kinds/kind_sources vectors must be parallel; a `queryable=true`
row requires its plugin to carry a getter (`getAltInstance !== nothing` — the
query seam calls it unguarded once the plugin enters the working set).
"""
function _record_wellformed_check(action_specs::Vector{ActionSpec},
                                  plugins::Vector{PlugIn})
    diags = Diagnostic[]
    _record_wellformed_collect!(diags, action_specs, plugins)
    _throw_first(diags)
    return nothing
end

"The indices of the action records tier 1 finds structurally broken (the tier-2 skip set; cure batch 2). Cure batch 3: the ACTION-level law only — a plugin-level defect never marks an action broken."
function _broken_record_indices(action_specs::Vector{ActionSpec}, plugins::Vector{PlugIn})
    broken = Set{Int}()
    for (i, spec) in enumerate(action_specs)
        d = Diagnostic[]
        _record_wellformed_actions_collect!(d, [spec], plugins)
        # (the t3t4r3 A6 cure) an ENCODABILITY-refused record is BROKEN for tier 2 too:
        # a well-shaped overload carrying an over-budget/unencodable type got its
        # REG_PROTOCOL row yet stayed in `sound`, so the reflection collector re-walked
        # the very type the budget had refused (probe P64: a SIG_MISMATCH row minted on
        # the refused overload — unbounded at pathological depth). The per-spec probe
        # re-runs the same bounded domain walk the chain runs.
        if isempty(d)
            for slot in _WALK_ACTION_FIELDS
                _domain_slot_probe!(d, "action", spec.name, slot, getfield(spec, slot),
                                    slot === :validate, slot === :overloads)
            end
        end
        any(x -> x.code === :REG_PROTOCOL, d) && push!(broken, i)
    end
    return broken
end

"The tier-1 STRUCTURAL law, accumulating: every row a `REG_PROTOCOL` diagnostic (the `protocol` class) — the action-level law then the plugin-level law."
function _record_wellformed_collect!(diags::Vector{Diagnostic}, action_specs::Vector{ActionSpec},
                                     plugins::Vector{PlugIn})
    _record_wellformed_actions_collect!(diags, action_specs, plugins)
    _record_wellformed_plugins_collect!(diags, plugins)
    return nothing
end

"Tier 1, the ACTION-level rows (cure batch 3: split from the plugin-level rows so the tier-2 skip set is per action)."
function _record_wellformed_actions_collect!(diags::Vector{Diagnostic}, action_specs::Vector{ActionSpec},
                                             plugins::Vector{PlugIn})
    proto(msg, ctx) = push!(diags, Diagnostic(:REG_PROTOCOL, :error, msg, ctx))
    for spec in action_specs
        # the owning-plugin index must exist BEFORE any dependent check reads `plugins[spec.plugin]`
        # (a hand-built record with a dangling index is a STRUCTURAL defect, never a BoundsError)
        plugin_ok = 1 <= spec.plugin <= length(plugins)
        plugin_ok || proto(string("GoMeta registry: action ", repr(spec.name), " names plugin index ",
            spec.plugin, " but the record declares ", length(plugins), " alterant(s) (the record ",
            "shape law)"), spec.name)
        spec.spelling in _SPELLING_KINDS ||
            proto(string("GoMeta registry: unknown spelling tag ", repr(spec.spelling),
                " on action ", repr(spec.name), " (the record shape law)"), spec.name)
        spec.sugar_candidacy in _CANDIDACIES ||
            proto(string("GoMeta registry: unknown sugar-candidacy tag ",
                repr(spec.sugar_candidacy), " on action ", repr(spec.name),
                " (the record shape law)"), spec.name)
        for ov in spec.overloads
            length(ov.kinds) == length(ov.kind_sources) ||
                proto(string("GoMeta registry: kinds/kind_sources arity mismatch on ",
                    repr(spec.name), " (the record shape law)"), spec.name)
            all(k in _LITERAL_KINDS for k in ov.kinds) &&
                (ov.vararg_kind === nothing || ov.vararg_kind in _LITERAL_KINDS) ||
                proto(string("GoMeta registry: unknown literal kind on ", repr(spec.name),
                    " (the record shape law)"), spec.name)
            length(ov.kinds) <= length(ov.sig_types) - 2 ||
                proto(string("GoMeta registry: the kinds vector on ", repr(spec.name),
                    " is longer than the overload's user arity — leading kinds ",
                    "would silently describe the dispatch preamble (the record ",
                    "shape law; the kinds tail-align to the LAST user slots)"), spec.name)
            all(s in _KIND_SOURCES for s in ov.kind_sources) ||
                proto(string("GoMeta registry: unknown kind source on ", repr(spec.name),
                    " (the record shape law)"), spec.name)
            ov.effect in _EFFECT_KINDS ||
                proto(string("GoMeta registry: unknown effect class ", repr(ov.effect),
                    " on ", repr(spec.name), " (the record shape law)"), spec.name)
            ov.applicability in _APPLICABILITIES ||
                proto(string("GoMeta registry: unknown applicability ",
                    repr(ov.applicability), " on ", repr(spec.name),
                    " (the record shape law)"), spec.name)
            ov.phase in _PHASES ||
                proto(string("GoMeta registry: unknown delivery phase ", repr(ov.phase),
                    " on ", repr(spec.name), " (the record shape law)"), spec.name)
            plugin_ok && ov.queryable && plugins[spec.plugin].getAltInstance === nothing &&
                proto(string("GoMeta registry: action ", repr(spec.name),
                    " declares queryable=true but its plugin carries no getter ",
                    "(the query seam would crash — the I20 class; the record ",
                    "shape law)"), spec.name)
        end
        # THE DISPATCH-TARGET UNIQUENESS LAW (external-review-commissioned): per
        # action, at most ONE Symbol-addressable declared row per reachable arity —
        # two fixed rows must differ in arity; a fixed row must sit BELOW every
        # vararg row's base; two vararg rows always overlap and refuse. With this
        # law the set-invocation guard's arity-compatible row set is a SINGLETON at
        # every reachable call, so (a) Julia dispatch can never select a row the
        # form-matcher rejected (the wrong-overload/ambiguity class is load-time
        # impossible), and (b) the return guard provably checks the SELECTED row's
        # own declaration (no masking via an unrelated same-arity row).
        addr = [ov for ov in spec.overloads if length(ov.sig_types) >= 2 && Symbol <: ov.sig_types[2]]
        for i in eachindex(addr), j in (i + 1):lastindex(addr)
            a, b = addr[i], addr[j]
            na, nb = length(a.sig_types) - 2, length(b.sig_types) - 2
            overlap = a.vararg_kind === nothing && b.vararg_kind === nothing ?
                    na == nb :
                a.vararg_kind !== nothing && b.vararg_kind !== nothing ?
                    true :
                a.vararg_kind === nothing ? na >= nb : nb >= na
            overlap && proto(string("GoMeta registry: action ", repr(spec.name),
                " declares two Symbol-addressable rows with overlapping arity ",
                "sets — the dispatch-target uniqueness law refuses (one declared ",
                "form per arity; the guard's row set must be a singleton)"), spec.name)
        end
        # v0.4 T1 — the per-action slots' shape (additive; the closed enums of state.jl):
        spec.default isa DefaultSlot ||
            proto(string("GoMeta registry: the default slot on ", repr(spec.name),
                " is not a DefaultSlot (NoDefault() | Declared(v)) (the record shape law)"), spec.name)
        # v0.4 T2 — a declared write-back key must be a settribute key the component carries
        spec.settribute === nothing || spec.settribute in keys(BLS.ComponentSettribute) ||
            proto(string("GoMeta registry: action ", repr(spec.name), " declares the write-back ",
                "settribute key ", repr(spec.settribute), " which ComponentSettribute does not carry ",
                "(the record shape law)"), spec.name)
    end
    return nothing
end

"Tier 1, the PLUGIN-level rows (the v0.4 T1 slot shapes)."
function _record_wellformed_plugins_collect!(diags::Vector{Diagnostic}, plugins::Vector{PlugIn})
    proto(msg, ctx) = push!(diags, Diagnostic(:REG_PROTOCOL, :error, msg, ctx))
    # v0.4 T1 — the per-Alterant slots' shape (additive): every enum-tagged member of the new
    # slots sits in its closed set; a mis-spelled tag registers LOUDLY, never silently.
    # (v0.4 T5) the effective stem, shared with the walk: declared, else the derived fallback
    _stem(p) = p.capture.attr_stem === nothing ?
        Symbol(lowercase(String(p.altName))) : p.capture.attr_stem
    seen_stems = Dict{Symbol,Symbol}()   # stem => first-declaring altName (the clash law)
    for p in plugins
        if p.capture !== nothing
            p.capture.attr_scheme in _CAPTURE_SCHEMES ||
                proto(string("GoMeta registry: unknown capture attr scheme ", repr(p.capture.attr_scheme),
                    " on alterant ", repr(p.altName), " (the record shape law; the closed set is ",
                    _CAPTURE_SCHEMES, ")"), p.altName)
            p.capture.multiplicity in _CAPTURE_MULTIPLICITIES ||
                proto(string("GoMeta registry: unknown capture multiplicity ", repr(p.capture.multiplicity),
                    " on alterant ", repr(p.altName), " (the record shape law; the closed set is ",
                    _CAPTURE_MULTIPLICITIES, ")"), p.altName)
            ## v0.4 T5 (the T5-round tier-1 family — every row free under the SEVENTH
            ## re-mint): the gate's closed set; the BIDIRECTIONAL setMode⟺gate coherence
            ## (either one-way hole was a NEW silent-no-rows class — the anti-T1 disease);
            ## the instance_type≡altConstructor law (the mint IS `altConstructor()`, so a
            ## mismatch would read one type's store through another's name table); the
            ## stem's shape; the cross-plugin stem-clash law (same stem ⇒ same
            ## `(handle, attr)` families ⇒ silent cross-plugin supersede).
            p.capture.mode_gate in _CAPTURE_MODE_GATES ||
                proto(string("GoMeta registry: unknown capture mode gate ", repr(p.capture.mode_gate),
                    " on alterant ", repr(p.altName), " (the record shape law; the closed set is ",
                    _CAPTURE_MODE_GATES, ")"), p.altName)
            ((p.setMode === :localOnly) == (p.capture.mode_gate === :localOnly)) ||
                proto(string("GoMeta registry: capture mode gate ", repr(p.capture.mode_gate),
                    " is INCOHERENT with setMode ", repr(p.setMode), " on alterant ",
                    repr(p.altName), " — a :localOnly record captures at the absorb seam and",
                    " MUST gate :localOnly; a queued record must not (either mismatch is a",
                    " silent zero-rows class — the capture coherence law)"), p.altName)
            ## (the crx-t5 A5 cure) the localOnly seam implements ONE scheme — a gated
            ## row declaring any other scheme would be heading-folded against its own
            ## declaration (or falsely floored): refuse at publish.
            (p.capture.mode_gate !== :localOnly || p.capture.attr_scheme === :per_occurrence) ||
                proto(string("GoMeta registry: a :localOnly capture row on alterant ",
                    repr(p.altName), " declares scheme ", repr(p.capture.attr_scheme),
                    " — the absorb-seam delivery implements :per_occurrence only at v0.4",
                    " (the localOnly scheme law)"), p.altName)
            ## (the crx-t5 A4/C3 cure — STATIC) a localOnly store must carry the
            ## CONCRETE entries protocol the seam folds; anything else would be
            ## registrable-then-floored, and the relay's "any lane" claim narrows to
            ## exactly this protocol (the correction relayed).
            (p.capture.mode_gate !== :localOnly ||
             (hasfield(p.capture.instance_type, :entries) &&
              fieldtype(p.capture.instance_type, :entries) === Vector{Tuple{String,Union{Nothing,Int}}})) ||
                proto(string("GoMeta registry: a :localOnly capture row on alterant ",
                    repr(p.altName), " declares instance type ",
                    _ctor_type_name(p.capture.instance_type), " without the entries",
                    " protocol (`entries::Vector{Tuple{String,Union{Nothing,Int}}}`) — the",
                    " absorb-seam fold reads exactly that shape (the localOnly store law)"), p.altName)
            p.capture.instance_type === p.altConstructor ||
                proto(string("GoMeta registry: capture instance_type ",
                    _ctor_type_name(p.capture.instance_type), " differs from altConstructor ",
                    _ctor_type_name(p.altConstructor), " on alterant ", repr(p.altName),
                    " — the walk would read one type's store through another's name table",
                    " (the capture identity law)"), p.altName)
            (p.capture.attr_stem === nothing ||
             (p.capture.attr_stem isa Symbol && !isempty(String(p.capture.attr_stem)))) ||
                proto(string("GoMeta registry: capture attr_stem on alterant ", repr(p.altName),
                    " is empty — a stem must be a non-empty Symbol or nothing (the record",
                    " shape law)"), p.altName)
            let s = _stem(p)
                ## (the crx-t5 A6 cure) the clash law covers the PREFIX FAMILY, not just
                ## exact stems: stem `:a` with key `:b_c` and stem `:a_b` with key `:c`
                ## both mint `:a_b_c` — an underscore-prefix relationship either way is a
                ## cross-plugin attr-namespace overlap (full structural namespacing is
                ## T11's row; this refusal closes the constructible collision class).
                for (s2, owner) in seen_stems
                    clash = s === s2 ||
                        startswith(String(s), String(s2) * "_") ||
                        startswith(String(s2), String(s) * "_")
                    clash && proto(string("GoMeta registry: capture attr stem ", repr(s),
                        " on ", repr(p.altName), " overlaps the stem family of ", repr(s2),
                        " on ", repr(owner),
                        " — overlapping families mint colliding (handle, attr) rows and",
                        " silently supersede across plugins (the stem-clash law)"), p.altName)
                end
                haskey(seen_stems, s) || (seen_stems[s] = p.altName)
            end
        end
        if p.render !== nothing
            for (act, row) in p.render.effects
                row.kind in _EFFECT_ROW_KINDS ||
                    proto(string("GoMeta registry: unknown effect kind ", repr(row.kind), " on action ",
                        repr(act), " of alterant ", repr(p.altName),
                        " (the record shape law; the closed set is ", _EFFECT_ROW_KINDS, ")"), p.altName)
                row.kind === :mark || row.payload === nothing ||
                    proto(string("GoMeta registry: effect row ", repr(act), " of alterant ", repr(p.altName),
                        " carries a payload but is not a :mark row (the record shape law)"), p.altName)
            end
        end
        p.provenance.acquisition_mode === nothing ||
            p.provenance.acquisition_mode in _ACQUISITION_MODES ||
            proto(string("GoMeta registry: unknown acquisition mode ", repr(p.provenance.acquisition_mode),
                " on alterant ", repr(p.altName), " (the record shape law; the closed set is ",
                _ACQUISITION_MODES, ")"), p.altName)
        for c in p.constraints
            isempty(c.actions) &&
                proto(string("GoMeta registry: an empty MutEx constraint on alterant ", repr(p.altName),
                    " (the record shape law)"), p.altName)
        end
    end
    return nothing
end

## v0.4 T2 — the INVENTORY law (tier 2, the record-level semantics the failure matrix measured
## silent on v0.3.2): unknown set modes (FM-REG-1), duplicate alterant names (FM-REG-6),
## reserved-vocabulary shadowing (FM-REG-3), uninterpreted `requires` (whole-record, R-V04-12),
## MutEx conflicts, the contract version, and slot-pool exhaustion at the registry grain.
const _SET_MODES = (:accumulate, :mutExclusive, :mutExclusivePerField, :localOnly)
const _INTERPRETED_REQUIRES = ()            # the v0.4.0 roster interprets NO capability token
const _CONTRACT_VERSIONS = (v"0.4.0",)      # the family's anchor (display); the accepted set = the 0.4 MINOR family
"The accepted `contract_version` family: `nothing` (undeclared) or any v0.4.x (the design's 0.4.x rule; cure batch 1)."
_contract_accepts(v::VersionNumber) = v.major == 0 && v.minor == 4
const _SLOT_POOL = Int(typemax(Int8))       # the Int8 index space of plugins/actions (127)
function _inventory_collect!(diags::Vector{Diagnostic}, plugins::Vector{PlugIn},
                             action_specs::Vector{ActionSpec};
                             sound::Vector{ActionSpec} = action_specs)   # (cure batch 3) ownership from SOUND records only
    seen = Dict{Symbol,Int}()
    for (i, p) in enumerate(plugins)
        p.setMode in _SET_MODES ||
            push!(diags, Diagnostic(:REG_UNKNOWN_SETMODE, :error, string("GoMeta registry: unknown ",
                "setMode ", repr(p.setMode), " on alterant ", repr(p.altName), " — the closed set is ",
                _SET_MODES, " (an unknown mode would silently enter neither mode set and misroute ",
                "at apply)"), p.altName))
        if haskey(seen, p.altName)
            push!(diags, Diagnostic(:REG_DUPLICATE_ALTNAME, :error, string("GoMeta registry: duplicate ",
                "alterant name ", repr(p.altName), " at plugin indices ", seen[p.altName], " and ", i,
                " (a Dict comprehension would silently keep the last)"), p.altName))
        else
            seen[p.altName] = i
        end
        isempty(p.requires) ||
            all(r -> r in _INTERPRETED_REQUIRES, p.requires) ||
            push!(diags, Diagnostic(:REG_UNINTERPRETED_REQUIRES, :error, string("GoMeta registry: ",
                "alterant ", repr(p.altName), " requires ", p.requires, " — the v0.4.0 roster ",
                "interprets none of it; the WHOLE record refuses (no partial admission; the ",
                "Execute room is a later contract version)"), p.altName))
        p.contract_version === nothing || _contract_accepts(p.contract_version) ||
            push!(diags, Diagnostic(:REG_CONTRACT_VERSION, :error, string("GoMeta registry: alterant ",
                repr(p.altName), " targets contract version ", p.contract_version, " — the accepted ",
                "family is v0.4.x (anchor ", _CONTRACT_VERSIONS[1], "; or undeclared)"), p.altName))
        own = Set(s.name for s in sound if Int(s.plugin) == i)   # never Int8(i): i may exceed the pool; a malformed record owns nothing
        for c in p.constraints
            for a in c.actions
                a in own || push!(diags, Diagnostic(:REG_MUTEX_CONFLICT, :error, string(
                    "GoMeta registry: the MutEx constraint ", c.actions, " on alterant ",
                    repr(p.altName), " names ", repr(a), ", which is not one of that alterant's ",
                    "registered actions"), p.altName))
            end
        end
    end
    for s in action_specs
        # reserved-vocabulary shadowing: an action named like a settribute key it does not itself
        # declare as its write-back target would shadow the key in the interpreter's state arm.
        s.name in keys(BLS.ComponentSettribute) && s.settribute !== s.name &&
            push!(diags, Diagnostic(:REG_RESERVED_SHADOW, :error, string("GoMeta registry: action ",
                repr(s.name), " shadows the reserved settribute key of the same name without ",
                "declaring it as its own write-back target (the interpreter's state arm would ",
                "resolve the key, never the action's query)"), s.name))
    end
    (length(plugins) > _SLOT_POOL || length(action_specs) > _SLOT_POOL) &&
        push!(diags, Diagnostic(:REG_SLOT_EXHAUSTED, :error, string("GoMeta registry: the inventory (",
            length(plugins), " alterants, ", length(action_specs), " actions) exceeds the slot pool ",
            "of ", _SLOT_POOL, " (the Int8 index space) — silent index aliasing refused at ",
            "registration"), nothing))
    return nothing
end

"""
    _kind_type(k::Symbol) -> Type

The ONE declared-kind → runtime-type map, TOTAL over the closed `_LITERAL_KINDS` set
(`:symbol` → `Symbol` · `:string` → `AbstractString` · `:raw` → `SubString{String}`), shared
by the load-time reflection cross-check's VARARG construction AND the runtime arming consult
in the set-invocation guard. (The (c) loop's per-slot kind/type AGREEMENT predicate remains
its own encoding — it answers a subtler question than kind→type, e.g. `:string` accepts any
`<:AbstractString` slot.) An unknown kind is an internal defect (the record shape law already
refuses it at registration).
"""
_kind_type(k::Symbol)::Type =
    k === :symbol ? Symbol :
    k === :string ? AbstractString :
    k === :raw    ? SubString{String} :
    error("GoMeta registry: unknown literal kind ", repr(k),
        " — the closed kind set is ", _LITERAL_KINDS, " (the shared kind map)")

"""
    _user_arity(ov::ActionOverload) -> Int

The overload's USER-argument arity. Every declared `sig_types` vector INCLUDES the
`(alterant, actionName)` dispatch preamble (the record shape the exact-signature cross-check
constructs against), so the user arity is `length(sig_types) - 2` — pinned here so the
convention cannot silently skew between the record and its consumers.
"""
_user_arity(ov::ActionOverload)::Int = length(ov.sig_types) - 2

"""
    _registration_digest(action_specs; plugins = PlugIn[]) -> UInt64

The canonicalized fingerprint of the EFFECTIVE declared registration record — the profile's
registration provenance/cache-key component. Canonicalization: first-owner-per-name dedup
FIRST (so a clash-arm-W loser spec never moves the fingerprint — the effective record is
first-wins; which spec WON is meaning-bearing and correctly stays visible), then specs
sorted by action name; within a spec, overload rows sorted by their own serialized text — so
the digest is invariant under registration/declaration ORDER (multi-order determinism). The
`validate` slot folds by FUNCTION NAME (a swapped validator is USUALLY a result-affecting
registration change — recorded limits: a swap to a SAME-NAMED function is invisible to the
fold, and an anonymous validator's gensym name is not stable across sessions; the shipped
record carries only named validators — extend consciously if either class ever registers),
and the owning plugins' declaration data (name, set mode, store type,
getter presence) folds when `plugins` is supplied — a set-mode flip moves the fingerprint.
The fold reads ONLY the declared record data (never live method tables — snapshot-not-live:
a spec vector backed by NO real methods digests identically well; the purity witness in the
profile tests). FNV-1a over the canonical serialization — deterministic across sessions and
Julia versions FOR the shipped record class (named callables; concrete DataType signatures):
an anonymous callable's gensym name and a UnionAll/Union's `string` text are the two
show-context-dependent inputs, both disclosed above.
"""
function _registration_digest(action_specs::Vector{ActionSpec};
                              plugins::Vector{PlugIn} = PlugIn[])::UInt64
    h = _digest_fold(_FNV_OFFSET, "gometa-registration-v1")
    seen = Set{Symbol}()
    owned = ActionSpec[]
    for spec in action_specs
        spec.name in seen || (push!(seen, spec.name); push!(owned, spec))
    end
    for spec in sort!(owned; by = s -> String(s.name))
        h = _fold_parts(h, "spec", spec.name, spec.spelling,
            Int(spec.plugin), spec.accepts_string_slot, spec.sugar_candidacy,
            spec.validate === nothing ? "-" : String(nameof(spec.validate)),
            spec.keyed_slot,
            # v0.4 T2 — the declared per-action slots join the fold (the seal covers the record)
            "default", _slot_text(spec.default), "settribute", _slot_text(spec.settribute))
        for ov in sort(spec.overloads; by = _overload_text)
            h = _fold_parts(h, "ov")
            for t in ov.sig_types
                h = _fold_parts(h, _type_text(t))
            end
            # in-band marker discipline (delta-recorded): the "k"/"s" list markers
            # separate two SPLATTED variable-length lists; boundary aliasing would
            # need a kind or source literally named k/s — impossible, both sets are
            # CLOSED enums the record shape law enforces, and kinds/kind_sources are
            # parallel-length by the same law. Revisit if either set ever opens.
            h = _fold_parts(h, "k", ov.kinds..., "s", ov.kind_sources...,
                ov.vararg_kind, _type_text(ov.return_type), ov.effect,
                ov.queryable, ov.applicability, ov.phase, ov.grammar)
        end
    end
    for p in plugins
        h = _fold_parts(h, "plug", p.altName, p.setMode,
            _type_text(p.altConstructor), p.getAltInstance !== nothing,
            # v0.4 T2 (cure batch 1) — the BEHAVIOR-BEARING base fields join the fold: the setter and
            # getter by NAME, the precedence tuple (the CRX after-T2 set: a plugin swapped for one
            # with a different setter kept the seal). Callables fold by name — the snapshot's
            # `===` leaf compare at the door (T2-bis) closes the same-named-swap remainder.
            "setter", _slot_text(p.setAltInstance), "getter", _slot_text(p.getAltInstance),
            "prec", _slot_text(p.precedencesTuple),
            # v0.4 T2 — every declared per-Alterant slot joins the fold: the seal (HC-9) covers the
            # record + the declared source digests + policy_id.
            "capture", _slot_text(p.capture), "render", _slot_text(p.render),
            "vocab", _slot_text(p.vocabulary), "constraints", _slot_text(p.constraints),
            "atoms", _slot_text(p.atoms), "contract", _slot_text(p.contract_version),
            "requires", _slot_text(p.requires), "sugar", _slot_text(p.sugar),
            "provenance", _slot_text(p.provenance), "permissions", _slot_text(p.permissions))
    end
    return h
end

## v0.4 T2 — the canonical TEXT of a declared slot for the digest fold: deterministic, module-
## unqualified, callables by NAME, containers element-wise in declaration order, and BOUNDARY-
## UNAMBIGUOUS (no element boundary can be re-cut) — NOT globally injective. Since T2-bis the
## fold is a lossy CACHE KEY, never the door's mechanism (docs/public-api.md §1.2): its residual
## collision classes — module-unqualified type names; the name-folded designated callables;
## function-valued type parameters; untagged parameter categories (`Val{M.T}` ≡ `Val{true}`);
## un-encoded container parameters (`Any[1]` ≡ `Int[1]`) — are FINGERPRINT-only, each caught at
## the door by the snapshot's `===` leaf compare. The former (iv)/(v) hard-stop classes are
## CLOSED (`String`-only values; every type-bearing field probed at validate under the node
## budget); non-DataType type nodes encode STRUCTURALLY (crx-t2bis cure A1 — never `string`)
## (cure batch 1: the first encoding joined elements with delimiters, so `[Symbol("a,b")]` and
## `[:a, :b]` folded identically — every element, every string leaf and every component is now
## LENGTH-PREFIXED, netstring-style `<bytes>:<text>`, so no boundary can be re-cut).
_ns(s::String)::String = string(sizeof(s), ":", s)
_nsv(parts)::String = join((_ns(String(p)) for p in parts), ",")
_slot_text(x::Nothing)::String = "-"
_slot_text(x::Symbol)::String = string("y", _ns(String(x)))
# (the t3t4r5 cure — three seats convergent) CONCRETE `String` ONLY, matching
# `_domain_leaf`'s own String-only law: the former `::AbstractString` arm ran the
# EXTENSIBLE `String(x)` on a caller-owned string subtype (probe P80: a stateful
# specialization threw at validate, raw, through the ordering prepass). A non-String
# AbstractString value now falls to the `_UnencodableSlot` fallback — the typed
# refusal, zero caller code run — exactly where the domain law always placed it.
_slot_text(x::String)::String = string("s", _ns(x))
_slot_text(x::Bool)::String = x ? "T" : "F"
# (cure batch 2) the CONCRETE numeric type is part of the value (`Int8(1)` ≠ `Int64(1)`), and a
# vector is not a tuple — distinct tags, so a same-display substitution moves the seal.
# (cure batch 4) THE ENCODABLE DOMAIN IS CLOSED. Numbers: the machine integers by decimal text,
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
# (the t3t4r6-A1 cure) getfield parts here too — the encoder repeated the extensible
# real/imag/numerator/denominator dispatches; output byte-identical for legal values
_slot_text(x::Complex)::String = string("c", _nsv((_type_text(typeof(x)), _slot_text(getfield(x, :re)), _slot_text(getfield(x, :im)))))
_slot_text(x::Rational)::String = string("r", _nsv((_type_text(typeof(x)), _slot_text(getfield(x, :num)), _slot_text(getfield(x, :den)))))
_slot_text(x::Number)::String = throw(_UnencodableSlot(typeof(x)))
_slot_text(x::VersionNumber)::String = string("v", _ns(string(x)))
_slot_text(x::Type)::String = string("t", _ns(_type_text(x)))
# (cure batch 5) DATA SLOTS HOLD DATA: a `Function` encodes by NAME only in the DESIGNATED callable
# fields (setter/getter/evaluate/validate — each a snapshot leaf the door compares by `===`);
# inside a declared DATA value (`Declared.value`, `EffectRow.payload`, any container in them) a
# same-named function from another module would be invisible to the fingerprint AND, were it not
# refused, indistinguishable in the fold, so a function there is UNENCODABLE (refused at
# validation; the snapshot door would separately fire on the identity move).
const _IN_DATA = Base.ScopedValues.ScopedValue{Bool}(false)
# (the t3t4r4 A1=B1 cure) the STRUCTURAL callable name — `nameof` is extensible, and a
# Function can legitimately appear as an isbits TYPE PARAMETER of a declared signature
# (`Store{tag}` — probe P70: reflection's param render dispatched a pirated `nameof`
# raw out of validate). `_callable_text` reads TypeName fields only; for an ordinary
# named function the text is IDENTICAL to the old `nameof` render (the P50 ladder), so
# the seal fold does not move for the shipped/Base-fallback class (suite-asserted);
# a closure's text differs — the same benign exotic-registrant seal-text class already
# disclosed at the r3-C4 scoping.
_slot_text(f::Function)::String =
    _IN_DATA[] ? throw(_UnencodableSlot(typeof(f))) : string("f", _ns(_callable_text(f)))
# (cure batch 3) CYCLE-aware container encoding: a published mutable container mutated into a
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
# (cure batch 5) CONCRETE containers only: a range, a view or a user AbstractVector/AbstractDict
# would fold content-only (`1:3` ≡ `[1,2,3]` — an undisclosed collision) and sits outside the
# domain copier's closed rebuild classes (T2-bis: `deepcopy` is never dispatched anywhere) —
# outside the closed domain, refused.
_slot_text(v::Vector)::String = _slot_container("[", "]", v)
_slot_text(v::Tuple)::String = string("<", _nsv(_slot_text(e) for e in v), ">")
_slot_text(p::Pair)::String = string("(", _nsv((_slot_text(p.first), _slot_text(p.second))), ")")
# (cure batch 4) dicts are cycle-guarded like vectors and CANONICAL: entries sorted by their
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
_slot_text(x::DomainRef)::String = string("DomainRef", _nsv((_slot_text(x.artifact), x.digest)))
_slot_text(x::CaptureDecl)::String =   # v0.4 T5: the stem joins the seal (the SEVENTH re-mint's locus — without it two registries differing only in stem would seal identically)
    string("Capture", _nsv((_type_text(x.instance_type), String(x.attr_scheme), String(x.multiplicity), _slot_text(x.mode_gate), _slot_text(x.attr_stem))))
_slot_text(x::EffectRow)::String =
    Base.ScopedValues.with(_IN_DATA => true) do; string("Effect", _nsv((String(x.kind), _slot_text(x.payload)))) end
_slot_text(x::RenderDecl)::String =
    string("Render", _nsv((_slot_text(x.effects), _slot_text(x.resolve_order), _slot_text(x.materialize))))
_slot_text(x::InlineVocabulary)::String = string("Inline", _nsv((_slot_text(x.names), _slot_text(x.flags))))
_slot_text(x::VocabularyRef)::String = string("Ref", _ns(_slot_text(x.ref)))
_slot_text(x::MutEx)::String = string("MutEx", _ns(_slot_text(x.actions)))
_slot_text(x::ConditionAtom)::String =
    string("Atom", _nsv((String(x.name), _slot_text(x.print_spelling), _slot_text(x.evaluate))))
_slot_text(x::SugarRow)::String = string("Sugar", _nsv((String(x.pattern), String(x.action), _slot_text(x.mode_gate))))
_slot_text(x::SignatureRecord)::String =
    string("Sig", _nsv((_slot_text(x.algorithm), _slot_text(x.key_id), _slot_text(x.signature))))
_slot_text(x::PermissionManifest)::String = string("Perm", _nsv((_slot_text(x.seam), _slot_text(x.ambient))))
_slot_text(x::Provenance)::String = string("Prov",
    _nsv(string(_ns(String(f)), _ns(_slot_text(getfield(x, f)))) for f in fieldnames(Provenance)))
# (cure batch 4) NO opaque fallback: a value of a type without an encoder is UNENCODABLE — refused
# at validation as `REG_PROTOCOL`; a payload type T10 admits gets its own encoder then.
_slot_text(x)::String = throw(_UnencodableSlot(typeof(x)))

## ————————————————————————————————————————————————————————————————————————————————————————
## v0.4 T2-bis — THE ONE DOMAIN + the three walks (T2BIS-DESIGN, R-V04B-4 (c+)): ONE leaf
## predicate (`_domain_leaf`) is the law for `validate` (the domain walk), the domain COPIER
## `_domain_copy` (publish stages 1+2 and the contained `RegistryBuilder(published)` route)
## and the deep-egal COMPARATOR `_deep_egal` (the one-check door). Leaves are carried BY
## REFERENCE and compared by `===` ONLY; containers are REBUILT at their exact concrete
## types and walked element-/field-wise; everything else is outside the domain. All three
## walks are ITERATIVE — explicit work stacks, no native recursion anywhere, probe frames
## included.

"The enumerated machine-scalar run of the closed value domain (R-V04B-8; **Bool IS in** —
`Bool <: Integer`, the Bool arm of the ratified encoder)."
const _MACHINE_REAL = Union{Bool, Int8, Int16, Int32, Int64, Int128,
                            UInt8, UInt16, UInt32, UInt64, UInt128,
                            Float16, Float32, Float64}
const _MACHINE_INT = Union{Bool, Int8, Int16, Int32, Int64, Int128,
                           UInt8, UInt16, UInt32, UInt64, UInt128}

# the parts-recursive numeric arm, matching the RATIFIED encoder exactly (T2BIS-DESIGN §1):
# `Complex`/`Rational` OF the machine run, parts-recursively — `Complex{Rational{Int64}}`,
# `Complex{Bool}` and `Rational{Bool}` admit; `BigInt` parts fall to the else-arm exactly
# as today. Bounded: Complex parts are `<:Real`, so the recursion depth is ≤ 2.
# (the t3t4r6-A1 cure) the Complex/Rational PARTS read via `getfield` — `real`/`imag`/
# `numerator` are EXTENSIBLE generics, and a legitimate specialization on
# `Complex{TheirReal}` executed (and threw) from the domain predicate BEFORE any guard
# (probe P90). Field reads are byte-identical for every legal value (`real(z)` IS
# `z.re`), so nothing legal moves.
_numeric_leaf(x)::Bool = x isa _MACHINE_REAL ||
    (x isa Rational && getfield(x, :num) isa _MACHINE_INT) ||
    (x isa Complex && _numeric_leaf(getfield(x, :re)) && _numeric_leaf(getfield(x, :im)))

"""
    _domain_leaf(x) -> Bool

THE ONE leaf predicate (T2BIS-DESIGN §1) — enumerated, never `isbits` (which would admit
`Char`, enums and opaque isbits structs R-V04B-8 refuses): `Function` · `Type` · `Symbol` ·
`Nothing` · `String` (VALUES are `String`-only — a non-`String` `AbstractString` value is
OUTSIDE the domain; `AbstractString` stays a legal `Type` leaf) · `VersionNumber` · the
machine scalars · `Complex`/`Rational` of those, parts-recursively. Leaves are carried by
reference by the copier and compared by `===` only by the comparator (bitwise on isbits —
NaN payloads and signed zero stay detected; `String` content-egal; `VersionNumber`
field-wise egal; `Function`/`Type`/`Symbol` by identity). Position rules (a `Function`
only in a designated callable field, never inside declared data — DATA WINS) live in the
walks, not here.
"""
_domain_leaf(x)::Bool =
    x isa Function || x isa Type || x isa Symbol || x === nothing || x isa String ||
    x isa VersionNumber || _numeric_leaf(x)

## the per-record explicit field lists — 16/10/10, each asserted against the compiler at
## load (T2BIS-DESIGN §15 (7)); the three record structs are POSITION-RESTRICTED walker
## containers (elements of `plugins`/`action_specs`; `ActionOverload` inside
## `ActionSpec.overloads`) and are REFUSED anywhere else, declared data included.
const _WALK_PLUGIN_FIELDS = (:altName, :setMode, :altConstructor, :setAltInstance,
    :getAltInstance, :precedencesTuple, :capture, :render, :vocabulary, :constraints, :atoms,
    :contract_version, :requires, :sugar, :provenance, :permissions)
@assert _WALK_PLUGIN_FIELDS == fieldnames(PlugIn)
const _WALK_ACTION_FIELDS = (:name, :spelling, :plugin, :overloads, :accepts_string_slot,
    :sugar_candidacy, :validate, :keyed_slot, :default, :settribute)
@assert _WALK_ACTION_FIELDS == fieldnames(ActionSpec)
const _WALK_OVERLOAD_FIELDS = (:sig_types, :kinds, :kind_sources, :vararg_kind, :return_type,
    :effect, :queryable, :applicability, :phase, :grammar)
@assert _WALK_OVERLOAD_FIELDS == fieldnames(ActionOverload)

"The 14 record-reachable slot-struct types (walked field-wise GENERICALLY; rebuilt
positionally at `typeof(x)`)."
const _SLOT_STRUCTS = (DomainRef, CaptureDecl, NoDefault, Declared, EffectRow, RenderDecl,
                       InlineVocabulary, VocabularyRef, MutEx, ConditionAtom, SugarRow,
                       SignatureRecord, PermissionManifest, Provenance)
const _SLOT_STRUCT_UNION = Union{DomainRef, CaptureDecl, NoDefault, Declared, EffectRow,
                                 RenderDecl, InlineVocabulary, VocabularyRef, MutEx,
                                 ConditionAtom, SugarRow, SignatureRecord,
                                 PermissionManifest, Provenance}
const _RECORD_STRUCT_UNION = Union{PlugIn, ActionSpec, ActionOverload}

# a VALUE-domain container at any position (the record structs are position-restricted and
# handled by the walks' `rk` class, never by this predicate); CONCRETE classes only —
# `Vector`/`Dict` are the concrete Base types, so ranges/views/user containers fall through
_value_container(x)::Bool = x isa Vector || x isa Dict || x isa Tuple || x isa Pair ||
                            x isa NamedTuple || x isa _SLOT_STRUCT_UNION

"Predicate 2's totality bound (T2BIS-DESIGN §2, THE BUDGET LAW): the node budget of the
iterative type-parameter walk. A budget-PASSING type has a whole parameter TREE of ≤ this
many nodes, so every text-encoder recursion over it at the mint is depth-bounded —
MINT-SAFE by construction, with NO catch (catching `StackOverflowError` is shape-dependent
at the Julia semantics — probes P1/P4, log §S2.6/§S2.9 — and is never a design premise)."
const _TYPE_BUDGET = 256

# the ITERATIVE budgeted type walk: EVERY child type node is descended — `DataType`
# parameters, `UnionAll` var/body, `Union` a/b, `TypeVar` lb/ub, `Vararg` T/N (probe P4,
# §S2.9: a UnionAll wrapping a deep body would count as ONE node under a counted-not-
# descended reading, yet `string()` on it recurses to a StackOverflowError at the mint —
# so the walk descends everything). A NON-type value parameter is leaf-checked (the
# `Val{'c'}` refusal — KNOWN OPEN (v) closes, witnessed by W5).
# (the t3t4r3 A2 cure) EVERY type-graph read below is `getfield` — property syntax
# lowers through the EXTENSIBLE `getproperty`, and a registered
# `Base.getproperty(::Type{Theirs}, ::Symbol)` specialization threw out of the budget
# walk BEFORE any gate it feeds (probe P62). `getfield`/`isa`/`isdefined` are builtins.
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

# the Dict-ORDER budget (T2BIS-DESIGN §2's determinism clause, AMENDED at the code commit,
# §S2.9: a deep VALUE key with a shallow type — a `Vector{Any}` nest — evades the TYPE
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
            # (the t3t4r4 B1 cure) a Function ANYWHERE in a key graph fails the order
            # budget outright — the prepass then never encodes the key (live iteration
            # order; the WALK refuses it typed), so no user method executes even
            # contained (probe P71: the pirated nameof ran TWICE under the old catch)
            return false
        elseif x isa Type || x isa TypeVar || x isa Core.TypeofVararg
            # (the t3t4r3 A2 cure) getfield-only type-graph reads — see _type_budget_check
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
                isassigned(x, i) || return false                  # crx-t2bis cure A3: no undef read
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

# canonical Dict entry order for the VALIDATE walk (deterministic first-failure,
# T2BIS-DESIGN §2): entries sorted by the encoded key text where EVERY key passes the
# order budget and encodes; ANY over-budget or unencodable key sends the whole Dict to the
# live iteration order (within-run stable — the A/A pin's property). Entries are collected
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
                # (t3t4r3 C1, RE-NARROWED at t3t4r4) with Function keys blocked at the
                # ORDER BUDGET (no user method can execute) and the encoder family
                # structural, the only expected throw classes here are the encoder's
                # own — anything else is an ENGINE defect and rethrows loudly (the
                # r4-C1 residue concern dissolves with the narrow catch).
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
    # (the t3t4r2 family cure, seat A row 6) the offending TYPE renders through the
    # structural zero-dispatch helper — interpolating `T` ran `show`, and a throwing
    # user `show(::IO, ::Type{Theirs})` broke the never-throws chain at the very row
    # refusing their value (probe P54).
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

# ONE (record, slot) probe of the validate walk (T2BIS-DESIGN §2): the iterative
# two-predicate walk, emitting AT MOST ONE slot-named row — the FIRST failure on the
# deterministic traversal (fields in listed order · Vector/Tuple by index · Pair
# first/second · NamedTuple by name order · Dict per `_walk_dict_entries`). Work items are
# `(value, pos, des, rk)`: `pos` ∈ (:structural, :data) — flipped at the two DATA loci
# `Declared.value`/`EffectRow.payload` and never flipped back (DATA WINS —
# `ConditionAtom.evaluate` nested in data is refused like any Function in data); `des` =
# the value sits in a designated callable field (`setAltInstance`/`getAltInstance`/
# `evaluate`/`validate`); `rk` = 0x02 for a Vector whose elements are admitted
# `ActionOverload` records (the `overloads` slot only), 0x01 for such an element itself.
# Cycle-guarded (visiting `IdSet`, push!/delete! bracketed) with a per-slot DONE-cache on
# the mutable containers; `validate` NEVER throws.
function _domain_slot_probe!(diags::Vector{Diagnostic}, label::String, ctx, slot::Symbol,
                             x, des0::Bool, ovvec::Bool)
    visiting = Base.IdSet{Any}()
    done = Base.IdSet{Any}()
    work = Any[(x, :structural, des0, ovvec ? 0x02 : 0x00)]
    while !isempty(work)
        item = pop!(work)
        if item isa _PopVisit
            delete!(visiting, item.v)
            push!(done, item.v)
            continue
        end
        (v, pos, des, rk) = item
        if v isa _RECORD_STRUCT_UNION
            (v isa ActionOverload && rk === 0x01 && pos === :structural) ||
                return _emit_unencodable!(diags, label, ctx, slot, typeof(v))
            for i in length(_WALK_OVERLOAD_FIELDS):-1:1
                push!(work, (getfield(v, _WALK_OVERLOAD_FIELDS[i]), pos, false, 0x00))
            end
        elseif v isa Vector || v isa Dict
            v in visiting && return _emit_cyclic!(diags, label, ctx, slot)
            v in done && continue
            push!(visiting, v)
            push!(work, _PopVisit(v))
            if v isa Vector
                kidrk = rk === 0x02 ? 0x01 : 0x00
                for i in 1:length(v)                              # crx-t2bis cure A3
                    isassigned(v, i) || return _emit_undef!(diags, label, ctx, slot)
                end
                for i in length(v):-1:1
                    push!(work, (v[i], pos, false, kidrk))
                end
            else
                entries = _walk_dict_entries(v)
                for i in length(entries):-1:1
                    push!(work, (entries[i].second, pos, false, 0x00))
                    push!(work, (entries[i].first, pos, false, 0x00))
                end
            end
        elseif v isa Declared
            push!(work, (v.value, :data, false, 0x00))
        elseif v isa EffectRow
            push!(work, (v.payload, :data, false, 0x00))
            push!(work, (v.kind, pos, false, 0x00))
        elseif v isa ConditionAtom
            push!(work, (v.evaluate, pos, pos === :structural, 0x00))
            push!(work, (v.print_spelling, pos, false, 0x00))
            push!(work, (v.name, pos, false, 0x00))
        elseif v isa _SLOT_STRUCT_UNION
            flds = fieldnames(typeof(v))
            for i in length(flds):-1:1
                push!(work, (getfield(v, flds[i]), pos, false, 0x00))
            end
        elseif v isa Tuple || v isa NamedTuple
            vals = v isa Tuple ? v : values(v)
            for i in length(vals):-1:1
                push!(work, (vals[i], pos, false, 0x00))
            end
        elseif v isa Pair
            push!(work, (v.second, pos, false, 0x00))
            push!(work, (v.first, pos, false, 0x00))
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

"""
    _dependency_collect!(diags, plugins)

(v0.4 T3 — T3-DESIGN §4; FM-DEP-1's eager closure; CE 2.g class C) every plugin's
`altConstructor` must be ZERO-ARG CONSTRUCTIBLE at the gate — the instance mint calls it
bare at the three mint sites, and an absent method was a RAW `MethodError` at first apply.
ONE `:DEP_MISSING` error row per offending plugin (record grain; the type name via the
structural zero-dispatch renderer). Hardened at the t3t4r2 closure set (the T3-era claim
"`hasmethod` is total over `Type`" was REFUTED three ways, each probe-confirmed):
`Union{}` refuses eagerly (its `hasmethod` is a FALSE true — probe P52); a
budget-refused ctor type SKIPS the lookup (the unbounded-`hasmethod` class — the
encodability row already refuses the registration); the lookup itself is
`invoke`-pinned to the Base `(Any, Any)` fallback (a registered
`Base.hasmethod(::Type{Theirs}, ::Type{Tuple{}})` specialization threw through the
gate — probes P51/P53).
"""
# (the T4-milestone-set A3 cure; hardened at t3t4r; STRUCTURAL-TOTAL at the t3t4r2
# closure set — seats B + C) the TOTAL, ZERO-DISPATCH ctor-type renderer. The onion,
# each layer probe-confirmed: `nameof` covers only DataType/UnionAll (the raw
# MethodError); `string(::Type)` dispatches `show` over Union members (the hostile-show
# class); `nameof` is ITSELF an extensible generic (`Base.nameof(::Type{T})` piracy —
# t3t4r2-B) and throws on a UnionAll whose body is a Union (t3t4r2-C). This form uses
# ONLY builtins — `===`/`isa`/`getfield` — plus Base string ops on concrete Base types:
# the Union walk over `.a`/`.b`, the UnionAll unwrap over `.body`, TypeVar leaves by
# their `.name`, DataType leaves via `.name.name` (TypeName field reads). NO generic a
# registrant can extend runs (the T2-bis door's own no-dispatch law). `@nospecialize` +
# the untyped signature: a Union member can BE a TypeVar (the t3t4r2-C example), which
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

# (the t3t4r2 family cure) the zero-dispatch CALLABLE display: interpolating a
# caller-supplied function value runs `show` on its own singleton type, and `nameof` is
# extensible (a legitimate specialization can throw through a diagnostic). TypeName
# field reads only; the leading `#` of a function's singleton-type name is stripped so
# an ordinary function displays as before (`boom_set`, not `#boom_set`).
function _callable_text(@nospecialize f)
    nm = String(getfield(getfield(typeof(f), :name), :name))
    return startswith(nm, "#") ? nm[2:end] : nm
end

# (the t3t4r5-A2 cure) the executable METHOD TABLE is caller-owned: an UNDECLARED
# method's signature can carry parameters outside the encodable domain (`Val{'x'}` —
# probe P81: the render threw a raw engine-internal `_UnencodableSlot(Char)` out of
# validate) or past the type budget. The guarded text buckets both classes to CONSTANT
# strings — the row still mints (implemented-but-undeclared is the CORRECT outcome),
# the render never throws, and the sort stays deterministic (equal-key methods keep
# the method-table's stable definition order within a run).
function _sig_guarded_text(@nospecialize msig)
    verdict = _type_budget_check(msig)[1]
    verdict === :over_budget && return "(an over-budget signature)"
    verdict === :bad_param && return "(a signature outside the encodable domain)"
    try
        return _type_text(msig)
    catch e
        (e isa _UnencodableSlot || e isa _CyclicSlot) || rethrow()
        return "(a signature outside the encodable domain)"
    end
end

function _dependency_collect!(diags::Vector{Diagnostic}, plugins::Vector{PlugIn})
    for p in plugins
        C = p.altConstructor
        # (the t3t4r2 family cure, seat A row 4 — probe P52) `Union{}` is storable and
        # `hasmethod(Union{}, Tuple{})` is TRUE (Core's vararg ctor), yet `Union{}()`
        # ALWAYS throws — the eager gate refuses the false admission here, not at the
        # first apply's guarded mint.
        if C === Union{}
            push!(diags, Diagnostic(:DEP_MISSING, :error, string(
                "GoMeta registry: alterant ", repr(p.altName), " declares altConstructor ",
                "Union{} — the bottom type has NO instances, so the mint can never ",
                "succeed (DEP_MISSING; eager dependency closure at publication)"), p.altName))
            continue
        end
        # (row 5) a ctor type past the encoder budget already refuses the WHOLE
        # registration at the encodability collector — running an UNBOUNDED method
        # lookup on it here is pure exposure (a 10^4-member Union stalls `hasmethod`);
        # the budget walk is the bound.
        _type_budget_check(C)[1] === :ok || continue
        # (row 3 — probe P51/P53) `hasmethod` is an EXTENSIBLE generic: a registered
        # `Base.hasmethod(::Type{Theirs}, ::Type{Tuple{}})` specialization threw through
        # the gate. `invoke` pins the Base `(Any, Any)` fallback — the specialization
        # cannot run.
        invoke(hasmethod, Tuple{Any,Any}, C, Tuple{}) ||
            push!(diags, Diagnostic(:DEP_MISSING, :error, string(
                "GoMeta registry: alterant ", repr(p.altName), " declares altConstructor ",
                _ctor_type_name(C), " with no zero-argument method — the ",
                "instance mint's dependency (DEP_MISSING; eager dependency closure at ",
                "publication)"), p.altName))
    end
    return nothing
end

"""
    _vocabulary_collect!(diags, plugins)

(v0.4 T4 — T4-DESIGN §2; the R-V04-37 PUBLICATION-ONLY RE-VERIFY) the vocabulary law at
the gate: a `VocabularyRef` whose DECLARED digest matches no CAPTURED artifact refuses
`:SRC_DIGEST_MISMATCH` (the fail-closed pre-flight — the DEFAULT publishes at module
load, so a tampered shipped artifact fails `using GoMeta` here); an `InlineVocabulary`
with a duplicate name or a flag key outside its name set refuses (`REG_PROTOCOL` family;
an ABSENT flag key defaults `query = true`, documented).
"""
function _vocabulary_collect!(diags::Vector{Diagnostic}, plugins::Vector{PlugIn})
    for p in plugins
        v = p.vocabulary
        v === nothing && continue
        if v isa VocabularyRef
            haskey(Alterants._VOCAB_CACHE, v.ref.digest) ||
                push!(diags, Diagnostic(:SRC_DIGEST_MISMATCH, :error, string(
                    "GoMeta registry: alterant ", repr(p.altName), " declares vocabulary ",
                    "digest ", v.ref.digest, " which matches NO loaded artifact — the ",
                    "artifact bytes moved without a declaration update, or the artifact ",
                    "was never loaded (verify-and-capture; publication-only ",
                    "re-verification per R-V04-37)"), p.altName))
        elseif v isa InlineVocabulary
            seen = Set{Symbol}()
            for n in v.names
                n in seen ? push!(diags, Diagnostic(:REG_PROTOCOL, :error, string(
                    "GoMeta registry: alterant ", repr(p.altName), " declares a DUPLICATE ",
                    "vocabulary name ", repr(n), " (the vocabulary law)"), p.altName)) :
                    push!(seen, n)
            end
            for k in keys(v.flags)
                k in seen || push!(diags, Diagnostic(:REG_PROTOCOL, :error, string(
                    "GoMeta registry: alterant ", repr(p.altName), " declares a vocabulary ",
                    "flag for ", repr(k), " which is not a declared name (the vocabulary ",
                    "law; an absent flag defaults query = true)"), p.altName))
            end
        end
    end
    return nothing
end

# the INTERNAL resolver (no copy — the membership helpers and the scope law read this;
# the PUBLIC `vocabulary` wraps it in a defensive copy)
function _resolve_vocabulary_by_index(registry::AlterantRegistry, i::Integer)
    slot = registry.plugins[i].vocabulary
    slot === nothing && return nothing
    slot isa InlineVocabulary && return slot
    v = get(Alterants._VOCAB_CACHE, slot.ref.digest, nothing)
    v === nothing && error("GoMeta apply: the declared vocabulary of alterant ",
        repr(registry.plugins[i].altName), " is UNRESOLVABLE (declared digest ",
        slot.ref.digest, " has no loaded artifact) — see docs/public-api.md §3.4")
    return v
end

"""
    vocabulary(registry, altName) -> Union{Nothing,InlineVocabulary}

G-VOC (v0.4 T4; package-public — the ONE vocabulary query surface the three planes read;
consumers adopt at T9): the named record's DECLARED vocabulary, resolved — an
`InlineVocabulary` slot verbatim, a `VocabularyRef` through the load-time capture cache
by its declared digest — and returned as a DEFENSIVE COPY (mutating the return changes
nothing; the membership helpers read only the private representation). `nothing` when
the record declares no vocabulary (no membership gate — the declared-content law) or the
alterant is unknown. An unresolvable `VocabularyRef` refuses LOUDLY.
"""
function vocabulary(registry::AlterantRegistry, altName::Symbol)
    i = get(registry.alt_index, altName, nothing)
    i === nothing && return nothing
    v = _resolve_vocabulary_by_index(registry, i)
    v === nothing && return nothing
    return InlineVocabulary(copy(v.names), copy(v.flags))
end

"""
    vocabulary_member(registry, altName, name) -> Bool

G-VOC membership: `true` iff the named record declares a vocabulary containing `name`,
OR declares none (no gate). An UNKNOWN alterant returns `false` — FAIL-CLOSED (the
T4-milestone-set B2 cure: a consumer using this as an allow-gate must not admit
everything on a misspelled or attacker-chosen alterant name; only a KNOWN record's
absent vocabulary slot means "no gate"). Order-independent (an `∈`-scan over the
declared names — never a sorted-order assumption).
"""
function vocabulary_member(registry::AlterantRegistry, altName::Symbol, name::Symbol)
    i = get(registry.alt_index, altName, nothing)
    i === nothing && return false           # unknown alterant: fail CLOSED (B2)
    v = _resolve_vocabulary_by_index(registry, i)
    v === nothing && return true
    return name ∈ v.names
end

"""
    vocabulary_queryable(registry, altName, name) -> Bool

G-VOC queryability: `true` iff `name` is a declared member whose flag is `query = true`
(an absent flag defaults `true`); `false` for a non-member (membership is checked FIRST
by every conforming caller — the branch order law); `true` when a KNOWN record declares
no vocabulary (no gate); `false` for an UNKNOWN alterant — FAIL-CLOSED (the B2 cure,
as `vocabulary_member`).
"""
function vocabulary_queryable(registry::AlterantRegistry, altName::Symbol, name::Symbol)
    i = get(registry.alt_index, altName, nothing)
    i === nothing && return false           # unknown alterant: fail CLOSED (B2)
    v = _resolve_vocabulary_by_index(registry, i)
    v === nothing && return true
    name ∈ v.names || return false
    return get(v.flags, name, (query = true,)).query
end

"""
    _encodability_collect!(diags, plugins, action_specs)

(T2-bis, replacing the cure-batch-4/5 `_slot_text` probe) tier 1's DOMAIN row — the ONE
walk with TWO predicates over EVERY record field (plugin × 16, spec × 10, overloads walked
within over all 10 overload fields — T2BIS-DESIGN §2): predicate 1 = membership AT
POSITION (leaves via `_domain_leaf`; the value-domain containers; the record structs only
at their structural positions; a `Function` only in the designated callable fields and
never inside declared data; `String`-only string values); predicate 2 = the type-encoder
BUDGET over every admitted `Type` leaf's parameter tree, so a validated record is
MINT-SAFE. At most ONE slot-named `REG_PROTOCOL` row per (record, slot), in deterministic
order; full collection across slots and records; `validate` never throws.
"""
function _encodability_collect!(diags::Vector{Diagnostic}, plugins::Vector{PlugIn}, action_specs::Vector{ActionSpec})
    for p in plugins
        for slot in _WALK_PLUGIN_FIELDS
            _domain_slot_probe!(diags, "alterant", p.altName, slot, getfield(p, slot),
                                slot === :setAltInstance || slot === :getAltInstance, false)
        end
    end
    for s in action_specs
        for slot in _WALK_ACTION_FIELDS
            _domain_slot_probe!(diags, "action", s.name, slot, getfield(s, slot),
                                slot === :validate, slot === :overloads)
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
container). Named beside `_OutsideDomain` per T2BIS-DESIGN §3 route 2 — both convert to
the typed refusal, never escape a public constructor."
struct _CyclicValue <: Exception
    path::Vector{Any}
end
"internal (crx-t2bis cure A2): a USER method (`hash`/`isequal`/`convert`) thrown while a
rebuilt `Dict` was being filled — the one rebuild step that dispatches user-extensible
code. Converted to a typed refusal at both public copy boundaries, never leaked raw."
struct _RebuildFailed <: Exception
    T::Type
end
"internal (crx-t2bis cure A3): an UNDEFINED container element met by a walk — a
`resize!`-widened published Vector, or an undef-slot declared vector. Refused typed at
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
            # method throwing here is contained TYPED (crx-t2bis cure A2), never leaked raw
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

THE DOMAIN COPIER (T2BIS-DESIGN §3; NOT `Base.deepcopy` — `deepcopy_internal` is never
dispatched, a capturing closure/callable struct keeps its identity): leaves BY REFERENCE;
containers, slot structs and (at structural positions) record structs REBUILT at their
EXACT concrete types (`T = typeof(v)` — THE TYPE LAW; a `Vector`/`Dict` is constructed AS
`T` and filled, never by an inferred comprehension); the else-arm throws the internal
`_OutsideDomain`. ITERATIVE — an explicit frame stack with post-order rebuild, no native
recursion. The `memo` is ALWAYS caller-supplied — ONE per copy stage/route, over EVERY
container class (immutables included: `IdDict` egal-keying makes the reuse sound), so
sharing is preserved WITHIN a stage and the copy is linear in the stage's distinct
containers. `visiting !== nothing` selects the CONTAINED route
(`RegistryBuilder(published)` — the one route that meets UNVALIDATED values): the on-stack
cycle guard rides beside the memo, the memo is keyed by `(source, position-class)`, and
§1's POSITION rules are ENFORCED (a `Function` in data or outside a designated field, or
a record struct outside its structural position, throws `_OutsideDomain`); cycles throw
`_CyclicValue`. Both carry the path. On the publish route (`visiting === nothing`) the
copy is TYPE-based — `validate` has already run, so every value is in-domain and acyclic.
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
            flds = v isa PlugIn ? _WALK_PLUGIN_FIELDS :
                   v isa ActionSpec ? _WALK_ACTION_FIELDS : _WALK_OVERLOAD_FIELDS
            n = length(flds)
            fr = _CopyFrame(v, :record, vpos, seg, Vector{Any}(undef, n), fill(vpos, n),
                            fill(false, n), fill(0x00, n), Vector{Any}(undef, n),
                            Vector{Any}(undef, n), 1)
            for (i, f) in enumerate(flds)
                fr.kids[i] = getfield(v, f)
                fr.ksegs[i] = f
            end
            if v isa PlugIn
                fr.kdes[4] = true            # setAltInstance
                fr.kdes[5] = true            # getAltInstance
            elseif v isa ActionSpec
                fr.krk[4] = 0x02             # overloads — its elements are admitted records
                fr.kdes[7] = true            # validate
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
                    isassigned(v, i) || throw(_UndefSlot())   # crx-t2bis cure A3
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
                elseif v isa EffectRow
                    fr.kpos[2] = :data                        # payload
                elseif v isa ConditionAtom
                    fr.kdes[3] = (vpos === :structural)       # evaluate — DATA WINS
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

## ————— the deep-egal COMPARATOR (T2BIS-DESIGN §4): ONE explicit machine — work-stack
## frames; a Dict entry-probe is a PROBE FRAME on the same stack carrying its overlay
## guard segment + backtracking state; NO native probe recursion. GUARD: a
## `Base.IdSet{Any}` of `(live, snap)` tuples per segment — the spine plus one overlay per
## active probe; a probe's guard view = the EFFECTIVE guard (the spine ∪ every enclosing
## overlay); a pair anywhere in it returns equal (coinductive — termination on tandem
## cycles at any depth); an overlay is DISCARDED on rejection and on acceptance MERGES
## into the ENCLOSING segment. There is NO verdict memo (the round-5 SIMPLIFY cure —
## degenerate nested duplicate-equal-key rejected-twin towers are exponential-in-depth by
## disclosure, T2BIS-DESIGN §11). The door dispatches NO user-extensible method anywhere —
## no `hash`, no `isequal`, no `==`, no user `show` (rendering included): Dicts are
## compared by the ONE-PATH structural ENTRY-MATCHING law — every snapshot entry must
## match a not-yet-consumed live entry with `_deep_egal`-equal stored KEY AND VALUE
## (greedy over entries is maximum: entry-equality is a product of two partial
## equivalences — the banked R1 proof).

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
        flds = a isa PlugIn ? _WALK_PLUGIN_FIELDS :
               a isa ActionSpec ? _WALK_ACTION_FIELDS : _WALK_OVERLOAD_FIELDS
        for i in length(flds):-1:1
            f = flds[i]
            des = (a isa PlugIn && (f === :setAltInstance || f === :getAltInstance)) ||
                  (a isa ActionSpec && f === :validate)
            rk2 = (a isa ActionSpec && f === :overloads) ? 0x02 : 0x00
            push!(work, _EgalTask(getfield(a, f), getfield(b, f), (t.path, f), t.pos, des, rk2))
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
                # (crx-t2bis cure A3) an UNDEFINED element (a resize!-widened live vector)
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
                pos2 = ((a isa Declared && f === :value) || (a isa EffectRow && f === :payload)) ?
                    :data : t.pos
                des2 = a isa ConditionAtom && f === :evaluate && t.pos === :structural
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

The comparator (T2BIS-DESIGN §4): the first divergent typed-segment path, or `nothing`
when the pair is content-structurally equal. Container-type-FIRST dispatch; per-class
gates (`typeof` → size → element-wise); leaves by `===` ONLY; alias topology is NOT
significant (the pair guard makes shared DAGs and even both-sided cycles terminate);
Dicts by the one-path structural entry-matching law. A fresh spine guard per call.
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
        pr.frame.probe_state = Int8(-1)          # into it by nested accepted probes (B2-5)
    end
    return nothing
end

## non-dispatching diagnostic rendering (T2BIS-DESIGN §4; probes P2a/P2b, §S2.8): a
## Base-owned leaf key renders by `repr` (its `show` is Base-owned; a user method on a
## Base-owned type is piracy, outside conforming code — the disclosed B-2-class boundary);
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
                        isassigned(v, i) && push!(stack, v[i])    # crx-t2bis cure A3
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
# dispatched `show` (the non-dispatching rule applies to this route's messages too)
_domain_type_name(T::Type)::String = String(nameof(T))

function _route2_refuse(r::AlterantRegistry, e, field::Symbol)
    # (crx-t2bis cures A2/A3) the two path-less internal classes convert typed too
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
        recname = String(rec isa PlugIn ? rec.altName : rec.name)
        length(p) >= 3 && p[3] isa Symbol && (slotname = String(p[3]))
    end
    msg = if e isa _CyclicValue
        string("GoMeta registry: RegistryBuilder(published) met a CYCLIC container at ", ptext,
               " (record ", repr(recname), ", slot ", slotname, ") — the published value was ",
               "mutated after publication; a declared value must be acyclic (the record shape law)")
    elseif e.T <: Function || e.T <: PlugIn || e.T <: ActionSpec || e.T <: ActionOverload
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

"the CONTAINED preload copy behind `RegistryBuilder(published)` (T2BIS-DESIGN §3 route 2):
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

"The canonical serialized text of one overload row (the digest's SORT KEY only — the fold
itself goes through the injective `_fold_parts`, never through this joined text)."
_overload_text(ov::ActionOverload)::String =
    string("|ov|", join((_type_text(t) for t in ov.sig_types), ","),
        "|", join(ov.kinds, ","), "|", join(ov.kind_sources, ","),
        "|", ov.vararg_kind, "|", _type_text(ov.return_type), "|", ov.effect,
        "|", ov.queryable, "|", ov.applicability, "|", ov.phase, "|", ov.grammar)

# The digest's type serialization: module-UNQUALIFIED (stable across load contexts) but
# parameter-FAITHFUL (`Dict{Symbol,Bool}` ≠ `Dict{Symbol,Int}` — a real drift class a bare
# `nameof` would collapse). (cure batch 5) a NON-type parameter is a VALUE and folds type-tagged
# through `_slot_text` (`Val{Int8(1)}` ≠ `Val{Int64(1)}`, `Val{:x}` ≠ `Val{1}`; a parameter value
# outside the closed domain is unencodable); TypeVar / Vararg parameters keep their text. NOTE
# (recorded limits): the `string` fallback for UnionAll/Union sig types is show-context-dependent
# (may qualify); and two SAME-NAMED types from DIFFERENT modules collide as one identity (the
# unqualified choice's deliberate trade — dispatch treats them as distinct; a second
# type-contributing module is the revisit trigger). No shipped record row reaches these — extend
# consciously.
function _type_text(t)::String
    t === Any && return "Any"
    if t isa DataType
        # (the t3t4r2 family cure) `nameof` is an EXTENSIBLE generic — a legitimate
        # `Base.nameof(::Type{Theirs})` specialization could throw through the seal
        # encoder. The getfield form is OUTPUT-IDENTICAL (`nameof(t::DataType)` IS
        # `t.name.name` — probe P50 across the type ladder, incl. function types), so
        # the registration pin does NOT move; `getfield` is a builtin — no user method
        # can run.
        nm = getfield(getfield(t, :name), :name)
        isempty(getfield(t, :parameters)) && return String(nm)
        return string(nm, "{", join((_type_param_text(p) for p in getfield(t, :parameters)), ","), "}")
    end
    # (T2-bis crx cure A1) non-DataType type nodes encode STRUCTURALLY — `string()` on a
    # UnionAll/Union/TypeVar dispatches `show`, and a user's own display method on its own
    # admitted type (legitimate specialization, not piracy) could throw out of the mint. The
    # structural text dispatches nothing (`nameof`/`Symbol` reads only) and stays
    # module-unqualified. Recursion is bounded: every minted type passed predicate 2's
    # descending node budget, so the tree has ≤ `_TYPE_BUDGET` nodes.
    t === Union{} && return "Bottom"
    # (the t3t4r3 A2 cure) getfield-only reads here too — property syntax on a
    # caller-owned type object dispatches the extensible `getproperty`
    t isa UnionAll && return string("where(", _typevar_text(getfield(t, :var)), ",",
                                    _type_text(getfield(t, :body)), ")")
    t isa Union && return string("union(", _type_text(getfield(t, :a)), ",",
                                 _type_text(getfield(t, :b)), ")")
    throw(_UnencodableSlot(typeof(t)))   # unreachable for an admitted `Type` leaf
end
_typevar_text(v::TypeVar)::String =
    string("tv(", String(getfield(v, :name)), ",", _type_text(getfield(v, :lb)), ",",
           _type_text(getfield(v, :ub)), ")")
_type_param_text(p)::String =
    p isa TypeVar ? _typevar_text(p) :
    p isa Core.TypeofVararg ? string("va(", isdefined(p, :T) ? _type_text(getfield(p, :T)) : "-", ",",
                                     isdefined(p, :N) ? _type_param_text(getfield(p, :N)) : "-", ")") :
    p isa Type ? _type_text(p) : _slot_text(p)

"""
    _reflection_cross_check(action_specs, plugins) -> nothing

The reflection memo's VERIFY-NOT-DERIVE cross-check, run at registration time (atomic —
any failure aborts the whole build): (a) every DECLARED overload must match an
executable method on its plugin's setter (`hasmethod` over the declared signature)
— declared-but-unimplemented refuses; (b) every executable method on a declared
setter must match some declared overload's signature — implemented-but-undeclared
raises the LOUD load-time diagnostic (the x-8 class; the probe-surfaced inherited
shapes are declared as internal rows precisely so this arm stays armed for future
drift); (c) where a declared `:string`/`:symbol` kind meets a TYPED signature
slot, the types must agree (`:string` ⇒ `<:AbstractString`, `:symbol` ⇒
`Symbol`; an `Any` slot carries a `:declared` kind by definition).
"""
function _reflection_cross_check(action_specs::Vector{ActionSpec},
                                 plugins::Vector{PlugIn})
    diags = Diagnostic[]
    _reflection_collect!(diags, action_specs, plugins)
    _throw_first(diags)
    return nothing
end

"The reflection cross-check, accumulating (`REG_SIG_MISMATCH` per defect; specs with a dangling plugin index are skipped — tier 1 already reported them)."
function _reflection_collect!(diags::Vector{Diagnostic}, action_specs::Vector{ActionSpec},
                              plugins::Vector{PlugIn})
    sigm(msg, ctx) = push!(diags, Diagnostic(:REG_SIG_MISMATCH, :error, msg, ctx))
    # (the t3t4r3 A3=B1=C2 cure) IDENTITY pooling: a plain Dict{Function} dispatched
    # `hash`/`isequal` on the caller-owned setter — a legitimate throwing specialization
    # broke validate at the very first `get!` (probe P60). IdDict keys by `objectid`
    # (builtin) — no user method can run.
    declared_by_setter = IdDict{Any,Vector{Vector{Any}}}()
    for spec in action_specs
        1 <= spec.plugin <= length(plugins) || continue
        setter = plugins[spec.plugin].setAltInstance
        sigs = get!(declared_by_setter, setter, Vector{Any}[])
        for ov in spec.overloads
            # a trailing Vararg is a Core.TypeofVararg, not a Type — the signature
            # containers are Any-typed on purpose. The vararg's DECLARED kind is
            # honored over the WHOLE closed kind set via the SHARED `_kind_type`
            # map (delta-caught: a two-way local map collapsed :raw onto
            # AbstractString; the shared total map keeps this load-time consult
            # and the runtime arming consult in lockstep — they cannot drift).
            # The vararg slot's kind↔type agreement is enforced HERE, by the (a)
            # exact-signature construction — not by the (c) loop below.
            local _vt = ov.vararg_kind === nothing ? nothing : _kind_type(ov.vararg_kind)
            full = _vt === nothing ? Any[ov.sig_types...] :
                Any[ov.sig_types..., Vararg{_vt}]
            # (a) declared ≡ executable, the declared→executable direction — by
            # EXACT method-signature match, not hasmethod subtyping (a mis-declared row
            # on a shared setter could ride a sibling's method through subtype dispatch
            # while the pooled (b) walk stayed green)
            sig_tuple = Tuple{typeof(setter), full...}
            # (the t3t4r2 family cure, seat A row 7) `methods` is invoke-pinned to the
            # Base fallback, and the diagnostic renders the signature + the setter
            # STRUCTURALLY — interpolating `sig_tuple`/`setter` ran `show` over
            # caller-owned types, so a legitimate throwing display specialization broke
            # the never-throws chain inside this very refusal.
            # (the t3t4r3 A4=B2 cure) the exact match is IDENTITY (`===`): `==` on Types
            # is the extensible subtype-equivalence generic, interceptable through a
            # specialization on the caller's own signature tuple type; the constructed
            # tuple and a normally-defined method's `sig` are both interned canonical
            # objects, so `===` IS the exact-match semantics the (a) direction ruled.
            any(m.sig === sig_tuple for m in invoke(methods, Tuple{Any}, setter)) ||
                sigm(string("GoMeta registry: declared overload has no executable ",
                    "method — action ", repr(spec.name), " declared ", _sig_guarded_text(sig_tuple),   # (t3t4r6-A2) guarded: typeof(setter) can carry out-of-domain parameters (Setter{'x'} — P91)
                    " on ", _callable_text(setter), " (declared-but-unimplemented refuses at ",
                    "load; the reflection cross-check; the match is EXACT ",
                    "per-signature, never subtype dispatch)"), spec.name)
            push!(sigs, full)
            # (c) kind ↔ type agreement on the literal tail (the vararg slot's
            # agreement lives in the (a) construction above — delta-trued)
            lit = ov.sig_types[(length(ov.sig_types) - length(ov.kinds) + 1):end]
            for (k, t) in zip(ov.kinds, lit)
                ok = t === Any ||
                     (k === :string && t <: AbstractString) ||
                     (k === :symbol && t === Symbol) ||
                     k === :raw
                ok || sigm(string("GoMeta registry: literal-kind/type disagreement — ",
                    "action ", repr(spec.name), " kind ", repr(k),
                    " vs signature slot type ", _type_text(t),   # (t3t4r2) structural render
                    " (the reflection cross-check)"), spec.name)
            end
        end
    end
    # (b) executable ≡ declared, the executable→declared direction — in DECLARATION order of the
    # setters (first-seen), methods in a stable signature-text order (cure batch 1: a
    # `Dict{Function}` iteration made this row's order hash-dependent, against the deterministic-
    # order contract)
    order = Function[]
    for spec in action_specs
        1 <= spec.plugin <= length(plugins) || continue
        f = plugins[spec.plugin].setAltInstance
        # (the t3t4r3 A3=B1=C2 cure) `f in order` dispatched `==` on the caller-owned
        # setter — the identity search dispatches nothing
        any(x -> x === f, order) || push!(order, f)
    end
    for setter in order
        sigs = declared_by_setter[setter]
        # (the t3t4r2 family cure) the stable ordering key is the STRUCTURAL signature
        # text (`string(m.sig)` ran `show` over caller-owned sig types during the SORT —
        # a throwing display specialization broke validate before any row was built);
        # `methods` invoke-pinned; the message + context render structurally.
        for m in sort!(collect(invoke(methods, Tuple{Any}, setter)); by = m -> _sig_guarded_text(m.sig))   # (t3t4r5-A2) guarded
            # (cure batch 2) a `where`-parametric method's `sig` is a UnionAll — unwrap it, never
            # index `.parameters` on it (validate must not throw on a parametric setter)
            # (the t3t4r3 A5 cure) the unwrap is LOCAL and structural — Base's unwrap
            # helper is an extensible generic on the caller-influenced signature;
            # getfield-only reads instead (the [15] source scan pins its absence)
            msig = m.sig
            while msig isa UnionAll
                msig = getfield(msig, :body)
            end
            m_argtypes = collect(getfield(msig, :parameters)[2:end])
            matched = any(sigs) do full
                length(full) == length(m_argtypes) &&
                    all(a === b for (a, b) in zip(full, m_argtypes))
            end
            matched || sigm(string("GoMeta registry: executable method matches no ",
                "declared overload — ", _sig_guarded_text(m.sig), " on ", _callable_text(setter),   # (t3t4r5-A2) guarded
                " (implemented-but-undeclared: declare it — as an internal ",
                "grammar=false row if it is not action grammar; the loud ",
                "drift diagnostic)"), Symbol(_callable_text(setter)))
        end
    end
    return nothing
end

"The id-5 value-algebra refusal: declared return types must sit in the closed serializable set."
function _value_algebra_check(action_specs::Vector{ActionSpec})
    diags = Diagnostic[]
    _value_algebra_collect!(diags, action_specs)
    _throw_first(diags)
    return nothing
end
function _value_algebra_collect!(diags::Vector{Diagnostic}, action_specs::Vector{ActionSpec})
    for spec in action_specs, ov in spec.overloads
        any(ov.return_type === t for t in _CLOSED_RETURN_TYPES) ||
            push!(diags, Diagnostic(:REG_VALUE_ALGEBRA, :error, string(
                "GoMeta registry: declared return type ", _ctor_type_name(ov.return_type),   # (t3t4r2) structural render
                " of action ", repr(spec.name), " is outside the closed ",
                "serializable set ", _CLOSED_RETURN_TYPES,
                " (the value-algebra refusal, id-5)"), spec.name))
    end
    return nothing
end

"The reachability refusal: every GRAMMAR overload's literal kinds must be expressible from the active literal floor (AlterantArgT = Symbol|String)."
function _reachability_check(action_specs::Vector{ActionSpec})
    diags = Diagnostic[]
    _reachability_collect!(diags, action_specs)
    _throw_first(diags)
    return nothing
end
function _reachability_collect!(diags::Vector{Diagnostic}, action_specs::Vector{ActionSpec})
    for spec in action_specs, ov in spec.overloads
        ov.grammar || continue
        for k in vcat(ov.kinds, ov.vararg_kind === nothing ? Symbol[] : [ov.vararg_kind])
            k in (:symbol, :string) ||
                push!(diags, Diagnostic(:REG_UNREACHABLE, :error, string(
                    "GoMeta registry: literal kind ", repr(k), " of action ",
                    repr(spec.name), " is unreachable from the active literal ",
                    "floor (Symbol|String) — the reachability refusal"), spec.name))
        end
    end
    return nothing
end

"The x-8 unactivated-candidacy diagnostic: sugar candidacy without user activation is LOUD at load (the grant register stays closed at two ACTIVATED grants)."
function _candidacy_check(action_specs::Vector{ActionSpec})
    diags = Diagnostic[]
    _candidacy_collect!(diags, action_specs)
    _throw_first(diags)
    return nothing
end
function _candidacy_collect!(diags::Vector{Diagnostic}, action_specs::Vector{ActionSpec})
    for spec in action_specs
        spec.sugar_candidacy === :candidate &&
            push!(diags, Diagnostic(:REG_CANDIDACY, :warning, string(
                "GoMeta registry: action ", repr(spec.name),
                " declares sugar CANDIDACY without user activation — the ",
                "candidacy is REGISTERED, not active (activation is a user ",
                "ruling; the grant list is closed at two; x-8)"), spec.name))
    end
    return nothing
end

## v0.4 T2 — THE ONE VALIDATION CHAIN (every public construction route runs it) + the derived
## tables + the seal + the lifecycle.
"""
    _validate_registration(plugins, action_specs) -> Vector{Diagnostic}

The ONE chain, in fixed order: tier 1 (`_record_wellformed_collect!`, the `protocol` class) →
tier 2 (the inventory law · the clash law · the reflection cross-check · the value algebra · the
reachability refusal · the candidacy warning). FULL collection: every defect is reported; the caller
decides the terminal outcome (error present ⇒ refuse). Deterministic order ⇒ A/A-stable refusals.
"""
function _validate_registration(plugins::Vector{PlugIn}, action_specs::Vector{ActionSpec})
    diags = Diagnostic[]
    n0 = length(diags)
    _record_wellformed_collect!(diags, action_specs, plugins)
    _encodability_collect!(diags, plugins, action_specs)   # (cure batch 4) the seal must be mintable
    _dependency_collect!(diags, plugins)                   # (T3) the mint's eager dependency closure
    _vocabulary_collect!(diags, plugins)                   # (T4) the vocabulary law + the R-V04-37 re-verify
    # (cure batch 1) tier 2 SKIPS every action record tier 1 found structurally broken: the semantic
    # collectors index and consult closed maps on the record's own data, and a malformed row would
    # otherwise THROW out of the accumulator (the CRX after-T2 set: `vararg_kind = :bogus` reached
    # `_kind_type`). `validate` never throws; every well-formed row is still fully checked.
    # (cure batch 2) broken records are tracked by INDEX, never by name: a duplicate-named or
    # plugin-named record must not shadow a well-formed one's tier-2 defects.
    broken = _broken_record_indices(action_specs, plugins)
    sound = ActionSpec[s for (i, s) in enumerate(action_specs) if !(i in broken)]
    _inventory_collect!(diags, plugins, action_specs; sound = sound)
    _register_actions_collect!(diags, Dict{Symbol,Int8}(), action_specs)
    _reflection_collect!(diags, sound, plugins)
    _value_algebra_collect!(diags, sound)
    _reachability_collect!(diags, sound)
    _candidacy_collect!(diags, action_specs)
    return diags
end

"The derived hot-path tables, computed from the DECLARED record only (never hand-supplied)."
function _derive_tables(plugins::Vector{PlugIn}, action_specs::Vector{ActionSpec})
    owner_of_action = Dict{Symbol,Int8}()
    for spec in action_specs
        haskey(owner_of_action, spec.name) || (owner_of_action[spec.name] = spec.plugin)   # first-wins
    end
    sorted_alt_actions = sort!(collect(keys(owner_of_action)))
    return (
        sorted_alt_actions   = sorted_alt_actions,
        action_to_plugin     = Int8[owner_of_action[a] for a in sorted_alt_actions],
        action_index         = Dict{Symbol,Int8}(a => Int8(i) for (i, a) in enumerate(sorted_alt_actions)),
        alt_index            = Dict{Symbol,Int8}(p.altName => Int8(i) for (i, p) in enumerate(plugins)),
        accum_alt_idxs       = sort!(Int8[i for (i, p) in enumerate(plugins) if p.setMode === :accumulate]),
        mutex_alt_idxs       = sort!(Int8[i for (i, p) in enumerate(plugins) if p.setMode === :mutExclusive]),
        action_to_settribute = Dict{Symbol,Symbol}(s.name => s.settribute for s in action_specs
                                                   if s.settribute !== nothing),
        spec_index           = _first_wins_spec_index(action_specs),
    )
end

"The seal (HC-9): the algorithm-tagged registration digest over every declared slot + the declared source digests + policy_id."
_mint_seal(plugins::Vector{PlugIn}, action_specs::Vector{ActionSpec})::String =
    string("fnv1a64:", string(_registration_digest(action_specs; plugins = plugins), base = 16, pad = 16))

"""
    validate(builder::RegistryBuilder) -> Vector{Diagnostic}

Run the ONE validation chain over the builder's declarations and return EVERY diagnostic (errors AND
warnings, deterministic order) — never throws. Empty ⇒ publishable.
"""
validate(b::RegistryBuilder) = _validate_registration(b.plugins, b.action_specs)

"""
    publish(builder::RegistryBuilder) -> AlterantRegistry

The SANCTIONED route to a SEALED registry — the only SUPPORTED one for conforming callers (not the
only possible one in-process: the construction token and this file's helpers are reachable by any
loaded module, the accident-grade bound recorded at `_SealToken`). Refuses (throws `RegistrationRefused` carrying every
diagnostic) if `validate` reports any error; proceeds on warnings. Atomic COPY-publication (T2-bis):
every container is copied by the domain copier `_domain_copy` — callables/Types/Symbols/Strings/
VersionNumbers/numbers carried BY REFERENCE, containers and slot structs REBUILT at their exact
concrete types, sharing preserved within each copy stage; `deepcopy_internal` is never dispatched,
so no user type can specialize the copy (a later mutation of the builder cannot reach a published
registry, and vice versa). The derived tables come from the declarations alone; the seal field
keeps the registration FINGERPRINT (a lossy cache key); the `_snapshot` baseline is a SECOND,
disjoint domain copy of all eleven `_SNAPSHOT_FIELDS`. The published value's containers are
READ-ONLY by contract — a mutation through them is detected at the door (`POST_SEAL_MUTATION`)
by the structural deep-egal comparison against the snapshot, never silently effective — for
conforming code (the disclosed bounds apply, docs/public-api.md §1.2).
"""
function publish(b::RegistryBuilder)
    diags = validate(b)
    any(d -> d.severity === :error, diags) && throw(RegistrationRefused(diags))
    # (cure batch 1) warnings are NEVER swallowed by the sanctioned route: every warning
    # diagnostic is emitted at publication (the legacy load-time @warn behavior kept); a caller
    # wanting them as data calls `validate` first.
    for d in diags
        d.severity === :warning && @warn d.message
    end
    # T2-bis STAGE 1 (T2BIS-DESIGN §5): the LIVE field values by the domain copier — validate
    # has run, so every value is in-domain and acyclic (predicate ground per field: validate
    # reaches `plugins`/`action_specs`; the derived tables are grounded in their concrete
    # declared types + their construction from the already-copied record) — ONE stage-1 memo.
    # (crx-t2bis cures A2/A3) the ONE remaining escape class — a USER `hash`/`isequal`
    # thrown at a Dict rebuild fill, or an undefined element racing in after validate —
    # converts to the typed refusal here, never a raw exception out of `publish`.
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
    # (cure batch 4) validation has already refused cyclic/unencodable declarations; this catch is
    # the defensive conversion so no internal exception can ever leave the public lifecycle.
    seal = try _mint_seal(plugins, specs) catch e
        (e isa _CyclicSlot || e isa _UnencodableSlot) || rethrow()
        throw(RegistrationRefused([Diagnostic(:REG_PROTOCOL, :error, string("GoMeta registry: the ",
            "declared record could not be sealed (", e isa _CyclicSlot ? "a cyclic container" :
            string("an unencodable value of type ", e.T), ") — the record shape law"), nothing)]))
    end
    # T2-bis STAGE 2: the SNAPSHOT — built MECHANICALLY over the field-name tuple (no per-table
    # keyword binding anywhere); ONE stage-2 memo, SEPARATE from stage 1's, so live and snapshot
    # share no mutable container (the disjointness assert below); the fingerprint String is a
    # leaf, carried by reference — a seal-only divergence fires at path `seal`.
    base = (; plugins = plugins, action_specs = specs, seal = seal, t...)
    snapshot = let m2 = IdDict{Any,Any}()
        NamedTuple{_SNAPSHOT_FIELDS}(map(k -> copyc(base[k], m2), _SNAPSHOT_FIELDS))
    end
    _assert_snapshot_disjoint(base, snapshot)
    return AlterantRegistry(_SealToken(), plugins, specs, t, seal, snapshot)
end

"""
    _registry_door_check(registry) -> Vector{Diagnostic}

The R-V04-34 STRICT door, T2-bis ONE-CHECK form (T2BIS-DESIGN §6): an UNPUBLISHED registry
(`_snapshot === nothing`) refuses typed, naming the sanctioned path; else the eleven
`_SNAPSHOT_FIELDS` are compared field-by-field against the publish-time snapshot by the ONE
structural deep-egal walk (`===`-only leaves; no `hash`/`isequal`/`==`/user `show` dispatched
anywhere, rendering included) and the FIRST divergent path fires exactly one
`POST_SEAL_MUTATION` row — the real freeze gate (M-AC-9), accident-grade: typed refusal of
post-seal mutation by conforming code. The retired seal re-mint, derived-table re-derivation
and callable-identity compare lose no detection for conforming code (the field lists being
COMPLETE): re-derivation is deterministic, so it never catches what the snapshot cannot; the
same-typed table swap is excluded by §5's by-name construction; every callable identity —
altConstructor, the setters/getters, `atom.evaluate`, `spec.validate` — is a snapshot leaf
compared by `===`.
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

## (The interim `_fill_action_owners!` uniqueness assert was RETIRED at the registration build
## — `_register_actions!` above is its successor, carrying the full clash law with
## both arms behind the disposition switch; its unit test flipped with it.)

"""
    const DEFAULT_REGISTRY :: AlterantRegistry

The v0 default alterant inventory — built ONCE at load and READ-ONLY thereafter. Mutating any of its
`Dict`/`Vector` fields destroys the determinism the registry exists to provide, so treat it as frozen.
It is threaded into `ProcessState` via `init_state(parse_state, config, DEFAULT_REGISTRY)`, and the
absorb/apply phases read it from there (`ctx().registry`) rather than from a module global.
"""
const DEFAULT_REGISTRY = build_default_registry()

## v0.4 T1 — the `VISIB_TO_SETTRIBUTE` convenience alias is RETIRED (a registered breaking change,
## no forwarding window): it was the SAME `Dict` object as the registry's map (`===`, not a copy),
## i.e. a mutable alias onto the "immutable" inventory — the measured post-publication-mutation
## class the freeze/publication seal (T2) closes. The write-back at both grains reads the
## PER-CALL `st.registry.action_to_settribute` (derived from the declared per-action `settribute`
## slots); the default inventory's table is `DEFAULT_REGISTRY.action_to_settribute`. It was never
## in the `export`/`public` surface (docs/public-api.md §1), so no consumer contract moves.

"""
    const DEFAULT_GRAMMAR_PROFILE :: GrammarProfile

The pinned closed-default grammar profile — built HERE (not in the profile file) because its
registration digest is a fold over `DEFAULT_REGISTRY.action_specs`, which must exist first
(the module include order puts the profile substrate before the registry; every reference to
this const is call-time-bound, so late construction is sound). Struct + constructor +
resolution law live in the profile file; this is the ONE default-profile construction site.
"""
const DEFAULT_GRAMMAR_PROFILE = _mk_profile(:jl_share_v1, :closed_v1,
    _registration_digest(DEFAULT_REGISTRY.action_specs;
        plugins = DEFAULT_REGISTRY.plugins))