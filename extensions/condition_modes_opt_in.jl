# extensions/condition_modes_opt_in.jl — THE OPT-IN CONDITION-INTAKE MODES (the dual-mode ruling).
#
# ┌─ READ THIS BEFORE INCLUDING ────────────────────────────────────────────────────────────┐
# │ Including this file OPTS YOU OUT of the closed condition interpreter's safety envelope   │
# │ for documents you then process under an opt-in profile. It is deliberately NOT part of   │
# │ the package: `using GoMeta` alone can never reach these modes. Opting in takes TWO        │
# │ explicit acts by the OPERATOR (never by a document, never by metaLine content):          │
# │   1. `include(joinpath(pkgdir(GoMeta), "extensions", "condition_modes_opt_in.jl"))`      │
# │   2. `GoMetaConfig(profile = :jl_share_v1_full_parse)`  (or `:jl_share_v1_full_eval`) │
# │ Neither act is reachable from processed content, so no document can widen its own        │
# │ intake. Without both, every condition parses under `:closed_v1` — the safe default.      │
# └─────────────────────────────────────────────────────────────────────────────────────────┘
#
# HEADING × EXECUTING RUNG — RESERVED (added at the localOnly delivery build, after a
# fresh-eyes external finding): a HEADING condition that would EXECUTE (text beyond the
# safe rung, i.e. a full-eval marker) meets a typed refusal at the absorb seam. The
# heading surface postdates this contract: headings now evaluate their conditions at
# ABSORB time, where an executed condition's alterant-state reads would see the
# PREVIOUS apply's residue — a context this header never asked the operator to accept
# ("opt-in execution does not imply consent to a changed context"). Settribute-only
# heading conditions still work under BOTH profiles — they arrive as the same closed
# data (the executing profile's safe-rung-first chain; the standalone full-parse
# profile's whitelist, which host-parses and never executes — no safe rung in its
# chain); every QUEUED action's conditions keep the modes' full behavior. Defining an
# executed heading condition's context is a future, compatible widening.
#
# WHY THIS EXISTS (the ruling, verbatim in RULINGS-RELEASE.md the dual-mode ruling): "I do NOT want to be
# UNCONDITIONALLY restricted (i.e.: without having another choice) by the safe parser. BOTH
# MUST BE AVAILABLE FOR THOSE USERS WHO FOR INSTANCE WORK ONLY WITH THEIR PRIVATE GoMeta
# statements (i.e.: If there is NO security risk whatsoever)." Alterant applications are
# open-ended; the engine must not decide for an author who owns every byte of their own
# corpus. The safe mode is the DEFAULT, not the ceiling.
#
# THE TWO MODES:
#
#   :full_julia_parse_v1 — FULL JULIA GRAMMAR, STILL NO EXECUTION.
#       Condition text is parsed by the host parser (the full expression grammar: any
#       operator, any literal, any call shape) and then WALKED against a closed whitelist:
#       only the node shapes the engine's own evaluator understands survive; anything else
#       is a typed refusal. Nothing is evaluated — the produced value is data, exactly as in
#       the closed mode. Widens ACCEPTANCE, not authority — with two KNOWN, recorded-OPEN
#       divergences on closed-ACCEPTED text (this mode is not a strict superset of the
#       closed grammar): the settribute-call argument DROP (see the lowering arm below)
#       and the word-less label-paren forms (`:(:label1)`, `:()`), which the closed
#       default accepts and this mode's whitelist refuses (a quote wrapper no arm lowers;
#       pinned at its current fate in the modes tests' M6 boundary rows).
#       Risk: parser exposure (attacker-controlled text reaches the host parser). Choose it
#       for corpora you author.
#
#   :full_eval_v1 — THREE RUNGS: safe grammar, then full syntax AS DATA, then EVALUATION.
#       (1) The safe grammar is tried FIRST: everything it accepts behaves EXACTLY as in the
#       default mode — same verdicts, same query traces, same refusal texts. Opting in never
#       changes what an already-working document means.
#       (2) What the safe grammar refuses is then offered to the full-syntax rung, and if that
#       rung can lower it COMPLETELY the condition is handled as DATA and nothing is executed.
#       This rung exists so that opting in for one exotic condition does not silently hand the
#       whole document to an evaluator.
#       (3) Only what neither rung can handle — and a PARTIAL lowering counts as "cannot",
#       because carrying it as data would deny the evaluation you opted in FOR — is parsed as
#       Julia and EVALUATED in the package module, where the engine's own condition helpers
#       (`getState(:isCode)`, `getAltState(...)`) resolve as they did before v0.2.
#       That third rung is arbitrary code execution driven by document content. It is the
#       genuine un-restriction, and it is the reason the default is closed.
#       NOT a verbatim restoration of the pre-v0.2 engine, and NOT a subset of it either —
#       be clear-eyed about this before enabling it:
#         · Rung (2) means less text reaches execution than a plain safe-or-execute chain
#           would send there. That is a comparison against the ALTERNATIVE DESIGN, not
#           against the old engine.
#         · Against the OLD ENGINE, execution reach is GREATER, not smaller. That engine
#           refused unknown vocabulary at its own scan and evaluated nothing for it; here,
#           a body like `rm("x")` or `run(`id`)` — refused outright there — reaches rung (3)
#           and IS EXECUTED. This is the intended un-restriction, and it is
#           precisely why the mode is opt-in, but the earlier wording of this header claimed
#           the opposite and was wrong (review-found, byte-confirmed).
#         · The engine's raw-byte wall binds on every rung including this one; the two SCAN
#           caps are properties of the closed scanner and do not constrain host evaluation.
#         · Text carried as data by rung (2) meets the argument wall with a re-rendered
#           message rather than the original bytes.
#         · THE LADDER LAW (external review, byte-confirmed; restated after a second
#           external lens showed the first wording was a FALSE UNIVERSAL). Whatever the
#           SAFE rung refuses ADVANCES to rung (2) — that much is unconditional. Whether it
#           goes further is NOT: host EVALUATION grows only for inputs rung (2) cannot
#           lower COMPLETELY. Both outcomes are real and both were observed across the
#           retirements so far: `cell(x)` moved from "mangled to a zero-argument query by
#           rung (1)" to "REACHES RUNG (3) AND IS EXECUTED" (text even the pre-v0.2 engine
#           never evaluated in that form), while the retired wall-truncation class stopped
#           at rung (2) as DATA and never reached evaluation at all. The K6 label-paren
#           retirement (stage-2 close) added a third observed class on the EXECUTED side:
#           `:abc(:label1)` parses as a call on a quoted symbol, which rung (2)'s
#           whitelist cannot lower, so it falls through to rung (3) — where the pre-cure
#           rung (1) had silently minted the word-discarded query and executed nothing.
#           SO: every future narrowing of the default intake MUST be assessed for
#           execution-reach growth — it does not automatically cause it, and it never
#           automatically fails to. The reach tests (M6) pin REPRESENTATIVE inputs per
#           class and per mode; they catch a class whose members move together, and they do
#           NOT prove coverage of an unpinned member of a class. Read them as a tripwire,
#           not as an exhaustive proof.
#       NEVER enable this for third-party or untrusted documents.
#
# CONTRACT both modes honour (the totality law is NOT relaxed by opting in): the parse
# function returns a value the evaluator accepts OR a typed `Diagnostic` refusal — it never
# throws out of the intake. The engine's RAW-BYTE wall binds in every mode including the
# executing one; the two SCAN-STEP caps are properties of the closed scanner and do NOT
# constrain host parsing or evaluation. (An earlier version of this paragraph claimed the
# scan caps "still bind first" — that was false, and the sibling claim in the header was
# corrected one wave before this one was noticed. Review-found, byte-confirmed.)

