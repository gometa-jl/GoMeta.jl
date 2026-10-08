# absorb_meta.jl — the metaLine parser and meta-hierarchy enqueuer (module AbsorbMeta)
#
# IS: the Absorb-phase metaLine parser and condition intake — his legacy's reader (GoMetaRetro AbsorbMeta.jl) with its grammar made
#     explicit (the metaLine parser effort of stage 5, R-V04B-118 (3); his Decision 1 of 2026-10-08, OWNER-WORDS §356: Design E — his
#     code fixed from the ground up, §342). It splits a metaLine's meta region into metaStatements (absorbMeta's loop + parseAlt), reads
#     one-word labels (parseOneWordLabel) and `()` argument lists (parseArgs) with ONE scanner (_span) and ONE splitter (_split_args),
#     RE-WRITES each condition body's GoMeta-specific parts to Julia text and has Julia's parser read it once (`_rewrite_condition` +
#     `Meta.parse` in parseConditions — his legacy's produceConditionStr read from the ground up, stage 5's E13, R-V04B-106 (2); his §D174),
#     and ENQUEUEs action + condition + args into the per-call queue tensors (absorbMeta — the module's sole export). It enqueues, never
#     applies: applying queued alterants is apply.jl's job.
# DOES: a metaStatement is a HEAD — a name, a `:` label, or (the region's first statement only) a `"…"` heading — then at most one `(…)`,
#     then at most one `{…}`, and ENDS at white space or at the region's end; any other character meets the one refusal `_refuse_char`,
#     which names the character, the token it begins and the region (his §341). The six structural characters `( ) { } , "` end a name or
#     a label (§362); every other non-white-space character is a name or label character — pictographs and emojis among them (§360); a
#     leading punctuation is part of the name and meets the registry's unknown-action refusal (§361; the prefix sugar a later design,
#     V05-15). absorbMeta reads the per-call ProcessState through the parent GoMeta.ctx(), hoisted once as `st`; each name is resolved
#     against st.registry.sorted_alt_actions; a slot already holding size(queued, 2) actions refuses with GoMeta's message BEFORE the
#     write (his Decision 3, §358 — the limit a fixed size raised by hand); the plugin index and the action index are written into
#     st.queue.queued at the current meta-hierarchy slot, st.mh.slot_has_accum set for the accumulate set, the condition (Julia's `Expr`,
#     or `nothing` for an action written without `{}`) and the argument tuple stored by value; ONE text-argument rule (`_string_slot_check`,
#     his §359 (8)) admits a quoted (String) argument in the slot the action's declared record names and refuses it elsewhere; an empty
#     argument piece (`cell(7,)`) is handed on as the empty token — the Alterant decides (§359 (1)). A condition body is READ HERE: a
#     settribute key becomes its state read `getState(:key)`, an action of an Alterant that answers queries becomes its query
#     `getAltState(Int8(p), Symbol("…"), …)` (the registry's one rule `queryable_action`, stage 5's E12 — R-V04B-99), a label test `:name`
#     the Labels query of that name, his `,` becomes `||`, everything else — `&&`, `!`, `()`, `|`, `&`, numbers, Julia operators,
#     whitespace — is copied verbatim (a bare word that is neither a settribute key nor a queryable action — `true`, `false`, `nothing`, a
#     quoted string's word among them — is a condition key and refuses, as his legacy read it); the result is parsed ONCE by `Meta.parse`
#     and the `Expr` evaluated by Julia at apply time (apply.jl; `Core.eval`), or, for a heading's condition, once at this seam
#     (`_absorb_local_only!`).
# REASONING: his design — the condition is Julia (OWNER-WORDS §120, §D174): GoMeta recognises its own parts and Julia does the rest; the
#     metaLine grammar is his legacy's with its two missing arms supplied: his `parseAlt` had arms for `(`, the label, `{` and white
#     space and no "anything else" case (AbsorbMeta.jl :307–:340), and its outer `ispunct` gate (:304) skipped a leading punctuation — so
#     a statement was never required to END and a leading punctuation was never read: every silent skip, drop and raw BoundsError of the
#     inventory (the register's D-1, D-2, D-3, D-8, D-10) was one of those two arms, cured at their root rather than by a patch per shape
#     (his §342, §343). One of each where there were several — one white-space predicate (`_isspace_valid`, his
#     legacy's `isspace` guarded; his §359 (10)), one scanner `_span` for the metaLine's spans (quote-aware: a `}` or `)` inside a quoted
#     text closes nothing — his §359 (5); the condition rewrite keeps its own `(…)` finder until the lever "strings in conditions" is
#     his — the register's PB-6), one splitter, one text-argument rule; the backslash reserved in GoMeta's quoted texts — the heading
#     sugar and the quoted arguments, his decision's two producers (U8 :1310) — while a condition's quoted text is Julia's and its `\`
#     Julia's escape — the session's default under his §D174, the register's PB-6, his to revert. The scanner's form is the quote-scan
#     panel's judge's specification (wf-s10-quote-scan-design, B.2).
#     Honest edges: each refusal is an untyped ErrorException raised via error() ("the usual error / refusal message", U8 :1473); a body
#     Julia cannot parse is Julia's own `Meta.ParseError` (his §319); an argument's arity or type fault is the Alterant's own setter
#     error (§359 (9)); the Labels Alterant's character law and whitelist judge the label names handed over (U8 :1252).
# PURPOSE: turn each metaLine of a BLS input into queued alterant work the apply phase consumes, refusing every malformed metaStatement
#     with a stable GoMeta message that names the character at fault, and reading every well-formed one exactly as his legacy read it
#     (his two example files and the twelve frozen forms byte-equal, his §78).

## AbsorbMeta.jl
module AbsorbMeta

# NamedElements is consumed solely by registry.jl (the package's single NamedElements consumer);
# absorb_meta references no NamedElements symbol by name (`keys(BLS.ComponentSettribute)` is
# `Base.keys`), so no `using ..BLS.NamedElements` import belongs here.
using StaticArrays: SVector
import ..CnS
import ..BLS
# The enqueue (`absorbMeta`) and the condition intake (`parseConditions` — the rewrite reads the registry's
# vocabulary) read the per-call `ProcessState` (registry + slot tensors + queue + cursor) via the parent `GoMeta.ctx()`.
import ..GoMeta: ctx
# the registry's one vocabulary rule for a bare name in a condition (stage 5's E12 — R-V04B-99): an action of an Alterant
# that answers queries; the rewrite's test where his legacy tested `insorted(key, sortedAltActionsSVec)` (AbsorbMeta.jl :219)
import ..GoMeta: queryable_action
# v0.2 CH-3 step 8: the widened action-argument literal floor (Symbol|String; ints reserved).
import ..GoMeta: AlterantArgT
# v0.2 CH-3 step 9: the context record type (the enqueue-seam applicability + derivation
# reads it) and the Alterants submodule (the Heading validation seam lives there).
import ..GoMeta: MetaContext, UserContext   # UserContext since stage 2's commit 3a — the enqueue's origin line (commit 2) reads it on the user feed
import ..Alterants
# v0.2 localOnly delivery: the absorb seam calls the record's setter directly (its guard
# `_invoke_set` left at stage 5's E6 of the v0.4 build — census row 14), evaluates
# conditions ONCE (`Core.eval` on the stored Expr — Julia's evaluation, stage 5's E13), and mints the heading rows
# (`capture_heading!`, annotations.jl) — all reached via the parent module.
import ..GoMeta as GMX
export absorbMeta

