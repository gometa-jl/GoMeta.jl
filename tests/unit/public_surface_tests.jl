# tests/unit/public_surface_tests.jl — the public-surface introspection guard.
#
# IS:   the standing guard that GoMeta's PUBLIC surface is EXACTLY the declared one
#       (docs/public-api.md §1), and the three clauses of R-V04B-24 (2026-09-12) — in the row's own words:
#       (i) "the package's canonical observable output = `altValues_evals` (+ `serialize_evals`,
#       `content_fingerprint`)" and "the Engine's delivered surface after the move = the run and the
#       evaluated values"; (ii) the (tree, render) pair is the development tool's and is obtained ONLY
#       through `Main.BasicRenderer.outputs` loaded by the one loader (checked mechanically below);
#       (iii) the test layer pins that pair byte-exact against the corpus golden.
# DOES: (1) introspects the surface — `names(GoMeta)` (minus the module name) returns the
#       exported ∪ `public` names; the EXPORTED tier (via `Base.isexported`) must equal the FOUR
#       declared exports and the remaining tier (via `Base.ispublic`) must equal the declared
#       package-public names (11 at v0.3.2; 36 since v0.4 T2 — the lifecycle + the record vocabulary;
#       37 since the v0.4 `Alterant` rename — the canonical name beside the `PlugIn` alias;
#       no accidental leak, no gap, no silent demotion) — the
#       machine-checkable surface oracle; (2) asserts each supporting package-public name is
#       defined, `public`, and NOT exported (the controlled surface); (3) asserts the internal
#       `render_bytes` is not an exported name (the renderer left the Engine); (4) FUNCTIONALLY
#       exercises the Engine's output surface (altValues_evals' typed per-cell map, serialize_evals) and
#       the development tool's pair (byte-exact to a pinned corpus golden); (5) asserts the exported `goMeta`
#       generic carries exactly ONE method (the driver — a second method would mean an internal
#       generic silently merged into the public entry); (6) asserts no conformance-adapter binding
#       enters the top module (cross-implementation validation tooling is not part of the v0
#       native surface); (7) guards the hand-synced TWIN test environments (`test/Project.toml`
#       vs `tests/Project.toml`) for structural parity, so `Pkg.test()` and the direct
#       `--project=tests` invocation always resolve the SAME environment; (8) the one-path assertions
#       (R-V04B-24 obligation 7): the basic renderer is loaded once, as Main.BasicRenderer, from
#       devtools/basic_renderer.jl, through devtools/load_basic_renderer.jl.
# REASONING: without a machine-checked export set, the declared semver API (docs/public-api.md)
#       drifts silently from the code; since Julia 1.11 `names(M)` returns the exported AND the
#       `public`-declared names, so the oracle partitions the live set with `Base.isexported` /
#       `Base.ispublic` and asserts EXACT set-equality per tier. The DECLARED_EXPORTS /
#       SUPPORTING_PUBLIC sets below MIRROR docs/public-api.md §1.1/§1.2 (the human-facing doc is
#       the same contract; this test is the code-side enforcement).
# PURPOSE: the public/export surface stays EXACTLY the declared one; the Engine's output is
#       `altValues_evals` (+ `serialize_evals`, `content_fingerprint`); the (tree, render) pair is the
#       development tool's, reached only through `Main.BasicRenderer.outputs` (the one-path assertions).

using Test
import GoMeta as GM
import TOML

