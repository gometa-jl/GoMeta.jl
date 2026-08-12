# absorb_meta.jl — the metaLine parser and meta-hierarchy enqueuer (module AbsorbMeta)
#
# IS: the Absorb-phase metaLine parser and condition extractor. It splits a metaLine's meta region
#     into alterant clauses (parseAlt), parses one-word labels (parseOneWordLabel) and balanced
#     '()' argument lists (parseArgs / produceArgsStr), parses each condition body through the
#     closed interpreter's parse_condition into a bounded ConditionAST or a typed refusal
#     (parseConditions), and ENQUEUEs action + condition + args into the per-call queue tensors
#     (absorbMeta — the module's sole export).
#     It enqueues, never applies: applying queued alterants is apply.jl's job.
# DOES: absorbMeta reads the per-call ProcessState through the parent GoMeta.ctx(), hoisted once
#     per call as `st`. Each parsed action name is resolved against st.registry.sorted_alt_actions;
#     the declaration-order plugin index and the action index are written into st.queue.queued at
#     the current meta-hierarchy slot, st.mh.slot_has_accum is set for actions in the registry's
#     accumulate set, and the parsed condition / Symbol-tuple args are stored by value in
#     st.queue.conditions / st.queue.args. Condition text is parsed HERE by the closed
#     interpreter's parse_condition into a bounded ConditionAST (settribute keys, registered
#     alterant-action queries, the documented operators — `,`/`||` OR, `&&` short-circuit AND,
#     eager `&`/`|`, `!` negation — and `()` grouping; nothing else), evaluated only
#     at apply time by the engine itself (README SECURITY; docs/public-api.md §3.2).
# REASONING: everything bound for evaluation must first pass this file's closed grammar and
#     vocabulary (docs/public-api.md §3.4) — and no condition text is ever host-evaluated in a
#     default-configured run (the opt-in `:full_eval_v1` mode stores its marker through the SAME
#     closed intake); out-of-vocabulary or
#     structurally malformed input refuses at absorb with a stable message. Four guarded refusals
#     live here (the fourth, "GoMeta absorb: condition too complex", is the scan-cap guard
#     described below): "GoMeta absorb: slot action capacity" — the pre-increment guard on the queued
#     tensor's per-slot cap, keeping state in-bounds (docs/public-api.md §3.4;
#     tests/unit/slot_overflow_tests.jl); "GoMeta absorb: malformed metaLine" — parseAlt's
#     no-token guard (tests/unit/malformed_meta_tests.jl); "GoMeta absorb: unknown alterant action"
#     — the registry else-branch (the E-01 family). Honest edges: each refusal is an
#     untyped ErrorException raised via error(); their typed conversion is deferred
#     at v0. The condition scanner carries fixed
#     safety counters (at most 29 steps per scan): the outer scan refuses with the stable
#     "condition too complex" message when the cap stops it with non-whitespace input unconsumed
#     (a whitespace-only remainder is semantically complete and stays accepted); per-atom scan
#     exhaustion surfaces as the malformed/unterminated-key refusals.
# PURPOSE: turn each metaLine of a BLS input into queued alterant work the apply phase consumes,
#     refusing malformed or out-of-vocabulary metadata with a stable, documented message.

## AbsorbMeta.jl
module AbsorbMeta

# NamedElements is consumed solely by registry.jl (the package's single NamedElements consumer);
# absorb_meta references no NamedElements symbol by name (`keys(BLS.ComponentSettribute)` is
# `Base.keys`), so no `using ..BLS.NamedElements` import belongs here.
using StaticArrays: SVector
import ..CnS
import ..BLS
# The enqueue (`absorbMeta`) and the condition intake (`parseConditions`, the closed
# interpreter's parse step) read the per-call
# `ProcessState` (registry + slot tensors + queue + cursor) via the parent `GoMeta.ctx()`.
import ..GoMeta: ctx
# v0.2 FLIP: the closed-interpreter intake unit + its refusal type + the flipped condition
# seam type (parseConditions returns ConditionT = ConditionAST; the sentinel is `nothing`).
import ..GoMeta: parse_condition, Diagnostic, ConditionT, resolve_profile, condition_mode_fn
# v0.2 CH-3 step 8: the widened action-argument literal floor (Symbol|String; ints reserved).
import ..GoMeta: AlterantArgT
# v0.2 CH-3 step 9: the context record type (the enqueue-seam applicability + derivation
# reads it) and the Alterants submodule (the Heading validation seam lives there).
import ..GoMeta: MetaContext
import ..Alterants
# v0.2 localOnly delivery: the absorb seam invokes the setter guard (`_invoke_set`,
# apply.jl — included AFTER this file, hence module-qualified late binding), evaluates
# conditions ONCE (`evaluate`, condition.jl), and mints the heading rows
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

