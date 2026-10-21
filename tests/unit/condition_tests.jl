# condition_tests.jl — the condition path since 0.4.0 (the creator's order and
# words): a `{…}` body's GoMeta-specific parts re-written to Julia text, Julia's parser reading it once at
# absorb, Julia evaluating the stored Expr at apply — the original engine's reading (GoMetaRetro AbsorbMeta.jl :116–:282) from the ground up.
#
# IS:   (1) the registry's ONE vocabulary rule for a bare name (`queryable_action`; the retired-keys testset
#       of the former condition_cap_tests.jl — retired with the closed interpreter — RE-HOMED here verbatim in meaning: the rule that
#       MUST survive the interpreter's removal); (2) the parser-quality rows of the Julia intake (the creator's words): what Julia's parser accepts that the
#       closed interpreter refused (the 29-step cap's inversion, the glued grouping, a Julia Boolean expression), what it
#       refuses and in which CLASS (Julia's own `Meta.ParseError` for a malformed or incomplete body; GoMeta's one refusal for an
#       empty block or a bare literal; Julia's own error at apply for an argument it cannot dispatch), and the
#       operators the creator's corpus writes (`,` as OR, `&&`, `!`, `()`).
# DOES: drives each shape through goMeta on a one-line document and pins the status, the render (the development tool's pair) and
#       the error class or message substring. Every pinned value was MEASURED on the tree that introduced the Julia intake (the Julia-intake
#       rows, the re-homed rows and the two render pins); a row added or re-pinned since names its change in its comment — the
#       unterminated-block head, the quoted-text rows and the timing witness below.
# PURPOSE: the condition path's witnesses in one file — the vocabulary rule's and the Julia intake's.

using Test
import GoMeta as GM

_cn_mk(cond) = Vector{UInt8}(codeunits("#~ hide{ $cond }\nx = 1\n"))
_cn_hidden(r) = occursin("## x = 1", String(copy(Main.BasicRenderer.outputs(r)[2])))
_cn_err(bytes) = try
    GM.goMeta(bytes)
    nothing
catch e
    e
end

@testset "the registry's vocabulary rule — retired condition keys refuse as unknown" begin
    # the creator's word: the three Visib names are no condition keys — "Just the usual error / refusal message."
    # MEASURED before the removal: `#~ hide{ show }` was PROCESS_OK
    # with 0 evals rows — the key accepted and silently false. The three names were removed from BLS's ComponentSettribute — necessary, NOT
    # sufficient: with the names out of BLS alone `#~ hide{ show }` was STILL PROCESS_OK (the intake
    # read `show` as a registered ACTION); the registry's `queryable_action` rule (src/state.jl) refuses a getter-less Alterant's action,
    # so the unknown-condition-key refusal names them — from the rewrite's `_cond_target` (src/absorb/absorb_meta.jl), where
    # the original engine's reader tested `insorted`. The control: a live settribute key applies.
    for k in ("show", "hide", "discard")
        e = _cn_err(_cn_mk(k))
        @test e isa ErrorException
        @test occursin("unknown condition key \"$k\"", e.msg)
    end
    r = GM.goMeta(_cn_mk("isCode"))
    @test r.status === GM.PROCESS_OK && _cn_hidden(r)
    # Id's and the Heading's actions answer no query either — the same refusal, with or without an argument list (the former
    # `{ cell }` form retired with the interpreter, no code mint pending, the rule decides at absorb)
    e1 = _cn_err(_cn_mk("cell(7)"))
    @test e1 isa ErrorException && occursin("unknown condition key \"cell\"", e1.msg)
    e2 = _cn_err(_cn_mk("head"))
    @test e2 isa ErrorException && occursin("unknown condition key \"head\"", e2.msg)
end

@testset "the operators the creator's corpus writes — `,` is OR, `&&`, `!`, `()` (Julia's reading of the re-written body)" begin
    @test _cn_hidden(GM.goMeta(_cn_mk("isText , isCode")))        # `,` → `||`: the code line hides on the second disjunct
    @test !_cn_hidden(GM.goMeta(_cn_mk("isCode && isText")))      # a code line is not text
    @test _cn_hidden(GM.goMeta(_cn_mk("!isText")))                # `!` prefix
    @test _cn_hidden(GM.goMeta(_cn_mk("(isCode)")))               # the glued grouping: refused "unknown condition
                                                                #   key `isCode)`" by the closed scanner, read by Julia's parser since 0.4.0
    @test _cn_hidden(GM.goMeta(_cn_mk("(isText && containsMeta), isCode")))   # a grouped disjunction over a code line
end

@testset "the closed interpreter's walls are gone — Julia's parser has none" begin
    # 13 comma-joined atoms = far over the former 29-step scan cap, which refused "condition too complex" with the deciding
    # atom unscanned; Julia reads the whole body — the deciding `isCode` hides the code line
    r13 = GM.goMeta(_cn_mk(join(fill("isText", 12), ", ") * ", isCode"))
    @test r13.status === GM.PROCESS_OK
    @test _cn_hidden(r13)
    # the 9-atom OR chain (under the former cap): TRUE hides; the all-FALSE twin on a text line renders the byte-exact passthrough
    r9 = GM.goMeta(_cn_mk(join(fill("isText", 8), ", ") * ", isCode"))
    @test r9.status === GM.PROCESS_OK && _cn_hidden(r9)
    rf = GM.goMeta(Vector{UInt8}(codeunits("#~ hide{ " * join(fill("isCode", 9), ", ") * " }\n# t\n")))
    @test rf.status === GM.PROCESS_OK
    @test String(copy(Main.BasicRenderer.outputs(rf)[2])) == "#~ hide{ isCode, isCode, isCode, isCode, isCode, isCode, isCode, isCode, isCode }\n# t\n"
    # a 40-character label name (the former atom wall refused it) is a label test like any other — unknown, so false, no row
    r40 = GM.goMeta(_cn_mk(":" * repeat("a", 40)))
    @test r40.status === GM.PROCESS_OK && !_cn_hidden(r40)
    # a Julia Boolean expression over no GoMeta name at all is a condition (the creator's words — the full parser): TRUE hides, FALSE does not
    @test _cn_hidden(GM.goMeta(_cn_mk("1 == 1")))
    @test !_cn_hidden(GM.goMeta(_cn_mk("1 == 2")))
