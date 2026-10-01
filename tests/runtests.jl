#!/usr/bin/env julia
# tests/runtests.jl — the canonical test entry (the LAYER DISPATCHER).
#
# IS:   the ARGS-filtered layer-dispatching runner for the shipped suite.
# DOES: runs the standing layers — golden (the byte-oracle authority) · unit (the public-surface
#   smoke + the documented-refusal witnesses) · authored (the owner's confirmed statements;
#   tests/authored/README.md) — each self-contained (own `using` + @testset).
#   With NO ARGS, runs ALL THREE; `JULIA_LOAD_PATH="@:@stdlib" julia --project=tests tests/runtests.jl golden`
#   (or any subset) runs only the named layers (FAIL-CLOSED on an unknown name); the load-path
#   prefix is REQUIRED — the guard below fail-closes on Julia's default load path.
# REASONING: invocation requires `JULIA_LOAD_PATH="@:@stdlib"`; an unknown layer name fails closed.
# PURPOSE: `julia --project=tests tests/runtests.jl [layer…]` (direct) and `]test` via the
#   test/runtests.jl shim both run the IDENTICAL layers.
#
# STANDING INVOCATION: `--project=tests` — the env resolves the package itself via its
#   `[sources]` entry; the declared test dependencies are `Random`, `SHA`, `TOML`, `Test` (standard library) and the
#   registered package `StaticArrays` (both test environments, kept equal by the env_twin check).

# --- load-path discipline (preamble assert) --- Run the suite with JULIA_LOAD_PATH="@:@stdlib" so the GLOBAL default env
# (@v#.#) is NOT reachable, and an undeclared package dependency fails LOUDLY instead of being silently
# satisfied. This guard verifies the resolved load path honors it.
if any(p -> startswith(p, "@v"), Base.LOAD_PATH)
    error("global-env-fallback guard: Base.LOAD_PATH=$(Base.LOAD_PATH) admits the global " *
          "default env (@v#.#). Invoke with JULIA_LOAD_PATH=\"@:@stdlib\" to prevent undeclared-dep masking.")
end

using Test
## THE ONE PATH to the basic renderer (a development tool; R-V04B-24 obligation 7): loaded ONCE here, at
## Main's top level, BEFORE the support hub and every layer; every layer spells the call `Main.BasicRenderer.outputs`.
include(joinpath(@__DIR__, "..", "devtools", "load_basic_renderer.jl"))
include(joinpath(@__DIR__, "support", "_support.jl"))   # the shared support hub (module TestSupport) — loaded ONCE before the layers

# === LAYER FENCE ==============================================================================
# ARMED (dispatched below): golden · unit · authored (the owner's confirmed statements —
#   tests/authored/README.md; R-V04B-15 (c); landed 2026-09-11 under R-V04B-24 (R)).
# FENCED (NOT dispatched): no further layers ship in this repository.
# ==============================================================================================

const LAYERS = ("golden", "unit", "authored")
if !isempty(ARGS)
    bad = setdiff(ARGS, collect(LAYERS))
    isempty(bad) || error("runtests: unknown layer arg(s) $(bad); known layers: $(join(LAYERS, ", "))")
end
const SEL = isempty(ARGS) ? LAYERS : Tuple(l for l in LAYERS if l in ARGS)

@testset "GoMeta" begin
    "golden"      in SEL && include(joinpath(@__DIR__, "golden",      "golden_tests.jl"))
    "unit"        in SEL && include(joinpath(@__DIR__, "unit",        "unit_tests.jl"))
    "authored"    in SEL && include(joinpath(@__DIR__, "authored",    "authored_tests.jl"))
end
