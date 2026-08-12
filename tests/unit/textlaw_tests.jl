# tests/unit/textlaw_tests.jl — the W2 KERNEL conformance matrix (behavior-zero wave:
# the kernel is UNWIRED; these tests pin the kernel's own internal coherence + the
# ruling-conditional LIVE state of the engine's delimiter class, so nothing drifts
# silently in the interim between W2 and the wiring waves).
# Source is pure ASCII — every exotic codepoint enters via Char()/escape construction.

using Test
import GoMeta as GM

@testset "textlaw_tests (the W2 kernel)" begin

    @testset "[1] P-ALPHA: tuple ≡ predicate ≡ regex fragment, full scalar sweep" begin
        re = Regex("\\A" * GM.GOMETA_WS_H_RE_FRAGMENT * "\\z")
        pinned = Set{UInt32}(UInt32.(GM.GOMETA_WS_H))
        bad = UInt32[]
        for cp in UInt32(0x0000):UInt32(0x10FFFF)
            0xD800 <= cp <= 0xDFFF && continue
            c = Char(cp)
            p = GM.is_ws_h(c)
            t = cp in pinned
            r = occursin(re, string(c))
            (p == t == r) || push!(bad, cp)
        end
        @test isempty(bad)
    end

    @testset "[2] baseline discrimination: delta vs live PCRE \\h == exactly {U+180E}" begin
        ph = r"\A[\h]\z"
        delta = UInt32[]
        for cp in UInt32(0x0000):UInt32(0x10FFFF)
            0xD800 <= cp <= 0xDFFF && continue
            c = Char(cp)
            occursin(ph, string(c)) == GM.is_ws_h(c) || push!(delta, cp)
        end
        @test delta == UInt32[0x180E]
    end

    @testset "[3] totality on malformed Chars: never a delimiter, never a throw" begin
        for raw in (0xC0000000, 0xFF000000, 0x80000000, 0xEDA08000)
            bad = reinterpret(Char, raw)
            @test GM.is_ws_h(bad) === false
        end
    end

    @testset "[4] the ruling-conditional LIVE pin: today's engine class is PCRE \\h (19 cp)" begin
        # The engine's live predicate keeps U+180E until the wiring waves land their
        # enumerated flips (the frozen/unfrozen alphabet completion). This pin makes the
        # interim EXPLICIT: it flips WITH those waves, consciously, never silently.
        @test GM.BLS._is_h_ws(Char(0x180E)) === true
        for cp in GM.GOMETA_WS_H
            @test GM.BLS._is_h_ws(Char(cp)) === true
        end
    end

    @testset "[5] nfc_key: guarded, unwired" begin
        @test GM.nfc_key("label1") === "label1"                      # ASCII fast path
        nfd = "e" * string(Char(0x0301)); nfc = string(Char(0x00E9))
        @test GM.nfc_key(nfd) == GM.nfc_key(nfc) == nfc              # ONE key per twin
        badstr = String(UInt8[0x3A, 0xC2])
        @test GM.nfc_key(badstr) == badstr                           # malformed stays RAW
        fire = string(Char(0x1F525))
        @test GM.nfc_key(fire) == fire                               # emoji NFC no-op
        @test GM.nfc_key(String(SubString("x" * nfd, 2))) == nfc     # SubString accepted
    end

    @testset "[6] the pinned data sets: sizes, membership, disjointness" begin
        @test length(GM.GOMETA_WS_H) == 18
        @test 0x180E ∉ Set(UInt32.(GM.GOMETA_WS_H))
        @test length(GM.GOMETA_BIDI_CTRL) == 10
        @test length(GM.GOMETA_INVISIBLES) == 8
        @test isempty(intersect(Set(GM.GOMETA_WS_H), Set(GM.GOMETA_BIDI_CTRL)))
        @test isempty(intersect(Set(GM.GOMETA_WS_H), Set(GM.GOMETA_INVISIBLES)))
        @test 0x200D in Set(GM.GOMETA_INVISIBLES)      # ZWJ screened until the emoji wave
        @test 0x202E in Set(GM.GOMETA_BIDI_CTRL)       # RLO — the Trojan-Source pivot
    end
end
