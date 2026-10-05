# apply.jl — the Apply phase: evaluates queued alterant conditions and runs the setters.
#
# IS: the Apply phase of the GoMeta engine. `detAltValuesForSetOfSlots` walks the eligible
#     meta-hierarchy slots and decides every queued alterant action in two passes — the
#     `:accumulate`-mode alterants over every slot except the primary (first) one, then all
#     queued actions slot by slot — building alterant instances into the per-call working dict
#     (`st.working` off `ctx()`, rebuilt fresh on every call) and returning the set-alterant
#     index vector with its count. `applyAltActionFns(::BLS.Segment)` and
#     `applyAltActionFns(::BLS.Block)` snapshot the settribute, gather the occupied eligible
#     slots for their grain (the Segment overload scans the `userMHIdx`/`lineMHIdx` levels
#     plus, when the enclosing Block is `:attachedToMeta`, the depth window; the Block overload
#     scans `userMHIdx` plus the depth window down to `fileMHIdx`; both append the `fallBack` level LAST —
#     R-V04B-55 (3), stage 2's commit 3), and delegate.
#     `_invoke_set` is the sole invocation seam for every plugin set-function.
# DOES: evaluates each queued action's stored condition — `nothing` means set unconditionally,
#     otherwise the stored `ConditionAST` is evaluated at apply time by the closed condition
#     interpreter (README SECURITY; docs/public-api.md §3.2) — the engine walks it itself against
#     the per-call settribute snapshot; no condition text reaches Julia's `eval` in a
#     default-configured run (the opt-in `:full_eval_v1` marker dispatches to its extension's
#     registered handler instead).
#     An alterant already set in an earlier-processed slot is never re-set. `_invoke_set` splats the
#     queued args tuple once into the setter and converts the malformed-argument crash classes
#     (MethodError, ArgumentError, OverflowError) into the stable refusal
#     "GoMeta apply: invalid arguments" (docs/public-api.md §3.4;
#     witness tests/unit/arg_guard_tests.jl), raised OUTSIDE the catch so the refusal
#     is the sole displayed exception; every other exception rethrows — internal defects stay
#     loud and correctly attributed.
# REASONING: conditions travel as parsed condition ASTs and arguments as opaque tuples, so there
#     is one auditable evaluation site (the closed interpreter's `evaluate`), one auditable setter
#     seam, plus explicit guards ("GoMeta internal invariant violated …", not reachable from any
#     v0 input) on impossible apply states. Honest edges: the E-06 absorb-path guarded refusal keeps
#     its typed conversion deferred (the E-04 apply-path crash origin left with the Visib write-back, stage 3's commit 4)
#     (docs/public-api.md §3.1); the BARE unqueryable condition atom aborts raw at evaluation —
#     the E-07 pending mint (docs/public-api.md §3.2/§3.4).
# PURPOSE: a runnable, observable Apply phase whose single evaluation site and single setter seam
#     are the package's two replaceable condition surfaces.

## stage 2's commit 2 (R-V04B-35 (d)): the provenance of an APPLIED action — the stating Component's handle
## (recorded at the enqueue, `st.queue.decided_by`), kept per Alterant in APPLICATION ORDER: one entry for a
## single-valued mode (the deciding statement — the first applicable wins), the contributing statements'
## entries for an accumulating one, the applied fields' for the compound. Rebuilt with `st.working`; the
## capture copies it onto every row of the Alterant (`captureEvals!`).
@inline function _record_origin!(st::ProcessState, altIdx::Int8, row::Int, slot::Int8)
    o = st.queue.decided_by[row, slot]
    o === nothing && error("GoMeta apply: an applied action without a recorded origin — ",
        "please report this (not reachable from any input by construction)")
    push!(get!(st.working_origin, altIdx, Vector{UInt8}[]), o)
    return nothing
end

