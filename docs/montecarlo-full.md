# Estimating pi by throwing darts

An ordinary Julia file: `include("montecarlo.jl")` runs it top to bottom.
Every notebook and manual page beside it is DERIVED from this one file by
`notebooks_from_source.jl` — purely from the `#~` marks you see below.

The label legend for this file (the five shipped labels, bound by this
project's own convention — the legend is data, not engine vocabulary):
  :label1 = parameters   :label2 = expensive   :label3 = solution
  :label4 = deep-dive    :label5 = private

```@setup gometa_carriage_montecarlo
##gometa carriage v1 kind=carrier n=1 carried=0 hidden=
## #~ discard{ :label5 }
```

## Parameters

```@setup gometa_carriage_montecarlo
##gometa carriage v1 kind=code n=3 carried=0 hidden=
## #~2 :label1
```

```@example gometa_montecarlo
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

```@example gometa_montecarlo
using Random
function estimate_pi(n; rng = MersenneTwister(rng_seed))
    hits = count(_ -> rand(rng)^2 + rand(rng)^2 <= 1, 1:n)
    4 * hits / n
end
estimate_pi(n_darts)
```

## Exercise
Rewrite the estimator so it draws both coordinates in one pass and
measure the speedup.

```@setup gometa_carriage_montecarlo
##gometa carriage v1 kind=code n=9 carried=0 hidden=
## #~2 :label3
```

```@example gometa_montecarlo
function estimate_pi_fused(n; rng = MersenneTwister(rng_seed))
    hits = 0
    for _ in 1:n
        hits += ifelse(rand(rng)^2 + rand(rng)^2 <= 1, 1, 0)
    end
    4 * hits / n
end
estimate_pi_fused(n_darts)
```

## Convergence study
More darts, better estimate — this cell is marked expensive: automated
executors that honor the `skip-execution` tag (nbclient, nbconvert) skip
it; an interactive Run All does not, so plain `include` and interactive
runs keep a fast default unless you opt in with the environment variable.

```@setup gometa_carriage_montecarlo
##gometa carriage v1 kind=code n=3 carried=0 hidden=
## #~2 :label2
```

```julia
n_many = get(ENV, "DARTS_FULL", "") == "" ? 100_000 : 100_000_000
estimate_pi(n_many)
```

*(Marked expensive in the source — shown here, deliberately NOT executed by the docs build.)*

## Why the error falls like one over sqrt of n

```@setup gometa_carriage_montecarlo
##gometa carriage v1 kind=markdown n=10 carried=0 hidden=
## #~2 :label4
```

The hit count is a Binomial sum, so the estimator's standard error is
`4 * sqrt(p * (1 - p) / n)` with `p = pi / 4`. Doubling the dart count
divides the error by sqrt of 2 — the check below is a doctest the
derived manual pages carry only where this deep-dive section survives:

```jldoctest
julia> round(4 * sqrt((pi / 4) * (1 - pi / 4) / 10_000); digits = 4)
0.0164
```

```@setup gometa_carriage_montecarlo
##gometa carriage v1 kind=code n=3 carried=0 hidden=
## #~2 :label4
```

```@example gometa_montecarlo
se(n) = 4 * sqrt((pi / 4) * (1 - pi / 4) / n)
se(10_000)
```

```@setup gometa_carriage_montecarlo
##gometa carriage v1 kind=markdown n=2 carried=0 hidden=
## #]
```

The section above closed; this line is deliberately detached from it.

---

## How this page was made

This page (and its reader twin) was derived from `notebooks/src/montecarlo.jl` by
`notebooks_from_source.jl` — the `#~` marks in that one source file decided which
sections appear here and which tests the docs build runs. This full page carries
**2** `jldoctest` block(s); the reader page carries **1** — the marks
chose the manual-page test selection (docstring doctests are a SEPARATE channel —
a `makedocs(modules = …)` configuration this site does not enable). The execution
axis has three distinct states:

| state | mechanism | executed at docs build? |
|---|---|---|
| run + shown | a named `@example` block | yes |
| run + hidden | `# hide` on the line (a fully hidden cell becomes a named `@setup`) | yes — the SOURCE line is hidden; a `# hide` line's output can still show |
| shown, not run | a plain fenced block | no |

This FULL page is a TRANSFORMATION artifact (v0.3.1): every
non-discarded metaLine — `#~` marks and `#]` close-markers alike — and every
hidden non-executed line rides INVISIBLY in the
page's `@setup gometa_carriage_…` blocks (`## `-commented original bytes with an
`##gometa carriage v1` index header — invisible on the built site and absent from its
search index), while hidden lines of EXECUTED blocks stay in place natively
(`# hide`-suffixed lines and whole `@setup` bodies: they run at the docs build,
display-hidden, and their positions are recorded in each envelope's `hidden=`
indices). The reader twin is a VIEW: its trimmed sections travel nowhere and it
carries no envelopes. The FULL notebook edition is the same transformation in
notebook form (HTML comments in markdown cells, `gometa` cell metadata in code
cells); discarded lines travel nowhere in any edition.

Regenerate and byte-compare every GENERATED file (notebooks and pages) yourself:
`julia --startup-file=no --project=. notebooks_from_source.jl --check` — the executed
notebook edition carries real kernel outputs and is validated separately, outside
this byte gate.
