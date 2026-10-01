# childdiff_tests.jl — stage 2's commit 6 of the v0.4 build: THE CHILD-DIFFERS SIGNAL `childDiffers` (R-V04B-35 (e); his §37 item 4.2;
# the plan v8.1 :58), over the inputs whose rows and deciding handles were MEASURED for commit 4 (receipts/S8-branch/precheck-s2c4/PROBES-*).
#
# IS:   four witnesses: [D1] a rowless Line inheriting its Block's value does NOT differ; a Block differs from the File; [D2] a Line with its
#       own inline statement differs from its Block, its Segment does not differ from the Line; [D3] a meta-free input — the Lines do not
#       differ from their Block (both the default), the Block differs from the File; [D4] the File, the refusal, the surface.
# PURPOSE: the signal measured against `answerFor` on both sides — never inferred from a row's presence.

using Test
import GoMeta as GM
const _CD_BLS = GM.BLS

_cd_bytes(s::String) = Vector{UInt8}(codeunits(s))

@testset "childDiffers (stage 2 commit 6; R-V04B-35 (e))" begin

    @testset "[D1] a rowless Line inheriting its Block's value does not differ; a Block differs from the File" begin
        r = GM.goMeta(_cd_bytes("#~ hide\nx = 1\ny = 2\n")); ps = r.blsComponentTree
        bs = _CD_BLS.children(ps); @test length(bs) == 2
        @test GM.childDiffers(r, bs[1], :Visib) === true                 # :hide against the File's nothing
        @test GM.childDiffers(r, bs[2], :Visib) === true
        ls = _CD_BLS.children(ps, bs[2]); @test length(ls) == 2
        @test all(l -> GM.childDiffers(r, l, :Visib) === false, ls)      # :hide inherited — hidden as PART OF the Block
        @test GM.childDiffers(r, bs[2], :labels) === false              # nothing against nothing
    end

    @testset "[D2] a Line's own inline statement differs from its Block; its Segment does not differ from the Line" begin
        r = GM.goMeta(_cd_bytes("#~ \"Title\"\nx = 1 #~ discard\ny = 2\n")); ps = r.blsComponentTree
        bs = _CD_BLS.children(ps); @test length(bs) == 2
        ls = _CD_BLS.children(ps, bs[2]); @test length(ls) == 2
        @test GM.childDiffers(r, ls[1], :Visib) === true                 # :discard against the Block's :show (the default)
        @test GM.childDiffers(r, ls[2], :Visib) === false                # :show against :show
        segs = _CD_BLS.children(ps, ls[1]); @test !isempty(segs)
        @test all(s -> GM.childDiffers(r, s, :Visib) === false, segs)    # every Segment of the Line answers the Line's :discard
        @test GM.childDiffers(r, bs[1], :heading) === true               # "Title" against the File's nothing
        @test GM.childDiffers(r, _CD_BLS.children(ps, bs[1])[1], :heading) === false   # the metaLine's own Line inherits the heading
    end

    @testset "[D3] a meta-free input: the Lines equal their Block (the default); the Block differs from the File" begin
        r = GM.goMeta(_cd_bytes("x = 1\n")); ps = r.blsComponentTree
        bs = _CD_BLS.children(ps); @test length(bs) == 1
        @test GM.childDiffers(r, bs[1], :Visib) === true                 # :show (the declared default) against nothing
        @test GM.childDiffers(r, bs[1], :labels) === false
        ls = _CD_BLS.children(ps, bs[1]); @test length(ls) == 1
        @test GM.childDiffers(r, ls[1], :Visib) === false
    end

    @testset "[D4] the File never differs; the refusal; the surface" begin
        r = GM.goMeta(_cd_bytes("#~ hide\nx = 1\n")); ps = r.blsComponentTree
        @test GM.childDiffers(r, _CD_BLS.root(ps), :Visib) === false
        @test_throws ArgumentError GM.childDiffers(r, _CD_BLS.children(ps)[1], :nosuch)
        @test Base.ispublic(GM, :childDiffers) && !Base.isexported(GM, :childDiffers)
        @test hasmethod(GM.childDiffers, Tuple{GM.GoMetaDelivery, GM.BLS.Line, Symbol})
    end
end
