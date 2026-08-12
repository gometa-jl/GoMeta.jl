# src/condition.jl — the closed condition interpreter: bounded intake (text → AST | typed
# refusal), the condition algebra, the canonical printer, and the evaluator.
#
# IS:  the no-eval replacement substrate for the engine's condition path. The intake SCAN is a
#      FAITHFUL transliteration of the engine's as-built condition scanner — the same two scan
#      caps (outer 29-step wall · inner 29-step atom wall, both read from the grammar
#      profile), the same step accounting (one step per operator char, per whitespace char, or
#      per WHOLE atom), the same operator vocabulary (',' lowers to short-circuit OR; '(' ')'
#      '!' '&' '|' verbatim, with source-adjacent doubles '&&'/'||' merging exactly where the
#      engine's built strings would), the same label arm (':' introduces a single one-word
#      label key), the same argument mechanics — EXCEPT three engine corners RETIRED by
#      recorded owner decisions:
#      · the ONE-CHARACTER DROP — a single-character parenthesized argument was silently
#        discarded; it now flows through the declared grammar and refuses unless
#        whitespace-only;
#      · K5, the UNTERMINATED-LABEL TRUNCATION — a label word EXACTLY at the inner scan
#        wall was silently rewritten to the zero-argument label query (TRUE against any
#        present label store, FALSE with the store absent, EITHER WAY a verdict the author
#        never wrote; those fates sit in the sealed retirement cells) — the wall now
#        REFUSES. The SECOND route to the same guard — a condition ENDING inside an atom
#        whose FINAL character is multibyte — has a three-generation history, kept whole:
#        (1) the OLD engine bytes CRASHED raw there (BoundsError one index past the final
#        multibyte character — a totality break; byte-verified at the K6 motion, correcting
#        an earlier revision that claimed the silent mint on both routes — the pre-cure
#        mint there was the TRANSLITERATION's own, its guarded loop exiting cleanly where
#        the old bytes crashed); (2) the transliteration's interim byte-count end test
#        (`nCodeUnitsPlus1 - 1`) could never equal a char-walker index on a multibyte
#        final, so the scan ran to the wall and refused WRONG-CLASS ("unterminated") on
#        flush shapes like `{:é}`/`{:🔥}`; (3) the Unicode-correctness cure replaced
#        it with the char end predicate `lastCharInd =
#        lastindex(text)` — end-of-text is now just another delimiter, flush ≡ spaced,
#        and the atom takes its ORDINARY vocabulary fate (store-unset → accept/silently-
#        false query; store-present → apply's unknown-label refusal). The 44 sealed
#        trigger-2 cells ride the sealed-oracle conversion ledger, consciously;
#      · K6, the LABEL-PAREN DISCARD — a label key immediately followed by a parenthesized
#        argument list silently DISCARDED the authored word, so `:abc(:label1)` parsed as
#        `:(:label1)` and a DIFFERENT label than the author named decided the verdict, and
#        its WORST sub-form `:word()` routed into the zero-argument query (TRUE vacuously
#        against a PRESENT label store, FALSE against an absent one — either way the label
#        the author NAMED was never checked); the same wrong-verdict family as K5,
#        surfaced by the K5 retirement's review round, retired at the stage-2 close — a
#        WORDED label key carrying an argument list now meets a typed grammar refusal
#        NAMING the word, while the WORD-LESS form `:(...)` (no authored word to lose) is
#        untouched.
#      All three retirements are pinned by documenting tests, and the
#      transition-time comparison tools carry the affected cells as deliberate, enumerated
#      differences — the frozen reference is never edited. TWO corners REMAIN deliberately
#      replicated: the settribute pending-argument LEAK (K3 — NOTE, recorded OPEN: the
#      full-parse opt-in mode DROPS these pended arguments instead of leaking them, a
#      divergence class on closed-accepted text, verdict-inert on the current registry;
#      see the extension file's settribute-call arm) and the END-OF-BODY parenthesis
#      fold (K4). (Adjacent engine quirk, also
#      replicated: the label arm's flag stays set after a label-paren atom — reachable
#      since the K6 retirement only through the WORD-LESS `:(...)` form — and the NEXT
#      atom's fate depends on its SHAPE — a follower that RESOLVES normally meets the
#      malformed-key refusal (the stale span check), one that leaves the inner loop
#      unresolved meets the unterminated-key refusal (the stale indices), and a LABEL
#      follower re-equalises the indices and is ACCEPTED unless it is itself unterminated
#      (the label guard refuses it) or itself WORDED-with-parens (the K6 refusal, which is
#      the atom's own fate, not a stale-flag fate) — four stale-flag sub-shapes, all
#      pinned.)
#      The same refusal classes ride the engine's stable message texts.
# DOES: (1) `parse_condition(text; registry, profile)` — TOTAL + BOUNDED: every input returns
#      EITHER a `ConditionAST` OR a typed refusal `Diagnostic` — it never throws and never
#      hangs, and every cap REFUSES — never truncates, never silently accepts a partial
#      scan (unqualified again since the owner retired the K5 truncation). Touches NO
#      per-call state and NO dynamic scope.
#      (2) the algebra: `CondStateAtom` (settribute read) · `CondQueryAtom` (alterant query;
#      Symbol literal args; a non-literal argument text is carried as `CondRawArg` — accepted
#      at intake exactly like the engine accepts it, refused at evaluation where the engine's
#      eval crashed raw) · `CondNot` · `CondAnd`/`CondOr` (eager '&'/'|') · `CondScAnd`/
#      `CondScOr` (short-circuit '&&' and '||'/','), parsed by precedence read from the
#      profile's DATA table. (3) `evaluate(st, ast) -> Bool` — walks the AST against the
#      per-call state passed AS AN ARGUMENT (no ambient lookup): a settribute atom reads the
#      snapshot; a query atom keeps unset ⇒ FALSE (membership on
#      an absent store is false — no tri-state), and dispatches the registered query exactly
#      as the engine's query seam does (the unknown-label whitelist refusal included); the
#      eager/short-circuit operator split reproduces the engine's query-evaluation COUNTS.
#      (4) `print_condition(ast)` — the canonical source-vocabulary form; printing and
#      re-parsing yields the same AST (round-trip law).
# REASONING: the interpreter must be alpha-equivalent to the engine's evaluated condition
#      strings over the WHOLE acceptance envelope — including its refusal walls and its known
#      corners — so equivalence is provable input-by-input; improvements are conscious,
#      separate motions, never side effects of the swap.
# PURPOSE: conditions become bounded data evaluation. In the DEFAULT intake no code
#      evaluation is reachable from condition text. That statement is scoped deliberately:
#      an operator may explicitly opt in to a mode that evaluates (two explicit acts, neither
#      reachable from document content) — the guarantee is about the default every document
#      gets, not an absolute property of the package.