end

@testset "what refuses, and in which class" begin
    # a body Julia cannot parse — Julia's own ParseError out of the goMeta call (the former coded "unparsable condition")
    @test _cn_err(_cn_mk("isCode !")) isa Base.Meta.ParseError
    @test _cn_err(Vector{UInt8}(codeunits("#~ hide{ :(:x)) }\nx = 1\n"))) isa Base.Meta.ParseError   # the unbalanced ')'
    # an INCOMPLETE body is thrown as the same class AT ABSORB — never stored for a later reader (the legacy stored it and threw at apply)
    @test _cn_err(_cn_mk("isCode &&")) isa Base.Meta.ParseError
    # the TIMING witness — one metaLine, two statements: the incomplete body first, an unknown action second. absorbMeta reads every
    # statement of the region before any apply, so an incomplete Expr STORED instead of refused would let `zzznotanaction` meet the
    # unknown-action refusal (an ErrorException); the ParseError thrown at parseConditions comes first (MEASURED)
    @test _cn_err(Vector{UInt8}(codeunits("#~ hide{ isCode && } zzznotanaction\nx = 1\n"))) isa Base.Meta.ParseError
    # an EMPTY block or a bare literal carries no condition expression — GoMeta's refusal (the legacy applied unconditionally, silently)
    for body in ("{}", "{ }", "{ 1 }", "{ | }")
        e = _cn_err(Vector{UInt8}(codeunits("#~ hide" * body * "\nx = 1\n")))
        @test e isa ErrorException && occursin("carries no condition expression", e.msg)
    end
    # a quoted text inside `{}` is Julia's (the creator's word of 2026-10-08 — "strings in conditions: now"):
    # copied whole by the rewrite, never read word by word — `{ isCode == "abc" }` is Julia's comparison, false at v0.4 (every value a
    # condition reads is a Bool), so the action is never applied; `{ "abc" }` is a bare literal — "carries no condition expression"
    # (the bare-literal guard); an unclosed `(` after a key meets the one scanner's unterminated refusal (the condition path's third GoMeta
    # refusal). MEASURED. Before the change the word inside
    # the quotes was read as a condition key (`unknown condition key "abc"`).
    @test !_cn_hidden(GM.goMeta(_cn_mk("isCode == \"abc\"")))
    es = _cn_err(Vector{UInt8}(codeunits("#~ hide{ \"abc\" }\nx = 1\n")))
    @test es isa ErrorException && occursin("carries no condition expression", es.msg)
    eu = _cn_err(_cn_mk("isCode(ab"))
    @test eu isa ErrorException && occursin("GoMeta absorb: unterminated '('", eu.msg)
    # an argument text is spliced as Julia text — Julia judges it at APPLY: an undefined name, a non-Symbol label argument
    @test _cn_err(_cn_mk(":(x)")) isa UndefVarError                       # `getAltState(Int8(1), Symbol(":"), x)` — x unbound
    @test _cn_err(_cn_mk(":(7)")) isa MethodError                         # `getAltState`'s `Vararg{Symbol}`
    @test _cn_err(_cn_mk("isCode(ab)")) isa UndefVarError                 # `getState(:isCode, ab)` — the legacy dropped the argument silently (K3)
    # the unterminated block stays GoMeta's (the metaLine grammar's own)
    e = _cn_err(Vector{UInt8}(codeunits("#~ hide{ isCode\nx = 1\n")))
    @test e isa ErrorException && occursin("unterminated '{'", e.msg)      # the one scanner's R2: the opener named
end

@testset "the label test — every admitted name spelled the one way" begin
    # the ZWJ pictograph `⛓️‍💥` is no Julia identifier (U+200D is no identifier character): the closed scanner refused it QUERIED while
    # the SET role accepted it (H17); the rewrite quotes every label name by `repr`, so the query is a label test like `:label1`
    r = GM.goMeta(Vector{UInt8}(codeunits("#~ :\u26d3\ufe0f\u200d\U1f4a5 hide{ :\u26d3\ufe0f\u200d\U1f4a5 }\n# content\n")))
    @test r.status === GM.PROCESS_OK
    @test length(GM.readAltValuesEvals(r.altValues_evals)) == 4           # the label rows and the Visib rows — the set and the query agree
    # the parenthesized label form of the original engine (`:(args)`), raw
    @test GM.goMeta(Vector{UInt8}(codeunits("#~ :label1 hide{ :(:label1) }\nx = 1\n"))).status === GM.PROCESS_OK
    # a label name ending at a multibyte whitespace (the ws-alphabet law — Julia's parser reads the space; the former [3] of unicode_cure)
    r3 = GM.goMeta(Vector{UInt8}(codeunits("#~ hide{ :x\u00a0}\nx = 1\n")))
    @test r3.status === GM.PROCESS_OK && !_cn_hidden(r3)
end
