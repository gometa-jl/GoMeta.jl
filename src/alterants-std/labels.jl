## labels.jl — THE LABELS ALTERANT'S OWN FILE (the creator's words:
## 2026-08-22 — the whitelist "for some unknown reason hard part of GoMeta Core. That is a MISTAKE and must be rectified.
## It is NOT a new feature or improvement, it is fixing a bug."; 2026-10-08 — "a basic true Labels Alterant first, inside v0.4. Keep it SIMPLE AND
## ELEGANT."; 2026-10-23 — the vocabulary in a data file outside the Engine, a user's additions and removals persistent in a file of the user's own,
## the shipped file the backup, everything "as simple as possible to make it work AND … LEARN FROM OUR EXPERIENCE OF USING the Labels Alterant").
## Under `alterants-std/` — the std-Alterants' territory (never a Core literal; vocabulary_tests [10] scans `src/` around this directory).
##
## THE VOCABULARY FILES (0.4.3): TWO FILES of one form — one name per line, a line beginning with `#` a comment, blank lines ignored, each line's
## edges trimmed with the Engine's argument-edge class (`is_argument_space`, src/arguments.jl — the ordinary white space and six invisible
## separators), a character of that class INSIDE a name refused at the load with the line named. THE SHIPPED FILE
## `data/alterants-std/labels-vocabulary.txt` (the package's top-level data folder, located through the package's directory at run time; 46 names:
## `label1` … `label5`, `doc`, the 33 pictograph names in the glued form `label🍀`, and the everyday names `warning`, `note`, `info`, `definition`,
## `todo`, `public`, `private`) is READ-ONLY — no run writes it — and the revert source. THE USER FILE `~/.gometa/labels-vocabulary.txt` (another
## path through the environment variable `GOMETA_LABELS_VOCABULARY` — the test suite's temporary file, a project's own file) is created from the
## shipped file the first time a run needs the vocabulary, read ONCE and remembered by its stat (the path, the inode, the time stamp, the size —
## a file changed since is read again at the next need), and EDITED by the vocabulary statements. A missing shipped file refuses the run; a user
## file that cannot be created leaves the run reading the shipped file.
##
## THE VOCABULARY STATEMENTS (0.4.2; PERSISTENT since 0.4.3): `:++x` / `:(++, x, y)` ADD names to the vocabulary, `:--x` / `:(--, x)` REMOVE names
## from it (the creator's terms) — legal at `#~0` (a metaBlock opened by `#~0`) and in the user level's profile ONLY; RECORDED ONCE AT THE READ by
## the Engine's read-time hook (`onRead` on the registration record): consumed there, never enqueued, no evals row; effective from the apply of
## their own metaBlock onward; the malformed shapes refused; a declared name carrying a character of the argument-edge class INSIDE refused,
## and one beginning with `#` refused (the vocabulary file reads such a line as a comment).
## THE PERSISTENCE: a statement that changes the USER FILE's set writes the file (an added name appended as a line; a removed name's line removed;
## the comments kept; the write atomic — a temporary file renamed over the old) and reports every change by ONE `:info` Diagnostic
## (`LABELS_VOCABULARY_FILE_CHANGED`: the file, the change and the label as data) returned to the Engine's door at the read together with the run
## state (the registration record's one grammar for a hook's return); a file that cannot be written is reported by ONE `:warning` Diagnostic per
## change (`LABELS_VOCABULARY_FILE_NOT_WRITTEN`), the change holding for the run alone. A `++` of a name the file holds and a `--` of a name it
## does not hold write nothing and report nothing. A change written before a refusal later in the same run stands in the file and is
## reported by no row (the refusal throws; nothing is delivered). THE VOCABULARY OF A RUN: the BASE behind ONE function `base_vocabulary()` — the user file's
## names at the first need — and the run's ADDITIONS and REMOVALS kept APART (`LabelsVocabulary`); the effective set = base ∪ added − removed.
##
## THE WITHHOLD AND THE EXPLICIT APPLY (0.4.3): `:-x` / `:(-, x, y)` WITHHOLDS a label from the current set of labels applied to the current
## Component (and, through the Engine's walk, from every Component under its metaBlock until the slot is replaced — the Engine's own walk, no
## reach law of its own); `:+x` / `:(+, x)` APPLIES it explicitly, after a withhold or not; a PLAIN `:x` met by a withhold APPLIES NOTHING and is
## REPORTED — one `:warning` Diagnostic per statement and name at each such Component (`LABEL_NOT_APPLIED_WITHHELD`; a name a statement writes
## twice is reported twice), returned by the setter to the Engine's door (apply.jl), the run proceeding `PROCESS_OK` (the creator's design: the
## user informed and allowed to proceed; the file never rewritten for one run); the malformed shapes refused (the sign at the head of a
## statement, never inside a list); the instance's third field `withheld`. A withheld label read by a condition answers false silently.
##
## THE UNKNOWN LABEL (0.4.3): an applied name outside the run's vocabulary — never declared, removed, misspelled, or carrying an invisible
## character swallowed inside — is SKIPPED under every verb (not applied, not withheld, not applied explicitly) and REPORTED by ONE `:warning`
## Diagnostic per name occurrence (`LABEL_NOT_APPLIED_UNKNOWN`: the label as data; the message renders the statement's form per verb and the
## remedy — declare the name, or correct the spelling; the accepted set is not listed, it is one print away in the development tools), returned
## by the setter to the Engine's door, the run proceeding `PROCESS_OK`; a list applies its other names. The `Dict{Symbol,Bool}` setter method keeps
## the former REFUSAL naming the accepted set (a custom registration without the instance). A QUERIED unknown name answers false silently (the
## checker). An EMPTY member of a plain list — a stray comma — is a SHAPE and is refused, as it is in the signed lists.
##
## IS:   the Labels Alterant's code — the two vocabulary files' paths and reader (`shipped_vocabulary_path`, `user_vocabulary_path`,
##       `parse_vocabulary`, `base_vocabulary` with its memo), the persistence (`_persist_vocabulary!`), `LabelsVocabulary` (the run state) and
##       `LabelsInstance` (the per-Component instance: the applied labels, the run's vocabulary and the names withheld); the hook `declareLabels!`;
##       `setLabels` — the check against the RUN's vocabulary (an unknown name reported and skipped), the withhold and the explicit apply;
##       `checkLabels` — the original engine's checker (:87–:99): an unset or unknown name answers false. The `Dict{Symbol,Bool}` methods of the
##       setter and the checker STAY: a custom registration pairing them with `altConstructor = Dict{Symbol,Bool}` runs without the hook, the
##       setter's check the former refusal over the base (the original engine's scan, GoMetaRetro Alterants.jl :73–:78 at 47f0521).
## DOES: a run WITHOUT a vocabulary statement reads the user file once (its memo answers every later Component), applies every shipped and every
##       persisted name as before, reports an unknown one and proceeds; a run WITH vocabulary statements edits the user file at the read and
##       reports each change; the signed statements and a plain `:x` met by a withhold as 0.4.3's withhold (above).
## REASONING: the ∈-scan over the vector in declaration order (never `insorted` over an unsorted declaration); the joiner name (the broken
##       chain, U+200D inside) is one name — the argument-edge class carves the joiner and the variation selectors out; the memo on the file's stat
##       is the one read per run the creator asked for, a changed file seen at the next run (a `stat` per Component, never a read).
## PURPOSE: a basic, true Labels Alterant whose vocabulary lives in a data file a user extends and prunes for good, per file or per profile.