#########################################################################################
## THE METALINE PARSER — his reader with its grammar made explicit (the metaLine parser effort, R-V04B-118 (3); his Decision 1 of
## 2026-10-08, OWNER-WORDS §356: Design E — his code fixed from the ground up, §342). A metaStatement is a HEAD — a name, a `:` label,
## or, as the region's FIRST statement only, a `"…"` heading (his U8 :1292 sugar) — then at most one `(…)`, then at most one `{…}`
## (his order, U8 :1390), and it ENDS at white space or at the region's end; any other character meets THE ONE refusal
## `_refuse_char`, which names it (his §341: such situations cause an error). The six structural characters `( ) { } , "` end a
## name or a one-word label (his §362); every other non-white-space character is a name or label character — a pictograph or an
## emoji among them (his §360; a leading punctuation is part of the name, §361 — the prefix sugar is a later design, V05-15).
## ONE white-space predicate (`_isspace_valid` — his legacy's `isspace`, guarded against invalid UTF-8; his §359 (10)), ONE scanner
## `_span` for the metaLine's spans `(…)` `{…}` `"…"` (the condition rewrite keeps its own `(…)` finder until the lever "strings in
## conditions" is his), ONE argument splitter `_split_args`, ONE refusal helper — where his legacy and the v0.2–v0.3 additions had
## three white-space tests, four bracket loops, three backslash sites and two String walls. The quote-scan panel of 2026-10-08
## (wf-s10-quote-scan-design; its judge's specification B.2) is the scanner's form.
const _STRUCTURAL = ('(', ')', '{', '}', ',', '"')

## The words of the refusals' hints (his item 6: the words as drafted; his to re-word): the glue hint is his item 2 — a space before
## '(' or '{' separates it from the preceding metaStatement; the labels hint is his Decision 2 (slide 43); the quote hint his U8 :1306.
const _HINT_GLUE = " — '()' and '{}' are written glued to the name, as in hide{isCode}: a white space before them separates them from the preceding metaStatement"
const _HINT_ORDER = " — a metaStatement is a name or a label, then '()' at most once, then '{}' at most once, and ends at white space"
const _HINT_LABELS = " — the short form :name takes ONE label; several labels are written :(name1, name2)"
const _HINT_QUOTE = " — a quoted text is the heading sugar at the region's first metaStatement only; elsewhere write head(\"…\")"

"the index after the TOKEN that starts at `i`: the run of characters that are neither white space nor structural (`i` itself when the run is empty)"
function _token_end(text::AbstractString, i::Int)::Int
    n = lastindex(text); j = i
    while j <= n && !_isspace_valid(text[j]) && text[j] ∉ _STRUCTURAL
        j = nextind(text, j)
    end
    return j
end

"""
    _span(text, thisInd; julia = false) -> Int

IS: THE ONE SCANNER of the metaLine grammar (Design E — "one routine finds a closing bracket or quote", his Decision 1,
OWNER-WORDS §356; his §359 (5)): his counter loop (AbsorbMeta.jl :44–:53 parseArgs, :88–:99 produceArgsStr, :253–:266
parseConditions) with the opener as its parameter and ONE quote arm.

DOES: `text[thisInd]` is an opener — `(`, `{` or `"`; returns the index of its closer. A bracket nests with its own kind
(his counters; the other kind is content, as in his loops); inside a bracket span a `"` opens a QUOTED TEXT whose characters
are content — a bracket or a comma inside it closes and splits nothing; a quoted span's own `"` closes it. A `\\` inside a
quoted text: in GoMeta's text (`julia = false` — the quoted heading, a quoted argument, a label list) it is RESERVED and
refuses (his v0.2 decision, U8 :1310, given for the sugar span and the String-argument span: a later escape grammar must be
a purely additive widening; reserving only `\\"` refused unevenly — the rejected alternative); in Julia's text (`julia =
true` — a condition body, his §D174) it escapes the next character as Julia reads it, so the quoted text ends where Julia
ends it. Reaching the end of `text` refuses ONCE, naming the innermost opener left open — the `"` when the text ends inside
a quoted text. One character walk (`nextind`, never a byte count); no regex; no allocation on the accepting path; generic
over `AbstractString` (the parser's `SubString{String}` today; the rewrite's `String` with the lever "strings in conditions" — the
register's PB-6, PB-12).

REASONING: his legacy counted brackets in three loops and the v0.2 additions added quote arms and backslash checks at three
more places; one walk with one quote state serves every span. Julia's other literal delimiters are not known — a Char
literal (`'}'`; `'` is also Julia's adjoint `x'`), a backtick, an odd `"` inside a triple-quoted text, a string prefix's
word: each ends in a loud refusal or Julia's own error (the register's PB-5).

PURPOSE: where a span ends, for every reader: parseArgs (the argument list and the label list), parseConditions, the quoted
heading and the splitter.
"""
function _span(text::AbstractString, thisInd::Int; julia::Bool = false)::Int
    o = text[thisInd]                                    # the opener: '(' '{' or '"'
    c = o == '(' ? ')' : o == '{' ? '}' : '"'            # its closer
    inQuote = o == '"'                                   # a quoted span starts inside its own quote
    countOpenBrakets = 1                                 # his counter — the opener counted
    while (thisInd = nextind(text, thisInd)) < ncodeunits(text) + 1      # his loop header (AbsorbMeta.jl :46, :92, :259)
        ch = text[thisInd]
        if inQuote
            if ch == '\\'
                julia || _refuse_backslash(text)         # GoMeta's quoted text: the v0.2 reservation
                thisInd == lastindex(text) && break      # Julia's quoted text: a final '\' escapes nothing — left open
                thisInd = nextind(text, thisInd)         #   else the escaped character is content (the header steps past it)
            elseif ch == '"'
                o == '"' && return thisInd               # a quoted span's own closer
                inQuote = false                          # a quoted text inside a bracket span ends
            end
        elseif ch == '"'
            inQuote = true                               # a quoted text inside a bracket span: its characters are content
        elseif ch == o
            countOpenBrakets += 1
        elseif ch == c
            (countOpenBrakets -= 1) == 0 && return thisInd
        end
    end
    _refuse_unterminated(text, inQuote ? '"' : o, inQuote ? 1 : countOpenBrakets)
end

"the one unterminated refusal of the metaLine grammar — the E seat's R2 in the words he approved as drafted (§359 (6)); the innermost opener left open is named, the `\"` when the text ends inside a quoted text"
_refuse_unterminated(text::AbstractString, o::Char, nOpen::Int) =
    error("GoMeta absorb: unterminated '", o, "' — never closed in the meta region ", repr(first(text, 40)),
        " (", nOpen, " still open) (see docs/public-api.md §3.4)")

