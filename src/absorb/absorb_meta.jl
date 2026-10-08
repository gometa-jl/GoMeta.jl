# absorb_meta.jl — the metaLine parser and meta-hierarchy enqueuer (module AbsorbMeta)
#
# IS: the Absorb-phase metaLine parser and condition extractor. It splits a metaLine's meta region
#     into alterant clauses (parseAlt), parses one-word labels (parseOneWordLabel) and balanced
#     '()' argument lists (parseArgs / produceArgsStr), RE-WRITES each condition body's GoMeta-specific parts to Julia text
#     and has Julia's parser read it once (`_rewrite_condition` + `Meta.parse` in parseConditions — his legacy's
#     produceConditionStr read from the ground up, stage 5's E13 of the v0.4 build, census row 1; R-V04B-106 (2); his §D174),
#     and ENQUEUEs action + condition + args into the per-call queue tensors (absorbMeta — the module's sole export).
#     It enqueues, never applies: applying queued alterants is apply.jl's job.
# DOES: absorbMeta reads the per-call ProcessState through the parent GoMeta.ctx(), hoisted once
#     per call as `st`. Each parsed action name is resolved against st.registry.sorted_alt_actions;
#     the declaration-order plugin index and the action index are written into st.queue.queued at
#     the current meta-hierarchy slot, st.mh.slot_has_accum is set for actions in the registry's
#     accumulate set, and the parsed condition (Julia's `Expr`) / Symbol-tuple args are stored by value in
#     st.queue.conditions / st.queue.args. A condition body is READ HERE: a settribute key becomes its state read
#     `getState(:key)`, an action of an Alterant that answers queries becomes its query `getAltState(Int8(p), Symbol("…"), …)`
#     (the registry's one rule `queryable_action`, stage 5's E12 — R-V04B-99), a label test `:name` the Labels query of that
#     name, his `,` becomes `||`, everything else — `&&`, `!`, `()`, `|`, `&`, numbers, Julia operators, whitespace — is copied
#     verbatim (a bare word that is neither a settribute key nor a queryable action — `true`, `false`, `nothing`, a quoted string's
#     word among them — is a condition key and refuses, as his legacy read it);
#     the result is parsed ONCE by `Meta.parse` and the `Expr` evaluated by Julia at apply time (apply.jl; `Core.eval`), or,
#     for a heading's condition, once at this seam (`_absorb_local_only!`).
# REASONING: his design — the condition is Julia (OWNER-WORDS §120, §D174): GoMeta recognises its own parts and Julia does the
#     rest, so a Julia Boolean expression over the GoMeta names is a condition (`{ 1 == 1 }` is one). The vocabulary stays
#     GoMeta's: a bare name that is neither a settribute key nor a queryable action meets the usual unknown-condition-key
#     refusal here (the legacy's :231–:234) — the vocabulary's one refusal; the seam's other refusal is the no-expression guard
#     below (two refusals of GoMeta's on the condition path, no more); a body Julia cannot parse is
#     Julia's own `Meta.ParseError` out of the goMeta call (an incomplete body thrown as the same class HERE, never stored for a
#     later reader); an empty block or a bare literal (`{}`, `{ 1 }`) carries no condition expression and is refused (register
#     E13-6); an argument text is spliced as Julia text and judged by Julia at apply (as the action arguments are since
#     stage 5's E6). Two guarded refusals live here: "GoMeta absorb: unknown alterant action" — the registry else-branch (the
#     E-01 family) — and the unknown condition key. Four guards ADDED to his legacy's metaLine parser left at stage 5's E7 of
#     the v0.4 build (census row 41; his §120) — the punctuation wall at the action-name position, the glued-token wall after a
#     closing ')' or '}', the no-token guard and the per-slot capacity guard: a malformed metaLine is read as his legacy read
#     it — punctuation at the action position skipped to the next identifier, a glued token dropped (census row 41) — or
#     meets Julia's own BoundsError (an empty meta region; a further action in a full slot — the queue tensor's width is the
#     registered action count). Honest edges: each refusal is an untyped ErrorException raised via error(); their typed
#     conversion is deferred at v0. The closed condition interpreter's walls (left at E13: the 29-step scan cap, the atom wall,
#     the byte and depth walls) and its typed condition codes left with the interpreter at E13 — Julia's parser has none of them.
# PURPOSE: turn each metaLine of a BLS input into queued alterant work the apply phase consumes,
#     refusing out-of-vocabulary metadata and the structural shapes his legacy refused (a duplicate or unterminated list or
#     block, a misplaced label) with a stable, documented message; a malformed metaLine is otherwise read as his legacy read it
#     (stage 5's E7 of the v0.4 build, census row 41).

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