import GoMeta as _GM

# ── :full_julia_parse_v1 ─────────────────────────────────────────────────────────────────
# The whitelist walk: host-parsed Expr → the engine's closed AST, or a typed refusal.
function _optin_full_parse(text::String, registry, profile)
    ncodeunits(text) <= profile.max_condition_bytes ||
        return _GM.Diagnostic(:ERR_CONDITION_CAP, :error,
            "GoMeta absorb: condition too large — the condition body exceeds the profile's " *
            "raw-byte wall (" * string(profile.max_condition_bytes) * " bytes)",
            profile.max_condition_bytes)   # the wall rides the context, as in every mint
    parsed = try
        Meta.parse(text)                      # ACCEPTANCE only — never evaluated
    catch
        return _GM.Diagnostic(:ERR_CONDITION_PARSE, :error,
            "GoMeta absorb: unparsable condition — the condition " *
            repr(first(text, 40)) * " does not parse (opt-in full-parser mode)", nothing)
    end
    (parsed isa Expr && (parsed.head === :error || parsed.head === :incomplete)) &&
        return _GM.Diagnostic(:ERR_CONDITION_PARSE, :error,
            "GoMeta absorb: unparsable condition — the condition " *
            repr(first(text, 40)) * " is incomplete (opt-in full-parser mode)", nothing)
    root = _optin_lower(parsed, registry, text, 0, profile)
    # the intake contract: a queue-carried ConditionT (a wrapped AST) or a typed refusal
    return root isa _GM.Diagnostic ? root : _GM.ConditionAST(root)
