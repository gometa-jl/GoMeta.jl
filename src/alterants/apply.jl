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
#     The setters are called directly (the record-armed invocation seam `_invoke_set` left at stage 5's E6 of the v0.4 build — census row 14).
# DOES: evaluates each queued action's stored condition — `nothing` means set unconditionally,
#     otherwise the stored `Expr` (Julia's reading of the re-written `{…}` body, absorb_meta.jl) is evaluated by
#     Julia at apply time — `Core.eval(GoMeta, ex)`, as his legacy's `eval` (goMetaAddOns.jl :37, :95) — against the
#     per-call settribute snapshot and working stores reached by `getState`/`getAltState` through the ScopedValue
#     (stage 5's E13 of the v0.4 build, census row 1; R-V04B-106; his §120, §D174).
#     An alterant already set in an earlier-processed slot is never re-set. The queued args tuple is
#     splatted once into the setter, bare, as his legacy called it (goMetaAddOns.jl); a malformed argument
#     meets Julia's own dispatch or the setter's own error — the seam's guarded refusal left at stage 5's E6 of
#     the v0.4 build (census row 14; his §120, the framework before hardening).
# REASONING: conditions travel as Julia `Expr`s and arguments as opaque tuples, so there
#     are two evaluation sites of one form (`Core.eval` in the two passes below) and direct setter calls
#     (the auditable setter seam and its internal-invariant guards left at stage 5's E6 of the v0.4 build —
#     census row 14). Honest edges: the E-06 absorb-path guarded refusal keeps
#     its coded conversion deferred (the E-04 apply-path crash origin left with the Visib write-back, stage 3's commit 4)
#     (docs/public-api.md §3.1); a condition that fails at evaluation — a non-Bool value where a Bool is needed, an
#     argument Julia cannot dispatch — is Julia's own error out of the goMeta call (the E-07 row retired at E13 with the
#     interpreter: a getter-less action is no condition key since E12).
# PURPOSE: a runnable, observable Apply phase whose evaluation is Julia's (the setter seam left at stage 5's E6 of the
#     v0.4 build — census row 14).

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
    checkTheseSlotsInOrderVec::AbstractVector{Int8},
    appliedKey::Vector{UInt8}   # the applying Component's own key (stage 1 of the Alterants build) — the referent of the localOnly rule
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
    #   `:localOnly` alterants (the Heading — his set mode of 2026-08-02) take ONE RULE inside pass 2 (stage 1 of the Alterants
    #   build; his §D241 point 2, R-V04B-101 (1)): a row of this mode applies ONLY at the Component the statement is applied to —
    #   `applied_to[row, slot]` equals `appliedKey`, the applying Component's own key — and every other Component that meets it
    #   on a shared level PASSES OVER it: its condition unevaluated, nothing marked set, nothing blocked. In NEITHER index set,
    #   so pass 1 never collects it and the within-slot mutex stop never applies; two heads in one slot both apply (the capture's
    #   attr-fold keeps them distinct).
    # The winner lands in `st.working` (one instance per alterant); the capture reads from there.
    # ──────────────────────────────────────────────────────────────────────────────────────────────
    # The per-call `ProcessState` is hoisted once: the working alterant-instance dict
    # (`st.working`), the registry inventory + action table + accumulate-set (`st.registry.*`),
    # the slot tensors (`st.mh.count_actions_per_slot`) and the queue
    # (`st.queue.queued`/`.conditions`/`.args`) all read off `ctx()`, so one call's Apply state is
    # never visible to another. The evaluation sites below — `Core.eval(GoMeta, _cond)` — are Julia's: the stored
    # `Expr` runs in module GoMeta, where `getState`/`getAltState` are bound by name and read this call's state through
    # the ScopedValue `STATE` (stage 5's E13; his legacy's goMetaAddOns.jl :37). MEASURED at the build (register E13-9):
    # 65–155 µs per evaluation on the corpus shapes — the legacy's known cost; the lowered form would be a hundredfold
    # cheaper, his to choose.
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
                local _condOutcome = _cond === nothing ? nothing : Core.eval(GoMeta, _cond)   # Julia evaluates the stored Expr (stage 5's E13; the legacy's :37/:95)
                if _cond === nothing || _condOutcome
                    if crntAltIdx ∉ keys(st.working)
                        st.working[crntAltIdx] = st.registry.plugins[crntAltIdx].altConstructor()
                    end
                    _record_origin!(st, crntAltIdx, row, crntSlot)   # R-V04B-35 (d)
                    if st.queue.args[row, crntSlot] === nothing
                        st.registry.plugins[crntAltIdx].setAltInstance(st.working[crntAltIdx],
                            st.registry.sorted_alt_actions[crntAltActionIdx])
                    else
                        st.registry.plugins[crntAltIdx].setAltInstance(st.working[crntAltIdx],
                            st.registry.sorted_alt_actions[crntAltActionIdx],
                            st.queue.args[row, crntSlot]...)
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
                ## THE ONE RULE of the set mode `localOnly` (his §D241 point 2; R-V04B-101 (1); stage 1 of the Alterants build): a row of
                ## this mode applies ONLY at the Component the statement is applied to — the metaBlock for a metaLine's statement, the
                ## Line for a Code Line's trailing metaSegment (his §286 (i)/(ii); R-V04B-98) — and every other Component that meets it
                ## on a shared level passes over it: the condition unevaluated, nothing marked set, nothing blocked (his §12: "applied
                ## to the first Block only, that is it"). A fed heading never reaches here (the feed refuses it at the read, §D242).
                if st.registry.plugins[crntAltIdx].setMode === :localOnly &&
                   st.queue.applied_to[idx, crntSlot] != appliedKey
                    continue
                end
                local _cond = st.queue.conditions[idx, crntSlot]
                local _condOutcome = _cond === nothing ? nothing : Core.eval(GoMeta, _cond)   # Julia evaluates the stored Expr (stage 5's E13; the legacy's :37/:95)
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
                        st.working[crntAltIdx] = st.registry.plugins[crntAltIdx].altConstructor()
                    end
                    _record_origin!(st, crntAltIdx, idx, crntSlot)   # R-V04B-35 (d)
                    if st.queue.args[idx, crntSlot] === nothing
                        st.registry.plugins[crntAltIdx].setAltInstance(st.working[crntAltIdx],
                            st.registry.sorted_alt_actions[crntAltActionIdx])
                    else
                        st.registry.plugins[crntAltIdx].setAltInstance(st.working[crntAltIdx],
                            st.registry.sorted_alt_actions[crntAltActionIdx],
                            st.queue.args[idx, crntSlot]...)
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
    ## the applying Component's own key (stage 1 of the Alterants build): the LINE with this Segment as the key's origin — as
    ## `captureEvals!` keys this grain's rows (R-V04B-98) — the referent of the localOnly rule
    local appliedKey::Vector{UInt8} = key_bytes(occurrence_key(st.parse, BLS.getParentComponent(st.parse, aSegment);
        origin = aSegment, namespace = st.config.namespace))
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
    detAltValuesForSetOfSlots(view(checkTheseSlotsInOrderVec, 1:countEligibleSlots), appliedKey)
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
    ## the applying Component's own key (stage 1 of the Alterants build) — as `captureEvals!` keys this grain's rows
    local appliedKey::Vector{UInt8} = key_bytes(occurrence_key(st.parse, thisBlock; namespace = st.config.namespace))
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
    detAltValuesForSetOfSlots(view(checkTheseSlotsInOrderVec, 1:countEligibleSlots), appliedKey)
end
