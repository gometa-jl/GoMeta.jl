# gometa.jl — one-liner access to GoMeta's surfaces (AGENT-RULES_GoMeta.md §R4 / §R4b).
#   A DEVELOPMENT TOOL: not part of the GoMeta process — the package never references this
#   file; it imports GoMeta, runs one file and prints. Lives in the GoMeta code home's
#   devtools/ since 2026-08-29 (owner ruling R-V04B-17); the Play keeps its own frozen copy
#   since 2026-09-12 (OWNER-WORDS §26 — a self-contained fork).
#
# usage (works from ANY directory; --project selects WHICH GoMeta runs):
#   GM=/home/fido/Dropbox/_01_Crypto_Dropbox/07_Claude/GoMetaEcosystem/GoMeta
#   julia --startup-file=no --project=$GM/tests $GM/devtools/gometa.jl <verb> <file>
#
#   tree       — the BLS component tree, line-mapped 1:1 (the R1 component data, raw)
#   segments   — the same tree with line numbers (the "what is line N?" answer)
#   evals      — the verdict rows: <attr> => <value> (polarity)  "cell excerpt" (⏎ = in-cell newline)
#   render     — the share-view bytes (pure on stdout; `> file` captures the recipient view)
#   trace      — the evals rows + each row's DECODED cell_handle (ns · grain · path · origin; schema-gated)
#   evals-tree — print_altValues_evals in the FULL form (devtools.jl: layout=:tree,
#                include_empty=true, show_handles=true): every Component, absence labelled
#   bls-tree   — print_BLS_Component_Tree (devtools.jl: style=:mix): the tree with every
#                Component's named-int + settribute state
#
# Evaluates, never executes. Status + diagnostics go to stderr; the surface to stdout.

import GoMeta
include(joinpath(@__DIR__, "load_basic_renderer.jl"))   # the ONE path to the basic renderer (R-V04B-24 obligation 7)

const _VERBS = ("tree", "segments", "evals", "render", "trace", "evals-tree", "bls-tree")

## The two print-tool verbs need devtools.jl (same directory); loaded at top level BEFORE
## main() runs so its methods are in the world main() is compiled in.
if length(ARGS) == 2 && ARGS[1] in ("evals-tree", "bls-tree")
    include(joinpath(@__DIR__, "devtools.jl"))
end

function fail_usage()
    println(stderr, "usage: gometa.jl <", join(_VERBS, "|"), "> <file>")
    exit(2)
end

# ── trace helpers: cell_handle decode (owner ruling R-CAP-5) ─────────────────────────────
# Layout per the key_bytes docblock (src/occurrence.jl:210-216): schema_version(1B) ·
# namespace(UInt16-BE byte-length prefix + UTF-8) · grain(1B) · path(UInt16-BE step count,
# then per step: store(1B) + ordinal(UInt32-BE)) · origin(same shape as path). The
# namespace length is PARSED — offsets after it are never hard-coded.

rd_u16(b, i) = (UInt16(b[i]) << 8) | UInt16(b[i+1])
rd_u32(b, i) = (UInt32(b[i]) << 24) | (UInt32(b[i+1]) << 16) | (UInt32(b[i+2]) << 8) | UInt32(b[i+3])

function rd_steps(b, i)
    n = Int(rd_u16(b, i)); i += 2
    v = Tuple{UInt8,UInt32}[]
    for _ in 1:n
        push!(v, (b[i], rd_u32(b, i + 1))); i += 5
    end
    return v, i
end

# SCHEMA GATE FIRST: byte 1 must equal 0x01, else the layout is unknown → nothing (no decode).
function decode_handle(b::Vector{UInt8})
    (isempty(b) || b[1] != 0x01) && return nothing
    i = 2
    nslen = Int(rd_u16(b, i)); i += 2
    ns = String(copy(b[i:i+nslen-1])); i += nslen
    grain = b[i]; i += 1
    path, i = rd_steps(b, i)
    origin, i = rd_steps(b, i)
    return (; namespace = ns, grain, path, origin)
end

