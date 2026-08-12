#!/usr/bin/env julia
# test/runtests.jl — the `Pkg.test()` shim.
#
# IS: the `Pkg.test()` entry (Julia hardcodes the SINGULAR test/runtests.jl path).
# DOES: include the canonical PLURAL tests/runtests.jl (which carries the load-path guard, the
#   LAYER FENCE, and the layer dispatch). The test sandbox env is test/Project.toml.
# REASONING: Julia's `Pkg.test` hardcodes the singular `test/runtests.jl`; the real runner is
#   `tests/runtests.jl`.
# PURPOSE: `Pkg.test()` runs exactly the same layers as `julia --project=tests tests/runtests.jl`.
include(joinpath(@__DIR__, "..", "tests", "runtests.jl"))