function detAltValuesForSetOfSlots(
    checkTheseSlotsInOrderVec::AbstractVector{Int8}
)
    # ── THE EVALUATION MECHANICS (the algorithm this function implements) ─────────────────────────
    # For ONE entity, resolve every alterant's value from the meta-hierarchy lineage. The slots to
    # consult arrive DEEPEST-PRIORITY-FIRST in `checkTheseSlotsInOrderVec`; each slot's column in the
    # queue matrices holds its enqueued (alterant, action) rows in SOURCE order, with the parallel
    # `conditions`/`args` matrices holding each row's condition expression and argument tuple.
    # A row is APPLICABLE when its condition evaluates true (no condition = implicit true).
    #   Pass 1 (below): `:accumulate` alterants collect through the PRE-primary lineage slots.
    #   Pass 2 (step 2): the priority-order slot walk — ALL primary-slot alterants (incl. its
    #   accumulate rows, which apply there) + the outer slots' non-accumulate alterants.
    #   TWO first-wins guards give one law — THE FIRST APPLICABLE VALUE WINS:
    #     across slots, an alterant set in a prior (higher-priority) slot is skipped entirely;
    #     within a slot, a `:mutExclusive` alterant already satisfied by an earlier applicable row
    #     skips the remaining rows of that alterant WITHOUT evaluating their conditions.
    #   `:mutExclusivePerField` alterants (the `id` compound — fields fill independently) take
    #   neither the accumulate pass nor the within-slot stop; see the registry's set derivations.
    #   `:localOnly` alterants (the Heading — set mode `:localOnly`) NEVER appear
    #   here at all: their actions never enqueue, so neither pass can visit one — the value
    #   applied once, where it stood, at the absorb seam (delivery = `capture_heading!`).
    # The winner lands in `st.working` (one instance per alterant); the capture reads from there.
    # ──────────────────────────────────────────────────────────────────────────────────────────────
    # The per-call `ProcessState` is hoisted once: the working alterant-instance dict
    # (`st.working`), the registry inventory + action table + accumulate-set (`st.registry.*`),
    # the slot tensors (`st.mh.count_actions_per_slot`) and the queue
    # (`st.queue.queued`/`.conditions`/`.args`) all read off `ctx()`, so one call's Apply state is
    # never visible to another. The evaluation sites below — `evaluate(st, _cond)` — are the
    # closed condition interpreter (README SECURITY; docs/public-api.md §3.2): a stored
    # `ConditionAST` is walked by the engine itself against the per-call settribute snapshot; no
    # condition text reaches Julia's `eval` in a default-configured run (a `FullEvalCondition`
    # marker — mintable only by the opt-in `:full_eval_v1` extension — dispatches to that
    # extension's registered host-evaluation handler instead).
    local st = ctx()
    ## 1.1 Compute / Determine the values of all alterants of `:setMode`-type
    ##      `:accumulate` up to BUT NOT including "primary" slot.
    ##      I.e.: Not incl. the slot corresponding to `crntComponent`.
    # The working dict is rebuilt fresh on every call: the Apply phase keeps no cross-call
    # accumulation store and returns only the set-alterant index vector plus its count.
    st.working = Dict{Int8,Any}()
    st.working_origin = Dict{Int8,Vector{Vector{UInt8}}}()   # stage 2's commit 2 (R-V04B-35 (d)): rebuilt with `working`
    local crntSlot::Int8
    local crntAltIdx::Int8
    local crntAltActionIdx::Int8
    idxOfSlot = length(checkTheseSlotsInOrderVec)
    while idxOfSlot > 1
        crntSlot = checkTheseSlotsInOrderVec[idxOfSlot]
        for row ∈ 1:st.mh.count_actions_per_slot[crntSlot]
            # Two scalar reads rather than a `queued[1:2, row, crntSlot]` slice: the slice would
            # heap-allocate a fresh 2-element `Vector{Int8}` (64 B) on every hot-loop iteration;
            # the scalar reads allocate nothing (`queued::Array{Int8,3}`).
            crntAltIdx       = st.queue.queued[1, row, crntSlot]
            crntAltActionIdx = st.queue.queued[2, row, crntSlot]
            if insorted(crntAltIdx, st.registry.accum_alt_idxs)

                local _cond = st.queue.conditions[row, crntSlot]
                local _condOutcome = _cond === nothing ? nothing : evaluate(st, _cond)   # v0.2 FLIP: the closed interpreter (the eval seam is retired)
                if _cond === nothing || _condOutcome
                    if crntAltIdx ∉ keys(st.working)
                        st.working[crntAltIdx] =
                            _mint_instance(st.registry.plugins[crntAltIdx])   # T3: the wrapped mint
                    end
                    _record_origin!(st, crntAltIdx, row, crntSlot)   # R-V04B-35 (d)
                    if st.queue.args[row, crntSlot] === nothing
                        _invoke_set(st.registry,
                            st.registry.plugins[crntAltIdx].setAltInstance,
                            st.working[crntAltIdx],
                            st.registry.sorted_alt_actions[crntAltActionIdx], ())
                    else
                        _invoke_set(st.registry,
                            st.registry.plugins[crntAltIdx].setAltInstance,
                            st.working[crntAltIdx],
                            st.registry.sorted_alt_actions[crntAltActionIdx],
                            st.queue.args[row, crntSlot])
                    end
                end
            end
        end
        idxOfSlot -= 1
    end
    ## FINISHED: "1.: Compute / Determine the values of all alterants of `:setMode`-type"
    ##                  "`:accumulate` up to BUT NOT including "primary" slot."
    ## 2.: Compute / Determine the values of `altActions` in the order in which
    ##      they appear in the queue (`st.queue.queued`) in "primary" slot.
    previousSetAltIdxVec = Vector{Int8}(undef, num_alterants(st.registry))
    countPreviousSetAlts::Int = 0
    local countInCrntSlotSetAlts::Int
    idxOfSlot = 0
    for crntSlot ∈ checkTheseSlotsInOrderVec
        countInCrntSlotSetAlts = 0
        idxOfSlot += 1
        if idxOfSlot == 2
            ## Before starting on next slot:
            ##      Mark all `:accumulate` alterants as completed,
            ##      BECAUSE above in `detAltValuesForSetOfSlots()` in step 1,
            ##      we computed / determined all `:accumulate` alterants
            ##      UP To the "primary" slot [the 1st on of `checkTheseSlotsInOrderVec`].
            for idxOfAccumAlt ∈ st.registry.accum_alt_idxs
                if idxOfAccumAlt ∉ view(previousSetAltIdxVec, 1:countPreviousSetAlts)
                    countPreviousSetAlts += 1
                    previousSetAltIdxVec[countPreviousSetAlts] = idxOfAccumAlt
                end
            end
        end
        for idx ∈ 1:st.mh.count_actions_per_slot[crntSlot]
            # slice→scalars (the primary-slot loop) — same as the accumulate loop above: two scalar
            #   reads instead of a per-iteration slice allocation.
            crntAltIdx       = st.queue.queued[1, idx, crntSlot]
            crntAltActionIdx = st.queue.queued[2, idx, crntSlot]

            if crntAltIdx ∉ view(
                previousSetAltIdxVec, 1:countPreviousSetAlts)

                if insorted(crntAltIdx, st.registry.mutex_alt_idxs) &&
                   crntAltIdx ∈ view(previousSetAltIdxVec,
                       (countPreviousSetAlts+1):(
                           countPreviousSetAlts+countInCrntSlotSetAlts))
                    ## A `:mutExclusive` alterant already SATISFIED within this slot: the first
                    ## APPLICABLE value won (first-applicable-in-source-order) — skip this row
                    ## WITHOUT evaluating its condition, mirroring the prior-slot guard above.
                    continue
                end
                local _cond = st.queue.conditions[idx, crntSlot]
                local _condOutcome = _cond === nothing ? nothing : evaluate(st, _cond)   # v0.2 FLIP: the closed interpreter (the eval seam is retired)
                if _cond === nothing || _condOutcome


                    if crntAltIdx ∉ view(previousSetAltIdxVec,
                        (countPreviousSetAlts+1):(
                            countPreviousSetAlts+countInCrntSlotSetAlts))
                        ## i.e.: current Alterant is:
                        ##      - NOT of :setMode `:accumulate`
                        ##  AND - NOT yet marked as completet
                        ## Do:
                        countInCrntSlotSetAlts += 1
                        previousSetAltIdxVec[countPreviousSetAlts+countInCrntSlotSetAlts] =
                            crntAltIdx
                    end

                    if crntAltIdx ∉ keys(st.working)
                        st.working[crntAltIdx] =
                            _mint_instance(st.registry.plugins[crntAltIdx])   # T3: the wrapped mint
                    end
                    _record_origin!(st, crntAltIdx, idx, crntSlot)   # R-V04B-35 (d)
                    if st.queue.args[idx, crntSlot] === nothing
                        _invoke_set(st.registry,
                            st.registry.plugins[crntAltIdx].setAltInstance,
                            st.working[crntAltIdx],
                            st.registry.sorted_alt_actions[crntAltActionIdx], ())
                    else
                        _invoke_set(st.registry,
                            st.registry.plugins[crntAltIdx].setAltInstance,
                            st.working[crntAltIdx],
                            st.registry.sorted_alt_actions[crntAltActionIdx],
                            st.queue.args[idx, crntSlot])
                    end
                end
            end
        end
        countPreviousSetAlts += countInCrntSlotSetAlts
    end
    return previousSetAltIdxVec, countPreviousSetAlts