# The scanner's whitespace predicate — the same valid-and-space test the engine's scanner uses
# (defined locally: the engine's copy lives in a submodule this file must not depend on).
_cond_isspace(c::AbstractChar) = isvalid(c) && isspace(c)

# TOTALITY GUARD (review-found, byte-confirmed): `Base.isidentifier` converts each character
# to a code point and THROWS `InvalidCharError` on malformed UTF-8 — so calling it on raw
# argument text let a malformed byte escape the intake as a raw exception, breaking the
# never-throws contract. Every identifier test in this file goes through here: invalid input
# is simply NOT an identifier, and meets the ordinary typed refusal.
_cond_isidentifier(s::AbstractString) = all(isvalid, s) && Base.isidentifier(s)

# ── the algebra (node family under ConditionAST.root) ───────────────────────────────────────────

"A settribute-state atom: reads one component-state flag from the per-call snapshot."
struct CondStateAtom
    key::Symbol
end

"A raw (non-Symbol-literal) query-argument text, accepted at intake, refused at evaluation."
struct CondRawArg
    text::String
end

"An alterant-query atom: the plugin index + action name + literal arguments."
struct CondQueryAtom
    plugin::Int8
    action::Symbol
    args::Vector{Any}   # Symbol | CondRawArg
end

"Prefix negation."
struct CondNot
    x::Any
end

"Eager AND ('&'): both sides always evaluated."
struct CondAnd
    a::Any
    b::Any
end

"Eager OR ('|'): both sides always evaluated."
struct CondOr
    a::Any
    b::Any
end

"Short-circuit AND ('&&')."
struct CondScAnd
    a::Any
    b::Any
end

"Short-circuit OR ('||' and the ','-lowering)."
struct CondScOr
    a::Any
    b::Any
end

# ── the typed refusal mints (never thrown from parse_condition — returned) ──────────────────────

_cond_refusal(code::Symbol, msg::String, context = nothing) =
    Diagnostic(code, :error, msg, context)

# Internal scan-abort carrier: the scan layer signals a refusal by throwing THIS one type;
# parse_condition catches it at its boundary and RETURNS the payload (total, never throws).
struct _CondRefusalSignal <: Exception
    d::Diagnostic
end
_refuse(code::Symbol, msg::String, context = nothing) =
    throw(_CondRefusalSignal(_cond_refusal(code, msg, context)))

# ── the token layer ──────────────────────────────────────────────────────────────────────────────

struct _CondTok
    kind::Symbol      # :atom | :op
    node::Any         # the atom node (kind = :atom)
    op::Char          # '(' ')' '!' '&' '|' ',' (kind = :op)
    pos::Int          # source byte index (adjacency merges for '&&'/'||')
end
_atom_tok(node, pos) = _CondTok(:atom, node, '\0', pos)
_op_tok(c, pos)      = _CondTok(:op, nothing, c, pos)

