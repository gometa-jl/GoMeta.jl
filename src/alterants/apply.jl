# apply.jl — the Apply phase: evaluates queued alterant conditions and runs the setters.
#
# IS: the Apply phase of the GoMeta engine. `detAltValuesForSetOfSlots` walks the eligible
#     meta-hierarchy slots and decides every queued alterant action in two passes — the
#     `:accumulate`-mode alterants over every slot except the Component's OWN one (the first eligible slot that is not the
#     user level's — since 0.4.1), then all queued actions slot by slot in the order
#     of EVALUATION [own, user, outer…] — building alterant instances into the per-call working dict
#     (`st.working` off `ctx()`, rebuilt fresh on every call) and returning the set-alterant
#     index vector with its count. `applyAltActionFns(::BLS.Segment)` and
#     `applyAltActionFns(::BLS.Block)` snapshot the settribute, gather the occupied eligible
#     slots for their grain (the Segment overload scans the `userMHIdx`/`lineMHIdx` levels
#     plus, when the enclosing Block is `:attachedToMeta`, the depth window; the Block overload
#     scans `userMHIdx` plus the depth window down to `fileMHIdx`; both append the `fallBack` level LAST), and delegate.
#     The setters are called directly (a record-armed invocation seam `_invoke_set` was removed within the 0.4 development).
#     A setter's RETURN is read for ONE purpose (since 0.4.3) — a `Vector{Diagnostic}` is delivered through `_deliver_diagnostics!`
#     with the place attached, the severity copied; anything else is ignored as before (not the removed seam: no wrapper, no catch; the
#     Engine reads a vector of diagnostics and never a label — the framework compartmentalized; the creator's design, possibly interim).
# DOES: evaluates each queued action's stored condition — `nothing` means set unconditionally,
#     otherwise the stored `Expr` (Julia's reading of the re-written `{…}` body, absorb_meta.jl) is evaluated by
#     Julia at apply time — `Core.eval(GoMeta, ex)`, as the original engine's `eval` (goMetaAddOns.jl :37, :95) — against the
#     per-call settribute snapshot and working stores reached by `getState`/`getAltState` through the ScopedValue
#     (since 0.4.0, the creator's design).
#     An alterant already set in an earlier-processed slot is never re-set — save the user level's OVERRIDE (since
#     0.4.1): under a fed profile an applicable non-accumulate row of the user level's slot, evaluated right after the
#     Component's own slot, replaces the value the own slot decided. The queued args tuple is
#     splatted once into the setter, bare, as the original engine called it (goMetaAddOns.jl); a malformed argument
#     meets Julia's own dispatch or the setter's own error — a former guarded refusal of the seam was removed within
#     the 0.4 development.
# REASONING: conditions travel as Julia `Expr`s and arguments as opaque tuples, so there
#     are two evaluation sites of one form (`Core.eval` in the two passes below) and direct setter calls
#     (an auditable setter seam and its internal-invariant guards were removed within the 0.4
#     development). Honest edges: the E-06 absorb-path guarded refusal keeps
#     its coded conversion deferred (the E-04 apply-path crash origin was removed with the Visib write-back)
#     (docs/public-api.md §3.1); a condition that fails at evaluation — a non-Bool value where a Bool is needed, an
#     argument Julia cannot dispatch — is Julia's own error out of the goMeta call (the E-07 row was retired with the
#     closed interpreter: a getter-less action is no condition key).
# PURPOSE: a runnable, observable Apply phase whose evaluation is Julia's (a former setter seam was removed within the
#     0.4 development).

## The provenance of an APPLIED action — the stating Component's handle
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