end

#########################################################################################
#########################################################################################
## applyAltActionFns(::Segment)
function applyAltActionFns(
    aSegment::BLS.Segment
)

    # The Segment overload hoists the per-call `ProcessState` and snapshots the settribute of the
    # enclosing component through `snapshot_settribute!(st, …)`; the slot tensors
    # (`st.mh.slots`/`st.mh.slot_occupied`) and the depth cursor (`st.crnt_depth_idx`) read off
    # that state, and the structural meta-hierarchy index constants
    # (`NUM_MH_LEVELS`/`userMHIdx`/`lineMHIdx`) live in state.jl.
    local st = ctx()
    snapshot_settribute!(st, BLS.getParentComponent(st.parse, aSegment))
    attachedToMeta::Bool = BLS.getElement(
        BLS.getParentComponent(st.parse, BLS.getParentComponent(st.parse, aSegment)).componentSettribute,
        :attachedToMeta
    )
    local crntSlot::Int8
    checkTheseSlotsInOrderVec = Vector{Int8}(undef, NUM_MH_LEVELS)
    countEligibleSlots::Int = 0
    ## 1.: Check "applicability":
    ##  - firstly at level: `userMHIdx`
    ##  - secondly at level: `lineMHIdx`
    for mhIdx ∈ (userMHIdx, lineMHIdx)
        crntSlot = st.mh.slots[mhIdx]
        if 0 != crntSlot && st.mh.slot_occupied[crntSlot] ## i.e.: contains Action.
            countEligibleSlots += 1
            checkTheseSlotsInOrderVec[countEligibleSlots] = crntSlot
        end
    end
    ## 2.: Check "applicability" down the depth window (`crnt_depth_idx` → `fileMHIdx`):
    if attachedToMeta
        mhIdx = st.crnt_depth_idx
        while 0 < mhIdx ## NOTE: fileMHIdx == 1 (state.jl) — the walk bottoms at fileMHIdx
            crntSlot = st.mh.slots[mhIdx]
            if 0 != crntSlot && st.mh.slot_occupied[crntSlot] ## i.e.: contains Action.
                countEligibleSlots += 1
                checkTheseSlotsInOrderVec[countEligibleSlots] = crntSlot
            end
            mhIdx -= 1
        end
    end
    ## 3.: the fallBack level LAST (stage 2's commit 3 — R-V04B-55 (3); his §196 (iv): "it only gets applied
    ##      if no altValue … has been set / evaluated for any of the preceeding meta level"); today never
    ##      occupied (the metaLevel Alterant and its feeds come after the branch — R-V04B-55 (4)).
    crntSlot = st.mh.slots[fallBackMHIdx]
    if 0 != crntSlot && st.mh.slot_occupied[crntSlot]
        countEligibleSlots += 1
        checkTheseSlotsInOrderVec[countEligibleSlots] = crntSlot
    end
    detAltValuesForSetOfSlots(view(checkTheseSlotsInOrderVec, 1:countEligibleSlots))
