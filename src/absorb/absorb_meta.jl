# absorb_meta.jl — the metaLine parser and meta-hierarchy enqueuer (module AbsorbMeta)
#
# IS: the Absorb-phase metaLine parser and condition intake — the original engine's reader (GoMetaRetro AbsorbMeta.jl) with its grammar made
#     explicit (the creator's decision: his code fixed from the ground up). It splits a metaLine's meta region into
#     metaStatements (absorbMeta's loop + parseAlt), reads
#     one-word labels (parseOneWordLabel) and `()` argument lists (parseArgs) with ONE scanner (_span) and ONE splitter (_split_args),
#     RE-WRITES each condition body's GoMeta-specific parts to Julia text and has Julia's parser read it once (`_rewrite_condition` +
#     `Meta.parse` in parseConditions — the original engine's produceConditionStr read from the ground up),
#     and ENQUEUEs action + condition + args into the per-call queue tensors (absorbMeta — the module's sole export). It enqueues EVERY action — the Heading's too (the creator's decision: the same process as any
#     other Alterant) — applying the queued actions is apply.jl's job; a heading in the profile feed meets the one refusal.
# DOES: a metaStatement is a HEAD — a name, a `:` label, or (the region's first statement only) a `"…"` heading — then at most one `(…)`,
#     then at most one `{…}`, and ENDS at white space or at the region's end; any other character meets the one refusal `_refuse_char`,
#     which names the character, the token it begins and the region. The six structural characters `( ) { } , "` end a name or
#     a label; every other non-white-space character is a name or label character — pictographs and emojis among them; a
#     leading punctuation is part of the name and meets the registry's unknown-action refusal (the prefix sugar is a later
#     version's design). absorbMeta reads the per-call ProcessState through the parent GoMeta.ctx(), hoisted once as `st`; each name is resolved
#     against st.registry.sorted_alt_actions; a slot already holding size(queued, 2) actions refuses with GoMeta's message BEFORE the
#     write (the creator's decision — the limit a fixed size raised by hand); the plugin index and the action index are written into
#     st.queue.queued at the current meta-hierarchy slot, st.mh.slot_has_accum set for the accumulate set, the condition (Julia's `Expr`,
#     or `nothing` for an action written without `{}`) and the argument tuple stored by value; ONE text-argument rule (`_string_slot_check`,
#     the creator's rule) admits a quoted (String) argument in the slot the action's declared record names and refuses it elsewhere; an empty
#     argument piece (`cell(7,)`) is handed on as the empty token — the Alterant decides. A condition body is READ HERE: a
#     settribute key becomes its state read `getState(:key)`, an action of an Alterant that answers queries becomes its query
#     `getAltState(Int8(p), Symbol("…"), …)` (the registry's one rule `queryable_action`), a label test `:name`
#     the Labels query of that name, the creator's `,` becomes `||`, everything else — `&&`, `!`, `()`, `|`, `&`, decimal integers and plain decimal floats (a numeral with a letter or an underscore — `1e3`, `0xff`, `1_000` — starts a key at its letter and refuses), Julia operators but `:` (every `:` outside a quoted text is a label test; this rule and the numerals' hold where the walk reads: the interior of a `:(…)` or `key(…)` argument list is spliced to Julia unread — `{ :(:a) }`),
#     whitespace — is copied verbatim (a bare word that is neither a settribute key nor a queryable action — `true`, `false`, `nothing`
#     among them — is a condition key and refuses, as the original engine read it; a quoted text is copied WHOLE to Julia, never read; except a triple-quoted text with inner quotes or an interpolation holding a quoted text, which the one scanner mis-pairs — a recorded limit); the result is parsed ONCE by `Meta.parse`
#     and the `Expr` evaluated by Julia at apply time (apply.jl; `Core.eval`).
# REASONING: the creator's design — the condition is Julia: GoMeta recognises its own parts and Julia does the rest; the
#     metaLine grammar is the original engine's with its two missing arms supplied: its `parseAlt` had arms for `(`, the label, `{` and white
#     space and no "anything else" case (AbsorbMeta.jl :307–:340), and its outer `ispunct` gate (:304) skipped a leading punctuation — so
#     a statement was never required to END and a leading punctuation was never read: every silent skip, drop and raw BoundsError of the
#     original engine's reader was one of those two arms, cured at their root rather than by a patch per shape
#     (the creator's decision). One of each where there were several — one white-space predicate (`_isspace_valid`, the original
#     engine's `isspace` guarded), one scanner `_span` for EVERY span — the metaLine's and the condition body's (quote-aware: a `}` or `)` inside a quoted
#     text closes nothing; the condition rewrite's own `(…)` finder was removed within the 0.4
#     development), one splitter, one text-argument rule; the backslash reserved in GoMeta's quoted texts — the heading
#     sugar and the quoted arguments, the two producers of the creator's decision — while a condition's quoted text is Julia's — copied WHOLE by the rewrite, never read — and its `\`
#     Julia's escape (the creator's decision). The scanner's form is
#     one routine finding a closing bracket or quote.
#     Honest edges: each refusal is an ErrorException without a code, raised via error() ("the usual error / refusal message", the creator's words); two string shapes are copied in pieces and re-read SILENTLY — a quoted text nested inside an interpolation `$(…)` and an even number of bare `"` inside a triple-quoted text (a recorded limit); the operator `:` and a numeral with letters are read as a label test and a key; a body
#     Julia cannot parse is Julia's own `Meta.ParseError`; an argument's arity or type fault is the Alterant's own setter
#     error; the Labels Alterant's character law and whitelist judge the label names handed over.
# PURPOSE: turn each metaLine of a BLS input into queued alterant work the apply phase consumes, refusing every malformed metaStatement
#     with a stable GoMeta message that names the character at fault, and reading every well-formed one exactly as the original engine read it
#     (the creator's two example files and the twelve frozen forms byte-equal).

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
# the registry's one vocabulary rule for a bare name in a condition: an action of an Alterant
# that answers queries; the rewrite's test where the original engine tested `insorted(key, sortedAltActionsSVec)` (AbsorbMeta.jl :219)
import ..GoMeta: queryable_action
# the widened action-argument literal floor (Symbol|String; ints reserved).
import ..GoMeta: AlterantArgT
# the context record type (the enqueue's provenance columns and the deriving head form's level
# read it) and the user-context record (the feed's identity).
import ..GoMeta: MetaContext, UserContext   # UserContext — the enqueue's origin line reads it on the user feed
export absorbMeta