## THE DOOR (since 0.4.3): a setter's return value is read for ONE purpose — a `Vector{Diagnostic}` is delivered on the run's
## diagnostics, the Engine's PLACE merged into each row's context (the applying Component's key, the stating statement's handle, the
## Alterant's statements applied at this Component so far — a withhold's source among them); the severity copied, never decided here;
## anything else returned is ignored exactly as before. No wrapper, no catch, no type check beyond this one test: the Engine reads a vector
## of diagnostics and never a label (the creator's design — the framework compartmentalized; a possibly interim agreement, the Engine /
## Alterants interface to be revised later).
@noinline function _deliver_diagnostics!(st::ProcessState, ds::Vector{Diagnostic}, altIdx::Int8, row::Int, slot::Int8, appliedKey::Vector{UInt8})
    place = (cell = appliedKey, stated_by = st.queue.decided_by[row, slot], statements = copy(get(st.working_origin, altIdx, Vector{UInt8}[])))
    for d in ds
        ctx = d.context
        merged = ctx isa NamedTuple ? merge(ctx, place) : ctx === nothing ? place : merge((alterant_context = ctx,), place)
        push!(st.diagnostics, Diagnostic(d.code, d.severity, d.message, merged))
    end
    return nothing
end

"THE FRESH INSTANCE of an Alterant for the Component at hand: the registered constructor, given the Alterant's PER-RUN state where its read-time hook minted one (`st.alt_run`), the zero-argument call otherwise — every Alterant without a hook, and the Labels Alterant in a run without a vocabulary statement, meets the former call"
_freshInstance(st, idx) = (run = st.alt_run[idx]; run === nothing ? st.registry.plugins[idx].altConstructor() : st.registry.plugins[idx].altConstructor(run))

