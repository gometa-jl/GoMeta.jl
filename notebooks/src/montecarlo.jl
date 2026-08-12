# # Estimating pi by throwing darts
#
# An ordinary Julia file: `include("montecarlo.jl")` runs it top to bottom.
# Every notebook and manual page beside it is DERIVED from this one file by
# `notebooks_from_source.jl` — purely from the `#~` marks you see below.
#
# The label legend for this file (the five shipped labels, bound by this
# project's own convention — the legend is data, not engine vocabulary):
#   :label1 = parameters   :label2 = expensive   :label3 = solution
#   :label4 = deep-dive    :label5 = private
#~ discard{ :label5 }

# ## Parameters

#~2 :label1
n_darts  = 10_000
rng_seed = 2026

# ## The estimator
# A dart lands uniformly in the unit square; the quarter-circle catches
# pi/4 of them — so four times the hit fraction estimates pi:
#
# ```jldoctest
# julia> round(4 * atan(1); digits = 4)   # the target the darts approach
# 3.1416
# ```

using Random
function estimate_pi(n; rng = MersenneTwister(rng_seed))
    hits = count(_ -> rand(rng)^2 + rand(rng)^2 <= 1, 1:n)
    println("hit count was ", hits)  #~ discard
    4 * hits / n
end
estimate_pi(n_darts)

# ## Exercise
# Rewrite the estimator so it draws both coordinates in one pass and
# measure the speedup.

#~2 :label3
function estimate_pi_fused(n; rng = MersenneTwister(rng_seed))
    hits = 0
    for _ in 1:n
        hits += ifelse(rand(rng)^2 + rand(rng)^2 <= 1, 1, 0)
    end
    4 * hits / n
end
estimate_pi_fused(n_darts)

# ## Convergence study
# More darts, better estimate — this cell is marked expensive: automated
# executors that honor the `skip-execution` tag (nbclient, nbconvert) skip
# it; an interactive Run All does not, so plain `include` and interactive
# runs keep a fast default unless you opt in with the environment variable.

#~2 :label2
n_many = get(ENV, "DARTS_FULL", "") == "" ? 100_000 : 100_000_000
estimate_pi(n_many)

# ## Why the error falls like one over sqrt of n

#~2 :label4
# The hit count is a Binomial sum, so the estimator's standard error is
# `4 * sqrt(p * (1 - p) / n)` with `p = pi / 4`. Doubling the dart count
# divides the error by sqrt of 2 — the check below is a doctest the
# derived manual pages carry only where this deep-dive section survives:
#
# ```jldoctest
# julia> round(4 * sqrt((pi / 4) * (1 - pi / 4) / 10_000); digits = 4)
# 0.0164
# ```

#~2 :label4
se(n) = 4 * sqrt((pi / 4) * (1 - pi / 4) / n)
se(10_000)
#]
# The section above closed; this line is deliberately detached from it.

#~2 :label5
# Synthetic PRIVATE sentinel (stands in for real notes-to-self; in real use
# the source file stays private and only derived views are shared — here the
# source ships too, so you can diff source against views yourself):
# tried stratified sampling here; abandoned — rethink the seeding first.
