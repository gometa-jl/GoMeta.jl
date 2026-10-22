## labels.jl — THE LABELS ALTERANT'S OWN FILE (the creator's words:
## 2026-08-22 — the whitelist "for some unknown reason hard part of GoMeta Core. That is a MISTAKE and must be rectified.
## It is NOT a new feature or improvement, it is fixing a bug."; 2026-10-08 — labels are added "by simply
## writing it into the code of the Labels Alterant (i.e.: hard coded). … If the label :doc or some other label is required, then
## simply hard code it into the Alterant for now."; "a basic true Labels Alterant first, inside v0.4. Keep it SIMPLE AND
## ELEGANT."). Under `alterants-std/` — the std-Alterants' territory
## (never a Core literal; vocabulary_tests [10] scans `src/` around this directory).
##
## THE VOCABULARY STATEMENTS (0.4.2): `:++x` / `:(++, x, y)` ADD names to the Labels Alterant's VOCABULARY,
## `:--x` / `:(--, x)` REMOVE names from it (the creator's terms) — legal at `#~0` (a metaBlock opened by `#~0`) and in the user level's
## profile ONLY; RECORDED ONCE AT THE READ by the Engine's read-time hook (`onRead` on the registration record): consumed
## there, never enqueued, no evals row; effective from the apply of their own metaBlock onward; the malformed
## shapes refused. THE VOCABULARY OF A RUN: the BASE behind ONE function `base_vocabulary()` — today the literal below, the
## INTERIM source (the vocabulary was never meant as part of the Engine; a data file outside it, loaded by this
## Alterant, is a later release's) — and the run's ADDITIONS and REMOVALS kept APART (`LabelsVocabulary`: the delta a later copy-and-merge
## write-out reads); the effective set = base ∪ added − removed, in that order.
##
## THE WITHHOLD AND THE EXPLICIT APPLY (0.4.3): `:-x` / `:(-, x, y)` WITHHOLDS a label from the current set of labels
## applied to the current Component (and, through the Engine's walk, from every Component under its metaBlock until the slot is replaced —
## the Engine's own walk, no reach law of its own); `:+x` / `:(+, x)` APPLIES it explicitly, after a withhold or not; a PLAIN `:x` met by a
## withhold APPLIES NOTHING and is REPORTED — one `:warning` Diagnostic per statement and name at each such Component (a name a statement writes twice is reported twice), returned by the setter to the
## Engine's door (apply.jl), the run proceeding `PROCESS_OK` (the creator's design: the user informed and allowed to proceed; the file never
## rewritten for one run); the malformed shapes refused (the sign at the head of a statement, never inside a list); the instance's third
## field `withheld`; the `Dict{Symbol,Bool}` setter method unchanged. A withheld label read by a condition answers false silently (the
## withhold's meaning; the limit stated on the pages). An applied name outside the run's vocabulary keeps the refusal (its turn into a
## warning diagnostic is a later release's).
##
## IS:   the Labels Alterant's code — THE HARD-CODED LIST `LABELS_VOCABULARY` (the 38 names the plain file `labels_vocabulary.txt`
##       carried before, in that file's order, plus `:doc`; a later name is one line here; none of the
##       original engine's other names; `public` / `private` out for now); `base_vocabulary()`; `LabelsVocabulary`
##       (the run state) and `LabelsInstance` (the per-Component instance: the applied labels, the run's vocabulary and the names withheld); the hook
##       `declareLabels!`; `setLabels` — the closed check against the RUN's vocabulary (the original engine's scan, GoMetaRetro Alterants.jl
##       :73–:78 at 47f0521: an applied name outside the set refuses with a message naming the accepted set, sorted for display);
##       `checkLabels` — the original engine's checker (:87–:99): an unset or unknown name answers false. The `Dict{Symbol,Bool}` methods of the
##       setter and the checker STAY: a custom registration pairing them with `altConstructor = Dict{Symbol,Bool}` runs without the hook: a run state handed to `Dict{Symbol,Bool}(…)` by `_freshInstance` (apply.jl) is Julia's own error.
## DOES: a run WITHOUT a vocabulary statement evaluates as before the vocabulary statements — every label statement passes the hook's `nothing` path, the
##       instance is built by the zero-argument constructor over the base, the setter's scan is the former one over the same 39 names
##       in the same order and its message the former one but for its noun ("the Labels Alterant's vocabulary").
## REASONING: the ∈-scan over the vector in declaration order (never `insorted` over an unsorted declaration);
##       the ZWJ name `⛓️‍💥` is one name (its former `query=false` field was inert data).
## PURPOSE: a basic, true Labels Alterant whose vocabulary a file (at `#~0`) or the user level can extend and prune, per run.

