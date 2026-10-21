# origin_tests.jl — THE ONE PROVENANCE FIELD `decided_by` on `EvalRecord`.
#
# IS:   the unit witnesses that the origin of an applied action is RECORDED at the enqueue (the stating Component's
#       handle), carried through the apply and captured with the row — MEASURED, never inferred from a row's presence.
# DOES: runs goMeta on four inline documents and pins each row's `decided_by` against the handles computed from the
#       delivered tree through the door (`occurrence_key` + `key_bytes`, the default namespace).
# REASONING: the creator's design — "so that own or indirect is MEASURED, never inferred from a row's presence"; the authored
#       runner's `decided_by` assertion builds on this field.
# PURPOSE: the commit-2 witness (the same-commit triple's test leg).

using Test
import GoMeta as GM

@testset "origin — the provenance field decided_by" begin
    _run(s) = GM.goMeta(Vector{UInt8}(codeunits(s)))
    _h(t, c) = GM.key_bytes(GM.occurrence_key(t, c; namespace = :default))
    _blocks(t) = collect(GM.BLS.children(t))
    _rows(r) = r.altValues_evals.records
    _row(r, h, attr) = only(x for x in _rows(r) if x.cell_handle == h && x.attr === attr)

    @testset "[O1] an inherited Visib row names the stating metaBlock; the metaBlock's own row names itself" begin
        r = _run("#~ hide\na = 1\nb = 2\n")
        @test r.status === GM.PROCESS_OK
        t = r.blsComponentTree; bs = _blocks(t)
        @test length(bs) == 2
        hm, hc = _h(t, bs[1]), _h(t, bs[2])          # the metaBlock; the Code Block attached to it
        @test _row(r, hm, :visib).decided_by == [hm]  # own
        @test _row(r, hc, :visib).decided_by == [hm]  # indirect through the metaBlock
    end

    @testset "[O2] an accumulating row carries every contributing statement in application order" begin
        r = _run("#~ :label1\na = 1\n#~2 :label2\nb = 2\n")
        @test r.status === GM.PROCESS_OK
        t = r.blsComponentTree; bs = _blocks(t)
        @test length(bs) == 4
        h1, h3 = _h(t, bs[1]), _h(t, bs[3])          # the depth-1 metaBlock; the depth-2 metaBlock
        @test _row(r, h1, :label_label1).decided_by == [h1]
        @test _row(r, h3, :label_label1).decided_by == [h1, h3]
        @test _row(r, h3, :label_label2).decided_by == [h1, h3]
    end

    @testset "[O3] an inline metaSegment's Visib row (keyed on its Line) names the Segment" begin
        r = _run("#~ hide\na = 1\nb = 2  #~ show\n")
        @test r.status === GM.PROCESS_OK
        t = r.blsComponentTree; bs = _blocks(t)
        ln = only(l for l in GM.BLS.children(t, bs[2]) if GM.BLS.getElement(l, :inputLineNum) == 3)
        seg = last(collect(GM.BLS.children(t, ln)))   # the metaSegment at the Line's end
        hl = GM.key_bytes(GM.occurrence_key(t, ln; origin = seg, namespace = :default))   # the Segment-carried row's key
        rowl = _row(r, hl, :visib)
        @test rowl.value === :show
        @test rowl.decided_by == [_h(t, seg)]
    end

    @testset "[O4] a heading row's origin is its own carrier; the field rides every row" begin
        r = _run("#~ \"Title\"\nx = 1\n")
        @test r.status === GM.PROCESS_OK
        t = r.blsComponentTree; hm = _h(t, first(_blocks(t)))
        @test _row(r, hm, :head_1).decided_by == [hm]
        @test all(x -> x.decided_by isa Vector{Vector{UInt8}} && !isempty(x.decided_by), _rows(r))
    end
end