"the one backslash refusal — the E seat's R3 in the words he approved as drafted (§359 (6)): a `\\` inside GoMeta's own quoted text (the heading sugar, a quoted argument, a label list) is reserved for the future escape grammar (his v0.2 decision, U8 :1310)"
_refuse_backslash(text::AbstractString) =
    error("GoMeta absorb: backslash in a quoted span — reserved for the future escape grammar in the meta region ",
        repr(first(text, 40)), " (see docs/public-api.md §3.4)")

"THE ONE REFUSAL of the metaLine grammar: the character at `i` cannot stand `where` (a position phrase); the message names it, the token it begins and the region — the usual GoMeta refusal form (his §341); its form approved as drafted by his item 6 of 2026-10-08 (the sitting pack's D.1), the four hints' words the session's — the register's PB-3, his to set"
function _refuse_char(metaSS::SubString{String}, i::Int, where::String, hint::String = "")
    j = i
    while j <= lastindex(metaSS) && !_isspace_valid(metaSS[j])
        j = nextind(metaSS, j)
    end
    error("GoMeta absorb: unexpected character ", repr(metaSS[i]), " ", where, " in the meta region ", repr(first(metaSS, 40)),
        " (the token ", repr(first(SubString(metaSS, i, prevind(metaSS, j)), 40)), ")", hint, " (see docs/public-api.md §3.4)")
end

"the argument list's interior split at its TOP-LEVEL commas — a quoted text is jumped whole by the one scanner, so its commas are content; each piece edge-stripped by the one white-space test; a piece carrying a `\"` must be exactly one well-formed `\"…\"` span (the token law at its ONE seam — the only producer of a quoted argument token; the heading's token is one by construction of `_span`); an empty piece among several is handed on as the empty token — the Alterant decides (his §359 (1)); `()` is no argument (his legacy's normalisation, AbsorbMeta.jl :57–:60 — `hide()` ≡ `hide`)"
function _split_args(argtext::SubString{String})::Vector{SubString{String}}
    argsSSVec = SubString{String}[]
    indStart = thisInd = firstindex(argtext)
    while thisInd <= lastindex(argtext)
        ch = argtext[thisInd]
        if ch == ','
            push!(argsSSVec, strip(_isspace_valid, SubString(argtext, indStart, prevind(argtext, thisInd))))
            indStart = nextind(argtext, thisInd)
        elseif ch == '"'
            thisInd = _span(argtext, thisInd)            # never refuses here: `_span('(')` paired every '"' and refused every '\'
        end
        thisInd = nextind(argtext, thisInd)
    end
    push!(argsSSVec, strip(_isspace_valid, SubString(argtext, indStart, lastindex(argtext))))
    for a in argsSSVec
        occursin('"', a) && !_is_wellformed_quote_span(a) && _refuse_malformed_quote(a)
    end
    return (length(argsSSVec) == 1 && isempty(argsSSVec[1])) ? SubString{String}[] : argsSSVec
end

## The quote-span LAW, one predicate: exactly one well-formed '"…"' span forming the WHOLE token. The length/edge conjuncts run
## BEFORE the interior slice, so the slice is computed only under its own precondition.
_is_wellformed_quote_span(t::AbstractString) =
    ncodeunits(t) >= 2 && t[firstindex(t)] == '"' && t[lastindex(t)] == '"' &&
    !occursin('"', t[nextind(t, firstindex(t)):prevind(t, lastindex(t))])

_refuse_malformed_quote(t::AbstractString) =
    error("GoMeta absorb: malformed quoted argument — a quoted argument is ",
        "exactly one '\"…\"' span forming the whole token (got ",
        repr(first(String(t), 40)),
        "); v0's argument grammar (see docs/public-api.md §3.4)")

"the one-word label starting at `i` (the first character after `:`): the index after the label and the ONE-element argument vector — the sugar `:name` takes one label (his slide 43, U8 :1236; his Decision 2 of 2026-10-08, §357: `:name1,name2` is refused at the comma, the right form named); what the name may contain is the Labels Alterant's (U8 :1252), the six structural characters excepted (§362); no shipped label name is spelled in this file (the zero-literal law, tests/unit/vocabulary_tests.jl [10])"
function parseOneWordLabel(metaSS::SubString{String}, i::Int)::Tuple{Int,Vector{SubString{String}}}
    j = _token_end(metaSS, i)
    return j, SubString{String}[SubString(metaSS, i, prevind(metaSS, j))]
end

"the `(…)` list opening at `i` (`metaSS[i] == '('` — an action's argument list or the Labels Alterant's `:(…)`): the index after its closing `)` and the argument tokens — his `parseArgs` (AbsorbMeta.jl :39–:67): its counter loop the one scanner's, its split the one splitter's"
function parseArgs(metaSS::SubString{String}, i::Int)::Tuple{Int,Vector{SubString{String}}}
    j = _span(metaSS, i)
    return nextind(metaSS, j), _split_args(SubString(metaSS, nextind(metaSS, i), prevind(metaSS, j)))
end
# Nothing in this file executes at module load beyond definitions and imports.

## THE CONDITION REWRITE — stage 5's E13 of the v0.4 build (census row 1; his order §319, R-V04B-106 (2)–(3)); his §D174 (2026-10-06):
## the parser "must simply be able to recognize the GoMeta specific parts of the conditions in order to slightly re-write it when
## storing the condition as a Julia Expression which gets then evaluated on demand by Julia". His legacy's produceConditionStr
## (GoMetaRetro AbsorbMeta.jl :116–:245) read from the ground up (his §342): the GoMeta-specific parts of a `{…}` body become Julia
## text, the rest is copied verbatim, and Julia's parser reads the result ONCE here; the stored `Expr` is evaluated by Julia at apply
## (apply.jl) or, for a heading, once at this seam (`_absorb_local_only!`):
##   `,`                 → ` || `                                              (his OR — the legacy's :139–:145)
##   `:name`             → `getAltState(Int8(p), Symbol(":"), Symbol("name"))`      (a label test: the Labels Alterant's `:` action,
##                         p its plugin index; the name quoted by `repr`, so EVERY name the vocabulary admits — a ZWJ pictograph too —
##                         is spelled the one way; register E13-8)
##   `:(args)`           → `getAltState(Int8(p), Symbol(":"), args)`               (the parenthesized label form, the args raw)
##   `key` / `key(args)` → `getState(:key)` / `getState(:key, args)`              (a settribute key — `keys(BLS.ComponentSettribute)`)
##                       → `getAltState(Int8(p), Symbol("key"), args)`             (a QUERYABLE action — `queryable_action`: an Alterant
##                         that declares `getAltInstance`; Labels at v0 — the registry's rule, R-V04B-99 / E12, kept)
##                       → the usual unknown-condition-key refusal                   (anything else — the legacy's :231–:234)
##   everything else — `&&`, `!`, `()`, `|`, `&`, `||`, numbers, Julia operators, whitespace — verbatim.
## A bare WORD that is neither a settribute key nor a queryable action IS a condition key and meets the refusal — `true`, `false`,
## `nothing` and a quoted string's word among them (his legacy's reading, :231–:234; register E13-14, his to widen). A worded label
## with a parenthesized list (`:abc(:xyz)` — the K6 corner) reads as the label test of the word followed by a Julia call on its
## Bool — a MethodError at apply; his legacy dropped the word and queried the list (:187–:191, :215), the closed interpreter (E13)
## refused the shape — register E13-13, his to revert to either.
## An argument text is spliced as Julia text: its shape is Julia's to judge at apply (`getAltState`'s `Vararg{Symbol}`; an undefined
## name its UndefVarError), as the action arguments are since stage 5's E6. The walk is a CHAR walk (`nextind`/`lastindex` — never
## the legacy's byte-count end test, whose BoundsError one index past a multibyte final character the 0.2.2 cure fixed;
## tests/unit/unicode_cure_tests.jl [4]/[7] hold the cure). A word ends at whitespace, at a non-identifier character or at one of
## `_COND_DELIMS`; a label name ends at whitespace or at one of `_COND_DELIMS`.
const _COND_DELIMS = ('(', ')', ',', '!', '&', '|')

