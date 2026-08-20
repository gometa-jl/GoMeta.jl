# inert_semantics_tests.jl — R-INERT-4 + §4.1 + §4.8 witnesses (the v0.3.1 rulings)
#
# IS:   the pinned test law of the v0.3.1 inert-marker fix: the DIFFERENTIAL ORACLE — `#~N! <content>` ≡ `#~N` (the
#       marker is structurally LIVE, only its content is ignored) — plus the bang-first refusal
#       and the Labels Alterant's empty-input guards.
# DOES: [O] table-drives the oracle over every specified shape class (status + evals rows equal;
#       renders equal after normalizing the metaLine's own bytes by the same truncation);
#       [R] pins the `#~!N` refusal in all three neighbourhoods at BOTH grains; [P] pins the
#       named post-fix outcomes (supersession, the cured swallow, SD-1's E-06, t_P6's
#       still-governable inert line); [G] pins the setLabels (LIST-side) §4.8 guard with the
#       positive controls — the checkLabels QUERY twin is witnessed by the flipped K2
#       (condition_interp_tests.jl); [U] pins the unchanged-by-ruling shapes.
# REASONING: the ≡ law is the RULING itself, so the oracle — not hand-picked expectations —
#       is the primary witness; hand-pins remain for the outcomes the sitting names, so a
#       regression flips a NAMED test. The bang-first family is the REFUSAL class, excluded
#       from the oracle by ruling (§4.1).
# PURPOSE: R-INERT-4 / SD-1 / SD-2 / §4.1 / §4.8 cannot drift silently.

using Test
import GoMeta as GM

_is(s) = GM.goMeta(Vector{UInt8}(codeunits(s)))
_is_render(s) = String(copy(GM.outputs(_is(s)).render_bytes))
_is_rows(s) = [(a, v, p) for (h, a, v, p) in GM.altValues_evals(_is(s))]
_is_msg(s) = try
    TestSupport.quiet_io(() -> _is(s))
    nothing
catch e
    sprint(showerror, e)
end
## FIXTURE CONSTRAINT: _liveempty truncates EVERY line matching the pattern from the bang to
## EOL — oracle rows must not carry the byte shape `#~N!` at a non-marker position (e.g.
## inside a code string); such a row would be silently mangled in the twin and the normalizer.
const _INERT_LINE_RE = r"^(.*?#~+[0-9]*)!.*$"
_liveempty(text) = join(
    [(m = match(_INERT_LINE_RE, l); m === nothing ? l : m.captures[1]) for l in split(text, '\n')],
    '\n')

