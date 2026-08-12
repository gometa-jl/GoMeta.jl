# tests/unit/public_surface_tests.jl — the public-surface introspection guard.
#
# IS:   the standing guard that GoMeta's PUBLIC surface is EXACTLY the declared one
#       (docs/public-api.md §1) and that the two OUTPUT surfaces (altValues_evals /
#       GoMeta.outputs) are the SOLE ways a consumer obtains output (the sole-surface invariant).
# DOES: (1) introspects the surface — `names(GoMeta)` (minus the module name) returns the
#       exported ∪ `public` names; the EXPORTED tier (via `Base.isexported`) must equal the FOUR
#       declared exports and the remaining tier (via `Base.ispublic`) must equal the ELEVEN declared
#       package-public names (no accidental leak, no gap, no silent demotion) — the
#       machine-checkable surface oracle; (2) asserts each supporting package-public name is
#       defined, `public`, and NOT exported (the controlled surface); (3) asserts the internal
#       `render_bytes` is NOT a public surface (reached ONLY via GoMeta.outputs); (4) FUNCTIONALLY
#       exercises the two output surfaces — GoMeta.outputs' tree+render (byte-exact to a pinned
#       corpus golden) and altValues_evals' typed per-cell map; (5) asserts the exported `goMeta`
#       generic carries exactly ONE method (the driver — a second method would mean an internal
#       generic silently merged into the public entry); (6) asserts no conformance-adapter binding
#       enters the top module (cross-implementation validation tooling is not part of the v0
#       native surface); (7) guards the hand-synced TWIN test environments (`test/Project.toml`
#       vs `tests/Project.toml`) for structural parity, so `Pkg.test()` and the direct
#       `--project=tests` invocation always resolve the SAME environment.
# REASONING: without a machine-checked export set, the declared semver API (docs/public-api.md)
#       drifts silently from the code; since Julia 1.11 `names(M)` returns the exported AND the
#       `public`-declared names, so the oracle partitions the live set with `Base.isexported` /
#       `Base.ispublic` and asserts EXACT set-equality per tier. The DECLARED_EXPORTS /
#       SUPPORTING_PUBLIC sets below MIRROR docs/public-api.md §1.1/§1.2 (the human-facing doc is
#       the same contract; this test is the code-side enforcement).
# PURPOSE: the public/export surface stays EXACTLY the declared one, and output flows only
#       through the two sanctioned surfaces.

using Test
import GoMeta as GM
import TOML

