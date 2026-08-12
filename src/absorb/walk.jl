# walk.jl — the Absorb-phase walk: reads metaLines into the meta-hierarchy, enqueues alterant actions, embeds the Segment-grain apply.
#
# IS: the Block- and Line-grain recursion of the Absorb phase plus the embedded Segment-grain apply.
#     `absorbWalk(::BLS.ParseState, ::BLS.Block, metaEnvInt)::Int` / `absorbWalk(::BLS.ParseState, ::BLS.Line,
#     metaEnvInt)::Int` descend the Block→Line→Segment tree (the File-grain loop over Blocks lives in
#     GoMeta.jl's `goMeta`); `applyAbsorbFn` reads one component's metaLine and hands its body to
#     `absorbMeta` (absorb_meta.jl), which enqueues alterant actions/conditions into per-call slot state.
# DOES: the walk descends only into children that carry meta (`:containsMeta` at the Block grain,
#     `:hasMetaStr` at the Line grain) and are neither `:depricated` (sic) nor `:ignoreThisMeta`; a
#     negative child id selects the `[2]` insert store — dormant at v0, which never populates it
#     (a documented latent path — docs/public-api.md §3.4). `applyAbsorbFn` snapshots the component's settribute
#     (`snapshot_settribute!`), pulls the line text from the parse store (`collectedLines`, or
#     `addedStrings` for a negative string index), matches the `#~` header (one to eight tildes plus an
#     optional definition token), and calls `absorbMeta` on the text after the header (an empty
#     SubString when nothing follows); the dispatch tuples resolve every path to `absorbMeta`.
#     `metaEnvInt` tracks the grain owning the open meta environment: a Block or Line updates the
#     meta-hierarchy only when its grain outranks that environment (`>`); a Segment also updates on a
#     tie (`>=`), so consecutive inline metaLines each re-trigger the reset. Slots follow depth +
#     attachment semantics (docs/SYNTAX-AND-SEMANTICS.md §2, §4): the Block grain updates by component
#     depth, the Line and Segment grains via the shared `lineMHIdx` slot (state.jl). When `metaEnvInt`
#     sits at Segment level, `applyAltActionFns` (apply.jl) runs immediately; a resolved Visib verdict
#     writes back to the ENCLOSING Line's settribute (inline meta applies to its line —
#     docs/SYNTAX-AND-SEMANTICS.md §9), and `capture_verdicts!` (annotations.jl) records that Line as
#     the cell.
# REASONING: this file holds no eval — conditions enqueued here are evaluated later at the
#     documented condition seam (README SECURITY; docs/public-api.md §3.2). Malformed, unknown, and
#     over-capacity meta refuse inside `absorbMeta` (docs/public-api.md §3.4).
# PURPOSE: a deterministic walk that turns authored metaLines into enqueued alterant state, re-runnable
#     against the shipped corpus via run_examples.jl.

#########################################################################################
###~ The absorb-fn dispatch tuples (the only LIVE consumer is `applyAbsorbFn` below).
# Only the `:goMeta` path is live: `applyAbsorbFn`'s guard `metaDef === nothing || metaDef != Symbol(0)`
#   is ALWAYS true (a `SubString` is never `== Symbol(0)`), so dispatch always resolves
#   `absorbGoFnNamedTuple[metaDefNamedTuple[Symbol()]]` = `[:goMeta]` = `absorbMeta`.
metaDefNamedTuple = NamedTuple{(Symbol(), Symbol(0))}((:goMeta, :goMeta))
absorbGoFnNamedTuple = NamedTuple{(:goMeta,)}((absorbMeta,))
# The grain SYMBOL for the MetaContext record — TYPE-dispatched (the BLS grains are
# distinct parameterized types and `nameof` collapses them, so dispatch is the reliable
# discriminator — same pattern as occurrence.jl's `_grain_code`).
_meta_grain(::BLS.Segment) = :Segment
_meta_grain(::BLS.Line)    = :Line
_meta_grain(::BLS.Block)   = :Block