"the environment variable naming another user-level vocabulary file (the test suite's temporary file; a project's own); unset or empty: `~/.gometa/labels-vocabulary.txt`"
const LABELS_VOCABULARY_ENV = "GOMETA_LABELS_VOCABULARY"
"the shipped vocabulary file's path inside the package — the top-level data folder, located through the package's directory at run time (never a path baked at precompilation)"
const LABELS_VOCABULARY_SHIPPED_RELPATH = joinpath("data", "alterants-std", "labels-vocabulary.txt")

"the package's root directory at run time (`pkgdir`); the source tree's root where the package was not loaded as a package"
_package_root() = (d = pkgdir(@__MODULE__); d === nothing ? normpath(joinpath(@__DIR__, "..", "..")) : d)
"THE SHIPPED FILE — read-only, the revert source"
shipped_vocabulary_path() = joinpath(_package_root(), LABELS_VOCABULARY_SHIPPED_RELPATH)
"THE USER FILE — the environment variable's path when set and not empty, else `~/.gometa/labels-vocabulary.txt`"
function user_vocabulary_path()
    p = get(ENV, LABELS_VOCABULARY_ENV, "")
    return isempty(p) ? joinpath(homedir(), ".gometa", "labels-vocabulary.txt") : p
end

"""
    parse_vocabulary(text, path) -> Vector{Symbol}

THE FORM of a vocabulary file: one name per line; a line whose first character after the edge trim is `#` is a comment; a blank line is
ignored; each line's two edges are trimmed with the Engine's argument-edge class (`is_argument_space`); a character of that class INSIDE a
name refuses the file with the line named and the name shown by its escapes; a name written twice counts once (its first place kept).
"""
function parse_vocabulary(text::AbstractString, path::AbstractString)
    names = Symbol[]
    for (i, raw) in enumerate(split(text, '\n'))
        line = strip(is_argument_space, raw)
        (isempty(line) || startswith(line, "#")) && continue
        any(is_argument_space, line) &&
            error("GoMeta labels: the vocabulary file ", path, " carries white space or an invisible character inside a label name at line ", i,
                  " — got ", repr(String(line)), "; one name per line; see docs/public-api.md §2")
        n = Symbol(line)
        n ∈ names || push!(names, n)
    end
    return names
