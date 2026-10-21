# parser_quality_tests.jl — THE PARSER-QUALITY BATTERY of the metaLine parser (the creator's words:
# "I DO want tests which check the quality of the parsers"). GENERATED from the rows table by a generator outside the repository
# (one override file for the
# rows the Heading's move into the apply loop changed); the comments were edited after generation.
#
# IS:   every shape of the parser inventory (100 items, A01–I08), the 50 needs-a-run shapes
#       (r01–r49, r19b) and the quote-scan shapes, each driven through goMeta on its one-line document (or its DOC), with the
#       EXPECTED outcome under the parser's design (the creator's decision of 2026-10-08): ACCEPTED with its evals row count, REFUSED
#       with the stable GoMeta head(s) the message carries, or JULIA's own exception class where the creator's decisions keep it (an argument's
#       arity or type fault is the Alterant's setter's; a malformed condition body is Julia's parse error).
# DOES: one @testset per row; the comment on each row is the outcome MEASURED before the parser's rework — the CHANGE column:
#       a row marked UNCHANGED pins today's behaviour against drift; a row marked CHANGED pins the effort's cure; a row marked
#       CHANGED (strings in conditions) pins that change's outcome, MEASURED
#       after the change: a quoted text inside a condition body is Julia's — copied whole, never read by
#       the rewrite — and the body's `(…)` lists are found by the one scanner (an unclosed `(` meets "unterminated '('").
#       A row marked WITNESS was added after the parser's rework
#       (the creator's word of 2026-10-09) with its outcome MEASURED from the FULL delivery
#       view.
#       A row marked GUARD pins the invalid-Char guard of the condition rewrite's two identifier tests (the creator's word of 2026-10-09):
#       an invalid UTF-8 byte at the rewrite's identifier tests inside a condition body meets Julia's
#       parse error or the unknown-key refusal where the tree before the guard threw a raw InvalidCharError; its document is built from BYTES (the
#       extra row's `doc_hex`), its outcome
#       MEASURED before and after the guard.
#       A row marked CHANGED (the Heading's move) pins the Heading's move into the apply loop (the creator's decision):
#       a label test in a heading's own condition is legal (the creator's decision — the former wall was removed with the Heading's separate path),
#       its outcome MEASURED after the move.
# REASONING: a refusal is pinned by its GoMeta head, never by Julia's message text; an accepted row's count was
#       measured with the development tool's printout.
# PURPOSE: the parser's quality, shape by shape — the creator's two example files and the twelve frozen forms are the oracle's other half
#       (tests/comparison/regenerate.jl --check; the golden layer).
using Test
import GoMeta as GM

_pq_doc(s) = Vector{UInt8}(codeunits(s))
function _pq(doc)
    try
        r = GM.goMeta(_pq_doc(doc))
        (:ok, r.status, length(GM.readAltValuesEvals(r.altValues_evals)), nothing)
    catch e
        (:throw, nothing, 0, e)
    end
end