"the hard-coded Labels vocabulary — the 38 shipped names in the former plain file's order, plus `:doc` (39 names) — the INTERIM base of every run (a later release loads it from a data file outside the Engine)"
const LABELS_VOCABULARY = Symbol[Symbol(n) for n in (
    "label1",
    "label2",
    "label3",
    "label4",
    "label5",
    "⛔",
    "💯",
    "🇨🇭",
    "🏔️",
    "🍒",
    "🫕",
    "💡",
    "💣",
    "🧮",
    "📝",
    "💕",
    "⌛",
    "💸",
    "💾",
    "⛓️‍💥",
    "⛓️",
    "📸",
    "🎨",
    "🍻",
    "🔥",
    "🐣",
    "😘",
    "🎿",
    "🚀",
    "🌍",
    "🌳",
    "🌛",
    "🌷",
    "🌹",
    "🌼",
    "🍀",
    "🌞",
    "💫",
    "doc",
)]

"THE BASE VOCABULARY OF A RUN — ONE function: today the literal above, the interim source; a later release replaces this one body with the loaded data file or files"
base_vocabulary() = LABELS_VOCABULARY

"""
    LabelsVocabulary

THE RUN STATE of the Labels Alterant: the BASE, the run's ADDITIONS and its REMOVALS kept APART — the delta a later
copy-and-merge write-out reads (the creator's design) — and the EFFECTIVE set = base ∪ added − removed, in that order, recomputed by the hook after
every vocabulary statement. Minted by the hook's first consumed statement (`ProcessState.alt_run`); dies with the call.
"""
mutable struct LabelsVocabulary
    base::Vector{Symbol}
    added::Vector{Symbol}
    removed::Vector{Symbol}
    effective::Vector{Symbol}
end
"the vocabulary of a run with no vocabulary statement yet: the base alone — `effective` IS the base vector (shared, read-only)"
LabelsVocabulary() = (b = base_vocabulary(); LabelsVocabulary(b, Symbol[], Symbol[], b))
function _recompute_effective!(v::LabelsVocabulary)
    eff = Symbol[]
    for n in v.base;  n ∈ v.removed || push!(eff, n); end
    for n in v.added; n ∈ v.removed || push!(eff, n); end
    v.effective = eff
    return v
end

"""
    LabelsInstance

THE PER-COMPONENT INSTANCE of the Labels Alterant (since 0.4.2): the applied labels (the former bare `Dict{Symbol,Bool}`), the run's
vocabulary the setter checks against and — since 0.4.3 — the names WITHHELD at the Component (`:-x`). Built by the Engine's instance constructor: the zero-argument call where the run minted no
vocabulary (the base), the one-argument call with the run state where it did (`_freshInstance`, apply.jl). Iterates as the Dict did —
the capture's one read of the instance (`for (kk, vv) in inst`, annotations.jl).
"""
struct LabelsInstance
    applied::Dict{Symbol,Bool}
    vocab::LabelsVocabulary
    withheld::Set{Symbol}      # the names WITHHELD at this Component (`:-x`); a plain `:x` met by one applies nothing and is reported
end
LabelsInstance() = LabelsInstance(Dict{Symbol,Bool}(), LabelsVocabulary(), Set{Symbol}())
LabelsInstance(run::LabelsVocabulary) = LabelsInstance(Dict{Symbol,Bool}(), run, Set{Symbol}())
Base.iterate(x::LabelsInstance) = iterate(x.applied)
Base.iterate(x::LabelsInstance, s) = iterate(x.applied, s)
Base.length(x::LabelsInstance) = length(x.applied)
Base.eltype(::Type{LabelsInstance}) = Pair{Symbol,Bool}

