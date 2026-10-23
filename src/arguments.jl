# arguments.jl — THE ARGUMENT-EDGE CLASS: the one class of characters the Engine's reader trims at a bare argument's edges, for every Alterant
#
# IS:   ONE predicate `is_argument_space` — package-public (docs/public-api.md §1.2) — over the characters the reader strips at the two edges
#       of every BARE argument token before the token reaches an Alterant (the coercion `_coerce_arg_token`, src/absorb/absorb_meta.jl): the
#       ordinary white space (Julia's `isspace`, guarded against an invalid byte sequence — content, never white space) PLUS six invisible
#       separators `isspace` does not count: the line separator U+2028, the paragraph separator U+2029, the Mongolian vowel separator
#       U+180E, the zero-width space U+200B, the word joiner U+2060 and the byte-order mark U+FEFF.
#       THE CARVE-OUT: the zero-width joiner U+200D, the zero-width non-joiner U+200C and the variation selectors U+FE0E / U+FE0F are NOT in
#       the class — they shape emoji and script (the shipped label name with the broken chain carries U+FE0F and U+200D inside; the chain and
#       the mountain carry U+FE0F).
# DOES: `is_argument_space(c)` answers true for a character of the class. The reader applies it as `strip(is_argument_space, token)` to
#       every bare token at the coercion — the list form's pieces and the one-word label alike — so no Alterant receives an argument with
#       an invisible character at its edge; a quoted text (`"…"`) is content and is not trimmed; the characters INSIDE a token are untouched
#       here (an Alterant decides what an inner one means — the Labels Alterant refuses one in a declared name and in a vocabulary file's
#       line, and reports one in an applied name; src/alterants-std/labels.jl). An Alterant that reads lines of its own (a data file) applies
#       the same predicate to them — one list, in one place.
# REASONING: a leading or trailing invisible character serves no one — it is not visible to the writer and slips in from a keyboard or a
#       copy and paste (the creator's reasoning) — and the reason holds for every Alterant's arguments alike; the tokeniser's own white-space
#       test (`_isspace_valid`, the parser's) is untouched: widening it would change how the whole file is read.
# PURPOSE: the one named class, for every Alterant and for every reader of names.

"the six invisible separators the ordinary `isspace` does not count — the second half of the argument-edge class (the first half is `isspace`); built from their code points"
const _ARGUMENT_SPACE_EXTRA = (Char(0x2028), Char(0x2029), Char(0x180E), Char(0x200B), Char(0x2060), Char(0xFEFF))

"""
    is_argument_space(c::AbstractChar) -> Bool

THE ARGUMENT-EDGE CLASS: true for a character the Engine's reader trims at the two edges of every bare argument token — the ordinary white
space (`isspace`; an invalid byte sequence is content, never white space) and the six invisible separators U+2028, U+2029, U+180E, U+200B,
U+2060, U+FEFF; false for every other character — the zero-width joiner U+200D, the zero-width non-joiner U+200C and the variation selectors
U+FE0E / U+FE0F among them (they shape emoji and script). For every Alterant: the Engine applies it before any argument is handed over; an
Alterant that reads names from lines of its own applies it as `strip(GoMeta.is_argument_space, line)` (the Labels Alterant's vocabulary
files) and may refuse a character of the class INSIDE a name (docs/public-api.md §2).
"""
is_argument_space(c::AbstractChar) = isvalid(c) && (isspace(c) || c in _ARGUMENT_SPACE_EXTRA)
