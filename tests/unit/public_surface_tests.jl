# tests/unit/public_surface_tests.jl — the public-surface introspection guard.
#
# IS:   the standing guard that GoMeta's PUBLIC surface is EXACTLY the declared one
#       (docs/public-api.md §1), and the three clauses of the creator's decision of 2026-09-12 — in its own words:
#       (i) "the package's canonical observable output = `altValues_evals` (+ `serialize_evals`,
#       `content_fingerprint`)" and "the Engine's delivered surface after the move = the run and the
#       evaluated values"; (ii) the (tree, render) pair is the development tool's and is obtained ONLY
#       through `Main.BasicRenderer.outputs` loaded by the one loader (checked mechanically below);
#       (iii) the test layer pins that pair byte-exact against the corpus golden.
# DOES: (1) introspects the surface — `names(GoMeta)` (minus the module name) returns the
#       exported ∪ `public` names; the EXPORTED tier (via `Base.isexported`) must equal the FOUR
#       declared exports and the remaining tier (via `Base.ispublic`) must equal the declared
#       package-public names (27 — the history of the count in docs/public-api.md §6;
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
#       — the basic renderer is loaded once, as Main.BasicRenderer, from
#       devtools/basic_renderer.jl, through devtools/load_basic_renderer.jl.
# REASONING: without a machine-checked export set, the declared semver API (docs/public-api.md)
#       drifts silently from the code; since Julia 1.11 `names(M)` returns the exported AND the
#       `public`-declared names, so the oracle partitions the live set with `Base.isexported` /
#       `Base.ispublic` and asserts EXACT set-equality per tier. The DECLARED_EXPORTS /
#       SUPPORTING_PUBLIC sets below MIRROR docs/public-api.md §1.1/§1.2 (the human-facing doc is
#       the same contract; this test is the code-side enforcement).
# PURPOSE: the public/export surface stays EXACTLY the declared one; the Engine's output is
#       `altValues_evals` (+ `serialize_evals`; `content_fingerprint` removed within the 0.4 development); the (tree, render) pair is the
#       development tool's, reached only through `Main.BasicRenderer.outputs` (the one-path assertions).

using Test
import GoMeta as GM
import TOML