function detAltValuesForSetOfSlots(
    checkTheseSlotsInOrderVec::AbstractVector{Int8},
    appliedKey::Vector{UInt8}   # the applying Component's own key — the referent of the localOnly rule
)
    # ── THE EVALUATION MECHANICS (the algorithm this function implements) ─────────────────────────
    # For ONE entity, resolve every alterant's value from the meta-hierarchy lineage. The slots to
    # consult arrive DEEPEST-PRIORITY-FIRST in `checkTheseSlotsInOrderVec`; each slot's column in the
    # queue matrices holds its enqueued (alterant, action) rows in SOURCE order, with the parallel
    # `conditions`/`args` matrices holding each row's condition expression and argument tuple.
    # A row is APPLICABLE when its condition evaluates true (no condition = implicit true).
    #   THE COMPONENT'S OWN SLOT = the first eligible slot that is NOT the user level's: position 1 without a fed profile,
    #   position 2 with one (the overloads place the user level's slot first when it is occupied — its PRIORITY). Before
    #   0.4.1 the loop called the FIRST slot the Component's own, which
    #   under a feed was the user level's — a Component's own labels then went into pass 1 before its own conditions ran.
    #   Pass 1 (below): `:accumulate` alterants collect through every slot BUT the own one — the user level's slot FIRST
    #   when fed (the outermost level), then the outer slots from the vector's end inward.
    #   Pass 2 (step 2): the slot walk in the order of EVALUATION [own, user, outer…] — ALL own-slot alterants in WRITTEN
    #   order (incl. its accumulate rows, which apply there) + the other slots' non-accumulate alterants; the user level's
    #   NON-accumulate rows are evaluated AFTER the own slot (a fed non-accumulate condition sees the Component's own labels —
    #   measured; a fed CONDITIONAL label does not: collected in pass 1, before the file's labels — measured;
    #   the sight is `getAltState` over `st.working`, so a custom queryable non-accumulate Alterant's own value is seen too, the
    #   row's own target's included, the override's reset below coming after the condition — the code's reading, unmeasured: no
    #   shipped Alterant but Labels answers a query) and with PRIORITY: an
    #   applicable non-accumulate row of the user level OVERRIDES the value the own slot decided (a fresh instance, the
    #   origin list replaced — the one place where a later-evaluated slot replaces an earlier one).
    #   TWO first-wins guards give one law — THE FIRST APPLICABLE VALUE WINS (the user level's override its one exception):
    #     across slots, an alterant set in a prior (higher-priority) slot is skipped entirely;
    #     within a slot, a `:mutExclusive` alterant already satisfied by an earlier applicable row
    #     skips the remaining rows of that alterant WITHOUT evaluating their conditions.
    #   `:mutExclusivePerField` alterants (the `id` compound — fields fill independently) take
    #   neither the accumulate pass nor the within-slot stop; see the registry's set derivations.
    #   `:localOnly` alterants (the Heading — the creator's set mode) take ONE RULE inside pass 2
    #   (the creator's decision): a row of this mode applies ONLY at the Component the statement is applied to —
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
    # the ScopedValue `STATE` (the original engine's goMetaAddOns.jl :37). MEASURED:
    # 65–155 µs per evaluation on the corpus shapes — the original engine's known cost; the lowered form would be a hundredfold
    # cheaper; the choice stays open.
    local st = ctx()
    ## 1.1 Compute / Determine the values of all alterants of `:setMode`-type
    ##      `:accumulate` in every slot BUT the Component's OWN slot (`ownPos` below) —
    ##      the user level's slot first when fed, then the outer slots from the vector's end.
    # The working dict is rebuilt fresh on every call: the Apply phase keeps no cross-call
    # accumulation store and returns only the set-alterant index vector plus its count.
    st.working = Dict{Int8,Any}()
    st.working_origin = Dict{Int8,Vector{Vector{UInt8}}}()   # the provenance store, rebuilt with `working`
    local crntSlot::Int8
    local crntAltIdx::Int8
    local crntAltActionIdx::Int8
    ## S1: THE OWN SLOT by what it is — the first eligible slot that is not the user level's. The
    ## user level's slot index is 0 without a feed (`init_state` zeroes `slots`; `updateMetaHierarchy(userMHIdx)` is called by
    ## `feed_user_mh!` alone, for a non-blank profile); detected by SLOT INDEX, never by a handle's grain. A vector holding the
    ## user level's slot alone (length 1) runs the un-fed path: that slot is then the only one and its rows apply in written order.
    userSlot = st.mh.slots[userMHIdx]
    uFirst   = userSlot != 0 && length(checkTheseSlotsInOrderVec) >= 2 && checkTheseSlotsInOrderVec[1] == userSlot
    ownPos   = uFirst ? 2 : 1
    ## S2: pass 1 visits the user level's slot FIRST when fed (position 1 — the outermost level), then the outer slots from the
    ## vector's end down to the slot after the own one; the own slot is never visited here (its rows apply in WRITTEN order in
    ## pass 2). Without a feed the sequence is the former one exactly: from the end down to position 2.
    for posOfSlot ∈ Iterators.flatten((1:(uFirst ? 1 : 0), length(checkTheseSlotsInOrderVec):-1:(ownPos + 1)))
        crntSlot = checkTheseSlotsInOrderVec[posOfSlot]
        for row ∈ 1:st.mh.count_actions_per_slot[crntSlot]
            # Two scalar reads rather than a `queued[1:2, row, crntSlot]` slice: the slice would
            # heap-allocate a fresh 2-element `Vector{Int8}` (64 B) on every hot-loop iteration;
            # the scalar reads allocate nothing (`queued::Array{Int8,3}`).
            crntAltIdx       = st.queue.queued[1, row, crntSlot]
            crntAltActionIdx = st.queue.queued[2, row, crntSlot]
            if insorted(crntAltIdx, st.registry.accum_alt_idxs)

                local _cond = st.queue.conditions[row, crntSlot]
                local _condOutcome = _cond === nothing ? nothing : Core.eval(GoMeta, _cond)   # Julia evaluates the stored Expr (as the original engine's :37/:95 did)
                if _cond === nothing || _condOutcome
                    if crntAltIdx ∉ keys(st.working)
                        st.working[crntAltIdx] = _freshInstance(st, crntAltIdx)   # the run state handed to the constructor where a hook minted one
                    end
                    _record_origin!(st, crntAltIdx, row, crntSlot)   # the provenance
                    _ret = if st.queue.args[row, crntSlot] === nothing
                        st.registry.plugins[crntAltIdx].setAltInstance(st.working[crntAltIdx],
                            st.registry.sorted_alt_actions[crntAltActionIdx])
                    else
                        st.registry.plugins[crntAltIdx].setAltInstance(st.working[crntAltIdx],
                            st.registry.sorted_alt_actions[crntAltActionIdx],
                            st.queue.args[row, crntSlot]...)
                    end
                    _ret isa Vector{Diagnostic} && _deliver_diagnostics!(st, _ret, crntAltIdx, row, crntSlot, appliedKey)   # the door: a setter's diagnostics delivered with the place
                end
            end
        end
    end
    ## FINISHED: "1.: Compute / Determine the values of all alterants of `:setMode`-type"
    ##                  "`:accumulate` in every slot BUT the Component's own."
    ## 2.: Compute / Determine the values of `altActions` in the order in which
    ##      they appear in the queue (`st.queue.queued`) in the Component's OWN slot — in WRITTEN order — then in the
    ##      user level's slot (when fed: with full sight of the own labels, and with the override), then in the outer slots.
    ## S5: an Alterant the user level overrides stands TWICE in this vector (the own slot's range and the user level's) — hence 2×.
    previousSetAltIdxVec = Vector{Int8}(undef, 2 * num_alterants(st.registry))
    countPreviousSetAlts::Int = 0
    local countInCrntSlotSetAlts::Int
    idxOfSlot = 0
    ## S3: ONE loop over the permuted order of EVALUATION [own, user, outer…] — with a feed positions 1 and 2 swap (the own slot
    ## is evaluated first, the user level's slot second); without one the order is the vector's own.
    for k ∈ eachindex(checkTheseSlotsInOrderVec)
        crntSlot = checkTheseSlotsInOrderVec[uFirst ? (k == 1 ? 2 : (k == 2 ? 1 : k)) : k]
        countInCrntSlotSetAlts = 0
        idxOfSlot += 1
        if idxOfSlot == 2
            ## Before starting on the next slot (the second one EVALUATED — right after the Component's own slot):
            ##      Mark all `:accumulate` alterants as completed,
            ##      BECAUSE above in `detAltValuesForSetOfSlots()` in step 1,
            ##      we computed / determined all `:accumulate` alterants
            ##      of every slot BUT the own one — and the own slot's have just applied, in written order.
            for idxOfAccumAlt ∈ st.registry.accum_alt_idxs
                if idxOfAccumAlt ∉ view(previousSetAltIdxVec, 1:countPreviousSetAlts)
                    countPreviousSetAlts += 1
                    previousSetAltIdxVec[countPreviousSetAlts] = idxOfAccumAlt
                end
            end
        end
        for idx ∈ 1:st.mh.count_actions_per_slot[crntSlot]
            # slice→scalars (the pass-2 slot loop) — same as the accumulate loop above: two scalar
            #   reads instead of a per-iteration slice allocation.
            crntAltIdx       = st.queue.queued[1, idx, crntSlot]
            crntAltActionIdx = st.queue.queued[2, idx, crntSlot]
            ## S4: THE USER LEVEL'S OVERRIDE — a non-accumulate row of the user level's slot (evaluated after the own slot) may
            ## replace the value the own slot decided (the creator's exception to the closer-wins rule: the user level
            ## over-rules). The accumulate Alterants are EXCLUDED (their user-level rows applied in pass 1 — never twice); a
            ## `localOnly` row never arrives from a feed (refused at the read).
            overridable = uFirst && crntSlot == userSlot && !insorted(crntAltIdx, st.registry.accum_alt_idxs)

            if crntAltIdx ∉ view(
                previousSetAltIdxVec, 1:countPreviousSetAlts) || overridable

                if insorted(crntAltIdx, st.registry.mutex_alt_idxs) &&
                   crntAltIdx ∈ view(previousSetAltIdxVec,
                       (countPreviousSetAlts+1):(
                           countPreviousSetAlts+countInCrntSlotSetAlts))
                    ## A `:mutExclusive` alterant already SATISFIED within this slot: the first
                    ## APPLICABLE value won (first-applicable-in-source-order) — skip this row
                    ## WITHOUT evaluating its condition, mirroring the prior-slot guard above.
                    continue
                end
                ## THE ONE RULE of the set mode `localOnly` (the creator's decision): a row of
                ## this mode applies ONLY at the Component the statement is applied to — the metaBlock for a metaLine's statement, the
                ## Line for a Code Line's trailing metaSegment — and every other Component that meets it
                ## on a shared level passes over it: the condition unevaluated, nothing marked set, nothing blocked (the creator's words: "applied
                ## to the first Block only, that is it"). A fed heading never reaches here (the feed refuses it at the read).
                if st.registry.plugins[crntAltIdx].setMode === :localOnly &&
                   st.queue.applied_to[idx, crntSlot] != appliedKey
                    continue
                end
                local _cond = st.queue.conditions[idx, crntSlot]
                local _condOutcome = _cond === nothing ? nothing : Core.eval(GoMeta, _cond)   # Julia evaluates the stored Expr (as the original engine's :37/:95 did)
                if _cond === nothing || _condOutcome


                    ## S4 (the override itself): on the user level's FIRST applicable row of an Alterant the own slot already set —
                    ## a fresh instance (the Visib setter only sets a flag and never clears one; two set flags meet the capture's
                    ## refusal) and the origin list EMPTIED before this row's own push, so `decided_by == [the user context]`; a
                    ## later user-level row of the same Alterant finds it in the user level's in-slot range and never rebuilds it
                    ## (a `:mutExclusive` one is stopped above; the Id compound's fields fill the same fresh instance).
                    if overridable && crntAltIdx ∈ view(previousSetAltIdxVec, 1:countPreviousSetAlts) &&
                       crntAltIdx ∉ view(previousSetAltIdxVec, (countPreviousSetAlts+1):(countPreviousSetAlts+countInCrntSlotSetAlts))
                        st.working[crntAltIdx] = _freshInstance(st, crntAltIdx)   # the run state handed to the constructor where a hook minted one
                        empty!(st.working_origin[crntAltIdx])
                    end
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
                        st.working[crntAltIdx] = _freshInstance(st, crntAltIdx)   # the run state handed to the constructor where a hook minted one
                    end
                    _record_origin!(st, crntAltIdx, idx, crntSlot)   # the provenance
                    _ret = if st.queue.args[idx, crntSlot] === nothing
                        st.registry.plugins[crntAltIdx].setAltInstance(st.working[crntAltIdx],
                            st.registry.sorted_alt_actions[crntAltActionIdx])
                    else
                        st.registry.plugins[crntAltIdx].setAltInstance(st.working[crntAltIdx],
                            st.registry.sorted_alt_actions[crntAltActionIdx],
                            st.queue.args[idx, crntSlot]...)
                    end
                    _ret isa Vector{Diagnostic} && _deliver_diagnostics!(st, _ret, crntAltIdx, idx, crntSlot, appliedKey)   # the door: a setter's diagnostics delivered with the place
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
    ## the applying Component's own key: the LINE with this Segment as the key's origin — as
    ## `captureEvals!` keys this grain's rows — the referent of the localOnly rule
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
    ## 3.: the fallBack level LAST (the creator's words: "it only gets applied
    ##      if no altValue … has been set / evaluated for any of the preceeding meta level"); today never
    ##      occupied (the metaLevel Alterant and its feeds are a later version's).
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
    ## the applying Component's own key — as `captureEvals!` keys this grain's rows
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
    ## 3.: the fallBack level LAST (the creator's words: "it only gets applied
    ##      if no altValue … has been set / evaluated for any of the preceeding meta level"); today never
    ##      occupied (the metaLevel Alterant and its feeds are a later version's).
    crntSlot = st.mh.slots[fallBackMHIdx]
    if 0 != crntSlot && st.mh.slot_occupied[crntSlot]
        countEligibleSlots += 1
        checkTheseSlotsInOrderVec[countEligibleSlots] = crntSlot
    end
    detAltValuesForSetOfSlots(view(checkTheseSlotsInOrderVec, 1:countEligibleSlots), appliedKey)
end
