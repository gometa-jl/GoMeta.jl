# scan_tests.jl — stage 2's commit 5 of the v0.4 build: THE SCAN BY ALTERANT and THE ACCESS BY COMPONENT (the plan v8.1 :57; card 4;
# his §6 item 9.A), over the inputs whose rows and deciding handles were MEASURED for commit 4 (receipts/S8-branch/precheck-s2c4/PROBES-*).
#
# IS:   six witnesses: [S1] the scan lists the recorded Components only, in tree order, each with its answer; [S2] the scan of a Labels
#       set; [S3] a meta-free input scans empty; [S4] the Segment-carried row lists its Line with the Line's OWN answer; [S5] the access by Component in the
#       registry's Alterant order; the refusal; the surface; [S6] two custom registries — a stem-less Visib (the derived stem `:visib`)
#       lists its two Blocks, a capture-less Visib lists nothing while `evaluatedAltValues` still answers the declared default.
# PURPOSE: the two views never disagree with `evaluatedAltValue` (they are built on it) — measured, not assumed.

using Test
import GoMeta as GM
const _SC_BLS = GM.BLS

_sc_bytes(s::String) = Vector{UInt8}(codeunits(s))
_sc_id(c) = _SC_BLS.getElement(c.cmpntNamedInt, :idComponent)

@testset "scanAlterant / evaluatedAltValues (stage 2 commit 5; his 9.A)" begin

    @testset "[S1] the scan by Alterant: the recorded Components only, in tree order, with their answers" begin
        r = GM.goMeta(_sc_bytes("#~ hide\nx = 1\ny = 2\n")); ps = r.blsComponentTree
        bs = _SC_BLS.children(ps); @test length(bs) == 2
        sc = GM.scanAlterant(r, :Visib)
        @test sc isa Vector{Pair{GM.BLS.AbstractComponent,GM.EvaluatedAltValue}}
        @test length(sc) == 2                                        # the two Blocks carry rows; the three Lines do not
        @test _sc_id(sc[1].first) == _sc_id(bs[1]) && sc[1].second.value === :hide && sc[1].second.source === :own
        @test _sc_id(sc[2].first) == _sc_id(bs[2]) && sc[2].second.value === :hide && sc[2].second.source === :indirect
        @test all(pr -> pr.second == GM.evaluatedAltValue(r, pr.first, :Visib), sc)     # never disagrees with the one answer function
        @test isempty(GM.scanAlterant(r, :labels)) && isempty(GM.scanAlterant(r, :heading))
    end

    @testset "[S2] the scan of a Labels set" begin
        r = GM.goMeta(_sc_bytes("#~ :label1 :label5\nx = 1\n"))
        sc = GM.scanAlterant(r, :labels); @test length(sc) == 2
        @test all(pr -> pr.second.value == [:label1, :label5], sc)
        @test sc[1].second.source === :own && sc[2].second.source === :indirect
    end

    @testset "[S3] a meta-free input scans empty for every Alterant" begin
        r = GM.goMeta(_sc_bytes("x = 1\n"))
        for alt in (:labels, :Visib, :id, :heading)
            @test isempty(GM.scanAlterant(r, alt))
        end
    end

    @testset "[S4] a Segment-carried row lists its Line — the Line's OWN answer (the trailing metaSegment applies directly to it, R-V04B-93)" begin
        r = GM.goMeta(_sc_bytes("#~ \"Title\"\nx = 1 #~ discard\ny = 2\n")); ps = r.blsComponentTree
        bs = _SC_BLS.children(ps); @test length(bs) == 2
        sc = GM.scanAlterant(r, :Visib); @test length(sc) == 1
        @test sc[1].first isa _SC_BLS.Line && _sc_id(sc[1].first) == _sc_id(_SC_BLS.children(ps, bs[2])[1])
        @test sc[1].second.value === :discard && sc[1].second.source === :own && sc[1].second.via === nothing   # R-V04B-93 (his §286/§288): the Line answers :own — the Segment is the statement's carrier, not a foreign decider
        hs = GM.scanAlterant(r, :heading); @test length(hs) == 1
        @test _sc_id(hs[1].first) == _sc_id(bs[1]) && hs[1].second.value == "Title" && hs[1].second.source === :own
    end

    @testset "[S6] a custom registry: an undeclared capture stem derives as the walk derives it; a capture-less Alterant lists nothing" begin
        _sc_with_capture(p, cap) = GM.Alterant(; altName = p.altName, setMode = p.setMode, altConstructor = p.altConstructor,
            setAltInstance = p.setAltInstance, getAltInstance = p.getAltInstance, precedencesTuple = p.precedencesTuple,
            default = p.default, capture = cap)
        k = findfirst(p -> p.altName === :Visib, GM.DEFAULT_REGISTRY.plugins); @test k !== nothing
        b1 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        b1.plugins[k] = _sc_with_capture(b1.plugins[k], GM.CaptureDecl(:single; attr_stem = nothing))
        R1 = GM.publish(b1)
        r1 = GM.goMeta(_sc_bytes("#~ hide\nx = 1\n"); registry = R1); @test r1.status === GM.PROCESS_OK
        sc1 = GM.scanAlterant(r1, :Visib; registry = R1); @test length(sc1) == 2      # the rows minted under the derived stem :visib are listed
        @test all(pr -> pr.second.value === :hide, sc1)
        b2 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        b2.plugins[k] = _sc_with_capture(b2.plugins[k], nothing)
        R2 = GM.publish(b2)
        r2 = GM.goMeta(_sc_bytes("#~ hide\nx = 1\n"); registry = R2); @test r2.status === GM.PROCESS_OK
        @test isempty(GM.scanAlterant(r2, :Visib; registry = R2))                     # no capture declaration: nothing recorded, nothing listed
        an2 = GM.evaluatedAltValues(r2, _SC_BLS.children(r2.blsComponentTree)[2]; registry = R2)
        @test an2[2].first === :Visib && an2[2].second.source === :default           # the access still answers the declared default
    end

    @testset "[S5] the access by Component in the registry's Alterant order; the refusal; the surface" begin
        r = GM.goMeta(_sc_bytes("#~ hide\nx = 1\ny = 2\n")); ps = r.blsComponentTree
        bs = _SC_BLS.children(ps); @test length(bs) == 2
        an = GM.evaluatedAltValues(r, bs[2])
        @test an isa Vector{Pair{Symbol,GM.EvaluatedAltValue}}
        @test first.(an) == [p.altName for p in GM.DEFAULT_REGISTRY.plugins] == [:labels, :Visib, :id, :heading]
        @test an[2].second.value === :hide && an[2].second.source === :indirect
        @test an[1].second.source === :default && an[3].second.source === :default && an[4].second.source === :default   # the three declared defaults (R-V04B-92, card C2)
        @test all(pr -> pr.second == GM.evaluatedAltValue(r, bs[2], pr.first), an)
        fa = GM.evaluatedAltValues(r, _SC_BLS.root(ps)); @test length(fa) == 4 && all(pr -> pr.second.source === :none, fa)
        @test_throws ArgumentError GM.scanAlterant(r, :nosuch)
        @test Base.ispublic(GM, :scanAlterant) && !Base.isexported(GM, :scanAlterant)
        @test Base.ispublic(GM, :evaluatedAltValues) && !Base.isexported(GM, :evaluatedAltValues)
    end
end
