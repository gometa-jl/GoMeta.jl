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
#     sits at Segment level, `applyAltActionFns` (apply.jl) runs immediately; a resolved Visib value
#     is CAPTURED on the ENCLOSING Line (inline meta applies to its line — docs/SYNTAX-AND-SEMANTICS.md §9)
#     by `captureEvals!` (annotations.jl), which records that Line as the cell; the former write into the
#     Line's settribute left at stage 3's commit 4 (R-V04B-42 (1)).
# REASONING: this file holds no eval — conditions enqueued here are evaluated later at the
#     documented condition seam (README SECURITY; docs/public-api.md §3.2). Malformed, unknown, and
#     over-capacity meta refuse inside `absorbMeta` (docs/public-api.md §3.4).
# PURPOSE: a deterministic walk that turns authored metaLines into enqueued alterant state, re-runnable
#     against the shipped corpus via devtools/run_examples.jl.

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
    # {grain, depth, application level, occurrence handle}, derived from the parse and
    # the configured namespace, stored in NO
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
    # R-V04B-50 (stage 2's commit 1 — THE HEADING RE-KEY): a WHOLE-LINE metaLine's heading is carried by the
    # metaBlock it forms (his §12: "applied to the first Block only"; his §8 item 3: it applies to the Block's
    # children INDIRECTLY through the Block), so the context record's HANDLE and the published CONTENT are the
    # Block's — the parent of the metaLine (a Line-grain handover is always a whole-line metaLine: the one Line
    # call site is guarded by `:hasMetaStr`); an inline metaSegment (a Segment-grain handover) keeps its own.
    # The record's grain, depth and level stay the metaLine's (the heading recognizer reads the level).
    local keyComponent = crntComponent isa BLS.Line ? BLS.parent(parse_state, crntComponent) : crntComponent
    local _mc_key = occurrence_key(parse_state, keyComponent;
        namespace = st.config.namespace)
    local _mc_content = BLS.content(parse_state, keyComponent)   # the degenerate-key diagnostic's payload only — stored on no row; a copy rides the diagnostic's context when it fires (R-V04B-43 (1), commit 9b; card C18)
    # DEGENERATE-KEY PARITY: the per-cell capture warns loudly on a
    # truncated-walk (degenerate) occurrence key; the metaLine's context-record key
    # gets the SAME diagnostic HERE — capture_heading! receives only the serialized
    # bytes and cannot run the check itself. Fires at every metaLine handover
    # (heading or not — the record keys whatever this metaLine delivers), and it can OVERLAP the capture site's own check when this
    # component later rides a capture as `origin` — both unreachable on real parses
    # (the capture site's note; zero TRUNCATED steps corpus-wide), both loud,
    # non-fatal; the overlap is recorded, not deduplicated. The content read through the
    # door for the payload only (no row stores it since commit 9b; the diagnostic's context carries a copy when it fires).
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
    if matchFound.offsets[end] != 0 &&
       !BLS.getElement(crntComponent.componentSettribute, :ignoreMetaContent)
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
        ## Two roads here: a live marker with NOTHING after it (offsets[end] == 0), and —
        ## R-INERT-4 (v0.3.1) — an :ignoreMetaContent component (the author's
        ## trailing-bang "#~N!"), whose content is deliberately absorbed as EMPTY: the specified
        ## law is "#~N! <content>" ≡ "#~N" (structure live, content ignored), so BOTH roads
        ## run the IDENTICAL live-empty intake — the ≡ holds by construction, not by a
        ## parallel code path. (Everything upstream — snapshot, MetaContext publish, the
        ## dispatch — already ran identically; the dispatch sees metaDef "N!"/"0!" but every
        ## metaDef routes to the standard absorbMeta: the comparison above is a SubString-vs-
        ## Symbol TYPE MISMATCH (always unequal via ===), so its else-arm is dead code — AND,
        ## independently, metaDefNamedTuple maps the keys to the same fn, so even "fixing"
        ## the comparison needs the table taught the "N!" keys first. Pinned by the
        ## differential-oracle tests; do not "clean up" the comparison without both.)
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

    # Hoist `local st = ctx()` once per call — the per-child apply and capture inside the
    # `for childId` loop below go through the single hoisted `st`,
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
                ## letting a stale Visib value win over a new one (e.g. an inline `#~ discard` rendered as
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
                ## The Segment-grain Visib write-back onto the Line LEFT here (stage 3's commit 4 of the v0.4 build, R-V04B-42 (1)): the Engine writes NOTHING into the
                ## caller's BLS Components — a Segment-carried Visib value is CAPTURED on its Line (below) and read through
                ## the one answer function (R-V04B-16 (1)); the registry's `settribute` declarations and the derived table stay
                ## until his word (R-V04B-42 (2)). The E-04 flagless read (`keys(Visib)[array][1]`) went with the write.
                # Capture the Segment-grain FINAL evals rows before the next apply wipes `st.working`;
                # the cell is the LINE (`crntComponent`) the Segment's meta applies to, NOT the Segment.
                # Reads `st.working`, puts or supersedes rows in `st.evals` (and may append warning
                # diagnostics) — never alters render bytes.
                # v0.2 CH-1 (step 3): the ORIGIN rides the key — `childComponent` (the Segment) mints
                #   the target/origin split, so two same-kind inline Segment evals on one Line stay
                #   DISTINCT through the segment-carried remap.
                captureEvals!(st, crntComponent; origin = childComponent)
            end
        end
    end
    return metaEnvInt
end