## v0.2 FLIP: the retired condition scanner (produceArgsStr + produceConditionStr +
## produceConditionExpr) was carried in a non-shipping reference harness used to derive the
## migration's sealed differential records; harness and scanner were deleted once those
## records were frozen (the development repository archives both). src carries NO code
## evaluation and NO Meta.parse on the condition path. parseConditions (below) now calls
## the closed interpreter's parse_condition as the (text -> value | refusal) unit.


function parseConditions(
    metaSS::SubString{String},
    thisInd::Int ## `thisInd` s.t. `metaSS[thisInd]` == '{'. See `parseAlt(...)`
)::Tuple{Int,ConditionT}

    countOpenBrakets = 1
    indStartArgs = nextind(metaSS, thisInd)
    local conditionAst::ConditionT

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
        local bodyStr = metaSS[indStartArgs:indEndArgs]
        ## v0.2 FLIP: the (text → value | refusal) intake unit is the closed interpreter.
        ## A refusal Diagnostic converts to the SAME statement-abort the old unit threw —
        ## byte-identical messages (sealed-oracle-proven); the typed carrier now exists at
        ## this seam for a later non-throwing routing motion.
        ## the intake MODE is resolved from the per-call profile. `:closed_v1`
        ## (the default, and the only mode reachable without the operator's explicit opt-in
        ## acts) runs the closed interpreter below; a registered opt-in mode runs its own
        ## registered intake under the SAME totality contract (value | typed refusal).
        local st_ = ctx()
        local prof = resolve_profile(st_.config)
        local r = if prof.mode === :closed_v1
            parse_condition(bodyStr; registry = st_.registry, profile = prof)
        else
            condition_mode_fn(prof.mode)(String(bodyStr), st_.registry, prof)
        end
        r isa Diagnostic && throw(ErrorException(r.message))
        conditionAst = r
    else
        error("GoMeta absorb: unterminated condition block — a '{' in a metaLine was never ",
            "closed (", countOpenBrakets, " still open); v0 requires balanced '{}' ",
            "(see docs/public-api.md §3.4)")
    end
    return thisInd, conditionAst
end

# function testParseConditions(
#     metaSS::SubString{String},
#     thisInd::Int
# )
#     (jtThisInd, jtCondExpr) = parseConditions2(metaSS, thisInd)

#     return eval(jtCondExpr)
# end

#########################################################################################
#########################################################################################
## `parseConditions()`:
# function insertGetState(conditionSS::SubString{String})
#     tmpConditionStr = replace(conditionSS, "," => "||")
#     println("\n############ insertGetState() #################")
#     println("\t tmpConditionStr = ", tmpConditionStr)
#     println("\t ncodeunits(tmpConditionStr) = ", ncodeunits(tmpConditionStr), "\n")

#     thisInd::Int = 0
#     indStartKey::Int = 0
#     indEndKey::Int = 0
#     conditionStr::String = " "
#     while (thisInd = nextind(tmpConditionStr, thisInd)) < ncodeunits(tmpConditionStr) + 1
#         # println("tmpConditionStr[", thisInd, "] = ", tmpConditionStr[thisInd])
#         if !isspace(tmpConditionStr[thisInd])

#             if (tmpConditionStr[thisInd] ∈ Char[':', '!']) ||
#                (!ispunct(tmpConditionStr[thisInd]) &&
#                 (tmpConditionStr[thisInd] ∉ Char['|', '&']))

