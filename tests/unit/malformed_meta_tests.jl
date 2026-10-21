# malformed_meta_tests.jl — the valid-twin witnesses of the metaLine parser, and the glued form's refusal
#
# IS:   the witness set of the parser's valid shapes — they parse green and byte-deterministically — and of the one refusal a glued
#       token meets (the creator's decision of 2026-10-08).
# DOES: proves (1) a valid metaLine twin stays PROCESS_OK and byte-deterministic; (2) the INERT `#~!` corpus shape passes through
#       byte-exact; (3) the documented spacing form after a closing bracket stays green; (4) the glued form `hide{isCode}show` is
#       refused by the grammar's one refusal naming the character (the original engine dropped the `show` silently).
# REASONING: a metaStatement ENDS at white space or the region's end; any other character is named in the refusal.
#       The full battery of shapes is tests/unit/parser_quality_tests.jl (generated); these are the valid paths' pins.
# PURPOSE: the parser's valid shapes, byte-exact; the glued form, refused by name.
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

    @testset "the spaced form stays green; the glued form is refused by name" begin
        spaced = GM.goMeta(Vector{UInt8}(codeunits("#~ hide{isCode} show\n# content\n")))
        @test spaced.status == GM.PROCESS_OK
        e = try GM.goMeta(Vector{UInt8}(codeunits("#~ hide{isCode}show\n# content\n"))); nothing catch err; err end
        @test e isa ErrorException && occursin("unexpected character 's' after the metaStatement \"hide{isCode}\"", e.msg)
    end
end
