# tests/unit/ensure_token_tests.jl — WP1-W6 step (b): the ENSURE-TOKEN witness
# battery (SYNTHESIS-JUDGE §3 row WP1-W6 + §2 K1 + §4's W6 enumeration). The hide
# write is skipped iff (a) comment-classified + fold-prefixed (the R-2 fold,
# unchanged) OR (b) the source line's POST-INDENT head already begins with the
# flavor's `hide_marker` — the second disjunct, landed at W6; suppression applies
# at BOTH grains via the LINE-head predicate (probe-proven: the growing meta
# segment's slice never carries the marker, so only the line-head reading closes
# the `render ∘ ingest ∘ render == render` fixed point; plan
# probes/w6_probe_segment_hide.OUT.md).
#
# EVERY expected string below was PRE-DECLARED from measured pre-edit state
# BEFORE the step-(b) edit existed (the wording-intent rider 2 discipline; plan
# probes/w6_probe_prestepb.OUT.md carries the pre/post table) and then measured
# to hold — never fitted post-hoc.
#
# THE FIDELITY BOUND (the FOLDBACK #4 disclosure): an authored marker-headed
# line under hide renders AS-IS — byte-indistinguishable from engine-hidden
# output; hide stays never byte-reversible (already true under the R-2 fold).
# The A/B/F/G first renders below (render == source) ARE that bound, witnessed.

using Test
import GoMeta as GM

_et_bytes(s::String) = Vector{UInt8}(codeunits(s))
_et_jl = GM.GoMetaConfig()
_et_c  = GM.GoMetaConfig(flavor_tag = :c)
_et_lx = GM.GoMetaConfig(flavor_tag = :latex)

"""One render; returns the render bytes as String."""
function _et_r(s::AbstractString; cfg = _et_jl)
    r = GM.goMeta(_et_bytes(String(s)); config = cfg)
    _, x = GM.outputs(r)
    return String(copy(x))
end

"""render ∘ ingest ∘ render — the second render of the first render."""
_et_rr(s::AbstractString; cfg = _et_jl) = _et_r(_et_r(s; cfg = cfg); cfg = cfg)

