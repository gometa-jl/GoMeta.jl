# answer_tests.jl — THE ONE ANSWER FUNCTION `evaluatedAltValue`.
#
# IS:   ten witnesses ([A1]–[A10]) of the answer's value and SOURCE over small inputs whose rows and deciding handles were MEASURED first
#       (the evals-tree printouts and the origin probe for [A1]–[A9], a testset
#       naming its own measurement where it differs; [A10] by the `ids` action's oracle).
# DOES: [A1] Visib — the metaBlock's own statement, the attached Block indirect through it, a rowless Line inherits; [A2] Labels —
#       the SET with one source; [A3] no rows anywhere — the declared default of each built-in Alterant, the File `:none`; [A4] a
#       Segment's statement — its Line OWN (the trailing metaSegment applies directly to it), its Segments the Line's
#       answer marked indirect, the heading metaBlock own, its rowless Line inherits the heading; [A5] the user feed — `:user` on
#       the Blocks, the Line and its Segments alike (a Segment answers as its Line answers); [A6] the refusals and the registry keyword; [A7] the
#       surface (package-public, not exported; the one method); [A8] a custom registry — an undeclared capture stem derived as the walk
#       derives it, a capture-less Alterant its declared default; [A9] the Id compound — a NamedTuple of the recorded fields, the nearest
#       statement's compound as a whole; [A10] the `ids` action's compound — the three fields at once, the stated zero absent, the later
#       single action overwriting a field.
# PURPOSE: the measured consult of the answer's two parts — the value and the source — never inferred from a row's presence.

using Test
import GoMeta as GM
const _AN_BLS = GM.BLS

_an_bytes(s::String) = Vector{UInt8}(codeunits(s))
_an_id(c) = _AN_BLS.getElement(c.cmpntNamedInt, :idComponent)

