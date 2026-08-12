# tests/unit/carrier_seam_tests.jl — WP1-W2: the callable driver seam + the
# carrier-state checker witnesses (SYNTHESIS-JUDGE §3 row WP1-W2; APPEND-ONLY).
#
# Covers: the seam-vs-goMeta identity (the first-consumer proof, both armed flavors,
# all three result surfaces); the meta-free contract row (PROCESS_OK + zero rows —
# the E-05 class); the surface discipline (package-public, NOT exported — names()
# byte-stable); validate_carrier_state — clean on real stores (both flavors) +
# detects EACH planted breach class (introducer law via a shifted slice start; store
# coherence via a corrupted child id; flag invariant via cleared depth flags).

using Test
import GoMeta as GM
const _CS_BLS = GM.BLS

_cs_bytes(s::String) = Vector{UInt8}(codeunits(s))

## The first meta-flagged (:hasMetaStr) Line component reachable from the File root
## (the checker's own traversal order), for the planted-breach witnesses.
function _cs_first_meta_line(ps)
    fileC = ps.componentsPDict[_CS_BLS.File][1][1]
    for blockId in _CS_BLS.eachchildid(fileC, ps.componentsPDict[_CS_BLS.File][1])
        blockC = ps.componentsPDict[_CS_BLS.Block][1][blockId]
        for lineId in _CS_BLS.eachchildid(blockC, ps.componentsPDict[_CS_BLS.Block][1])
            lineC = ps.componentsPDict[_CS_BLS.Line][1][lineId]
            if _CS_BLS.getElement(lineC.componentSettribute, :hasMetaStr)
                return lineC
            end
        end
    end
    return nothing
end

@testset "carrier_seam_tests (WP1-W2 seam + checker)" begin

    @testset "[1] seam-vs-goMeta identity (the first-consumer proof, both flavors)" begin
        for (tag, src) in ((:julia, "#~ hide\nx = 1\n#~2 :label1\ny = 2\n"),
                           (:c,     "//~ hide\nint x;\n"))
            cfg = GM.GoMetaConfig(flavor_tag = tag)
            r_go = GM.goMeta(_cs_bytes(src); config = cfg)
            ## the manual pipeline an adapter rides: setup → parse → seam
            ps = _CS_BLS.setUpToProcessFromBytes(_cs_bytes(src);
                flavor = _CS_BLS.flavor_for(tag))
            ## F-21 (WP1-W4): ONE loop for every flavor — the per-flavor copy the
            ## original branch named is deleted; the record carries the divergence.
            _CS_BLS.parseBLS(ps, 1, -1)
            r_seam = GM.run_absorb_apply!(ps; config = cfg)
            @test r_seam.status === r_go.status
            @test GM.outputs(r_seam) == GM.outputs(r_go)
            @test GM.serialize_evals(r_seam) == GM.serialize_evals(r_go)
        end
    end

    @testset "[2] the meta-free contract row (PROCESS_OK, zero rows — the E-05 class)" begin
        ps = _CS_BLS.setUpToProcessFromBytes(_cs_bytes("plain = 1\n# note\n"))
        _CS_BLS.parseBLS(ps, 1, -1)
        r = GM.run_absorb_apply!(ps)
        @test r.status === GM.PROCESS_OK
        @test isempty(GM.altValues_evals(r))
    end

    @testset "[3] surface discipline (package-public, NOT exported)" begin
        @test :run_absorb_apply! ∉ names(GM)
        @test :validate_carrier_state ∉ names(GM)
        @test isdefined(GM, :run_absorb_apply!)
        @test isdefined(GM, :validate_carrier_state)
    end

    @testset "[4] validate_carrier_state: clean on real stores; detects each planted breach" begin
        for (tag, src) in ((:julia, "#~ hide\nx = 1\n"), (:c, "//~ hide\nint x;\n"))
            r = GM.goMeta(_cs_bytes(src); config = GM.GoMetaConfig(flavor_tag = tag))
            @test isempty(GM.validate_carrier_state(r.state.parse))
        end
        ## breach A — the introducer law: shift the metaLine slice's start byte so it
        ## no longer begins at the lead.
        ps_a = GM.goMeta(_cs_bytes("#~ hide\nx = 1\n")).state.parse
        ml_a = _cs_first_meta_line(ps_a)
        @test ml_a !== nothing
        _CS_BLS.setElement(ml_a.cmpntNamedInt,
            :startMainStr => _CS_BLS.getElement(ml_a.cmpntNamedInt, :startMainStr) + 1)
        @test any(contains("introducer law"), GM.validate_carrier_state(ps_a))
        ## breach B — store coherence: corrupt the File root's first child id.
        ps_b = GM.goMeta(_cs_bytes("#~ hide\nx = 1\n")).state.parse
        ps_b.componentsPDict[_CS_BLS.File][1][1].childComponentsIdxVec[1] = 99999
        @test any(contains("store coherence"), GM.validate_carrier_state(ps_b))
        ## breach C — the flag invariant: clear the metaLine's depth flags (leaving a
        ## Meta-typed component with neither :depthN nor :ignoreThisMeta).
        ps_c = GM.goMeta(_cs_bytes("#~ hide\nx = 1\n")).state.parse
        ml_c = _cs_first_meta_line(ps_c)
        @test ml_c !== nothing
        for i in 0:9
            _CS_BLS.setElementToFalseIfTrue(ml_c.componentSettribute, Symbol("depth", i))
        end
        @test any(contains("flag invariant"), GM.validate_carrier_state(ps_c))
        ## breach D — a corrupted :idExtension link REPORTS, never throws (the W2
        ## round-1 panel's convergent MAJOR: the shared iterator would BoundsError
        ## here; the checker's guarded chain-walk must report instead). The File
        ## root's child vector is FILLED so the chain-follow lane is actually
        ## reached (a 0 entry short-circuits it).
        ps_d = GM.goMeta(_cs_bytes("#~ hide\nx = 1\n")).state.parse
        f_d = ps_d.componentsPDict[_CS_BLS.File][1][1]
        fill!(f_d.childComponentsIdxVec, 1)
        _CS_BLS.setElement(f_d.cmpntNamedInt, :idExtension => 99999)
        iss_d = GM.validate_carrier_state(ps_d)
        @test any(contains("extension id"), iss_d)
        ## breach E — a CYCLIC extension chain REPORTS, never hangs (the step cap:
        ## a chain longer than its store must revisit a slot). idExtension = 1
        ## points the File root's chain at itself.
        ps_e = GM.goMeta(_cs_bytes("#~ hide\nx = 1\n")).state.parse
        f_e = ps_e.componentsPDict[_CS_BLS.File][1][1]
        fill!(f_e.childComponentsIdxVec, 1)
        _CS_BLS.setElement(f_e.cmpntNamedInt, :idExtension => 1)
        iss_e = GM.validate_carrier_state(ps_e)
        @test any(contains("cycle or runaway"), iss_e)
    end
end