grain_name(g) = g == 0x01 ? "Segment" : g == 0x0a ? "Line" : g == 0x46 ? "Block" :
                g == 0xd2 ? "File" : g == 0xe0 ? "USER_CONTEXT" : ""
store_name(s) = s == 0x01 ? "direct" : s == 0x02 ? "insert" : s == 0x00 ? "TRUNCATED" : "?"
fmt_steps(v) = "[" * join(["($(store_name(s)),$(Int(o)))" for (s, o) in v], " ") * "]"

function main()
    length(ARGS) == 2 || fail_usage()
    cmd, path = ARGS[1], ARGS[2]
    cmd in _VERBS || fail_usage()
    isfile(path) || (println(stderr, "gometa: no such file: ", path); exit(2))

    r = GoMeta.goMeta(read(path))
    println(stderr, "status: ", r.status)
    for d in r.diagnostics
        println(stderr, "diagnostic: ", d)
    end

    if cmd == "tree"
        print(String(copy(Main.BasicRenderer.outputs(r).blsStructure_bytes)))
    elseif cmd == "segments"
        rows = split(String(copy(Main.BasicRenderer.outputs(r).blsStructure_bytes)), '\n')
        !isempty(rows) && isempty(last(rows)) && pop!(rows)
        for (i, row) in enumerate(rows)
            println(lpad(i, 4), "  ", row)
        end
    elseif cmd == "render"
        print(String(copy(Main.BasicRenderer.outputs(r).render_bytes)))
    elseif cmd == "evals"
        fp = Dict{Vector{UInt8},Vector{UInt8}}(h => c for (h, c) in GoMeta.content_fingerprint(r))
        rows = GoMeta.altValues_evals(r)
        isempty(rows) && println(stderr, "(no evals rows — no LIVE metaLine on any surface)")
        for (h, attr, v, pol) in rows
            cell = replace(String(copy(fp[h])), '\n' => '⏎')
            println(rpad(String(attr), 14), " => ", rpad(repr(v), 40), " (", pol, ")  \"",
                    first(cell, 60), length(cell) > 60 ? "…\"" : "\"")
        end
    elseif cmd == "evals-tree"
        ## the owner's print tool, FULL form (R-DEV-4's option): every Component visible,
        ## absence labelled "(no evals — defaults apply)", every row with its decoded handle
        print_altValues_evals(stdout, r; layout = :tree, include_empty = true,
                              show_handles = true, _name = basename(path))
    elseif cmd == "bls-tree"
        ## the owner's tree printer (R-DEV-1 :mix): tree rows + typed named-int / settribute dumps
        print_BLS_Component_Tree(stdout, r; style = :mix, _name = basename(path))
    elseif cmd == "trace"
        fp = Dict{Vector{UInt8},Vector{UInt8}}(h => c for (h, c) in GoMeta.content_fingerprint(r))
        rows = GoMeta.altValues_evals(r)
        isempty(rows) && println(stderr, "(no evals rows — no LIVE metaLine on any surface)")
        for (h, attr, v, pol) in rows
            cell = replace(String(copy(fp[h])), '\n' => '⏎')
            println(rpad(String(attr), 14), " => ", rpad(repr(v), 40), " (", pol, ")  \"",
                    first(cell, 60), length(cell) > 60 ? "…\"" : "\"")
            d = decode_handle(h)
            if d === nothing
                println("    handle: UNDECODED (schema != 0x01) — the excerpt above is the only locator")
                continue
            end
            g = grain_name(d.grain)
            trunc = any(s -> s[1] == 0x00, d.path) || any(s -> s[1] == 0x00, d.origin)
            println("    handle: ns=:", d.namespace, "  grain=0x", string(d.grain, base = 16, pad = 2),
                    isempty(g) ? "" : " ($g)", "  path=", fmt_steps(d.path),
                    trunc ? "  !! TRUNCATED step — degenerate walk !!" : "")
            println("    origin: ", isempty(d.origin) ? "[] — the key addresses the cell itself" :
                    fmt_steps(d.origin) * " — Segment-carried remap")
        end
    end
    exit(r.status == GoMeta.PROCESS_OK ? 0 : 1)
end

main()
