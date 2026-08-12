# tests/unit/latex_flavor_tests.jl — WP1-W5 (F-22): the FLAVOR_LATEX data point —
# THE ACCEPTANCE PROOF's witness battery (SYNTHESIS-JUDGE §3 row WP1-W5; the .tex
# classification vocabulary per the owner's N-4 ruling = the cfam-parallel
# default). Every tree/render pin below was MEASURED AT BIRTH (the probe run
# preceding this file — empirical-first; goldens-additive-only honored: the pins
# live HERE, the golden layer's files untouched).
#
# THE WAVE'S MECHANICAL FALSIFIER (checked at the close, not here): the W5 diff
# names NO parser file and the parseBLS.jl pin is UNCHANGED — the reader below is
# the SAME parseLeadHeader! both prior flavors ride; this file witnesses that the
# RECORD alone carries the third flavor.

using Test
import GoMeta as GM
const _LX_BLS = GM.BLS

_lx_bytes(s::String) = Vector{UInt8}(codeunits(s))
_lx_cfg = GM.GoMetaConfig(flavor_tag = :latex)
function _lx_run(s::String)
    r = GM.goMeta(_lx_bytes(s); config = _lx_cfg)
    t, x = GM.outputs(r)
    return r, String(copy(t)), String(copy(x))
end