@testset "ensure_token_tests (WP1-W6 step (b))" begin

    @testset "[1] engine-hidden re-ingestion: the fixed point, x3 flavors" begin
        ## The §4 head-shape (i): engine-hidden `## #~ hide` / `//# //~ hide` /
        ## `%% %~ hide` — one render then the fixed point, per flavor.
        @test _et_r("#~ hide\nx = 1\n")  == "## #~ hide\n## x = 1\n"
        @test _et_rr("#~ hide\nx = 1\n") == "## #~ hide\n## x = 1\n"
        @test _et_r("//~ hide\nint a;\n"; cfg = _et_c)  == "//# //~ hide\n//# int a;\n"
        @test _et_rr("//~ hide\nint a;\n"; cfg = _et_c) == "//# //~ hide\n//# int a;\n"
        @test _et_r("%~ hide\nalpha\n"; cfg = _et_lx)  == "%% %~ hide\n%% alpha\n"
        @test _et_rr("%~ hide\nalpha\n"; cfg = _et_lx) == "%% %~ hide\n%% alpha\n"
    end

    @testset "[2] authored comment head under hide: the (a) disjunct unchanged" begin
        ## The §4 head-shape (ii): comment-classified + fold-prefixed lines take
        ## no marker (today's R-2 fold — byte-identical to pre-W6 behavior).
        @test _et_r("#~ hide\n## note\nx = 1\n") == "## #~ hide\n## note\n## x = 1\n"
        @test _et_rr("#~ hide\n## note\nx = 1\n") == "## #~ hide\n## note\n## x = 1\n"
        ## Per-flavor EXACT-byte pins (panel cure: a fold-classification drift
        ## must surface as byte drift here, not hide behind the (b) disjunct).
        ## MEASURED 2026-08-10 (cure round): in :c the `// note` line is
        ## TEXT-class (takes a marker — unlike julia's `## note`); in :latex the
        ## `%% note` line is comment-classified (fold-suppressed, F-12 family).
        @test _et_r("//~ hide\n// note\nint f;\n"; cfg = _et_c) ==
              "//# //~ hide\n//# // note\n//# int f;\n"
        @test _et_rr("//~ hide\n// note\nint f;\n"; cfg = _et_c) ==
              "//# //~ hide\n//# // note\n//# int f;\n"
        @test _et_r("%~ hide\n%% note\nalpha\n"; cfg = _et_lx) ==
              "%% %~ hide\n%% note\n%% alpha\n"
        @test _et_rr("%~ hide\n%% note\nalpha\n"; cfg = _et_lx) ==
              "%% %~ hide\n%% note\n%% alpha\n"
    end

    @testset "[3] authored marker-head non-comment under hide: the (b) bite, x3 flavors" begin
        ## The §4 head-shape (iii): the authored marker-headed metaLine-carrying
        ## line (segmented; live self-hide) takes NO markers — render == source,
        ## the fixed point at n=0. THE FIDELITY BOUND witnessed: these authored
        ## forms are byte-indistinguishable from engine-hidden output.
        @test _et_r("x = 1\n## #~ hide\ny = 2\n")  == "x = 1\n## #~ hide\ny = 2\n"
        @test _et_rr("x = 1\n## #~ hide\ny = 2\n") == "x = 1\n## #~ hide\ny = 2\n"
        @test _et_r("//# //~ hide\nint a;\n"; cfg = _et_c)  == "//# //~ hide\nint a;\n"
        @test _et_rr("//# //~ hide\nint a;\n"; cfg = _et_c) == "//# //~ hide\nint a;\n"
        @test _et_r("%% %~ hide\nalpha\n"; cfg = _et_lx)  == "%% %~ hide\nalpha\n"
        @test _et_rr("%% %~ hide\nalpha\n"; cfg = _et_lx) == "%% %~ hide\nalpha\n"
    end

    @testset "[4] the INDENTED authored marker-head: the K1 post-indent discriminator" begin
        ## The brief-mandated indented variant: a column-0 implementation misses
        ## the post-indent marker head and writes `    ## ## #~ hide` — this row
        ## REDS on exactly that divergence (K1's post-indent qualifier is
        ## load-bearing; the check runs on lstrip of the source line).
        @test _et_r("    ## #~ hide\nx = 1\n")  == "    ## #~ hide\nx = 1\n"
        @test _et_rr("    ## #~ hide\nx = 1\n") == "    ## #~ hide\nx = 1\n"
        ## The indented PLAIN metaLine (no marker head): first render UNCHANGED
        ## (the marker precedes the preserved indent — pre-W6 bytes), then fixed.
        @test _et_r("    #~ hide\nx = 1\n")  == "##     #~ hide\n## x = 1\n"
        @test _et_rr("    #~ hide\nx = 1\n") == "##     #~ hide\n## x = 1\n"
    end

    @testset "[5] mid-line marker bytes UNTOUCHED: the check anchors at the head" begin
        @test _et_r("#~ hide\nx = ## y\n")  == "## #~ hide\n## x = ## y\n"
        @test _et_rr("#~ hide\nx = ## y\n") == "## #~ hide\n## x = ## y\n"
    end

    @testset "[6] the multi-segment fresh-hide: FIRST-render bytes must not move (K1 boundary)" begin
        ## Per-segment markers on a fresh inline hide — byte-identical to the
        ## pre-W6 first render; the fixed point closes only on re-ingestion.
        @test _et_r("x = 1 #~ hide\n")  == "## x = 1 ## #~ hide\n"
        @test _et_rr("x = 1 #~ hide\n") == "## x = 1 ## #~ hide\n"
        ## The trailing-comment multi-segment shape (fold at segment grain rides
        ## unchanged beside the new disjunct).
        @test _et_r("x = 1 ## note #~ hide\n")  == "## x = 1 ## note ## #~ hide\n"
        @test _et_rr("x = 1 ## note #~ hide\n") == "## x = 1 ## note ## #~ hide\n"
    end

    @testset "[7] the banked growth witnesses re-landed as fixed points (bases stated)" begin
        ## Fixture A (`"x = 1\n## #~ hide\ny = 2\n"`, `## ` count basis): the
        ## banked 3→7→15 was the PRE-fold shipped-twin lane; on the current
        ## engine the authored line is a segmented self-hide (measured, plan
        ## probes/w6_probe_prestepb.OUT.md) and W6 closes it at n=0 — count
        ## STABLE across renders. State the basis when quoting (the
        ## DIFFERENT-FIXTURE-BASES caution, ADJUDICATION_R2-vs-L18).
        let r1 = _et_r("x = 1\n## #~ hide\ny = 2\n"),
            r2 = _et_r(r1), r3 = _et_r(r2)
            @test count("## ", r1) == 1 && r2 == r1 && r3 == r2
        end
        ## PROBE A (`"x = 1 #~ hide\n"`, `## ` count basis; was 2→5→11 pre-fold,
        ## linear post-fold): now count 2 STABLE — the fixed point.
        let r1 = _et_r("x = 1 #~ hide\n"), r2 = _et_r(r1), r3 = _et_r(r2)
            @test count("## ", r1) == 2 && r2 == r1 && r3 == r2
        end
        ## The fork 2-line fixture (`"//~ hide\nint f;\n"`, `//# ` occurrence
        ## basis; 2→4 pre-fold, 2→3 post-fold): now 2 STABLE — the s2_battery
        ## row (w) twin, pinned here on the tests side.
        let r1 = _et_r("//~ hide\nint f;\n"; cfg = _et_c),
            r2 = _et_r(r1; cfg = _et_c)
            @test count("//# ", r1) == 2 && r2 == r1
        end
    end

    @testset "[8] the alphabet law: invalid bytes are CONTENT, the (b) head-read never throws" begin
        ## The step-(b) panel MAJOR-1 regression witness (cured 2026-08-10): a
        ## hidden line HEADING with an overlong sequence (0xE0 0x80 0x80 — the
        ## class bare `isspace` throws on at decode) must RENDER — the (b)
        ## disjunct rides the parser's own `_isspace_valid` guard; the parser
        ## classifies these bytes CONTENT and emit must agree. Confirmed thrown
        ## pre-cure, measured green post-cure (the measurement records live in the development fork).
        let src = Vector{UInt8}(vcat(codeunits("#~ hide\n"), UInt8[0xE0, 0x80, 0x80], codeunits("x\n")))
            r = GM.goMeta(copy(src); config = _et_jl)
            _, x = GM.outputs(r)
            r1 = String(copy(x))
            @test r1 == "## #~ hide\n## " * String(UInt8[0xE0, 0x80, 0x80]) * "x\n"
            @test _et_r(r1) == r1
        end
    end
end
