# find_by_label.jl — the "find it again" demo: process the committed examples, index the
# evaluated label surface, and answer "which pieces of which files carry this label?".
#
# What it does, end to end:
#   1. runs `GoMeta.goMeta` on every input in `examples/InFileFolder/` (trusted committed
#      input — see the SECURITY section of the README before running GoMeta on files you
#      did not write);
#   2. asks the Engine, through the BLS Component tree, which Components got label values —
#      `GoMeta.scanAlterant(delivery, :labels)`, each with its sorted label names — and reads
#      each piece's text through BLS's door (`GoMeta.BLS.content`); the evals rows themselves
#      (`GoMeta.readAltValuesEvals`) are counted, not joined;
#   3. builds a label → pieces index across all files, remembering each piece's visibility;
#   4. answers a query: which pieces carry the label, in which file, and each piece's resolved
#      visibility — the Engine's ANSWER (`GoMeta.evaluatedAltValue(delivery, component, :Visib)`: the
#      piece's own Visib rows, else its parent's up the tree, else the declared default `:show`;
#      the former literal `:show` for a piece without a row of its own is now the answer's
#      default source). An enclosing discarded region's verdict reaches a piece through the
#      answer's inheritance (the corpus-documented nesting semantics).
#
# Run from the repository root (after `Pkg.instantiate()`):
#   julia --startup-file=no --project=. extensions/find_by_label.jl            # per-label overview
#   julia --startup-file=no --project=. extensions/find_by_label.jl label5     # one label, all hits
#   (the file lives under extensions/; run it from the repository's root)
#
# The corpus-documented labels are `:label1`..`:label5`; since 0.3.0 the closed whitelist also
# accepts a fixed pictograph vocabulary, and since 0.4.0 `:doc` — the whole list
# hard-coded in `src/alterants-std/labels.jl` (this driver's index covers the corpus labels).
# A query outside that set is refused with the accepted list — the engine-side refusal
# behaviour for out-of-whitelist names is documented in `docs/public-api.md` §3.4.

import GoMeta

const EXAMPLES = joinpath(@__DIR__, "..", "examples", "InFileFolder")   # the file lives under extensions/
const LABELS   = [:label1, :label2, :label3, :label4, :label5]

# one indexed occurrence: the file it came from, the piece's verbatim CONTENT bytes (read
# through BLS's door, `GoMeta.BLS.content`, from the delivered BLS Component tree), and the
# piece's resolved visibility — the Engine's answer (:show / :hide / :discard)
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
        # the pieces that carry labels, THROUGH THE TREE: the Components
        # that got label values, each with its sorted label names; the piece's text through the door; its
        # visibility the Engine's answer. The hits per file come in tree order (formerly the rows' order).
        tree = result.blsComponentTree
        n_evals += length(GoMeta.readAltValuesEvals(result.altValues_evals))
        for (c, a) in GoMeta.scanAlterant(result, :labels)
            visib = GoMeta.evaluatedAltValue(result, c, :Visib).value
            for l in a.value
                l in LABELS || continue
                push!(index[l], Hit(f, GoMeta.BLS.content(tree, c), visib))
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
