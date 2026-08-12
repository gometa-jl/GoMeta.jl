# slot_overflow_tests.jl — the slot-overflow guarded-refusal witnesses
#
# IS:   the witness set for the slot-overflow guard (absorb_meta.jl, pre-increment).
# DOES: proves (1) the over-capacity action in ONE MH slot raises the STABLE typed refusal — an ErrorException (capacity = the action count, 8 since the step-9 heading registration)
#       carrying "slot action capacity" — never a raw BoundsError; (2) the
#       8-action boundary stays green (PROCESS_OK) and byte-deterministic (double-call identical);
#       (3) the cap discrimination is exact (8 ok / 9 refuses — re-pinned at step 9).
# REASONING: the guard's off-path must be invisible (≤cap inputs byte-exact — the corpus/golden layer
#       carries the broad evidence; the boundary leg pins the edge) and its on-path must be the
#       documented refusal (docs/public-api.md §3.4).
# PURPOSE: a stranger's dense metadata meets an explanatory, stable-message refusal — never a bare
#       BoundsError stack trace.

using Test
import GoMeta as GM

@testset "slot_overflow_guard" begin

    mk_input(n) = Vector{UInt8}(codeunits(
        join(["#~ hide{ :label1 }" for _ in 1:n], "\n") * "\n# content\n"))

    @testset "nine actions: the typed refusal (not BoundsError) — step-9 re-pin, capacity 7→8" begin
        err = try
            GM.goMeta(mk_input(9))
            nothing
        catch e
            e
        end
        @test err isa ErrorException
        @test !(err isa BoundsError)
        @test occursin("slot action capacity", err.msg)
        @test occursin("meta-hierarchy slot", err.msg)
    end

    @testset "eight actions: boundary green + deterministic — step-9 re-pin" begin
        r1 = GM.goMeta(mk_input(8))
        @test r1.status == GM.PROCESS_OK
        (tree1, render1) = GM.outputs(r1)
        r2 = GM.goMeta(mk_input(8))
        (tree2, render2) = GM.outputs(r2)
        @test tree1 == tree2
        @test render1 == render2
        @test !isempty(render1)
    end

    @testset "cap discrimination is exact" begin
        @test GM.goMeta(mk_input(8)).status == GM.PROCESS_OK
        @test (try GM.goMeta(mk_input(9)); false catch e; e isa ErrorException end)
    end
end