#########################################################################################
## THE METALINE PARSER — the original engine's reader with its grammar made explicit (the creator's decision: his code fixed
## from the ground up). A metaStatement is a HEAD — a name, a `:` label,
## or, as the region's FIRST statement only, a `"…"` heading (the creator's sugar) — then at most one `(…)`, then at most one `{…}`
## (the creator's order), and it ENDS at white space or at the region's end; any other character meets THE ONE refusal
## `_refuse_char`, which names it (the creator's rule: such situations cause an error). The six structural characters `( ) { } , "` end a
## name or a one-word label; every other non-white-space character is a name or label character — a pictograph or an
## emoji among them (a leading punctuation is part of the name — the prefix sugar is a later design).
## ONE white-space predicate (`_isspace_valid` — the original engine's `isspace`, guarded against invalid UTF-8), ONE scanner
## `_span` for EVERY span — the metaLine's `(…)` `{…}` `"…"` and the
## condition body's `(…)` lists and quoted texts (the rewrite's own finder was removed), ONE argument splitter `_split_args`, ONE refusal helper — where the original engine and the v0.2–v0.3 additions had
## three white-space tests, four bracket loops, three backslash sites and two String walls. One routine finding a closing bracket or quote
## is the scanner's form.
const _STRUCTURAL = ('(', ')', '{', '}', ',', '"')

## The words of the refusals' hints (provisional): the glue hint — a space before
## '(' or '{' separates it from the preceding metaStatement; the labels hint and the quote hint follow the creator's decisions.
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

IS: THE ONE SCANNER of the metaLine grammar ("one routine finds a closing bracket or quote" — the creator's
decision): the original engine's counter loop (AbsorbMeta.jl :44–:53 parseArgs, :88–:99 produceArgsStr, :253–:266
parseConditions) with the opener as its parameter and ONE quote arm.

