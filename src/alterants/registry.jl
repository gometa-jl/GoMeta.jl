# registry.jl — the alterant inventory: label whitelist + toy setters, state accessors, the default registry
#
# IS: the register file of the alterant layer — two nested sub-modules plus a top-level tail. `module
#     Alterants`: the closed label whitelist `sortedSetOfLabelsSVec` + the toy setters `setLabels`/
#     `checkLabels`/`setVisib`/`setId` over the `@namedElement` types `Visib` (Bool: hide/show/discard)
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
#     T2): its Dict/Vector fields stay mutable containers, but a mutation by CONFORMING code
#     through any of them — the declared record, a derived table, or a callable IDENTITY — is
#     DETECTED at the entry door (`POST_SEAL_MUTATION`), never silently effective (accident-grade:
#     a callable's BEHAVIOR is not pinned by its identity, and the door is an entry check, not a
#     lock over the run — B-2); the former `===` alias onto its write-back Dict is retired (v0.4 T1).
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

## The label whitelist: the corpus-documented labels `:label1`..`:label5` plus (since 0.3.0)
## the fixed pictograph vocabulary (byte-exact names, no normalization — an emoji variant with
## different bytes is a different, unknown name). The whitelist is
## PURELY a membership test: `sortedSetOfLabelsSVec` is consumed only by `insorted` in `setLabels`
## below, and any label outside it raises the stable "GoMeta apply: unknown label" refusal, which
## names the accepted set (docs/public-api.md §3.4).
goMetaLabels = [:label1, :label2, :label3, :label4, :label5]
append!(goMetaLabels, Symbol.(["⛔", "💯", "🇨🇭", "🏔️", "🍒", "🫕", "💡", "💣", "🧮", "📝",
    "💕", "⌛", "💸", "💾", "⛓️‍💥", "⛓️", "📸", "🎨", "🍻", "🔥", "🐣", "😘", "🎿",
    "🚀", "🌍", "🌳", "🌛", "🌷", "🌹", "🌼", "🍀", "🌞", "💫"]))

