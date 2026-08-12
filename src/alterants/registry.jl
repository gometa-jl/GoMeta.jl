# registry.jl — the alterant inventory: label whitelist + toy setters, state accessors, the default registry
#
# IS: the register file of the alterant layer — two nested sub-modules plus a top-level tail. `module
#     Alterants`: the closed label whitelist `sortedSetOfLabelsSVec` + the toy setters `setLabels`/
#     `checkLabels`/`setVisib`/`setId` over the `@namedElement` types `Visib` (Bool: hide/show/discard)
#     and `Id` (Int16: cell/parent/file). `module CnS`: the per-call state accessors `wipeAltActionSlots`/
#     `updateMetaHierarchy`/`getState`/`getAltState`. The tail builds the immutable `AlterantRegistry`
#     (type: src/state.jl) — `build_default_registry()` → `const DEFAULT_REGISTRY` + `VISIB_TO_SETTRIBUTE`.
# DOES: registers the closed v0 inventory (3 alterants / 7 actions) in DECLARATION order (labels=1,
#     Visib=2, id=3 — the live key is :id): the sorted action table, the parallel action→plugin index, the name→index Dicts,
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
#     condition atom is the deferred E-07 row. `DEFAULT_REGISTRY` is read-only by convention (its
#     Dict/Vector fields are mutable containers); `VISIB_TO_SETTRIBUTE` aliases its Dict (===, not a copy).
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
    st.mh.slots[st.crnt_idx] = findfirst(isequal(false), st.mh.slot_occupied)
    st.mh.slot_occupied[st.mh.slots[st.crnt_idx]] = true

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
#     + the `Dict` lookups + the SORTED `accum_alt_idxs` + the `visib_to_settribute` identity map through
#     the CHECKED owner fill (a duplicate action name refuses at load — no silent last-writer-wins), and
#     returns `const DEFAULT_REGISTRY`. `VISIB_TO_SETTRIBUTE` aliases that same map.
# REASONING: alterant/action indices are fixed by declaration order, never by `Dict` iteration order —
#     those indices are baked into the eval'd condition strings.
# PURPOSE: a deterministic-by-construction, immutable, read-only alterant inventory for the pipeline.

"""
    build_default_registry() -> AlterantRegistry

Build the v0 alterant inventory in DECLARATION order. Constructs fresh top-level `PlugIn` instances for
`labels` / `Visib` / `Id` / `Heading` (the heading alterant — its names are RATIFIED: alterant
`Heading`, action `head`) in the `state.jl` type, derives the sorted action table + the lookups through the
clash law (a duplicate action name refuses at load, naming both owners; deterministic — never silent
last-writer-wins), verifies the DECLARED registration record against the executable method tables
(declared ≡ executable, both directions, checked at registration), and returns the immutable
`AlterantRegistry` that is consumed READ-ONLY via `DEFAULT_REGISTRY`. Pure — no
module-load side-effects.
"""
function build_default_registry()
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
        ActionSpec(:hide, :identifier, Int8(2),
            [_ov(Type[Alterants.Visib, Symbol], Symbol[], Symbol[]; rt=Bool),
             _ov(Type[Alterants.Visib, SubString{String}], Symbol[], Symbol[];
                 rt=Bool, gr=false)],
            0, :none, nothing, nothing),
        ActionSpec(:show, :identifier, Int8(2),
            [_ov(Type[Alterants.Visib, Symbol], Symbol[], Symbol[]; rt=Bool)],
            0, :none, nothing, nothing),
        ActionSpec(:discard, :identifier, Int8(2),
            [_ov(Type[Alterants.Visib, Symbol], Symbol[], Symbol[]; rt=Bool)],
            0, :none, nothing, nothing),
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
    owner_of_action = _register_actions!(Dict{Symbol,Int8}(), action_specs)
    _record_wellformed_check(action_specs, plugins)
    _reflection_cross_check(action_specs, plugins)
    _value_algebra_check(action_specs)
    _reachability_check(action_specs)
    _candidacy_check(action_specs)
    spec_index = _first_wins_spec_index(action_specs)

    sorted_alt_actions = sort!(collect(keys(owner_of_action)))   # the sorted action table
    action_index       = Dict{Symbol,Int8}(a => Int8(i) for (i, a) in enumerate(sorted_alt_actions))
    action_to_plugin   = Int8[owner_of_action[a] for a in sorted_alt_actions]  # parallel to sorted_alt_actions
    alt_index          = Dict{Symbol,Int8}(p.altName => Int8(i) for (i, p) in enumerate(plugins))
    accum_alt_idxs     = sort!(Int8[i for (i, p) in enumerate(plugins) if p.setMode === :accumulate])  # SORTED — apply-phase `insorted`/`searchsortedfirst` depend
    # Per-ALTERANT mutually-exclusive plugins ONLY (`:mutExclusive`): the apply-phase within-slot
    # first-applicable stop keys on this set. `:mutExclusivePerField` (the `id` compound: one value
    # PER FIELD — cell/parent/file fill independently) is deliberately OUTSIDE both sets, so it
    # keeps the pre-stop flow; its per-field semantics are deferred at v0.
    mutex_alt_idxs     = sort!(Int8[i for (i, p) in enumerate(plugins) if p.setMode === :mutExclusive])
    # A Visib action → its `ComponentSettribute` key. IDENTITY at v0 — verified, not assumed: the Visib
    # write-back in GoMeta.jl sets the matching settribute key directly, and `ComponentSettribute`
    # carries the `:hide`/`:show`/`:discard` keys. The explicit map decouples the action name from the
    # settribute key, so a divergence between the two would be a registry edit, not a code change.
    visib_to_settribute = Dict{Symbol,Symbol}(
        s.name => s.name for s in action_specs if s.plugin == Int8(2))

    return AlterantRegistry(
        plugins, sorted_alt_actions, action_to_plugin,
        action_index, alt_index, accum_alt_idxs, mutex_alt_idxs, visib_to_settribute,
        action_specs, spec_index,
    )