"the balanced `(…)` span opening at `i` (text[i] == '(') — (the index of the matching ')', the raw interior); `nothing` when no ')' closes it (the '(' is then copied verbatim and Julia's parser judges the rest)"
function _paren_span(text::String, i::Int)
    depth = 0; j = i
    while j <= lastindex(text)
        c = text[j]
        c == '(' && (depth += 1)
        if c == ')'
            depth -= 1
            depth == 0 && return (j, text[nextind(text, i):prevind(text, j)])
        end
        j = nextind(text, j)
    end
    return nothing
end

"the Julia call a condition KEY (a settribute key or a queryable action) with an optional raw argument text re-writes to — or the usual refusal"
function _cond_target(key::Symbol, args::Union{Nothing,String}, r)::String
    tail = args === nothing ? ")" : string(", ", args, ")")
    if key ∈ keys(BLS.ComponentSettribute)
        return string("getState(:", key, tail)
    elseif queryable_action(r, key)
        p = r.action_to_plugin[r.action_index[key]]
        return string("getAltState(Int8(", p, "), Symbol(", repr(String(key)), ")", tail)
    else
        error("GoMeta absorb: unknown condition key ", repr(first(String(key), 40)), " — neither a component state-ref nor a ",
            "queryable alterant action; a condition's bare name is a settribute key or an action of an Alterant that answers ",
            "queries (see docs/public-api.md §3.4)")
    end
end

"""
    _rewrite_condition(text, registry) -> String

IS: the condition REWRITE of stage 5's E13 (census row 1; his order §319, R-V04B-106 (2)–(3); his §D174): the `{…}` body
with its GoMeta-specific parts re-written to Julia text (the table in the comment above); the registry supplies the
vocabulary — the settribute keys and the queryable actions. His legacy's `produceConditionStr` read from the ground up.

DOES: one CHAR walk over `text` (`nextind`/`lastindex`, never a byte-count end test), printing into a buffer: `,` →
` || ` (his OR); `:` followed by `(` → the balanced span (`_paren_span`) becomes the Labels query
`getAltState(Int8(p), Symbol(":"), args)` with the raw interior as `args` (an empty interior passes none; an unclosed
`(` leaves the `:` copied verbatim for Julia's parser to judge); `:name` (the name to whitespace or one of
`_COND_DELIMS`) → the same query with `Symbol("name")`, the name quoted by `repr` so every name the vocabulary admits
is spelled the one way; a word at an identifier-start character (its run of identifier characters, an optional
balanced `(args)` spliced raw) → `_cond_target`: a settribute key (`keys(BLS.ComponentSettribute)`) becomes
`getState(:key[, args])`, a QUERYABLE action (`queryable_action` — an Alterant that declares `getAltInstance`; the
registry's one rule, R-V04B-99 / E12: the three Visib names `hide` / `show` / `discard` are neither) becomes
`getAltState(Int8(p), Symbol("key")[, args])` with `p` its plugin index, anything else — `true`, `false`, `nothing` and a
quoted string's word among them — meets the refusal `error("GoMeta absorb: unknown condition key …")`, an
`ErrorException` naming the key (bounded to 40 characters); every other character — operators, parentheses, numbers,
whitespace — verbatim. Returns the re-written text as a `String`. Pure over its two arguments (no state read; the
refusal its one exit besides the return); `Meta.parse` reads the result ONCE in its one caller, `parseConditions`,
with `ctx().registry`.

REASONING: his design — the condition is Julia: GoMeta recognises its own parts and Julia does the rest, so the parser
carries no condition grammar of its own (the closed interpreter's walls and typed codes left at E13); the vocabulary
stays the registry's (settribute keys, queryable actions), and the spelling of a label through `repr` keeps one form
for every admitted name (register E13-8).

PURPOSE: the text Julia's parser turns into the stored `Expr` a queued action's condition evaluates at apply (or, for a
heading, once at the absorb seam).
"""
function _rewrite_condition(text::String, r)::String
    out = IOBuffer()
    i = firstindex(text); n = lastindex(text)
    while i <= n
        c = text[i]
        if c == ','
            print(out, " || "); i = nextind(text, i)
        elseif c == ':'
            j = nextind(text, i)
            if j <= n && text[j] == '('
                span = _paren_span(text, j)
                if span === nothing
                    print(out, c); i = j                    # an unclosed '(' — copied verbatim; Julia's parser judges the remainder
                else
                    args = strip(_isspace_valid, span[2])
                    print(out, _cond_target(Symbol(":"), isempty(args) ? nothing : String(args), r)); i = nextind(text, span[1])
                end
            else
                k = j
                while k <= n && !_isspace_valid(text[k]) && text[k] ∉ _COND_DELIMS
                    k = nextind(text, k)
                end
                name = text[j:prevind(text, k)]
                print(out, _cond_target(Symbol(":"), isempty(name) ? nothing : string("Symbol(", repr(name), ")"), r)); i = k
            end
        elseif Base.is_id_start_char(c)
            k = nextind(text, i)
            while k <= n && Base.is_id_char(text[k]) && text[k] ∉ _COND_DELIMS
                k = nextind(text, k)
            end
            key = Symbol(text[i:prevind(text, k)])
            args = nothing
            if k <= n && text[k] == '('
                span = _paren_span(text, k)
                if span !== nothing
                    inner = strip(_isspace_valid, span[2])
                    args = isempty(inner) ? nothing : String(inner); k = nextind(text, span[1])
                end
            end
            print(out, _cond_target(key, args, r)); i = k
        else
            print(out, c); i = nextind(text, i)           # operators, parentheses, numbers, whitespace — Julia's, verbatim
        end
    end
    return String(take!(out))
end

"the stored condition `Expr` names a label test (`getAltState` — the alterant-state query) somewhere in its tree"
_has_query(x) = x isa Expr && ((x.head === :call && !isempty(x.args) && x.args[1] === :getAltState) || any(_has_query, x.args))

