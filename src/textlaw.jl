# textlaw.jl — the GoMeta-owned TEXT-LAW KERNEL (the Unicode program —
# BEHAVIOR-ZERO: nothing in the engine consumes these yet; the wiring arrives with the
# planned flip tables for the un-frozen and frozen-zone seams, each
# gated on its own enumerated-flip evidence). Defining the single sources FIRST,
# unwired, is this wave's point: the alphabets stop being implicit properties of PCRE's
# compile-time Unicode tables and become GoMeta-owned, pinned, version-independent
# data — the cure for the measured toolchain skew (one process holds utf8proc at
# Unicode 16.0.0 while PCRE2 carries Unicode 15.0.0; a class named `\h` can move under
# a toolchain upgrade with zero source change, a pinned tuple cannot).

import Unicode

## THE DELIMITER ALPHABET — GOMETA_WS_H: 18 codepoints = PCRE `\h` MINUS U+180E
## (MONGOLIAN VOWEL SEPARATOR — reclassified Zs -> Cf at Unicode 6.3; an invisible,
## default-ignorable FORMAT character must never delimit — the adopted posture; the
## live engine keeps the 19-codepoint `\h` behavior until the wiring waves land
## their enumerated flips, pinned ruling-conditional in the kernel tests).
const GOMETA_WS_H = (
    0x0009, 0x0020, 0x00A0, 0x1680,
    0x2000, 0x2001, 0x2002, 0x2003, 0x2004, 0x2005,
    0x2006, 0x2007, 0x2008, 0x2009, 0x200A,
    0x202F, 0x205F, 0x3000,
)
const _WS_H_SET = Set{UInt32}(UInt32.(GOMETA_WS_H))

## The predicate: ASCII fast path, TOTAL on malformed Chars (a malformed Char carries
## no codepoint — it is never a delimiter and never a throw).
@inline function is_ws_h(c::Char)
    (c == ' ' || c == '\t') && return true
    isascii(c) && return false
    Base.isvalid(c) || return false
    return UInt32(c) in _WS_H_SET
end

## The regex fragment — an explicit codepoint alternation, deliberately NEVER `\h`:
## generated from the pinned tuple, so a pattern built from it cannot drift from the
## predicate. The escape form is the ECMAScript FOUR-DIGIT `\uHHHH` — Julia compiles
## Regex with PCRE2's ALT_BSUX option (JavaScript-style escapes), under which BOTH
## `\x{...}` AND `\u{...}` are inert inside a class (measured: `[\x{9}]` matched the
## literal characters, not TAB; the braced `\u{...}` needs EXTRA_ALT_BSUX, unset);
## `\uHHHH` is the form ALT_BSUX guarantees (measured clean: tab/space/NBSP/U+3000
## match, digits and the literal letters do not). Every pinned codepoint is <= 0xFFFF,
## so the four-digit form is total here; a future >0xFFFF member must extend the
## generator consciously (the P-ALPHA sweep would red on it immediately). The kernel
## test asserts all three representations (tuple, predicate, fragment) agree on every
## Unicode scalar, and that their delta against live PCRE `\h` is exactly {U+180E}.
const GOMETA_WS_H_RE_FRAGMENT =
    "[" * join("\\u" * lpad(string(cp, base = 16), 4, '0') for cp in GOMETA_WS_H) * "]"

## THE BIDI-CONTROL SET (the security floor's data; consumed by the planned screens
## and lints — dormant here): the explicit directional controls + ALM.
const GOMETA_BIDI_CTRL = (0x061C,
    0x202A, 0x202B, 0x202C, 0x202D, 0x202E,
    0x2066, 0x2067, 0x2068, 0x2069)

## THE INVISIBLE SET — the production Julia parser's own closed rejection list
## (soft hyphen, ZWSP, ZWNJ, ZWJ, LRM, RLM, word joiner, function application).
## ZWJ/ZWNJ get rescued ONLY inside validated emoji sequences at the emoji wave.
const GOMETA_INVISIBLES = (0x00AD, 0x200B, 0x200C, 0x200D, 0x200E, 0x200F,
    0x2060, 0x2061)

"""
    nfc_key(s) -> String

The COMPARISON-KEY normalizer (WIRED at the carriage wave under its
own behavior gate): NFC on keys at intake only — author bytes are never rewritten
anywhere. Guarded three ways: the ASCII fast path returns the input unchanged; the
validity gate returns malformed UTF-8 RAW (Unicode.normalize throws on invalid
input — a malformed token must stay loudly unknown, never crash the intake); valid
non-ASCII normalizes to NFC, so visually-identical NFD/NFC twins mint ONE key.
"""
function nfc_key(s::AbstractString)::String
    str = String(s)
    isascii(str) && return str
    isvalid(str) || return str
    return Unicode.normalize(str, :NFC)
end