end

#########################################################################################
#########################################################################################
## applyAltActionFns(::Block)
function applyAltActionFns(
    thisBlock::BLS.Block
)
    # The Block overload hoists the per-call `ProcessState` the same way and snapshots the
    # settribute with `snapshot_settribute!(st, thisBlock)`; the slot tensors and the depth cursor
    # read `st.mh`/`st.crnt_depth_idx`, and the structural index constants live in state.jl.
    local st = ctx()
    snapshot_settribute!(st, thisBlock)
    local crntSlot::Int8

    checkTheseSlotsInOrderVec = Vector{Int8}(undef, NUM_MH_LEVELS)
    countEligibleSlots::Int = 0
    ## 1.: Check "applicability" at level: `userMHIdx`:
    crntSlot = st.mh.slots[userMHIdx]
    if 0 != crntSlot && st.mh.slot_occupied[crntSlot] ## i.e.: contains Action.
        countEligibleSlots += 1
        checkTheseSlotsInOrderVec[countEligibleSlots] = crntSlot
    end
    ## 2.: Check "applicability" down the depth window (`crnt_depth_idx` → `fileMHIdx`):
    mhIdx = st.crnt_depth_idx
    while 0 < mhIdx ## NOTE: fileMHIdx == 1 (state.jl) — the walk bottoms at fileMHIdx
        crntSlot = st.mh.slots[mhIdx]
        if 0 != crntSlot && st.mh.slot_occupied[crntSlot] ## i.e.: contains Action.
            countEligibleSlots += 1
            checkTheseSlotsInOrderVec[countEligibleSlots] = crntSlot
        end
        mhIdx -= 1
    end
    ## 3.: the fallBack level LAST (stage 2's commit 3 — R-V04B-55 (3); his §196 (iv): "it only gets applied
    ##      if no altValue … has been set / evaluated for any of the preceeding meta level"); today never
    ##      occupied (the metaLevel Alterant and its feeds come after the branch — R-V04B-55 (4)).
    crntSlot = st.mh.slots[fallBackMHIdx]
    if 0 != crntSlot && st.mh.slot_occupied[crntSlot]
        countEligibleSlots += 1
        checkTheseSlotsInOrderVec[countEligibleSlots] = crntSlot
    end
    detAltValuesForSetOfSlots(view(checkTheseSlotsInOrderVec, 1:countEligibleSlots))