function parseOneWordLabel(
    metaSS::SubString{String},
    thisInd::Int
)::Tuple{Int,Vector{SubString{String}}}

    indStartArgs = thisInd
    local labelEndFound::Union{Nothing,UnitRange{Int64}}
    local indEndArgs::Int
    labelEndFound = findfirst(
        r"(\s|{){1}",
        view(metaSS, thisInd:lastindex(metaSS)))
    if labelEndFound !== nothing
        thisInd = indStartArgs - 1 + labelEndFound[1]
        indEndArgs = prevind(metaSS, thisInd)
    else
        indEndArgs = lastindex(metaSS)
    end
    thisInd = indEndArgs
    argsSSVec = [strip(_isspace_valid, p) for p in split(metaSS[indStartArgs:indEndArgs], ",")]
    if length(argsSSVec) == 1 && argsSSVec[1] == ""
        ## Return `isempty` vector instead:
        argsSSVec = Vector{SubString{String}}[]
    end
    return thisInd, argsSSVec
end

#########################################################################################
#########################################################################################
## `parseArgs()` — the STRING-LANE WIDENING (quote-aware; MECHANISM only).
## A '"'-delimited span is ONE token: ',' '(' ')' inside it are CONTENT, not structure. NO
## metaLine grammar accepts a string argument here (that is the heading recognizer's carve-out): a
## quoted token flows the widened lane as a String KIND (see `_coerce_arg_token`) and meets
## a TRANSITIONAL typed refusal at the enqueue seam in `absorbMeta` (dispatch alone cannot
## hold the law — the built-in toy setters keep an untyped value slot that would parse
## `cell("7")`; byte-probed).
## Every QUOTE-FREE argument list takes the BYTE-IDENTICAL pre-widening path below (two-path
## split), so the pre-widening envelope cannot shift. Refusal classes minted here, all
## loud, never a silent mangle: UNTERMINATED quoted argument; BACKSLASH inside a
## quoted span (the WHOLE backslash character is RESERVED at v0.2 for the future
## escape grammar; see
## `_consume_heading_span`'s header for the full why + rejected alternative);
## MALFORMED quoted argument (a quote
## glued to bare text, a stray quote, or more than one span in one token).
function parseArgs(
    metaSS::SubString{String},
    thisInd::Int
)::Tuple{Int,Vector{SubString{String}}}

    countOpenBrakets = 1
    inQuote = false
    sawQuote = false
    indStartArgs = nextind(metaSS, thisInd)
    while (thisInd = nextind(metaSS, thisInd)) < ncodeunits(metaSS) + 1
        c = metaSS[thisInd]
        if c == '"'
            inQuote = !inQuote
            sawQuote = true
        elseif inQuote
            ## THE BACKSLASH RESERVATION:
            ## ANY `\` inside a quoted span refuses at v0.2 — the argument-lane twin
            ## of the heading-span law (full WHY + rejected alternative at
            ## `_consume_heading_span`'s header: the future escape grammar must be a
            ## purely additive widening, so no valid v0.2 document may carry a
            ## backslash a later grammar would reinterpret; sugar ≡ canonical holds
            ## because both producers refuse).
            if c == '\\'
                error("GoMeta absorb: backslash in a quoted argument — the backslash is ",
                    "reserved inside quoted spans at v0.2 for the future escape grammar ",
                    "in the meta region ", repr(first(metaSS, 40)),
                    " (see docs/public-api.md §3.4)")
            end
        elseif c == '('
            countOpenBrakets += 1
        elseif c == ')'
            countOpenBrakets -= 1
        end
        countOpenBrakets == 0 ? break : nothing
    end
    inQuote && error("GoMeta absorb: unterminated quoted argument — a '\"' in a metaLine ",
        "argument list was never closed in the meta region ", repr(first(metaSS, 40)),
        "; v0 requires balanced '\"\"' around a quoted argument ",
        "(see docs/public-api.md §3.4)")
    if countOpenBrakets == 0
        indEndArgs = prevind(metaSS, thisInd)
        if !sawQuote
            ## the BYTE-IDENTICAL pre-widening path — every quote-free list, verbatim as before
            argsSSVec = [strip(_isspace_valid, p) for p in split(metaSS[indStartArgs:indEndArgs], ",")]
            if length(argsSSVec) == 1 && argsSSVec[1] == ""
                ## Return `isempty` vector instead:
                argsSSVec = Vector{SubString{String}}[]
            end
        else
            argsSSVec = _split_args_quote_aware(metaSS[indStartArgs:indEndArgs])
        end
    else
        error("GoMeta absorb: unterminated argument list — a '(' in a metaLine was never closed ",
            "(", countOpenBrakets, " still open); v0 requires balanced '()' ",
            "(see docs/public-api.md §3.4)")
    end
    return thisInd, argsSSVec