end

# Expr → closed AST. Only whitelisted shapes survive; depth-bounded; total.
function _optin_lower(x, registry, text, depth::Int, profile)
    depth > profile.max_parser_depth &&
        return _GM.Diagnostic(:ERR_CONDITION_PARSE, :error,
            "GoMeta absorb: condition too deeply nested (opt-in full-parser mode)", nothing)
    _refuse(why) = _GM.Diagnostic(:ERR_CONDITION_PARSE, :error,
        "GoMeta absorb: unsupported condition shape (" * why * ") in " *
        repr(first(text, 40)) * " — the opt-in full-parser mode still evaluates only the " *
        "engine's own condition algebra (no code is executed in this mode)", nothing)
    if x isa Symbol
        return _GM.cond_atom_for(x, registry)          # state atom | query atom | refusal
    elseif x isa QuoteNode && x.value isa Symbol
        # a LABEL literal (`:label1`): the closed grammar's `:` grant lowers this to the
        # labels-plugin query atom (plugin 1, action `:`), and the opt-in mode must produce
        # the IDENTICAL node — an opt-in widens accepted TEXT, never the algebra.
        return _GM.CondQueryAtom(Int8(1), :(:), Any[x.value])
    elseif x isa Expr && x.head === :call && length(x.args) == 2 && x.args[1] === :!
        inner = _optin_lower(x.args[2], registry, text, depth + 1, profile)
        return inner isa _GM.Diagnostic ? inner : _GM.CondNot(inner)
    elseif x isa Expr && x.head === :call && length(x.args) == 3 &&
           x.args[1] in (:&, :|)
        a = _optin_lower(x.args[2], registry, text, depth + 1, profile)
        a isa _GM.Diagnostic && return a
        b = _optin_lower(x.args[3], registry, text, depth + 1, profile)
        b isa _GM.Diagnostic && return b
        return x.args[1] === :& ? _GM.CondAnd(a, b) : _GM.CondOr(a, b)
    elseif x isa Expr && (x.head === :&& || x.head === :||) && length(x.args) == 2
        a = _optin_lower(x.args[1], registry, text, depth + 1, profile)
        a isa _GM.Diagnostic && return a
        b = _optin_lower(x.args[2], registry, text, depth + 1, profile)
        b isa _GM.Diagnostic && return b
        return x.head === :&& ? _GM.CondScAnd(a, b) : _GM.CondScOr(a, b)
    elseif x isa Expr && x.head === :call && x.args[1] isa Symbol &&
           x.args[1] in keys(_GM.BLS.ComponentSettribute)
        # A SETTRIBUTE KEY USED AS A CALL — `isCode(ab)`. The closed engine's scanner treats
        # the atom as a plain state read and PENDS its parenthesised arguments (they leak to
        # the next query atom). THIS ARM REPRODUCES ONLY THE STATE READ AND DROPS THE
        # PENDING ARGUMENTS — a KNOWN, recorded-OPEN divergence from the closed intake on
        # text both accept (verdict-inert on the current registry; divergent in decision
        # records; see the K3 register note in src/condition.jl). Without this arm the call
        # was unlowerable here and fell through to the EXECUTING rung — which made execution reach GROW rather than shrink for this whole
        # class (external review, byte-confirmed: `isCode(ab)` executed where the pre-cure
        # engine had returned a Bool with no evaluation at all).
        return _GM.cond_atom_for(x.args[1], registry)
    elseif x isa Expr && x.head === :call && x.args[1] isa Symbol
        # a query atom with literal arguments: cell(:a), cell(:a, :b)
        args = Any[]
        for a in x.args[2:end]
            if a isa QuoteNode && a.value isa Symbol
                push!(args, a.value)
            else
                # RIDER A (adopted with the argument-domain decision): an argument outside the
                # SAFE grammar is CARRIED as a raw argument, not refused at intake. This is
                # what makes this mode the compatibility rail for the default's declared
                # argument domain: text the default now refuses is ACCEPTED here and meets
                # the ordinary EVALUATION wall — no code is executed to achieve that. Without
                # this rider the only remedy for a narrowed argument would have been the
                # EXECUTING mode, which would have made the cut a security regression.
                push!(args, _GM.CondRawArg(_optin_arg_text(a)))
            end
        end
        return _GM.cond_query_for(x.args[1], args, registry)
    elseif x isa Expr && x.head === :tuple
        # the ','-lowering: a, b, c  ⇒  short-circuit OR chain (left-folded, as the engine)
        isempty(x.args) && return _refuse("empty group")
        acc = _optin_lower(x.args[1], registry, text, depth + 1, profile)
        acc isa _GM.Diagnostic && return acc
        for a in x.args[2:end]
            nxt = _optin_lower(a, registry, text, depth + 1, profile)
            nxt isa _GM.Diagnostic && return nxt
            acc = _GM.CondScOr(acc, nxt)
        end
        return acc
    end
    return _refuse("shape " * string(x isa Expr ? x.head : typeof(x)))