@testset "public_surface (the Engine's surface, the tool's pair + the declared export set)" begin

    # The declared semver export set (docs/public-api.md §1.1).
    DECLARED_EXPORTS = Set([:goMeta, :readAltValuesEvals, :GoMetaConfig, :GoMetaDelivery])
    # The supporting PACKAGE-PUBLIC surface (docs/public-api.md §1.2): documented + qualified-access, NOT exported.
    SUPPORTING_PUBLIC = [:serialize_evals, :EvalRecord, :EvalStore, :ProcessStatus, :PROCESS_OK,
                         :PROCESS_ERROR, :Diagnostic, :AlterantRegistry, :DEFAULT_REGISTRY,
                         # the registration LIFECYCLE (Builder → validate → publish; the coded refusal) and the record VOCABULARY a
                         # third-party author constructs — the sanctioned Extension-facing seam
                         :RegistryBuilder, :register!, :next_plugin_index, :validate, :publish, :RegistrationRefused,
                         :Alterant, :ActionSpec, :CaptureDecl, :DefaultSlot, :NoDefault, :Declared,
                         :BLS,   # the parser module, public by name — its door inside it
                         :evaluatedAltValue, :EvaluatedAltValue,   # THE ONE ANSWER FUNCTION and its record
                         :scanAlterant, :evaluatedAltValues,   # the scan by Alterant and the access by Component
                         :childDiffers]   # mirrors docs/public-api.md §1.2 EXACTLY — 27 names; every change of the set is a row of §6

    @testset "export set is EXACTLY the declared semver surface" begin
        live = setdiff(Set(names(GM)), Set([:GoMeta]))     # names() on Julia ≥1.11 == exported ∪ `public` (+ the module name)
        exported = Set(filter(n -> Base.isexported(GM, n), collect(live)))
        @test exported == DECLARED_EXPORTS                        # [1] no accidental leak AND no gap (exact equality)
        @test setdiff(live, exported) == Set(SUPPORTING_PUBLIC)   # [1b] the `public` tier is EXACTLY the declared names (27; the history of the count in docs/public-api.md §6)
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

    @testset "the BLS tier: the parser module public by name; its door EXACTLY the declared set" begin
        DOOR = Set([:children, :parent, :kind, :content, :root, :flavor, :endsWithNewline, :isHorizontalSpace, :getElement, :File, :Block, :Line, :Segment, :ComponentSettribute, :CmpntNamedInt])   # the door's declared set
        live = setdiff(Set(names(GM.BLS)), Set([:BLS]))
        @test live == DOOR                                        # [B1] the door is EXACTLY the declared names — no leak, no gap
        @test all(n -> Base.ispublic(GM.BLS, n), DOOR)            # [B2] every door name carries the `public` marking
        @test all(n -> !Base.isexported(GM.BLS, n), DOOR)         # [B3] …and none is exported (qualified access only: BLS.<name>)
        @test all(n -> isdefined(GM.BLS, n), DOOR)                # [B4] every door name is a real binding
        @test Base.ispublic(GM, :BLS) && !Base.isexported(GM, :BLS)   # [B5] the module itself: public, not exported
        ps = GM.BLS.setUpToProcessFromBytes(Vector{UInt8}(codeunits("x = 1\n#~ hide\n\ny = 2\n")))
        @test String(GM.BLS.content(ps)) == join(ps.collectedLines, '\n')   # [B6] the File's whole text — the one-argument form
        @test isempty(GM.BLS.content(ps, GM.BLS.root(ps)))                # [B7] the two-argument form stays EMPTY for the File — the Engine's capture predicate untouched
    end

    @testset "naming tooth (the methods tooth, armed at the dialect-convergence wave)" begin
        # The naming pre-condition: before/while `goMeta` is the pipeline entry,
        # pin the method inventory so a collision with the retired earlier driver family (or any
        # accidental extra method) fails LOUD instead of silently widening dispatch.
        @test length(methods(GM.goMeta)) == 1                    # [T1] exactly the pipeline entry
        @test Main.BasicRenderer.outputs isa Function && length(methods(Main.BasicRenderer.outputs)) >= 1  # [T3] the development tool's pair is live (never deleted)
        # the one-path assertions — the SENTINEL is the gate against a second
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
        ann = GM.readAltValuesEvals(r.altValues_evals)
        @test ann isa Vector{Tuple{Vector{UInt8},Symbol,Any,Bool}}    # [8a] altValues_evals is the pinned typed surface
        @test !isempty(ann)                                           # [8b] …and is functionally populated (the fixture has verdicts)
        @test all(t -> !isempty(t[1]) && t[3] !== nothing, ann)       # [8c] each row: non-empty cell_handle + present verdict value (the [8a] type-pin already guarantees the Symbol attr + Bool polarity slots)
        ser = String(GM.serialize_evals(ann))
        @test first(split(ser, '\n')) == "# annotations golden — sorted (cell_handle, attr, value); final-verdicts-only."   # [8d] the serializer + its layout-stable header line, byte-pinned in-suite
        let hand = Tuple{Vector{UInt8},Symbol,Any,Bool}[(UInt8[0x00], :visib, :hide, true), (UInt8[0x01, 0x02], :label_label1, true, true), (UInt8[0xab, 0xcd], :heading, "a\tb", false), (UInt8[0xab, 0xce], :heading, "c\nd", false), (UInt8[0xab, 0xcf], :heading, "e\\f", false)]   # in the reader's sort order (by handle); tab, newline and backslash payloads
            @test String(GM.serialize_evals(hand)) == "# annotations golden — sorted (cell_handle, attr, value); final-verdicts-only.\n# columns: <attr>\\t<value>\\t<polarity>\\t<cell_handle = occurrence-key bytes, hex>\nvisib\t:hide\ttrue\t00\nlabel_label1\ttrue\ttrue\t0102\nheading\t\"a\\tb\"\tfalse\tabcd\nheading\t\"c\\nd\"\tfalse\tabce\nheading\t\"e\\\\f\"\tfalse\tabcf\n"   # [8g] the 4-column form's BYTES over a hand vector in the reader's order — value-discriminating; the tab, newline and backslash payloads escaped by repr (the bytes MEASURED 2026-09-30)
        end
        let hand = Tuple{Vector{UInt8},Symbol,Any,Bool}[(UInt8[0x00], Symbol("label_a\tb"), true, true), (UInt8[0x01], Symbol("x\ny\\z\r"), :v, false)]   # attribute NAMES carrying a tab, a newline, a backslash, a carriage return (a third-party stem or member)
            @test String(GM.serialize_evals(hand)) == "# annotations golden — sorted (cell_handle, attr, value); final-verdicts-only.\n# columns: <attr>\\t<value>\\t<polarity>\\t<cell_handle = occurrence-key bytes, hex>\nlabel_a\\tb\ttrue\ttrue\t00\nx\\ny\\\\z\\r\t:v\tfalse\t01\n"   # [8h] the attr column ENCODED: one row, one line, four columns
            @test count(==('\n'), String(GM.serialize_evals(hand))) == 4 && all(l -> count(==('\t'), l) == 3, split(String(GM.serialize_evals(hand)), '\n'; keepempty = false)[3:end])
        end
        @test hasmethod(GM.readAltValuesEvals, Tuple{GM.EvalStore})          # [8e] the reader takes the delivered PART `altValues_evals`
        @test !hasmethod(GM.readAltValuesEvals, Tuple{GM.GoMetaDelivery})   # [8f] and no method over the whole delivered object remains — the clean cut
    end

    @testset "the delivered object, its show, the reader: (a) (b) (e) (f); every value MEASURED 2026-10-03" begin
        # (a) the four parts by name, in the creator's order: the tree, the evals, the status, the diagnostics
        @test fieldnames(GM.GoMetaDelivery) == (:blsComponentTree, :altValues_evals, :status, :diagnostics)   # [a]
        # (b) ONE `Base.show` method over the delivered object — one line of counts, never the tree or the rows (src/state.jl); the strings MEASURED
        @test count(m -> (p = Base.unwrap_unionall(m.sig).parameters; length(p) == 3 && p[3] === GM.GoMetaDelivery), methods(Base.show, (IO, GM.GoMetaDelivery))) == 1   # [b1] exactly one method whose third parameter is the delivery itself
        let d = GM.goMeta(Vector{UInt8}(codeunits("x = 1\n#~ hide\n\ny = 2\n"))), s = sprint(show, d)
            @test which(Base.show, Tuple{IO, GM.GoMetaDelivery}).module === GM                       # [b2] the method dispatched is GoMeta's own
            @test count(==('\n'), s) == 0                                                             # [b3] one line
            @test s == "GoMetaDelivery(blsComponentTree: BLS.ParseState over 4 source lines; altValues_evals: 1 evals rows; PROCESS_OK; diagnostics: 0)"   # [b4] the measured string — the counts, never the tree or the rows
            @test sprint(show, GM.goMeta(UInt8[])) == "GoMetaDelivery(blsComponentTree: BLS.ParseState over 0 source lines; altValues_evals: 0 evals rows; PROCESS_OK; diagnostics: 0)"   # [b5] the empty input's
        end
        # (e) the reader's method COUNT — one, over the delivered PART ([8e]/[8f]). Its alternative — a convenience method over the whole
        # delivered object — is an open point: the pin is re-cut
        # in the commit that adds the method. A test of the present state, not a decision.
        @test length(methods(GM.readAltValuesEvals)) == 1                                               # [e]
        # (f) the reader's PURITY and the copied handles — a hand-built store, two records pushed in reverse handle order (the
        # test of 2026-10-01, re-cut without the field `content`, since removed)
        let st = GM.EvalStore(), h2 = UInt8[0x02], h1 = UInt8[0x01]
            push!(st.records, GM.EvalRecord(h2, :visib, :hide, true, [copy(h2)]))
            push!(st.records, GM.EvalRecord(h1, :visib, :show, true, [copy(h1)]))
            snap() = [(copy(e.cell_handle), e.attr, e.value, e.polarity, deepcopy(e.decided_by)) for e in st.records]
            s1 = snap()
            rows = GM.readAltValuesEvals(st)
            @test rows == [(UInt8[0x01], :visib, :show, true), (UInt8[0x02], :visib, :hide, true)]      # [f1] sorted by handle, the store's reverse order notwithstanding
            @test snap() == s1 && length(st.records) == 2 && st.records[1].cell_handle == h2             # [f2] the store unchanged by the read — records, order, bytes
            @test all(rows[i][1] !== e.cell_handle for i in 1:2 for e in st.records)                    # [f3] every returned handle is a COPY, never a record's own vector
            empty!(rows[1][1])
            @test GM.readAltValuesEvals(st) == [(UInt8[0x01], :visib, :show, true), (UInt8[0x02], :visib, :hide, true)]   # [f4] a second read after emptying a returned handle: the same rows
            @test snap() == s1                                                                            # [f5] …and the store still unchanged
        end
    end

    @testset "surface oracle: an out-of-surface implementation name is NOT bound in the top module" begin
        # The standing oracle for the v0 public surface: a name OUTSIDE the declared surface must
        # not be a binding in the top module (⇒ a fortiori it cannot be exported either, so a separate
        # `∉ exported` assertion would be implied by [1]). The two load-bearing checks below red the
        # moment a future edit binds either name — any module addition must consciously update the oracle.
        @test !isdefined(GM, :OtherImpl)                         # [9] the name is not bound in the top module
        @test !isdefined(GM, :PlugIn)                           # [10] the public alias `PlugIn` was REMOVED (a clean cut): a re-binding reds here where [1b] alone would not
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
