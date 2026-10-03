# tests/unit/token_law_tests.jl — F-13 TOKEN-DELIMITER LAW verification matrix (owner-ruled
# 2026-08-08; the spec is recorded in the development fork).
#
# THE LAW: every GoMeta marker token requires whitespace-or-line-boundary BEFORE and AFTER
# its head; a shape failing the after-side is bucket (A) — PLAIN CONTENT of its
# neighbourhood (inherited contentType, no `:comment`, no meta semantics, never refused).
# The owner's reason, verbatim anchor: `someCharacters##someMoreCharacters` and
# `someCharacters#~someMoreCharacters` MUST be writable as plain content.
#
# Rows carry their amendment referent. Value-vs-delimitation: ws-delimited malformed
# BODIES still refuse loudly (`#~9 ` E-06); only token RECOGNITION is gated by the law.

using Test
import GoMeta as GM

_tl_r(s; flavor=nothing) = begin
    cfg = flavor === nothing ? GM.GoMetaConfig() : GM.GoMetaConfig(flavor_tag=flavor)
    GM.goMeta(Vector{UInt8}(s); config=cfg)
end
_tl_render(s; kw...) = String(copy(Main.BasicRenderer.outputs(_tl_r(s; kw...)).render_bytes))
_tl_tree(s; kw...)   = String(copy(Main.BasicRenderer.outputs(_tl_r(s; kw...)).blsStructure_bytes))
_tl_err(s; kw...)    = try _tl_r(s; kw...); nothing catch e sprint(showerror, e) end
_tl_nblocks(s; kw...) = length(collect(eachmatch(r"\{:B-", _tl_tree(s; kw...))))