end

## The quote-aware splitter (the widening step): top-level commas split; commas inside a quoted span are
## inert. Each piece is edge-stripped exactly like the pre-widening path (quotes are not
## whitespace, so a quoted token keeps its delimiters — the KIND marker `_coerce_arg_token`
## reads). A piece carrying any '"' must be EXACTLY one well-formed span (`"…"`); anything
## else refuses loudly. Empty pieces survive as "" tokens, exactly like the pre-widening split.
function _split_args_quote_aware(argtext::Union{String,SubString{String}})::Vector{SubString{String}}
    pieces = SubString{String}[]
    start = firstindex(argtext)
    i = start
    inq = false
    while i <= lastindex(argtext)
        c = argtext[i]
        if c == '"'
            inq = !inq
        elseif c == ',' && !inq
            push!(pieces, SubString(argtext, start, prevind(argtext, i)))
            start = nextind(argtext, i)
        end
        i = nextind(argtext, i)
    end
    push!(pieces, SubString(argtext, start, lastindex(argtext)))
    out = SubString{String}[]
    for p in pieces
        t = strip(_isspace_valid, p)
        occursin('"', t) && !_is_wellformed_quote_span(t) && _refuse_malformed_quote(t)
        push!(out, t)
    end
    return out
end

## The quote-span LAW, one predicate, enforced at TWO seams (the quote-aware splitter
## above and the kind coercion `_coerce_arg_token` below — two seams because argsSSVec has
## two producers and only parseArgs is quote-aware): exactly one well-formed '"…"' span
## forming the WHOLE token. The length/edge conjuncts run BEFORE the interior slice, so
## the slice is computed only under its own precondition (review-found ordering).
_is_wellformed_quote_span(t::AbstractString) =
    ncodeunits(t) >= 2 && t[firstindex(t)] == '"' && t[lastindex(t)] == '"' &&
    !occursin('"', t[nextind(t, firstindex(t)):prevind(t, lastindex(t))])

_refuse_malformed_quote(t::AbstractString) =
    error("GoMeta absorb: malformed quoted argument — a quoted argument is ",
        "exactly one '\"…\"' span forming the whole token (got ",
        repr(first(String(t), 40)),
        "); v0's argument grammar (see docs/public-api.md §3.4)")
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
                    args = strip(span[2])
                    print(out, _cond_target(Symbol(":"), isempty(args) ? nothing : String(args), r)); i = nextind(text, span[1])
                end
            else
                k = j
                while k <= n && !isspace(text[k]) && text[k] ∉ _COND_DELIMS
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
                    inner = strip(span[2])
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

