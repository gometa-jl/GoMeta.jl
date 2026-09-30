# tests/unit/renderer_free_process_tests.jl — the SEPARATION witness: the Engine's delivery needs no development tool
#   (stage 1 commit 5; item 8 of the stage-1 brief — the set REAL-1's top action #6; SESSION 10, 2026-09-30).
#
# IS:   ONE fresh Julia child process that does `import GoMeta` (and `using SHA`, a test dependency) and nothing else — no
#       `Main.BasicRenderer`, no devtools — it runs
#       `goMeta` over a committed corpus input and reports what the delivered object's part `altValues_evals` holds, read
#       through the reader.
# DOES: spawns the child with the suite's own project (the active test environment; JULIA_LOAD_PATH inherited) and asks it for
#       (1) `isdefined(Main, :BasicRenderer)` — false expected; (2) the status; (3) the reader's row count; (4) the sha256 of the
#       4-column serialization of the rows; then computes (2)–(4) in THIS process (where the renderer IS loaded — tests/runtests.jl
#       loads it once at Main's top level before every layer) and asserts equality: the Engine's output is the same with and
#       without the development tool in the image.
# REASONING: every other test runs after the renderer is loaded; none proved that the delivered object needs no tool. A fresh
#       process is the only witness of absence (the fresh-process helpers retired from tests/support/_support.jl on 2026-09-12
#       called the pair without the loader — this one never touches the pair; R-V04B-24).
# PURPOSE: the branch's headline — the delivered object without the pair — pinned mechanically (THE PLAN §2 Stage 1 item 8, #6).

using Test
using SHA
import GoMeta as GM

@testset "renderer-free process (REAL-1 #6): the Engine's delivery needs no development tool" begin
    fx = only(filter(f -> f["id"] == "feature_contiguous_metablock.jl", TestSupport.corpus_fixtures()))   # the manifest's first byte-identical corpus fixture, selected by id
    input = joinpath(TestSupport.REPO, fx["input_path"])
    proj = dirname(Base.active_project())                         # the suite's own environment (tests/ — or Pkg.test's sandbox)
    code = """
        import GoMeta
        using SHA
        r = GoMeta.goMeta(read(ARGS[1]))
        rows = GoMeta.readAltValuesEvals(r.altValues_evals)
        println(isdefined(Main, :BasicRenderer))
        println(r.status)
        println(length(rows))
        println(bytes2hex(sha256(GoMeta.serialize_evals(rows))))
        """
    cmd = `$(Base.julia_cmd()) --startup-file=no --project=$proj -e $code $input`
    out = split(strip(read(cmd, String)), '\n')
    @test length(out) == 4                                        # [1] the child answered the four questions
    @test out[1] == "false"                                       # [2] no BasicRenderer in the child's Main — the tool ABSENT
    r = GM.goMeta(read(input))
    rows = GM.readAltValuesEvals(r.altValues_evals)
    @test !isempty(rows)                                          # [3b] the fixture is meta-bearing (its committed golden: 8 rows) — the digests below compare rows, never two empty headers
    @test out[2] == string(r.status)                              # [3] the same status
    @test out[3] == string(length(rows))                          # [4] the same row count
    @test out[4] == bytes2hex(sha256(GM.serialize_evals(rows)))   # [5] the same bytes of the rows (the 4-column form) — the delivery independent of the tool
    @test isdefined(Main, :BasicRenderer)                         # [6] and THIS process does carry the tool — the contrast is real
end
