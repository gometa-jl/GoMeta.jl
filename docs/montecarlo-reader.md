# Estimating pi by throwing darts

An ordinary Julia file: `include("montecarlo.jl")` runs it top to bottom.
Every notebook and manual page beside it is DERIVED from this one file by
`notebooks_from_source.jl` — purely from the `#~` marks you see below.

The label legend for this file (the five shipped labels, bound by this
project's own convention — the legend is data, not engine vocabulary):
  :label1 = parameters   :label2 = expensive   :label3 = solution
  :label4 = deep-dive    :label5 = private

## Parameters

```@example montecarlo
n_darts  = 10_000
rng_seed = 2026
```

## The estimator
A dart lands uniformly in the unit square; the quarter-circle catches
pi/4 of them — so four times the hit fraction estimates pi:

```jldoctest
julia> round(4 * atan(1); digits = 4)   # the target the darts approach
3.1416
```

```@example montecarlo
using Random
function estimate_pi(n; rng = MersenneTwister(rng_seed))
    hits = count(_ -> rand(rng)^2 + rand(rng)^2 <= 1, 1:n)
    4 * hits / n
end
estimate_pi(n_darts)
```

## Convergence study
More darts, better estimate — this cell is marked expensive: automated
executors that honor the `skip-execution` tag (nbclient, nbconvert) skip
it; an interactive Run All does not, so plain `include` and interactive
runs keep a fast default unless you opt in with the environment variable.

```julia
n_many = get(ENV, "DARTS_FULL", "") == "" ? 100_000 : 100_000_000
estimate_pi(n_many)
```

*(Marked expensive in the source — shown here, deliberately NOT executed by the docs build.)*

---

*A trimmed reading view derived from the same source as the
[full page](montecarlo-full.md). The trim is SECTION-grain: a section whose marks say
solution or deep-dive leaves whole — heading, prose, and any unmarked lines inside
it included. This page carries 1 `jldoctest` block(s) to the full page's
2 — the marks chose.*
