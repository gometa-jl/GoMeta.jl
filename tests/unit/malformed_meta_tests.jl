# malformed_meta_tests.jl — the valid-twin witnesses of the metaLine parser (the three guarded refusals of malformed
# metaLines — the no-token guard, the punctuation wall, the glued-token wall — left at stage 5's E7 of the v0.4 build, census row 41)
#
# IS:   the witness set that stays after E7: the valid shapes parse green and byte-deterministically.
# DOES: proves (1) a valid metaLine twin stays PROCESS_OK and byte-deterministic; (2) the INERT `#~!` corpus shape passes
#       through byte-exact; (3) the documented spacing form after a closing bracket stays green.
# REASONING: since stage 5's E7 a malformed metaLine is read as his legacy read it — stray punctuation skipped to the next identifier, a glued token
#       dropped, an empty meta region Julia's own BoundsError — measured in the build's probe pair, not pinned here (census row 41):
#       a raw Julia error class is no witness; the valid paths are the pins.
# PURPOSE: the parser's valid shapes, byte-exact.
using Test
import GoMeta as GM

@testset "malformed_meta_valid_twins" begin

    @testset "valid twin: green + deterministic" begin
        valid = Vector{UInt8}(codeunits("#~ hide{ :label1 }\n# content\n"))
        r1 = GM.goMeta(valid)
        @test r1.status == GM.PROCESS_OK
        (t1, o1) = Main.BasicRenderer.outputs(r1)
        (t2, o2) = Main.BasicRenderer.outputs(GM.goMeta(valid))
        @test t1 == t2
        @test o1 == o2
    end

    @testset "the inert #~! shape passes through byte-exact" begin
        inert = Vector{UInt8}(codeunits("#~! discard{ isMeta }\n# content\n"))
        r = GM.goMeta(inert)
        @test r.status == GM.PROCESS_OK
        @test String(copy(Main.BasicRenderer.outputs(r)[2])) == "#~! discard{ isMeta }\n# content\n"   # the inert line passes through byte-exact
    end

    @testset "the spaced form stays green (the former walls left at stage 5's E7 — census row 41)" begin
        # the documented spacing form after a closing bracket; the glued form is read as the legacy read it since stage 5's E7 (the glued token
        # dropped — measured in the build's probe pair, not pinned here; census row 41)
        spaced = GM.goMeta(Vector{UInt8}(codeunits("#~ hide{isCode} show\n# content\n")))
        @test spaced.status == GM.PROCESS_OK
    end
end