"""
    declareLabels!(run, mhIdx, actionName, args, hasCondition) -> nothing | LabelsVocabulary

THE READ-TIME HOOK of the Labels Alterant (the registration record's `onRead`): called by `absorbMeta` for
every `:` statement WITH arguments, before the slot bound. Returns `nothing` for a plain label statement (the Engine enqueues it as
stated) and the run's vocabulary for a VOCABULARY statement — consumed at the read: the Engine stores it as this Alterant's run state and
ends the statement's processing (no slot action, no row). THE CHECKS, in this order: the PLACE (a metaBlock opened by `#~0`
or the user level's profile; nothing else), then the malformed shapes: (iv) the prefixed sign with several arguments,
(iii) no name, (ii) a declared name beginning with a sign, (i) a condition. Every refusal carries the read-time prefix "GoMeta absorb:".
THE FOLD: `++n` — `n` leaves `removed` and joins `added` unless it is in the base or already added;
`--n` — `n` leaves `added` and joins `removed` if it is in the base and not yet removed; `--` of a name never present is a no-op; the
last statement in reading order wins. A quoted (String) token among the arguments is never a vocabulary statement: handed back, it meets
the Engine's String-slot law at the enqueue as before.
"""
function declareLabels!(run, mhIdx::Int, actionName::Symbol, args::Tuple, hasCondition::Bool)
    actionName === :(:) || return nothing
    any(a -> a isa String, args) && return nothing
    s1 = String(args[1])
    adding = startswith(s1, "++")
    (adding || startswith(s1, "--")) || return nothing
    sign = s1[1:2]
    ## THE PLACE: the file slot — a metaBlock opened by `#~0` — or the user level's profile
    (mhIdx == fileMHIdx || mhIdx == userMHIdx) ||
        error("GoMeta absorb: a vocabulary statement (`:", sign, "x`, `:(", sign, ", x, y)`) is legal at `#~0` and in the user level's profile only — here ",
            mhIdx == lineMHIdx ? "an inline metaSegment" : string("a metaBlock of depth ", mhIdx - 1), "; see docs/public-api.md §3.4")
    ## (iv) the prefixed form takes exactly one name
    length(s1) > 2 && length(args) > 1 &&
        error("GoMeta absorb: the prefixed vocabulary statement `:", s1, "` takes one name — ", length(args), " arguments given (the list form is `:(",
            sign, ", x, y)`); see docs/public-api.md §3.4")
    names = length(s1) > 2 ? Symbol[Symbol(s1[3:end])] : Symbol[Symbol(String(a)) for a in args[2:end]]
    ## (iii) no name
    isempty(names) &&
        error("GoMeta absorb: the vocabulary statement `:", s1, "` names no label — the forms are `:", sign, "x` and `:(", sign, ", x, y)`; see docs/public-api.md §3.4")
    ## (iii) too — an EMPTY member, a stray comma (`:(++,)`, `:(++, x, )`, `:(--,)`): the splitter hands the empty piece on and the
    ## Alterant decides (absorb_meta.jl `_split_args`); a member that names no label is refused like no name at all
    ## (an empty member — a stray comma — refused like no name; measured V42 … V45)
    any(n -> isempty(String(n)), names) &&
        error("GoMeta absorb: the vocabulary statement `:", s1, "` names an empty label (a stray comma) — the forms are `:", sign, "x` and `:(", sign, ", x, y)`; see docs/public-api.md §3.4")
    ## (ii) a declared name beginning with a sign (the names `+x` / `-x` kept free for a later release's forms; a signed member of a PLAIN list stays an unknown label, as before)
    for n in names
        ns = String(n)
        (startswith(ns, "+") || startswith(ns, "-")) &&
            error("GoMeta absorb: a label name in a vocabulary statement may not begin with `+` or `-` — got ", repr(ns), " in `:", s1, "`; see docs/public-api.md §3.4")
    end
    ## (i) a condition on a vocabulary statement
    hasCondition &&
        error("GoMeta absorb: a vocabulary statement takes no condition — `:", s1, "{ … }` (a declaration is a fact of the run, not of a Component); see docs/public-api.md §3.4")
    v = run === nothing ? LabelsVocabulary() : run::LabelsVocabulary
    for n in names
        if adding
            filter!(!=(n), v.removed)
            (n ∈ v.base || n ∈ v.added) || push!(v.added, n)
        else
            filter!(!=(n), v.added)
            (n ∈ v.base && n ∉ v.removed) && push!(v.removed, n)
        end
    end
    return _recompute_effective!(v)
end