# ── the faithful argument scan (the engine's produceArgsStr mechanics, token-emitting) ──────────
# Returns (thisInd at the closing ')', argtext) — argtext == "" only for the truly empty `()`.
# The engine's one-character drop (a strict `<` here silently discarded a single-character
# argument, so `cell(x)` became `cell()`) is RETIRED by a recorded owner decision: single-
# character argument text is preserved and flows through the DECLARED grammar like all argtext
# (whitespace-only accepts as zero-argument; anything else meets ERR_CONDITION_ARG_DOMAIN).
# Balanced-parens walk; unterminated refuses.
function _scan_args(text::String, thisInd::Int)
    countOpenBrakets = 1
    indStartArgs = nextind(text, thisInd)
    local indEndArgs::Int
    while (thisInd = nextind(text, thisInd)) < ncodeunits(text) + 1
        if text[thisInd] == '('
            countOpenBrakets += 1
        elseif text[thisInd] == ')'
            countOpenBrakets -= 1
        end
        countOpenBrakets == 0 ? break : nothing
    end
    countOpenBrakets == 0 ||
        _refuse(:ERR_CONDITION_PARSE,
            "GoMeta absorb: unterminated argument list — a '(' in a metaLine was never closed " *
            "(" * string(countOpenBrakets) * " still open); v0 requires balanced '()' " *
            "(see docs/public-api.md §3.4)")
    indEndArgs = prevind(text, thisInd)
    argtext = indStartArgs <= indEndArgs ? text[indStartArgs:indEndArgs] : ""
    return thisInd, argtext
end

# ── the dual-mode OPT-IN seams (DATA + dispatch only; every opt-in mode's parser and
# evaluator lives OUTSIDE this package, in extensions/condition_modes_opt_in.jl, so `src/`
# never gains a code-evaluation path and its purity/no-eval gates stay armed for everyone).

"""
    cond_atom_for(key::Symbol, registry) -> CondStateAtom | CondQueryAtom | Diagnostic

Build ONE closed atom from a bare vocabulary key, applying the same closed-vocabulary rule
the scanner applies (settribute state-ref | registered alterant action | typed refusal).
Exposed so an opt-in mode maps its own parse result onto the SAME closed algebra — an
opt-in widens which TEXT is accepted, never which atoms exist or what evaluation may do.
"""
function cond_atom_for(key::Symbol, registry::AlterantRegistry)
    key ∈ keys(BLS.ComponentSettribute) && return CondStateAtom(key)
    insorted(key, registry.sorted_alt_actions) &&
        return CondQueryAtom(registry.action_to_plugin[registry.action_index[key]], key, Any[])
    return _cond_refusal(:ERR_UNKNOWN_CONDITION_KEY,
        "GoMeta absorb: unknown condition key " * repr(first(String(key), 40)) *
        " — neither a component state-ref nor a registered alterant action; " *
        "v0's closed condition vocabulary (see docs/public-api.md §3.4)")
end

"""
    cond_query_for(action::Symbol, args::Vector, registry) -> CondQueryAtom | Diagnostic

Build ONE closed query atom with literal arguments (the same closed vocabulary rule).
"""
function cond_query_for(action::Symbol, args::Vector{Any}, registry::AlterantRegistry)
    insorted(action, registry.sorted_alt_actions) ||
        return _cond_refusal(:ERR_UNKNOWN_CONDITION_KEY,
            "GoMeta absorb: unknown condition key " * repr(first(String(action), 40)) *
            " — neither a component state-ref nor a registered alterant action; " *
            "v0's closed condition vocabulary (see docs/public-api.md §3.4)")
    return CondQueryAtom(registry.action_to_plugin[registry.action_index[action]], action, args)
end


