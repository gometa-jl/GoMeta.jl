# golden_tests.jl — the MANIFEST-driven golden byte-oracle layer of the GoMeta test suite.
#
# IS:   the read-side golden runner: it drives tests/golden/MANIFEST.toml and byte-compares
#       GoMeta.outputs — the (tree, render) pair per docs/CANONICAL-OUTPUT.md — against
#       pinned goldens across three partitions: byte_identical, expected_to_change, net_new_surface.
# DOES: (1) fail-closed MANIFEST schema validation: required keys present and non-empty,
#       partition-specific golden keys, no partition silently empty. (2) byte_identical:
#       input sha256 integrity, then render and tree goldens checked twice (sha256 pre-check +
#       full byte-compare), plus in-process determinism across two runs. (3) expected_to_change:
#       every fixture carries re-pin provenance rows (category, reason, old/new sha256, date);
#       its current render equals the NEW pinned bytes, and its tree golden is held
#       to the same two-leg check. (4) net_new_surface: the serialized annotations golden (sha
#       pre-check + byte-compare), a PROCESS_OK clean-run guard, determinism across two fresh
#       runs, sorted order, all-true verdict polarity, and no WARN_VERDICT_COLLISION diagnostic.
#       (5) an oracle-depth gate: at least three byte_identical fixtures sourced from the
#       reference render corpus. (6) a corpus drift-check: each harvested fixture's input byte-equals
#       its examples/InFileFolder original, and its render golden equals the examples/OutFileFolder
#       oracle keyed on the INPUT's terminal byte (input ends 0x0a ⇒ verbatim; else minus exactly
#       one trailing 0x0a, the newline the corpus writer appends); skips with a warning when
#       examples/ is absent. (7) meta-free passthrough: an input with no metaLines renders
#       byte-identical to itself. (8) render polarity: a hidden line renders as "## " plus its
#       original bytes, a discarded subtree's content is absent, and outputs is never
#       tree-only (render ≠ tree). (9) the verdict-free tree invariant: for every (tree, render)
#       fixture, the PRE-apply structural serialization byte-equals the POST-apply tree bytes —
#       absorb/apply never mutates the structural tree — a stability any condition-evaluation
#       implementation can rely on. (10) a comparator self-test: the
#       sha+byte equality rejects an empty render and a tree-only render at both legs, proving
#       the golden comparator is non-vacuous.
# REASONING: a golden layer only has teeth when its fixtures are oracle-grounded and its
#       comparator is non-vacuous — so fixture provenance, partition accounting, corpus drift,
#       and the comparator itself are tested here rather than assumed; one shared helper parses
#       the optional "@a:b" range suffix in fixture ids so the render and tree paths never drift.
# PURPOSE: any engine change that breaks byte-parity with the corpus render references under
#       examples/OutFileFolder, or degrades the evals surface, fails loudly. Run via
#       tests/runtests.jl (layer: golden).

using Test, TOML, SHA
using GoMeta
const G = GoMeta

const REPO = normpath(joinpath(@__DIR__, "..", ".."))
const ANCHOR_EXAMPLES = normpath(joinpath(@__DIR__, "..", "..", "examples"))
_sha(b::Vector{UInt8}) = bytes2hex(sha256(b))

# _fixture_range — parse the optional "@a:b" parse-range suffix out of a fixture id (the anchor id ends in
# "…@1:37" → 1:37), returning `nothing` for a whole-file fixture. This is the SINGLE source of a fixture's parse
# range, shared by `_co` (which builds the GoMetaConfig) and `_preapply_tree` (which derives the parseBLS `to`),
# so the two can never drift on a separate literal AND a FUTURE ranged fixture (e.g. an id ending "…@1:50") is
# handled identically by both with no code change. The `$`-anchored pattern matches only an id-trailing range tag
# (never the "annotations@…" net_new_surface prefix, which has no trailing "@a:b").
function _fixture_range(fx)
    m = match(r"@(\d+):(\d+)$", fx["id"])
    return m === nothing ? nothing : (parse(Int, m.captures[1]):parse(Int, m.captures[2]))
end

