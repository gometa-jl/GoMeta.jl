# tests/unit/unicode_cure_tests.jl — the Unicode-correctness cure witnesses.
# THE CURE: the condition scanner's end-of-text test is the CHAR predicate (lastCharInd =
# lastindex), so end-of-text is just another delimiter — a multibyte-FINAL atom flush
# against the closing brace takes its ORDINARY vocabulary fate (flush ≡ spaced). The
# companion U2 cure widens the content slice's final character (nextind; the slice is `BLS.content`'s since stage 2), keeping a
# multibyte final character whole in the slice the door hands out and in every derived content payload ([6] holds it).
# Every assertion below pins a MEASURED value. GENERATED file:
# exotic characters are REAL codepoints, byte-verified at authoring.
# v0.4 T4 HAND-EDIT (T4B-3) and stage 5's E9 HAND-EDIT: testset [7]'s membership probes read the plain
# shipped list (`GM.Alterants.LABELS_VOCABULARY`; the G-VOC surface left at E9 — census row 28); testset [2]
# applies its unknown labels instead of querying them (a queried unknown label answers false since E9 —
# census row 55). Assert-count neutral. Stage 5's E13 HAND-EDIT: the closed interpreter left (census row 1; R-V04B-106) — testsets
# [1], [3] and [5] drove `parse_condition` and `print_condition` directly (E13); they drive the whole run now (the same shapes END-TO-END,
# 37 → 34 asserts: [1] 4 → 3, [3] 3 → 2, [5] 4 → 3). The CURE this file holds — a multibyte-final atom flush against the closing
# brace takes its ordinary fate — is held by the rewrite's CHAR walk (never the legacy's byte-count end test); [1] and [4] carry the
# flush shapes; the known-label asserts of [3] and [7] fix where a name ends (the s5c37 HAND-EDIT of 2026-10-09 — the closing set's row
# L4 r2, his word §383; each count MEASURED on the s5c37 scratch from the FULL delivery view, PROBES-s5c37-witness-values_on-0cf389d4.txt). The s5close HAND-EDIT
# (2026-10-09): the header's store clause above re-cut to the door's slice (the Engine stores no copy). The stage-2 HAND-EDIT of the Alterants build
# (2026-10-16): [7]'s membership comment re-cut — the constant is the Labels Alterant's hard-coded list in `alterants-std/labels.jl` since
# that stage (R-ALT-20), the plain file gone; assert-count neutral. A regeneration of this file must re-apply all six forms.

using Test
import GoMeta as GM

_uc_full(s)    = GM.goMeta(Vector{UInt8}(s))
_uc_err(s)     = try _uc_full(s); nothing catch e sprint(showerror, e) end