# ═══ THE ARGUMENT DOMAIN — DECLARED, not predicted ══════════════════════════════════════════
#
# A query argument is a LABEL LITERAL. That is the whole grammar:
#
#     argtext := WS* | piece ("," piece)* ["," WS*]
#     piece   := WS* ":" ident WS*        where ident is a valid identifier
#
# Everything else meets ONE typed refusal (ERR_CONDITION_ARG_DOMAIN). The two WS* forms are
# stated explicitly because they are REAL and were previously under-declared (review-found):
# an all-whitespace argument text is a zero-argument query, and a trailing comma may be
# followed by whitespace. Since the one-character drop was retired, EVERY
# argument text reaches this grammar — including single characters, so `cell(x)`, `cell(7)`,
# `cell(:)` and `cell(,)` now meet the typed refusal instead of silently becoming
# zero-argument queries.
#
# WHY DECLARED RATHER THAN REPLICATED. The retired implementation had no argument grammar: it
# spliced the text into a generated call and let the HOST decide, so its acceptance test was
# accidentally "does this parse — and LOWER — as Julia?". Lowering EXPANDS MACROS, so that
# engine could EXECUTE code at intake on a condition it never evaluated (verified: a macro
# argument lowers with the macro already expanded). An exact NON-EXECUTING predictor of that
# envelope therefore cannot exist even in principle. Four adversarial review rounds each found
# fresh leaks in successive predictors — reserved words, the whole narrowing direction,
# quote/bracket-blind splitting, group interiors, unary operators, multi-dot numerics,
# identifier classes — because the target was unreachable, not because the attempts were poor.
# The envelope is therefore DECLARED (an owner decision; the narrowing is deliberate and
# recorded), and the boundary chosen is the one that is FINITE: `Base.isidentifier`, the same
# predicate the label arm already uses. One identifier law in this file, not two.
#
# WHAT THE NARROWING ACTUALLY COSTS. When the domain was first declared, only MULTI-CHARACTER
# non-label arguments changed (the then-replicated one-character drop still silently accepted
# `cell(7)` and `cell(x)` as zero-argument atoms). A second recorded decision then retired
# that drop, so 0/1-char non-label arguments now refuse too — deliberately. Anything
# richer is served by the opt-in modes, where the full host grammar is accepted (and, one
# rung further, evaluated) — so the choice was never removed from the user, only moved behind
# an explicit act.
#
# THE SPLIT LEMMA (why no quote/depth state is needed, and why totality is STRUCTURAL here):
# splitting on ',' UNCONDITIONALLY is accept-set-invariant — the ACCEPT SETS of the naive and
# the delimiter-aware splits are equal.
#
# The argument is about the WHOLE argument text, not about individual pieces; a per-piece
# version of it is FALSE and was corrected here after review. Counterexample to the per-piece
# claim: for the argument text `"a,:b,c"` the naive split yields `"a` / `:b` / `c"` while an
# aware split yields the single piece `"a,:b,c"` — the middle piece `:b` moved, is
# label-shaped, and contains no quote or bracket at all. What saves invariance is that EVERY
# piece must pass: any quote or bracket that could move a boundary is itself somewhere in the
# text, so it lands either in a SIBLING piece (which then fails) or inside the merged piece
# (which then fails) — so both splits reject the whole argument text either way. Acceptance
# requires every piece to be `:ident`, and no `:ident` contains a comma, quote or bracket, so
# on the ACCEPTED side the two splits coincide exactly.
#
# Consequence: this function needs no scanner, no recursion and no lookahead — it cannot hang
# and cannot overflow, by construction rather than by fuzzing.
function _parse_argtext(argtext::String, body::String)
    args = Any[]
    isempty(argtext) && return args
    pieces = split(argtext, ',')
    for (k, piece) in enumerate(pieces)
        p = String(strip(_cond_isspace, piece))
        if isempty(p)
            # a single TRAILING empty piece is the legal `cell(:a,)` form; empty anywhere
            # else (leading, interior, doubled) is outside the grammar
            k == length(pieces) ? continue : _refuse_arg_domain(body)
        end
        startswith(p, ':') || _refuse_arg_domain(body)
        tail = SubString(p, nextind(p, firstindex(p)))
        _cond_isidentifier(tail) || _refuse_arg_domain(body)
        push!(args, Symbol(tail))
    end
    return args
end

_refuse_arg_domain(body::String) =
    _refuse(:ERR_CONDITION_ARG_DOMAIN,
        "GoMeta absorb: unsupported condition argument — in " * repr(first(body, 40)) *
        " a query argument must be a ':'-prefixed one-word label (e.g. `cell(:a)` or " *
        "`cell(:a, :b)`); richer argument syntax is available through the opt-in intake " *
        "modes (see docs/public-api.md §3.2)")


