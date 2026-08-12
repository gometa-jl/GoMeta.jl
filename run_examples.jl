# run_examples.jl — the runnable driver for the GoMeta example corpus.
#
# IS:   the corpus driver: it processes every input in examples/InFileFolder/ through GoMeta and
#       verifies the rendered output against the committed examples/OutFileFolder/ reference files.
# DOES: per input: bytes -> goMeta -> outputs; writes the render to a scratch folder
#       (printed at the end; pass --out <dir> to keep the renders somewhere specific) and reports
#       byte-agreement per file. Exit code 0 = every render byte-identical to the committed
#       reference. The committed reference outputs are never overwritten.
# REASONING: the corpus is, at once — (a) a regression set: input -> render -> compare against the
#       committed reference; (b) an illustration of GoMeta syntax + behaviour: every input file is
#       self-explanatory (its ## comments state the expected behaviour AND the reason why); and
#       (c) a hypothesis playfield: copy or edit an input, rerun, and READ the resulting render to
#       see the effect.
# PURPOSE: one runnable, verifiable, self-documenting source of GoMeta ground-truth.
#
# RUN (from the repository root, after `Pkg.instantiate()`):
#   julia --startup-file=no --project=. run_examples.jl [--out <dir>]

import GoMeta as GM

const HERE   = @__DIR__
const INDIR  = joinpath(HERE, "examples", "InFileFolder")
const REFDIR = joinpath(HERE, "examples", "OutFileFolder")

function main()
    outdir = ""
    i = 1
    while i <= length(ARGS)
        if ARGS[i] == "--out" && i < length(ARGS)
            outdir = abspath(ARGS[i+1]); i += 2
        else
            error("usage: julia --startup-file=no --project=. run_examples.jl [--out <dir>]")
        end
    end
    isempty(outdir) && (outdir = mktempdir(; cleanup = false))
    canon(p) = ispath(p) ? realpath(p) : abspath(p)
    canon(outdir) in (canon(REFDIR), canon(INDIR)) &&
        error("refusing --out $(outdir): that is the committed corpus folder")
    mkpath(outdir)
    inputs = sort(filter(f -> endswith(f, ".jl"), readdir(INDIR)))
    isempty(inputs) && error("no inputs found under $INDIR")
    n_match = 0
    for f in inputs
        bytes = read(joinpath(INDIR, f))
        r = GM.goMeta(bytes)
        r.status == GM.PROCESS_OK ||
            error("goMeta() reported a non-OK status on $f — diagnostics: $(r.diagnostics)")
        out = GM.outputs(r)
        dest = joinpath(outdir, f)
        (islink(dest) || isfile(dest)) &&
            error("refusing to overwrite an existing entry at $dest — use an empty --out directory")
        write(dest, out.render_bytes)
        ref = joinpath(REFDIR, f)
        agree = isfile(ref) && read(ref) == out.render_bytes
        agree && (n_match += 1)
        println(rpad(f, 45), agree ? "byte-identical to the committed reference" :
                                     "DIFFERS from the committed reference")
    end
    println()
    println("rendered $(length(inputs)) inputs -> $outdir")
    println("byte-agreement with examples/OutFileFolder: $n_match/$(length(inputs))")
    exit(n_match == length(inputs) ? 0 : 1)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