@testset "token_law_tests (F-13 verification matrix)" begin

    @testset "[1] the owner's POSSIBILITY-SHAPES: plain content, zero evals, byte-identical" begin
        for s in ("someCharacters##someMoreCharacters\nx = 1\n",
                  "someCharacters#~someMoreCharacters\nx = 1\n")
            r = _tl_r(s)
            @test r.status == GM.PROCESS_OK
            @test isempty(GM.readAltValuesEvals(r.altValues_evals))
            @test _tl_render(s) == s
            @test _tl_nblocks(s) == 1                  # a single Code block, unsplit
        end
    end

    @testset "[2] the glued matrix: bucket (A) — content, no refusal, byte-identical" begin
        for s in ("##glued\n", "### run\n", "#x\n", "#\n", " #~hide\n",
                  "#~9x\n", "#~2!x\n", "#]x\n", "####\n")
            inp = s * "x = 1\n"
            @test _tl_err(inp) === nothing
            r = _tl_r(inp)
            @test r.status == GM.PROCESS_OK
            @test isempty(GM.readAltValuesEvals(r.altValues_evals))
            @test _tl_render(inp) == inp
        end
    end

    @testset "[3] neighbourhood integrity: bucket (A) never splits its block (§B)" begin
        for mid in ("##glued", "#", "#~9x", "#]x")
            @test _tl_nblocks("y0 = 0\n" * mid * "\ny1 = 1\n") == 1        # ONE Code block
        end
        # Text neighbourhood: ONE Text block (the γ-catcher — a Code fall-through would split)
        @test _tl_nblocks("# text\n##glued\n# more text\n") == 1
    end

    @testset "[4] Meta adjacency: bucket (A) joins INERTLY — no refusal, no DSL entry (§B)" begin
        # line grain — directly after a metaLine (the stale-Meta-landing class the panel
        # proved fatal under a flagless design; β's :ignoreThisMeta is the shield)
        let s = "#~ hide\n###banner\nx = 1\n"
            @test _tl_err(s) === nothing
            @test _tl_r(s).status == GM.PROCESS_OK
        end
        let s = "#~ :label1\n#nonsense ## note\nx = 1\n"                   # seat-3 F-4 witness
            @test _tl_err(s) === nothing
        end
        # segment grain — glued shape after a real inline token on the SAME line
        let s = "x = 1 #~ hide ##glued\ny = 2\n"
            @test _tl_err(s) === nothing
            @test _tl_r(s).status == GM.PROCESS_OK
        end
    end

    @testset "[5] keep-the-split, drop-the-marking: glued mid-line = plain segment (§B)" begin
        # drift fixture c1_inline_nospace pins the two-segment tree shape externally; this
        # is the in-suite twin: same type both segments, no :S-Meta, byte-identical render.
        let s = "x = 1 #nospace inline\ny = 2\n"
            t = _tl_tree(s)
            @test !occursin(":S-Meta", t)
            @test _tl_render(s) == s
        end
        # a LATER real token on the same line is still found past a glued head
        let s = "z = 9 ##glued w #~ hide\nq = 1\n"
            @test _tl_err(s) === nothing
            @test occursin(":S-Meta", _tl_tree(s))
        end
    end

    @testset "[6] preserved family: ws-or-EOL-delimited tokens are UNCHANGED (§F)" begin
        @test _tl_render("## comment\nx = 1\n") == "## comment\nx = 1\n"
        @test _tl_render("    ## indented\nx = 1\n") == "    ## indented\nx = 1\n"
        @test _tl_render("x ##\nx = 1\n") == "x ##\nx = 1\n"               # ##+EOL comment
        @test occursin(":B-Text", _tl_tree("# text\nx = 1\n"))
        let r = _tl_r("#~ hide\nx = 1\n")                                   # hide still lands
            @test r.status == GM.PROCESS_OK
            @test occursin("## x = 1", _tl_render("#~ hide\nx = 1\n"))
        end
        @test occursin(":S-Meta", _tl_tree("x = 1 #~\ny = 2\n"))            # EOL inline token
        @test _tl_err("x = 1 #]\ny = 2\n") === nothing                      # closer alone
    end

    @testset "[7] value-vs-delimitation: E-06 refusals PRESERVED for ws-delimited bodies" begin
        let m = _tl_err("#~9 show\nx\n")                                    # dw1's shape
            @test m !== nothing && occursin("depth", m)
        end
        @test _tl_err("#~9x\nx\n") === nothing                              # glued twin: content
    end

    @testset "[8] hidden bucket (A) takes the hide marker — R-2 exclusion is the law (§B)" begin
        # `###banner` is NOT a comment under F-13 ⇒ NOT fold-eligible ⇒ hidden it is MARKED
        # (formerly comment-classified + `##`-initial ⇒ folded bare). Render delta, intended.
        let s = "#~ hide\n###banner\ny = 1\n"       # attached (no blank line between)
            r = _tl_render(s)
            @test occursin("## ###banner", r)
        end
        # contrast: a REAL `## ` comment in the same position folds (takes NO extra marker)
        let s = "#~ hide\n## note\ny = 1\n"
            r = _tl_render(s)
            @test occursin("\n## note\n", "\n" * r)
            @test !occursin("## ## note", r)
        end
    end

    @testset "[9] cfam mirror (host divergence §D): glued //-shapes are ordinary comments" begin
        let s = "//~hide\na = 1;\n"                                          # bound 5 DEAD
            @test _tl_err(s; flavor=:c) === nothing
            @test _tl_render(s; flavor=:c) == s
            @test isempty(GM.readAltValuesEvals(_tl_r(s; flavor=:c).altValues_evals))
        end
        let s = "//]x\nb = 2;\n"                                             # glued closer
            @test _tl_err(s; flavor=:c) === nothing
            @test _tl_render(s; flavor=:c) == s
        end
        let s = "//~ hide\na = 1;\n"                                         # token unchanged
            @test occursin("//# a = 1;", _tl_render(s; flavor=:c))
        end
    end

    @testset "[10] grammar single-source: _re_meta is DERIVED from _RE_META_BODY_STR (§C)" begin
        @test GM.BLS._re_meta.pattern == "^" * GM.BLS._RE_META_BODY_STR
    end

    @testset "[11] post-apply panel additions (2026-08-08; all shapes probe-confirmed first)" begin
        # fence row: bucket-(A) shapes INSIDE an open fence — one unsplit Code block,
        # the glued mid-line shape a plain same-type segment, byte-identical render
        let s = "s = \"\"\"\ntext #~glued\n##x\n\"\"\"\ny = 1\n"
            t = _tl_tree(s)
            @test _tl_nblocks(s) == 2                      # the fence block + y = 1
            @test occursin("{:S-Code [#~glued]}", t)       # plain segment, keep-the-split
            @test !occursin(":S-Meta", t)
            @test _tl_render(s) == s
        end
        # Meta-adjacency INERT-JOIN tree assert (the §E.6 mandate [4] under-asserted):
        # the glued run joins the Meta block as an inert Meta line — no eval, no refusal
        let s = "#~ hide\n###banner\nx = 1\n"
            t = _tl_tree(s)
            @test occursin(":L-Meta [###banner]", t)
            @test !any(a -> a[3] === :discard, GM.readAltValuesEvals(_tl_r(s).altValues_evals))
        end
        # preserved family completion: digit form (label LANDS) + bang form (inert)
        let s = "#~2 :label1\nx = 1\n"
            @test occursin(":L-Meta [#~2 :label1]", _tl_tree(s))
            @test any(a -> a[2] == :label_label1, GM.readAltValuesEvals(_tl_r(s).altValues_evals))
        end
        let s = "#~~~! x\nx = 1\n"
            @test occursin(":L-Meta [#~~~! x]", _tl_tree(s))
            @test isempty(GM.readAltValuesEvals(_tl_r(s).altValues_evals))    # ! = inert, never evaluated
        end
        # line-START glued head followed by a real inline token (flag-leak witnesses:
        # a leaked line-grain :hasMetaStr would trip the >1-inline-marker refusal)
        for s in ("##glued #~ hide\nx = 1\n", "#~9x #~ hide\nx = 1\n")
            @test _tl_err(s) === nothing
            @test occursin(":S-Meta", _tl_tree(s))
        end
        # file-start else-family resolves Text (the comment-arm mirror at fallbackCT nothing)
        @test occursin(":B-Text", _tl_tree("#!shebang-ish\nconst A = 1\n"))
        # the ##+EOL comment form DISCRIMINATED in a hidden region: it folds (unchanged)
        # while content takes the marker — reds if the EOL disjunct of the ## arm breaks
        let r = _tl_render("#~ hide\n##\ny = 1\n")
            @test occursin("\n##\n", r)
            @test !occursin("## ##", r)
            @test occursin("## y = 1", r)
        end
        # the ws-delimited closer produces a real Meta segment (not just no-error)
        @test occursin("{:S-Meta [#]]}", _tl_tree("x = 1 #]\ny = 2\n"))
    end

    @testset "[12] REAL-1b rows 3, 17 and 7 — the delivered object on the edge inputs (stage 1 commit 5; every value measured first, 2026-09-30)" begin
        let s = "x#~ hide\ny = 1\n", r = _tl_r(s)             # row 3: a missing BEFORE boundary — plain content by the token law
            @test r.status == GM.PROCESS_OK
            @test isempty(GM.readAltValuesEvals(r.altValues_evals))
            @test _tl_render(s) == s                             # (the one-Block witness — a read of the old tree dump — is written at stage 6 with rows 15/16, against the reference style)
        end
        let r = GM.goMeta(UInt8[])                               # row 17 + R2 #21: the EMPTY input
            @test r.status == GM.PROCESS_OK
            @test isempty(GM.readAltValuesEvals(r.altValues_evals))
            @test isempty(r.diagnostics)
            @test isempty(Main.BasicRenderer.outputs(r).render_bytes)   # (the terminal-newline fact of the empty input has no witness from the outside — through the door's `endsWithNewline` at stage 2, if door B lands)
        end
        let r = GM.goMeta(Vector{UInt8}(codeunits("\n")))         # card C14 (c), R-V04B-96 (his §306 of 2026-10-03): the LF-ONLY input beside the empty one — R2 #21's "with and without the terminal newline"; every value MEASURED 2026-10-03 (receipts/S8-branch/PROBES-c14-pins_cd3ee9d3.txt)
            @test r.status == GM.PROCESS_OK                                                   # [C14c1]
            @test isempty(GM.readAltValuesEvals(r.altValues_evals))                           # [C14c2] no evals row
            @test isempty(r.diagnostics)                                                      # [C14c3]
            @test Main.BasicRenderer.outputs(r).render_bytes == UInt8[0x0a]                  # [C14c4] the render is the one line break back
            @test length(GM.BLS.children(r.blsComponentTree)) == 1                            # [C14c5] ONE Block — the one empty line — read through the door (measured; the session's presentation had said none)
            @test GM.BLS.endsWithNewline(r.blsComponentTree)                                  # [C14c6] the terminal-newline fact, through the door (the door landed at stage 2's commit 0)
            @test isempty(GM.BLS.children(GM.goMeta(UInt8[]).blsComponentTree))               # [C14c7] the EMPTY input beside it: no Block…
            @test !GM.BLS.endsWithNewline(GM.goMeta(UInt8[]).blsComponentTree)                # [C14c8] …and no terminal newline
        end
        let s = "x = 1\n#~ hide\ny = 2", r = _tl_r(s)           # row 17: NO terminal newline
            @test r.status == GM.PROCESS_OK
            @test _tl_render(s) == "x = 1\n## #~ hide\n## y = 2"   # the render ends without LF, as the input did (the terminal-newline fact witnessed from the outside)
            @test _tl_render(s * "\n") == _tl_render(s) * "\n"     # the LF twin renders the same bytes plus the final LF
            @test GM.readAltValuesEvals(r.altValues_evals) == GM.readAltValuesEvals(_tl_r(s * "\n").altValues_evals)   # the same two evals rows either way — WHOLE rows, handles included (measured equal)
        end
        let s = "#~ hide\n", r = _tl_r(s)                          # R2 #21: a METADATA-ONLY input — one metaLine, nothing else
            @test r.status == GM.PROCESS_OK
            @test [(a, v, p) for (h, a, v, p) in GM.readAltValuesEvals(r.altValues_evals)] == [(:visib, :hide, true)]   # one evals row, the metaLine's own Block
            @test isempty(r.diagnostics)
            @test _tl_render(s) == "## #~ hide\n"                 # the metaLine itself is hidden — the render is NOT the input
            @test _tl_render("#~ hide") == "## #~ hide"           # its LF-less twin renders without the final LF
        end
        let m = _tl_err("x = 1 #~ hide #~ show\n")                # row 7: two inline markers on ONE line — refused at parse (docs/public-api.md §3.4)
            @test m !== nothing && occursin("more than one inline meta segment", m)
        end
    end
end