# ── the faithful condition scan (the engine's scanner mechanics, token-emitting) ────────────────
function _scan_condition(text::String, registry::AlterantRegistry, profile::GrammarProfile)
    ncodeunits(text) <= profile.max_condition_bytes ||
        _refuse(:ERR_CONDITION_CAP,
            "GoMeta absorb: condition too large — the condition body exceeds the profile's " *
            "raw-byte wall (" * string(profile.max_condition_bytes) * " bytes); shorten or " *
            "split the condition (see docs/public-api.md §3.4)",
            profile.max_condition_bytes)
    toks = _CondTok[]
    nCodeUnitsPlus1::Int = ncodeunits(text) + 1
    lastCharInd::Int = lastindex(text)   # start index of the FINAL character — equals
                                         # ncodeunits(text) ONLY when that character is
                                         # single-byte; the char-walker end-of-text predicate
    thisInd::Int = 0
    indStartKey::Int = 0
    indEndKey::Int = 0
    pending_args = Any[]          # the argsStr state machine (incl. the replicated leak)
    have_pending::Bool = false
    inLabel::Bool = false
    safetyCount1 = 1
    while (thisInd = nextind(text, thisInd)) < nCodeUnitsPlus1 &&
        safetyCount1 < profile.outer_scan_cap + 1

        safetyCount1 += 1

        if !_cond_isspace(text[thisInd])
            if text[thisInd] ∈ (',', '(', ')', '!', '&', '|')
                push!(toks, _op_tok(text[thisInd], thisInd))
                continue
            else
                indStartKey = thisInd
                atom_is_label = text[thisInd] == ':'    # THIS atom's own label-ness — the
                                                        # guard below keys on it, never on
                                                        # the (engine-faithful) stale flag
                if atom_is_label
                    inLabel = true
                    indEndKey = indStartKey
                end
                safetyCount2 = 1
                inner_resolved = false      # set on BOTH break arms; false ⇒ wall exhausted
                while thisInd < nCodeUnitsPlus1 && safetyCount2 < profile.inner_scan_cap + 1
                    safetyCount2 += 1
                    if _cond_isspace(text[thisInd]) ||
                       text[thisInd] ∈ ('|', '&', ',', ')') ||
                       thisInd == lastCharInd

                        if thisInd != lastCharInd || _cond_isspace(text[thisInd])
                            thisInd = prevind(text, thisInd)
                        end
                        if inLabel
                            indStartKey == indEndKey ||
                                _refuse(:ERR_CONDITION_PARSE,
                                    "GoMeta absorb: malformed condition key — a ':' inside a " *
                                    "condition must introduce a single one-word label key " *
                                    "(key span " * string(indStartKey) * ":" * string(indEndKey) *
                                    "); v0's condition grammar (see docs/public-api.md §3.4)")
                            word = text[nextind(text, indEndKey):thisInd]
                            _cond_isidentifier(word) ||
                                _refuse(:ERR_CONDITION_PARSE,
                                    "GoMeta absorb: unparsable condition — the condition " *
                                    repr(first(text, 40)) * " does not form a complete v0 " *
                                    "condition expression (see docs/public-api.md §3.4)")
                            pending_args = Any[Symbol(word)]
                            have_pending = true
                            inLabel = false
                        else
                            indEndKey = thisInd
                        end
                        inner_resolved = true
                        break
                    elseif text[thisInd] == '('
                        if !inLabel
                            indEndKey = prevind(text, thisInd)
                        end
                        indOpenParen = thisInd
                        (thisInd, argtext) = _scan_args(text, thisInd)
                        pending_args = _parse_argtext(argtext, text)
                        have_pending = true
                        # RETIRED DEFECT K6 (a recorded owner decision, the stage-2 close):
                        # a LABEL key immediately followed by a parenthesized argument list
                        # used to DISCARD the authored word — the label arm pre-sets the key
                        # span to the bare ':', this arm never widens it for a label atom,
                        # so `:abc(:label1)` minted as `:(:label1)` and `:word()` as the
                        # zero-argument query. A WORDED label key with an argument list now
                        # refuses, NAMING the word the discard erased. The guard keys on
                        # THIS atom's own label-ness (never the stale flag) AND a NONEMPTY
                        # word: the word-less `:(...)` form (no authored word to lose) is
                        # NOT retired. PRECEDENCE, stated at both grains (an external lens
                        # caught the one-grain wording as an overclaim): WITHIN this atom,
                        # the argument refusals (unterminated list, arg-domain) still fire
                        # first, so those forms keep their refusal class; ACROSS the body,
                        # this refusal now fires AT the worded atom and so PREEMPTS
                        # whatever later refusal the pre-cure scan produced for a composite
                        # body (follower stale-span/stale-index/label-guard — message, and
                        # in one pinned shape the code, differ). Verdicts changed ONLY for
                        # the silent accepts; zero sealed cells carry either family
                        # (verified at the motion).
                        if atom_is_label && prevind(text, indOpenParen) > indStartKey
                            _refuse(:ERR_CONDITION_PARSE,
                                "GoMeta absorb: label key with an argument list — a worded " *
                                "':'-introduced label key takes no parenthesized argument " *
                                "list; the intake refuses rather than silently discarding " *
                                "the authored word " *
                                repr(first(text[nextind(text, indStartKey):prevind(text, indOpenParen)], 40)) *
                                " (see docs/public-api.md §3.4)")
                        end
                        # inLabel is deliberately NOT cleared here — the engine keeps the
                        # stale flag, and clearing it (tried once, review-caught) ACCEPTED
                        # text the engine refuses. The follower's fate is shape-dependent
                        # and pinned (see the K-register note and the stale-flag pins,
                        # anchored on the word-less `:(...)` setup since the K6 retirement);
                        # the unterminated-label guard below is scoped PER ATOM instead.
                        inner_resolved = true
                        break
                    end
                    thisInd = nextind(text, thisInd)
                end
                # RETIRED DEFECT K5 (a recorded owner decision): an UNTERMINATED label key
                # used to be silently rewritten to the zero-argument label query (the
                # end-of-key guard below compares two indices the label arm pre-set EQUAL,
                # so it could not fire). TWO triggers land here, both refused with one
                # truthful message: (1) the label runs to the inner scan wall — there the
                # OLD bytes minted the silent query (TRUE against a present label store,
                # FALSE with it absent, either way a verdict the author never wrote; the
                # sealed retirement cells hold both fates); (2) the condition ENDS inside
                # the label with a MULTIBYTE final character, which the single-byte
                # end-of-text arm above cannot terminate — there the OLD bytes CRASHED raw
                # (BoundsError, one index past the final multibyte character; byte-verified
                # at the K6 motion's execution, correcting an earlier revision of this note
                # that claimed the
                # silent mint on this route too — that mint was the pre-cure
                # transliteration's own, whose guarded loop exits cleanly where the old
                # bytes crashed). The trigger-2 form is witnessed in the sealed populations
                # by supplement-2's inner/lbl_mb_end family (ridden in with the K6 motion,
                # class- and membership-pinned there).
                atom_is_label && !inner_resolved &&
                    _refuse(:ERR_CONDITION_CAP,
                        "GoMeta absorb: unterminated label key — a ':'-introduced key ran " *
                        "to the inner scan wall (" * string(profile.inner_scan_cap) *
                        " scan steps) or to the end of the condition without terminating; " *
                        "the intake refuses rather than silently minting the zero-argument " *
                        "label query (see docs/public-api.md §3.4)",
                        profile.inner_scan_cap)
                indEndKey < indStartKey &&
                    _refuse(:ERR_CONDITION_PARSE,
                        "GoMeta absorb: unterminated condition key — the end of a condition " *
                        "key was not found (key span " * string(indStartKey) * ":" *
                        string(indEndKey) * "); v0's condition grammar " *
                        "(see docs/public-api.md §3.4)")
                keySymbol = Symbol(text[indStartKey:indEndKey])
                if keySymbol ∈ keys(BLS.ComponentSettribute)
                    # DELIBERATE REPLICATION: pending arguments are NOT consumed here — a
                    # settribute atom's parenthesized args leak into the next parenless query
                    # atom, exactly as the engine's scanner leaves its argument buffer.
                    push!(toks, _atom_tok(CondStateAtom(keySymbol), indStartKey))
                elseif insorted(keySymbol, registry.sorted_alt_actions)
                    plugin = registry.action_to_plugin[registry.action_index[keySymbol]]
                    args = have_pending ? pending_args : Any[]
                    pending_args = Any[]
                    have_pending = false
                    push!(toks, _atom_tok(CondQueryAtom(plugin, keySymbol, args), indStartKey))
                else
                    _refuse(:ERR_UNKNOWN_CONDITION_KEY,
                        "GoMeta absorb: unknown condition key " *
                        repr(first(String(text[indStartKey:indEndKey]), 40)) *
                        " — neither a component state-ref nor a registered alterant action; " *
                        "v0's closed condition vocabulary (see docs/public-api.md §3.4)")
                end
            end
        end
    end
    if thisInd < nCodeUnitsPlus1 && !all(_cond_isspace, SubString(text, thisInd))
        _refuse(:ERR_CONDITION_CAP,
            "GoMeta absorb: condition too complex — the condition tail " *
            repr(first(String(strip(_cond_isspace, SubString(text, thisInd))), 40)) *
            " was not scanned (v0's condition scanner stops after " *
            string(profile.outer_scan_cap) * " steps; one step is one operator, one space, " *
            "or one whole atom); shorten or split the condition " *
            "(see docs/public-api.md §3.4)",
            profile.outer_scan_cap)
    end
    return toks
