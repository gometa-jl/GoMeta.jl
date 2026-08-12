# reserved_adjacency_tests.jl — the directive-adjacency SHIPPED witnesses (APPEND-ONLY)
#
# IS:   the ship-class witness set for the directive-adjacency refusals (the 0.2.3
#       cure): a structural-directive form (`#-`/`#+`/`#[`/`#>` — prefix-fired, so
#       `#----` dividers and `#->` arrows are in the class) DIRECTLY adjacent to
#       metadata refuses EARLY and typed, at BOTH grains (same-line segment; next-line
#       LINE), instead of crashing raw (the pre-0.2.3 published behavior: a raw
#       MethodError, or a wrong-class "meta depth out of range" blaming a metaLine the
#       author never wrote).
# DOES: pins the refusal for the headline shapes of both grains + the documented escapes
#       (an interposed content line; `##`-initial dividers; an intervening benign
#       fragment) as byte-exact accepts, the refusal's determinism, and the per-grain
#       message distinction. The message pins derive from the live-measured refusal
#       bytes of THIS line and include per-grain clauses EXCLUSIVE to its widened
#       wording (a regression to the narrower pre-widening message text reds here,
#       not just a loss of the refusal); the measurement record lives in the
#       development fork's provenance ledger, never here.
# REASONING: the deep matrix (the reserved-syntax r6–r10 family: boundary corners,
#       CRLF twins) runs on the development line (the ship posture keeps it there);
#       THIS file is the shipped regression tripwire — the formerly-blind published
#       gate reds on a regression of the cure, the 0.2.2 unicode_cure_tests.jl pattern.
# PURPOSE: the published suite itself proves the 0.2.3 headline cure and its escapes.

using Test
import GoMeta as GM

_ra(s) = GM.goMeta(Vector{UInt8}(codeunits(s)))
_ra_render(s) = String(copy(GM.outputs(_ra(s)).render_bytes))
_ra_msg(s) = try
    _ra(s)
    nothing
catch e
    sprint(showerror, e)
end

@testset "reserved directive-adjacency witnesses (the 0.2.3 cure)" begin

    @testset "w1 :: segment grain — a directive fragment directly after an inline meta event refuses typed" begin
        for s in ("x = 1 #~ hide #- y\n",     # the headline same-line shape
                  "x = 1 #~ hide #----\n",    # ordinary divider run (prefix-fired)
                  "x = 1 #] #> y\n")          # closer-adjacent (no marker event)
            @test_throws ErrorException _ra(s)
            m = _ra_msg(s)
            @test m !== nothing && occursin("GoMeta parse: a structural-directive segment", m) &&
                occursin("separate the directive from the metadata", m) &&
                occursin("an intervening plain fragment", m)
        end
    end

    @testset "w2 :: line grain — a directive LINE directly after a metaLine/meta block refuses typed" begin
        for s in ("#~ hide{ :label1 }\n#----\nx = 2\n",  # annotation + ordinary divider line
                  "#~ :label1\n#> y\nx = 2\n",           # the #> twin (died at the re-match pre-cure)
                  "#~ hide{ :label1 }\n\n#----\nx = 2\n") # a blank line between does NOT defuse
            @test_throws ErrorException _ra(s)
            m = _ra_msg(s)
            @test m !== nothing && occursin("GoMeta parse: a structural-directive line", m) &&
                occursin("write the divider `##`-initial", m) &&
                occursin("a blank line between does not defuse", m)
        end
    end

    @testset "w3 :: the documented escapes stay byte-exact accepts" begin
        # escape #1 — an interposed content line defuses the class:
        @test _ra_render("#~ hide{ :label1 }\nx = 1\n#----\ny = 2\n") ==
            "#~ hide{ :label1 }\nx = 1\n#----\ny = 2\n"
        # escape #2 — a `##`-initial divider rides even a meta block inertly:
        @test _ra_render("#~ hide{ :label1 }\n##----\nx = 2\n") ==
            "#~ hide{ :label1 }\n##----\nx = 2\n"
        # escape #3 (segment grain) — an intervening benign fragment resets the context:
        @test _ra_render("x = 1 #~ hide # note #- y\n") == "## x = 1 ## #~ hide ## # note ## #- y\n"
        # directives AWAY from metadata are unaffected (file start; between code lines):
        @test _ra_render("#----\nx = 1\n") == "#----\nx = 1\n"
        @test _ra_render("x = 1\n#----\ny = 2\n") == "x = 1\n#----\ny = 2\n"
    end

    @testset "w4 :: deterministic + per-grain messages are distinct" begin
        a = _ra_msg("x = 1 #~ hide #- y\n")
        b = _ra_msg("x = 1 #~ hide #- y\n")
        @test a == b !== nothing
        c = _ra_msg("#~ :label1\n#- y\nx = 2\n")
        @test occursin("structural-directive line", c) && !occursin("structural-directive segment", c)
    end
end
