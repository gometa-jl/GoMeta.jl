# userfeed_visib_tests.jl — stage 2's commit 7b of the v0.4 build: THE FED VISIB VERDICT AGAINST AN AUTHORED ONE (the CrossReview set REAL-1
# R2 #13 — "All five user_mh_profile tests feed headings; none opposes a fed Visib action against an authored one. Add fed 'show' against
# authored '#~ hide', asserting the fed verdict wins and the rows carry the user-context handle"; the plan v8.1 :62 — the R2 test proposals that
# witness stage-2 code; the brief v2 §1 row 7a–c).
#
# IS:   four witnesses over the public entry, every value MEASURED first (R4b; receipts/S8-branch/precheck-s2c4/PROBES-origins_decided_by.txt
#       cases E and F; the fed verdict's handle = the user-context key of ordinal 1): [U1] fed `show` against authored `#~ hide` — the fed
#       verdict wins on the metaBlock and the attached Block, the rows carry the user-context handle; [U2] fed `hide` against authored `#~ show`
#       — the same, the other way; [U3] fed `discard` over a meta-free input — PROCESS_OK and ZERO rows (no Block is attached to meta, the
#       apply runs for none); [U4] the fed verdict read through the answer function: `:user`.
# REASONING: the user slot is scanned FIRST by both apply walks (feed_user_mh!'s docstring: "the fed profile OVERRIDES authored Visib");
#       a queued fed action reaches the enqueue's origin line (commit 2) that no heading-only profile reaches — the path commit 3a's witness F3
#       found broken (the UserContext import) is witnessed here at the public entry for its own sake.
# PURPOSE: the fed verdict's precedence and provenance, measured — never inferred from the feed's docstring.

using Test
import GoMeta as GM
const _UF_BLS = GM.BLS

_uf_bytes(s::String) = Vector{UInt8}(codeunits(s))

@testset "the fed Visib verdict against an authored one (stage 2 commit 7b; REAL-1 R2 #13)" begin
    uc = GM.key_bytes(GM.user_context_key(:default, 1))
    _visib_rows(r) = [x for x in r.altValues_evals.records if x.attr === :visib]

    @testset "[U1] fed `show` against authored `#~ hide`: the fed verdict wins; the rows carry the user-context handle" begin
        r = GM.goMeta(_uf_bytes("#~ hide\nx = 1\n"); config = GM.GoMetaConfig(; user_mh_profile = "show"))
        @test r.status === GM.PROCESS_OK
        rows = _visib_rows(r); @test length(rows) == 2
        @test all(x -> x.value === :show && x.decided_by == [uc], rows)
        @test [v for (h, a, v, p) in GM.readAltValuesEvals(r.altValues_evals) if a === :visib] == [:show, :show]
    end

    @testset "[U2] fed `hide` against authored `#~ show`: the fed verdict wins the other way too" begin
        r = GM.goMeta(_uf_bytes("#~ show\nx = 1\n"); config = GM.GoMetaConfig(; user_mh_profile = "hide"))
        @test r.status === GM.PROCESS_OK
        rows = _visib_rows(r); @test length(rows) == 2
        @test all(x -> x.value === :hide && x.decided_by == [uc], rows)
    end

    @testset "[U3] fed `discard` over a meta-free input: PROCESS_OK and zero rows (no Block attached to meta — the apply runs for none)" begin
        r = GM.goMeta(_uf_bytes("x = 1\n"); config = GM.GoMetaConfig(; user_mh_profile = "discard"))
        @test r.status === GM.PROCESS_OK
        @test isempty(r.altValues_evals.records)
    end

    @testset "[U4] the fed verdict through the answer function: the source `:user`" begin
        r = GM.goMeta(_uf_bytes("#~ hide\nx = 1\ny = 2\n"); config = GM.GoMetaConfig(; user_mh_profile = "show")); ps = r.blsComponentTree
        bs = _UF_BLS.children(ps); @test length(bs) == 2
        for b in bs
            a = GM.answerFor(r, b, :Visib); @test a.value === :show && a.source === :user && a.via === nothing
        end
        ls = _UF_BLS.children(ps, bs[2]); @test length(ls) == 2
        @test all(l -> GM.answerFor(r, l, :Visib).source === :user, ls)        # the rowless Lines inherit the fed verdict
    end
end