end

# ── the parser (precedence read from the profile's DATA; grouping; '&&'/'||' adjacency merge) ───

mutable struct _CondParser
    toks::Vector{_CondTok}
    i::Int
    depth::Int
    profile::GrammarProfile
    body::String
end

_unparsable(p::_CondParser) =
    _refuse(:ERR_CONDITION_PARSE,
        "GoMeta absorb: unparsable condition — the condition " * repr(first(p.body, 40)) *
        " does not form a complete v0 condition expression (see docs/public-api.md §3.4)")

_peek(p::_CondParser) = p.i <= length(p.toks) ? p.toks[p.i] : nothing

# Merge check: two identical op chars at source-adjacent byte positions form '&&'/'||' —
# exactly where the engine's built string would carry the doubled operator.
function _take_op(p::_CondParser, c::Char)
    t = _peek(p)
    (t !== nothing && t.kind === :op && t.op === c) || return 0
    n = p.toks[p.i]
    if p.i + 1 <= length(p.toks)
        m = p.toks[p.i+1]
        if m.kind === :op && m.op === c && m.pos == nextind(p.body, n.pos)
            p.i += 2
            return 2                      # the short-circuit doubled form
        end
    end
    p.i += 1
    return 1                              # the eager single form
end

function _parse_primary(p::_CondParser)
    t = _peek(p)
    t === nothing && _unparsable(p)
    if t.kind === :atom
        p.i += 1
        return t.node
    elseif t.op === '('
        p.depth += 1
        p.depth <= p.profile.max_parser_depth ||
            _refuse(:ERR_CONDITION_CAP,
                "GoMeta absorb: condition too complex — the condition's grouping depth " *
                "exceeds the profile's parser-depth wall (" *
                string(p.profile.max_parser_depth) * "); shorten or split the condition " *
                "(see docs/public-api.md §3.4)", p.profile.max_parser_depth)
        p.i += 1
        inner = _parse_scor(p)
        u = _peek(p)
        (u !== nothing && u.kind === :op && u.op === ')') || _unparsable(p)
        p.i += 1
        p.depth -= 1
        return inner
    elseif t.op === '!'
        p.i += 1
        return CondNot(_parse_primary(p))
    end
    _unparsable(p)
end

function _parse_and(p::_CondParser)          # eager '&' (single)
    a = _parse_primary(p)
    while true
        t = _peek(p)
        (t !== nothing && t.kind === :op && t.op === '&') || return a
        n = _take_op(p, '&')
        if n == 2
            p.i -= 2                          # the doubled form belongs to the sc_and level
            return a
        end
        a = CondAnd(a, _parse_primary(p))
    end
end

function _parse_or(p::_CondParser)           # eager '|' (single)
    a = _parse_and(p)
    while true
        t = _peek(p)
        (t !== nothing && t.kind === :op && t.op === '|') || return a
        n = _take_op(p, '|')
        if n == 2
            p.i -= 2                          # the doubled form belongs to the sc_or level
            return a
        end
        a = CondOr(a, _parse_and(p))
    end
end