function parseConditions(
    metaSS::SubString{String},
    thisInd::Int ## `thisInd` s.t. `metaSS[thisInd]` == '{'. See `parseAlt(...)`
)::Tuple{Int,Expr}

    countOpenBrakets = 1
    indStartArgs = nextind(metaSS, thisInd)
    local conditionExpr::Expr

    while (thisInd = nextind(metaSS, thisInd)) < ncodeunits(metaSS) + 1
        if metaSS[thisInd] == '{'
            countOpenBrakets += 1
        elseif metaSS[thisInd] == '}'
            countOpenBrakets -= 1
        end
        countOpenBrakets == 0 ? break : nothing
    end
    if countOpenBrakets == 0
        indEndArgs = prevind(metaSS, thisInd)
        local bodyStr = String(metaSS[indStartArgs:indEndArgs])
        ## THE REWRITE, then Julia's parser — ONCE, here (his legacy's :269–:270). A syntax error is Julia's own `Meta.ParseError`
        ## out of the goMeta call (as a malformed action argument is Julia's since stage 5's E6); an INCOMPLETE body (`isCode &&`)
        ## comes back as `Expr(:incomplete, …)` and is thrown as the same class HERE, at the statement — never stored for a later
        ## reader; an EMPTY body or a bare literal (`{}`, `{ 1 }`, `{ | }`) carries no condition expression and is refused
        ## (an unconditional action is written without `{}`; register E13-6 — the legacy stored nothing and applied unconditionally;
        ## a quoted string's WORD is a condition key and meets the rewrite's refusal, E13-6's note). The echoed body is bounded to
        ## 40 characters, as every refusal's token is (docs/public-api.md §4).
        local ex = Meta.parse(_rewrite_condition(bodyStr, ctx().registry))
        ex isa Expr || error("GoMeta absorb: the condition block {", first(bodyStr, 40), "} carries no condition expression (",
            ex === nothing ? "an empty block" : "a bare literal", ") — an unconditional action is written without '{}' ",
            "(see docs/public-api.md §3.4)")
        Meta.isexpr(ex, :incomplete) && throw(ex.args[1] isa Exception ? ex.args[1] : Meta.ParseError(string(ex.args[1])))
        conditionExpr = ex
    else
        error("GoMeta absorb: unterminated condition block — a '{' in a metaLine was never ",
            "closed (", countOpenBrakets, " still open); v0 requires balanced '{}' ",
            "(see docs/public-api.md §3.4)")
    end
    return thisInd, conditionExpr
end