end

# ── _invoke_set: the action-args refusal seam (record-armed) ────────────────────────────────────
# IS:   the SOLE invocation seam for every plugin set-function (the four
#       `detAltValuesForSetOfSlots` call sites above and the heading delivery at the absorb seam
#       route here; it is defined at the tail of the file because top-level functions are
#       late-bound).
# DOES: consults the DECLARED registration record BEFORE dispatch: the action must be registered
#       (`spec_index`), and some declared overload must accept the args — arity AND per-slot form,
#       checked as typed DATA (`_args_match`: signature types for typed slots; the declared kind
#       via the shared `_kind_type` map for untyped slots; the vararg tail by the same map; rows
#       whose actionName slot cannot carry a `Symbol` are unreachable from this seam and skipped).
#       Refusals are typed and name the failing class. THEN invokes `setAltInstance` (real Julia
#       dispatch — the matcher is a CHECK, never a dispatcher) and guards the RETURN against the
#       ARITY-compatible addressable rows' declared return types (for the shipped record, whose
#       rows differ in arity, that set is a singleton; the registration-time uniqueness law that
#       made it one for every record left at stage 5's E4 — a custom record with two same-arity
#       rows is guarded against the union of their declared types; an off-declaration return is
#       an INTERNAL defect, loud).
#       The catch is the value-level backstop: ArgumentError/OverflowError (arity+form
#       pass, the VALUE itself fails — pre-checks cannot see values) keep the stable
#       "GoMeta apply: invalid arguments" refusal, raised OUTSIDE the catch so the refusal is the
#       SOLE displayed exception (no `caused by:` raw-payload chain); a MethodError here means
#       declaration/reality drift and raises the internal-invariant error WITH its cause chain
#       (attribution wanted for defects). Anything else RETHROWS.
# REASONING: the bar is "no raw crash on any input; extreme input gets a typed, documented
#       refusal" at the argument surface. The guard sits at the SEAM, not inside the alterant
#       bodies — the declared data (the author's statement; the load-time cross-check left at
#       stage 5's E4) guards every live invocation. CALLER INVARIANT (documented, unenforced here): the store
#       passed as the alterant is built by the OWNING plugin's constructor; the matcher does not
#       check the alterant slot. The pass path is one Dict lookup + two small row loops of `isa`
#       checks (once to admit the args, once to bound the return), allocation-free; refusal text
#       builds only on refusal.
#       Condition-side atoms on the query side (the `#~ cell(7) :label1{ cell(7) }` class — the
#       raw crash arms only once an earlier Id action populated the slot) are a documented
#       edge (E-07, typed mint pending; docs/public-api.md §3.2/§3.4): the bare
#       unqueryable atom aborts raw at evaluation, not here.
# PURPOSE: a stranger's malformed argument gets an explanatory, catalogued refusal
#       (docs/public-api.md §3.4), never a bare stack trace — and a drifted build gets a loud
#       internal error, never a silently absorbed wrong shape.
"""
    _arity_match(ov::ActionOverload, args::Tuple) -> Bool

The ADDRESSABILITY + ARITY half of the match (no per-slot form checks): the row's actionName
slot carries `Symbol`, and the arg count fits (fixed == / vararg ≥). The RETURN guard uses
this wider predicate — dispatch selects by types, not by declared kinds, so the admissible
return set is the arity-compatible rows' (see the seam header).
"""
function _arity_match(ov::ActionOverload, args::Tuple)::Bool
    Symbol <: ov.sig_types[2] || return false
    n_user = _user_arity(ov)
    return ov.vararg_kind === nothing ? length(args) == n_user : length(args) >= n_user