end

# ── :full_eval_v1 ──────────────────────────────────────────────────────────────────────
# Unrestricted evaluation for private corpora — NOT the pre-v0.2 semantics verbatim (see the
# header: reach differs in BOTH directions from that engine). The retired engine's own
# host parse + EVALUATION for whatever the two safer rungs could not handle. This is the mode
# that executes document-driven code; it is why every other layer of this engine refuses to.
# SUPERSET by construction, in THREE rungs: the SAFE grammar is tried FIRST and, when it
# accepts, its own AST is returned — so every condition the closed mode understands behaves
# IDENTICALLY here (same verdict, same query trace, same refusal texts; no document changes
# meaning by opting in). Text it refuses goes to the full-syntax rung and is handled as DATA
# when that rung lowers it COMPLETELY; only the remainder reaches evaluation. The user is
# never restricted, never surprised, and never handed an evaluator they did not need.
function _optin_full_eval(text::String, registry, profile)
    closed = _GM.parse_condition(text; registry = registry,
                                 profile = _GM.DEFAULT_GRAMMAR_PROFILE)
    closed isa _GM.Diagnostic || return closed          # the safe grammar accepted it
    # RIDER B (adopted with the argument-domain decision): before falling through to
    # EXECUTION, try the NON-EXECUTING full-syntax mode, so text it can fully handle is
    # handled as DATA and the set of text that reaches evaluation shrinks.
    #
    # BUT ONLY IF IT LOWERS COMPLETELY. External review caught the interaction between the
    # two riders: rider A makes the full-syntax mode CARRY an unrecognised argument as a raw
    # value, so an unconditional chain would have swallowed `cell(myvar)` here — returning a
    # value that refuses at evaluation — even though the operator opted into THIS mode
    # precisely to have `myvar` evaluated. Denying the mode's whole purpose is not a safety
    # win, it is a silent capability loss. So a partially-lowered result (one still carrying
    # a raw argument) falls through to evaluation, where the operator asked for it to go;
    # only a COMPLETE lowering short-circuits the chain.
    syntax = _optin_full_parse(text, registry, profile)
    if !(syntax isa _GM.Diagnostic) && !_optin_has_raw_arg(syntax)
        return syntax
    end
    # THE WALL BINDS BEFORE THE HOST PARSER SEES THE TEXT. Binding it after the parse (as the
    # first version of this cure did) still handed an over-wall body to the parser and only
    # then refused it — a wall placed behind the exposure it exists to prevent.
    ncodeunits(text) <= profile.max_condition_bytes ||
        return _GM.Diagnostic(:ERR_CONDITION_CAP, :error,
            "GoMeta absorb: condition too large — the condition body exceeds the profile's " *
            "raw-byte wall (" * string(profile.max_condition_bytes) * " bytes); this wall " *
            "binds in EVERY mode, including the opt-in executing one",
            profile.max_condition_bytes)   # the wall rides the context, as in every mint
    try
        parsed = Meta.parse(text)
        (parsed isa Expr && (parsed.head === :error || parsed.head === :incomplete)) &&
            return _GM.Diagnostic(:ERR_CONDITION_PARSE, :error,
                "GoMeta absorb: unparsable condition — the condition " *
                repr(first(text, 40)) * " is refused by the safe grammar AND does not " *
                "parse as Julia (opt-in full-eval mode)", nothing)
    catch
        return _GM.Diagnostic(:ERR_CONDITION_PARSE, :error,
            "GoMeta absorb: unparsable condition — the condition " *
            repr(first(text, 40)) * " is refused by the safe grammar AND does not parse " *
            "as Julia (opt-in full-eval mode)", nothing)
    end
    return _GM.FullEvalCondition(text)      # the marker the evaluator dispatches on