#########################################################################################
#########################################################################################
function parseAlt(
    metaSS::SubString{String},
    thisInd::Int,
    firstToken::Bool = false   # v0.2 CH-3 step 9: true only for the FIRST metaComponent
                               # of the meta region — gates the quoted-first recognizer
)::Tuple{SubString{String},Vector{SubString{String}},Union{Nothing,Expr},Int}

    indStartAlt::Int = 0
    indEndAlt::Int = 0
    argsDone::Bool = false
    conditionsDone::Bool = false
    foundLabel::Bool = false
    headSugar::Bool = false       ## v0.2 CH-3 step 9: this atom is the quoted-first heading
    local argsSSVec::Vector{SubString{String}}
    local conditionExpr::Union{Nothing,Expr}   # Julia's Expr, or the `nothing` sentinel (an action without `{}`)
    if metaSS[nextind(metaSS, thisInd)] == ':'
        foundLabel = true
    end
    while (thisInd = nextind(metaSS, thisInd)) < ncodeunits(metaSS) + 1
        if !_isspace_valid(metaSS[thisInd])
            ## THE QUOTED-FIRST HEADING RECOGNIZER (the second of the two CLOSED grammar grants).
            ## IF this is the FIRST metaComponent of the
            ## meta region AND it starts with '"': the fenced String is a parameter input
            ## to the deriving head call — the sugar LOWERS here (parse-time shape, not an
            ## alias): the returned action name is the `head` action and the
            ## fenced token (delimiters kept — the String-lane kind marker) is its single argument,
            ## riding the widened String lane. The span is consumed FIRST; the state primed below sets the
            ## token inds, and the inner loop continues normally (a following '{' attaches conditions; '('
            ## meets the duplicate-argument refusal). The punctuation wall, the glued-token wall and the no-token guard left at stage 5's E7
            ## of the v0.4 build (census row 41): glued junk after the closing '"' is dropped by the same inner-loop silence with
            ## which his legacy's reader dropped a token glued to a closing ')' or '}' (the legacy had no quoted-heading span —
            ## the seat's F4). A NON-first quoted token's semantics stay RESERVED (unassigned) at v0.2 — it meets the
            ## legacy's unknown-action refusal (the quote skipped, the token `T"` unknown), not the former wall.
            ## Applicability (the MetaContext record) is checked at the enqueue seam.
            if firstToken && !foundLabel && metaSS[thisInd] == '"'
                headSugar = true
                indStartAlt = thisInd
                (thisInd, headingTok) = _consume_heading_span(metaSS, thisInd)
                indEndAlt = thisInd            ## the closing '"'
                argsSSVec = SubString{String}[headingTok]
                argsDone = true
            end
            ## The first non-space Char: punctuation at the action-name position is skipped to the next identifier,
            ## as his legacy read it (`#~ , discard` reads as `discard`) — the punctuation wall left at stage 5's E7
            ## of the v0.4 build, census row 41.
            if !_ispunct_valid(metaSS[thisInd]) || foundLabel || headSugar

                headSugar || (indStartAlt = thisInd)
                while (thisInd = nextind(metaSS, thisInd)) < ncodeunits(metaSS) + 1
                    if metaSS[thisInd] == '('
                        if argsDone == false && conditionsDone == false
                            indEndAlt = prevind(metaSS, thisInd)
                            (thisInd, argsSSVec) = parseArgs(metaSS, thisInd)
                            argsDone = true
                        else
                            error("GoMeta absorb: duplicate argument list — a metaLine action ",
                                "may carry '()' arguments only once (see docs/public-api.md §3.4)")
                        end
                    ## Text-law rider: the char-next predicate replaces byte+1 — identical
                    ## today (the char at indStartAlt is single-byte on this path),
                    ## structurally safe when the vocabulary widens.
                    elseif foundLabel && thisInd == nextind(metaSS, indStartAlt)
                        if argsDone == false && conditionsDone == false
                            indEndAlt = prevind(metaSS, thisInd)
                            (thisInd, argsSSVec) = parseOneWordLabel(metaSS, thisInd)
                            argsDone = true
                        else
                            error("GoMeta absorb: misplaced one-word label — a metaLine action may carry its ",
                                "arguments ('()' list or one-word label) only once, before any '{}' conditions (see docs/public-api.md §3.4)")
                        end
                    elseif metaSS[thisInd] == '{'
                        if conditionsDone == false
                            (indStartAlt > indEndAlt) ?
                            indEndAlt = prevind(metaSS, thisInd) : nothing
                            (thisInd, conditionExpr) = parseConditions(metaSS, thisInd)
                            conditionsDone = true
                        else
                            error("GoMeta absorb: duplicate condition block — a metaLine action ",
                                "may carry '{}' conditions only once (see docs/public-api.md §3.4)")
                        end

                    elseif _isspace_valid(metaSS[thisInd])
                        break
                    end
                    ## (a token glued to a closing ')' or '}' is dropped, as his legacy's reader dropped it — `hide()junk`
                    ## reads as `hide`; the glued-token wall left at stage 5's E7 of the v0.4 build, census row 41)
                end
                thisInd = prevind(metaSS, thisInd)
                (indStartAlt > indEndAlt) ? indEndAlt = thisInd : nothing
                if argsDone
                    argsDone = false
                end
                if conditionsDone
                    conditionsDone = false
                end
                break
            end
        end
    end
    if !(@isdefined argsSSVec)
        argsSSVec = Vector{SubString{String}}[]
    end
    if !(@isdefined conditionExpr)
        ## The no-condition SENTINEL is minted ONLY here (an action written WITHOUT `{}`);
        ## the condition intake (parseConditions) never returns it — an authored `{}` either yields
        ## an `Expr` or a refusal (the queue's condition matrix is Union{Nothing,Expr}).
        conditionExpr = nothing
    end
    ## (a meta region yielding NO alterant token — `#~ ,`, `#~3 (` — reaches `metaSS[0:0]` and meets Julia's own
    ## BoundsError, as his legacy's reader did; the no-token guard left at stage 5's E7 of the v0.4 build, census row 41)
    ## The sugar's action NAME is SYNTHETIC (the lowering target — the `head` action),
    ## never a metaSS span; the token inds above stay the SPAN's
    ## (the end-of-scan arithmetic keys on them).
    return (headSugar ? _HEAD_ACTION_NAME_SS : metaSS[indStartAlt:indEndAlt]),
        argsSSVec, conditionExpr, thisInd
end

## The lowered spelling of the quoted-first sugar — the deriving head call's name (the
## action is `head`), as a SubString so parseAlt's return type is unchanged.
const _HEAD_ACTION_NAME_SS = SubString(String("head"))

