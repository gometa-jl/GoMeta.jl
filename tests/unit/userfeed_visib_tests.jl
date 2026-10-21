# userfeed_visib_tests.jl — THE FED VISIB VERDICT AGAINST AN AUTHORED ONE (a review finding:
# "All five user_mh_profile tests feed headings; none opposes a fed Visib action against an authored one. Add fed 'show' against
# authored '#~ hide', asserting the fed verdict wins and the rows carry the user-context handle").
#
# IS:   five witnesses over the public entry, every value MEASURED first but one — [U5]'s "  " on its document, the testset's own
#       run, disclosed there — (the fed verdict's handle = the user-context key of ordinal 1): [U1] fed `show` against authored `#~ hide` — the fed
#       verdict wins on the metaBlock and the attached Block, the rows carry the user-context handle; [U2] fed `hide` against authored `#~ show`
#       — the same, the other way; [U3] fed `discard` over a meta-free input — PROCESS_OK and ZERO rows (no Block is attached to meta, the
#       apply runs for none); [U4] the fed verdict read through the answer function: `:user`; [U5] (the creator's
#       word of 2026-10-16) an EMPTY or whitespace-only profile is INERT like no profile: it feeds nothing and
#       occupies no slot, so the loop's order is the un-fed one — the slot's inertness rests on the driver's non-blank test at the `feed_user_mh!` call
#       site (src/GoMeta.jl); since 0.4.1 the two documents below give the same heading and Visib rows fed the former pins' `:label3` or not — a fed label no condition of theirs tests adds its own label rows alone (4 rows where the no-feed twin has 2; a fed label a condition does test IS seen — fed_profile_order_tests.jl [W7], [W10]) — so [U5]'s assertions on those rows cannot tell an inert profile from a fed one and check the delivered rows alone (MEASURED
#       when the fed order still differed — before
#       the change an empty profile occupied the user slot); a profile whose edge character is an INVALID
#       byte sequence is content, never white space — FED; the one-character overlong profile refused by the absorb as
#       before (MEASURED), an invalid sequence glued to the label sugar `:` fed and NOT refused (MEASURED —
#       PROCESS_OK, no row).
# REASONING: the user slot is placed FIRST in both apply walks' slot order and, since 0.4.1, evaluated after
#       the Component's own slot with the override (feed_user_mh!'s docstring: "the fed profile OVERRIDES authored Visib");
#       a queued fed action reaches the enqueue's origin line (commit 2) that no heading-only profile reaches — the path commit 3a's witness F3
#       found broken (the UserContext import) is witnessed here at the public entry for its own sake.
# PURPOSE: the fed verdict's precedence and provenance, measured — never inferred from the feed's docstring.

using Test
import GoMeta as GM
const _UF_BLS = GM.BLS

_uf_bytes(s::String) = Vector{UInt8}(codeunits(s))

@testset "the fed Visib verdict against an authored one" begin
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
            a = GM.evaluatedAltValue(r, b, :Visib); @test a.value === :show && a.source === :user && a.via === nothing
        end
        ls = _UF_BLS.children(ps, bs[2]); @test length(ls) == 2
        @test all(l -> GM.evaluatedAltValue(r, l, :Visib).source === :user, ls)        # the rowless Lines inherit the fed verdict
    end

    @testset "[U5] an EMPTY or whitespace-only profile is INERT like no profile; an invalid edge byte is no white space (the creator's decision; MEASURED)" begin
        # the document: `hide{ :label1 }` stated BEFORE `:label1` on one metaLine — un-fed, the hide's condition does not see the label
        # (no visib row); before 0.4.1 a FED profile (`:label3`) made the user slot the loop's first and the hide
        # applied — since 0.4.1 it does not (fed_profile_order_tests.jl [W5]), so these assertions no longer tell an inert profile from a fed one (a
        # user slot without rows equals no feed under the cured order — the stage-0 plan §3): they check the delivered rows alone; that "" and "  " occupy no
        # slot rests on the driver's non-blank test (src/GoMeta.jl, the `feed_user_mh!` call site); "" and "  " must behave as no profile
        # ("" on this document MEASURED first; "  " on this document is this testset's own run, green — the
        # measurement of "  " was on the second document below)
        for p in ("", "  ")
            r = GM.goMeta(_uf_bytes("#~ hide{ :label1 } :label1\nx = 1\n"); config = GM.GoMetaConfig(; user_mh_profile = p))
            @test r.status === GM.PROCESS_OK && isempty(_visib_rows(r))
        end
        # the P24 document: a heading whose condition tests a label stated after it — no head row un-fed (P07); none with "" either (L04)
        r24 = GM.goMeta(_uf_bytes("#~2 head(\"T\"){ :label2 } :label2\nx = 1\n"); config = GM.GoMetaConfig(; user_mh_profile = ""))
        @test r24.status === GM.PROCESS_OK && !any(x -> startswith(String(x.attr), "head"), r24.altValues_evals.records)
        # an INVALID edge byte is content, never white space (the absorb's one predicate): a profile whose only character is
        # an overlong sequence is FED and meets the absorb's unknown-action refusal, as before — never Julia's raw
        # InvalidCharError out of the driver's feed test (MEASURED on both trees)
        e8 = try GM.goMeta(_uf_bytes("x = 1\n"); config = GM.GoMetaConfig(; user_mh_profile = "\xe0\x80\x80")); nothing catch err; err end
        @test e8 isa ErrorException && occursin("GoMeta absorb: unknown alterant action", e8.msg)
    end
end