"""
    parseConditions(metaSS, i) -> (index after the closing `}`, the condition's `Expr`)

IS: the condition intake — the `{…}` block opening at `i` read into the `Expr` Julia evaluates at apply (his `parseConditions`,
AbsorbMeta.jl :248–:282; the seam stage 5's E13 left: the GoMeta parts of the body re-written to Julia text, Julia's parser once).

DOES: finds the block's end with the one scanner (quote-aware since the parser effort — a `}` inside a quoted text no longer closes
the block, his §359 (5)); `Meta.parse`s the re-written body ONCE; an EMPTY body or a bare literal (`{}`, `{ 1 }`, `{ | }`) carries
no condition expression and is refused (an unconditional action is written without `{}`; register E13-6); an INCOMPLETE body
(`isCode &&`) is thrown as Julia's own `Meta.ParseError` class HERE, at the statement, never stored for a later reader; a body
Julia cannot parse is Julia's own error out of the goMeta call. The echoed body is bounded to 40 characters.

REASONING: his design — a condition is Julia (OWNER-WORDS §120, §D174); the parser carries no condition grammar of its own.

PURPOSE: the stored `Expr` a queued action's condition evaluates at apply, or a heading's once at the absorb seam.
"""
function parseConditions(metaSS::SubString{String}, i::Int)::Tuple{Int,Expr}
    j = _span(metaSS, i; julia = true)                   # the matching `}` — quote-aware; the body is Julia's text (its `\` Julia's escape)
    bodyStr = String(SubString(metaSS, nextind(metaSS, i), prevind(metaSS, j)))
    ex = Meta.parse(_rewrite_condition(bodyStr, ctx().registry))
    ex isa Expr || error("GoMeta absorb: the condition block {", first(bodyStr, 40), "} carries no condition expression (",
        ex === nothing ? "an empty block" : "a bare literal", ") — an unconditional action is written without '{}' ",
        "(see docs/public-api.md §3.4)")
    Meta.isexpr(ex, :incomplete) && throw(ex.args[1] isa Exception ? ex.args[1] : Meta.ParseError(string(ex.args[1])))
    return nextind(metaSS, j), ex
end

#########################################################################################
"""
    parseAlt(metaSS, thisInd, firstToken = false) -> (name, args, condition, the index of the statement's last character)

IS: the reader of ONE metaStatement — his `parseAlt` (AbsorbMeta.jl :286–:360) with its grammar made explicit: HEAD, TAIL, END.

DOES: from the first non-white-space character after `thisInd` (his :301–:302 search): the HEAD is a `:` label (his `foundLabel`
arm — `:(name1, name2)` through `parseArgs`, `:name` through `parseOneWordLabel`, the lone `:` with zero arguments handed to the
Labels Alterant as his word orders, U8 :1250; any other character after the `:` refused), a `"…"` heading at the region's FIRST
statement only (the sugar lowers here to the `head` action with the quoted span as its one argument — the quotes kept as the
String-lane kind marker `_coerce_arg_token` reads; a non-first quoted text is refused with his U8 :1306 hint), a structural
character (refused: no metaStatement starts with one — `#~ ,` and `#~3 (` no longer reach an empty name and Julia's BoundsError),
or a NAME (the run to white space or a structural character — never empty). The TAIL is at most one `(…)` (unless the head took
its arguments) then at most one `{…}`, his order (U8 :1390). The END: the next character is white space or the region's end —
anything else is refused by name: a token glued to a closing bracket (`hide()junk`, `hide{isCode}show` — his legacy dropped it),
a second `(` or `{`, a `(` after `{…}`, a `,` after a one-word label (the right form named), a stray `)` `}` `"`. Returns the
name (`head` for the sugar), the argument tokens, the condition (`nothing` for an action without `{}` — minted ONLY here) and
the index of the statement's last character (his :359 contract; the caller's loop resumes after it).

REASONING: his legacy's reader had arms for `(`, the label, `{` and white space and no "anything else" case (AbsorbMeta.jl
:307–:340), and its outer `ispunct` gate (:304) skipped a leading punctuation — so a statement was never required to END and a
leading punctuation was never read: every silent skip, drop and raw BoundsError of the inventory (the register's D-1, D-2, D-3,
D-8, D-10) was one of those two arms, cured at their root rather than by a patch per shape; the grammar in one sequence replaces his `argsDone` / `conditionsDone`
flags and the three "again" refusals. The negative character rule (white space and the six structural characters end a token;
everything else is a token character) keeps his pictograph and emoji labels and names (his §360) and drops the Unicode-category
dependence that made `-hide` apply and `+hide` refuse (§361).

PURPOSE: one metaStatement, read as his grammar states it, or one refusal naming the character at fault.
"""
function parseAlt(
    metaSS::SubString{String},
    thisInd::Int,
    firstToken::Bool = false   # true only for the FIRST metaStatement of the meta region — gates the quoted-first heading
)::Tuple{SubString{String},Vector{SubString{String}},Union{Nothing,Expr},Int}

    n = lastindex(metaSS)
    i = nextind(metaSS, thisInd)
    while i <= n && _isspace_valid(metaSS[i])
        i = nextind(metaSS, i)
    end
    s = i; c = metaSS[i]
    local name::SubString{String}
    argsSSVec = SubString{String}[]
    local conditionExpr::Union{Nothing,Expr} = nothing
    headArgs = false
    ## HEAD
    if c == ':'
        name = SubString(metaSS, i, i); i = nextind(metaSS, i)
        if i <= n && metaSS[i] == '('
            (i, argsSSVec) = parseArgs(metaSS, i); headArgs = true
        elseif i <= n && !_isspace_valid(metaSS[i]) && metaSS[i] ∉ _STRUCTURAL
            (i, argsSSVec) = parseOneWordLabel(metaSS, i); headArgs = true
        elseif i <= n && !_isspace_valid(metaSS[i])
            _refuse_char(metaSS, i, "after ':'", metaSS[i] == '"' ? _HINT_QUOTE : _HINT_ORDER)
        end
    elseif c == '"'
        firstToken || _refuse_char(metaSS, i, "at the start of a metaStatement", _HINT_QUOTE)
        j = _span(metaSS, i)
        name = _HEAD_ACTION_NAME_SS
        argsSSVec = SubString{String}[SubString(metaSS, i, j)]; headArgs = true
        i = nextind(metaSS, j)
    elseif c ∈ _STRUCTURAL
        _refuse_char(metaSS, i, "at the start of a metaStatement", (c == '(' || c == '{') && !firstToken ? _HINT_GLUE : _HINT_ORDER)
    else
        j = _token_end(metaSS, i); name = SubString(metaSS, i, prevind(metaSS, j)); i = j
    end
    ## TAIL
    if !headArgs && i <= n && metaSS[i] == '('
        (i, argsSSVec) = parseArgs(metaSS, i)
    end
    if i <= n && metaSS[i] == '{'
        (i, conditionExpr) = parseConditions(metaSS, i)
    end
    ## END
    if i <= n && !_isspace_valid(metaSS[i])
        e = metaSS[i]
        _refuse_char(metaSS, i, string("after the metaStatement ", repr(SubString(metaSS, s, prevind(metaSS, i)))),
            e == ',' && c == ':' ? _HINT_LABELS : e == '"' ? _HINT_QUOTE : e ∈ _STRUCTURAL ? _HINT_ORDER : "")
    end
    return name, argsSSVec, conditionExpr, prevind(metaSS, i)
end

## The lowered spelling of the quoted-first sugar — the deriving head call's name (the action is `head`), as a SubString so parseAlt's
## return type is unchanged.
const _HEAD_ACTION_NAME_SS = SubString(String("head"))