## v0.2 CH-3: consume ONE '"'-fenced heading span starting at the opening quote.
## Returns (index-of-the-closing-quote, the token WITH its delimiters — the String-lane kind
## marker the coercion strips). Refusal classes, the heading-lane siblings of the
## argument-lane quote refusals: a BACKSLASH anywhere in the span is reserved (below),
## an unterminated span refuses loudly.
##
## THE BACKSLASH RESERVATION: ANY
## `\` inside a quoted span meets a typed refusal at v0.2 — not merely `\"`. WHY: an escape grammar
## is intended for a later version; if v0.2 accepted `\` as ordinary content, every
## shipped document containing one would change meaning or break the day escapes
## arrive (`\b` → unknown escape), forcing that grammar to either break shipped
## documents or carve permanent literal-backslash exceptions. Refusing ALL backslashes
## now means no valid v0.2 document can be reinterpreted — the future escape grammar
## becomes a purely additive widening. REJECTED ALTERNATIVE: reserving only `\"` —
## which also refused unevenly (`"a\b"`
## accepted while `"a\\"` refused, the trailing backslash reading as `\"`). BOTH span
## producers hold this law identically (parseArgs' in-quote scan is the argument-lane
## twin), so the documented sugar ≡ canonical equivalence holds.
function _consume_heading_span(metaSS::SubString{String}, thisInd::Int)::Tuple{Int,SubString{String}}
    indOpen = thisInd
    while (thisInd = nextind(metaSS, thisInd)) < ncodeunits(metaSS) + 1
        c = metaSS[thisInd]
        if c == '\\'
            error("GoMeta absorb: backslash in a quoted heading — the backslash is ",
                "reserved inside quoted spans at v0.2 for the future escape grammar ",
                "in the meta region ", repr(first(metaSS, 40)),
                " (see docs/public-api.md §3.4)")
        elseif c == '"'
            return thisInd, SubString(metaSS, indOpen, thisInd)
        end
    end
    error("GoMeta absorb: unterminated quoted heading — a first-position '\"' in the ",
        "meta region ", repr(first(metaSS, 40)), " was never closed; a quoted heading ",
        "is one '\"…\"'-fenced span (see docs/public-api.md §3.4)")
end


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
    ## ONCE after the component loop via the REGISTRY-DRIVEN loop below (keyed to the
    ## carrying Component's occurrence handle — the metaBlock a whole-line metaLine forms,
    ## R-V04B-50; the Segment of an inline one).
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
                ## The queue tensors hold size(queued, 2) = the registered action count of actions per MH slot; a further
                ## action meets Julia's own BoundsError at the write below (the plain Array is bounds-checked; no @inbounds) —
                ## the pre-increment capacity guard left at stage 5's E7 of the v0.4 build (census row 41; his §120).
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
                ## v0.2 CH-3 step 8: kind-preserving coercion through the widened args wall
                ## (was the blanket `Tuple{Vararg{Symbol}}(Symbol.(argsSSVec))` — every bare
                ## token still becomes the SAME Symbol it always did; only a VALIDATED
                ## well-formed quoted token becomes a String — the coercion enforces the
                ## span law ITSELF, because the one-word-label producer is quote-blind;
                ## see _coerce_arg_token's docstring).
                argsTup = Tuple{Vararg{AlterantArgT}}(_coerce_arg_token.(argsSSVec))
                ## THE STEP-8 WALL, SIMPLIFIED AT THE localOnly BUILD: NO queued action
                ## accepts a String argument at v0.2 — the head action (the one
                ## String-accepting surface) is localOnly and DIVERTED before this
                ## path, so the wall here is UNCONDITIONAL (the former name-literal
                ## head exemption is RETIRED; the mode divert is registry-driven).
                ## Dispatch alone cannot hold this law: the built-in toy setters keep
                ## an UNTYPED value slot (`setId` does `parse(Int16, string(idValue))`,
                ## so `cell("7")` would silently ACCEPT — byte-probed).
                ## PLACEMENT NOTE (review-found, recorded not moved): this wall runs
                ## AFTER the row bookkeeping above, unlike the I13 guard's
                ## fire-before-mutate doctrine. Deliberate: every refusal here aborts
                ## the whole call and the per-call state is discarded whole, so the
                ## partial row is unobservable.
                for _a in argsTup
                    _a isa String &&
                        error("GoMeta absorb: string argument not accepted — ",
                            "a quoted (String) argument is reserved at this surface at v0.2 ",
                            "(only an action whose DECLARED record carries a String slot ",
                            "accepts one — the heading's text slot; see ",
                            "docs/public-api.md §3.4)")
                end
                st.queue.args[altActionOnRow, crntSlot] = argsTup
            end
            end
        end
    end
    ## v0.2 localOnly delivery — the ONCE-per-region FLUSH (v0.4 T5: REGISTRY-DRIVEN,
    ## per-plugin, deterministic order): each pending store (every condition-passing
    ## localOnly action of this meta region, in source order per store) mints its rows
    ## keyed to the region's OWN identity + content: on the document surface that is
    ## the carrying Component's occurrence handle + its verbatim bytes (the metaBlock a
    ## whole-line metaLine forms, R-V04B-50; the Segment of an inline one); on the userMH feed it is
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
        for (_i, _a) in enumerate(argsTup)
            _a isa String && _i != spec.accepts_string_slot &&
                error("GoMeta absorb: string argument not accepted — ",
                    "a quoted (String) argument is reserved at this surface at v0.2 ",
                    "(only an action whose DECLARED record carries a String slot ",
                    "accepts one — the heading's text slot) in the meta region ",
                    repr(first(metaSS, 40)),
                    " (see docs/public-api.md §3.4)")
        end
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