end

"the memo of the one read: the file's path, inode, time stamp and size, and its names — a changed file is read again at the next need"
mutable struct _VocabularyMemo
    path::String
    inode::UInt
    mtime::Float64
    size::Int64
    names::Vector{Symbol}
end
const _VOCAB_MEMO = Ref{Union{Nothing,_VocabularyMemo}}(nothing)
const _VOCAB_LOCK = ReentrantLock()

"an atomic write: the text to a temporary file beside the target, renamed over it (the directory created)"
function _atomic_write(path::AbstractString, text::AbstractString)
    mkpath(dirname(path))
    tmp = string(path, ".", getpid(), ".tmp")
    try
        open(tmp, "w") do io
            write(io, text)
        end
        Base.Filesystem.rename(tmp, path)
    catch
        rm(tmp; force = true)   # a failed write or rename leaves no temporary file beside the target
        rethrow()
    end
    return nothing
end

"the shipped file's text — a missing shipped file refuses the run (a fault of the installation, not of the file processed)"
function _shipped_vocabulary_text()
    sp = shipped_vocabulary_path()
    isfile(sp) || error("GoMeta labels: the Labels Alterant's shipped vocabulary file is missing — expected at ", sp, "; see docs/public-api.md §2")
    return read(sp, String)
end

"""
    base_vocabulary() -> Vector{Symbol}

THE BASE VOCABULARY OF A RUN — ONE function: the USER FILE's names (`user_vocabulary_path()`), the file created from the shipped one the first
time it is needed, read once and remembered by its stat — a file changed since (by a vocabulary statement of this or another run, or by hand)
is read again at the next call; a user file that cannot be created (a home that cannot be written) leaves the run reading the shipped file. The
returned vector is shared and never mutated (the persistence writes the file; the memo follows). A `stat` per call, never a read.
"""
function base_vocabulary()
    lock(_VOCAB_LOCK) do
        p = user_vocabulary_path()
        if !isfile(p)
            text = _shipped_vocabulary_text()
            try
                _atomic_write(p, text)
            catch e
                e isa InterruptException && rethrow()
                p = shipped_vocabulary_path()      # the user file cannot be created: the shipped file read directly
            end
        end
        s = stat(p)
        m = _VOCAB_MEMO[]
        if m !== nothing && m.path == p && m.inode == s.inode && m.mtime == s.mtime && m.size == s.size
            return m.names
        end
        names = parse_vocabulary(read(p, String), p)
        _VOCAB_MEMO[] = _VocabularyMemo(p, s.inode, s.mtime, s.size, names)
        return names
    end
