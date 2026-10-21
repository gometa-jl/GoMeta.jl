# _support.jl — the shared test-support hub (module TestSupport; defines NO @testset of its own).
#
# IS:   the single source of shared fixtures + helpers for the layers tests/runtests.jl dispatches
#       (golden · unit). runtests.jl includes this file ONCE, before any layer. The golden layer
#       (golden_tests.jl) keeps its own manifest reader — it is the byte-parity layer — so this hub
#       serves the unit layer, and (since stage 2's commit 8) every layer's producer of the five-column annotations form.
# DOES: (1) the corpus loaders corpus_fixtures() / corpus_inputs() — the manifest's
#       byte_identical partition as (id, input bytes) pairs. (1b) derive_annotations_golden(delivery) — the test-layer
#       deriver of the reference files' five-column annotations form (derive_annotations.jl; stage 2's commit 8,
#       R-V04B-43 (3)) — the golden runner's producer and, at commit 9, the unit witnesses'. (2) quiet_io(f) — an
#       fd-level redirect of stdout+stderr to /dev/null (Base.devnull has no backing fd, so a plain
#       redirect_stdout(devnull) misses fd-level output), suppressing the benign, deterministic notices
#       the vendored BLS parser prints on over-capacity/deep inputs. (3) _sha, the shared sha256 hex helper.
#       (The fresh-process surface helpers were retired 2026-09-12, R-V04B-24 obligation 13 — see below.)
# REASONING: no test may hold a hardcoded byte or size baseline. Every expected render/tree is obtained
#       through the tests/golden/MANIFEST.toml indirection, so a golden re-pin touches ONLY the manifest
#       and the golden files — zero test files.
# PURPOSE: one deduplicated foundation for the layered suite, so each layer file stays small,
#       baseline-free, and reproducible. Helpers live in module TestSupport; the engine is reached via
#       `import GoMeta as GM`.

module TestSupport

using TOML, SHA
import GoMeta as GM

# REPO = the package root. MANIFEST = the single source for the pinned anchor/corpus bytes.
const REPO = normpath(joinpath(@__DIR__, "..", ".."))
const MANIFEST_PATH = joinpath(REPO, "tests", "golden", "MANIFEST.toml")

_sha(b::AbstractVector{UInt8}) = bytes2hex(sha256(b))

_manifest() = TOML.parsefile(MANIFEST_PATH)
_abs(relpath::AbstractString) = joinpath(REPO, relpath)


"The byte_identical corpus fixtures (the examples/ corpus rows)."
corpus_fixtures() = filter(f -> f["partition"] == "byte_identical", _manifest()["fixture"])

"Pairs (id, input_bytes) for the byte_identical corpus."
corpus_inputs() = [(fx["id"], read(_abs(fx["input_path"]))) for fx in corpus_fixtures()]


# (The fresh-process surface helpers `surface_shas` / `spawn_fresh` / `warmup_fresh` / `surface_code` were
# RETIRED on 2026-09-12 with the basic renderer's move — R-V04B-24 obligation 13: zero callers, and a fresh
# process would have called the pair without the loader.)

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

# THE TEST-LAYER DERIVER of the reference files' fifth column: `derive_annotations_golden(delivery)` —
# the five-column annotations form, its fifth column through the BLS Component tree and the door's `BLS.content`, never the Engine's copy.
include(joinpath(@__DIR__, "derive_annotations.jl"))

end # module TestSupport