"""
    setLabels(inst::LabelsInstance, :(:), tokens...) -> nothing | Vector{Diagnostic}

THE SETTER ON THE `LabelsInstance` (the withhold and the explicit apply — since 0.4.3): the sign is read from the FIRST token alone — `-` or
`+` as the whole first token is the LIST form (the verb for every following name: `:(-, x, y)`, `:(+, x)`), a first token beginning with
`-` / `+` and longer is the PREFIXED form (one name: `:-x`, `:+x`), any other first token a PLAIN statement (every token a name — the former
path). THE SHAPES refused with GoMeta's message at the apply (the standing class, out of the call): the prefixed sign with several arguments;
a sign with no name; an empty member of a SIGNED list (a stray comma — a plain list's empty member keeps the former path, the unknown-label
refusal); a name beginning with a sign — after a prefixed sign (`:+-x`), inside a signed list and inside a PLAIN list alike (the mixed list `:(x, -y)`): the sign stands at
the head of a statement, never inside a list. PER NAME, in token order: the vocabulary check as before (an unknown name refuses, naming the
accepted set — the unknown label's turn into a warning diagnostic is a later release's), then THE VERB: WITHHOLD — the name leaves the
applied set and joins the withheld set (a name not applied: the same, a harmless no-op in the delivery); APPLY EXPLICITLY — the name joins
the applied set and leaves the withheld set; PLAIN — a name WITHHELD here applies nothing and is REPORTED: one `Diagnostic` of severity
`:warning` per such name, code `LABEL_NOT_APPLIED_WITHHELD`, the label as data in its context, RETURNED to the Engine (which attaches the
place and delivers it with the run's result; the run proceeds, the status untouched — the creator's design: the user informed and allowed
to proceed, the file never rewritten for one run); every other name applies as before. A withhold reaches every Component whose walk
includes its statement's slot — the Engine's own walk, no reach law here. The `Dict{Symbol,Bool}` method below is untouched (a custom
registration pairing it with the shipped setter keeps the former scan).
"""
function setLabels(
    crntLabels::LabelsInstance, # The Alterant here.
    actionName::Symbol,
    labels::Vararg{Symbol}
)
    actionName == :(:) || error("GoMeta internal invariant violated: setLabels called with actionName = ",
        actionName, " != :(:) — please report this (not reachable from any v0 input)")
    ## the guard (since v0.3.1, "fixed WITHIN THE Labels Alterant"): a lone ':' / ':()' names no label — the former refusal, kept
    isempty(labels) && error("GoMeta apply: empty label list — the labels action ':' ",
        "names no label; v0 requires at least one label (e.g. ':label1'); ",
        "see docs/public-api.md §3.4")
    s1 = String(labels[1])
    verb = :plain
    names = labels
    if s1 == "-" || s1 == "+"
        ## the LIST form: the sign the first member, the verb for every following name
        verb = s1 == "-" ? :withhold : :explicit
        names = labels[2:end]
        isempty(names) && error("GoMeta apply: the label statement `:(", s1, ")` names no label — the forms are `:", s1, "x` and `:(", s1,
            ", x, y)`; see docs/public-api.md §3.4")
    elseif startswith(s1, "-") || startswith(s1, "+")
        ## the PREFIXED form: one name after the sign
        verb = startswith(s1, "-") ? :withhold : :explicit
        length(labels) > 1 && error("GoMeta apply: the prefixed label statement `:", s1, "` takes one name — ", length(labels),
            " arguments given (the list form is `:(", s1[1:1], ", x, y)`); see docs/public-api.md §3.4")
        names = (Symbol(s1[2:end]),)
    end
    ## an EMPTY member (a stray comma) is refused as a shape in the SIGNED forms (`:(-, )`, `:(+, )`), checked over the whole statement before any
    ## name's sign; in a plain statement (`:(,)`) it keeps the former path — the vocabulary check refuses the empty name as unknown, as before
    ## (a later release decides its shape)
    (verb !== :plain && any(n -> isempty(String(n)), names)) && error("GoMeta apply: the label statement `:(", s1, ", )` names an empty label (a stray comma) — the forms are `:",
        s1, "x` and `:(", s1, ", x, y)`; see docs/public-api.md §3.4")
    for n in names
        ns = String(n)
        (startswith(ns, "+") || startswith(ns, "-")) && error("GoMeta apply: a label name may not begin with `+` or `-` inside a label list — got ",
            repr(ns), " (the sign stands at the head of a statement: `:-x`, `:(-, x, y)`, `:+x`, `:(+, x)`); see docs/public-api.md §3.4")
    end
    vocab = crntLabels.vocab.effective
    applied = crntLabels.applied
    withheld = crntLabels.withheld
    diags = nothing
    for n in names
        ## the closed check (the original engine's): the ∈-scan over the vocabulary's order; the refusal renders a SORTED display copy of the RUN's set
        n ∈ vocab || error("GoMeta apply: unknown label ", repr(first(String(n), 40)),
            " — not in the Labels Alterant's vocabulary (the accepted set = ",
            sort(copy(vocab)), "); see docs/public-api.md §3.4")
        if verb === :withhold
            delete!(applied, n)
            push!(withheld, n)
        elseif verb === :explicit
            applied[n] = true
            delete!(withheld, n)
        elseif n ∈ withheld
            diags === nothing && (diags = Diagnostic[])
            push!(diags, Diagnostic(:LABEL_NOT_APPLIED_WITHHELD, :warning,
                string("GoMeta apply: the plain `:", n, "` did not apply ", n, " here — withheld; if this run means to withhold it, nothing to do; ",
                       "drop `:-", n, "` (in the user level's profile or in the file) to apply it everywhere; write `:+", n,
                       "` where one statement must apply it regardless — a written `:+", n, "` then applies under every later withhold at that place; ",
                       "see docs/public-api.md §3.4"),
                (label = n,)))
        else
            applied[n] = true
        end
    end
    return diags
