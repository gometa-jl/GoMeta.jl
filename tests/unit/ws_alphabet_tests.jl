# tests/unit/ws_alphabet_tests.jl — F-14 WS-ALPHABET matrix (owner-ruled 2026-08-08:
# "Unicode horizontal whitespace (\\h) as THE delimiter class, unified everywhere").
#
# THE RULING'S REASONS, pinned: the original grammar was owner-authored `[\\h]`;
# international keyboards must delimit (U+3000 = CJK full-width IME space, U+00A0 = Mac
# Option+Space / French typography); the emoji/plugin-head future requires char-safe
# multibyte token machinery. Boundary law: newline-class chars stay LINE boundaries;
# zero-width FORMAT chars (U+200B et al.) are NOT whitespace and never delimit.
#
# GENERATED FILE NOTE: the exotic characters below are REAL codepoints (byte-verified at
# authoring: NBSP=C2A0, U+3000=E38080, ZWSP=E2808B) — editors may render them invisibly.

using Test
import GoMeta as GM

_ws_r(s; flavor=nothing) = begin
    cfg = flavor === nothing ? GM.GoMetaConfig() : GM.GoMetaConfig(flavor_tag=flavor)
    GM.goMeta(Vector{UInt8}(s); config=cfg)
end
_ws_render(s; kw...) = String(copy(GM.outputs(_ws_r(s; kw...)).render_bytes))
_ws_tree(s; kw...)   = String(copy(GM.outputs(_ws_r(s; kw...)).blsStructure_bytes))
_ws_err(s; kw...)    = try _ws_r(s; kw...); nothing catch e sprint(showerror, e) end

@testset "ws_alphabet_tests (F-14 matrix)" begin

    @testset "[1] NBSP postDef: live token end-to-end (the dead crash class's witness)" begin
        # formerly a StringIndexError in the walk body extraction (byte+1 arithmetic on a
        # 2-byte postDef); now char-safe via nextind — the hide verdict LANDS through NBSP
        s = "#~ hide\nx = 1\n"
        @test _ws_err(s) === nothing
        @test _ws_r(s).status == GM.PROCESS_OK
        @test occursin("## x = 1", _ws_render(s))
    end

    @testset "[2] CJK ideographic space delimits at BOTH grains" begin
        s = "#~　hide\nx = 1\n"
        @test _ws_err(s) === nothing
        @test occursin("## x = 1", _ws_render(s))
        a = "x = 1　#~ hide\ny = 2\n"            # before-side, segment grain
        b = "x = 1 #~ hide\ny = 2\n"
        @test _ws_err(a) === nothing
        @test GM.altValues_evals(_ws_r(a)) == GM.altValues_evals(_ws_r(b))
        @test occursin(":S-Meta", _ws_tree(a))
    end

    @testset "[3] NBSP-delimited `##` comment + `#]` closer keep their classes" begin
        s = "#~ hide\n## note\ny = 1\n"          # comment ⇒ fold-eligible hidden
        r = _ws_render(s)
        @test occursin("\n## note\n", r)
        @test !occursin("## ## note", r)
        c = "x = 1 #] \ny = 2\n"                  # closer stays a close event
        @test _ws_err(c) === nothing
        @test occursin(":S-Meta", _ws_tree(c))
    end

    @testset "[4] NBSP Text lead" begin
        @test occursin(":B-Text", _ws_tree("# text\nx = 1\n"))
    end

    @testset "[5] zero-width format chars NEVER delimit (bucket A) + glued stays glued" begin
        s = "#~​hide\nx = 1\n"                    # ZWSP is Cf, not whitespace
        @test _ws_err(s) === nothing
        @test _ws_render(s) == s
        @test isempty(GM.altValues_evals(_ws_r(s)))
        @test _ws_render("#~hide\nx = 1\n") == "#~hide\nx = 1\n"
    end

    @testset "[6] cfam mirror: NBSP postDef through the shared walk (2-byte lead)" begin
        s = "//~ hide\na = 1;\n"
        @test _ws_err(s; flavor=:c) === nothing
        @test occursin("//# a = 1;", _ws_render(s; flavor=:c))
    end

    @testset "[7] the predicate is derived from the grammar class (single source)" begin
        @test GM.BLS._is_h_ws(' ') && GM.BLS._is_h_ws('\t')
        @test GM.BLS._is_h_ws(' ') && GM.BLS._is_h_ws('　')
        @test !GM.BLS._is_h_ws('​') && !GM.BLS._is_h_ws('\n') && !GM.BLS._is_h_ws('x')
        for c in (' ', '\t', ' ', '　')        # predicate ≡ the regex class
            @test occursin(GM.BLS._RE_H_WS_ONE, string(c))
        end
    end
end
