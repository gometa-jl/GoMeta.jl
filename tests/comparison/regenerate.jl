# tests/comparison/regenerate.jl — THE DRIVER of the reference set's comparison forms:
#   writes, or checks, the twelve forms of the corpus inputs — the seven under
#   examples/InFileFolder/ and the five under tests/golden/constructed/InFileFolder/ — as tests/comparison/<stem>.cmp.txt.
#
# IS:   the one way the committed reference forms are produced; the check that they still equal what the tree produces.
# DOES: --at <sha>  writes the twelve (the header names the producing commit — the code home's HEAD the forms were made
#                   at; the caller states it); --out <dir> writes elsewhere (never over a committed file without --at);
#       --check     produces the twelve in memory and compares each BODY (the lines after the header) with the committed
#                   file's body; prints one line per input; exit 0 = every body equal, 1 = a difference or a missing file.
# REASONING: the forms are frozen as the reference set (the creator's decision of 2026-10-03; tests/comparison/README.md)
#       — the check is a drift alarm on the tree, not a byte law (the byte law's three families are
#       the golden layer's); a changed body is re-made with --at <the re-making commit's parent sha> on the commit that changes it, named in that
#       commit's message.
# PURPOSE: the twelve forms — v0.4's reference altValues (the creator's term of 2026-09-29, provisional) — versioned with the
#       v0.4 commit that produced them.
#
#   GM=<the repository root>
#   julia --startup-file=no --project=$GM/tests $GM/tests/comparison/regenerate.jl --check
#   julia --startup-file=no --project=$GM/tests $GM/tests/comparison/regenerate.jl --at <short sha> [--out <dir>]

import GoMeta
const _RG_HOME = normpath(joinpath(@__DIR__, "..", ".."))
include(joinpath(_RG_HOME, "devtools", "load_basic_renderer.jl"))   # the ONE path to the basic renderer
include(joinpath(_RG_HOME, "devtools", "devtools.jl"))               # the tools — comparisonForm lives there (§I)

const _RG_INPUT_DIRS = (joinpath(_RG_HOME, "examples", "InFileFolder"),
                        joinpath(_RG_HOME, "tests", "golden", "constructed", "InFileFolder"))

function _rg_inputs()
    out = Tuple{String,String}[]
    for d in _RG_INPUT_DIRS
        for f in sort(filter(f -> endswith(f, ".jl"), readdir(d)))
            push!(out, (f[1:end-3], joinpath(d, f)))
        end
    end
    out
end

_rg_body(text::AbstractString) = join(filter(l -> !startswith(l, "#"), split(chomp(String(text)), '\n')), "\n")

function main()
    at = ""; outdir = @__DIR__; check = false
    i = 1
    while i <= length(ARGS)
        if ARGS[i] == "--at" && i < length(ARGS)
            at = ARGS[i+1]; i += 2
        elseif ARGS[i] == "--out" && i < length(ARGS)
            outdir = abspath(ARGS[i+1]); i += 2
        elseif ARGS[i] == "--check"
            check = true; i += 1
        else
            error("usage: regenerate.jl --check | --at <short sha> [--out <dir>]")
        end
    end
    check || !isempty(at) || error("regenerate.jl: --at <short sha> is required to write (the header names the producing commit); use --check to compare")
    inputs = _rg_inputs()
    length(inputs) == 12 || error("regenerate.jl: expected the twelve corpus inputs, found $(length(inputs))")
    nbad = 0
    for (stem, path) in inputs
        r = GoMeta.goMeta(read(path))
        r.status == GoMeta.PROCESS_OK || error("regenerate.jl: goMeta reported $(r.status) on $stem — $(r.diagnostics)")
        dest = joinpath(outdir, stem * ".cmp.txt")
        if check
            text = comparisonForm(r; name = stem, at = "-")
            if !isfile(dest)
                nbad += 1; println(rpad(stem, 42), "MISSING: ", dest)
            elseif _rg_body(read(dest, String)) == _rg_body(text)
                println(rpad(stem, 42), "the committed form equals the tree's (body)")
            else
                nbad += 1; println(rpad(stem, 42), "DIFFERS from the committed form — re-make with --at <sha> in the commit that changes it")
            end
        else
            mkpath(outdir)
            writeComparisonFormToFile(dest, r; name = stem, at = at)
            println(rpad(stem, 42), "written: ", dest)
        end
    end
    check && println(nbad == 0 ? "regenerate.jl --check: the twelve committed forms equal the tree's" : "regenerate.jl --check: $nbad of 12 differ or are missing")
    exit(nbad == 0 ? 0 : 1)
end

main()