#                 indStartKey = thisInd
#                 while (thisInd = nextind(tmpConditionStr, thisInd)) <
#                       ncodeunits(tmpConditionStr) + 1
#                     # println("tmpConditionStr[", thisInd, "] = ", tmpConditionStr[thisInd])
#                     if isspace(tmpConditionStr[thisInd]) ||
#                        (tmpConditionStr[thisInd] ∈ ['|', '&'])

#                         # indEndKey = prevind(tmpConditionStr, thisInd)
#                         break
#                     elseif ispunct(tmpConditionStr[thisInd])
#                         error("@F: ", basename(@__FILE__), " @L: ", @__LINE__, "\n",
#                             "\t Found `Punctuation` in `conditionStr`! ")
#                     end
#                 end
#                 if indEndKey < indStartKey
#                     println("indEndKey = ", indEndKey)
#                     thisInd = prevind(tmpConditionStr, thisInd)
#                     indEndKey = thisInd
#                     println("indEndKey = ", indEndKey)
#                 end
#                 conditionStr *= " getState(:" *
#                                 tmpConditionStr[indStartKey:indEndKey] * ") "
#             else
#                 conditionStr *= tmpConditionStr[thisInd]
#             end
#         else
#             conditionStr *= tmpConditionStr[thisInd]
#         end
#     end
#     return conditionStr
# end
# jtCondStr = " state1"
# jtCondSS = SubString(jtCondStr)
# insertGetState(jtCondSS)
#########################################################################################
#########################################################################################
# function parseConditions_OLD(
#     metaSS::SubString{String},
#     thisInd::Int
# )::Tuple{Int,Expr}

#     countOpenBrakets = 1
#     indStartArgs = nextind(metaSS, thisInd)
#     local conditionStr::String
#     local thisConditionExpr::Union{Nothing,Expr}
#     local conditionExpr::Union{Nothing,ConditionT}   # v0.2 FLIP: AST or the `nothing` sentinel
#     while (thisInd = nextind(metaSS, thisInd)) < ncodeunits(metaSS) + 1
#         if metaSS[thisInd] == '{'
#             countOpenBrakets += 1
#         elseif metaSS[thisInd] == '}'
#             countOpenBrakets -= 1
#         end
#         countOpenBrakets == 0 ? (
#             println("@L ", @__LINE__, " 0 open {-brakes "); break) : nothing
#     end
#     if countOpenBrakets == 0
#         indEndArgs = prevind(metaSS, thisInd)
#         # println("\ntypeof(Meta.parse(...):")
#         # println("Here: ",
#         #     typeof(Meta.parse(replace(metaSS[indStartArgs:indEndArgs], "," => "||"))),
#         #     "\n")
#         # println("Dump: \n")
#         # println(dump(Meta.parse(replace(metaSS[indStartArgs:indEndArgs], "," => "||"))))
#         conditionStr = insertGetState(metaSS[indStartArgs:indEndArgs])
#         thisConditionExpr = Meta.parse(conditionStr)
#         if thisConditionExpr !== nothing
#             conditionExpr = thisConditionExpr
#         else
#             conditionExpr = Expr(:(nothing))
#         end
#     else
#         error("@F: ", basename(@__FILE__), " @L: ", @__LINE__, "\n",
#             "\t countOpenBrakets = ", countOpenBrakets, " != 0 i.e.: args not complete!")
#     end
#     return thisInd, conditionExpr
# end