function _parse_scand(p::_CondParser)        # '&&'
    a = _parse_or(p)
    while true
        t = _peek(p)
        (t !== nothing && t.kind === :op && t.op === '&') || return a
        n = _take_op(p, '&')
        n == 2 || _unparsable(p)              # a stray eager '&' here is a malformed sequence
        a = CondScAnd(a, _parse_scand(p))
        return a
    end
end

function _parse_scor(p::_CondParser)         # '||' and the ','-lowering
    a = _parse_scand(p)
    while true
        t = _peek(p)
        t === nothing && return a
        if t.kind === :op && t.op === ','
            p.i += 1
            a = CondScOr(a, _parse_scand(p))
        elseif t.kind === :op && t.op === '|'
            n = _take_op(p, '|')
            n == 2 || _unparsable(p)
            a = CondScOr(a, _parse_scand(p))
        else
            return a
        end
    end
end

# ── the public intake (Contract: text → ConditionAST | typed refusal Diagnostic; never throws) ──

"""
    parse_condition(text; registry = DEFAULT_REGISTRY, profile = DEFAULT_GRAMMAR_PROFILE)
        -> Union{ConditionAST, Diagnostic}

The TOTAL + BOUNDED condition intake: every input returns EITHER a `ConditionAST` OR a typed
refusal `Diagnostic` — never a throw, never a hang, and every cap REFUSES, never truncates,
never silently accepts a partial scan. The scan replicates the engine's as-built acceptance
envelope — its refusal walls, its stable refusal messages, and its remaining replicated
corners (the pending-argument leak and the end-of-body parenthesis fold — K3/K4 in the
module-header register) — EXCEPT three retired corners (the one-character drop, the K5
label truncation, and the K6 label-paren discard), all recorded owner decisions whose cells
the transition-time comparison tools carry as deliberate, enumerated differences. Caps and
operator precedence are DATA read from the resolved grammar profile. Touches no per-call
state and no dynamic scope.
"""
function parse_condition(text::AbstractString;
                         registry::AlterantRegistry = DEFAULT_REGISTRY,
                         profile::GrammarProfile = DEFAULT_GRAMMAR_PROFILE)
    body = String(text)
    try
        all(_cond_isspace, body) &&
            _refuse(:ERR_CONDITION_PARSE,
                "GoMeta absorb: empty condition block — '{}' contains no condition; v0 " *
                "requires a non-empty condition inside '{}' (an unconditional action is " *
                "written without '{}'; see docs/public-api.md §3.4)")
        toks = _scan_condition(body, registry, profile)
        isempty(toks) &&
            _refuse(:ERR_CONDITION_PARSE,
                "GoMeta absorb: empty condition block — '{}' contains no condition; v0 " *
                "requires a non-empty condition inside '{}' (an unconditional action is " *
                "written without '{}'; see docs/public-api.md §3.4)")
        p = _CondParser(toks, 1, 0, profile, body)
        root = _parse_scor(p)
        _peek(p) === nothing || _unparsable(p)
        return ConditionAST(root)
    catch e
        e isa _CondRefusalSignal && return e.d
        rethrow()
    end
end

# ── the evaluator (state passed as an argument; query counts replicate the engine's) ────────────

"""
    evaluate(st::ProcessState, ast::ConditionAST) -> Bool

Evaluate a parsed condition against the per-call state — passed AS AN ARGUMENT (the evaluator
reads no ambient scope itself). A settribute atom reads the per-call snapshot; a query atom
keeps unset ⇒ FALSE (membership on an absent store is false — no
tri-state), then dispatches the registered query (the closed label whitelist's loud
unknown-label refusal included); a raw (non-literal) argument meets the stable invalid-argument
refusal at this stage (where the engine's evaluated string crashed raw). The eager ('&'/'|')
vs short-circuit ('&&'/'||'/',') operator split reproduces the engine's query-evaluation
counts exactly.
"""
evaluate(st::ProcessState, ast::ConditionAST)::Bool = _eval_node(st, ast.root)::Bool

"""
    has_query_atom(ast::ConditionAST) -> Bool

TRUE iff the condition's algebra contains any `CondQueryAtom` (an alterant-state
query). The localOnly delivery seam consults this: a heading condition may test only
SETTRIBUTE predicates at v0.2 — a query atom has no honest referent at the absorb
seam (the working set there is the PREVIOUS apply's residue, not the heading's own
context; an identical condition would mint or drop the head row depending on
unrelated preceding content — the order-dependent wrong-verdict class), so the
query form REFUSES there, RESERVED for a build that can give it the heading's own
lineage context (a compatible refusal→semantics widening later).
"""
has_query_atom(ast::ConditionAST) = _has_query(ast.root)
_has_query(::CondQueryAtom) = true
_has_query(::CondStateAtom) = false
_has_query(n::CondNot) = _has_query(n.x)
_has_query(n::Union{CondAnd,CondOr,CondScAnd,CondScOr}) =
    _has_query(n.a) || _has_query(n.b)

"""
    print_condition(marker::FullEvalCondition) -> String

The canonical form of an OPT-IN full-eval condition: its SOURCE TEXT, which is the only
faithful rendering (the text is never lowered into the closed algebra — that is the point of
the mode). This method exists because the apply phase renders EVERY carried condition into
its decision records; without it an opt-in run aborted as soon as those records were
collected. The marker is a condition carrier like any other, so every consumer of the
carried type must accept it.
"""
print_condition(marker::FullEvalCondition) = marker.text