@testset "latex_flavor_tests (WP1-W5 pure-data flavor)" begin

    @testset "[1] the record: pure data, the shared reader, the shared strategy" begin
        lx = _LX_BLS.FLAVOR_LATEX
        @test lx isa _LX_BLS.FlavorProfile
        @test lx.flavor_tag === :latex
        @test lx.lead == "%" && lx.comment_run_char == '%'
        @test lx.hide_marker == "%% " && lx.hide_fold_prefix == "%%"
        @test lx.extensions == (".tex",)
        ## The 1-cu lead exercises the width arithmetic beside :c's 2-cu history
        ## (the judgment row's lead_ncu-pinned-from-both-sides clause).
        @test lx.lead_ncu == 1 && lx.lead_cus == (UInt8('%'),)
        ## ZERO new parser code: the SAME reader + strategy as every armed flavor.
        @test lx.parse_header! === _LX_BLS.parseLeadHeader!
        @test lx.header_strategy === :table_v1
        ## N-4: the cfam-parallel vocabulary — comment policies, lax runs, no fences.
        @test lx.glued_policy === :comment && lx.bare_policy === :comment
        @test !lx.comment_run_strict && !lx.fences_armed
        ## The deletion-note shape: four :absent + the claimed ws-strict close.
        @test all(r -> r.status === :absent, lx.directives[1:4])
        @test lx.directives[5].status === :claimed && lx.directives[5].ws_strict
        ## Cross-flavor digest distinctness (property, no pinned constant).
        @test lx.digest != _LX_BLS.FLAVOR_JULIA.digest
        @test lx.digest != _LX_BLS.FLAVOR_CFAM.digest
    end

    @testset "[2] the inventory rows: flavor_for + validate_config" begin
        @test _LX_BLS.flavor_for(:latex) === _LX_BLS.FLAVOR_LATEX
        r_ok = GM.goMeta(_lx_bytes("x 1\n"); config = _lx_cfg)
        @test r_ok.status === GM.PROCESS_OK
        @test r_ok.state.parse.flavor === _LX_BLS.FLAVOR_LATEX
        r_bad = GM.goMeta(_lx_bytes("x\n");
            config = GM.GoMetaConfig(flavor_tag = :tex))
        @test r_bad.status === GM.PROCESS_ERROR
        @test any(d -> d.code === :ERR_UNKNOWN_FLAVOR, r_bad.diagnostics)
    end

    @testset "[3] %~ mint — tree + render pinned at birth" begin
        r, t, x = _lx_run("%~ hide\nx 1\ny 2\n")
        @test r.status === GM.PROCESS_OK
        @test t == "{:B-Meta:L-Meta [%~ hide]}\n{:B-Code:L-Code [x 1]}\n{       :L-Code [y 2]}\n"
        @test x == "%% %~ hide\n%% x 1\n%% y 2\n"
    end

    @testset "[4] inline %~ lifts to LINE grain (the trap-4 law, third flavor)" begin
        r, t, x = _lx_run("x 1 %~ hide\ny 2\n")
        @test r.status === GM.PROCESS_OK
        @test t == "{:B-Code:L-Code [{:S-Code [x 1 ]}{:S-Meta [%~ hide]}]}\n{       :L-Code [y 2]}\n"
        @test x == "%% x 1 %% %~ hide\ny 2\n"
    end

    @testset "[5] glued %~hide is an ordinary comment — NEVER meta (F-13 under :comment policy)" begin
        r, t, x = _lx_run("%~hide\nx 1\n")
        @test r.status === GM.PROCESS_OK
        @test t == "{:B-Text:L-Text [%~hide]}\n{:B-Code:L-Code [x 1]}\n"
        @test x == "%~hide\nx 1\n"
        @test isempty(GM.altValues_evals(r))
    end

    @testset "[5b] `% `-led is the TEXT arm (N-4's second clause — the W5-panel cure)" begin
        r, t, x = _lx_run("% plain text\nx 1\n")
        @test r.status === GM.PROCESS_OK
        @test t == "{:B-Text:L-Text [% plain text]}\n{:B-Code:L-Code [x 1]}\n"
        ## `% ` TEXT lacks :comment ⇒ NOT fold-eligible: hidden, it TAKES the
        ## marker (the record's own class-split annotation, now pinned).
        rh, th, xh = _lx_run("%~ hide\n% plain text\nx 1\n")
        @test xh == "%% %~ hide\n%% % plain text\n%% x 1\n"
    end

    @testset "[6] %-runs are comments at EVERY length (N-4 lax runs) + the %% hide-fold" begin
        r, t, x = _lx_run("%% note\n%%% more\nx 1\n")
        @test r.status === GM.PROCESS_OK
        @test t == "{:B-Text:L-Text [%% note]}\n{       :L-Text [%%% more]}\n{:B-Code:L-Code [x 1]}\n"
        @test x == "%% note\n%%% more\nx 1\n"
        ## The F-12 fold: a %%-led COMMENT line inside a hidden span takes NO
        ## additional marker (fold-eligible); non-comment lines take "%% ".
        rf, tf, xf = _lx_run("%~ hide\n%% already\nx 1\n")
        @test xf == "%% %~ hide\n%% already\n%% x 1\n"
    end

    @testset "[7] %] close — ws-strict, the flag set from the original" begin
        r, t, x = _lx_run("%~ :label1\nx 1\n%] tail\ny 2\n")
        @test r.status === GM.PROCESS_OK
        @test t == "{:B-Meta:L-Meta [%~ :label1]}\n{:B-Code:L-Code [x 1]}\n{:B-Meta:L-Meta [%] tail]}\n{:B-Code:L-Code [y 2]}\n"
        ## The label reaches the closer line but NOT past it (:stopAttachmentToMeta).
        ev = String(copy(GM.serialize_evals(r)))
        @test count("label_label1", ev) == 3
        ## Glued %]x = an ordinary comment, never a close event.
        rg, tg, xg = _lx_run("%]x\nx 1\n")
        @test tg == "{:B-Text:L-Text [%]x]}\n{:B-Code:L-Code [x 1]}\n"
    end

    @testset "[8] the four reserved arms are PLAIN COMMENTS — no restructuring (INTERIM law)" begin
        r, t, x = _lx_run("%- y\n%+ y\n%> y\n%[ y\nx 1\n")
        @test r.status === GM.PROCESS_OK
        ## ONE Text block — a stray %-directive shape can never split blocks.
        @test t == "{:B-Text:L-Text [%- y]}\n{       :L-Text [%+ y]}\n{       :L-Text [%> y]}\n{       :L-Text [%[ y]}\n{:B-Code:L-Code [x 1]}\n"
        @test isempty(GM.altValues_evals(r))
    end

    @testset "[9] the verbatim DECLINED bound — %~ inside \\begin{verbatim} IS live (witnessed)" begin
        r, t, x = _lx_run("\\begin{verbatim}\n%~ hide\n\\end{verbatim}\nx 1\n")
        @test r.status === GM.PROCESS_OK
        ## fences_armed=false: no environment tracking — the interior metaLine
        ## mints and HIDES the rest (incl. the \\end line). The recorded bound,
        ## pinned so any future environment-model lands as a CONSCIOUS change.
        @test x == "\\begin{verbatim}\n%% %~ hide\n%% \\end{verbatim}\n%% x 1\n"
    end

    @testset "[10] the newline-eating hide hazard — doc + fixture (the typeset bound)" begin
        r, t, x = _lx_run("a line\n%~ hide\nhidden line\nafter\n")
        @test x == "a line\n%% %~ hide\n%% hidden line\n%% after\n"
        ## THE BOUND (doc row): each "%% …" hidden line is a TeX comment whose %
        ## consumes the line's own newline at TYPESET time — consecutive hidden
        ## lines join in the typeset stream (spacing-visible, content-invisible).
        ## GoMeta's render keeps the newline BYTES (byte-fidelity law); the
        ## typeset behavior is the host's. Catcode redefinitions of % are out of
        ## scope (the trigraph-class posture).
    end

    @testset "[11] %~9 depth refusal reaches through (the shared window law)" begin
        @test_throws ErrorException GM.goMeta(_lx_bytes("%~9 x\nx 1\n"); config = _lx_cfg)
        m = try GM.goMeta(_lx_bytes("%~9 x\nx 1\n"); config = _lx_cfg); ""
            catch e sprint(showerror, e) end
        @test occursin("meta depth out of range", m)
    end

    @testset "[12] the synthetic composition witness (the CRX design-set adoption): sentinel-before-width is TESTABLE" begin
        ## No ARMED flavor combines a sentinel-capable reader with a multi-unit
        ## lead — a SYNTHETIC profile does, making the _lead_head! composition
        ## ORDER mechanically observable: with the sentinel tested on the RAW
        ## return (correct), raw 0 ⇒ (true, lead_ncu-1+1); with the width added
        ## first (the defect class), the sentinel test could never see the 0.
        sentinel_reader(profile, sub, s) = 0
        ## The :julia tag is REUSED deliberately: the INTERIM reserved-arms law
        ## admits claimed directive rows for :julia only, and this synthetic
        ## borrows julia's claimed rows — a future tag↔record coupling guard
        ## must re-point this witness consciously (W5-panel note, recorded).
        syn = _LX_BLS._mk_flavor(; flavor_tag = :julia, lead = "!!",
            comment_run_char = '!', hide_marker = "!!x ", hide_fold_prefix = "!!",
            extensions = (".syn",),
            directives = _LX_BLS.FLAVOR_JULIA.directives,
            glued_policy = :content, bare_policy = :content,
            parse_header! = sentinel_reader, fences_armed = false,
            comment_run_strict = true, header_strategy = :table_v1)
        s = _LX_BLS.ComponentSettribute()
        (bucketA, off) = _LX_BLS._lead_head!(syn, "!! x", 1, s)
        @test bucketA === true
        @test off == 2   # (lead_ncu-1) + 1 — the sentinel mapped BEFORE the width term
    end
end