function absorbMeta(
    metaSS::SubString{String}
)

    # The enqueue reads/writes the per-call `ProcessState` via `ctx()`; `st` is hoisted once for
    # type-stable field reads.
    local st = ctx()
    crntSlot::Int = st.mh.slots[st.crnt_idx]
    thisInd::Int = 0
    local altActionName::SubString{String}
    local argsSSVec::Vector{SubString{String}}
    local conditionExpr::Union{Nothing,Expr}   # Julia's Expr, or the `nothing` sentinel (an action without `{}`)
    local crntAltActionIdx::Int8
    local altActionOnRow::Int8
    firstTok::Bool = true   # the quoted-first recognizer fires only for the FIRST
                            # metaComponent of the meta region (hd-2/hd-3)
    ## localOnly delivery (set mode `:localOnly`): ONE pending store PER localOnly
    ## PLUGIN per meta region (v0.4 T5 — the round's T5P-C row-1 cure: the former single
    ## Heading-typed local made a second localOnly plugin either raw-TypeError
    ## post-latch or non-injective over the shared store) — every localOnly action sets
    ## into ITS OWNING PLUGIN's store (entry order preserved per store, so the
    ## per-region fold's injectivity ordinals keep their key), and the region flushes
    ## ONCE after the component loop via the REGISTRY-DRIVEN loop below (keyed on the
    ## Component the statement is APPLIED TO and decided by the carrier — the metaBlock a
    ## whole-line or a comment-split metaLine forms, R-V04B-50; the LINE with the Segment as
    ## the key's origin for an inline metaSegment, R-V04B-98).
    local pendingLocal::Dict{Int8,Any} = Dict{Int8,Any}()
    local isLocalOnly::Bool = false
    while (thisInd = nextind(metaSS, thisInd)) < ncodeunits(metaSS) + 1

        if !_isspace_valid(metaSS[thisInd])

            (altActionName, argsSSVec, conditionExpr, thisInd) = parseAlt(
                metaSS,
                prevind(metaSS, thisInd),
                firstTok)
            firstTok = false
            # `st.registry` supplies the sorted action table, the action→index map, the
            # declaration-order `action_to_plugin` index, and the accumulate-set; the slot tensors
            # (`count_actions_per_slot`/`slot_has_accum`) and the queue tensor (`queued`) are the
            # per-call `st.mh`/`st.queue`. `queued[1,…]` stores the same declaration-order plugin
            # index that the eval-string, `getAltState`, and the apply phase use.
            if insorted(Symbol(altActionName), st.registry.sorted_alt_actions) ## NEW

                crntAltActionIdx = st.registry.action_index[
                    Symbol(altActionName)]
                ## v0.2 localOnly delivery: the mode is read FROM THE REGISTRY (the
                ## plugin's declared setMode — never a name literal), so a localOnly
                ## action DIVERTS here, BEFORE any queue bookkeeping: it never enters
                ## the slot tensors, never consumes slot capacity, and the inheritance
                ## backtrack (both apply passes) never sees it — "applies once, where
                ## it stands". The whole head path (wall, validation, applicability,
                ## materialization, the ONE condition evaluation, the setter call)
                ## lives in `_absorb_local_only!` below.
                local loPlugIdx = st.registry.action_to_plugin[crntAltActionIdx]
                isLocalOnly = st.registry.plugins[loPlugIdx].setMode === :localOnly
                if isLocalOnly
                    _absorb_local_only!(
                        st, metaSS, Symbol(altActionName), argsSSVec, conditionExpr,
                        pendingLocal, loPlugIdx)
                else
                ## THE SLOT BOUND (his Decision 3 of 2026-10-08, §358): the queue tensors hold size(queued, 2) = the registered action
                ## count of actions per meta-hierarchy slot — a fixed size, raised by hand when an example needs it (the slower overflow
                ## buffer a later design, V05-14); a further action meets GoMeta's message here, BEFORE the write.
                st.mh.count_actions_per_slot[crntSlot] == size(st.queue.queued, 2) &&
                    error("GoMeta absorb: more than ", size(st.queue.queued, 2), " actions in one meta-hierarchy slot — the queue holds ",
                        "the registered action count (", size(st.queue.queued, 2), ") per slot in the meta region ", repr(first(metaSS, 40)),
                        " (see docs/public-api.md §3.4)")
                altActionOnRow = (st.mh.count_actions_per_slot[crntSlot] += 1)
                st.queue.queued[1,
                    altActionOnRow, crntSlot] = st.registry.action_to_plugin[crntAltActionIdx]
                st.queue.queued[2,
                    altActionOnRow, crntSlot] = crntAltActionIdx
                ## stage 2's commit 2 (R-V04B-35 (d)): THE ORIGIN of the enqueued action — the handle of the
                ## Component that STATES it (the carrying Component's, published at the walk handover —
                ## R-V04B-50; on the userMH feed the minted user-context handle), carried through the
                ## apply into the stored row's `decided_by`.
                st.queue.decided_by[altActionOnRow, crntSlot] =
                    st.meta_context !== nothing ? (st.meta_context::MetaContext).handle :
                    st.user_context !== nothing ? (st.user_context::UserContext).handle :
                    error("GoMeta absorb: an action enqueued without a document or user context — ",
                        "please report this (not reachable from any input by construction)")

                if !st.mh.slot_has_accum[crntSlot] &&
                   insorted(st.registry.action_to_plugin[crntAltActionIdx],
                    st.registry.accum_alt_idxs)

                    st.mh.slot_has_accum[crntSlot] = true
                end
                end
            else
                error("GoMeta absorb: unknown alterant action ",
                    repr(first(String(altActionName), 40)),
                    " — not one of the registered sorted_alt_actions = ",
                    st.registry.sorted_alt_actions,
                    " (v0's closed action set; see docs/public-api.md §3.4)")
            end
            # The queue condition/args matrices are `Ref`-free: the `Expr` / arg-tuple VALUE is
            # stored directly and the read sites use no `[]` deref.
            if !isLocalOnly     ## a localOnly action never queues — fully handled above
            if conditionExpr !== nothing            # v0.2 FLIP: the no-condition sentinel is `nothing`
                st.queue.conditions[altActionOnRow, crntSlot] = conditionExpr
            end
            if !isempty(argsSSVec)
                ## the kind-preserving coercion: a bare token stays the Symbol it always was; a well-formed quoted token (the
                ## splitter's or the heading arm's — both scanned by `_span`) becomes its String content (`_coerce_arg_token`).
                argsTup = Tuple{Vararg{AlterantArgT}}(_coerce_arg_token.(argsSSVec))
                ## THE ONE TEXT-ARGUMENT RULE (his §359 (8)): the declared record says which slot takes a quoted text.
                _string_slot_check(st.registry.action_specs[st.registry.spec_index[Symbol(altActionName)]], argsTup, metaSS)
                st.queue.args[altActionOnRow, crntSlot] = argsTup
            end
            end
        end
    end
    ## v0.2 localOnly delivery — the ONCE-per-region FLUSH (v0.4 T5: REGISTRY-DRIVEN,
    ## per-plugin, deterministic order): each pending store (every condition-passing
    ## localOnly action of this meta region, in source order per store) mints its rows
    ## with the heading's verbatim text as the value: on the document surface keyed on the
    ## Component the statement is APPLIED TO and decided by the carrier (the metaBlock a
    ## whole-line or a comment-split metaLine forms, R-V04B-50; the LINE with the Segment as
    ## the key's origin for an inline metaSegment, R-V04B-98); on the userMH feed it is
    ## the minted USER-CONTEXT handle + the profile's verbatim bytes. The WRONG-SHAPE
    ## check runs HERE, BEFORE any typed conversion (the T5 floor law — a mismatched or
    ## entries-less store takes the typed WARNING, never a raw TypeError in the poison
    ## window); the attr stem comes from the DECLARED row. Delivery is COMPLETE here:
    ## nothing was queued, so the apply plane never revisits localOnly values.
    for pidx in sort!(collect(keys(pendingLocal)))
        inst = pendingLocal[pidx]
        p = st.registry.plugins[pidx]
        cap = p.capture
        ## (the crx-t5 A1 cure) `capture === nothing` branches FIRST to the FLOOR arm —
        ## the old else-route sent it to UNREADABLE, whose message reads
        ## `p.capture.attr_scheme` on nothing: a raw post-latch throw.
        if cap === nothing
            GMX._capture_floor!(st, p, :WARN_CAPTURE_FLOOR)
        ## (the crx-t5 A4/A5 cures) the scheme IS consulted (`:per_occurrence` — the one
        ## implemented localOnly scheme; tier 1 refuses other localOnly schemes) and the
        ## entries protocol is the CONCRETE type via getfield — `hasfield` alone admitted
        ## a wrong-shaped `entries` that threw inside `capture_heading!`, and property
        ## syntax dispatched an extensible getproperty. The Vector type makes iteration
        ## Base-concrete and every text a String.
        elseif cap.mode_gate === :localOnly && cap.attr_scheme === :per_occurrence &&
               inst isa p.altConstructor &&                       # the record's own store type (the row's instance_type left at stage 5's E5)
               getfield(inst, :entries) isa Vector{Tuple{String,Union{Nothing,Int}}}
            GMX.capture_heading!(st, inst, GMX._capture_stem(p))
        else
            GMX._capture_floor!(st, p, :WARN_CAPTURE_UNREADABLE)
        end
    end
