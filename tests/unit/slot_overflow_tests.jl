# slot_overflow_tests.jl — the per-slot capacity BOUNDARY witnesses (the pre-increment capacity guard left at stage 5's E7 of the
# v0.4 build, census row 41 — its message was "GoMeta absorb: slot action capacity")
#
# IS:   the witness set that stays after E7: the boundary — as many actions in ONE meta-hierarchy slot as the queue tensor holds
#       (size(queued, 2) = the registered action count, 8 since the heading action's registration) — stays green.
# DOES: proves the 8-action boundary stays PROCESS_OK and byte-deterministic (double-call identical).
# REASONING: a further action meets Julia's own BoundsError at the enqueue write since E7 (the plain Array is bounds-checked) —
#       measured in the build's probe pair, not pinned here (a raw Julia error class is no witness); the boundary is the pin.
# PURPOSE: the queue tensor's width, exercised at its edge.
using Test
import GoMeta as GM

@testset "slot_capacity_boundary" begin

    mk_input(n) = Vector{UInt8}(codeunits(
        join(["#~ hide{ :label1 }" for _ in 1:n], "\n") * "\n# content\n"))

    @testset "eight actions: boundary green + deterministic — step-9 re-pin" begin
        r1 = GM.goMeta(mk_input(8))
        @test r1.status == GM.PROCESS_OK
        (tree1, render1) = Main.BasicRenderer.outputs(r1)
        r2 = GM.goMeta(mk_input(8))
        (tree2, render2) = Main.BasicRenderer.outputs(r2)
        @test tree1 == tree2
        @test render1 == render2
        @test !isempty(render1)
    end
end