const sortedSetOfLabelsSVec = SVector{length(goMetaLabels),Symbol}(
    sort(goMetaLabels))

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
        for label ∈ labels
            if insorted(label, sortedSetOfLabelsSVec)
                crntLabels[label] = true
            else
                error("GoMeta apply: unknown label ", repr(first(String(label), 40)),
                    " — not in v0's closed label whitelist (sortedSetOfLabelsSVec = ",
                    sortedSetOfLabelsSVec, "); see docs/public-api.md §3.4")
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
    for label ∈ labels
        ## Condition-side whitelist guard: a label outside the closed v0 whitelist refuses loudly
        ## (the SAME contract as setLabels' guard above), never a silent `false` — a query for an
        ## unknown label is a vocabulary error, not an unset label.
        if !insorted(label, sortedSetOfLabelsSVec)
            error("GoMeta apply: unknown label ", repr(first(String(label), 40)),
                " — not in v0's closed label whitelist (sortedSetOfLabelsSVec = ",
                sortedSetOfLabelsSVec, "); see docs/public-api.md §3.4")
        end
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
_heading_validate_text(t) =
    isempty(String(t)) && error("GoMeta absorb: empty heading text — an empty ",
        "heading is refused at v0.2 (a ratified standing decision; ",
        "see docs/public-api.md §3.4)")

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
        return st.registry.plugins[altInd].getAltInstance(
            st.working[altInd],
            altActionName,
            args...
        )
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
        PlugIn(:labels, :accumulate,   Dict{Symbol,Bool}, Alterants.setLabels, Alterants.checkLabels, nothing),
        PlugIn(:Visib,  :mutExclusive, Alterants.Visib,   Alterants.setVisib,  nothing,               nothing),
        PlugIn(:id,     :mutExclusivePerField, Alterants.Id, Alterants.setId,  nothing,               nothing),
        # The Heading plugin. setMode `:localOnly` — the THIRD inheritance mode:
        # a localOnly alterant's value applies ONCE, WHERE IT STANDS — its
        # actions NEVER ENQUEUE into the slot tensors, so the inheritance
        # backtrack (both apply passes) never visits them; delivery happens at
        # the absorb seam, keyed to the metaLine's own occurrence handle (the
        # outline model: one row per heading occurrence, document order
        # recoverable from handles). Deliberately in NEITHER derived set below.
        PlugIn(:heading, :localOnly, Alterants.Heading, Alterants.setHead, nothing, nothing),
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
profile tests). FNV-1a over the canonical serialization (deterministic across sessions and
Julia versions).
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
            # with a different setter kept the seal). Callables fold by name — the identity
            # comparison at the door (`_callables`, `===`) closes the same-named-swap remainder.
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
## unqualified, callables by NAME, containers element-wise in declaration order, and INJECTIVE
## (cure batch 1: the first encoding joined elements with delimiters, so `[Symbol("a,b")]` and
## `[:a, :b]` folded identically — every element, every string leaf and every component is now
## LENGTH-PREFIXED, netstring-style `<bytes>:<text>`, so no boundary can be re-cut).
_ns(s::String)::String = string(sizeof(s), ":", s)
_nsv(parts)::String = join((_ns(String(p)) for p in parts), ",")
_slot_text(x::Nothing)::String = "-"
_slot_text(x::Symbol)::String = string("y", _ns(String(x)))
_slot_text(x::AbstractString)::String = string("s", _ns(String(x)))
_slot_text(x::Bool)::String = x ? "T" : "F"
# (cure batch 2) the CONCRETE numeric type is part of the value (`Int8(1)` ≠ `Int64(1)`), and a
# vector is not a tuple — distinct tags, so a same-display substitution moves the seal.
_slot_text(x::Number)::String = string("n", _nsv((_type_text(typeof(x)), string(x))))
# (cure batch 3) floats encode BIT-EXACTLY — display text collapses distinct NaN payloads (and
# signed zeros' bit patterns) into one string; the bits are the value.
_slot_text(x::Float64)::String = string("n", _nsv((_type_text(typeof(x)), string(reinterpret(UInt64, x); base = 16))))
_slot_text(x::Float32)::String = string("n", _nsv((_type_text(typeof(x)), string(reinterpret(UInt32, x); base = 16))))
_slot_text(x::Float16)::String = string("n", _nsv((_type_text(typeof(x)), string(reinterpret(UInt16, x); base = 16))))
_slot_text(x::VersionNumber)::String = string("v", _ns(string(x)))
_slot_text(x::Type)::String = string("t", _ns(_type_text(x)))
_slot_text(f::Function)::String = string("f", _ns(String(nameof(f))))
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
_slot_text(v::AbstractVector)::String = _slot_container("[", "]", v)
_slot_text(v::Tuple)::String = string("<", _nsv(_slot_text(e) for e in v), ">")
_slot_text(p::Pair)::String = string("(", _nsv((_slot_text(p.first), _slot_text(p.second))), ")")
_slot_text(d::AbstractDict)::String =
    string("{", _nsv(string(_ns(_slot_text(k)), _ns(_slot_text(d[k]))) for k in sort!(collect(keys(d)); by = string)), "}")
_slot_text(nt::NamedTuple)::String =
    string("N", _nsv(string(_ns(String(k)), _ns(_slot_text(getfield(nt, k)))) for k in keys(nt)))
_slot_text(x::NoDefault)::String = "NoDefault"
_slot_text(x::Declared)::String = string("Declared", _ns(_slot_text(x.value)))
_slot_text(x::DomainRef)::String = string("DomainRef", _nsv((_slot_text(x.artifact), x.digest)))
_slot_text(x::CaptureDecl)::String =
    string("Capture", _nsv((_type_text(x.instance_type), String(x.attr_scheme), String(x.multiplicity), _slot_text(x.mode_gate))))
_slot_text(x::EffectRow)::String = string("Effect", _nsv((String(x.kind), _slot_text(x.payload))))
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
# The honest fallback: an OPAQUE payload of an unknown type folds by its type + `repr` — a
# disclosed limit (a mutation whose `repr` is stable is invisible to the seal); T10 defines the
# opaque payload shapes and closes this by giving each an encoder.
_slot_text(x)::String = string("any", _nsv((string(typeof(x)), repr(x))))

