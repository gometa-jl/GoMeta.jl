# malformed_meta_tests.jl — the malformed-metaLine guarded-refusal witnesses
#
# IS:   the witness set for the malformed-metaLine guard (parseAlt's no-token refusal in src/absorb/absorb_meta.jl).
# DOES: proves (1) both malformed shapes raise the STABLE typed refusal — ErrorException
#       carrying "malformed metaLine" — never a raw BoundsError; (2) a valid metaLine twin
#       stays PROCESS_OK and byte-deterministic; (3) the INERT `#~!` corpus shape is untouched by the
#       guard (the guard-placement constraint: no shape validation before the token search).
# REASONING: the guard refuses exactly the no-token class,
#       so every valid path — including `#~!`, which the corpus exercises — is byte-exact unchanged.
# PURPOSE: a stranger's typo in a metaLine meets an explanatory refusal naming the offending region,
#       never a bare BoundsError stack trace.

using Test
import GoMeta as GM

@testset "malformed_meta_guard" begin

    @testset "both malformed shapes: the typed refusal (not BoundsError)" begin
        for s in ("#~ ,\n", "#~3 (\n")
            err = try
                GM.goMeta(Vector{UInt8}(codeunits(s)))
                nothing
            catch e
                e
            end
            @test err isa ErrorException
            @test !(err isa BoundsError)
            @test occursin("malformed metaLine", err.msg)
        end
    end

    @testset "valid twin: green + deterministic" begin
        valid = Vector{UInt8}(codeunits("#~ hide{ :label1 }\n# content\n"))
        r1 = GM.goMeta(valid)
        @test r1.status == GM.PROCESS_OK
        (t1, o1) = GM.outputs(r1)
        (t2, o2) = GM.outputs(GM.goMeta(valid))
        @test t1 == t2
        @test o1 == o2
    end

    @testset "the inert #~! shape is untouched by the guard" begin
        inert = Vector{UInt8}(codeunits("#~! discard{ isMeta }\n# content\n"))
        r = GM.goMeta(inert)
        @test r.status == GM.PROCESS_OK
        @test String(copy(GM.outputs(r)[2])) == "#~! discard{ isMeta }\n# content\n"   # the inert line passes through byte-exact
    end

    @testset "strict token boundaries: punctuation at action position + glued tokens refuse" begin
        # punctuation at the action-name position refuses — the parser never skips ahead to the next identifier
        for s in ("#~ , discard\n# content\n", "#~ ! discard\n# content\n")
            err = try
                GM.goMeta(Vector{UInt8}(codeunits(s)))
                nothing
            catch e
                e
            end
            @test err isa ErrorException
            @test occursin("malformed metaLine", err.msg)
            @test occursin("unexpected punctuation", err.msg)
        end
        # a closing ')' or '}' must be followed by end-of-input or whitespace — glued tokens refuse
        for s in ("#~ hide()junk\n# content\n", "#~ hide{isCode}show\n# content\n")
            err = try
                GM.goMeta(Vector{UInt8}(codeunits(s)))
                nothing
            catch e
                e
            end
            @test err isa ErrorException
            @test occursin("malformed metaLine", err.msg)
            @test occursin("glued token", err.msg)
        end
        # the whitespace-separated twin stays green (the documented spacing form)
        spaced = GM.goMeta(Vector{UInt8}(codeunits("#~ hide{isCode} show\n# content\n")))
        @test spaced.status == GM.PROCESS_OK
    end
end