# render outputs for a manifest fixture (a ranged fixture's id carries an "@a:b" range tag).
function _co(fx)
    bytes = read(joinpath(REPO, fx["input_path"]))
    r = _fixture_range(fx)
    cfg = r === nothing ? G.GoMetaConfig() : G.GoMetaConfig(parse_range = r)
    return G.outputs(G.goMeta(bytes; config = cfg))
end

# _preapply_tree — the VERDICT-FREE tree half taken at the PARSE stage (pre-absorb / pre-apply), used by the
# verdict-free-tree testset below. It mirrors the EXACT parse `goMeta` performs (GoMeta.jl setUpToProcessFromBytes
# → `parseBLS(ps, 1, to)` with `to = isnothing(range) ? -1 : last(range)`) and serializes via the SAME
# `structural_serialization` `outputs` uses — but STOPS before absorb+apply. The range comes from
# the SHARED `_fixture_range` (the same source `_co` uses — no duplicated literal). Equality with the post-apply
# tree proves apply never mutated the structural tree (verdict-free).
function _preapply_tree(fx)
    bytes = read(joinpath(REPO, fx["input_path"]))
    ps    = G.BLS.setUpToProcessFromBytes(bytes)
    r     = _fixture_range(fx)
    to    = r === nothing ? -1 : last(r)
    G.BLS.parseBLS(ps, 1, to)
    return G.BLS.structural_serialization(ps)
end