@testset "public_surface (sole-surface + the declared export set)" begin

    # The declared semver export set (docs/public-api.md §1.1).
    DECLARED_EXPORTS = Set([:goMeta, :altValues_evals, :GoMetaConfig, :GoMetaResult])
    # The supporting PACKAGE-PUBLIC surface (docs/public-api.md §1.2): documented + qualified-access, NOT exported.
    SUPPORTING_PUBLIC = [:outputs, :serialize_evals, :content_fingerprint, :EvalRecord, :EvalStore, :ProcessStatus, :PROCESS_OK,
                         :PROCESS_ERROR, :Diagnostic, :AlterantRegistry, :DEFAULT_REGISTRY]   # mirrors docs/public-api.md §1.2 EXACTLY

    @testset "export set is EXACTLY the declared semver surface" begin
        live = setdiff(Set(names(GM)), Set([:GoMeta]))     # names() on Julia ≥1.11 == exported ∪ `public` (+ the module name)
        exported = Set(filter(n -> Base.isexported(GM, n), collect(live)))
        @test exported == DECLARED_EXPORTS                        # [1] no accidental leak AND no gap (exact equality)
        @test setdiff(live, exported) == Set(SUPPORTING_PUBLIC)   # [1b] the `public` tier is EXACTLY the eleven declared names
        @test all(n -> Base.ispublic(GM, n), SUPPORTING_PUBLIC)   # [1c] every supporting name carries the `public` marking
        @test all(n -> !Base.isexported(GM, n), SUPPORTING_PUBLIC) # [1d] …and none is exported (the two-tier partition is real)
        for n in DECLARED_EXPORTS
            @test isdefined(GM, n)                                # [2] every exported name is a real binding
        end
        # the supporting types are package-public (defined) but NOT exported — checked DIRECTLY against the live
        # `exported` set, so a stray `export Diagnostic` reds even if DECLARED_EXPORTS were mis-edited in lockstep.
        for n in SUPPORTING_PUBLIC
            @test isdefined(GM, n)                                # [3a] documented package-public surface present…
            @test n ∉ exported                                   # [3b] …and NOT in the live export set (controlled surface)
        end
        @test isempty(intersect(Set(SUPPORTING_PUBLIC), exported))  # [4] none of the supporting names leaked into the LIVE export set
        # the INTERNAL render fn is reached ONLY via GoMeta.outputs — it is not part of the public `using` surface.
        @test :render_bytes ∉ exported                           # [5] render_bytes is package-internal, never exported
    end

    @testset "naming tooth (the methods tooth, armed at the dialect-convergence wave)" begin
        # The naming pre-condition: before/while `goMeta` is the pipeline entry,
        # pin the method inventory so a collision with the retired earlier driver family (or any
        # accidental extra method) fails LOUD instead of silently widening dispatch.
        @test length(methods(GM.goMeta)) == 1                    # [T1] exactly the pipeline entry
        @test GM.outputs isa Function && length(methods(GM.outputs)) >= 1  # [T3] the converged output surface is live
    end

    @testset "the two OUTPUT surfaces are the sole way to obtain output" begin
        # fixture: a meta-bearing member of the pinned byte_identical corpus (MANIFEST-driven, whole-file parse).
        fx = only(filter(f -> f["id"] == "file_for_Example_Proposal_JuliaCon.jl", TestSupport.corpus_fixtures()))
        input = read(joinpath(TestSupport.REPO, fx["input_path"]))
        r  = GM.goMeta(input)
        # surface 1 — outputs: tree + render bytes, the render byte-exact to the pinned corpus golden.
        co = GM.outputs(r)
        @test !isempty(co.blsStructure_bytes)                            # [6a] tree half via outputs
        @test !isempty(co.render_bytes)                          # [6b] render half via outputs
        @test co.render_bytes == read(joinpath(TestSupport.REPO, fx["render_golden_path"]))   # [7] the SOLE render surface, byte-exact
        # the production surface — altValues_evals: the typed per-cell map of evaluated Alterant values (the DB-interface payload). The fixture is
        # meta-bearing, so [8b] asserts the surface is FUNCTIONALLY populated (the type-only [8a] would hold even
        # for an empty result); [8c] is a per-row content guard (non-empty cell_handle + a present verdict value).
        ann = GM.altValues_evals(r)
        @test ann isa Vector{Tuple{Vector{UInt8},Symbol,Any,Bool}}    # [8a] altValues_evals is the pinned typed surface
        @test !isempty(ann)                                           # [8b] …and is functionally populated (the fixture has verdicts)
        @test all(t -> !isempty(t[1]) && t[3] !== nothing, ann)       # [8c] each row: non-empty cell_handle + present verdict value (the [8a] type-pin already guarantees the Symbol attr + Bool polarity slots)
        ser = String(GM.serialize_evals(ann))
        @test first(split(ser, '\n')) == "# annotations golden — sorted (cell_handle, attr, value); final-verdicts-only."   # [8d] the serializer + its layout-stable header line, byte-pinned in-suite
    end

    @testset "surface oracle: an out-of-surface implementation name is NOT bound in the top module" begin
        # The standing oracle for the v0 public surface: a name OUTSIDE the declared surface must
        # not be a binding in the top module (⇒ a fortiori it cannot be exported either, so a separate
        # `∉ exported` assertion would be implied by [1]). The single load-bearing check below reds the
        # moment a future edit binds this name — any module addition must consciously update the oracle.
        @test !isdefined(GM, :OtherImpl)                         # [9] the name is not bound in the top module
    end

    @testset "env_twin (test/ and tests/ resolve the same environment)" begin
        # the TWO test environments are kept in sync BY HAND (`test/Project.toml` = the Pkg.test entry
        # convention — Julia hardcodes the singular path; `tests/Project.toml` = the suite's own env);
        # silent drift would make Pkg.test() resolve a DIFFERENT environment than the direct invocation.
        # The env-defining sections must parse IDENTICAL (header comments legitimately differ).
        root = normpath(joinpath(@__DIR__, "..", ".."))
        a = TOML.parsefile(joinpath(root, "test", "Project.toml"))
        b = TOML.parsefile(joinpath(root, "tests", "Project.toml"))
        for section in ("deps", "compat", "sources")
            @test get(a, section, nothing) == get(b, section, nothing)   # the env-defining twins
        end
        @test isfile(joinpath(root, "test", "runtests.jl"))   # the Pkg.test entry shim exists
    end
end