DOES: `text[thisInd]` is an opener — `(`, `{` or `"`; returns the index of its closer. A bracket nests with its own kind
(the original engine's counters; the other kind is content, as in its loops); inside a bracket span a `"` opens a QUOTED TEXT whose characters
are content — a bracket or a comma inside it closes and splits nothing; a quoted span's own `"` closes it. A `\\` inside a
quoted text: in GoMeta's text (`julia = false` — the quoted heading, a quoted argument, a label list) it is RESERVED and
refuses (the creator's v0.2 decision, given for the sugar span and the String-argument span: a later escape grammar must be
a purely additive widening; reserving only `\\"` refused unevenly — the rejected alternative); in Julia's text (`julia =
true` — a condition body) it escapes the next character as Julia reads it, so the quoted text ends where Julia
ends it. Reaching the end of `text` refuses ONCE, naming the innermost opener left open — the `"` when the text ends inside
a quoted text. One character walk (`nextind`, never a byte count); no regex; no allocation on the accepting path; generic
over `AbstractString` (the parser's `SubString{String}` today; the rewrite's `String` — a condition's quoted
texts are read too).

REASONING: the original engine counted brackets in three loops and the v0.2 additions added quote arms and backslash checks at three
more places; one walk with one quote state serves every span. Julia's other literal delimiters are not known — a Char
literal (`'}'`; `'` is also Julia's adjoint `x'`), a backtick, an odd `"` inside a triple-quoted text, a string prefix's
word: the shapes named — `'}'` and `` `}` `` (the span ends early), the odd `"` (the span left open), a prefix's word (`r"a}b"`, read as a condition key) — end in a loud refusal or Julia's own error; a Char or backtick literal the walk reads nothing of (no word, no `{`, `}`, `"`, `,` or `:` — `'1' == '1'`) reaches Julia unchanged and evaluates. Two shapes are copied in pieces and re-read SILENTLY — a quoted text nested inside an interpolation `\$(…)` and an even number of bare `"` inside a triple-quoted text (a recorded limit).

PURPOSE: where a span ends, for every reader: parseArgs (the argument list and the label list), parseConditions, the quoted
heading, the splitter and the condition rewrite (a body's `(…)` lists and its quoted texts).
"""
function _span(text::AbstractString, thisInd::Int; julia::Bool = false)::Int
    o = text[thisInd]                                    # the opener: '(' '{' or '"'
    c = o == '(' ? ')' : o == '{' ? '}' : '"'            # its closer
    inQuote = o == '"'                                   # a quoted span starts inside its own quote
    countOpenBrakets = 1                                 # the original engine's counter — the opener counted
    while (thisInd = nextind(text, thisInd)) < ncodeunits(text) + 1      # the original engine's loop header (AbsorbMeta.jl :46, :92, :259)
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

"the one unterminated refusal of the metaLine grammar; the innermost opener left open is named, the `\"` when the text ends inside a quoted text"
_refuse_unterminated(text::AbstractString, o::Char, nOpen::Int) =
    error("GoMeta absorb: unterminated '", o, "' — never closed in the meta region ", repr(first(text, 40)),
        " (", nOpen, " still open) (see docs/public-api.md §3.4)")

"the one backslash refusal: a `\\` inside GoMeta's own quoted text (the heading sugar, a quoted argument, a label list) is reserved for the future escape grammar (the creator's v0.2 decision)"
_refuse_backslash(text::AbstractString) =
    error("GoMeta absorb: backslash in a quoted span — reserved for the future escape grammar in the meta region ",
        repr(first(text, 40)), " (see docs/public-api.md §3.4)")

"THE ONE REFUSAL of the metaLine grammar: the character at `i` cannot stand `where` (a position phrase); the message names it, the token it begins and the region — the usual GoMeta refusal form; the four hints' words are provisional"
function _refuse_char(metaSS::SubString{String}, i::Int, where::String, hint::String = "")
    j = i
    while j <= lastindex(metaSS) && !_isspace_valid(metaSS[j])
        j = nextind(metaSS, j)
    end
    error("GoMeta absorb: unexpected character ", repr(metaSS[i]), " ", where, " in the meta region ", repr(first(metaSS, 40)),
        " (the token ", repr(first(SubString(metaSS, i, prevind(metaSS, j)), 40)), ")", hint, " (see docs/public-api.md §3.4)")
end

"the argument list's interior split at its commas outside quoted texts — a quoted text is jumped whole by the one scanner, so its commas are content; a nested `(…)` inside a bare piece does not suppress the split (`f(a,b), c` is three pieces, as the original engine's `split` at AbsorbMeta.jl :56); each piece edge-stripped by the one white-space test; a piece carrying a `\"` must be exactly one well-formed `\"…\"` span (the token law at its ONE seam — the only producer of a quoted argument token; the heading's token is one by construction of `_span`); an empty piece among several is handed on as the empty token — the Alterant decides; `()` is no argument (the original engine's normalisation, AbsorbMeta.jl :57–:60 — `hide()` ≡ `hide`)"
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

"the one-word label starting at `i` (the first character after `:`): the index after the label and the ONE-element argument vector — the sugar `:name` takes one label (the creator's decision: `:name1,name2` is refused at the comma, the right form named); what the name may contain is the Labels Alterant's, the six structural characters excepted; no shipped label name is spelled in this file (the zero-literal law, tests/unit/vocabulary_tests.jl [10])"
function parseOneWordLabel(metaSS::SubString{String}, i::Int)::Tuple{Int,Vector{SubString{String}}}
    j = _token_end(metaSS, i)
    return j, SubString{String}[SubString(metaSS, i, prevind(metaSS, j))]
end

"the `(…)` list opening at `i` (`metaSS[i] == '('` — an action's argument list or the Labels Alterant's `:(…)`): the index after its closing `)` and the argument tokens — the original engine's `parseArgs` (AbsorbMeta.jl :39–:67): its counter loop the one scanner's, its split the one splitter's"
function parseArgs(metaSS::SubString{String}, i::Int)::Tuple{Int,Vector{SubString{String}}}
    j = _span(metaSS, i)
    return nextind(metaSS, j), _split_args(SubString(metaSS, nextind(metaSS, i), prevind(metaSS, j)))
end
# Nothing in this file executes at module load beyond definitions and imports.

## THE CONDITION REWRITE — the creator's design:
## the parser "must simply be able to recognize the GoMeta specific parts of the conditions in order to slightly re-write it when
## storing the condition as a Julia Expression which gets then evaluated on demand by Julia". The original engine's produceConditionStr
## (GoMetaRetro AbsorbMeta.jl :116–:245) read from the ground up: the GoMeta-specific parts of a `{…}` body become Julia
## text, the rest is copied verbatim, and Julia's parser reads the result ONCE here; the stored `Expr` is evaluated by Julia at apply
## (apply.jl):
##   `,`                 → ` || `                                              (the creator's OR — the original engine's :139–:145)
##   `:name`             → `getAltState(Int8(p), Symbol(":"), Symbol("name"))`      (a label test: the Labels Alterant's `:` action,
##                         p its plugin index; the name quoted by `repr`, so EVERY name the vocabulary admits — a ZWJ pictograph too —
##                         is spelled the one way)
##   `:(args)`           → `getAltState(Int8(p), Symbol(":"), args)`               (the parenthesized label form, the args raw)
##   `key` / `key(args)` → `getState(:key)` / `getState(:key, args)`              (a settribute key — `keys(BLS.ComponentSettribute)`)
##                       → `getAltState(Int8(p), Symbol("key"), args)`             (a QUERYABLE action — `queryable_action`: an Alterant
##                         that declares `getAltInstance`; Labels at v0 — the registry's rule)
##                       → the usual unknown-condition-key refusal                   (anything else — the original engine's :231–:234)
##   `"…"`               → verbatim, WHOLE                                       (a quoted text is Julia's — never read by the rewrite, but for the two mis-paired shapes, a recorded limit; its end
##                         found by the one scanner `_span(…; julia = true)`, its `\` Julia's escape)
##   everything else — `&&`, `!`, `()`, `|`, `&`, `||`, decimal integers and plain decimal floats (a numeral with letters starts a key), Julia operators but `:` (a label test), whitespace — verbatim.
## A bare WORD that is neither a settribute key nor a queryable action IS a condition key and meets the refusal — `true`, `false`,
## `nothing` among them (the original engine's reading, :231–:234; a widening stays open); a quoted text is not a word. A worded label
## with a parenthesized list (`:abc(:xyz)`) reads as the label test of the word followed by a Julia call on its
## Bool — a MethodError at apply; the original engine dropped the word and queried the list (:187–:191, :215), the closed interpreter
## refused the shape — a return to either stays open.
## An argument text is spliced as Julia text: its shape is Julia's to judge at apply (`getAltState`'s `Vararg{Symbol}`; an undefined
## name its UndefVarError), as the action arguments are. The walk is a CHAR walk (`nextind`/`lastindex` — never
## the original engine's byte-count end test, whose BoundsError one index past a multibyte final character the 0.2.2 cure fixed;
## tests/unit/unicode_cure_tests.jl [4]/[7] hold the cure). A word ends at whitespace, at a non-identifier character or at one of
## `_COND_DELIMS`; a label name ends at whitespace or at one of `_COND_DELIMS` — the `"` among them:
## a quoted text glued to a key or a label name begins Julia's text (one reading of `"` on both planes).
const _COND_DELIMS = ('(', ')', ',', '!', '&', '|', '"')

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

IS: the condition REWRITE (the creator's design): the `{…}` body
with its GoMeta-specific parts re-written to Julia text (the table in the comment above); the registry supplies the
vocabulary — the settribute keys and the queryable actions. The original engine's `produceConditionStr` read from the ground up.

DOES: one CHAR walk over `text` (`nextind`/`lastindex`, never a byte-count end test), printing into a buffer: `,` →
` || ` (the creator's OR); `:` followed by `(` → the balanced span (the one scanner `_span`, quote-aware) becomes the Labels query
`getAltState(Int8(p), Symbol(":"), args)` with the raw interior as `args` (an empty interior passes none; an unclosed
`(` meets the scanner's unterminated refusal — the condition path's third GoMeta refusal); `:name` (the name to whitespace or one of
`_COND_DELIMS`) → the same query with `Symbol("name")`, the name quoted by `repr` so every name the vocabulary admits
is spelled the one way; a word at an identifier-start character (its run of identifier characters, an optional
balanced `(args)` spliced raw) → `_cond_target`: a settribute key (`keys(BLS.ComponentSettribute)`) becomes
`getState(:key[, args])`, a QUERYABLE action (`queryable_action` — an Alterant that declares `getAltInstance`; the
registry's one rule: the three Visib names `hide` / `show` / `discard` are neither) becomes
`getAltState(Int8(p), Symbol("key")[, args])` with `p` its plugin index, anything else — `true`, `false`, `nothing` among
them — meets the refusal `error("GoMeta absorb: unknown condition key …")`, an `ErrorException` naming the key (bounded
to 40 characters); a quoted text (`"…"`) is copied WHOLE, never read (but for the two mis-paired shapes, a recorded limit) — its end found by `_span(…; julia = true)`, its `\`
Julia's escape (the creator's design); every other character — operators but `:`, parentheses, decimal integers and plain decimal floats,
whitespace, an invalid UTF-8 byte (never a key's start or character — a guard; Julia's parser refuses the text
it reaches) — verbatim. Returns the re-written text as a `String`. Pure over its two arguments (no state read; a
refusal — the unknown key's or the scanner's unterminated `(` — its one exit besides the return); `Meta.parse` reads the result ONCE in its one caller, `parseConditions`,
with `ctx().registry`.

REASONING: the creator's design — the condition is Julia: GoMeta recognises its own parts and Julia does the rest, so the parser
carries no condition grammar of its own (the closed interpreter's walls and condition codes were removed with it); the vocabulary
stays the registry's (settribute keys, queryable actions), the spelling of a label through `repr` keeps one form
for every admitted name, and ONE scanner serves both planes — the condition's own `(…)` finder was removed
(one of each).

PURPOSE: the text Julia's parser turns into the stored `Expr` a queued action's condition evaluates at apply.
"""
function _rewrite_condition(text::String, r)::String
    out = IOBuffer()
    i = firstindex(text); n = lastindex(text)
    while i <= n
        c = text[i]
        if c == '"'                                                  # a quoted text is Julia's: copied whole, never read
            e = _span(text, i; julia = true)                         #   never refuses: the body's extent scan paired every '"' the walk reaches
            print(out, SubString(text, i, e)); i = nextind(text, e)
        elseif c == ','
            print(out, " || "); i = nextind(text, i)
        elseif c == ':'
            j = nextind(text, i)
            if j <= n && text[j] == '('
                e = _span(text, j; julia = true)                     # the parenthesized label list — the one scanner
                args = strip(_isspace_valid, SubString(text, nextind(text, j), prevind(text, e)))
                print(out, _cond_target(Symbol(":"), isempty(args) ? nothing : String(args), r)); i = nextind(text, e)
            else
                k = j
                while k <= n && !_isspace_valid(text[k]) && text[k] ∉ _COND_DELIMS
                    k = nextind(text, k)
                end
                name = text[j:prevind(text, k)]
                print(out, _cond_target(Symbol(":"), isempty(name) ? nothing : string("Symbol(", repr(name), ")"), r)); i = k
            end
        elseif isvalid(c) && Base.is_id_start_char(c)                 # an invalid Char never starts a key — it falls to the verbatim arm and Julia's parser refuses it (the guard of _isspace_valid's class)
            k = nextind(text, i)
            while k <= n && isvalid(text[k]) && Base.is_id_char(text[k]) && text[k] ∉ _COND_DELIMS
                k = nextind(text, k)
            end
            key = Symbol(text[i:prevind(text, k)])
            args = nothing
            if k <= n && text[k] == '('
                e = _span(text, k; julia = true)                     # `key(args)` — the one scanner
                inner = strip(_isspace_valid, SubString(text, nextind(text, k), prevind(text, e)))
                args = isempty(inner) ? nothing : String(inner); k = nextind(text, e)
            end
            print(out, _cond_target(key, args, r)); i = k
        else
            print(out, c); i = nextind(text, i)                       # operators, a bare grouping, plain numbers (a numeral with letters starts a key), whitespace — Julia's, verbatim
        end
    end
    return String(take!(out))
end

"""
    parseConditions(metaSS, i) -> (index after the closing `}`, the condition's `Expr`)

IS: the condition intake — the `{…}` block opening at `i` read into the `Expr` Julia evaluates at apply (the original engine's `parseConditions`,
AbsorbMeta.jl :248–:282; the seam that remains: the GoMeta parts of the body re-written to Julia text, Julia's parser once).

DOES: finds the block's end with the one scanner (quote-aware since 0.4.0 — a `}` inside a quoted text no longer closes
the block); `Meta.parse`s the re-written body ONCE; an EMPTY body or a bare literal (`{}`, `{ 1 }`, `{ | }`) carries
no condition expression and is refused (an unconditional action is written without `{}`); an INCOMPLETE body
(`isCode &&`) is thrown as Julia's own `Meta.ParseError` class HERE, at the statement, never stored for a later reader; a body
Julia cannot parse is Julia's own error out of the goMeta call. The echoed body is bounded to 40 characters.

REASONING: the creator's design — a condition is Julia; the parser carries no condition grammar of its own.

PURPOSE: the stored `Expr` a queued action's condition evaluates at apply.
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

IS: the reader of ONE metaStatement — the original engine's `parseAlt` (AbsorbMeta.jl :286–:360) with its grammar made explicit: HEAD, TAIL, END.

DOES: from the first non-white-space character after `thisInd` (the original engine's :301–:302 search): the HEAD is a `:` label (its `foundLabel`
arm — `:(name1, name2)` through `parseArgs`, `:name` through `parseOneWordLabel`, the lone `:` with zero arguments handed to the
Labels Alterant as the creator orders; any other character after the `:` refused), a `"…"` heading at the region's FIRST
statement only (the sugar lowers here to the `head` action with the quoted span as its one argument — the quotes kept as the
String-lane kind marker `_coerce_arg_token` reads; a non-first quoted text is refused with the creator's hint), a structural
character (refused: no metaStatement starts with one — `#~ ,` and `#~3 (` no longer reach an empty name and Julia's BoundsError),
or a NAME (the run to white space or a structural character — never empty). The TAIL is at most one `(…)` (unless the head took
its arguments) then at most one `{…}`, the creator's order. The END: the next character is white space or the region's end —
anything else is refused by name: a token glued to a closing bracket (`hide()junk`, `hide{isCode}show` — the original engine dropped it),
a second `(` or `{`, a `(` after `{…}`, a `,` after a one-word label (the right form named), a stray `)` `}` `"`. Returns the
name (`head` for the sugar), the argument tokens, the condition (`nothing` for an action without `{}` — minted ONLY here) and
the index of the statement's last character (the original engine's :359 contract; the caller's loop resumes after it).

REASONING: the original engine's reader had arms for `(`, the label, `{` and white space and no "anything else" case (AbsorbMeta.jl
:307–:340), and its outer `ispunct` gate (:304) skipped a leading punctuation — so a statement was never required to END and a
leading punctuation was never read: every silent skip, drop and raw BoundsError of the original engine's reader
was one of those two arms, cured at their root rather than by a patch per shape; the grammar in one sequence replaces its `argsDone` / `conditionsDone`
flags and the three "again" refusals. The negative character rule (white space and the six structural characters end a token;
everything else is a token character) keeps the creator's pictograph and emoji labels and names and drops the Unicode-category
dependence that made `-hide` apply and `+hide` refuse.

PURPOSE: one metaStatement, read as the creator's grammar states it, or one refusal naming the character at fault.
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
                            # metaComponent of the meta region
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
                ## THE ONE REFUSAL of a heading in the profile feed (the creator's decision — no row, one refusal at the read; the
                ## message in his words): a statement of an Alterant of the set mode `localOnly` applies only at the Component
                ## it is applied to, and the profile feed has no Component of the file levels (the creator's term) to be local to.
                st.user_context !== nothing &&
                    st.registry.plugins[st.registry.action_to_plugin[crntAltActionIdx]].setMode === :localOnly &&
                    error("GoMeta absorb: a heading (Heading Alterant) in the profile feed has no Component of the file levels to be local to",
                        " (see docs/public-api.md §3.4)")
                ## THE SLOT BOUND (the creator's decision — the matrix size he chose to start with, increased by hand (hard coded) if 8 proves too small; the size raised by hand when an example asks): the queue
                ## tensors hold size(queued, 2) = SLOT_CAPACITY (state.jl) actions per meta-hierarchy slot — 8, a named constant DECOUPLED
                ## from the registered action count (the slower overflow buffer a later
                ## version's); a further action meets GoMeta's message here, BEFORE the write.
                st.mh.count_actions_per_slot[crntSlot] == size(st.queue.queued, 2) &&
                    error("GoMeta absorb: more than ", size(st.queue.queued, 2), " actions in one meta-hierarchy slot — the queue holds ",
                        size(st.queue.queued, 2), " actions per slot (the slot capacity) in the meta region ", repr(first(metaSS, 40)),
                        " (see docs/public-api.md §3.4)")
                altActionOnRow = (st.mh.count_actions_per_slot[crntSlot] += 1)
                st.queue.queued[1,
                    altActionOnRow, crntSlot] = st.registry.action_to_plugin[crntAltActionIdx]
                st.queue.queued[2,
                    altActionOnRow, crntSlot] = crntAltActionIdx
                ## THE ORIGIN of the enqueued action — the handle of the
                ## Component that STATES it (the carrying Component's, published at the walk handover;
                ## on the userMH feed the minted user-context handle), carried through the
                ## apply into the stored row's `decided_by`.
                st.queue.decided_by[altActionOnRow, crntSlot] =
                    st.meta_context !== nothing ? (st.meta_context::MetaContext).handle :
                    st.user_context !== nothing ? (st.user_context::UserContext).handle :
                    error("GoMeta absorb: an action enqueued without a document or user context — ",
                        "please report this (not reachable from any input by construction)")
                ## The Component the statement is APPLIED TO (the walk's record; `nothing` on the
                ## feed) — the referent of the apply loop's one rule for the set mode `localOnly`
                ## (the metaBlock for a metaLine's statement, the Line for a Code Line's trailing metaSegment).
                st.queue.applied_to[altActionOnRow, crntSlot] =
                    st.meta_context !== nothing ? (st.meta_context::MetaContext).applied : nothing

                if !st.mh.slot_has_accum[crntSlot] &&
                   insorted(st.registry.action_to_plugin[crntAltActionIdx],
                    st.registry.accum_alt_idxs)

                    st.mh.slot_has_accum[crntSlot] = true
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
            if conditionExpr !== nothing            # the no-condition sentinel is `nothing` (since v0.2)
                st.queue.conditions[altActionOnRow, crntSlot] = conditionExpr
            end
            if !isempty(argsSSVec)
                ## the kind-preserving coercion: a bare token stays the Symbol it always was; a well-formed quoted token (the
                ## splitter's or the heading arm's — both scanned by `_span`) becomes its String content (`_coerce_arg_token`).
                argsTup = Tuple{Vararg{AlterantArgT}}(_coerce_arg_token.(argsSSVec))
                local spec = st.registry.action_specs[st.registry.spec_index[Symbol(altActionName)]]
                ## THE ONE TEXT-ARGUMENT RULE: the declared record says which slot takes a quoted text.
                _string_slot_check(spec, argsTup, metaSS)
                ## THE DECLARED HANDOVER VALIDATION, at the read (one seam for every action, where
                ## the Heading's separate path ran it before; the Heading's empty-text refusal thereby stays condition-independent):
                ## the spec's `validate` runs on the String text of the declared slot (`_declared_validation`).
                if spec.validate !== nothing && spec.accepts_string_slot in 1:length(argsTup) && argsTup[spec.accepts_string_slot] isa String
                    _declared_validation(spec, argsTup[spec.accepts_string_slot], Symbol(altActionName), metaSS)
                end
                ## THE DERIVING FORM's LEVEL (the creator's words — `head()` infers its level from where it is placed; the level
                ## vocabulary his: `#~` ⇒ 1, `#~0` ⇒ 0, an inline metaSegment ⇒ 10 = lineMHIdx − 1):
                ## a one-argument statement OF AN ALTERANT OF THE SET MODE `localOnly` whose only argument fills the declared String
                ## slot takes the placement's level from the walk's record as its second argument — the scope the retired separate
                ## path had — so the setter the apply calls is the explicit
                ## two-argument form; the level rides from the queue, never read from the Component's depth;
                ## every other action's tuple is handed over as stated.
                if length(argsTup) == 1 && spec.accepts_string_slot == 1 && argsTup[1] isa String &&
                   st.registry.plugins[st.registry.action_to_plugin[crntAltActionIdx]].setMode === :localOnly
                    st.meta_context === nothing &&
                        error("GoMeta absorb: an action deriving its level without a document context — please report this ",
                            "(not reachable from any input by construction: the profile feed refuses every statement of the set mode localOnly before this point)")
                    argsTup = (argsTup[1], Symbol(string((st.meta_context::MetaContext).level - 1)))
                end
                st.queue.args[altActionOnRow, crntSlot] = argsTup
            end
        end
    end
end

"THE DECLARED HANDOVER VALIDATION of one String argument at the read (the spec's `validate` slot; the envelope moved from the Heading's separate path to the enqueue seam — one seam for every action): `true` accepts; `false` refuses (REG_VALIDATE_FALSE); a non-Bool refuses (RES_RETURN_TYPE — the `-> Bool` contract); a FOREIGN throw wraps (CB_VALIDATE_THROW); the Engine's own \"GoMeta \"-prefixed refusals pass through VERBATIM (the pass-through law — the Heading's empty-text refusal among them); an InterruptException is rethrown"
function _declared_validation(spec, text::String, actionName::Symbol, metaSS::SubString{String})
    ok = try
        spec.validate(text)
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
    return nothing
end

## THE ONE WHITE-SPACE PREDICATE over possibly-invalid UTF-8 (the original engine's `isspace`, guarded): an invalid byte sequence is
## CONTENT — never white space (`isspace` throws at decode on sequences that require it, so every input-facing test of this module that
## decodes a character carries this guard — the white-space tests through this predicate, the condition rewrite's two identifier tests in
## line (`_rewrite_condition`)); on every VALID char it is exactly `isspace`.
_isspace_valid(c::AbstractChar) = isvalid(c) && isspace(c)

"THE ONE TEXT-ARGUMENT RULE: a quoted (String) argument is accepted in the one slot the action's DECLARED record names (`accepts_string_slot` — `head`'s text slot; 0 for every other shipped action) and refused in every other — the shipped setters keep untyped value slots, so dispatch alone cannot hold the law (byte-probed: `cell(\"7\")` would parse)"
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