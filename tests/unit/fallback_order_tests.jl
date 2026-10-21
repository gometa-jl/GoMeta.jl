# fallback_order_tests.jl — THE fallBack LEVEL IS CONSULTED LAST (the creator's words:
# "it only gets applied if no altValue … has been set / evaluated for any of the preceeding meta level").
#
# IS:   three witnesses of the apply's slot order with the fallBack slot OCCUPIED — the way the user feed occupies the user slot
#       (`updateMetaHierarchy(fallBackMHIdx)` + `absorbMeta`, a minted user-context identity as the statement's carrier); the Engine's
#       own absorb walk, apply and capture then run over the prepared state through the test's OWN copy of goMeta's File loop
#       (the Engine's `_walk_and_apply!` factoring, once cut for this test, was removed —
#       the loop below is that body, verbatim).
# DOES: [F1] a Block under a metaLine WITHOUT Visib takes the fallBack value (hide), its row's `decided_by` the fallBack carrier;
#       [F2] a document `#~ show` WINS over the fallBack `hide` (the fallBack slot last); [F3] the user feed `discard` WINS over
#       the fallBack `hide` (the user level precedes); in every case the metaBlock itself follows the same order.
# REASONING: no feed occupies the fallBack slot in the Engine today (the `metaLevel` Alterant and its feeds come later —
#       the creator's design); the order is nevertheless BUILT now, with room for them, so the test prepares the slot itself.
# PURPOSE: the consult order MEASURED, never inferred from the code's shape.

using Test
import GoMeta as GM

@testset "fallBack consult order" begin
    _bytes(s) = Vector{UInt8}(codeunits(s))
    _h(t, c) = GM.key_bytes(GM.occurrence_key(t, c; namespace = :default))
    _rows(st) = st.evals.records
    _visib(st, h) = [x for x in _rows(st) if x.cell_handle == h && x.attr === :visib]
    FALLBACK_CARRIER = GM.key_bytes(GM.user_context_key(:default, 2))   # the stand-in identity of the fallBack statement (ordinal 2; the user feed is 1)

    ## run the Engine's pipeline over `src` with the fallBack slot fed `fb` (a metaLine body) and, optionally, the user profile
    function _run_with_fallback(src::String, fb::String; user_profile = nothing)
        ps = GM.BLS.setUpToProcessFromBytes(_bytes(src))
        GM.BLS.parseBLS(ps, 1, -1)   # the manual pipeline an adapter rides: setup → parse → the walk and apply (carrier_seam_tests.jl's form)
        cfg = user_profile === nothing ? GM.GoMetaConfig() : GM.GoMetaConfig(; user_mh_profile = user_profile)
        st = GM.init_state(ps, cfg, GM.DEFAULT_REGISTRY)
        Base.ScopedValues.with(GM.STATE => st) do
            user_profile === nothing || GM.feed_user_mh!(st)
            # the fallBack feed — the user feed's shape (feed_user_mh!), aimed at slot 12
            prev = st.crnt_idx
            GM.CnS.updateMetaHierarchy(GM.fallBackMHIdx)
            st.meta_context = nothing
            prior = st.user_context
            st.user_context = GM.UserContext(copy(FALLBACK_CARRIER))   # the context carries its handle alone (no copy of the statement's bytes)
            try
                GM.AbsorbMeta.absorbMeta(SubString(fb))
            finally
                st.user_context = prior
            end
            st.crnt_idx = prev
            # the File loop — goMeta's own body, copied verbatim: per child Block the absorb walk, the apply and the capture
            crntFileComponent::GM.BLS.File = ps.componentsPDict[GM.BLS.File][1][1]
            local metaEnvInt::Int = GM.BLS.orderedComponentTypesNamedT[:noMetaEnvYet]
            local childComponent::GM.BLS.Block
            for childId in GM.BLS.eachchildid(crntFileComponent, ps.componentsPDict[GM.BLS.File][1])
                if childId > 0
                    childComponent = ps.componentsPDict[GM.BLS.Block][1][childId]
                else
                    childId *= -1
                    childComponent = ps.componentsPDict[GM.BLS.Block][2][childId]
                end
                if !GM.BLS.getElement(childComponent.componentSettribute, :depricated)
                    if GM.BLS.getElement(childComponent.componentSettribute, :containsMeta) &&
                       !GM.BLS.getElement(childComponent.componentSettribute, :ignoreThisMeta)
                        metaEnvInt = GM.BLS.orderedComponentTypesNamedT[:noMetaEnvYet]
                        metaEnvInt = GM.absorbWalk(ps, childComponent::GM.BLS.Block, metaEnvInt)
                    end
                end
                if GM.BLS.getElement(childComponent.componentSettribute, :attachedToMeta)
                    GM.applyAltActionFns(childComponent::GM.BLS.Block)
                    GM.captureEvals!(st, childComponent)
                end
            end
        end
        return st, ps
    end

    @testset "[F1] a Block under a metaLine without Visib takes the fallBack value; the row names the fallBack carrier" begin
        st, ps = _run_with_fallback("#~ :label1\nx = 1\n", "hide")
        bs = collect(GM.BLS.children(ps)); @test length(bs) == 2
        for b in bs
            r = _visib(st, _h(ps, b)); @test length(r) == 1
            @test r[1].value === :hide
            @test r[1].decided_by == [FALLBACK_CARRIER]
        end
        @test st.mh.slot_occupied[st.mh.slots[GM.fallBackMHIdx]]   # the slot stayed occupied through the whole walk
    end

    @testset "[F2] a document `show` wins over the fallBack `hide` — the fallBack slot is consulted LAST" begin
        st, ps = _run_with_fallback("#~ show\nx = 1\n", "hide")
        bs = collect(GM.BLS.children(ps)); @test length(bs) == 2
        hm = _h(ps, bs[1])
        for b in bs
            r = _visib(st, _h(ps, b)); @test length(r) == 1
            @test r[1].value === :show
            @test r[1].decided_by == [hm]          # the document's statement, not the fallBack carrier
        end
    end

    @testset "[F3] the user feed `discard` wins over the fallBack `hide` — the user level precedes" begin
        st, ps = _run_with_fallback("#~ :label1\nx = 1\n", "hide"; user_profile = "discard")
        bs = collect(GM.BLS.children(ps)); @test length(bs) == 2   # never a vacuous loop
        uc = GM.key_bytes(GM.user_context_key(:default, 1))
        for b in bs
            r = _visib(st, _h(ps, b)); @test length(r) == 1
            @test r[1].value === :discard
            @test r[1].decided_by == [uc]
        end
    end

    @testset "[F4] the public path: a user profile with a QUEUED action runs" begin
        # the enqueue records the statement's origin; on the user feed that is the user-context handle — read through a type
        # the absorb module did not then import (`UserContext`): the earlier user-profile tests fed headings, which the former separate path
        # diverted before the enqueue (a fed heading refuses at the read)
        r = GM.goMeta(_bytes("#~ :label1\nx = 1\n"); config = GM.GoMetaConfig(; user_mh_profile = "discard"))
        @test r.status === GM.PROCESS_OK
        uc = GM.key_bytes(GM.user_context_key(:default, 1))
        rows = [x for x in r.altValues_evals.records if x.attr === :visib]
        @test length(rows) == 2 && all(x -> x.value === :discard && x.decided_by == [uc], rows)
        @test [(a, v) for (h, a, v, p) in GM.readAltValuesEvals(r.altValues_evals) if a === :visib] == [(:visib, :discard), (:visib, :discard)]
    end
end
