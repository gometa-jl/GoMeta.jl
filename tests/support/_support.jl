# _support.jl — the shared test-support hub (module TestSupport; defines NO @testset of its own).
#
# IS:   the single source of shared fixtures + helpers for the layers tests/runtests.jl dispatches
#       (golden · unit). runtests.jl includes this file ONCE, before any layer. The golden layer
#       (golden_tests.jl) keeps its own manifest reader — it is the byte-parity layer — so this hub
#       serves the unit layer.
# DOES: (1) the corpus loaders corpus_fixtures() / corpus_inputs() — the manifest's
#       byte_identical partition as (id, input bytes) pairs. (2) surface_shas(), the
#       (tree_sha, render_sha, annotations_sha) fingerprint of one in-process run. (3) spawn_fresh() —
#       runs a code string in a FRESH julia process under the package's own project with
#       JULIA_LOAD_PATH="@:@stdlib" (the global default env cannot silently satisfy an undeclared dep)
#       and a per-call tempdir cwd; returns (out, err, exitcode, files). warmup_fresh() precompiles in a
#       throwaway spawn so empty-stderr assertions never false-fail on build noise; surface_code()
#       builds the fingerprint program those spawns print. (4) quiet_io(f) — an
#       fd-level redirect of stdout+stderr to /dev/null (Base.devnull has no backing fd, so a plain
#       redirect_stdout(devnull) misses fd-level output), suppressing the benign, deterministic notices
#       the vendored BLS parser prints on over-capacity/deep inputs. (5) _sha, the shared sha256 hex helper.
# REASONING: no test may hold a hardcoded byte or size baseline. Every expected render/tree is obtained
#       through the tests/golden/MANIFEST.toml indirection, so a golden re-pin touches ONLY the manifest
#       and the golden files — zero test files.
# PURPOSE: one deduplicated foundation for the layered suite, so each layer file stays small,
#       baseline-free, and reproducible. Helpers live in module TestSupport; the engine is reached via
#       `import GoMeta as GM`.

module TestSupport

using TOML, SHA
import GoMeta as GM

# REPO = the package root. PROJECT_ROOT = the CORE env the fresh-process load/purity
# tests spawn under (they test the PACKAGE's own load surface, stdlib + StaticArrays/InlineStrings — NOT the
# heavier --project=tests env). MANIFEST = the single source for the pinned anchor/corpus bytes.
const REPO = normpath(joinpath(@__DIR__, "..", ".."))
const PROJECT_ROOT = REPO
const MANIFEST_PATH = joinpath(REPO, "tests", "golden", "MANIFEST.toml")

_sha(b::AbstractVector{UInt8}) = bytes2hex(sha256(b))

_manifest() = TOML.parsefile(MANIFEST_PATH)
_abs(relpath::AbstractString) = joinpath(REPO, relpath)


"The byte_identical corpus fixtures (the examples/ corpus rows)."
corpus_fixtures() = filter(f -> f["partition"] == "byte_identical", _manifest()["fixture"])

"Pairs (id, input_bytes) for the byte_identical corpus."
corpus_inputs() = [(fx["id"], read(_abs(fx["input_path"]))) for fx in corpus_fixtures()]


"The (tree_sha, render_sha, annotations_sha) triple for `bytes` under `cfg` — the in-process surface fingerprint."
function surface_shas(bytes::Vector{UInt8}; cfg = GM.GoMetaConfig())
    r = GM.goMeta(bytes; config = cfg)
    co = GM.outputs(r)
    ann = GM.serialize_evals(r)   # v0.2: the 5-column GoMetaResult form
    return (_sha(co.blsStructure_bytes), _sha(co.render_bytes), _sha(ann))
end

# ── fresh-process runner ──────────────────────────────────────────────────────────────────────────
# Spawns a FRESH julia (same toolchain) under the CORE env + the clean LOAD_PATH, runs `code` in an
# isolated scratch cwd, and returns (out, err, exitcode, files). addenv PRESERVES the inherited env (HOME /
# JULIA_DEPOT_PATH / PATH) and ADDS JULIA_LOAD_PATH + any env_extra — so the spawn is reproducible AND the
# global default env (@v#.#) cannot mask undeclared deps. Each call gets a fresh tempdir cwd, so two calls
# naturally exercise two DIFFERENT cwds (the purity contract: output must be cwd-independent).
function spawn_fresh(code::String; env_extra::Vector{Pair{String,String}} = Pair{String,String}[])
    return mktempdir() do scratch
        out = IOBuffer(); err = IOBuffer()
        cmd = addenv(`$(Base.julia_cmd()) --startup-file=no --project=$PROJECT_ROOT -e $code`,
                     "JULIA_LOAD_PATH" => "@:@stdlib", env_extra...)
        proc = cd(scratch) do
            run(pipeline(ignorestatus(cmd); stdout = out, stderr = err))
        end
        return (out = String(take!(out)), err = String(take!(err)),
                exitcode = proc.exitcode, files = readdir(scratch))
    end
end

# Precompile GoMeta under the CORE env in a throwaway spawn, so a subsequent measured spawn_fresh does
# NOT emit "Precompiling…" build noise to stderr (build noise is NOT a load side-effect). Call ONCE before
# the empty-stderr fresh-process assertions.
warmup_fresh() = (spawn_fresh("using GoMeta"); nothing)

# A fresh-process code string that renders an input file (absolute path) at `range` and PRINTS its surface
# fingerprint "tree_sha render_sha ann_sha" to stdout — the payload a fresh-process caller compares.
function surface_code(input_abspath::AbstractString; range::Union{Nothing,UnitRange{Int}} = nothing)
    cfg = range === nothing ? "GM.GoMetaConfig()" : "GM.GoMetaConfig(parse_range = $(range.start):$(range.stop))"
    return """
    import GoMeta as GM
    using SHA
    bytes = read(raw\"$(input_abspath)\")
    r = GM.goMeta(bytes; config = $cfg)
    co = GM.outputs(r)
    ann = GM.serialize_evals(r)   # v0.2: the 5-column GoMetaResult form
    print(bytes2hex(sha256(co.blsStructure_bytes)), " ", bytes2hex(sha256(co.render_bytes)), " ", bytes2hex(sha256(ann)))
    """
end


# Run `f()` with stdout + stderr redirected to /dev/null at the fd level, returning f()'s value (the redirect
# is restored even if `f` throws). PURPOSE: suppress the BENIGN vendored parse-layer `printstyled` notices
# that fire on the child-capacity whole-file path + the out-of-window depth path (handled + deterministic —
# not defects of this package; the vendored parse layer's own notices sit outside the package's documented
# message surface, see docs/public-api.md §3). We open /dev/null explicitly because
# `Base.devnull` is a Julia-level discard IO (no backing fd), which `redirect_stdout` cannot swap to — a
# `redirect_stdout(devnull)` would be a silent no-op for fd-level printstyled output. The golden suite never
# trips these notices.
function quiet_io(f)
    open("/dev/null", "w") do nul
        redirect_stdout(nul) do
            redirect_stderr(nul) do
                f()
            end
        end
    end
end

end # module TestSupport