end

# THE EVALUATION HANDLER — the one place in this whole system that executes condition text.
# It lives HERE, outside the package, so `src/` carries no evaluation path and its purity /
# no-eval gates stay armed for everyone who has not opted in. The per-call state is in scope
# (the same dynamic scope the retired engine used), so the engine's own condition helpers —
# `getState(:isCode)`, `getAltState(...)` — resolve exactly as they did pre-v0.2.
function _optin_full_eval_handler(st, text::String)
    v = Base.eval(_GM, Meta.parse(text))       # ← document-driven execution, by explicit opt-in
    v isa Bool && return v
    error("GoMeta apply: the full-eval condition ", repr(first(text, 40)),
        " produced a non-Boolean verdict (", typeof(v), ") — the apply boolean context ",
        "requires Bool (this is the pre-v0.2 behaviour, reproduced)")
end

# Render one parsed argument back to source-ish text for the raw carrier (RIDER A).
# Does a lowered condition still carry a raw (un-lowered) argument? Used by the eval chain
# to tell a COMPLETE lowering from a partial one.
_optin_has_raw_arg(x::_GM.ConditionAST) = _optin_has_raw_arg(x.root)
_optin_has_raw_arg(a::_GM.CondQueryAtom) = any(v -> v isa _GM.CondRawArg, a.args)
_optin_has_raw_arg(n::_GM.CondNot) = _optin_has_raw_arg(n.x)
_optin_has_raw_arg(n::Union{_GM.CondAnd,_GM.CondOr,_GM.CondScAnd,_GM.CondScOr}) =
    _optin_has_raw_arg(n.a) || _optin_has_raw_arg(n.b)
_optin_has_raw_arg(::Any) = false

_optin_arg_text(a) = a isa QuoteNode ? ":" * string(a.value) : sprint(Base.show_unquoted, a)

_GM.register_condition_mode!(:full_julia_parse_v1, _optin_full_parse)
_GM.register_condition_mode!(:full_eval_v1, _optin_full_eval)
_GM.register_full_eval_handler!(_optin_full_eval_handler)

@info """GoMeta OPT-IN condition modes LOADED (the dual-mode ruling).
  :jl_share_v1_full_parse  — full Julia grammar accepted, NOTHING executed.
  :jl_share_v1_full_eval — document content IS EXECUTED for whatever the two safer
      rungs cannot handle. NOT the pre-v0.2 engine: it executes MORE than that engine did
      (which refused unknown vocabulary outright) and less than a plain safe-or-execute
      chain would. See this file's header before relying on either comparison.
  The default profile (:jl_share_v1) is unchanged and remains the closed, safe intake."""