end

## v0.2 localOnly delivery — the WHOLE head path at the absorb seam (the delivery law:
## "applies once, where it stands"). Carries the head-path laws
## that formerly lived on the queued path, verbatim in force:
## - the SLOT-SCOPED String law: the localOnly action admits
##   a String in its TEXT slot (position 1) ONLY — a quoted LEVEL (`head("T", "2")`)
##   meets the same wall as every queued String, so the setter's untyped level slot
##   (the setId-class hazard) can never silently parse one, and a String in a
##   malformed position never reaches the wrong validation class;
## - the Heading VALIDATION (condition-independent, BEFORE the condition): the
##   empty-`""` refusal is STANDING — it fires whether or not a condition would have
##   gated the action — pinned;
## - the APPLICABILITY law for the DERIVING one-argument form: the MetaContext
##   record must be PRESENT (the userMH feed nulls it — no document line exists
##   there, and the USER context is not a placement: the deriving refusal stands on
##   the feed BY CONSTRUCTION); the EXPLICIT two-argument form passes context-free
##   and as-given (it derives nothing; on the feed surface it
##   RECORDS against the minted user-context handle — the user-context build);
## - THE LEVEL VOCABULARY (one vocabulary for depth-marked and explicit forms): the derived level
##   MATERIALIZES as ladder−1 — exactly the author's own `#~`-digit vocabulary (BLS
##   documents `#~`=depth 1 … `#~8`, digit 0 = the file level; ladder =
##   author-digit+1) — so depth-marked and explicit vocabularies COINCIDE (`#~2 "T"`
##   ≡ `head("T", 2)` ⇒ head_2; plain `#~` ⇒ 1; `#~0` ⇒ 0; inline segment ⇒ 10 =
##   lineMHIdx−1, the documented constant). The MetaContext record stays as derived from
##   the parse and the configured namespace, mutated by nothing; the normalization lives
##   at THIS one materialization seam. Materialized as
##   a floor-legal Symbol (`Symbol("2")` — the literal floor reserves ints);
## - THE ONE CONDITION EVALUATION (condition-evaluated-once-at-the-heading): a
##   SETTRIBUTE condition gates the HEADING at its own context (the metaLine's
##   snapshot) — ON THE DOCUMENT SURFACE a false condition means no row, no refusal
##   (pinned); ON THE FEED SURFACE a conditioned head refuses BEFORE evaluation (the
##   user-context build's reserved wall below: the feed carries no evaluable settribute
##   state — the pre-walk snapshot describes no component). A QUERY atom
##   (alterant-state query) REFUSES here at v0.2 (at absorb time `st.working` holds the PREVIOUS apply's residue, so a query
##   would gate the heading on unrelated preceding content — the order-dependent
##   wrong-outcome class; the query form is RESERVED until the Heading runs through the apply loop,
##   R-V04B-101 — the ONE minimal refusal R-V04B-106 (3) keeps; the closed interpreter's full-eval arm (E13)
##   left with its marker at stage 5's E13);
## - the setter is called bare, as on the apply plane — its guard `_invoke_set` left at stage 5's E6
##   of the v0.4 build with its typed refusals (census row 14).
## Registry-driven WHERE THE REGISTRY CAN DRIVE IT: the DIVERT (mode),
## the constructor, the setter, the String-slot capability
## (`accepts_string_slot`), and the VALIDATION seam (the spec's `validate` slot)
## come from the registry record. STILL Heading/grammar-specific in this
## function's own bytes: the arity-keyed deriving-form APPLICABILITY refusal and
## the ladder−1 LEVEL MATERIALIZATION (the record's applicability/phase fields
## DOCUMENT them; their runtime consult is deferred), plus the
## wall message's naming of the head action. (v0.4 T5: the pending store is the
## PER-PLUGIN `Dict{Int8,Any}` and `capture_heading!` is widened to the declared-row
## drive `(st, heading, stem)` — the flush's concrete entries-Vector gate is the
## runtime shape law.) (v0.4 T3 sweep: the former "custom
## localOnly is OUTSIDE the v0.2 envelope / registry reserved" posture note was
## STALE — T2 made published custom registries RUN at the seam; the mint and the set below
## are bare since stage 5's E6 of the v0.4 build (the wrap and the store check left — census row 14);
## `capture_heading!`'s Heading-typing is the T5 capture re-home's row.)
function _absorb_local_only!(
    st, metaSS::SubString{String}, actionName::Symbol,
    argsSSVec::Vector{SubString{String}},
    conditionExpr::Union{Nothing,Expr},
    pendingLocal::Dict{Int8,Any}, plugIdx::Int8
)
    plug = st.registry.plugins[plugIdx]
    ## The String slot law and the validation seam consult the DECLARED registration
    ## record — the spec's `accepts_string_slot` capability and `validate` slot (no
    ## hard-coded slot position or validator call). (What still rides grammar-level head
    ## semantics in this function is enumerated at the function header.)
    spec = st.registry.action_specs[st.registry.spec_index[actionName]]
    argsTup = isempty(argsSSVec) ? () :
        Tuple{Vararg{AlterantArgT}}(_coerce_arg_token.(argsSSVec))
    if any(_a -> _a isa String, argsTup)
        _string_slot_check(spec, argsTup, metaSS)
        # the declared validation runs on the STRING text (a bare-word text in
        # the accepting slot rides to the setter's own dispatch — Julia's MethodError since stage 5's E6
        # of the v0.4 build, census row 14, the build's probe, its B3 — never the wrong-class validation message).
        # v0.4 T3 (T3-DESIGN §3; FM-CB-5) — the result is CONSUMED: `true` accepts;
        # `false` refuses (REG_VALIDATE_FALSE); a non-Bool refuses (RES_RETURN_TYPE — the `-> Bool`
        # contract); a FOREIGN throw wraps (CB_VALIDATE_THROW) — each a catalogue-named stable-message
        # ErrorException (docs/public-api.md §3.4); the engine's own "GoMeta "-prefixed refusals (the
        # ratified empty-heading class) pass through VERBATIM (the pass-through law).
        if spec.validate !== nothing && argsTup[spec.accepts_string_slot] isa String
            ok = try
                spec.validate(argsTup[spec.accepts_string_slot])
            catch e
                e isa InterruptException && rethrow()
                (e isa ErrorException && startswith(e.msg, "GoMeta ")) && rethrow()
                error("GoMeta absorb: the declared handover validation of action ",
                    repr(first(String(actionName), 40)), " threw (CB_VALIDATE_THROW): ",
                    String(nameof(typeof(e))),
                    " — the validate contract is `(text::String) -> Bool` ",
                    "(see docs/public-api.md §3.4)")
            end
            ok === true || (ok === false ?
                error("GoMeta absorb: the declared handover validation of action ",
                    repr(first(String(actionName), 40)), " REFUSED this text ",
                    "(REG_VALIDATE_FALSE) in the meta region ", repr(first(metaSS, 40)),
                    " (see docs/public-api.md §3.4)") :
                error("GoMeta absorb: the declared handover validation of action ",
                    repr(first(String(actionName), 40)), " returned ",
                    String(nameof(typeof(ok))), " (RES_RETURN_TYPE) — the validate ",
                    "contract is `(text::String) -> Bool` (see docs/public-api.md §3.4)"))
        end
        if length(argsTup) == 1
            st.meta_context === nothing &&
                error("GoMeta absorb: heading without a document context — ",
                    "the deriving head form infers its level from the ",
                    "metaLine's attachment, and this surface carries no ",
                    "document line (typed applicability refusal; the ",
                    "explicit head(text, level) form is the context-free ",
                    "sibling; see docs/public-api.md §3.4)")
            argsTup = (argsTup[1],
                Symbol(string((st.meta_context::MetaContext).level - 1)))
        end
    end
    ## THE QUERY WALL (see the function header; R-V04B-106 (3) — ONE minimal refusal kept until the Heading runs through the
    ## apply loop, R-V04B-101): a heading condition may test settribute predicates only — a label test (`getAltState` in the
    ## stored Expr, found by `_has_query`) would read the PREVIOUS apply's residue at this seam.
    if conditionExpr !== nothing && _has_query(conditionExpr)
        error("GoMeta absorb: alterant-state query in a heading condition — a ",
            "heading condition may test only settribute predicates at v0.2 (the ",
            "heading applies at its own line, where no alterant state exists yet; ",
            "the query form is reserved) in the meta region ",
            repr(first(metaSS, 40)), " (see docs/public-api.md §3.4)")
    end
    ## The user-context build's reserved wall (ratified standing; seated AFTER the query wall,
    ## BEFORE evaluation; fires only on the feed surface): a CONDITIONED
    ## head in a fed profile refuses — the feed has no evaluable settribute state (the
    ## pre-walk snapshot describes NO component; a negated atom would evaluate true
    ## against init filler — the fabricated-state class). LIFTING CONDITION (recorded):
    ## the refusal lifts when a build supplies the profile's OWN deserialized settribute
    ## state for this evaluation — not merely when feed state "arrives".
    if conditionExpr !== nothing && st.user_context !== nothing
        error("GoMeta absorb: a conditioned heading in a profile feed — the feed ",
            "surface carries no evaluable settribute state at v0.2 (an unconditioned ",
            "head records; conditions on fed headings are reserved) in the meta ",
            "region ", repr(first(metaSS, 40)),
            " (see docs/public-api.md §3.4)")
    end
    ## THE ONE CONDITION EVALUATION of a heading: Julia evaluates the stored Expr in module GoMeta (where `getState`/`getAltState`
    ## are bound by name) against this metaLine's own snapshot — his legacy's form (goMetaAddOns.jl :37), stage 5's E13
    local _condOutcome = conditionExpr === nothing ? nothing : Core.eval(GMX, conditionExpr)
    if conditionExpr === nothing || _condOutcome
        # v0.4 T5: the store is the OWNING PLUGIN's pending entry (per-plugin injective)
        store = get(pendingLocal, plugIdx, nothing)
        store === nothing && (store = plug.altConstructor())   # the bare mint since stage 5's E6 (census row 14)
        plug.setAltInstance(store, actionName, argsTup...)
        pendingLocal[plugIdx] = store
    end
    return nothing