function applyAbsorbFn(
    parse_state::BLS.ParseState,
    crntComponent::BLS.AbstractComponent
)

    # Snapshot the component's settribute bytes into the per-call `st.snapshot`
    # (the `snapshot_settribute!` helper) — per-call state, no module globals.
    local st = ctx()
    snapshot_settribute!(st, crntComponent)
    # v0.2 CH-3 step 9 — publish the MetaContext record at the walk→absorb HANDOVER:
    # {grain, depth, application level, occurrence handle}, pure from parse, stored in NO
    # Component (hd-4). The MH cursor was set by the CALLER before this call (Block:
    # updateMetaHierarchy(getGivenDepthMH); Line and Segment: lineMHIdx — a
    # Segment-attached metaLine therefore inherits the metaLine's level, the hd-2
    # inheritance law, by construction), so `st.crnt_idx` IS the application level. The
    # userMH feed does NOT pass through here and NULLS the record instead — the heading
    # recognizer's context-less typed applicability refusal keys on that absence.
    # (delta-review trued: applyAbsorbFn has Line/Segment-grain call sites only, so
    # the Block arm below is DEFENSIVE — depth is 0 on every live path at v0.2; the
    # field is the context record's designed shape, populated when a Block-grain
    # handover site exists.)
    local _mc_key = occurrence_key(parse_state, crntComponent;
        namespace = st.config.namespace)
    local _mc_content = cell_content_bytes(parse_state, crntComponent)
    # DEGENERATE-KEY PARITY: the per-cell capture warns loudly on a
    # truncated-walk (degenerate) occurrence key; the metaLine's context-record key
    # gets the SAME diagnostic HERE — capture_heading! receives only the serialized
    # bytes and cannot run the check itself. Fires at every metaLine handover
    # (heading or not — the record keys whatever this metaLine delivers), and it can OVERLAP the capture site's own check when this
    # component later rides a capture as `origin` — both unreachable on real parses
    # (the capture site's note; zero TRUNCATED steps corpus-wide), both loud,
    # non-fatal; the overlap is recorded, not deduplicated. Content computed ONCE
    # for the payload + the meta_content publish below.
    if any(s -> s.store == 0x00, _mc_key.path) || any(s -> s.store == 0x00, _mc_key.origin)
        push!(st.diagnostics, Diagnostic(:WARN_DEGENERATE_OCCURRENCE_KEY, :warning,
            "meta_context: a truncated-walk (degenerate) occurrence key keys this " *
            "metaLine's context record (and any heading rows it delivers) — " *
            "per-occurrence identity is not guaranteed among degenerate keys.",
            copy(_mc_content)))
    end
    st.meta_context = MetaContext(
        _meta_grain(crntComponent),
        crntComponent isa BLS.Block ? Int(BLS.getGivenDepthMH(crntComponent)) : 0,
        st.crnt_idx,
        key_bytes(_mc_key))
    # localOnly delivery: publish the metaLine
    # component's verbatim content bytes BESIDE the record — the absorb-seam heading
    # delivery mints its row keyed (meta_context.handle, …, meta_content), the same
    # (handle, content) pair the apply-plane capture derives per governed cell. The
    # canonical extractor keeps the pair grain-consistent with every other row.
    st.meta_content = _mc_content

    stringIdx::Int = BLS.getElement(crntComponent.cmpntNamedInt, :idxString)
    local metaSS::SubString
    if stringIdx > 0
        metaSS = SubString(parse_state.collectedLines[stringIdx])
    else
        stringIdx *= -1
        metaSS = SubString(parse_state.addedStrings[stringIdx])
    end
    ## The lead-anchored introducer recognizer, selected by the document's flavor (the
    ## FlavorProfile record rides the ParseState — populated at setup, so the recognizer and the stored slice can never disagree about the lead;
    ## the stored Meta slice begins at the lead's first byte in BOTH flavors, and
    ## `offsets[end]` is slice-relative, so the body arithmetic below self-adjusts
    ## under the two-byte `//` lead). Both
    ## regexes are DERIVED from one body string in flavor.jl (closing the drift-copy hazard); the `::RegexMatch` typed assert stays: a mis-typed slice
    ## still fails LOUD. ## FUTURE-BLS(M6): one profile-owned grammar for parse AND walk.
    ## The bare `::RegexMatch` assert alone would throw a raw TypeError on a
    ## nomatch (unreachable today — the walk only sees parse-flagged components, which always match the tightened grammar); a typed internal-error message
    ## replaces it so an unreachable-become-reachable regression fails NAMED, not raw.
    _mf = match(
        parse_state.flavor.re_meta_leaded,
        metaSS[
            BLS.getElement(crntComponent.cmpntNamedInt, :startMainStr
        ):BLS.getElement(crntComponent.cmpntNamedInt, :stopMainStr)])
    _mf === nothing && error("GoMeta internal: a meta-flagged component's slice does ",
        "not match the leaded marker grammar — the parse/walk grammar coupling broke")
    matchFound::RegexMatch = _mf

    local crntAbsorbGoFn::Function
    ## For "Standard metaLine" OR "metaLine on file-level" (set above):
    if matchFound[:metaDef] === nothing || matchFound[:metaDef] != Symbol(0)
        crntAbsorbGoFn = absorbGoFnNamedTuple[metaDefNamedTuple[Symbol()]]
    else ## ELSE: get `crntGoFn` matching "special" `:medaDef`:
        crntAbsorbGoFn = absorbGoFnNamedTuple[
            metaDefNamedTuple[Symbol(matchFound[:metaDef])]]
    end
    if matchFound.offsets[end] != 0
        ## Whitespace-alphabet unification: the body starts at the char AFTER the postDef
        ## delimiter — char-safe via nextind, because postDef may be a MULTIBYTE
        ## horizontal space (NBSP, U+3000, …); byte+1 arithmetic landed on a
        ## continuation byte and threw StringIndexError (byte-identical for 1-byte
        ## postDef, so ASCII shapes are unchanged). The same char-safe arithmetic is the foundation a multibyte (emoji-class)
        ## head lead requires.
        crntAbsorbGoFn( ## e.g.: absorbMeta(...)
            metaSS[
                nextind(metaSS, BLS.getElement(
                crntComponent.cmpntNamedInt, :startMainStr)+matchFound.offsets[end]-1
            ):BLS.getElement(crntComponent.cmpntNamedInt,
                :stopMainStr)]
        )
    else
        crntAbsorbGoFn(SubString{String}(""))
    end