end

"""
    _args_match(ov::ActionOverload, args::Tuple) -> Bool

Whether one declared overload row accepts the user-args tuple AT THE SET-INVOCATION SEAM
(where the actionName is always a `Symbol`): row addressable (its actionName slot carries
`Symbol`) · arity (fixed == / vararg ≥ the user arity) · per-slot form (typed slots by
signature type; untyped `Any` slots by the DECLARED kind where the kind vector covers them —
the kinds tail-align to the LAST `length(kinds)` user slots; uncovered `Any` slots accept
anything) · vararg tail by the shared kind map.
A CHECK, not a dispatcher — on pass, the real call still runs ordinary Julia dispatch.
"""
function _args_match(ov::ActionOverload, args::Tuple)::Bool
    _arity_match(ov, args) || return false
    n_user = _user_arity(ov)
    if ov.vararg_kind !== nothing
        vt = _kind_type(ov.vararg_kind)
        for j in (n_user + 1):length(args)
            args[j] isa vt || return false
        end
    end
    kind_off = n_user - length(ov.kinds)
    for i in 1:n_user
        t = ov.sig_types[2 + i]
        if t === Any
            ki = i - kind_off
            ki >= 1 && !(args[i] isa _kind_type(ov.kinds[ki])) && return false
        else
            args[i] isa t || return false
        end
    end
    return true
end

