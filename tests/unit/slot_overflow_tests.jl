# slot_overflow_tests.jl — the per-slot capacity witnesses: the BOUNDARY and the BOUND
#
# IS:   the witness set of the queue tensor's width: as many actions in ONE meta-hierarchy slot as the queue tensor holds
#       (size(queued, 2) = SLOT_CAPACITY, 8 — a named constant DECOUPLED from the registered action count since stage 3 of the Alterants build,
#       R-ALT-31; the registered count is 9 with the `ids` action) stay green; the ninth meets
#       GoMeta's message (the metaLine parser effort, stage 5's s5c29; his Decision 3 of 2026-10-08, OWNER-WORDS §358).
# DOES: proves (1) the 8-action boundary stays PROCESS_OK and byte-deterministic (double-call identical); (2) a ninth action in the
#       same slot meets "GoMeta absorb: more than 8 actions in one meta-hierarchy slot" — the stable message, not Julia's BoundsError.
#       (3) THE CAPACITY IS EIGHT FOR EVERY REGISTRY (his R-ALT-36 of 2026-10-17): a custom registry of 4 actions admits five and eight
#       statements in one slot — where the base 63ffff7 refused the fifth at its registered count — and refuses the ninth; an extended
#       registry of 11 admits eight and refuses the ninth — where the base admitted up to its count (MEASURED on both trees by the lane's
#       instruments/probe-custom-registry.jl: plan/2026-10-15-gometa-alterants-build/receipts/stage3/PROBE-custom-registry_*.txt).
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

    @testset "[C] the capacity is EIGHT for EVERY registry — a custom registry of 4 actions and an extended one of 11 (his R-ALT-36 of 2026-10-17; MEASURED by the lane's probe on the base 63ffff7 and the landed eecac0f)" begin
        R = GM.DEFAULT_REGISTRY
        bK = GM.RegistryBuilder()                                  # K: the shipped Labels and Visib alone — 4 actions
        GM.register!(bK, R.plugins[1], GM.ActionSpec(; name = Symbol(":"), plugin = Int8(1)))
        GM.register!(bK, R.plugins[2], GM.ActionSpec(; name = :hide, plugin = Int8(2)), GM.ActionSpec(; name = :show, plugin = Int8(2)), GM.ActionSpec(; name = :discard, plugin = Int8(2)))
        RK = GM.publish(bK)
        @test GM.num_alt_actions(RK) == 4
        bX = GM.RegistryBuilder(R); pX = GM.next_plugin_index(bX)   # X: DEFAULT + one Extension Alterant with two actions — 11
        GM.register!(bX, GM.Alterant(; altName = :ext, setMode = :mutExclusive, altConstructor = GM.Alterants.Visib, setAltInstance = GM.Alterants.setVisib),
                     GM.ActionSpec(; name = :ext1, plugin = Int8(pX)), GM.ActionSpec(; name = :ext2, plugin = Int8(pX)))
        RX = GM.publish(bX)
        @test GM.num_alt_actions(RX) == 11
        doc(s) = Vector{UInt8}(codeunits("#~ " * s * "\nx = 1\n"))
        # K: five and eight statements in one slot ADMITTED (the base, sized by the count 4, refused the fifth: PROBE K5); the ninth refused
        @test GM.goMeta(doc("hide show discard :label1 :label2"); registry = RK).status == GM.PROCESS_OK
        @test GM.goMeta(doc("hide show discard :label1 :label2 hide show discard"); registry = RK).status == GM.PROCESS_OK
        eK = try GM.goMeta(doc("hide show discard :label1 :label2 hide show discard :doc"); registry = RK); nothing catch err; err end
        @test eK isa ErrorException && occursin("more than 8 actions in one meta-hierarchy slot", eK.msg)
        # X: eight admitted, the ninth REFUSED (the base, sized by its count — 10 before `ids` — admitted the ninth: PROBE X9)
        @test GM.goMeta(doc("hide show discard cell(1) parent(2) file(3) :label1 :label2"); registry = RX).status == GM.PROCESS_OK
        eX = try GM.goMeta(doc("hide show discard cell(1) parent(2) file(3) :label1 :label2 :doc"); registry = RX); nothing catch err; err end
        @test eX isa ErrorException && occursin("more than 8 actions in one meta-hierarchy slot", eX.msg)
    end
end