@testset "public_surface (the Engine's surface, the tool's pair + the declared export set)" begin

    # The declared semver export set (docs/public-api.md §1.1).
    DECLARED_EXPORTS = Set([:goMeta, :readAltValuesEvals, :GoMetaConfig, :GoMetaResult])
    # The supporting PACKAGE-PUBLIC surface (docs/public-api.md §1.2): documented + qualified-access, NOT exported.
    SUPPORTING_PUBLIC = [:serialize_evals, :content_fingerprint, :EvalRecord, :EvalStore, :ProcessStatus, :PROCESS_OK,
                         :PROCESS_ERROR, :Diagnostic, :AlterantRegistry, :DEFAULT_REGISTRY,
                         # v0.4 T2 — the registration LIFECYCLE surface (Builder → validate → publish; the
                         # typed refusal) + (cure batch 1) the record VOCABULARY a third-party author
                         # constructs: 11 → 36 package-public names (a registered widening — the
                         # sanctioned registration surface IS the intended Extension-facing seam);
                         # 36 → 37 at the v0.4 `Alterant` rename (R-V04B-5): the canonical record
                         # name beside the `PlugIn` 0.4.x deprecation alias.
                         # 37 → 40 at v0.4 T4: the G-VOC query triple — the ONE vocabulary
                         # read surface the three planes share (T4-DESIGN §4);
                         # 40 → 39 at R-V04B-24 (2026-09-12): `outputs` REMOVED with the basic renderer
                         # (a development tool; the register row in docs/public-api.md §6).
                         :RegistryBuilder, :register!, :next_plugin_index, :validate, :publish, :RegistrationRefused,
                         :Alterant, :PlugIn, :ActionSpec, :ActionOverload, :DomainRef, :CaptureDecl, :DefaultSlot,
                         :NoDefault, :Declared, :EffectRow, :RenderDecl, :VocabularySlot,
                         :InlineVocabulary, :VocabularyRef, :MutEx, :ConditionAtom, :SugarRow,
                         :Provenance, :SignatureRecord, :PermissionManifest,
                         :vocabulary, :vocabulary_member, :vocabulary_queryable]   # mirrors docs/public-api.md §1.2 EXACTLY

    @testset "export set is EXACTLY the declared semver surface" begin
        live = setdiff(Set(names(GM)), Set([:GoMeta]))     # names() on Julia ≥1.11 == exported ∪ `public` (+ the module name)
        exported = Set(filter(n -> Base.isexported(GM, n), collect(live)))
        @test exported == DECLARED_EXPORTS                        # [1] no accidental leak AND no gap (exact equality)
        @test setdiff(live, exported) == Set(SUPPORTING_PUBLIC)   # [1b] the `public` tier is EXACTLY the declared names (39 since R-V04B-24; 40 before)
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
        # `render_bytes` is the development tool's function (devtools/basic_renderer.jl), never an exported name of the Engine.
        @test :render_bytes ∉ exported                           # [5] render_bytes is never an exported name
    end

    @testset "naming tooth (the methods tooth, armed at the dialect-convergence wave)" begin
        # The naming pre-condition: before/while `goMeta` is the pipeline entry,
        # pin the method inventory so a collision with the retired earlier driver family (or any
        # accidental extra method) fails LOUD instead of silently widening dispatch.
        @test length(methods(GM.goMeta)) == 1                    # [T1] exactly the pipeline entry
        @test Main.BasicRenderer.outputs isa Function && length(methods(Main.BasicRenderer.outputs)) >= 1  # [T3] the development tool's pair is live (re-pointed at R-V04B-24; never deleted)
        # the one-path assertions (R-V04B-24 obligation 7) — the SENTINEL is the gate against a second
        # copy of the module in another namespace; the method check alone is not.
        @test isdefined(Main, :BasicRenderer)                    # [T4] the module lives in Main
        @test isdefined(Main, :_BASIC_RENDERER_LOADED)           # [T5] the load sentinel: a second load through ANY path throws
        let m = only(methods(Main.BasicRenderer.outputs))       # `only` fails loudly on 0 or ≥2
            @test parentmodule(m) === Main.BasicRenderer         # [T6] defined in the module the loader lands
            @test String(m.file) == joinpath(pkgdir(GM), "devtools", "basic_renderer.jl")   # [T7] from the one file (GM = this file's alias)
        end
    end

    @testset "the Engine's output surface and the development tool's pair (the three clauses)" begin
        # fixture: a meta-bearing member of the pinned byte_identical corpus (MANIFEST-driven, whole-file parse).
        fx = only(filter(f -> f["id"] == "file_for_Example_Proposal_JuliaCon.jl", TestSupport.corpus_fixtures()))
        input = read(joinpath(TestSupport.REPO, fx["input_path"]))
        r  = GM.goMeta(input)
        # the development tool's pair — byte-exact to the pinned corpus golden (the test layer's property).
        co = Main.BasicRenderer.outputs(r)
        @test !isempty(co.blsStructure_bytes)                            # [6a] tree half via the tool's outputs
        @test !isempty(co.render_bytes)                          # [6b] render half via the tool's outputs
        @test co.render_bytes == read(joinpath(TestSupport.REPO, fx["render_golden_path"]))   # [7] the tool's render, byte-exact to the corpus golden
        # the Engine's surface — altValues_evals: the typed per-cell map of evaluated Alterant values (the DB-interface payload). The fixture is
        # meta-bearing, so [8b] asserts the surface is FUNCTIONALLY populated (the type-only [8a] would hold even
        # for an empty result); [8c] is a per-row content guard (non-empty cell_handle + a present verdict value).
        ann = GM.readAltValuesEvals(r)
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