"The canonical serialized text of one overload row (the digest's SORT KEY only — the fold
itself goes through the injective `_fold_parts`, never through this joined text)."
_overload_text(ov::ActionOverload)::String =
    string("|ov|", join((_type_text(t) for t in ov.sig_types), ","),
        "|", join(ov.kinds, ","), "|", join(ov.kind_sources, ","),
        "|", ov.vararg_kind, "|", _type_text(ov.return_type), "|", ov.effect,
        "|", ov.queryable, "|", ov.applicability, "|", ov.phase, "|", ov.grammar)

# The digest's type serialization: module-UNQUALIFIED (stable across load contexts) but
# parameter-FAITHFUL (`Dict{Symbol,Bool}` ≠ `Dict{Symbol,Int}` — a real drift class a bare
# `nameof` would collapse). Non-type parameters fall through to `string` — NOTE (recorded
# limits): the `string` fallback for UnionAll/Union sig types is show-context-dependent
# (may qualify); symbol-vs-string `Val` parameters collide as the same text; and two
# SAME-NAMED types from DIFFERENT modules collide as one identity (the unqualified choice's
# deliberate trade — dispatch treats them as distinct; a second type-contributing module is
# the revisit trigger). No shipped record row reaches any of these — extend consciously.
function _type_text(t)::String
    t === Any && return "Any"
    t isa DataType || return string(t)
    isempty(t.parameters) && return String(nameof(t))
    return string(nameof(t), "{", join((_type_text(p) for p in t.parameters), ","), "}")