end

## THE ONE WHITE-SPACE PREDICATE over possibly-invalid UTF-8 (his §359 (10): his legacy's `isspace`): an invalid byte sequence is
## CONTENT — never white space (`isspace` throws at decode on sequences that require it, so every input-facing test of this module goes
## through this guard); on every VALID char it is exactly `isspace`.
_isspace_valid(c::AbstractChar) = isvalid(c) && isspace(c)

"THE ONE TEXT-ARGUMENT RULE (his §359 (8)): a quoted (String) argument is accepted in the one slot the action's DECLARED record names (`accepts_string_slot` — `head`'s text slot; 0 for every other shipped action) and refused in every other — the shipped setters keep untyped value slots, so dispatch alone cannot hold the law (byte-probed: `cell(\"7\")` would parse)"
function _string_slot_check(spec, argsTup, metaSS::SubString{String})
    for (k, a) in enumerate(argsTup)
        a isa String && k != spec.accepts_string_slot &&
            error("GoMeta absorb: string argument not accepted — a quoted (String) argument is accepted only in the slot the action's ",
                "DECLARED record names (the heading's text slot) in the meta region ", repr(first(metaSS, 40)),
                " (see docs/public-api.md §3.4)")
    end
    return nothing
end

"the kind-preserving coercion of one argument token: a bare token stays the Symbol it always was (numeric text included — the integer space is reserved, the setter parses it); a `\"`-led token is a well-formed quoted span — its two producers, the splitter and the heading arm, are scanned by `_span` and validated — and becomes its String content"
_coerce_arg_token(a::SubString{String})::AlterantArgT =
    (isempty(a) || a[firstindex(a)] != '"') ? Symbol(a) : String(a[nextind(a, firstindex(a)):prevind(a, lastindex(a))])

end
#########################################################################################
#########################################################################################