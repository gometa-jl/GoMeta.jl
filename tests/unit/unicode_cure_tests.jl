# tests/unit/unicode_cure_tests.jl — the Unicode-correctness cure witnesses.
# THE CURE: the condition scanner's end-of-text test is the CHAR predicate (lastCharInd =
# lastindex), so end-of-text is just another delimiter — a multibyte-FINAL atom flush
# against the closing brace takes its ORDINARY vocabulary fate (flush ≡ spaced). The
# companion U2 cure widens cell_content_bytes' final-character slice (nextind), keeping a
# multibyte final character whole in the verdict store.
# Every assertion below pins a MEASURED value. GENERATED file:
# exotic characters are REAL codepoints, byte-verified at authoring.

using Test
import GoMeta as GM

_uc_pc(body)   = GM.parse_condition(body)
_uc_full(s)    = GM.goMeta(Vector{UInt8}(s))
_uc_err(s)     = try _uc_full(s); nothing catch e sprint(showerror, e) end

@testset "unicode_cure_tests (the char end predicate + the store widening)" begin

    @testset "[1] flush ≡ spaced: multibyte-final atoms take the ordinary vocabulary fate" begin
        d = _uc_pc(":aß")                      # the d2 twin, flush at end-of-text
        @test d isa GM.ConditionAST
        @test GM.print_condition(d) == ":aß"
        @test GM.print_condition(_uc_pc(":é")) == ":é"
        @test GM.print_condition(_uc_pc(":🔥")) == ":🔥"
    end

    @testset "[2] store-present flush trio: apply's unknown-label names the FULL token" begin
        # Witness note: 🔥 joined the pictograph whitelist at 0.3.0, so it can no longer
        # serve as the UNKNOWN-label witness — 🐙 (not whitelisted) carries the
        # multibyte-final role in its place.
        for (lbl,) in (("é",), ("🐙",), ("aß",))
            m = _uc_err("#~ :label1 hide{:" * lbl * "}\nx = 1\n")
            @test m !== nothing
            @test occursin("unknown label", m)
            @test occursin("\"" * lbl * "\"", m)   # the FULL token, never truncated
        end
    end

    @testset "[3] multibyte-WHITESPACE-final flush (the analytically-traced path, executed)" begin
        a = _uc_pc(":x ")                      # NBSP-final, flush
        @test a isa GM.ConditionAST
        @test GM.print_condition(a) == ":x"
        @test GM.print_condition(_uc_pc(":x  ")) == ":x"
    end

    @testset "[4] CAL-14 + the honest worst case (comma-OR, unknown silently false)" begin
        g = _uc_full("#~ hide{ isCode , :zzz9 }\nx = 1\n")
        @test g.status == GM.PROCESS_OK           # ASCII control row
        @test length(GM.altValues_evals(g)) == 1
        u = _uc_full("#~ hide{ isCode , :é}\nx = 1\n")   # U1-16: formerly ABORTED
        @test u.status == GM.PROCESS_OK           # now renders WITH hide applied —
        @test length(GM.altValues_evals(u)) == 1  # measured + pre-registered
    end

    @testset "[5] preservation: walls, quirks, parity (the cure changed NOTHING else)" begin
        k = _uc_pc(":" * repeat("a", 40))         # KP-1: the cap wall unchanged
        @test k isa GM.Diagnostic && k.code === :ERR_CONDITION_CAP
        e28 = _uc_pc(":" * repeat("é", 28))     # KP-3b: cross-width parity —
        a28 = _uc_pc(":" * repeat("a", 28))       # 28 two-byte chars ≡ 28 one-byte chars
        @test e28 isa GM.ConditionAST && a28 isa GM.ConditionAST
        q = _uc_pc(":(:x))")                      # QK-1: the glued-')' quirk byte-identical
        @test q isa GM.Diagnostic && q.code === :ERR_CONDITION_PARSE
        @test GM.print_condition(_uc_pc(":ab")) == ":ab"   # CAL-12 ASCII control
    end

    @testset "[6] U2: a multibyte FINAL character survives the verdict store whole" begin
        # store-level integration: the segment's content bytes end with the COMPLETE final
        # character (NBSP c2 a0), not a lone lead byte — the widened nextind slice.
        s = "x = 1 #~ \"T\" ## c\ny = 2\n"
        r = _uc_full(s)
        @test r.status == GM.PROCESS_OK
        fps = GM.content_fingerprint(r)
        @test !isempty(fps)
        ok = false
        for (h, c) in fps
            if length(c) >= 2 && c[end-1] == 0xc2 && c[end] == 0xa0
                ok = true
            end
            # every stored content payload must be valid UTF-8 when the source is
            @test isvalid(String(copy(c)))
        end
        @test ok                                   # at least one payload ends …c2 a0
    end

    @testset "[7] the pictograph label vocabulary (0.3.0): byte-exact, both roles" begin
        # The fixed pictograph names are whitelist members BYTE-EXACTLY — incl. the
        # regional-indicator pair and a ZWJ sequence; a variation-selector-less base
        # char is a DIFFERENT byte sequence and refuses like any unknown name.
        for name in ("⛔", "💯", "🇨🇭", "⛓️‍💥", "🌛", "💫")
            @test insorted(Symbol(name), GM.Alterants.sortedSetOfLabelsSVec)
        end
        r = _uc_full("#~ :⛔ hide{ :⛔ }\n# content\n")
        @test r.status == GM.PROCESS_OK           # set role + condition role, end-to-end
        @test !insorted(Symbol("⛓"), GM.Alterants.sortedSetOfLabelsSVec)   # no VS16 ⇒ unknown
        m = _uc_err("#~ :⛓\n# content\n")
        @test m !== nothing && occursin("unknown label", m)
    end
end