end


#########################################################################################
## ── the absorb-walk recursion ──

## ── Block grain ──
##      addapted for `BlockLineSegment`:
function absorbWalk(
    parse_state::BLS.ParseState,
    crntComponent::BLS.Block,
    metaEnvInt::Int
)::Int ## Returning updated value of `metaEnvInt`
    # Hoist `local st = ctx()` once per call: `st === ctx() === STATE[]` is stable for the whole call
    # (bound once by `goMeta`'s `with(STATE=>…)`), so `st.field` reads the same per-call state while
    # avoiding repeated ScopedValue lookups.
    local st = ctx()
    ## Block-Component-Specific:
    if BLS.getElement(crntComponent.componentSettribute, :isMeta)
        # The Block-grain meta-hierarchy update is guarded on `_mh_changed`.
        local _mh_changed = BLS.orderedComponentTypesNamedT[:Block] > metaEnvInt &&
                            BLS.getElement(crntComponent.componentSettribute, :isMeta)
        if _mh_changed
            CnS.updateMetaHierarchy(BLS.getGivenDepthMH(crntComponent))
            if st.crnt_idx > 1
                metaEnvInt = BLS.orderedComponentTypesNamedT[:Block]
            else
                metaEnvInt = BLS.orderedComponentTypesNamedT[:File]
            end
        end
    end

    ## For Components with Children:
    local childComponent::BLS.Line
    for childId in BLS.eachchildid(crntComponent, parse_state.componentsPDict[BLS.Block][1])
        if childId > 0
            childComponent = parse_state.componentsPDict[BLS.Line][1][childId]
        else
            childId *= -1
            childComponent = parse_state.componentsPDict[BLS.Line][2][childId]
        end
        if !BLS.getElement(childComponent.componentSettribute, :depricated) &&
           BLS.getElement(childComponent.componentSettribute, :containsMeta) &&
           !BLS.getElement(childComponent.componentSettribute, :ignoreThisMeta)
            metaEnvInt = absorbWalk(parse_state, childComponent::BLS.Line, metaEnvInt)
        end
    end
    return metaEnvInt
end

#########################################################################################