end

"""
    _persist_vocabulary!(adding, names) -> Vector{Diagnostic}

THE PERSISTENCE of a vocabulary statement: the USER FILE edited where the statement changes ITS set — an added name not yet in the file is
appended as a line; a removed name's lines are removed; comments and blank lines kept; the write atomic. Returns the rows for the Engine's
door: one `:info` `LABELS_VOCABULARY_FILE_CHANGED` per change (the file, the change `:added` / `:removed` and the label as data); where the
file cannot be written, one `:warning` `LABELS_VOCABULARY_FILE_NOT_WRITTEN` per change naming the fault, the change holding for the run alone.
"""
_persist_vocabulary!(adding::Bool, names::Vector{Symbol}) = lock(() -> _persist_vocabulary_locked!(adding, names), _VOCAB_LOCK)   # the read-modify-write under the one lock (reentrant: `base_vocabulary()` takes it again inside)

function _persist_vocabulary_locked!(adding::Bool, names::Vector{Symbol})
    rows = Diagnostic[]
    current = base_vocabulary()
    p = user_vocabulary_path()
    todo = unique(adding ? [n for n in names if n ∉ current] : [n for n in names if n ∈ current])
    isempty(todo) && return rows
    sign = adding ? "++" : "--"
    try
        isfile(p) || error("the user file does not exist and could not be created")
        text = read(p, String)
        if adding
            (isempty(text) || endswith(text, "\n")) || (text *= "\n")
            text *= join(String.(todo), "\n") * "\n"
        else
            keep = String[]
            for l in split(text, '\n')
                t = strip(is_argument_space, l)
                (!isempty(t) && !startswith(t, "#") && Symbol(t) ∈ todo) || push!(keep, String(l))
            end
            text = join(keep, "\n")
        end
        _atomic_write(p, text)
    catch e
        e isa InterruptException && rethrow()
        for n in todo
            push!(rows, Diagnostic(:LABELS_VOCABULARY_FILE_NOT_WRITTEN, :warning,
                string("GoMeta absorb: `:", sign, n, "` could not be written to the vocabulary file ", p, " (", sprint(showerror, e),
                       ") — the change holds for this run alone; see docs/public-api.md §2"),
                (file = p, change = adding ? :added : :removed, label = n)))
        end
        return rows
    end
    for n in todo
        push!(rows, Diagnostic(:LABELS_VOCABULARY_FILE_CHANGED, :info,
            adding ? string("GoMeta absorb: `:++", n, "` added ", n, " to the vocabulary file ", p,
                            " — it holds for this run and every later one; `:--", n, "` removes it again; see docs/public-api.md §2") :
                     string("GoMeta absorb: `:--", n, "` removed ", n, " from the vocabulary file ", p,
                            " — it is unknown for this run and every later one; `:++", n, "` adds it again (the shipped file keeps the original list); see docs/public-api.md §2"),
            (file = p, change = adding ? :added : :removed, label = n)))
    end
    return rows
end

