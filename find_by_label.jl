# find_by_label.jl — the "find it again" demo: process the committed examples, index the
# evaluated label surface, and answer "which pieces of which files carry this label?".
#
# What it does, end to end:
#   1. runs `GoMeta.goMeta` on every input in `examples/InFileFolder/` (trusted committed
#      input — see the SECURITY section of the README before running GoMeta on files you
#      did not write);
#   2. collects each file's evaluated Alterant values via `GoMeta.altValues_evals` (+ the
#      cells' verbatim content via `GoMeta.content_fingerprint`, same order by contract) —
#      tuples of (occurrence-handle bytes, attribute, value, polarity), where labels appear as
#      `:label_label1` .. `:label_label5` and the visibility outcome as `:visib`;
#   3. builds a label → cells index across all files, remembering each cell's visibility;
#   4. answers a query: which cells carry the label, in which file, and each cell's OWN
#      evaluated visibility verdict (`:visib`; `:show` when the cell carries none). The
#      verdict is per-cell — an enclosing discarded region can remove content beyond a
#      cell's own verdict (the corpus-documented nesting semantics).
#
# Run from the repository root (after `Pkg.instantiate()`):
#   julia --startup-file=no --project=. find_by_label.jl            # per-label overview
#   julia --startup-file=no --project=. find_by_label.jl label5     # one label, all hits
#
# The corpus-documented labels are `:label1`..`:label5`; since 0.3.0 the closed whitelist also
# accepts a fixed pictograph vocabulary (this driver's index covers the corpus labels).
# A query outside that set is refused with the accepted list — the engine-side refusal
# behaviour for out-of-whitelist names is documented in `docs/public-api.md` §3.4.

import GoMeta

const EXAMPLES = joinpath(@__DIR__, "examples", "InFileFolder")
const LABELS   = [:label1, :label2, :label3, :label4, :label5]

# one indexed occurrence: the file it came from, the cell's verbatim CONTENT bytes (from
# the `content_fingerprint` sibling accessor — the evals KEY is the structural occurrence
# handle since v0.2 and is opaque here), and the cell's OWN evaluated visibility entry
# (:show / :hide / :discard; :show when the cell itself carries no :visib entry — the
# per-cell verdict this demo reports)
struct Hit
    file::String
    cell::Vector{UInt8}
    visib::Symbol
end

function first_line_excerpt(cell::Vector{UInt8}; width::Int = 64)
    s = String(copy(cell))
    # some cells begin with a newline byte — excerpt the first line a reader would see
    lines = filter(!isempty, strip.(split(s, '\n'; keepempty = false)))
    stripped = isempty(lines) ? "(blank cell)" : first(lines)
    length(stripped) > width ? first(stripped, width) * "…" : String(stripped)
end

function index_examples()
    isdir(EXAMPLES) || error("the examples folder is missing beside this script ($EXAMPLES) — run it from a full repository checkout")
    files = sort(filter(f -> endswith(f, ".jl"), readdir(EXAMPLES)))
    isempty(files) && error("no example inputs found under $EXAMPLES — the committed corpus ships with the repository checkout")
    index = Dict(l => Hit[] for l in LABELS)
    n_evals = 0
    n_skipped = 0
    for f in files
        bytes  = read(joinpath(EXAMPLES, f))
        # a malformed input is typically REFUSED by the engine with a stable message
        # (docs/public-api.md §3; a few documented edges stay raw at v0) — whatever the
        # failure form, the demo reports it and moves on, so an edited example (the
        # syntax reference's "TRY IT" flow) never ends in a stack trace
        result = try
            GoMeta.goMeta(bytes)
        catch err
            println(stderr, "skipping $f — processing failed: ",
                    first(split(sprint(showerror, err), '\n')))
            n_skipped += 1
            continue
        end
        if result.status != GoMeta.PROCESS_OK
            println(stderr, "skipping $f — processing did not complete ($(result.status))")
            n_skipped += 1
            continue
        end
        evals = GoMeta.altValues_evals(result)
        fps   = GoMeta.content_fingerprint(result)   # same order as evals, by contract
        length(evals) == length(fps) ||
            error("find_by_label: evals/fingerprint arity diverged — the accessors' contract broke")
        content = Dict{Vector{UInt8},Vector{UInt8}}(h => c for (h, c) in fps)
        n_evals += length(evals)
        # per cell (keyed by the occurrence handle): the visibility outcome (if any) …
        visib = Dict{Vector{UInt8},Symbol}()
        for (cell, attr, value, _) in evals
            attr === :visib && (visib[cell] = value)
        end
        # … and one Hit per (cell × carried label); the Hit carries the cell's CONTENT bytes
        # (reader-facing); a cell with no :visib entry of its own gets the :show per-cell
        # verdict here (see the Hit comment for the scope caveat)
        for (cell, attr, value, _) in evals
            for l in LABELS
                if attr === Symbol("label_", l) && value === true
                    haskey(content, cell) ||
                        error("find_by_label: evals handle missing from the fingerprint map — the accessors' key contract broke")
                    push!(index[l], Hit(f, content[cell], get(visib, cell, :show)))
                end
            end
        end
    end
    return (index, length(files) - n_skipped, n_evals, n_skipped)
end

function main()
    (index, n_files, n_evals, n_skipped) = index_examples()
    println("processed $n_files files → $n_evals evaluated entries",
            n_skipped > 0 ? " ($n_skipped file(s) skipped — see the messages above)" : "")
    if isempty(ARGS)
        println("\nlabel overview (pass a label name for the full hit list, e.g. `label5`):")
        for l in LABELS
            hits = index[l]
            println(rpad("  :$l", 12), length(hits), " cell(s) in ",
                    length(unique(h.file for h in hits)), " file(s)")
        end
        return
    end
    query = Symbol(replace(ARGS[1], r"^:" => ""))
    query in LABELS || begin
        println("\n\"", ARGS[1], "\" is not one of the accepted labels — the documented set is ",
                join(string.(":", LABELS), " "))
        return
    end
    hits = index[query]
    println("\n:$query — $(length(hits)) cell(s) in $(length(unique(h.file for h in hits))) file(s):")
    for f in sort(unique(h.file for h in hits))
        println("  examples/InFileFolder/", f)
        for h in filter(h -> h.file == f, hits)
            println("    • \"", first_line_excerpt(h.cell), "\"   [visib: ", h.visib, "]")
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    # script use gets a clean one-line message + a nonzero status instead of a stack
    # trace; loading the file from elsewhere (e.g. a notebook) keeps normal exceptions
    try
        main()
    catch err
        err isa ErrorException || rethrow()
        println(stderr, "find_by_label: ", err.msg)
        exit(1)
    end
end
