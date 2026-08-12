# error_message_tests.jl — stable-message witnesses for GoMeta.goMeta errors.
#
# IS:   witnesses for the stabilized error messages that a plain input can trigger.
# DOES: proves those messages carry their stable substrings on real triggers. The deep-state
#       loci (duplicate-conditions, condition-key family) and the internal-invariant messages
#       ship unwitnessed here, as does the unknown-action message.
# REASONING: the spaced `#~ : x` form is rejected at the argument guard before label handling,
#       so the unspaced form is the true label path exercised below.
# PURPOSE: no bare stack traces — every user-triggerable failure names what went wrong.

using Test
import GoMeta as GM

@testset "error_message_stables" begin

    _err(s) = try
        GM.goMeta(Vector{UInt8}(codeunits(s)))
        nothing
    catch e
        e
    end

    @testset "unknown label → the apply-stage whitelist message" begin
        err = _err("#~ :zznotalabel\n# content\n")
        @test err isa ErrorException
        @test occursin("unknown label", err.msg)
        @test occursin("zznotalabel", err.msg)
    end

    @testset "duplicate argument list → the absorb-stage message" begin
        err = _err("#~ hide(a)(b)\n# content\n")
        @test err isa ErrorException
        @test occursin("duplicate argument list", err.msg)
    end

    @testset "unknown label queried in a CONDITION → the same whitelist message (both roles refuse where the query is consulted)" begin
        err = _err("#~ :label1 hide{ :zznotalabel }\n# content\n")
        @test err isa ErrorException
        @test occursin("unknown label", err.msg)
        @test occursin("zznotalabel", err.msg)
    end
end