## ── Line grain ──
function absorbWalk(
    parse_state::BLS.ParseState,
    crntComponent::BLS.Line,
    metaEnvInt::Int
)::Int ## Returning updated value of `metaEnvInt`

    # Hoist `local st = ctx()` once per call — the per-child Visib write-back inside the
    # `for childId` loop below goes through the single hoisted `st`,
    # avoiding per-iteration ScopedValue lookups (`st === ctx()` is stable for the whole call).
    local st = ctx()
    ## Line-Component-Specific:
    if BLS.getElement(crntComponent.componentSettribute, :isMeta)
        # The Line-grain meta-hierarchy update is guarded on `_mh_changed`.
        local _mh_changed = BLS.orderedComponentTypesNamedT[:Line] > metaEnvInt &&
                            BLS.getElement(crntComponent.componentSettribute, :isMeta)
        if _mh_changed
            CnS.updateMetaHierarchy(lineMHIdx)
            metaEnvInt = BLS.orderedComponentTypesNamedT[:Line]
        end
    end

    if BLS.getElement(crntComponent.componentSettribute, :hasMetaStr)
        applyAbsorbFn(parse_state, crntComponent)
    end

    ## For Components with Children:
    local childComponent::BLS.Segment
    for childId in BLS.eachchildid(crntComponent, parse_state.componentsPDict[BLS.Line][1])
        if childId > 0
            childComponent = parse_state.componentsPDict[BLS.Segment][1][childId]
        else
            childId *= -1
            childComponent = parse_state.componentsPDict[BLS.Segment][2][childId]
        end
        if !BLS.getElement(childComponent.componentSettribute, :depricated) &&
           BLS.getElement(childComponent.componentSettribute, :hasMetaStr) &&
           !BLS.getElement(childComponent.componentSettribute, :ignoreThisMeta)

            if BLS.getElement(childComponent.componentSettribute, :isMeta)
                # The Segment-grain meta-hierarchy update is guarded on `_mh_changed`.
                ## The Segment comparison uses `>=`, NOT `>`: with consecutive inline-meta lines
                ## `metaEnvInt` carries as :Segment, so a strict `>` (`Segment > Segment`) is false — no
                ## `updateMetaHierarchy` reset — and the prior line's `working[:Visib]` would persist,
                ## letting a stale verdict win over a new one (e.g. an inline `#~ discard` rendered as
                ## hide). `>=` re-triggers the reset on every tie.
                ## (The Line-grain comparison above stays strict `>`.)
                local _mh_changed = BLS.orderedComponentTypesNamedT[:Segment] >= metaEnvInt &&
                                    BLS.getElement(childComponent.componentSettribute, :isMeta)
                if _mh_changed
                    CnS.updateMetaHierarchy(lineMHIdx) ## there is NO `segmentMHIdx`
                    metaEnvInt = BLS.orderedComponentTypesNamedT[:Segment]
                end
            end

            applyAbsorbFn(parse_state, childComponent)
            if metaEnvInt == BLS.orderedComponentTypesNamedT[:Segment]
                ## `applyAltActionFns(::Segment)` only at this point,
                ## IF `metaEnvInt` ("metaEnvironment") is on `:Segment`-level:
                applyAltActionFns(childComponent) ## `childComponent` is :Segment.
                # Segment-grain Visib write-back: a resolved Visib verdict maps through
                # `st.registry.alt_index[:Visib]` / `st.working` to a settribute key via the
                # per-call registry's `visib_to_settribute` table (identity at v0), written in the Pair form
                # `setElement(cs, key => true)` — `setElement(::BLS.ComponentSettribute, ::Symbol)` has
                # NO method (only `Vararg{Pair{Symbol, Bool}}`), so the Pair form is required at both
                # grains (the Block-grain sibling lives in GoMeta.jl).
                # Deferred: the E-04 flagless-Visib `keys(Visib)[array][1]` BoundsError and its typed
                # `ERR_VISIB_NO_FLAG` conversion (docs/public-api.md §3.1).
                ## A Segment-carried Visib verdict applies to the LINE containing the Segment (inline
                ## meta applies to its line — docs/SYNTAX-AND-SEMANTICS.md §9), NOT to the Segment
                ## itself: written to the Segment it would be unreachable by `checkVisib(line)` at
                ## emit, so inline `#~ hide`
                ## / `#~ show`(override) / `#~ discard` / bare-`#~` verdicts would not gate the render
                ## and the content segment would emit before the override. Hence the target is
                ## `crntComponent` (the Line, in scope here).
                ## The Visib-action → settribute-key map is read off the PER-CALL registry
                ## (`st.registry.visib_to_settribute`), not the module-global alias, so a custom
                ## `registry` kwarg's mapping is honored at the Segment grain too.
                if st.registry.alt_index[:Visib] ∈ keys(st.working)
                    BLS.setElement(
                        crntComponent.componentSettribute,
                        st.registry.visib_to_settribute[
                            keys(Alterants.Visib)[
                                st.working[
                                    st.registry.alt_index[:Visib]
                                    ].array][1]
                        ] => true
                    )
                end
                # Capture the Segment-grain FINAL verdicts before the next apply wipes `st.working`;
                # the cell is the LINE (`crntComponent`) the Segment's meta applies to, NOT the Segment.
                # Reads `st.working` and appends to `st.verdicts` — never alters render bytes.
                # v0.2 CH-1 (step 3): the ORIGIN rides the key — `childComponent` (the Segment) mints
                #   the target/origin split, so two same-kind inline Segment evals on one Line stay
                #   DISTINCT through the segment-carried remap.
                capture_verdicts!(st, crntComponent; origin = childComponent)
            end
        end
    end
    return metaEnvInt
end