"""
    LabelsVocabulary

THE RUN STATE of the Labels Alterant: the BASE (the user file's names at the first need), the run's ADDITIONS and its REMOVALS kept APART, and
the EFFECTIVE set = base ∪ added − removed, in that order, recomputed by the hook after every vocabulary statement. Minted by the hook's first
consumed statement (`ProcessState.alt_run`); dies with the call (the file carries what persists).
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
    declareLabels!(run, mhIdx, actionName, args, hasCondition) -> nothing | LabelsVocabulary | (LabelsVocabulary, Vector{Diagnostic})

THE READ-TIME HOOK of the Labels Alterant (the registration record's `onRead`): called by `absorbMeta` for
every `:` statement WITH arguments, before the slot bound. Returns `nothing` for a plain label statement (the Engine enqueues it as
stated) and, for a VOCABULARY statement — consumed at the read: the Engine stores the run state as this Alterant's and ends the statement's
processing (no slot action, no row) — the run's vocabulary alone where the user file is unchanged, or the run's vocabulary WITH the rows
reporting the file's change (one `:info` row per added or removed name; a `:warning` row where the file could not be written), which the
Engine delivers with the read-time place. THE CHECKS, in this order: the PLACE (a metaBlock opened by `#~0` or the user level's profile;
nothing else), then the malformed shapes: (iv) the prefixed sign with several arguments, (iii) no name or an empty member, (ii) a declared name
beginning with a sign, (vi) a declared name beginning with `#`, (v) a declared name carrying a character of the argument-edge class inside, (i) a condition. Every refusal carries the
read-time prefix "GoMeta absorb:". THE FOLD: `++n` — `n` leaves `removed` and joins `added` unless it is in the base or already added;
`--n` — `n` leaves `added` and joins `removed` if it is in the base and not yet removed; `--` of a name never present is a no-op; the
last statement in reading order wins. THE PERSISTENCE follows the fold (`_persist_vocabulary!`). A quoted (String) token among the arguments
is never a vocabulary statement: handed back, it meets the Engine's String-slot law at the enqueue as before.
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
    ## the prefixed form's name trimmed at its own edges with the Engine's class (the sign is glued, so the name's leading edge is inside the argument the Engine trimmed)
    names = length(s1) > 2 ? Symbol[Symbol(strip(is_argument_space, s1[3:end]))] : Symbol[Symbol(String(a)) for a in args[2:end]]
    ## (iii) no name
    isempty(names) &&
        error("GoMeta absorb: the vocabulary statement `:", s1, "` names no label — the forms are `:", sign, "x` and `:(", sign, ", x, y)`; see docs/public-api.md §3.4")
    ## (iii) too — an EMPTY member, a stray comma (`:(++,)`, `:(++, x, )`, `:(--,)`): the splitter hands the empty piece on and the
    ## Alterant decides (absorb_meta.jl `_split_args`); a member that names no label is refused like no name at all
    any(n -> isempty(String(n)), names) &&
        error("GoMeta absorb: the vocabulary statement `:", s1, "` names an empty label (a stray comma) — the forms are `:", sign, "x` and `:(", sign, ", x, y)`; see docs/public-api.md §3.4")
    ## (ii) a declared name beginning with a sign (the signed statements `:+x` / `:-x` are the setter's own since 0.4.3 — a declared name never carries a sign)
    for n in names
        ns = String(n)
        (startswith(ns, "+") || startswith(ns, "-")) &&
            error("GoMeta absorb: a label name in a vocabulary statement may not begin with `+` or `-` — got ", repr(ns), " in `:", s1, "`; see docs/public-api.md §3.4")
    end
    ## (vi) a declared name beginning with `#` — the vocabulary file reads a line beginning with `#` as a comment, so such a name could not be kept
    for n in names
        ns = String(n)
        startswith(ns, "#") &&
            error("GoMeta absorb: a label name in a vocabulary statement may not begin with `#` — got ", repr(ns), " in `:", _shown(s1), "` (the vocabulary file reads a line beginning with `#` as a comment); see docs/public-api.md §3.4")
    end
    ## (v) a declared name carrying white space or an invisible separator INSIDE (the edges arrive trimmed — the argument's from the Engine, the
    ## prefixed name's own above; the joiner and the variation selectors of the pictograph names are not of the class)
    for n in names
        ns = String(n)
        any(is_argument_space, ns) &&
            error("GoMeta absorb: a label name in a vocabulary statement may not carry white space or an invisible character inside — got ", repr(ns), " in `:", _shown(s1), "`; see docs/public-api.md §3.4")
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
    _recompute_effective!(v)
    rows = _persist_vocabulary!(adding, names)
    return isempty(rows) ? v : (v, rows)
end

"a text as a message shows it: an invisible or unprintable character shown by its escape (the quotes of `repr` dropped)"
_shown(s::AbstractString) = (e = repr(String(s)); e[nextind(e, firstindex(e)):prevind(e, lastindex(e))])
"the name as a message shows it: cut at 40 characters, then as `_shown` shows a text"
_shown_name(n::Symbol) = (s = String(n); length(s) > 40 ? _shown(first(s, 40)) * "…" : _shown(s))

"the unknown label's message — the statement's FORM per verb, the remedy; the accepted set not listed (the development tools print it)"
function _unknown_message(verb::Symbol, n::Symbol)
    s = _shown_name(n)
    form = verb === :withhold ? string("the withhold `:-", s, "`") : verb === :explicit ? string("the explicit `:+", s, "`") : string("the plain `:", s, "`")
    return string("GoMeta apply: ", form, " had no effect here — not in the Labels Alterant's vocabulary; declare it with `:++", s,
                  "` at `#~0` or in the user level's profile, or correct the spelling; see docs/public-api.md §3.4")
end

"""
    setLabels(inst::LabelsInstance, :(:), tokens...) -> nothing | Vector{Diagnostic}