@testset "golden layer (MANIFEST-driven)" begin
    man = TOML.parsefile(joinpath(REPO, "tests", "golden", "MANIFEST.toml"))
    @test haskey(man, "fixture")
    fixtures = man["fixture"]
    @test !isempty(fixtures)

    @testset "manifest schema (fail-closed)" begin
        common = ("id", "partition", "source", "input_path", "input_sha256")
        for fx in fixtures, k in common
            @test haskey(fx, k) && !isempty(string(fx[k]))
        end
        for fx in fixtures
            @test fx["partition"] in ("byte_identical", "expected_to_change", "net_new_surface")
            @test fx["source"] in ("legacy_anchor", "captured", "narration", "synthesized", "legacy_harvest")
            # required keys are PARTITION-SPECIFIC: the (tree, render) partitions pin both render+tree goldens;
            # the net_new_surface (annotations) partition pins the annotations golden.
            req = fx["partition"] == "net_new_surface" ?
                ("annotations_golden_path", "annotations_golden_sha256") :
                ("tree_golden_path", "tree_golden_sha256", "render_golden_path", "render_golden_sha256")
            for k in req
                @test haskey(fx, k) && !isempty(string(fx[k]))
            end
        end
        # partition accounting (fail-closed vs tampering/corruption emptying a partition silently):
        @test !isempty(filter(f -> f["partition"] == "byte_identical", fixtures))
        # (no expected_to_change fixtures ship in this repository's manifest)
        # net_new_surface = the evals surface (docs/CANONICAL-OUTPUT.md §4).
        @test !isempty(filter(f -> f["partition"] == "net_new_surface", fixtures))
    end

    @testset "byte_identical :: $(fx["id"])" for fx in filter(f -> f["partition"] == "byte_identical", fixtures)
        # input integrity (the pinned input is what we render)
        @test _sha(read(joinpath(REPO, fx["input_path"]))) == fx["input_sha256"]
        co = _co(fx)
        # render golden: sha pre-check + full byte-compare on the in-repo golden file
        @test _sha(co.render_bytes) == fx["render_golden_sha256"]
        @test co.render_bytes == read(joinpath(REPO, fx["render_golden_path"]))
        # tree golden (the verdict-free tree half)
        @test _sha(co.blsStructure_bytes) == fx["tree_golden_sha256"]
        @test co.blsStructure_bytes == read(joinpath(REPO, fx["tree_golden_path"]))
        # in-process determinism
        co2 = _co(fx)
        @test co2.render_bytes == co.render_bytes
        @test co2.blsStructure_bytes == co.blsStructure_bytes
    end

    @testset "expected_to_change :: $(fx["id"])" for fx in filter(f -> f["partition"] == "expected_to_change", fixtures)
        @test haskey(fx, "repin") && !isempty(fx["repin"])
        for rp in fx["repin"]
            @test rp["category"] in ("i", "ii", "iii")
            @test !isempty(string(rp["reason"]))
            @test !isempty(string(rp["old_sha256"])) && !isempty(string(rp["new_sha256"]))
            @test haskey(rp, "date") && !isempty(string(rp["date"]))            # required repin keys
        end
        co = _co(fx)
        # current render == the NEW pinned bytes (and the golden file); a diverging output without a
        # matching repin row would already have failed the sha check above.
        @test _sha(co.render_bytes) == fx["render_golden_sha256"]
        @test fx["repin"][end]["new_sha256"] == fx["render_golden_sha256"]
        @test co.render_bytes == read(joinpath(REPO, fx["render_golden_path"]))
        # tree golden too — guards the anchor's tree surface against a false-green
        @test _sha(co.blsStructure_bytes) == fx["tree_golden_sha256"]
        @test co.blsStructure_bytes == read(joinpath(REPO, fx["tree_golden_path"]))
    end

    @testset "net_new_surface :: annotations :: $(fx["id"])" for fx in filter(f -> f["partition"] == "net_new_surface", fixtures)
        # the net-new surface (altValues_evals(result)): no oracle FILE (the reference corpus carries
        # no per-cell verdict map), values oracle-grounded. The golden is this engine's serialized annotations;
        # a standing determinism + totality + regression guard.
        bytes = read(joinpath(REPO, fx["input_path"]))
        @test _sha(bytes) == fx["input_sha256"]                        # input integrity
        res = G.goMeta(bytes; config = G.GoMetaConfig())
        # clean-run guard: a
        # PROCESS_ERROR yields an empty EvalStore ⇒ a 2-line-header-only serialization. For a non-empty golden
        # the sha pre-check below catches that, but for a (future) intentionally-EMPTY-annotations fixture the
        # headers would MATCH ⇒ this guard is what keeps that case from silently false-greening.
        @test res.status == G.PROCESS_OK
        ann = G.altValues_evals(res)
        ser = G.serialize_evals(res)                             # the SINGLE shared serializer (v0.2: the 5-column GoMetaResult form)
        @test _sha(ser) == fx["annotations_golden_sha256"]             # golden sha pre-check
        @test ser == read(joinpath(REPO, fx["annotations_golden_path"]))   # full byte-compare on the golden file
        # deterministic across a 2nd fresh in-process run; sorted; polarity; totality.
        ann2 = G.altValues_evals(G.goMeta(bytes; config = G.GoMetaConfig()))
        @test ann2 == ann                                                # determinism (independent fresh run)
        @test issorted(ann; by = t -> (t[1], string(t[2]), string(t[3])))
        @test all(t -> t[4] === true, ann)                               # v0: every applied verdict polarity true
        # TOTALITY (real, not the length(ann)==length(records) 1:1-sortperm tautology): the EXACT verdict
        # set+count is pinned by the golden byte-compare above; here we assert totality is not silently degraded
        # by a value-CHANGING content-addressed merge (which would drop a distinct cell's verdict) — no such
        # WARN_VERDICT_COLLISION diagnostic fired during capture.
        @test isempty(filter(d -> d.code === :WARN_VERDICT_COLLISION, res.diagnostics))
    end

    @testset "golden-oracle-depth (≥3 oracle-grounded byte_identical fixtures)" begin
        depth = count(f -> f["partition"] == "byte_identical" &&
                           f["source"] in ("legacy_anchor", "legacy_harvest"), fixtures)
        @test depth >= 3
    end

    @testset "drift-check vs the anchor examples/ (single source of truth)" begin
        if isdir(joinpath(ANCHOR_EXAMPLES, "InFileFolder"))
            for fx in filter(f -> f["source"] == "legacy_harvest", fixtures)
                name = basename(fx["input_path"])
                anchor_in = joinpath(ANCHOR_EXAMPLES, "InFileFolder", name)
                @test isfile(anchor_in)
                @test _sha(read(anchor_in)) == fx["input_sha256"]          # in-repo input == anchor canonical
                anchor_out = joinpath(ANCHOR_EXAMPLES, "OutFileFolder", name)
                @test isfile(anchor_out)
                # This engine's render is byte-faithful on the TERMINAL NEWLINE (src/emit/emit.jl), where the
                # reference corpus comes from a writer that appends one unconditionally. So the
                # "golden == oracle" drift-check is keyed
                # on the INPUT's terminal byte — NOT the filename, NOT a blanket OR: when the whole-file input
                # ends 0x0a the golden equals the oracle verbatim; else it equals the oracle minus exactly one
                # trailing 0x0a (the one that writer appends). The rule keeps FULL teeth on the
                # six terminated corpus files (their goldens must still byte-equal the oracle).
                oracle_bytes = read(anchor_out)
                in_bytes = read(anchor_in)
                input_nl = !isempty(in_bytes) && in_bytes[end] == 0x0a
                expected_golden_sha = input_nl ? _sha(oracle_bytes) :
                    (!isempty(oracle_bytes) && oracle_bytes[end] == 0x0a ?
                        _sha(oracle_bytes[1:end-1]) : _sha(oracle_bytes))
                # (The two formerly deliberately-AHEAD harvested goldens agree with the
                # canonical reference in this tree — the rows assert live here.)
                @test expected_golden_sha == fx["render_golden_sha256"] # golden == oracle (mod terminal 0x0a)
            end
        else
            @warn "drift-check SKIPPED: anchor examples/ not reachable (detached checkout)" ANCHOR_EXAMPLES
            @test_skip false
        end
    end

    @testset "prop_metafree_passthrough (meta-free input ⇒ render == input)" begin
        metafree = [
            "x = 1\ny = 2\nz = 3\n# a plain comment line\nfunction f(a)\n    return a + 1\nend\n## a double-hash comment\nq = f(10)\nr = q * 2\n",
            "module M\n# no metaLines anywhere here\nconst K = 42\nstruct S\n    a::Int\n    b::Int\nend\ng(s::S) = s.a + s.b\n# trailing comment\nh = g(S(1, 2))\nend\n",
        ]
        for src in metafree
            bytes = Vector{UInt8}(codeunits(src))
            co = G.outputs(G.goMeta(bytes; config = G.GoMetaConfig()))
            @test co.render_bytes == bytes   # verbatim passthrough (no metaLines ⇒ nothing hidden/discarded)
        end
    end

    @testset "render-polarity + not-tree-only canary" begin
        # The byte_identical fixture pins the Extended corpus file's FULL render; the [1] checks below NAME
        # the explicit render-polarity invariant it must satisfy (hide renders "## " + original bytes; a
        # discarded subtree's content is absent) and [9] is the lite pair-shape canary.
        ext_bytes = read(joinpath(REPO, "tests", "golden", "corpus", "InFileFolder", "file_for_Example_Extended.jl"))
        co_ext = G.outputs(G.goMeta(ext_bytes; config = G.GoMetaConfig()))
        extR = String(copy(co_ext.render_bytes))   # copy: String(::Vector{UInt8}) is DESTRUCTIVE (steals the buffer) — keep co_ext.render_bytes intact for the [9] checks below
        @test occursin("## # This `Line` should still be \"hidden\"", extR)   # [1] hide ⇒ `## `+original bytes (indent after marker)
        @test !occursin("should still be \"discarded\"", extR)               # [1] discard ⇒ subtree content ABSENT (zero subtree bytes)
        # [9] lite canary — outputs is the (tree, render) PAIR, never tree-only (a tree-only
        #     collapse cannot arise silently). The FULL comparator canary is the self-test at the end of this file.
        @test !isempty(co_ext.render_bytes)
        @test !isempty(co_ext.blsStructure_bytes)
        @test co_ext.render_bytes != co_ext.blsStructure_bytes
    end

    @testset "tree half is verdict-free (pre-apply structural_serialization == post-apply tree)" begin
        # IS: the explicit verdict-free-tree invariant — the tree half of outputs is the PARSE-stage
        #     structural serialization, carrying NO verdict/alterant information, so it is STABLE across
        #     absorb+apply (and across any condition-evaluation implementation). DOES: for
        #     every (tree,render)-bearing golden fixture (byte_identical + expected_to_change; the
        #     net_new_surface annotations fixtures have no tree golden), assert the tree taken PRE-apply
        #     (`_preapply_tree`, the parse stage alone) byte-equals the tree taken POST-apply
        #     (`outputs(goMeta(...)).blsStructure_bytes`). REASONING: `outputs().blsStructure_bytes` IS
        #     `structural_serialization(result.state.parse)` (GoMeta.jl), so a DIVERGENCE here would mean
        #     absorb/apply MUTATED the parse tree (e.g. an `addedStrings` insertion leaking into the
        #     structural half) — precisely the verdict leak this invariant forbids. PURPOSE: a standing guard
        #     that the tree surface stays verdict-free — a property any condition-evaluation
        #     implementation can rely on. MANIFEST-driven (the shared
        #     `_fixture_range` handles ranged ids) so any future (tree,render) fixture is auto-covered.
        treefix = filter(f -> f["partition"] in ("byte_identical", "expected_to_change"), fixtures)
        @test !isempty(treefix)
        for fx in treefix
            @testset "$(fx["id"])" begin
                pre  = _preapply_tree(fx)
                post = _co(fx).blsStructure_bytes
                @test !isempty(post)            # non-vacuity: a non-empty tree ⇒ the equality below is a real constraint
                @test pre == post               # apply did not mutate the structural (verdict-free) tree
            end
        end
    end

    @testset "comparator self-test canary :: render-blanked / tree-only result must be REJECTED [C2]" begin
        # IS: a SELF-TEST of THIS layer's OWN byte-comparator — the (sha pre-check + full byte-compare) equality the
        #     byte_identical / expected_to_change @testsets above perform on `co.render_bytes` vs the pinned golden.
        #     DOES: take a real fixture's render golden, then assert the comparator REJECTS the two degenerate
        #     render-blanked shapes a regression could produce — an EMPTY render (emit returns nothing) and a
        #     TREE-ONLY render (outputs collapsed so the render half is replaced by the tree half / a
        #     noncompliant tree-only result) — at BOTH comparator legs (the sha pre-check AND the byte-compare).
        #     REASONING: the byte_identical comparator can only CATCH a render regression if its equality is a REAL
        #     constraint (a non-empty golden) that a blanked render FAILS; this canary proves that discrimination so
        #     the golden layer cannot silently false-green on a blanked emit. It is the FULL counterpart of the `[9]`
        #     lite canary (which only asserts the (tree,render) PAIR shape). PURPOSE: keep the golden comparator
        #     non-vacuous — a self-test that the regression net has teeth.
        ext_matches = filter(f -> f["id"] == "file_for_Example_Extended.jl", fixtures)
        @test length(ext_matches) == 1     # the canary fixture must exist in MANIFEST exactly once (named, fail-closed)
        ext = only(ext_matches)
        golden_render = read(joinpath(REPO, ext["render_golden_path"]))
        co  = _co(ext)
        # baseline — the comparator ACCEPTS the truthful result (the equality is satisfiable, not vacuously false):
        @test !isempty(golden_render)                              # a non-empty golden ⇒ `==` is a real constraint
        @test _sha(co.render_bytes) == ext["render_golden_sha256"] # sha leg accepts truth
        @test co.render_bytes == golden_render                     # byte leg accepts truth
        # prerequisite for the tree-only rejection (proven LOCALLY, not via the byte_identical sha rows): this
        # fixture's tree half ≠ its render half (it carries real alterant effects), so a tree-only substitution is
        # a genuinely DIFFERENT byte string — without this the (b) legs could be vacuously true if tree == render.
        @test co.blsStructure_bytes != co.render_bytes
        # rejection — a render-blanked / tree-only result FAILS the comparator at BOTH legs:
        @test _sha(UInt8[]) != ext["render_golden_sha256"]         # (a) empty render — sha leg rejects
        @test UInt8[] != golden_render                             # (a) empty render — byte leg rejects
        @test _sha(co.blsStructure_bytes) != ext["render_golden_sha256"]   # (b) tree-only render — sha leg rejects
        @test co.blsStructure_bytes != golden_render                       # (b) tree-only render — byte leg rejects
    end
end