end

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
    for spec in action_specs
        if haskey(owner_of_action, spec.name)
            msg = string("GoMeta registry: duplicate alterant action name ",
                repr(spec.name), " — already owned by plugin index ",
                owner_of_action[spec.name], ", re-declared by plugin index ",
                spec.plugin, " (the clash law; disposition = ", disposition, ")")
            if disposition === :refuse
                error(msg, "; the registration REFUSES at load — remedy: rename ",
                    "one action or retire one declaration (no action ever ",
                    "registers through silent last-writer-wins)")
            else
                @warn string(msg, "; keeping the FIRST declaration ",
                    "(deterministic first-writer-wins) — remedy: rename one ",
                    "action or retire one declaration")
                continue
            end
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
    for spec in action_specs
        spec.spelling in _SPELLING_KINDS ||
            error("GoMeta registry: unknown spelling tag ", repr(spec.spelling),
                " on action ", repr(spec.name), " (the record shape law)")
        spec.sugar_candidacy in _CANDIDACIES ||
            error("GoMeta registry: unknown sugar-candidacy tag ",
                repr(spec.sugar_candidacy), " on action ", repr(spec.name),
                " (the record shape law)")
        for ov in spec.overloads
            length(ov.kinds) == length(ov.kind_sources) ||
                error("GoMeta registry: kinds/kind_sources arity mismatch on ",
                    repr(spec.name), " (the record shape law)")
            all(k in _LITERAL_KINDS for k in ov.kinds) &&
                (ov.vararg_kind === nothing || ov.vararg_kind in _LITERAL_KINDS) ||
                error("GoMeta registry: unknown literal kind on ", repr(spec.name),
                    " (the record shape law)")
            length(ov.kinds) <= length(ov.sig_types) - 2 ||
                error("GoMeta registry: the kinds vector on ", repr(spec.name),
                    " is longer than the overload's user arity — leading kinds ",
                    "would silently describe the dispatch preamble (the record ",
                    "shape law; the kinds tail-align to the LAST user slots)")
            all(s in _KIND_SOURCES for s in ov.kind_sources) ||
                error("GoMeta registry: unknown kind source on ", repr(spec.name),
                    " (the record shape law)")
            ov.effect in _EFFECT_KINDS ||
                error("GoMeta registry: unknown effect class ", repr(ov.effect),
                    " on ", repr(spec.name), " (the record shape law)")
            ov.applicability in _APPLICABILITIES ||
                error("GoMeta registry: unknown applicability ",
                    repr(ov.applicability), " on ", repr(spec.name),
                    " (the record shape law)")
            ov.phase in _PHASES ||
                error("GoMeta registry: unknown delivery phase ", repr(ov.phase),
                    " on ", repr(spec.name), " (the record shape law)")
            ov.queryable && plugins[spec.plugin].getAltInstance === nothing &&
                error("GoMeta registry: action ", repr(spec.name),
                    " declares queryable=true but its plugin carries no getter ",
                    "(the query seam would crash — the I20 class; the record ",
                    "shape law)")
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
        addr = [ov for ov in spec.overloads if Symbol <: ov.sig_types[2]]
        for i in eachindex(addr), j in (i + 1):lastindex(addr)
            a, b = addr[i], addr[j]
            na, nb = length(a.sig_types) - 2, length(b.sig_types) - 2
            overlap = a.vararg_kind === nothing && b.vararg_kind === nothing ?
                    na == nb :
                a.vararg_kind !== nothing && b.vararg_kind !== nothing ?
                    true :
                a.vararg_kind === nothing ? na >= nb : nb >= na
            overlap && error("GoMeta registry: action ", repr(spec.name),
                " declares two Symbol-addressable rows with overlapping arity ",
                "sets — the dispatch-target uniqueness law refuses (one declared ",
                "form per arity; the guard's row set must be a singleton)")
        end
    end
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
            spec.keyed_slot)
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
            _type_text(p.altConstructor), p.getAltInstance !== nothing)
    end
    return h
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
    declared_by_setter = Dict{Function,Vector{Vector{Any}}}()
    for spec in action_specs
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
                error("GoMeta registry: declared overload has no executable ",
                    "method — action ", repr(spec.name), " declared ", sig_tuple,
                    " on ", setter, " (declared-but-unimplemented refuses at ",
                    "load; the reflection cross-check; the match is EXACT ",
                    "per-signature, never subtype dispatch)")
            push!(sigs, full)
            # (c) kind ↔ type agreement on the literal tail (the vararg slot's
            # agreement lives in the (a) construction above — delta-trued)
            lit = ov.sig_types[(length(ov.sig_types) - length(ov.kinds) + 1):end]
            for (k, t) in zip(ov.kinds, lit)
                ok = t === Any ||
                     (k === :string && t <: AbstractString) ||
                     (k === :symbol && t === Symbol) ||
                     k === :raw
                ok || error("GoMeta registry: literal-kind/type disagreement — ",
                    "action ", repr(spec.name), " kind ", repr(k),
                    " vs signature slot type ", t,
                    " (the reflection cross-check)")
            end
        end
    end
    # (b) executable ≡ declared, the executable→declared direction
    for (setter, sigs) in declared_by_setter
        for m in methods(setter)
            m_argtypes = collect(m.sig.parameters[2:end])
            matched = any(sigs) do full
                length(full) == length(m_argtypes) &&
                    all(a === b for (a, b) in zip(full, m_argtypes))
            end
            matched || error("GoMeta registry: executable method matches no ",
                "declared overload — ", m.sig, " on ", setter,
                " (implemented-but-undeclared: declare it — as an internal ",
                "grammar=false row if it is not action grammar; the loud ",
                "drift diagnostic)")
        end
    end
    return nothing