THE SETTER ON THE `LabelsInstance`: the sign is read from the FIRST token alone — `-` or `+` as the whole first token is the LIST form (the verb
for every following name: `:(-, x, y)`, `:(+, x)`), a first token beginning with `-` / `+` and longer is the PREFIXED form (one name: `:-x`,
`:+x`), any other first token a PLAIN statement (every token a name — the former path). THE SHAPES refused with GoMeta's message at the apply
(the standing class, out of the call): the prefixed sign with several arguments; a sign with no name; an empty member of ANY list — a stray
comma (the signed lists since the withhold, the plain list since the vocabulary files); a name beginning with a sign — after a prefixed sign
(`:+-x`), inside a signed list and inside a PLAIN list alike (the mixed list `:(x, -y)`): the sign stands at the head of a statement, never
inside a list. PER NAME, in token order: THE VOCABULARY CHECK — a name outside the run's vocabulary is SKIPPED under every verb and REPORTED
(one `Diagnostic` of severity `:warning` per name occurrence, code `LABEL_NOT_APPLIED_UNKNOWN`, the label as data in its context; the message
renders the statement's form per verb — the plain `:zzz`, the withhold `:-zzz`, the explicit `:+zzz` — and the remedy); then THE VERB:
WITHHOLD — the name leaves the applied set and joins the withheld set (a name not applied: the same, a harmless no-op in the delivery); APPLY
EXPLICITLY — the name joins the applied set and leaves the withheld set; PLAIN — a name WITHHELD here applies nothing and is REPORTED (one
`:warning` per such name, code `LABEL_NOT_APPLIED_WITHHELD`, the label as data); every other name applies. The rows are RETURNED to the Engine,
which attaches the place and delivers them with the run's result; the run proceeds, the status untouched (the creator's design: the user
informed and allowed to proceed, the file never rewritten for one run). A withhold reaches every Component whose walk includes its
statement's slot — the Engine's own walk, no reach law here. The `Dict{Symbol,Bool}` method below is untouched (a custom registration pairing
it with the shipped setter keeps the former scan and its refusal).
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
        names = (Symbol(strip(is_argument_space, s1[2:end])),)   # the name after the glued sign trimmed at its own edges (the Engine trimmed the argument's)
    end
    ## an EMPTY member (a stray comma) is refused as a SHAPE in every form — the signed lists (`:(-, )`, `:(+, )`) and the plain list (`:(,)`,
    ## `:(label1, )`, `:(, label1)`) alike — checked over the whole statement before any name's sign
    if any(n -> isempty(String(n)), names)
        verb === :plain && error("GoMeta apply: the label statement `:(", join(String.(labels), ", "),
            ")` names an empty label (a stray comma) — the forms are `:x` and `:(x, y)`; see docs/public-api.md §3.4")
        error("GoMeta apply: the label statement `:(", s1, ", )` names an empty label (a stray comma) — the forms are `:",
            s1, "x` and `:(", s1, ", x, y)`; see docs/public-api.md §3.4")
    end
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
        if n ∉ vocab
            ## THE UNKNOWN LABEL: skipped under every verb and reported (the ∈-scan over the run's vocabulary in its order)
            diags === nothing && (diags = Diagnostic[])
            push!(diags, Diagnostic(:LABEL_NOT_APPLIED_UNKNOWN, :warning, _unknown_message(verb, n), (label = n,)))
        elseif verb === :withhold
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
                       "` where one statement must apply it regardless — a written `:+", n, "` then holds against a withhold stated above it or in the user level's profile; ",
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
