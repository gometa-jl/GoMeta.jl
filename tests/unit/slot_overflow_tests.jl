# slot_overflow_tests.jl — the per-slot capacity witnesses: the BOUNDARY and the BOUND
#
# IS:   the witness set of the queue tensor's width: as many actions in ONE meta-hierarchy slot as the queue tensor holds
#       (size(queued, 2) = SLOT_CAPACITY, 8 — a named constant DECOUPLED from the registered action count since stage 3 of the Alterants build,
#       R-ALT-31; the registered count is 9 with the `ids` action) stay green; the ninth meets
#       GoMeta's message (the metaLine parser effort, stage 5's s5c29; his Decision 3 of 2026-10-08, OWNER-WORDS §358).
# DOES: proves (1) the 8-action boundary stays PROCESS_OK and byte-deterministic (double-call identical); (2) a ninth action in the
#       same slot meets "GoMeta absorb: more than 8 actions in one meta-hierarchy slot" — the stable message, not Julia's BoundsError.
# REASONING: his word — the current slot limit is a hard-coded starting size, raised by hand if the examples need it; a dedicated error
#       message is sufficient for now; the slower overflow buffer is a later design (V05-14).
# PURPOSE: the queue tensor's width, exercised at its edge and one past it.
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

    @testset "nine actions: the ninth meets GoMeta's message before the write (his Decision 3, §358)" begin
        e = try GM.goMeta(mk_input(9)); nothing catch err; err end
        @test e isa ErrorException
        @test occursin("more than 8 actions in one meta-hierarchy slot", e.msg)
        @test occursin("GoMeta absorb:", e.msg)
    end
end