## Character predicates over possibly-invalid UTF-8: an invalid byte sequence is CONTENT — never
## whitespace, never punctuation. The Unicode-category predicates (`isspace`/`ispunct`) throw at
## decode on sequences that require it (overlong encodings and kin), so every input-facing test
## in this module goes through these guards. On every VALID char each is exactly its Base twin.
_isspace_valid(c::AbstractChar) = isvalid(c) && isspace(c)
_ispunct_valid(c::AbstractChar) = isvalid(c) && ispunct(c)

## The ONE kind-preserving coercion point of the widened String lane.
## The String arm VALIDATES THE SPAN ITSELF (the shared `_is_wellformed_quote_span` law):
## argsSSVec has TWO producers and only one is quote-aware — parseArgs validates spans in
## its splitter, but parseOneWordLabel (the one-word-label route) is QUOTE-BLIND, so a
## label metaLine like `#~ :"ab` hands this point an unvalidated '"'-leading token
## (an unconditional strip would MANGLE such tokens before the transitional wall refused
## them). A '"'-leading token
## failing the span law meets the same malformed-quoted-argument refusal the splitter
## mints; a well-formed one becomes its String CONTENT (delimiters stripped). TRIGGER
## SCOPE, per route: here the law binds '"'-LEADING tokens; a
## label token merely CONTAINING a quote (`#~ :a"b`) stays a Symbol and meets the closed
## label vocabulary's own refusal downstream — its pre-widening fate, deliberately
## unchanged (re-classing it would be an uncommanded envelope change; the argument-list
## route's splitter, by contrast, invokes the law on ANY quote in a piece). EVERY bare
## token stays the Symbol it always was, INCLUDING numeric text (`Symbol("7")`) — the
## literal floor is EXACTLY Symbol|String: the integer space is RESERVED, deliberately not
## coerced, so numeric args keep their byte-exact pre-widening fates at the setter, which
## parses them itself. No metaLine grammar accepts a String at this step — a String kind meets the
## TRANSITIONAL typed refusal at the enqueue seam (see absorbMeta; dispatch alone cannot
## hold the law — the built-in toy setters keep an untyped value slot); the recognizer
## step opens the first legitimate String surface.
function _coerce_arg_token(a::SubString{String})::AlterantArgT
    (isempty(a) || a[firstindex(a)] != '"') && return Symbol(a)
    _is_wellformed_quote_span(a) || _refuse_malformed_quote(a)
    ## THE BACKSLASH RESERVATION at the THIRD producer (the quote-blind
    ## one-word-label route hands this point spans NEITHER scan visited — e.g.
    ## `#~ :"a\b"` — which would otherwise fall to the String wall's WRONG refusal class):
    ## the interior scan holds the reservation with its OWN class at every producer.
    occursin('\\', a) &&
        error("GoMeta absorb: backslash in a quoted argument — the backslash is ",
            "reserved inside quoted spans at v0.2 for the future escape grammar ",
            "(the token ", repr(first(String(a), 40)),
            "; see docs/public-api.md §3.4)")
    return String(a[nextind(a, firstindex(a)):prevind(a, lastindex(a))])
end

end
#########################################################################################
#########################################################################################