end

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
    declared_by_setter = Dict{Function,Vector{Vector{Any}}}()
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
            any(m.sig == sig_tuple for m in methods(setter)) ||
                sigm(string("GoMeta registry: declared overload has no executable ",
                    "method — action ", repr(spec.name), " declared ", sig_tuple,
                    " on ", setter, " (declared-but-unimplemented refuses at ",
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
                    " vs signature slot type ", t,
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
        f in order || push!(order, f)
    end
    for setter in order
        sigs = declared_by_setter[setter]
        for m in sort!(collect(methods(setter)); by = m -> string(m.sig))
            # (cure batch 2) a `where`-parametric method's `sig` is a UnionAll — unwrap it, never
            # index `.parameters` on it (validate must not throw on a parametric setter)
            m_argtypes = collect(Base.unwrap_unionall(m.sig).parameters[2:end])
            matched = any(sigs) do full
                length(full) == length(m_argtypes) &&
                    all(a === b for (a, b) in zip(full, m_argtypes))
            end
            matched || sigm(string("GoMeta registry: executable method matches no ",
                "declared overload — ", m.sig, " on ", setter,
                " (implemented-but-undeclared: declare it — as an internal ",
                "grammar=false row if it is not action grammar; the loud ",
                "drift diagnostic)"), nameof(setter))
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
                "GoMeta registry: declared return type ", ov.return_type,
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
diagnostic) if `validate` reports any error; proceeds on warnings. Atomic COPY-publication: every
container is copied, so no mutable container is shared between the builder and the published value
(a later mutation of the builder cannot reach a published registry, and vice versa); the derived
tables come from the declarations alone; the seal covers the declared record. The published value's
containers are READ-ONLY by contract — a mutation through them is detected at the door
(`POST_SEAL_MUTATION`), never silently effective.
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
    # DEEP copies: the record structs are immutable but carry Vectors/Dicts (constraints, atoms,
    # sugar rows, vocabulary flags, provenance sources) — a shallow `copy` of the outer vectors
    # would leave those NESTED containers shared with the builder (finding 3's class: a later
    # builder mutation reaching the published record). Callables/Types deepcopy to themselves.
    plugins = deepcopy(b.plugins)
    specs   = deepcopy(b.action_specs)
    t = _derive_tables(plugins, specs)
    return AlterantRegistry(_SealToken(), plugins, t.sorted_alt_actions, t.action_to_plugin,
                            t.action_index, t.alt_index, t.accum_alt_idxs, t.mutex_alt_idxs,
                            t.action_to_settribute, specs, t.spec_index, _mint_seal(plugins, specs),
                            _callable_identities(plugins, specs))
end

"""
    _registry_door_check(registry) -> Vector{Diagnostic}

The R-V04-34 STRICT door: an UNPUBLISHED registry (`seal === nothing`) refuses typed, naming the
sanctioned path; a published registry whose recomputed seal differs from the stored one has been
MUTATED after publication (through one of its containers) and refuses `POST_SEAL_MUTATION` — the
real freeze gate (M-AC-9), accident-grade: typed refusal of post-seal mutation by conforming code.
"""
function _registry_door_check(registry::AlterantRegistry)
    diags = Diagnostic[]
    if registry.seal === nothing
        push!(diags, Diagnostic(:REG_UNPUBLISHED, :error, string("GoMeta registry: the registry passed ",
            "to goMeta is not published — the v0.4 door accepts ONLY published (validated + sealed) ",
            "registries; build it via RegistryBuilder → validate → publish (GoMeta.publish) and pass ",
            "the published value"), nothing))
        return diags
    end
    # (cure batch 1) THREE checks, all three required — the CRX after-T2 set showed each alone
    # leaves a mutation class through: (i) the seal over the DECLARED record; (ii) every DERIVED
    # table re-derived from the declarations and compared (a mutated `action_to_settribute`,
    # `action_index`, `alt_index`, index vector or `spec_index` — or a re-ordered `action_specs`
    # — changes dispatch without touching the declared bytes); (iii) the validated CALLABLE
    # identities compared by `===` (a same-named swapped setter/getter/ctor/evaluator/validator).
    what = String[]
    # (cure batch 3) an UNENCODABLE declared record (a container mutated into a cycle) is itself a
    # post-publication mutation — refused typed, never a StackOverflowError out of the door
    sealed_now = try _mint_seal(registry.plugins, registry.action_specs) catch e
        e isa _CyclicSlot || rethrow(); nothing end
    (sealed_now !== nothing && registry.seal == sealed_now) || push!(what,
        sealed_now === nothing ? "the declared record (a cyclic container — no longer encodable)" :
                                 "the declared record (seal)")
    derived = try _derive_tables(registry.plugins, registry.action_specs) catch; nothing end
    if derived === nothing
        push!(what, "the declared record (tables no longer derivable)")
    else
        for f in (:sorted_alt_actions, :action_to_plugin, :action_index, :alt_index, :accum_alt_idxs,
                  :mutex_alt_idxs, :action_to_settribute, :spec_index)
            getfield(registry, f) == getfield(derived, f) || push!(what, string("the derived table `", f, "`"))
        end
    end
    now = _callable_identities(registry.plugins, registry.action_specs)
    (registry._callables === nothing || length(now) != length(registry._callables) ||
        !all(a === b for (a, b) in zip(now, registry._callables))) &&
        push!(what, "a callable identity (setter/getter/constructor/evaluator/validator)")
    isempty(what) || push!(diags, Diagnostic(:POST_SEAL_MUTATION, :error, string("GoMeta registry: the ",
        "published registry was MUTATED after publication — ", join(what, "; "), " no longer match(es) ",
        "the sealed publication ", registry.seal, "; re-publication is the sanctioned change path"),
        registry.seal))
    return diags
end

"""
The validated callable identities of a record, declaration order, as an IMMUTABLE Tuple (compared
by `===` at the door; cure batch 2: a Vector baseline could be rewritten through the published
value). Honest bound (the reconfirm set's finding): identity ≠ behavior — a closure over a `Ref`
or a generic whose methods are redefined keeps its identity while its behavior moves; both are
acts of loaded code with full process authority (B-2), outside the accident-grade guarantee.
"""
function _callable_identities(plugins::Vector{PlugIn}, action_specs::Vector{ActionSpec})
    ids = Any[]
    for p in plugins
        push!(ids, p.altConstructor, p.setAltInstance, p.getAltInstance)
        for a in p.atoms; push!(ids, a.evaluate); end
    end
    for s in action_specs; push!(ids, s.validate); end
    return Tuple(ids)
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