"""
    _mint_instance(plug) -> the alterant instance   (v0.4 T3 — T3-DESIGN §4)

THE ONE instance-mint wrap, used at all THREE bare-`altConstructor()` sites (the two
apply-loop mints + the absorb-seam localOnly heading mint): a THROW from a user ctor
(an absent zero-arg method — the bare call's `MethodError` — meets this wrap too since the
gate's eager dependency closure left at stage 5's E4)
converts to the typed refusal naming `CB_CTOR_THROW` with record attribution via
`altName`. `InterruptException` and the engine's own `"GoMeta "`-prefixed refusals
rethrow (the T3 pass-through law); the guarantee is scoped to exceptions delivered to
the handler.
"""
function _mint_instance(plug)
    try
        return plug.altConstructor()
    catch e
        e isa InterruptException && rethrow()
        (e isa ErrorException && startswith(e.msg, "GoMeta ")) && rethrow()
        error("GoMeta apply: alterant instance constructor threw (CB_CTOR_THROW): ",
            String(nameof(typeof(e))), " for alterant ", repr(plug.altName),
            " — the declared altConstructor must construct with zero arguments ",
            "(see docs/public-api.md §3.4)")
    end
end

function _invoke_set(registry::AlterantRegistry, setfn::Function, alterant,
                     actionName::Symbol, args::Tuple)
    si = get(registry.spec_index, actionName, 0)
    si == 0 && error("GoMeta apply: unregistered alterant action ",
        repr(first(String(actionName), 40)),
        " reached the set-invocation seam (the registered inventory has ",
        length(registry.action_specs), " actions) — the registration record is the law; ",
        "declare the action (see docs/public-api.md §3.4)")
    spec = registry.action_specs[si]
    matched = false
    local mov = nothing              # T3: the MATCHED overload, captured for the store check
    for ov in spec.overloads
        _args_match(ov, args) && (matched = true; mov = ov; break)
    end
    matched || error("GoMeta apply: invalid arguments for alterant action ",
        repr(first(String(actionName), 40)), " (no declared form accepts ",
        length(args), " argument(s) of the given shapes; the declared arities are ",
        sort!(unique(Int[_user_arity(ov) for ov in spec.overloads if Symbol <: ov.sig_types[2]])),
        any(ov.vararg_kind !== nothing && Symbol <: ov.sig_types[2]
            for ov in spec.overloads) ? " + a vararg tail" : "",
        ") — v0's documented argument forms: see docs/public-api.md §3.4")
    ## v0.4 T3 (T3-DESIGN §4; FM-RES-1) — the STORE-IDENTITY check at the post-dispatch
    ## point, PER INVOKE (the matched overload is known only here; a persisted instance is
    ## re-checked on every set-call — strictly stronger than a per-mint check, and it
    ## covers the absorb seam's `_invoke_set` call for free). The no-match refusal above
    ## fires FIRST (the ruled precedence). `sig_types[1]` gains its first reader; nothing
    ## constrains store-type consistency ACROSS one action's overloads — the check binds
    ## to the MATCHED overload, well-defined per invocation (disclosed).
    alterant isa mov.sig_types[1] || error("GoMeta apply: alterant store of type ",
        String(nameof(typeof(alterant))),
        " is FOREIGN to the declared overload's store type (RES_FOREIGN_STORE) on action ",
        repr(first(String(actionName), 40)), " (see docs/public-api.md §3.4)")
    failed_as = nothing
    ret = nothing
    try
        ret = setfn(alterant, actionName, args...)
    catch e
        if e isa Union{ArgumentError, OverflowError}
            failed_as = typeof(e).name.name
        elseif e isa MethodError
            error("GoMeta internal invariant violated: set dispatch failed AFTER the ",
                "declared-record pre-checks passed (declaration/reality drift on action ",
                repr(first(String(actionName), 40)), ") — please report this")
        else
            rethrow()
        end
    end
    failed_as === nothing || error("GoMeta apply: invalid arguments for alterant action ",
        repr(first(String(actionName), 40)), " (", failed_as,
        "; CB_SET_THROW; alterant ", repr(registry.plugins[spec.plugin].altName),
        ") — v0's documented argument forms: see docs/public-api.md §3.4")
    ret_ok = false
    for ov in spec.overloads
        (_arity_match(ov, args) && ret isa ov.return_type) && (ret_ok = true; break)
    end
    ret_ok || error("GoMeta internal invariant violated: alterant action ",
        repr(first(String(actionName), 40)), " returned ", typeof(ret),
        " — off its DECLARED return type (RES_RETURN_TYPE; the value-algebra guard at ",
        "the live seam) — please report this")
    return nothing
end