#########################################################################################
#########################################################################################
function parseAlt(
    metaSS::SubString{String},
    thisInd::Int,
    firstToken::Bool = false   # v0.2 CH-3 step 9: true only for the FIRST metaComponent
                               # of the meta region — gates the quoted-first recognizer
)::Tuple{SubString{String},Vector{SubString{String}},Union{Nothing,ConditionT},Int}   # v0.2 FLIP

    indStartAlt::Int = 0
    indEndAlt::Int = 0
    argsDone::Bool = false
    conditionsDone::Bool = false
    foundLabel::Bool = false
    headSugar::Bool = false       ## v0.2 CH-3 step 9: this atom is the quoted-first heading
    closedBracket::Bool = false   ## true right after a consumed '()' or '{}' group — gates the glued-token refusal
    local argsSSVec::Vector{SubString{String}}
    local conditionExpr::Union{Nothing,ConditionT}   # v0.2 FLIP: AST or the `nothing` sentinel
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
            ## riding the widened String lane. The span is consumed BEFORE the punctuation
            ## guard (whose general-punctuation refusal was exactly the wall that killed
            ## this form); the state primed below makes the EXISTING walls hold: the
            ## closing '"' takes the closedBracket discipline (glued junk → the existing
            ## glued-token refusal), the token inds are set (the I12 no-token guard never
            ## false-fires), and the inner loop continues normally (a following '{'
            ## attaches conditions; '(' meets the duplicate-argument refusal). A NON-first
            ## quoted token deliberately falls through to the punctuation refusal — its
            ## semantics are RESERVED (unassigned) at v0.2.
            ## Applicability (the MetaContext record) is checked at the enqueue seam.
            if firstToken && !foundLabel && metaSS[thisInd] == '"'
                headSugar = true
                indStartAlt = thisInd
                (thisInd, headingTok) = _consume_heading_span(metaSS, thisInd)
                indEndAlt = thisInd            ## the closing '"'
                argsSSVec = SubString{String}[headingTok]
                argsDone = true
                closedBracket = true
            end
            ## Punctuation at the action-name position refuses loudly — the parser never skips
            ## ahead to the next identifier (a `#~ , discard` form is malformed, not `discard`).
            if _ispunct_valid(metaSS[thisInd]) && !foundLabel && !headSugar
                error("GoMeta absorb: malformed metaLine — unexpected punctuation ",
                    repr(metaSS[thisInd]), " at the action-name position in the meta region ",
                    repr(first(metaSS, 40)),
                    " (v0 expects an action or label token; see docs/public-api.md §3.4)")
            end
            if !_ispunct_valid(metaSS[thisInd]) || foundLabel || headSugar

                headSugar || (indStartAlt = thisInd)
                while (thisInd = nextind(metaSS, thisInd)) < ncodeunits(metaSS) + 1
                    if metaSS[thisInd] == '('
                        if argsDone == false && conditionsDone == false
                            indEndAlt = prevind(metaSS, thisInd)
                            (thisInd, argsSSVec) = parseArgs(metaSS, thisInd)
                            argsDone = true
                            closedBracket = true   ## thisInd sits on the closing ')'
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
                            closedBracket = true   ## thisInd sits on the closing '}'
                        else
                            error("GoMeta absorb: duplicate condition block — a metaLine action ",
                                "may carry '{}' conditions only once (see docs/public-api.md §3.4)")
                        end

                    elseif _isspace_valid(metaSS[thisInd])
                        break
                    elseif closedBracket
                        ## A closing ')' or '}' must be followed by end-of-input or whitespace —
                        ## a glued token (e.g. `hide()junk`, `hide{isCode}show`) refuses loudly,
                        ## never a silent swallow.
                        error("GoMeta absorb: malformed metaLine — glued token after a closing ",
                            "')' or '}' in the meta region ", repr(first(metaSS, 40)),
                            " (v0 requires end-of-input or whitespace after a closing ')' or '}'; ",
                            "see docs/public-api.md §3.4)")
                    end
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
        ## the condition-intake boundary (parse_condition) can never return it — an authored
        ## `{}` either yields a real ConditionAST or the stable refusal. v0.2 FLIP: the
        ## sentinel is `nothing` (the queue's condition matrix is Union{Nothing,ConditionT}).
        conditionExpr = nothing
    end
    ## Guarded refusal (docs/public-api.md §3.4): a meta region yielding NO
    ## alterant token (e.g. `#~ ,`, `#~3 (`) would otherwise reach `metaSS[0:0]` and raise a
    ## BoundsError. Valid metaLines (incl. the inert `#~!`) never reach this return with indices
    ## at 0 — the guard refuses exactly that malformed class.
    if indStartAlt == 0 || indEndAlt == 0
        error("GoMeta absorb: malformed metaLine — no alterant token found in the meta region ",
            repr(first(metaSS, 40)),
            " (v0 expects an action or label token; guarded refusal, ",
            "see docs/public-api.md §3.4)")
    end
    ## The sugar's action NAME is SYNTHETIC (the lowering target — the `head` action),
    ## never a metaSS span; the token inds above stay the SPAN's
    ## (the I12 guard + the end-of-scan arithmetic key on them).
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
    local conditionExpr::Union{Nothing,ConditionT}   # v0.2 FLIP: AST or the `nothing` sentinel
    local crntAltActionIdx::Int8
    local altActionOnRow::Int8
    firstTok::Bool = true   # the quoted-first recognizer fires only for the FIRST
                            # metaComponent of the meta region (hd-2/hd-3)
    ## localOnly delivery (the third inheritance mode): ONE pending
    ## Heading store per meta region — every localOnly action on this metaLine sets
    ## into the SAME store (preserving the entry order the per-region fold's
    ## injectivity ordinals key on), and the region flushes ONCE after the component
    ## loop (capture_heading! — keyed to the metaLine's own occurrence handle).
    local pendingHeading::Union{Nothing,Alterants.Heading} = nothing
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
                ## materialization, the ONE condition evaluation, the setter guard)
                ## lives in `_absorb_local_only!` below.
                isLocalOnly = st.registry.plugins[
                    st.registry.action_to_plugin[crntAltActionIdx]].setMode === :localOnly
                if isLocalOnly
                    pendingHeading = _absorb_local_only!(
                        st, metaSS, Symbol(altActionName), argsSSVec, conditionExpr,
                        pendingHeading)
                else
                ## Guarded refusal (docs/public-api.md §3.4): the queue tensors hold size(queued,2) actions per MH
                ## slot; the guard fires BEFORE the counter increment so state stays in-bounds for every
                ## 1:count reader. Slot-honest wording (also reachable from the userMH feed — no input
                ## line exists there). Capacity growth is deferred; at or below the cap behavior is byte-exact.
                if st.mh.count_actions_per_slot[crntSlot] >= size(st.queue.queued, 2)
                    error("GoMeta absorb: slot action capacity (",
                        size(st.queue.queued, 2), ") exceeded at meta-hierarchy slot ", crntSlot,
                        " — at most ", size(st.queue.queued, 2),
                        " alterant actions may accumulate in one slot at v0 (guarded refusal; ",
                        "see docs/public-api.md §3.4)")
                end
                altActionOnRow = (st.mh.count_actions_per_slot[crntSlot] += 1)
                st.queue.queued[1,
                    altActionOnRow, crntSlot] = st.registry.action_to_plugin[crntAltActionIdx]
                st.queue.queued[2,
                    altActionOnRow, crntSlot] = crntAltActionIdx

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
    ## v0.2 localOnly delivery — the ONCE-per-region FLUSH: the pending Heading store
    ## (every condition-passing localOnly action of this meta region, in source order)
    ## mints its rows keyed to the region's OWN identity + content (capture_heading!):
    ## on the document surface that is the metaLine's occurrence handle + its verbatim
    ## bytes; on the userMH feed it is the minted USER-CONTEXT handle + the profile's
    ## verbatim bytes (the user-context build — the former no-row fate is REVERSED;
    ## witnessed). Delivery is COMPLETE here: nothing was queued, so the apply plane
    ## never revisits headings.
    if pendingHeading !== nothing
        GMX.capture_heading!(st, pendingHeading)
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
##   lineMHIdx−1, the documented constant). The MetaContext record stays PURE from
##   parse; the normalization lives at THIS one materialization seam. Materialized as
##   a floor-legal Symbol (`Symbol("2")` — the literal floor reserves ints);
## - THE ONE CONDITION EVALUATION (condition-evaluated-once-at-the-heading): a
##   SETTRIBUTE condition gates the HEADING at its own context (the metaLine's
##   snapshot) — ON THE DOCUMENT SURFACE a false condition means no row, no refusal
##   (pinned); ON THE FEED SURFACE a conditioned head refuses BEFORE evaluation (the
##   user-context build's reserved wall below: the feed carries no evaluable settribute
##   state — the pre-walk snapshot describes no component). A QUERY atom
##   (alterant-state query) REFUSES here at v0.2 (at absorb time `st.working` holds the PREVIOUS apply's residue, so a query
##   would gate the heading on unrelated preceding content — the order-dependent
##   wrong-verdict class; the query form is RESERVED until a build can supply the
##   heading's own lineage context — refusal→semantics is a compatible widening).
##   An opt-in FullEvalCondition marker on a heading is RESERVED TOO (the second
##   wall arm below);
## - the setter guard (`_invoke_set`) supplies the SAME typed arity/type refusals as
##   the apply plane ("invalid arguments" — the I15 seam), so canonical-call refusal
##   classes are surface-identical to the queued era.
## Registry-driven WHERE THE REGISTRY CAN DRIVE IT: the DIVERT (mode),
## the constructor, the setter, the String-slot capability
## (`accepts_string_slot`), and the VALIDATION seam (the spec's `validate` slot)
## come from the registry record. STILL Heading/grammar-specific in this
## function's own bytes: the arity-keyed deriving-form APPLICABILITY refusal and
## the ladder−1 LEVEL MATERIALIZATION (the record's applicability/phase fields
## DOCUMENT them; their runtime consult is deferred), plus the
## wall message's naming of the head action. The store type and
## `capture_heading!` remain Heading-typed — a custom registry declaring a
## NON-Heading `:localOnly` plugin is OUTSIDE the v0.2 envelope (the registry
## parameter is reserved/default-only, the established posture).
function _absorb_local_only!(
    st, metaSS::SubString{String}, actionName::Symbol,
    argsSSVec::Vector{SubString{String}},
    conditionExpr::Union{Nothing,ConditionT},
    pendingHeading
)
    plug = st.registry.plugins[
        st.registry.action_to_plugin[st.registry.action_index[actionName]]]
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
        # the accepting slot rides to the typed arity/type refusals at the setter
        # guard — never the wrong-class validation message)
        if spec.validate !== nothing && argsTup[spec.accepts_string_slot] isa String
            spec.validate(argsTup[spec.accepts_string_slot])
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
    ## THE QUERY-ATOM WALL (see the function header): a heading condition may test
    ## settribute predicates only at v0.2.
    if conditionExpr isa GMX.ConditionAST && GMX.has_query_atom(conditionExpr)
        error("GoMeta absorb: alterant-state query in a heading condition — a ",
            "heading condition may test only settribute predicates at v0.2 (the ",
            "heading applies at its own line, where no alterant state exists yet; ",
            "the query form is reserved) in the meta region ",
            repr(first(metaSS, 40)), " (see docs/public-api.md §3.4)")
    end
    ## THE FULL-EVAL ARM of the same wall (external-lens MEDIUM at the fresh-eyes
    ## set): an opt-in FULL-EVAL heading condition would EXECUTE at the absorb seam —
    ## a context the executing rung's contract predates (its state reads would see
    ## the same previous-apply residue the query reservation exists for; "opt-in
    ## execution does not imply consent to this changed context"). The heading
    ## surface postdates the dual-mode contract, so its intersection with the
    ## executing rung never had a settled semantic — RESERVED at v0.2, the same
    ## conservative arm as the query atoms. Every QUEUED action's conditions keep
    ## the opt-in mode's full contracted behavior. (The marker only mints for text the
    ## safer rungs cannot lower — a settribute-only heading condition under the
    ## opt-in profile still arrives as ConditionAST and works.)
    if conditionExpr isa GMX.FullEvalCondition
        error("GoMeta absorb: a full-eval condition on a heading — the opt-in ",
            "executing mode's heading conditions are reserved at v0.2 (the heading ",
            "evaluates at the absorb seam, a context the opt-in contract predates) ",
            "in the meta region ", repr(first(metaSS, 40)),
            " (see docs/public-api.md §3.4)")
    end
    ## The user-context build's reserved wall (ratified standing; seated AFTER the query-atom and
    ## full-eval walls, BEFORE evaluation; fires only on the feed surface): a CONDITIONED
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
    local _verdict = conditionExpr === nothing ? nothing : GMX.evaluate(st, conditionExpr)
    if conditionExpr === nothing || _verdict
        store = pendingHeading === nothing ? plug.altConstructor() : pendingHeading
        GMX._invoke_set(st.registry, plug.setAltInstance, store, actionName, argsTup)
        return store
    end
    return pendingHeading
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
## coerced, so numeric args keep their byte-exact pre-widening fates at the `_invoke_set`
## arg seam. No metaLine grammar accepts a String at this step — a String kind meets the
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