# The `:full_eval_v1` opt-in arm (the dual-mode ruling): dispatch to the handler the opt-in extension
# registered. `src/` holds NO evaluation itself — an unregistered marker is a loud stable-message
# error, never a silent skip (a marker can only exist if the operator loaded the extension, so this
# arm fires only on a mis-wired opt-in, and it fails LOUD).
function evaluate(st::ProcessState, marker::FullEvalCondition)::Bool
    h = _FULL_EVAL_HANDLER[]
    h === nothing && error("GoMeta apply: a full-eval condition marker was reached but the ",
        ":full_eval_v1 handler is not registered — include ",
        "\"extensions/condition_modes_opt_in.jl\" before selecting that profile (the dual-mode ruling)")
    return h(st, marker.text)::Bool
end

_eval_node(st::ProcessState, n::CondStateAtom) = get_state(st.snapshot, n.key)::Bool

function _eval_node(st::ProcessState, n::CondQueryAtom)
    for a in n.args
        a isa CondRawArg &&
            error("GoMeta apply: invalid condition argument ", repr(first(a.text, 40)),
                " — a v0 condition argument is a ':'-prefixed one-word label ",
                "(see docs/public-api.md §3.4)")
    end
    if n.plugin ∈ keys(st.working)
        return st.registry.plugins[n.plugin].getAltInstance(
            st.working[n.plugin],
            n.action,
            n.args...
        )
    else
        return false
    end
end

_eval_node(st::ProcessState, n::CondNot)   = !(_eval_node(st, n.x)::Bool)
_eval_node(st::ProcessState, n::CondAnd)   = (_eval_node(st, n.a)::Bool) & (_eval_node(st, n.b)::Bool)
_eval_node(st::ProcessState, n::CondOr)    = (_eval_node(st, n.a)::Bool) | (_eval_node(st, n.b)::Bool)
_eval_node(st::ProcessState, n::CondScAnd) = (_eval_node(st, n.a)::Bool) && (_eval_node(st, n.b)::Bool)
_eval_node(st::ProcessState, n::CondScOr)  = (_eval_node(st, n.a)::Bool) || (_eval_node(st, n.b)::Bool)

# ── the canonical printer (source vocabulary; round-trips through parse_condition) ──────────────

# Precedence levels for parenthesization (mirrors the profile's DATA table).
_prec(::CondNot)    = 5
_prec(::CondAnd)    = 4
_prec(::CondOr)     = 3
_prec(::CondScAnd)  = 2
_prec(::CondScOr)   = 1
_prec(::Any)        = 6   # atoms never need wrapping

_wrap(s::String, need::Bool) = need ? "(" * s * ")" : s

_print_arg(a::Symbol)     = ":" * String(a)
_print_arg(a::CondRawArg) = a.text

function _print_node(n::CondQueryAtom)
    if n.action === Symbol(":") && length(n.args) == 1 && n.args[1] isa Symbol
        return ":" * String(n.args[1]::Symbol)          # the one-word label form
    end
    return String(n.action) * "(" * join([_print_arg(a) for a in n.args], ", ") * ")"
end
_print_node(n::CondStateAtom) = String(n.key)
_print_node(n::CondNot)   = "!" * _wrap(_print_node(n.x), _prec(n.x) < _prec(n))
_print_node(n::CondAnd)   = _wrap(_print_node(n.a), _prec(n.a) < 4) * " & " *
                            _wrap(_print_node(n.b), _prec(n.b) <= 4)
_print_node(n::CondOr)    = _wrap(_print_node(n.a), _prec(n.a) < 3) * " | " *
                            _wrap(_print_node(n.b), _prec(n.b) <= 3)
_print_node(n::CondScAnd) = _wrap(_print_node(n.a), _prec(n.a) <= 2) * " && " *
                            _wrap(_print_node(n.b), _prec(n.b) < 2)
_print_node(n::CondScOr)  = _wrap(_print_node(n.a), _prec(n.a) < 1) * ", " *
                            _wrap(_print_node(n.b), _prec(n.b) <= 1)   # left-assoc parse: a
                                                                       # same-level RIGHT child
                                                                       # keeps its grouping

"""
    print_condition(ast::ConditionAST) -> String

The canonical source-vocabulary form of a parsed condition: atoms print bare (`isCode`),
label queries print `:word`, other queries print `action(:arg, …)`; operators print `!`,
`&`, `|`, `&&`, and `, ` (the canonical OR spelling); grouping parentheses appear exactly
where precedence demands. A form ending in `)` gains ONE trailing space — the scanner's
replicated end-of-body arm folds a final `)` into the last atom's key (the engine's own
built strings carry trailing spaces for the same reason), so the space keeps every canonical
form re-parsable. Printing and re-parsing yields the same AST (the round-trip law); this
form becomes the logged condition representation when the engine flips to this path.
"""
function print_condition(ast::ConditionAST)::String
    s = _print_node(ast.root)
    return endswith(s, ')') ? s * " " : s
end