end

"The id-5 value-algebra refusal: declared return types must sit in the closed serializable set."
function _value_algebra_check(action_specs::Vector{ActionSpec})
    for spec in action_specs, ov in spec.overloads
        any(ov.return_type === t for t in _CLOSED_RETURN_TYPES) ||
            error("GoMeta registry: declared return type ", ov.return_type,
                " of action ", repr(spec.name), " is outside the closed ",
                "serializable set ", _CLOSED_RETURN_TYPES,
                " (the value-algebra refusal, id-5)")
    end
    return nothing
end

"The reachability refusal: every GRAMMAR overload's literal kinds must be expressible from the active literal floor (AlterantArgT = Symbol|String)."
function _reachability_check(action_specs::Vector{ActionSpec})
    for spec in action_specs, ov in spec.overloads
        ov.grammar || continue
        for k in vcat(ov.kinds, ov.vararg_kind === nothing ? Symbol[] : [ov.vararg_kind])
            k in (:symbol, :string) ||
                error("GoMeta registry: literal kind ", repr(k), " of action ",
                    repr(spec.name), " is unreachable from the active literal ",
                    "floor (Symbol|String) — the reachability refusal")
        end
    end
    return nothing
end

"The x-8 unactivated-candidacy diagnostic: sugar candidacy without user activation is LOUD at load (the grant register stays closed at two ACTIVATED grants)."
function _candidacy_check(action_specs::Vector{ActionSpec})
    for spec in action_specs
        spec.sugar_candidacy === :candidate &&
            @warn string("GoMeta registry: action ", repr(spec.name),
                " declares sugar CANDIDACY without user activation — the ",
                "candidacy is REGISTERED, not active (activation is a user ",
                "ruling; the grant list is closed at two; x-8)")
    end
    return nothing
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

"""
    const VISIB_TO_SETTRIBUTE :: Dict{Symbol,Symbol}

The Visib-action → settribute-key map of the DEFAULT inventory (identity at v0), kept as a
convenience alias. The write-back at both grains reads the PER-CALL `st.registry.visib_to_settribute`
(a custom registry's mapping is honored), not this alias. It is the SAME `Dict` object as
`DEFAULT_REGISTRY.visib_to_settribute` (===, not a copy) — READ-ONLY by convention; mutating it
corrupts the registry.
"""
const VISIB_TO_SETTRIBUTE = DEFAULT_REGISTRY.visib_to_settribute

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