@testset "evaluatedAltValue" begin

    @testset "[A1] Visib: own on the metaBlock; indirect through it on the attached Block; a rowless Line inherits" begin
        r = GM.goMeta(_an_bytes("#~ hide\nx = 1\ny = 2\n")); ps = r.blsComponentTree
        bs = _AN_BLS.children(ps); @test length(bs) == 2
        a = GM.evaluatedAltValue(r, bs[1], :Visib)
        @test a isa GM.EvaluatedAltValue
        @test a.value === :hide && a.source === :own && a.via === nothing
        b = GM.evaluatedAltValue(r, bs[2], :Visib)
        @test b.value === :hide && b.source === :indirect
        @test b.via isa _AN_BLS.Block && _an_id(b.via) == _an_id(bs[1])
        ls = _AN_BLS.children(ps, bs[2]); @test length(ls) == 2
        l = GM.evaluatedAltValue(r, ls[2], :Visib)                      # "y = 2": no row of its own — its Block's, through the metaBlock
        @test l.value === :hide && l.source === :indirect
        @test l.via isa _AN_BLS.Block && _an_id(l.via) == _an_id(bs[1])
    end

    @testset "[A2] Labels: the SET of names with ONE source" begin
        r = GM.goMeta(_an_bytes("#~ :label1 :label5\nx = 1\n")); ps = r.blsComponentTree
        bs = _AN_BLS.children(ps); @test length(bs) == 2
        a = GM.evaluatedAltValue(r, bs[1], :labels)
        @test a.value == [:label1, :label5] && a.source === :own && a.via === nothing
        b = GM.evaluatedAltValue(r, bs[2], :labels)
        @test b.value == [:label1, :label5] && b.source === :indirect
        @test b.via isa _AN_BLS.Block && _an_id(b.via) == _an_id(bs[1])
    end

    @testset "[A3] no rows anywhere: the declared default of each built-in Alterant; the File answers nothing" begin
        r = GM.goMeta(_an_bytes("x = 1\n")); ps = r.blsComponentTree
        @test r.status === GM.PROCESS_OK && isempty(r.altValues_evals.records)
        bs = _AN_BLS.children(ps); @test length(bs) == 1
        a = GM.evaluatedAltValue(r, bs[1], :Visib)
        @test a.value === :show && a.source === :default && a.via === nothing     # Visib's ONE declared default
        b = GM.evaluatedAltValue(r, bs[1], :labels)
        @test b.value == Symbol[] && b.source === :default && b.via === nothing    # Labels' declared default: the EMPTY SET — MEASURED
        hd = GM.evaluatedAltValue(r, bs[1], :heading)
        @test hd.value === nothing && hd.source === :default && hd.via === nothing  # Heading's declared default: NONE
        id = GM.evaluatedAltValue(r, bs[1], :id)
        @test id.value == (cell = Int16(0), parent = Int16(0), file = Int16(0)) && id.source === :default   # Id's declared default: the ZERO compound
        l = GM.evaluatedAltValue(r, _AN_BLS.children(ps, bs[1])[1], :Visib)
        @test l.value === :show && l.source === :default                          # a rowless Line under a rowless Block: the default too
        f = GM.evaluatedAltValue(r, _AN_BLS.root(ps), :Visib)
        @test f.value === nothing && f.source === :none && f.via === nothing      # the File: NOTHING built (an open point)
    end

    @testset "[A4] a Segment's statement and a heading: the Line OWN (the trailing metaSegment applies directly to it), the Segment its Line's answer marked indirect; the metaBlock's heading own; its Line inherits" begin
        r = GM.goMeta(_an_bytes("#~ \"Title\"\nx = 1 #~ discard\ny = 2\n")); ps = r.blsComponentTree
        bs = _AN_BLS.children(ps); @test length(bs) == 2
        h = GM.evaluatedAltValue(r, bs[1], :heading)
        @test h.value == "Title" && h.source === :own && h.via === nothing
        hl = GM.evaluatedAltValue(r, _AN_BLS.children(ps, bs[1])[1], :heading)
        @test hl.value == "Title" && hl.source === :indirect && _an_id(hl.via) == _an_id(bs[1])
        ls = _AN_BLS.children(ps, bs[2]); @test length(ls) == 2
        l = GM.evaluatedAltValue(r, ls[1], :Visib)                      # "x = 1 #~ discard": the Line-keyed row, decided by Segment #3 — the Line's OWN statement (the trailing metaSegment applies directly to its Line)
        @test l.value === :discard && l.source === :own && l.via === nothing
        segs = _AN_BLS.children(ps, ls[1]); @test !isempty(segs)
        k = findfirst(s -> _an_id(s) == 3, segs); @test k !== nothing
        s = GM.evaluatedAltValue(r, segs[k], :Visib)                     # the Segment: no row keyed on itself — its Line's answer marked INDIRECT through the Line (the creator's words: applied to the metaSegment indirectly through its Line)
        @test s.value === :discard && s.source === :indirect && s.via isa _AN_BLS.Line && _an_id(s.via) == _an_id(ls[1])
        s0 = GM.evaluatedAltValue(r, segs[1], :Visib)                    # the Line's first Segment ("x = 1"): the same — its Line's answer, indirect through the Line
        @test s0.value === :discard && s0.source === :indirect && _an_id(s0.via) == _an_id(ls[1])
        l2 = GM.evaluatedAltValue(r, ls[2], :Visib)                     # "y = 2": neither it nor its Block carries a Visib row
        @test l2.value === :show && l2.source === :default
        n = GM.evaluatedAltValue(r, bs[2], :heading)
        @test n.value === nothing && n.source === :default       # Heading's declared default: none; the code Block carries no heading
    end

    @testset "[A5] the user feed: the source `:user`" begin
        r = GM.goMeta(_an_bytes("#~ hide\nx = 1\n"); config = GM.GoMetaConfig(; user_mh_profile = "show")); ps = r.blsComponentTree
        bs = _AN_BLS.children(ps); @test length(bs) == 2
        for b in bs
            a = GM.evaluatedAltValue(r, b, :Visib)
            @test a.value === :show && a.source === :user && a.via === nothing
        end
        # a Line WITH Segments under the feed: the fed value wins on the Line (:user) and its Segments answer AS
        # the Line answers — :user, not :indirect through the Line (MEASURED).
        # ("x = 1" alone has NO Segments — a Segment needs the inline `#~`.)
        r2 = GM.goMeta(_an_bytes("x = 1 #~ discard
"); config = GM.GoMetaConfig(; user_mh_profile = "show")); ps2 = r2.blsComponentTree
        bs2 = _AN_BLS.children(ps2); @test length(bs2) == 1
        ls2 = _AN_BLS.children(ps2, bs2[1]); @test length(ls2) == 1
        l2 = GM.evaluatedAltValue(r2, ls2[1], :Visib)
        @test l2.value === :show && l2.source === :user && l2.via === nothing  # the feed over the Line's own `discard`
        segs2 = _AN_BLS.children(ps2, ls2[1]); @test length(segs2) == 2      # "x = 1 " and the metaSegment
        for sg in segs2
            a = GM.evaluatedAltValue(r2, sg, :Visib)
            @test a.value === :show && a.source === :user && a.via === nothing
        end
    end

    @testset "[A6] the refusals and the registry keyword" begin
        r = GM.goMeta(_an_bytes("#~ hide\nx = 1\n")); b1 = _AN_BLS.children(r.blsComponentTree)[1]
        @test_throws ArgumentError GM.evaluatedAltValue(r, b1, :nosuch)
        a = GM.evaluatedAltValue(r, b1, :Visib; registry = GM.DEFAULT_REGISTRY)
        @test a.value === :hide && a.source === :own
    end

    @testset "[A8] a custom registry: an undeclared capture stem derives as the walk derives it; a capture-less Alterant answers its declared default" begin
        # the Engine mints a stem-less Alterant's rows under lowercase(altName) and a capture-less Alterant's none
        _with_capture(p, cap) = GM.Alterant(; altName = p.altName, setMode = p.setMode, altConstructor = p.altConstructor,
            setAltInstance = p.setAltInstance, getAltInstance = p.getAltInstance, precedencesTuple = p.precedencesTuple,
            default = p.default, capture = cap)
        k = findfirst(p -> p.altName === :Visib, GM.DEFAULT_REGISTRY.plugins); @test k !== nothing
        b1 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        b1.plugins[k] = _with_capture(b1.plugins[k], GM.CaptureDecl(:single; attr_stem = nothing))
        R1 = GM.publish(b1)
        r1 = GM.goMeta(_an_bytes("#~ hide\nx = 1\n"); registry = R1); @test r1.status === GM.PROCESS_OK
        bs1 = _AN_BLS.children(r1.blsComponentTree); @test length(bs1) == 2
        @test any(x -> x.attr === :visib, r1.altValues_evals.records)                  # the rows minted under the derived stem :visib
        a1 = GM.evaluatedAltValue(r1, bs1[2], :Visib; registry = R1)
        @test a1.value === :hide && a1.source === :indirect && _an_id(a1.via) == _an_id(bs1[1])
        b2 = GM.RegistryBuilder(GM.DEFAULT_REGISTRY)
        b2.plugins[k] = _with_capture(b2.plugins[k], nothing)
        R2 = GM.publish(b2)
        r2 = GM.goMeta(_an_bytes("#~ hide\nx = 1\n"); registry = R2); @test r2.status === GM.PROCESS_OK
        @test !any(x -> x.attr === :visib, r2.altValues_evals.records)                 # no capture declaration: no Visib rows
        a2 = GM.evaluatedAltValue(r2, _AN_BLS.children(r2.blsComponentTree)[2], :Visib; registry = R2)
        @test a2.value === :show && a2.source === :default && a2.via === nothing       # the declared default
    end

    @testset "[A9] the Id compound: a NamedTuple of the recorded fields; the nearest statement's compound as a WHOLE" begin
        # MEASURED (the evals-tree printout of the two-level Id document)
        r = GM.goMeta(_an_bytes("#~ cell(7) parent(3)\nx = 1\n#~2 cell(9)\ny = 2\n")); ps = r.blsComponentTree
        bs = _AN_BLS.children(ps); @test length(bs) == 4
        a = GM.evaluatedAltValue(r, bs[1], :id); @test a.value == (cell = 7, parent = 3) && a.source === :own
        b = GM.evaluatedAltValue(r, bs[2], :id); @test b.value == (cell = 7, parent = 3) && b.source === :indirect && _an_id(b.via) == _an_id(bs[1])
        c = GM.evaluatedAltValue(r, bs[3], :id); @test c.value == (cell = 9,) && c.source === :own          # parent(3) NOT inherited across the depth — the per-field semantics deferred
        d = GM.evaluatedAltValue(r, bs[4], :id); @test d.value == (cell = 9,) && d.source === :indirect && _an_id(d.via) == _an_id(bs[3])
        z = GM.goMeta(_an_bytes("#~ cell(0) parent(5)\nx = 1\n"))
        za = GM.evaluatedAltValue(z, _AN_BLS.children(z.blsComponentTree)[1], :id); @test za.value == (parent = 5,) && za.source === :own   # a stated zero is not recorded (zero-versus-unset)
    end

    @testset "[A10] the `ids` action — the three fields at once, as the single actions set them (the creator's decision; MEASURED; the compound's FORM — the fields in alphabetical order)" begin
        r = GM.goMeta(_an_bytes("#~ ids(1, 2, 3)\nx = 1\n")); bs = _AN_BLS.children(r.blsComponentTree)
        a = GM.evaluatedAltValue(r, bs[1], :id); @test a.value == (cell = 1, file = 3, parent = 2) && a.source === :own   # the answer's compound names its fields alphabetically (MEASURED)
        b = GM.evaluatedAltValue(r, bs[2], :id); @test b.value == (cell = 1, file = 3, parent = 2) && b.source === :indirect && _an_id(b.via) == _an_id(bs[1])
        z = GM.goMeta(_an_bytes("#~ ids(0, 5, 2)\nx = 1\n"))                 # I02: the stated zero is not recorded (zero-versus-unset, OQ-15 untouched)
        za = GM.evaluatedAltValue(z, _AN_BLS.children(z.blsComponentTree)[1], :id); @test za.value == (file = 2, parent = 5) && za.source === :own
        o = GM.goMeta(_an_bytes("#~ ids(1, 2, 3) cell(7)\nx = 1\n"))           # I03: the later statement overwrites the field, as `cell(1) cell(7)` does
        oa = GM.evaluatedAltValue(o, _AN_BLS.children(o.blsComponentTree)[1], :id); @test oa.value == (cell = 7, file = 3, parent = 2) && oa.source === :own
    end

    @testset "[A7] the surface: package-public, NOT exported; the one method over the delivered object" begin
        @test Base.ispublic(GM, :evaluatedAltValue) && !Base.isexported(GM, :evaluatedAltValue)
        @test Base.ispublic(GM, :EvaluatedAltValue) && !Base.isexported(GM, :EvaluatedAltValue)
        @test hasmethod(GM.evaluatedAltValue, Tuple{GM.GoMetaDelivery, GM.BLS.Block, Symbol})
        @test fieldnames(GM.EvaluatedAltValue) == (:value, :source, :via)
    end
end