@testset "parser_quality — the battery of the metaLine parser" begin
    # A01 [valid] — UNCHANGED — BEFORE: OK PROCESS_OK, 2 evals rows
    @testset "A01" begin
        k, st, n, e = _pq("#~ hide\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 2
    end
    # A02 [valid] — UNCHANGED — BEFORE: OK PROCESS_OK, 1 evals rows
    @testset "A02" begin
        k, st, n, e = _pq("#~ hide{isCode}\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 1
    end
    # A03 [valid] — UNCHANGED — BEFORE: OK PROCESS_OK, 1 evals rows
    @testset "A03" begin
        k, st, n, e = _pq("#~ cell(7){isCode}\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 1
    end
    # A04 [malformed] — CHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: duplicate argument list
    @testset "A04" begin
        k, st, n, e = _pq("#~ cell{isCode}(7)\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unexpected character '(' after the metaStatement \"cell{isCode}\"", e.msg)
    end
    # A05 [valid] — UNCHANGED — BEFORE: OK PROCESS_OK, 2 evals rows
    @testset "A05" begin
        k, st, n, e = _pq("#~ hide show\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 2
    end
    # A06 [valid] — UNCHANGED — BEFORE: OK PROCESS_OK, 2 evals rows
    @testset "A06" begin
        k, st, n, e = _pq("#~ discard{ isCode } show\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 2
    end
    # A07 [valid] — UNCHANGED — BEFORE: OK PROCESS_OK, 4 evals rows
    @testset "A07" begin
        k, st, n, e = _pq("#~ :label1 hide{ :label1 }\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 4
    end
    # A08 [valid] — UNCHANGED — BEFORE: OK PROCESS_OK, 2 evals rows
    @testset "A08" begin
        k, st, n, e = _pq("#~ hide{ :label1 } :label1\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 2
    end
    # A09 [malformed] — UNCHANGED — BEFORE: THROWS MethodError
    @testset "A09" begin
        k, st, n, e = _pq("#~ hide(x)\nx = 1\n")
        @test k === :throw && e isa MethodError
    end
    # A10 [boundary] — UNCHANGED — BEFORE: OK PROCESS_OK, 2 evals rows
    @testset "A10" begin
        k, st, n, e = _pq("#~ hide()\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 2
    end
    # B01 [boundary] — UNCHANGED — BEFORE: OK PROCESS_OK, 0 evals rows
    @testset "B01" begin
        k, st, n, e = _pq("#~hide\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # B02 [valid] — UNCHANGED — BEFORE: OK PROCESS_OK, 2 evals rows
    @testset "B02" begin
        k, st, n, e = _pq("#~\thide\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 2
    end
    # B03 [valid] — UNCHANGED — BEFORE: OK PROCESS_OK, 2 evals rows
    @testset "B03" begin
        k, st, n, e = _pq("#~ hide ## a comment\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 2
    end
    # B04 [boundary] — UNCHANGED — BEFORE: OK PROCESS_OK, 2 evals rows
    @testset "B04" begin
        k, st, n, e = _pq("#~ hide # a note\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 2
    end
    # B05 [malformed] — CHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: unterminated condition block
    @testset "B05" begin
        k, st, n, e = _pq("#~ hide{ :label1 ## c }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unterminated '{'", e.msg)
    end
    # B06 [ambiguous] — UNCHANGED — BEFORE: THROWS ErrorException: GoMeta parse: more than one inline meta segment on one line
    @testset "B06" begin
        k, st, n, e = _pq("#~ hide #~ show\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta parse: more than one inline meta segment on one line", e.msg)
    end
    # B07 [boundary] — UNCHANGED — BEFORE: OK PROCESS_OK, 0 evals rows
    @testset "B07" begin
        k, st, n, e = _pq("#~! hide{\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # B08 [malformed] — UNCHANGED — BEFORE: THROWS ErrorException: GoMeta parse: bang-first meta marker "#~!2"
    @testset "B08" begin
        k, st, n, e = _pq("#~!2 hide\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta parse: bang-first meta marker \"#~!2\"", e.msg)
    end
    # B09 [boundary] — UNCHANGED — BEFORE: OK PROCESS_OK, 2 evals rows
    @testset "B09" begin
        k, st, n, e = _pq("#~ hide\n#]\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 2
    end
    # B10 [boundary] — UNCHANGED — BEFORE: OK PROCESS_OK, 0 evals rows
    @testset "B10" begin
        k, st, n, e = _pq("#] hide\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # B11 [malformed] — CHANGED — BEFORE: THROWS BoundsError
    @testset "B11" begin
        k, st, n, e = _pq("#~ hide .\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unknown alterant action \".\"", e.msg)
    end
    # B12 [valid] — UNCHANGED — BEFORE: OK PROCESS_OK, 2 evals rows
    @testset "B12" begin
        k, st, n, e = _pq("#~   hide\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 2
    end
    # C01 [valid] — UNCHANGED — BEFORE: OK PROCESS_OK, 2 evals rows
    @testset "C01" begin
        k, st, n, e = _pq("#~2 hide\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 2
    end
    # C02 [valid] — UNCHANGED — BEFORE: OK PROCESS_OK, 2 evals rows
    @testset "C02" begin
        k, st, n, e = _pq("#~8 hide\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 2
    end
    # C03 [malformed] — UNCHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: meta depth out of range
    @testset "C03" begin
        k, st, n, e = _pq("#~9 hide\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: meta depth out of range", e.msg)
    end
    # C04 [ambiguous] — UNCHANGED — BEFORE: OK PROCESS_OK, 2 evals rows
    @testset "C04" begin
        k, st, n, e = _pq("#~10 hide\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 2
    end
    # C05 [ambiguous] — UNCHANGED — BEFORE: OK PROCESS_OK, 2 evals rows
    @testset "C05" begin
        k, st, n, e = _pq("#~~~~~~~~~ hide\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 2
    end
    # C06 [valid] — UNCHANGED — BEFORE: OK PROCESS_OK, 0 evals rows
    @testset "C06" begin
        k, st, n, e = _pq("#~2\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # C07 [boundary] — UNCHANGED — BEFORE: OK PROCESS_OK, 0 evals rows
    @testset "C07" begin
        k, st, n, e = _pq("#~​hide\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # C08 [valid] — UNCHANGED — BEFORE: OK PROCESS_OK, 2 evals rows
    @testset "C08" begin
        k, st, n, e = _pq("#~ hide\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 2
    end
    # C09 [valid] — UNCHANGED — BEFORE: OK PROCESS_OK, 2 evals rows
    @testset "C09" begin
        k, st, n, e = _pq("#~　hide\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 2
    end
    # D01 [malformed] — CHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: unterminated argument list
    @testset "D01" begin
        k, st, n, e = _pq("#~ cell(7\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unterminated '('", e.msg)
    end
    # D02 [malformed] — CHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: unterminated condition block
    @testset "D02" begin
        k, st, n, e = _pq("#~ hide{isCode\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unterminated '{'", e.msg)
    end
    # D03 [malformed] — CHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: duplicate argument list
    @testset "D03" begin
        k, st, n, e = _pq("#~ cell(3)(4)\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unexpected character '(' after the metaStatement \"cell(3)\"", e.msg)
    end
    # D04 [malformed] — CHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: duplicate condition block
    @testset "D04" begin
        k, st, n, e = _pq("#~ hide{isCode}{isText}\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unexpected character '{' after the metaStatement \"hide{isCode}\"", e.msg)
    end
    # D05 [malformed] — UNCHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: the condition block {} carries no condition expression (an empty block)
    @testset "D05" begin
        k, st, n, e = _pq("#~ hide{}\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: the condition block {} carries no condition expression (an empty block)", e.msg)
    end
    # D06 [malformed] — UNCHANGED — BEFORE: THROWS MethodError
    @testset "D06" begin
        k, st, n, e = _pq("#~ cell()\nx = 1\n")
        @test k === :throw && e isa MethodError
    end
    # D07 [malformed] — CHANGED — BEFORE: OK PROCESS_OK, 1 evals rows
    @testset "D07" begin
        k, st, n, e = _pq("#~ hide{isCode}}\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unexpected character '}' after the metaStatement \"hide{isCode}\"", e.msg)
    end
    # D08 [malformed] — CHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: unknown alterant action "isCode)"
    @testset "D08" begin
        k, st, n, e = _pq("#~ hide (isCode)\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unexpected character '(' at the start of a metaStatement", e.msg)
        @test occursin("glued to the name", e.msg)
    end
    # D09 [malformed] — CHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: unknown alterant action "isCode}"
    @testset "D09" begin
        k, st, n, e = _pq("#~ hide {isCode}\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unexpected character '{' at the start of a metaStatement", e.msg)
        @test occursin("glued to the name", e.msg)
    end
    # D10 [malformed] — UNCHANGED — BEFORE: THROWS MethodError
    @testset "D10" begin
        k, st, n, e = _pq("#~ cell(7,)\nx = 1\n")
        @test k === :throw && e isa MethodError
    end
    # D11 [malformed] — UNCHANGED — BEFORE: THROWS ArgumentError
    @testset "D11" begin
        k, st, n, e = _pq("#~ cell(a)\nx = 1\n")
        @test k === :throw && e isa ArgumentError
    end
    # E01 [malformed] — UNCHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: unknown alterant action "hi-de"
    @testset "E01" begin
        k, st, n, e = _pq("#~ hi-de\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown alterant action \"hi-de\"", e.msg)
    end
    # E02 [malformed] — UNCHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: unknown alterant action "2hide"
    @testset "E02" begin
        k, st, n, e = _pq("#~ 2hide\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown alterant action \"2hide\"", e.msg)
    end
    # E03 [ambiguous] — CHANGED — BEFORE: OK PROCESS_OK, 2 evals rows
    @testset "E03" begin
        k, st, n, e = _pq("#~ -hide\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unknown alterant action \"-hide\"", e.msg)
    end
    # E04 [malformed] — UNCHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: unknown alterant action "+hide"
    @testset "E04" begin
        k, st, n, e = _pq("#~ +hide\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown alterant action \"+hide\"", e.msg)
    end
    # E05 [ambiguous] — CHANGED — BEFORE: OK PROCESS_OK, 2 evals rows
    @testset "E05" begin
        k, st, n, e = _pq("#~ _hide\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unknown alterant action \"_hide\"", e.msg)
    end
    # E06 [malformed] — UNCHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: unknown alterant action "hide\u200bshow"
    @testset "E06" begin
        k, st, n, e = _pq("#~ hide​show\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown alterant action \"hide\\u200bshow\"", e.msg)
    end
    # F01 [valid] — UNCHANGED — BEFORE: OK PROCESS_OK, 2 evals rows
    @testset "F01" begin
        k, st, n, e = _pq("#~ :label1\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 2
    end
    # F02 [valid] — UNCHANGED — BEFORE: OK PROCESS_OK, 1 evals rows
    @testset "F02" begin
        k, st, n, e = _pq("#~ :label1{isCode}\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 1
    end
    # F03 [ambiguous] — CHANGED — BEFORE: OK PROCESS_OK, 4 evals rows
    @testset "F03" begin
        k, st, n, e = _pq("#~ :label1,label2\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unexpected character ',' after the metaStatement \":label1\"", e.msg)
        @test occursin(":(name1, name2)", e.msg)
    end
    # F04 [valid] — UNCHANGED — BEFORE: OK PROCESS_OK, 4 evals rows
    @testset "F04" begin
        k, st, n, e = _pq("#~ :(label1, label2)\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 4
    end
    # F05 [malformed] — CHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: unknown alterant action "label2"
    @testset "F05" begin
        k, st, n, e = _pq("#~ :label1, label2\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unexpected character ',' after the metaStatement \":label1\"", e.msg)
        @test occursin(":(name1, name2)", e.msg)
    end
    # F06 [malformed] — UNCHANGED — BEFORE: THROWS ErrorException: GoMeta apply: unknown label "label9"
    @testset "F06" begin
        k, st, n, e = _pq("#~ :label9\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta apply: unknown label \"label9\"", e.msg)
    end
    # F07 [malformed] — UNCHANGED — BEFORE: THROWS ErrorException: GoMeta apply: empty label list
    @testset "F07" begin
        k, st, n, e = _pq("#~ :\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta apply: empty label list", e.msg)
    end
    # F08 [malformed] — CHANGED — BEFORE: THROWS ErrorException: GoMeta apply: unknown label "label1(x)"
    @testset "F08" begin
        k, st, n, e = _pq("#~ :label1(x)\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unexpected character '(' after the metaStatement \":label1\"", e.msg)
    end
    # F09 [malformed] — CHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: string argument not accepted
    @testset "F09" begin
        k, st, n, e = _pq("#~ :\"ab\"\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unexpected character '\"' after ':'", e.msg)
    end
    # F10 [malformed] — CHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: backslash in a quoted argument
    @testset "F10" begin
        k, st, n, e = _pq("#~ :\"a\\b\"\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unexpected character '\"' after ':'", e.msg)
    end
    # F11 [valid] — UNCHANGED — BEFORE: OK PROCESS_OK, 2 evals rows
    @testset "F11" begin
        k, st, n, e = _pq("#~ :\U0001F525\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 2
    end
    # F12 [valid] — UNCHANGED — BEFORE: OK PROCESS_OK, 2 evals rows
    @testset "F12" begin
        k, st, n, e = _pq("#~ :⛓️‍\U0001F4A5\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 2
    end
    # G01 [valid] — UNCHANGED — BEFORE: OK PROCESS_OK, 1 evals rows
    @testset "G01" begin
        k, st, n, e = _pq("#~2 \"T\"\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 1
    end
    # G02 [valid] — UNCHANGED — BEFORE: OK PROCESS_OK, 1 evals rows
    @testset "G02" begin
        k, st, n, e = _pq("#~ head(\"T\", 2)\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 1
    end
    # G03 [malformed] — UNCHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: explicit heading level 9 is outside the level vocabulary
    @testset "G03" begin
        k, st, n, e = _pq("#~ head(\"T\", 9)\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: explicit heading level 9 is outside the level vocabulary", e.msg)
    end
    # G04 [malformed] — UNCHANGED — BEFORE: THROWS ArgumentError
    @testset "G04" begin
        k, st, n, e = _pq("#~ head(\"T\", x)\nx = 1\n")
        @test k === :throw && e isa ArgumentError
    end
    # G05 [malformed] — UNCHANGED — BEFORE: THROWS MethodError
    @testset "G05" begin
        k, st, n, e = _pq("#~ head(T)\nx = 1\n")
        @test k === :throw && e isa MethodError
    end
    # G06 [malformed] — UNCHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: empty heading text
    @testset "G06" begin
        k, st, n, e = _pq("#~ head(\"\")\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: empty heading text", e.msg)
    end
    # G07 [boundary] — UNCHANGED — BEFORE: OK PROCESS_OK, 1 evals rows
    @testset "G07" begin
        k, st, n, e = _pq("#~ \" \"\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 1
    end
    # G08 [boundary] — UNCHANGED — BEFORE: OK PROCESS_OK, 0 evals rows
    @testset "G08" begin
        k, st, n, e = _pq("#~ \"T\"{isCode}\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # G09 [ambiguous] — CHANGED (the Heading through the apply loop — the creator's decision: a label test in a heading's own condition is legal; the outcome MEASURED after the move: PROCESS_OK, 0 evals rows — the label known to the vocabulary and set nowhere, the condition false, no refusal; its unknown-label sibling the same outcome) — BEFORE: THROWS ErrorException: GoMeta absorb: alterant-state query in a heading condition
    @testset "G09" begin
        k, st, n, e = _pq("#~ \"T\"{ :label1 }\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # G10 [malformed] — CHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: duplicate argument list
    @testset "G10" begin
        k, st, n, e = _pq("#~ \"T\"(2)\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unexpected character '(' after the metaStatement", e.msg)
    end
    # G11 [malformed] — CHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: unterminated quoted heading
    @testset "G11" begin
        k, st, n, e = _pq("#~ \"T\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unterminated '\"'", e.msg)
    end
    # G12 [malformed] — CHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: backslash in a quoted heading
    @testset "G12" begin
        k, st, n, e = _pq("#~ \"a\\b\"\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("backslash in a quoted span", e.msg)
    end
    # G13 [malformed] — CHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: unknown alterant action "T\""
    @testset "G13" begin
        k, st, n, e = _pq("#~ :label1 \"T\"\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unexpected character '\"' at the start of a metaStatement", e.msg)
        @test occursin("heading sugar at the region's first metaStatement only", e.msg)
    end
    # G14 [valid] — UNCHANGED — BEFORE: OK PROCESS_OK, 3 evals rows
    @testset "G14" begin
        k, st, n, e = _pq("#~ \"T\" :label1\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 3
    end
    # G15 [valid] — UNCHANGED — BEFORE: OK PROCESS_OK, 1 evals rows
    @testset "G15" begin
        k, st, n, e = _pq("x = 1 #~ \"T\"\ny = 2\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 1
    end
    # H01 [valid] — UNCHANGED — BEFORE: OK PROCESS_OK, 1 evals rows
    @testset "H01" begin
        k, st, n, e = _pq("#~ hide{(isCode)}\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 1
    end
    # H02 [valid] — UNCHANGED — BEFORE: OK PROCESS_OK, 1 evals rows
    @testset "H02" begin
        k, st, n, e = _pq("#~ hide{(isCode) }\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 1
    end
    # H03 [valid] — UNCHANGED — BEFORE: OK PROCESS_OK, 1 evals rows
    @testset "H03" begin
        k, st, n, e = _pq("#~ hide{ (isText && containsMeta), isMeta }\n# content\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 1
    end
    # H04 [ambiguous] — UNCHANGED — BEFORE: OK PROCESS_OK, 1 evals rows
    @testset "H04" begin
        k, st, n, e = _pq("#~ hide{isCode || isText}\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 1
    end
    # H05 [malformed] — UNCHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "isCod"
    @testset "H05" begin
        k, st, n, e = _pq("#~ hide{isCod}\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"isCod\"", e.msg)
    end
    # H06 [ambiguous] — UNCHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "label1"
    @testset "H06" begin
        k, st, n, e = _pq("#~ hide{label1}\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"label1\"", e.msg)
    end
    # H07 [ambiguous] — UNCHANGED — BEFORE: OK PROCESS_OK, 0 evals rows
    @testset "H07" begin
        k, st, n, e = _pq("#~ hide{:label9}\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # H08 [malformed] — UNCHANGED — BEFORE: THROWS MethodError
    @testset "H08" begin
        k, st, n, e = _pq("#~ hide{:label1(:label2)}\nx = 1\n")
        @test k === :throw && e isa MethodError
    end
    # H09 [malformed] — UNCHANGED — BEFORE: THROWS ErrorException: GoMeta apply: empty label query
    @testset "H09" begin
        k, st, n, e = _pq("#~ :label1 hide{:()}\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta apply: empty label query", e.msg)
    end
    # H10 [malformed] — UNCHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "cell"
    @testset "H10" begin
        k, st, n, e = _pq("#~ cell(3) hide{cell}\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"cell\"", e.msg)
    end
    # H11 [ambiguous] — UNCHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "show"
    @testset "H11" begin
        k, st, n, e = _pq("#~ hide{show}\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"show\"", e.msg)
    end
    # H12 [malformed] — UNCHANGED — BEFORE: THROWS UndefVarError
    @testset "H12" begin
        k, st, n, e = _pq("#~ hide{isCode(x)}\nx = 1\n")
        @test k === :throw && e isa UndefVarError
    end
    # H13 [boundary] — UNCHANGED — BEFORE: OK PROCESS_OK, 1 evals rows
    @testset "H13" begin
        k, st, n, e = _pq("#~ hide{isCode,isCode,isCode,isCode,isCode,isCode,isCode,isCode,isCode,isCode,isCode,isCode,isCode,isCode,isCode}\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 1
    end
    # H14 [boundary] — UNCHANGED — BEFORE: OK PROCESS_OK, 1 evals rows
    @testset "H14" begin
        k, st, n, e = _pq("#~ hide{isCode,isCode,isCode,isCode,isCode,isCode,isCode,isCode,isCode,isCode,isCode,isCode,isCode,isCode,isCode,isCode}\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 1
    end
    # H15 [boundary] — UNCHANGED — BEFORE: OK PROCESS_OK, 0 evals rows
    @testset "H15" begin
        k, st, n, e = _pq("#~ hide{:abcdefghijklmnopqrstuvwxyzabc}\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # H16 [valid] — UNCHANGED — BEFORE: OK PROCESS_OK, 4 evals rows
    @testset "H16" begin
        k, st, n, e = _pq("#~ :\U0001F525 hide{ :\U0001F525 }\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 4
    end
    # H17 [ambiguous] — UNCHANGED — BEFORE: OK PROCESS_OK, 4 evals rows
    @testset "H17" begin
        k, st, n, e = _pq("#~ :⛓️‍\U0001F4A5 hide{ :⛓️‍\U0001F4A5 }\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 4
    end
    # I01 [valid] — UNCHANGED — BEFORE: OK PROCESS_OK, 1 evals rows
    @testset "I01" begin
        k, st, n, e = _pq("x = 1 #~ hide\ny = 2\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 1
    end
    # I02 [boundary] — UNCHANGED — BEFORE: OK PROCESS_OK, 0 evals rows
    @testset "I02" begin
        k, st, n, e = _pq("x = 1#~ hide\ny = 2\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # I03 [ambiguous] — CHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: unknown alterant action "hide\""
    @testset "I03" begin
        k, st, n, e = _pq("s = \"a #~ hide\"\ny = 2\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unexpected character '\"' after the metaStatement \"hide\"", e.msg)
    end
    # I04 [ambiguous] — CHANGED — BEFORE: THROWS BoundsError
    @testset "I04" begin
        k, st, n, e = _pq("s = \"a #~ hide \"\ny = 2\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unexpected character '\"' at the start of a metaStatement", e.msg)
    end
    # I05 [valid] — UNCHANGED — BEFORE: OK PROCESS_OK, 1 evals rows
    @testset "I05" begin
        k, st, n, e = _pq("# a note #~ hide\ny = 2\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 1
    end
    # I06 [valid] — UNCHANGED — BEFORE: OK PROCESS_OK, 4 evals rows
    @testset "I06" begin
        k, st, n, e = _pq("#~2 :label5\nmd\"\"\"\nThis is markdown. #~ hide\n\"\"\"\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 4
    end
    # I07 [ambiguous] — UNCHANGED — BEFORE: OK PROCESS_OK, 0 evals rows
    @testset "I07" begin
        k, st, n, e = _pq("s = \"\"\"\n#~ hide\n\"\"\"\ny = 2\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # I08 [malformed] — UNCHANGED — BEFORE: THROWS ErrorException: GoMeta parse: more than one inline meta segment on one line
    @testset "I08" begin
        k, st, n, e = _pq("#~ \"a #~ b\"\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta parse: more than one inline meta segment on one line", e.msg)
    end
    # r01 [needs-a-run] — CHANGED — BEFORE: THROWS BoundsError
    @testset "r01" begin
        k, st, n, e = _pq("#~ ,\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unexpected character ',' at the start of a metaStatement", e.msg)
    end
    # r02 [needs-a-run] — CHANGED — BEFORE: THROWS BoundsError
    @testset "r02" begin
        k, st, n, e = _pq("#~3 (\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unexpected character '(' at the start of a metaStatement", e.msg)
    end
    # r03 [needs-a-run] — CHANGED — BEFORE: THROWS BoundsError
    @testset "r03" begin
        k, st, n, e = _pq("#~ !\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unknown alterant action \"!\"", e.msg)
    end
    # r04 [needs-a-run] — CHANGED — BEFORE: OK PROCESS_OK, 2 evals rows
    @testset "r04" begin
        k, st, n, e = _pq("#~ ! discard\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unknown alterant action \"!\"", e.msg)
    end
    # r05 [needs-a-run] — CHANGED — BEFORE: OK PROCESS_OK, 2 evals rows
    @testset "r05" begin
        k, st, n, e = _pq("#~ , discard\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unexpected character ',' at the start of a metaStatement", e.msg)
    end
    # r06 [needs-a-run] — CHANGED — BEFORE: OK PROCESS_OK, 2 evals rows
    @testset "r06" begin
        k, st, n, e = _pq("#~ ( hide\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unexpected character '(' at the start of a metaStatement", e.msg)
    end
    # r07 [needs-a-run] — UNCHANGED — BEFORE: THROWS MethodError
    @testset "r07" begin
        k, st, n, e = _pq("#~ discard(:label3)\nx = 1\n")
        @test k === :throw && e isa MethodError
    end
    # r08 [needs-a-run] — UNCHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "codeLines"
    @testset "r08" begin
        k, st, n, e = _pq("#~ hide{ codeLines > 5 }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"codeLines\"", e.msg)
    end
    # r09 [needs-a-run] — UNCHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "true"
    @testset "r09" begin
        k, st, n, e = _pq("#~ hide{ true }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"true\"", e.msg)
    end
    # r10 [needs-a-run] — UNCHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "true"
    @testset "r10" begin
        k, st, n, e = _pq("#~ hide{ isCode || true }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"true\"", e.msg)
    end
    # r11 [needs-a-run] — CHANGED — BEFORE: THROWS BoundsError
    @testset "r11" begin
        k, st, n, e = _pq("#~ hide show discard hide show discard hide show discard\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("more than 8 actions in one meta-hierarchy slot", e.msg)
    end
    # r12 [needs-a-run] — CHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: misplaced one-word label
    @testset "r12" begin
        k, st, n, e = _pq("#~ :{isCode}\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unexpected character '{' after ':'", e.msg)
    end
    # r13 [needs-a-run] — CHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: misplaced one-word label
    @testset "r13" begin
        k, st, n, e = _pq("#~ : label1\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unknown alterant action \"label1\"", e.msg)
    end
    # r14 [needs-a-run] — CHANGED — BEFORE: THROWS ParseError
    @testset "r14" begin
        k, st, n, e = _pq("#~ hide{ isCode == \"}\" }\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # r15 [needs-a-run] — UNCHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "name"
    @testset "r15" begin
        k, st, n, e = _pq("#~ hide{ name == \"}\" }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"name\"", e.msg)
    end
    # r16 [needs-a-run] — UNCHANGED — BEFORE: THROWS MethodError
    @testset "r16" begin
        k, st, n, e = _pq("#~ cell(7,)\nx = 1\n")
        @test k === :throw && e isa MethodError
    end
    # r17 [needs-a-run] — UNCHANGED — BEFORE: THROWS MethodError
    @testset "r17" begin
        k, st, n, e = _pq("#~ hide(a,,b)\nx = 1\n")
        @test k === :throw && e isa MethodError
    end
    # r18 [needs-a-run] — UNCHANGED — BEFORE: OK PROCESS_OK, 1 evals rows
    @testset "r18" begin
        k, st, n, e = _pq("#~ \"a \$x\"\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 1
    end
    # r19 [needs-a-run] — UNCHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: unknown alterant action "hide#x"
    @testset "r19" begin
        k, st, n, e = _pq("x = 1 #~ hide#x\ny = 2\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown alterant action \"hide#x\"", e.msg)
    end
    # r19b [needs-a-run] — UNCHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: unknown alterant action "hide#x"
    @testset "r19b" begin
        k, st, n, e = _pq("#~ hide#x\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown alterant action \"hide#x\"", e.msg)
    end
    # r20 [needs-a-run] — UNCHANGED — BEFORE: OK PROCESS_OK, 1 evals rows
    @testset "r20" begin
        k, st, n, e = _pq("#~ hide{(isCode)}\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 1
    end
    # r21 [needs-a-run] — UNCHANGED — BEFORE: OK PROCESS_OK, 0 evals rows
    @testset "r21" begin
        k, st, n, e = _pq("#~ hide{:label9}\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # r22 [needs-a-run] — UNCHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "show"
    @testset "r22" begin
        k, st, n, e = _pq("#~ hide{show}\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"show\"", e.msg)
    end
    # r23 [needs-a-run] — UNCHANGED — BEFORE: OK PROCESS_OK, 1 evals rows
    @testset "r23" begin
        k, st, n, e = _pq("#~ hide{isCode,isCode,isCode,isCode,isCode,isCode,isCode,isCode,isCode,isCode,isCode,isCode,isCode,isCode,isCode}\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 1
    end
    # r24 [needs-a-run] — UNCHANGED — BEFORE: OK PROCESS_OK, 1 evals rows
    @testset "r24" begin
        k, st, n, e = _pq("#~ hide{isCode,isCode,isCode,isCode,isCode,isCode,isCode,isCode,isCode,isCode,isCode,isCode,isCode,isCode,isCode,isCode}\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 1
    end
    # r25 [needs-a-run] — UNCHANGED — BEFORE: OK PROCESS_OK, 0 evals rows
    @testset "r25" begin
        k, st, n, e = _pq("#~ hide{:abcdefghijklmnopqrstuvwxyzabc}\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # r26 [needs-a-run] — UNCHANGED — BEFORE: OK PROCESS_OK, 4 evals rows
    @testset "r26" begin
        k, st, n, e = _pq("#~ :\u26d3\ufe0f\u200d\U0001f4a5 hide{ :\u26d3\ufe0f\u200d\U0001f4a5 }\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 4
    end
    # r27 [needs-a-run] — UNCHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "cell"
    @testset "r27" begin
        k, st, n, e = _pq("#~ cell(3) hide{cell}\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"cell\"", e.msg)
    end
    # r28 [needs-a-run] — UNCHANGED — BEFORE: THROWS UndefVarError
    @testset "r28" begin
        k, st, n, e = _pq("#~ hide{isCode(x)}\nx = 1\n")
        @test k === :throw && e isa UndefVarError
    end
    # r29 [needs-a-run] — UNCHANGED — BEFORE: THROWS MethodError
    @testset "r29" begin
        k, st, n, e = _pq("#~ hide{:label1(:label2)}\nx = 1\n")
        @test k === :throw && e isa MethodError
    end
    # r30 [needs-a-run] — UNCHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: the condition block {} carries no condition expression (an empty block)
    @testset "r30" begin
        k, st, n, e = _pq("#~ hide{}\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: the condition block {} carries no condition expression (an empty block)", e.msg)
    end
    # r31 [needs-a-run] — UNCHANGED — BEFORE: OK PROCESS_OK, 2 evals rows
    @testset "r31" begin
        k, st, n, e = _pq("#~ :\u26d3\ufe0f\u200d\U0001f4a5\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 2
    end
    # r32 [needs-a-run] — CHANGED — BEFORE: OK PROCESS_OK, 2 evals rows
    @testset "r32" begin
        k, st, n, e = _pq("#~ -hide\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unknown alterant action \"-hide\"", e.msg)
    end
    # r33 [needs-a-run] — CHANGED — BEFORE: OK PROCESS_OK, 2 evals rows
    @testset "r33" begin
        k, st, n, e = _pq("#~ _hide\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unknown alterant action \"_hide\"", e.msg)
    end
    # r34 [needs-a-run] — CHANGED — BEFORE: THROWS BoundsError
    @testset "r34" begin
        k, st, n, e = _pq("#~ hide .\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unknown alterant action \".\"", e.msg)
    end
    # r35 [needs-a-run] — CHANGED — BEFORE: THROWS BoundsError
    @testset "r35" begin
        k, st, n, e = _pq("s = \"a #~ hide \"\ny = 2\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unexpected character '\"' at the start of a metaStatement", e.msg)
    end
    # r36 [needs-a-run] — CHANGED — BEFORE: OK PROCESS_OK, 1 evals rows
    @testset "r36" begin
        k, st, n, e = _pq("#~ hide{isCode}show\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unexpected character 's' after the metaStatement \"hide{isCode}\"", e.msg)
    end
    # r37 [needs-a-run] — CHANGED — BEFORE: OK PROCESS_OK, 2 evals rows
    @testset "r37" begin
        k, st, n, e = _pq("#~ hide()junk\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unexpected character 'j' after the metaStatement \"hide()\"", e.msg)
    end
    # r38 [needs-a-run] — CHANGED — BEFORE: OK PROCESS_OK, 1 evals rows
    @testset "r38" begin
        k, st, n, e = _pq("#~ \"T\"junk\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unexpected character 'j' after the metaStatement", e.msg)
    end
    # r39 [needs-a-run] — UNCHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "x"
    @testset "r39" begin
        k, st, n, e = _pq("#~ hide{ x == \"}\" }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"x\"", e.msg)
    end
    # r40 [needs-a-run] — UNCHANGED — BEFORE: OK PROCESS_OK, 1 evals rows
    @testset "r40" begin
        k, st, n, e = _pq("#~ head(\"T (sub)\", 2)\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 1
    end
    # r41 [needs-a-run] — UNCHANGED — BEFORE: THROWS ErrorException: GoMeta absorb: string argument not accepted
    @testset "r41" begin
        k, st, n, e = _pq("#~ :(\"a,b\")\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: string argument not accepted", e.msg)
    end
    # r42 [needs-a-run] — UNCHANGED — BEFORE: OK PROCESS_OK, 4 evals rows
    @testset "r42" begin
        k, st, n, e = _pq("#~ :label1\u0085hide\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 4
    end
    # r43 [needs-a-run] — CHANGED — BEFORE: OK PROCESS_OK, 2 evals rows
    @testset "r43" begin
        k, st, n, e = _pq("#~ :label1\u2028hide\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unknown label", e.msg)
    end
    # r44 [needs-a-run] — CHANGED — BEFORE: OK PROCESS_OK, 2 evals rows
    @testset "r44" begin
        k, st, n, e = _pq("#~ :label1\u2029hide\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unknown label", e.msg)
    end
    # r45 [needs-a-run] — CHANGED — BEFORE: OK PROCESS_OK, 2 evals rows
    @testset "r45" begin
        k, st, n, e = _pq("#~ :label1\u180ehide\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("unknown label", e.msg)
    end
    # r46 [needs-a-run] — UNCHANGED — BEFORE: OK PROCESS_OK, 2 evals rows
    @testset "r46" begin
        k, st, n, e = _pq("#~ hide\x0cshow\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 2
    end
    # r47 [needs-a-run] — UNCHANGED — BEFORE: OK PROCESS_OK, 2 evals rows
    @testset "r47" begin
        k, st, n, e = _pq("#~ hide\x0bshow\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 2
    end
    # r48 [needs-a-run] — UNCHANGED — BEFORE: OK PROCESS_OK, 4 evals rows
    @testset "r48" begin
        k, st, n, e = _pq("#~ cell(7) parent(3)\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 4
    end
    # r49 [needs-a-run] — UNCHANGED — BEFORE: OK PROCESS_OK, 1 evals rows
    @testset "r49" begin
        k, st, n, e = _pq("#~ head(\"Canonical\", 4)\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 1
    end
    # q01 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ParseError
    @testset "q01" begin
        k, st, n, e = _pq("#~ hide{ isCode == \"}\" }\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # q02 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "name"
    @testset "q02" begin
        k, st, n, e = _pq("#~ hide{ name == \"abc\" }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"name\"", e.msg)
    end
    # q03 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "s"
    @testset "q03" begin
        k, st, n, e = _pq("#~ hide{ s == \"a, b\" }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"s\"", e.msg)
    end
    # q04 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "s"
    @testset "q04" begin
        k, st, n, e = _pq("#~ hide{ s == \":x\" }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"s\"", e.msg)
    end
    # q05 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "s"
    @testset "q05" begin
        k, st, n, e = _pq("#~ hide{ s == \"(\" }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"s\"", e.msg)
    end
    # q06 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unterminated condition block
    @testset "q06" begin
        k, st, n, e = _pq("#~ hide{ s == \"{\" }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"s\"", e.msg)
    end
    # q07 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "c"
    @testset "q07" begin
        k, st, n, e = _pq("#~ hide{ c == '}' }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"c\"", e.msg)
    end
    # q08 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "s"
    @testset "q08" begin
        k, st, n, e = _pq("#~ hide{ s == \"a\\\"b\" }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"s\"", e.msg)
    end
    # q09 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "s"
    @testset "q09" begin
        k, st, n, e = _pq("#~ hide{ s == \"unterminated }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unterminated '\"'", e.msg)
    end
    # q10 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "s"
    @testset "q10" begin
        k, st, n, e = _pq("#~ hide{ s == \"\" }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"s\"", e.msg)
    end
    # q11 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "s"
    @testset "q11" begin
        k, st, n, e = _pq("#~ hide{ s == \"\u65e5\u672c\" }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"s\"", e.msg)
    end
    # q12 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "s"
    @testset "q12" begin
        k, st, n, e = _pq("#~ hide{ s == \"\"\"x\"\"\" }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"s\"", e.msg)
    end
    # q13 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "s"
    @testset "q13" begin
        k, st, n, e = _pq("#~ hide{ s == r\"a}b\" }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"s\"", e.msg)
    end
    # q14 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "s"
    @testset "q14" begin
        k, st, n, e = _pq("#~ hide{ s == \"\\\\\" }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"s\"", e.msg)
    end
    # q15 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "s"
    @testset "q15" begin
        k, st, n, e = _pq("#~ hide{ s == \"a\" || t == \"b\" }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"s\"", e.msg)
    end
    # q16 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "s"
    @testset "q16" begin
        k, st, n, e = _pq("#~ hide{ :label1 || s == \":label2\" }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"s\"", e.msg)
    end
    # q17 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "s"
    @testset "q17" begin
        k, st, n, e = _pq("#~ hide{ isCode && (s == \")\") }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"s\"", e.msg)
    end
    # q18 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException
    @testset "q18" begin
        k, st, n, e = _pq("#~ hide{ { isCode } }\nx = 1\n")
        @test k === :throw && e isa ErrorException
    end
    # q19 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "f"
    @testset "q19" begin
        k, st, n, e = _pq("#~ hide{ f(\"x\", \")\") }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"f\"", e.msg)
    end
    # q20 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "codeLines"
    @testset "q20" begin
        k, st, n, e = _pq("#~ hide{ codeLines > 5 }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"codeLines\"", e.msg)
    end
    # q21 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "author"
    @testset "q21" begin
        k, st, n, e = _pq("#~ hide{ author == \"Weber\" }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"author\"", e.msg)
    end
    # q22 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: string argument not accepted
    @testset "q22" begin
        k, st, n, e = _pq("#~ hide(\"a,b\", c)\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: string argument not accepted", e.msg)
    end
    # q23 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: string argument not accepted
    @testset "q23" begin
        k, st, n, e = _pq("#~ hide(\"a)b\")\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: string argument not accepted", e.msg)
    end
    # q24 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: string argument not accepted
    @testset "q24" begin
        k, st, n, e = _pq("#~ hide(\"a\", \"b,c\")\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: string argument not accepted", e.msg)
    end
    # q25 [quote-scan] — QUOTE-SCAN — BEFORE: OK PROCESS_OK, 1 evals rows
    @testset "q25" begin
        k, st, n, e = _pq("#~ head(\"T (sub)\", 2)\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 1
    end
    # q26 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: string argument not accepted
    @testset "q26" begin
        k, st, n, e = _pq("#~ :(\"a,b\")\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: string argument not accepted", e.msg)
    end
    # q27 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: string argument not accepted
    @testset "q27" begin
        k, st, n, e = _pq("#~ :(\"a\", b)\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: string argument not accepted", e.msg)
    end
    # q28 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unknown alterant action "isCode"
    @testset "q28" begin
        k, st, n, e = _pq("#~ \"T}\" { isCode }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unexpected character '{' at the start of a metaStatement in the meta region \"\\\"T}\\\" { isCode }\" (the token \"{\")", e.msg)
    end
    # q29 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "s"
    @testset "q29" begin
        k, st, n, e = _pq("#~ \"T\"{ s == \"}\" }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"s\"", e.msg)
    end
    # q30 [quote-scan] — QUOTE-SCAN — BEFORE: OK PROCESS_OK, 1 evals rows
    @testset "q30" begin
        k, st, n, e = _pq("#~ \"T (x)\"\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 1
    end
    # q31 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: backslash in a quoted heading
    @testset "q31" begin
        k, st, n, e = _pq("#~ \"T\\\"x\"\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: backslash in a quoted span", e.msg)
    end
    # q32 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unterminated quoted heading
    @testset "q32" begin
        k, st, n, e = _pq("#~ \"unterminated\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unterminated '\"'", e.msg)
    end
    # q33 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "x"
    @testset "q33" begin
        k, st, n, e = _pq("#~ :label{ x == \"}\" }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"x\"", e.msg)
    end
    # q34 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ParseError
    @testset "q34" begin
        k, st, n, e = _pq("#~ cell(7){ isCode == \"}\" }\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # q35 [quote-scan] — QUOTE-SCAN — BEFORE: OK PROCESS_OK, 1 evals rows
    @testset "q35" begin
        k, st, n, e = _pq("#~ hide{ isCode }show\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unexpected character 's' after the metaStatement \"hide{ isCode }\" in the meta region \"hide{ isCode }show\" (the token \"show\") (see docs/public-api.md \u00a73.4)", e.msg)
    end
    # q36 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: duplicate condition block
    @testset "q36" begin
        k, st, n, e = _pq("#~ hide{isCode}{isCode}\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unexpected character '{' after the metaStatement \"hide{isCode}\" in the meta region \"hide{isCode}{isCode}\" (the token \"{isCode}\")", e.msg)
    end
    # q37 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unterminated condition block
    @testset "q37" begin
        k, st, n, e = _pq("#~ hide{ isCode == \"{\" }\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # q38 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "s"
    @testset "q38" begin
        k, st, n, e = _pq("#~ hide{ s == \"}\" }show\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"s\"", e.msg)
    end
    # q39 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "s"
    @testset "q39" begin
        k, st, n, e = _pq("#~ hide( \"x\" ){ s == \")\" }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"s\"", e.msg)
    end
    # q40 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "s"
    @testset "q40" begin
        k, st, n, e = _pq("#~ hide{ s == \"a\" } show{ t == \"b\" }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"s\"", e.msg)
    end
    # s01 [quote-scan] — CHANGED (strings in conditions) — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "a"
    @testset "s01" begin
        k, st, n, e = _pq("#~ hide{ isCode == \"a } show{ isText == \" }\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # s02 [quote-scan] — CHANGED (strings in conditions) — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "a"
    @testset "s02" begin
        k, st, n, e = _pq("#~ hide{ isCode == \"a \"isCode\" c\" }\nx = 1\n")
        @test k === :throw && e isa Base.Meta.ParseError
    end
    # s04 [quote-scan] — CHANGED (strings in conditions) — BEFORE: OK PROCESS_OK, 0 evals rows
    @testset "s04" begin
        k, st, n, e = _pq("#~ hide{ :\"x\" }\nx = 1\n")
        @test k === :throw && e isa Base.Meta.ParseError
    end
    # s05 [quote-scan] — CHANGED (strings in conditions) — BEFORE: OK PROCESS_OK, 1 evals rows
    @testset "s05" begin
        k, st, n, e = _pq("#~ hide{ :a\"b\", isCode }\nx = 1\n")
        @test k === :throw && e isa Base.Meta.ParseError
    end
    # s09 [quote-scan] — QUOTE-SCAN — BEFORE: OK PROCESS_OK, 0 evals rows
    @testset "s09" begin
        k, st, n, e = _pq("#~ hide{ isCode == '\"' }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unterminated '\"'", e.msg)
    end
    # s10 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unterminated condition block
    @testset "s10" begin
        k, st, n, e = _pq("#~ hide{ isCode == '{' }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unterminated '{'", e.msg)
    end
    # s13 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ParseError
    @testset "s13" begin
        k, st, n, e = _pq("#~ hide{ isCode == \u201c}\u201d }\nx = 1\n")
        @test k === :throw && e isa Base.Meta.ParseError
    end
    # s16a [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unterminated condition block
    @testset "s16a" begin
        k, st, n, e = _pq("#~ hide{ isCode == \"\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unterminated '\"'", e.msg)
    end
    # s16b [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unterminated quoted argument
    @testset "s16b" begin
        k, st, n, e = _pq("#~ hide(\"\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unterminated '\"'", e.msg)
    end
    # s16c [quote-scan] — QUOTE-SCAN — BEFORE: THROWS BoundsError
    @testset "s16c" begin
        k, st, n, e = _pq("#~ hide \"\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unexpected character '\"' at the start of a metaStatement in the meta region \"hide \\\"\" (the token \"\\\"\")", e.msg)
    end
    # s22 [quote-scan] — CHANGED (strings in conditions) — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "x"
    @testset "s22" begin
        k, st, n, e = _pq("#~ hide{ isCode\"x\" }\nx = 1\n")
        @test k === :throw && e isa Base.Meta.ParseError
    end
    # s23 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "s"
    @testset "s23" begin
        k, st, n, e = _pq("#~ hide{ s == \"\"\"a\"b\"\"\" }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unterminated '\"'", e.msg)
    end
    # s25a [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: malformed quoted argument
    @testset "s25a" begin
        k, st, n, e = _pq("#~ hide(\"a) show(\"b)\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: malformed quoted argument", e.msg)
    end
    # s25b [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unterminated quoted argument
    @testset "s25b" begin
        k, st, n, e = _pq("#~ hide(\"a) show(\"b\")\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unterminated '\"'", e.msg)
    end
    # t01 [quote-scan] — CHANGED (strings in conditions) — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "a"
    @testset "t01" begin
        k, st, n, e = _pq("#~ hide{ isCode == \"a\" } show{ isText == \"b\" }\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # t02 [quote-scan] — CHANGED (strings in conditions) — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "it"
    @testset "t02" begin
        k, st, n, e = _pq("#~ hide{ isCode == \"it's\" }\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # t03 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: string argument not accepted
    @testset "t03" begin
        k, st, n, e = _pq("#~ hide( \"x\" )\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: string argument not accepted", e.msg)
    end
    # t04 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "s"
    @testset "t04" begin
        k, st, n, e = _pq("#~ :label1 hide{ s == \"}\" }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"s\"", e.msg)
    end
    # j02t [quote-scan] — CHANGED (strings in conditions) — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "abc"
    @testset "j02t" begin
        k, st, n, e = _pq("#~ hide{ isCode == \"abc\" }\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # j03t [quote-scan] — CHANGED (strings in conditions) — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "a"
    @testset "j03t" begin
        k, st, n, e = _pq("#~ hide{ isCode == \"a, b\" }\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # j03u [quote-scan] — QUOTE-SCAN — BEFORE: OK PROCESS_OK, 0 evals rows
    @testset "j03u" begin
        k, st, n, e = _pq("#~ hide{ isCode == \",\" }\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # j04t [quote-scan] — CHANGED (strings in conditions) — BEFORE: THROWS ParseError
    @testset "j04t" begin
        k, st, n, e = _pq("#~ hide{ isCode == \":x\" }\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # j05t [quote-scan] — QUOTE-SCAN — BEFORE: OK PROCESS_OK, 0 evals rows
    @testset "j05t" begin
        k, st, n, e = _pq("#~ hide{ isCode == \"(\" }\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # j07t [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ParseError
    @testset "j07t" begin
        k, st, n, e = _pq("#~ hide{ isCode == '}' }\nx = 1\n")
        @test k === :throw && e isa Base.Meta.ParseError
    end
    # j08t [quote-scan] — CHANGED (strings in conditions) — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "a"
    @testset "j08t" begin
        k, st, n, e = _pq("#~ hide{ isCode == \"a\\\"b\" }\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # j09t [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "unterminated"
    @testset "j09t" begin
        k, st, n, e = _pq("#~ hide{ isCode == \"unterminated }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unterminated '\"'", e.msg)
    end
    # j10t [quote-scan] — QUOTE-SCAN — BEFORE: OK PROCESS_OK, 0 evals rows
    @testset "j10t" begin
        k, st, n, e = _pq("#~ hide{ isCode == \"\" }\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # j11t [quote-scan] — CHANGED (strings in conditions) — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "日本"
    @testset "j11t" begin
        k, st, n, e = _pq("#~ hide{ isCode == \"\u65e5\u672c\" }\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # j12t [quote-scan] — CHANGED (strings in conditions) — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "x"
    @testset "j12t" begin
        k, st, n, e = _pq("#~ hide{ isCode == \"\"\"x\"\"\" }\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # j13t [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "r"
    @testset "j13t" begin
        k, st, n, e = _pq("#~ hide{ isCode == r\"a}b\" }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"r\"", e.msg)
    end
    # j14t [quote-scan] — QUOTE-SCAN — BEFORE: OK PROCESS_OK, 0 evals rows
    @testset "j14t" begin
        k, st, n, e = _pq("#~ hide{ isCode == \"\\\\\" }\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # j15t [quote-scan] — CHANGED (strings in conditions) — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "a"
    @testset "j15t" begin
        k, st, n, e = _pq("#~ hide{ isCode == \"a\" || isText == \"b\" }\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # j16t [quote-scan] — CHANGED (strings in conditions) — BEFORE: THROWS ParseError
    @testset "j16t" begin
        k, st, n, e = _pq("#~ hide{ :label1 || isCode == \":label2\" }\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # j17t [quote-scan] — QUOTE-SCAN — BEFORE: OK PROCESS_OK, 0 evals rows
    @testset "j17t" begin
        k, st, n, e = _pq("#~ hide{ isCode && (isText == \")\") }\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # j19t [quote-scan] — QUOTE-SCAN — BEFORE: THROWS MethodError
    @testset "j19t" begin
        k, st, n, e = _pq("#~ hide{ isCode(\"x\", \")\") }\nx = 1\n")
        @test k === :throw && e isa MethodError
    end
    # j29t [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ParseError
    @testset "j29t" begin
        k, st, n, e = _pq("#~ \"T\"{ isCode == \"}\" }\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # j38t [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ParseError
    @testset "j38t" begin
        k, st, n, e = _pq("#~ hide{ isCode == \"}\" }show\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unexpected character 's' after the metaStatement \"hide{ isCode == \\\"}\\\" }\" in the meta region \"hide{ isCode == \\\"}\\\" }show\" (the token \"show\") (see docs/public-api.md \u00a73.4)", e.msg)
    end
    # j39t [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: string argument not accepted
    @testset "j39t" begin
        k, st, n, e = _pq("#~ hide( \"x\" ){ isCode == \")\" }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: string argument not accepted", e.msg)
    end
    # j40t [quote-scan] — CHANGED (strings in conditions) — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "a"
    @testset "j40t" begin
        k, st, n, e = _pq("#~ hide{ isCode == \"a\" } show{ isText == \"b\" }\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # jS1p [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "a"
    @testset "jS1p" begin
        k, st, n, e = _pq("#~ hide{ isCode == \"a } show{ isText == \"b\" }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unterminated '\"'", e.msg)
    end
    # jX2 [quote-scan] — CHANGED (strings in conditions) — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "abc"
    @testset "jX2" begin
        k, st, n, e = _pq("#~ hide{ \"abc\" }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: the condition block { \"abc\" } carries no condition expression (a bare literal) \u2014 an unconditional action is written without '{}'", e.msg)
    end
    # jX3 [quote-scan] — CHANGED (strings in conditions) — BEFORE: THROWS ParseError
    @testset "jX3" begin
        k, st, n, e = _pq("#~ hide{ isCode( }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unterminated '(' \u2014 never closed in the meta region \" isCode( \" (1 still open)", e.msg)
    end
    # jX4 [quote-scan] — CHANGED (strings in conditions) — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "x"
    @testset "jX4" begin
        k, st, n, e = _pq("#~ hide{ :(x }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unterminated '(' \u2014 never closed in the meta region \" :(x \" (1 still open)", e.msg)
    end
    # jX5 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ParseError
    @testset "jX5" begin
        k, st, n, e = _pq("#~ hide{ (isCode }\nx = 1\n")
        @test k === :throw && e isa Base.Meta.ParseError
    end
    # jX7 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unterminated condition block
    @testset "jX7" begin
        k, st, n, e = _pq("#~ hide{ isCode == \"a\\\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unterminated '\"'", e.msg)
    end
    # jX8 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "a"
    @testset "jX8" begin
        k, st, n, e = _pq("#~ hide{ isCode == \"a\\\" }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unterminated '\"'", e.msg)
    end
    # jX9 [quote-scan] — CHANGED (strings in conditions) — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "x"
    @testset "jX9" begin
        k, st, n, e = _pq("#~ hide{ isCode == \"\$x\" }\nx = 1\n")
        @test k === :throw && e isa UndefVarError
    end
    # jX10 [quote-scan] — CHANGED (strings in conditions) — BEFORE: OK PROCESS_OK, 0 evals rows
    @testset "jX10" begin
        k, st, n, e = _pq("#~ hide{ :\"x\" }\nx = 1\n")
        @test k === :throw && e isa Base.Meta.ParseError
    end
    # jX11 [quote-scan] — CHANGED (strings in conditions) — BEFORE: OK PROCESS_OK, 0 evals rows
    @testset "jX11" begin
        k, st, n, e = _pq("#~ hide{ :a\"b\" }\nx = 1\n")
        @test k === :throw && e isa Base.Meta.ParseError
    end
    # jX12 [quote-scan] — CHANGED (strings in conditions) — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "x"
    @testset "jX12" begin
        k, st, n, e = _pq("#~ hide{ isCode\"x\" }\nx = 1\n")
        @test k === :throw && e isa Base.Meta.ParseError
    end
    # jX13 [quote-scan] — CHANGED (strings in conditions) — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "a"
    @testset "jX13" begin
        k, st, n, e = _pq("#~ hide{ isCode == \"a\" \"b\" }\nx = 1\n")
        @test k === :throw && e isa Base.Meta.ParseError
    end
    # jX14 [quote-scan] — CHANGED (strings in conditions) — BEFORE: OK PROCESS_OK, 0 evals rows
    @testset "jX14" begin
        k, st, n, e = _pq("#~ hide{ :label1==\"x\" }\nx = 1\n")
        @test k === :throw && e isa Base.Meta.ParseError
    end
    # jX15 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ParseError
    @testset "jX15" begin
        k, st, n, e = _pq("#~ hide{ isCode == \"\u201c}\u201d\" }\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # jX17 [quote-scan] — CHANGED (strings in conditions) — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "a"
    @testset "jX17" begin
        k, st, n, e = _pq("#~ hide{ isCode == \"a\u200bb\" }\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # jX18 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unterminated condition block
    @testset "jX18" begin
        k, st, n, e = _pq("#~ hide{ isCode == \"a # b\" }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unterminated '\"'", e.msg)
    end
    # jX19 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "a"
    @testset "jX19" begin
        k, st, n, e = _pq("#~ hide{ isCode == \"\"\"a\"b\"\"\" }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unterminated '\"'", e.msg)
    end
    # jX20 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ParseError
    @testset "jX20" begin
        k, st, n, e = _pq("#~ hide{ isCode == `}` }\nx = 1\n")
        @test k === :throw && e isa Base.Meta.ParseError
    end
    # jP1 [quote-scan] — CHANGED (strings in conditions) — BEFORE: THROWS ErrorException: GoMeta absorb: unknown condition key "f"
    @testset "jP1" begin
        k, st, n, e = _pq("#~ hide{ isCode == \"f(\" }\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # jP2 [quote-scan] — QUOTE-SCAN — BEFORE: OK PROCESS_OK, 0 evals rows
    @testset "jP2" begin
        k, st, n, e = _pq("#~ hide{ isCode == \":(\" }\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 0
    end
    # jA7 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: malformed quoted argument
    @testset "jA7" begin
        k, st, n, e = _pq("#~ hide(\"a) show(\"b)\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: malformed quoted argument", e.msg)
    end
    # jA8 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unterminated quoted argument
    @testset "jA8" begin
        k, st, n, e = _pq("#~ hide(\"a) show(\"b\")\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unterminated '\"'", e.msg)
    end
    # jA11 [quote-scan] — QUOTE-SCAN — BEFORE: OK PROCESS_OK, 2 evals rows
    @testset "jA11" begin
        k, st, n, e = _pq("#~ hide()\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 2
    end
    # jA12 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS MethodError
    @testset "jA12" begin
        k, st, n, e = _pq("#~ cell(7,)\nx = 1\n")
        @test k === :throw && e isa MethodError
    end
    # jA13 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS MethodError
    @testset "jA13" begin
        k, st, n, e = _pq("#~ hide(f(a,b), c)\nx = 1\n")
        @test k === :throw && e isa MethodError
    end
    # jA14 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unterminated argument list
    @testset "jA14" begin
        k, st, n, e = _pq("#~ :(label1\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unterminated '('", e.msg)
    end
    # jA15 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: backslash in a quoted argument
    @testset "jA15" begin
        k, st, n, e = _pq("#~ :(\"a\\b\")\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: backslash in a quoted span", e.msg)
    end
    # jA16a [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unknown alterant action "hide\""
    @testset "jA16a" begin
        k, st, n, e = _pq("#~ hide\"\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unexpected character '\"' after the metaStatement \"hide\" in the meta region \"hide\\\"\" (the token \"\\\"\")", e.msg)
    end
    # jA16b [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unknown alterant action "hide\"x\""
    @testset "jA16b" begin
        k, st, n, e = _pq("#~ hide\"x\"\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unexpected character '\"' after the metaStatement \"hide\" in the meta region \"hide\\\"x\\\"\" (the token \"\\\"x\\\"\")", e.msg)
    end
    # jA17a [quote-scan] — QUOTE-SCAN — BEFORE: OK PROCESS_OK, 1 evals rows
    @testset "jA17a" begin
        k, st, n, e = _pq("#~ \"T\"junk\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unexpected character 'j' after the metaStatement \"\\\"T\\\"\" in the meta region \"\\\"T\\\"junk\" (the token \"junk\") (see docs/public-api.md \u00a73.4)", e.msg)
    end
    # jA17b [quote-scan] — QUOTE-SCAN — BEFORE: OK PROCESS_OK, 1 evals rows
    @testset "jA17b" begin
        k, st, n, e = _pq("#~ \"a\"\"b\"\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unexpected character '\"' after the metaStatement \"\\\"a\\\"\" in the meta region \"\\\"a\\\"\\\"b\\\"\" (the token \"\\\"b\\\"\")", e.msg)
    end
    # jA18 [quote-scan] — QUOTE-SCAN — BEFORE: OK PROCESS_OK, 1 evals rows
    @testset "jA18" begin
        k, st, n, e = _pq("#~ \"a \$x\"\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 1
    end
    # jA19 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: backslash in a quoted argument
    @testset "jA19" begin
        k, st, n, e = _pq("#~ :\"a\\b\"\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unexpected character '\"' after ':' in the meta region \":\\\"a\\\\b\\\"\" (the token \"\\\"a\\\\b\\\"\")", e.msg)
    end
    # jH2 [quote-scan] — QUOTE-SCAN — BEFORE: THROWS ErrorException: GoMeta absorb: unknown alterant action "+:"
    @testset "jH2" begin
        k, st, n, e = _pq("#~ +:(label1)\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown alterant action \"+:\"", e.msg)
    end
    # jC1 [witness] — WITNESS (a quoted text is copied whole, never read for the comma; the outcome MEASURED from the FULL delivery view) — BEFORE: none (the row is new); MEASURED: OK PROCESS_OK, 2 evals rows — the comma inside the quoted text is Julia's, copied whole, never split by the rewrite's `,` arm; the condition `"," == "\x2c"` is true and the hide applies (0 rows if the comma were rewritten to ` || `)
    @testset "jC1" begin
        k, st, n, e = _pq("#~ hide{ \",\" == \"\\x2c\" }\nx = 1\n")
        @test k === :ok && st == GM.PROCESS_OK && n == 2
    end
    # jG1 [invalid-char-guard] — GUARD (the invalid-Char guard in the rewrite's two identifier tests, the creator's word of 2026-10-09; the outcome MEASURED after the guard) — BEFORE: THROWS InvalidCharError: Base.InvalidCharError{Char}('\xff') — the shape: an invalid byte alone inside the condition body; AFTER: THROWS ParseError: ParseError: # Error @ none:1:2  \xff  #╙ ── invalid UTF-8 sequence "\xff"
    @testset "jG1" begin
        k, st, n, e = _pq("#~ hide{ \xff }\nx = 1\n")
        @test k === :throw && e isa Base.Meta.ParseError
    end
    # jG2 [invalid-char-guard] — GUARD (the invalid-Char guard in the rewrite's two identifier tests, the creator's word of 2026-10-09; the outcome MEASURED after the guard) — BEFORE: THROWS InvalidCharError: Base.InvalidCharError{Char}('\xe9') — the shape: an invalid byte glued to a known key; AFTER: THROWS ParseError: ParseError: # Error @ none:1:19  getState(:isCode)\xe9  #                 ╙ ── invalid UTF-8 sequence "\xe9"
    @testset "jG2" begin
        k, st, n, e = _pq("#~ hide{ isCode\xe9 }\nx = 1\n")
        @test k === :throw && e isa Base.Meta.ParseError
    end
    # jG3 [invalid-char-guard] — GUARD (the invalid-Char guard in the rewrite's two identifier tests, the creator's word of 2026-10-09; the outcome MEASURED after the guard) — BEFORE: THROWS InvalidCharError: Base.InvalidCharError{Char}('\xe9') — the shape: an invalid byte inside an unknown word (Latin-1 'café'); AFTER: THROWS ErrorException: GoMeta absorb: unknown condition key "caf"
    @testset "jG3" begin
        k, st, n, e = _pq("#~ hide{ caf\xe9 }\nx = 1\n")
        @test k === :throw && e isa ErrorException
        @test occursin("GoMeta absorb: unknown condition key \"caf\"", e.msg)
    end
end