@testset "unicode_cure_tests (the char end predicate + the store widening)" begin

    @testset "[1] flush ≡ spaced: multibyte-final atoms take the ordinary vocabulary fate" begin
        # a label test flush against the closing brace, three multibyte finals (stage 5's E13: end-to-end — the query of an
        # unknown label answers false, the run is PROCESS_OK; the former direct parse pins left with the interpreter)
        @test _uc_full("#~ hide{ :aß}\nx = 1\n").status == GM.PROCESS_OK     # the d2 twin, flush at end-of-text
        @test _uc_full("#~ hide{ :é}\nx = 1\n").status == GM.PROCESS_OK
        @test _uc_full("#~ hide{ :🔥}\nx = 1\n").status == GM.PROCESS_OK
    end

    @testset "[2] store-present flush trio: apply's unknown-label names the FULL token" begin
        # Witness note: 🔥 joined the pictograph whitelist at 0.3.0, so it can no longer
        # serve as the UNKNOWN-label witness — 🐙 (not whitelisted) carries the
        # multibyte-final role in its place. Since stage 5's E9 the refusal lives in the SET
        # role alone (a queried unknown label answers false), so the witness APPLIES the label.
        for (lbl,) in (("é",), ("🐙",), ("aß",))
            m = _uc_err("#~ :" * lbl * "\nx = 1\n")
            @test m !== nothing
            @test occursin("unknown label", m)
            @test occursin("\"" * lbl * "\"", m)   # the FULL token, never truncated
        end
    end

    @testset "[3] multibyte-WHITESPACE-final flush (the analytically-traced path, executed)" begin
        # NBSP-final, flush against the brace (a REAL codepoint, this file's convention): the label name ends at the Unicode
        # whitespace (the ws-alphabet law); Julia's parser reads the NBSP as whitespace (MEASURED at the E13 build) — the
        # run is PROCESS_OK, the unknown label false
        @test _uc_full("#~ hide{ :x }\nx = 1\n").status == GM.PROCESS_OK
        @test _uc_full("#~ hide{ :x  }\nx = 1\n").status == GM.PROCESS_OK
        # the KNOWN label set, then queried with the NBSP flush before the brace: the name walk ENDS at the Unicode whitespace (the ws-alphabet
        # law) and the known label applies — a walk that swallowed the NBSP would query an unknown name, false, 2 rows; MEASURED on the s5c37
        # scratch at 0cf389d4 from the FULL delivery view: 4 rows (PROBES-s5c37-witness-values_on-0cf389d4.txt [A]; the closing set's row L4 r2)
        r = _uc_full("#~ :label1 hide{ :label1 }\nx = 1\n")
        @test r.status == GM.PROCESS_OK && length(GM.readAltValuesEvals(r.altValues_evals)) == 4
    end

    @testset "[4] CAL-14 + the honest worst case (comma-OR, unknown silently false)" begin
        g = _uc_full("#~ hide{ isCode , :zzz9 }\nx = 1\n")
        @test g.status == GM.PROCESS_OK           # ASCII control row
        @test length(GM.readAltValuesEvals(g.altValues_evals)) == 1
        u = _uc_full("#~ hide{ isCode , :é}\nx = 1\n")   # U1-16: formerly ABORTED
        @test u.status == GM.PROCESS_OK           # now renders WITH hide applied —
        @test length(GM.readAltValuesEvals(u.altValues_evals)) == 1  # measured + pre-registered
    end

    @testset "[5] parity and the quirk (stage 5's E13: the atom wall KP-1 left with the interpreter — a 40-character label is a label test)" begin
        # KP-3b: cross-width parity — 28 two-byte chars ≡ 28 one-byte chars, both PROCESS_OK (unknown labels, false)
        @test _uc_full("#~ hide{ :" * repeat("é", 28) * " }\nx = 1\n").status == GM.PROCESS_OK
        @test _uc_full("#~ hide{ :" * repeat("a", 28) * " }\nx = 1\n").status == GM.PROCESS_OK
        # QK-1: the glued-')' quirk is Julia's own ParseError since E13 (the former coded ERR_CONDITION_PARSE)
        @test (try _uc_full("#~ hide{ :(:x)) }\nx = 1\n"); nothing catch e; e end) isa Base.Meta.ParseError
    end

    @testset "[6] U2: a multibyte FINAL character survives the content slice whole (the Segment through the door; every derived payload valid UTF-8)" begin
        # the metaSegment's content bytes through the door (`BLS.content` — the slice the cure widened; the Engine stores no copy
        # since commit 9b) end with the COMPLETE final character (NBSP c2 a0), not a lone lead byte — the widened nextind slice.
        # Since stage 5's E1 (R-V04B-98) no row is keyed on a Segment — the inline heading's row keys on its LINE with the Segment
        # as the key's origin — so the TEST LAYER's derived five-column form shows the LINE's content for it (ending in `c`); the
        # Segment's slice is read here through the door (MEASURED 2026-10-03: Line 1's Segments [x = 1 ] [#~ "T" + NBSP] [## c]),
        # and every derived payload is still checked for valid UTF-8.
        s = "x = 1 #~ \"T\" ## c\ny = 2\n"
        r = _uc_full(s)
        @test r.status == GM.PROCESS_OK
        t = r.blsComponentTree
        seg = GM.BLS.children(t, first(GM.BLS.children(t, first(GM.BLS.children(t)))))[2]   # Line 1's metaSegment
        c = GM.BLS.content(t, seg)
        @test length(c) >= 2 && c[end-1] == 0xc2 && c[end] == 0xa0                          # the slice ends with the whole NBSP
        rows = [split(l, '\t') for l in split(String(TestSupport.derive_annotations_golden(r)), '\n'; keepempty = false) if !startswith(l, "#")]
        @test !isempty(rows)
        for cols in rows
            # every derived content payload must be valid UTF-8 when the source is
            @test isvalid(String(copy(hex2bytes(cols[5]))))
        end
    end

    @testset "[7] the pictograph label vocabulary (0.3.0): byte-exact, both roles" begin
        # The fixed pictograph names are whitelist members BYTE-EXACTLY — incl. the
        # regional-indicator pair and a ZWJ sequence; a variation-selector-less base
        # char is a DIFFERENT byte sequence and refuses like any unknown name.
        for name in ("⛔", "💯", "🇨🇭", "⛓️‍💥", "🌛", "💫")
            @test Symbol(name) ∈ GM.Alterants.LABELS_VOCABULARY   # the Labels Alterant's hard-coded list (stage 2 of the Alterants build; the plain file's until then — stage 5's E9)
        end
        r = _uc_full("#~ :⛔ hide{ :⛔ }\n# content\n")
        @test r.status == GM.PROCESS_OK           # set role + condition role, end-to-end
        # the pictograph label FLUSH against the brace (the multibyte-final atom flush this file's cure holds): the name is read whole to the
        # body's end and the known label applies — read short it would be unknown, false, 2 rows (the legacy's byte-count end test threw);
        # MEASURED on the s5c37 scratch at 0cf389d4 from the FULL delivery view: 4 rows (PROBES-s5c37-witness-values_on-0cf389d4.txt [B]; the closing set's row L4 r2)
        r7 = _uc_full("#~ :⛔ hide{ :⛔}\nx = 1\n")
        @test r7.status == GM.PROCESS_OK && length(GM.readAltValuesEvals(r7.altValues_evals)) == 4
        @test Symbol("⛓") ∉ GM.Alterants.LABELS_VOCABULARY   # no VS16 ⇒ unknown
        m = _uc_err("#~ :⛓\n# content\n")
        @test m !== nothing && occursin("unknown label", m)
    end
end