@testset "inert semantics (R-INERT-4 + §4.1 + §4.8)" begin

    @testset "[O] the differential oracle — #~N! content ≡ #~N (per shape class)" begin
        for src in (
            "#~0! hide{ isText }\n\n# T\n",              # detached, depth 0
            "#~! hide{ isText }\n\n# T\n",               # bare
            "#~1! hide{ isText }\n# T\n",                # attached, depth 1
            "#~2 hide{ isText }\n# A\n\n#~2! hide{ isText }\n# B\n",   # the p_discrim2 shape
            "#~2 hide{ isText }\n# A\n\n#~2! show{ isText }\n# B\n",   # inert show after hide
            "#~2! :label2\n#~2 :label1\n# B\n",          # inert-first mixed run
            "#~2 :label1\n#~2! :label2\n# B\n",          # inert non-first
            "#~2 :label1\n#~! foo\n#~2 :label2\n# T\n",  # mid-run continuation (Extended-L10 class)
            "#~2! hide{ isText }\n# A\n\n#~2! hide{ isText }\n# B\n",  # two inert blocks
            "#~ hide{ isMeta }\n\n#~2! show{ isMeta }\n# T\n",         # t_P6: governable inert
            "#~2 hide{ isText }\n# A\n\n#~2! :label1\n# B\n\n#~3 :label2\n# C\n",  # deeper re-entry
            "# T #~0! hide{ isText }\n# U\n",            # inline Segment grain (SD-2)
            "x = 1 #~2! hide{ isCode }\ny = 2\n",        # inline on Code (SD-2)
            "#~0! \"Title\"\n# T\n",                     # heading-content inert
            "#~ discard{ isText }\n\n#~2! x\n# B\n",     # a standing discard shield holds through an inert head
            "#~ hide{ isText }\n\n#~2! x\n# B\n",        # the shallow depth-1 rule survives a depth-2 inert head
            "#~2 hide{ isText }\n# A\n#~2! x\n# B\n",    # the glued sandwich (no blanks)
            "#~ hide{ isText }\n\n#~2! x\n# B\n\n#~2 :label1\n# C\n",  # the owner's own 3-block example
        )
            twin = _liveempty(src)
            r_i, r_l = _is(src), _is(twin)
            @test string(r_i.status) == string(r_l.status)
            @test [(a, v, p) for (h, a, v, p) in GM.altValues_evals(r_i)] ==
                  [(a, v, p) for (h, a, v, p) in GM.altValues_evals(r_l)]
            @test _liveempty(String(copy(GM.outputs(r_i).render_bytes))) ==
                  _liveempty(String(copy(GM.outputs(r_l).render_bytes)))
            # §4.4: the inert metaLine's OWN bytes travel VERBATIM in the render ('!' and
            # content included; a standing hide may `## `-prefix the line — substring holds).
            # Asserted RAW, before _liveempty, so the normalizer stays a comparison aid,
            # never a blind spot.
            ren_raw = String(copy(GM.outputs(r_i).render_bytes))
            for l in split(src, '\n')
                if match(_INERT_LINE_RE, l) !== nothing
                    @test occursin(l, ren_raw)
                end
            end
        end
    end

    @testset "[O2] the oracle holds THROWN too: #~9! ≡ #~9 (both refuse E-06 — SD-1)" begin
        m_i = _is_msg("#~9! hide{ isText }\n# T\n")
        m_l = _is_msg("#~9\n# T\n")
        @test m_i !== nothing && m_l !== nothing
        @test occursin("meta depth out of range", m_i)
        @test occursin("meta depth out of range", m_l)
        # the retired dw5 pin's exact input (bare `#~9!`, no content) — refusal, not passthrough:
        @test occursin("meta depth out of range", something(_is_msg("#~9!\nx\n"), ""))
    end

    @testset "[R] bang-first #~!N refuses in every neighbourhood, both grains (§4.1)" begin
        for s in ("#~!0 hide{ isText }\n# t\n",          # file start (was: Text)
                  "x = 1\n#~!0 hide{ isText }\n# t\n",   # after code (was: Code)
                  "#~2 :label1\n#~!0 hide{ isText }\n# t\n",   # in a meta run (was: inert Meta)
                  "#~2 :label1\n\n#~!0 hide{ isText }\n#~2 hide{ isText }\n# B\n", # block-first in meta ctx
                  "#~!2 hide{ isText }\n# t\n")          # non-zero digit
            m = _is_msg(s)
            @test m !== nothing
            @test occursin("GoMeta parse: bang-first meta marker", m)
            @test occursin("TRAILING bang", m)
        end
        # the message carries the CORRECTED spelling for the matched marker:
        @test occursin("\"#~2!\"", _is_msg("#~!2 hide{ isText }\n# t\n"))
        # the INLINE-Segment grain refuses identically (the refusal covers BOTH grains):
        for s in ("x = 1 #~!2 hide{ isCode }\ny = 2\n",
                  "# T #~!0 hide{ isText }\n# U\n")
            m = _is_msg(s)
            @test m !== nothing && occursin("bang-first meta marker", m)
        end
        # the refused family INCLUDES an optional trailing bang — `#~!N!` refuses too:
        @test occursin("bang-first meta marker", something(_is_msg("#~!2! hide{ isText }\n# t\n"), ""))
        # MENTION neighbourhoods (probe-pinned): a ws-preceded un-glued `#~!N`
        # refuses even inside `# `-prose, a prose code fence, and a multiline string —
        # consistent with the standing law (un-glued markers are LIVE in prose; string
        # literals are not parsed; the quote-glue escape is the documented way to mention):
        for s in ("# ```julia\n# #~!2 hide{ isText }\n# ```\n# after\n",
                  "# We write #~!2 as a WRONG example here.\n# next\n",
                  "\"\"\"\na docstring mentioning #~!2 inside\n\"\"\"\nx = 1\n")
            @test occursin("bang-first meta marker", something(_is_msg(s), ""))
        end
        # glued and MULTI-bang shapes stay bucket-(A) user content — NOT refused (the family
        # is exactly tildes + ONE `!` + digits [+ one trailing `!`], ws/EOL-terminated):
        @test _is("#~!0x hide\n# t\n").status == GM.PROCESS_OK
        @test _is("#~!!0 hide\n# t\n").status == GM.PROCESS_OK
        # the POSITIVE mention escape (probe-pinned):
        # a quote-GLUED "#~!2" is plain content in every neighbourhood — the glued opening
        # quote blocks dispatch (the before-the-lead whitespace law) and a glued trailing
        # byte de-families the shape — so the escape the docs teach (S&S §1/§9) provably
        # works: PROCESS_OK, ZERO evals rows, byte-identical render:
        for s in ("# We write \"#~!2\" as the wrong example here.\n# next\n",
                  "x = \"#~!2\"\ny = 1\n",
                  "x = 1  # see \"#~!2\" in prose\ny = 2\n")
            r = _is(s)
            @test r.status == GM.PROCESS_OK
            @test isempty(GM.altValues_evals(r))
            @test String(copy(GM.outputs(r).render_bytes)) == s
        end
    end

    @testset "[P] named post-fix outcomes (the sitting §8)" begin
        # supersession: the inert depth-2 sibling retires the earlier depth-2 rule — B SHOWN:
        r = _is("#~2 hide{ isText }\n# A\n\n#~2! hide{ isText }\n# B\n")
        @test [(a, v) for (h, a, v, p) in GM.altValues_evals(r)] == [(:visib, :hide)]
        @test occursin("\n# B", String(copy(GM.outputs(r).render_bytes)))
        # the cured swallow: a live metaLine after an inert first line ABSORBS:
        r2 = _is("#~2! :label2\n#~2 :label1\n# B\n")
        @test any(a == :label_label1 for (h, a, v, p) in GM.altValues_evals(r2))
        @test !any(a == :label_label2 for (h, a, v, p) in GM.altValues_evals(r2))
        # security hand-pin: a standing discard still discards THROUGH an inert head
        # (the rejected L3 design's travel hole can never open):
        rd = _is("#~ discard{ isText }\n\n#~2! x\n# B\n")
        @test !occursin("# B", String(copy(GM.outputs(rd).render_bytes)))
        @test any(a == :visib && v == :discard for (h, a, v, p) in GM.altValues_evals(rd))
        # t_P6: the inert metaLine itself stays governable (altValue ON it, never FROM it):
        r3 = _is("#~ hide{ isMeta }\n\n#~2! show{ isMeta }\n# T\n")
        @test occursin("## #~2! show{ isMeta }", String(copy(GM.outputs(r3).render_bytes)))
        @test occursin("\n# T", String(copy(GM.outputs(r3).render_bytes)))
    end

    @testset "[G] the Labels Alterant guards (§4.8: in-Alterant, seam-verbatim)" begin
        for s in ("#~0 :\n# T\n", "#~0 :()\n# T\n")
            m = _is_msg(s)
            @test m !== nothing
            @test occursin("empty label list", m)
        end
        # positive control — a named label still lands:
        r = _is("#~0 :label1\n# T\n")
        @test any(a == :label_label1 for (h, a, v, p) in GM.altValues_evals(r))
        # the inert exemption (R-INERT-4: content never read — no guard can fire):
        @test _is("#~2! :\n# T\n").status == GM.PROCESS_OK
        # the neighbouring malformation keeps its own family:
        @test occursin("unknown label", something(_is_msg("#~ :(,)\n# T\n"), ""))
    end

    @testset "[U] unchanged-by-ruling shapes stay unchanged" begin
        # a live metaLine glued directly under `#]` is still skipped (the close-marker-headed
        # block keeps :ignoreThisMeta — the unchanged family remainder):
        r = _is("#~2 :label1\n# A\n#]\n#~2 hide{ isText }\n# B\n")
        @test !any(a == :visib for (h, a, v, p) in GM.altValues_evals(r))
        # a comment-headed post-blank meta block still conducts without absorbing its head:
        r2 = _is("#~2 :label1\n\n## c\n#~2 hide{ isText }\n# B\n")
        @test !any(a == :visib for (h, a, v, p) in GM.altValues_evals(r2))
        @test any(a == :label_label1 for (h, a, v, p) in GM.altValues_evals(r2))
    end
end