end

"the setter on a bare `Dict{Symbol,Bool}` — KEPT: a custom registration pairing the shipped setter with `altConstructor = Dict{Symbol,Bool}` checks against the base list, as before"
function setLabels(
    crntLabels::Dict{Symbol,Bool}, # The Alterant here.
    actionName::Symbol,
    labels::Vararg{Symbol}
)
    _setLabels!(crntLabels, base_vocabulary(), actionName, labels...)
end

function _setLabels!(
    applied::Dict{Symbol,Bool},
    vocab::Vector{Symbol},
    actionName::Symbol,
    labels::Vararg{Symbol}
)

    if actionName == :(:)
        ## The guard (since v0.3.1, "fixed WITHIN THE Labels Alterant"): a lone ':'
        ## (or ':()') reaches this setter with ZERO labels — the vacuous loop below then stored
        ## nothing, minted no evals row, and the author's mistyped label vanished SILENTLY
        ## (measured). The Alterant verifies its own input: an empty label list
        ## refuses loudly. error() (not ArgumentError): chosen when a former setter seam —
        ## since removed — reduced an ArgumentError to its type name; an ArgumentError now
        ## propagates with its message; kept as the Alterant's own refusal (the unknown-label mechanics below).
        isempty(labels) && error("GoMeta apply: empty label list — the labels action ':' ",
            "names no label; v0 requires at least one label (e.g. ':label1'); ",
            "see docs/public-api.md §3.4")
        ## the closed check (the original engine's): the ∈-scan over the vocabulary's order (never `insorted` over declaration
        ## order); the refusal renders a SORTED display copy of the accepted set — the RUN's effective vocabulary
        for label ∈ labels
            if label ∈ vocab
                applied[label] = true
            else
                error("GoMeta apply: unknown label ", repr(first(String(label), 40)),
                    " — not in the Labels Alterant's vocabulary (the accepted set = ",
                    sort(copy(vocab)), "); see docs/public-api.md §3.4")
            end
        end
    else
        error("GoMeta internal invariant violated: setLabels called with actionName = ",
            actionName, " != :(:) — please report this (not reachable from any v0 input)")
    end
end

"the checker on the `LabelsInstance`: the applied labels alone (the original engine's checker; the vocabulary plays no part in a query)"
function checkLabels(
    crntLabels::LabelsInstance, # The Alterant here.
    actionName::Symbol,
    labels::Vararg{Symbol}
)
    checkLabels(crntLabels.applied, actionName, labels...)
end

function checkLabels(
    crntLabels::Dict{Symbol,Bool}, # The Alterant here.
    actionName::Symbol,
    labels::Vararg{Symbol}
)
    ## The twin guard (since v0.3.1, with the setLabels guard above): the word-less
    ## label query ':()' reached this checker with ZERO labels and returned a vacuous TRUE —
    ## a wrong-outcome class; no corpus input depended on the vacuous form (measured at v0.3.1).
    isempty(labels) && error("GoMeta apply: empty label query — ':()' names no label to ",
        "check; v0 requires at least one label (e.g. ':(:label1)'); ",
        "see docs/public-api.md §3.4")
    ## no membership gate, no valve: a label outside the shipped set is simply not set — the query answers false
    ## (the original engine's checker, GoMetaRetro Alterants.jl :87–:99; the membership refusal of 0.3.2 and a write-only
    ## valve of the 0.4 development were removed before 0.4.0)
    for label ∈ labels
        if label ∉ keys(crntLabels)
            return false
        end
    end
    return true
end
