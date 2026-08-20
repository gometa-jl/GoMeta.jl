# notebooks_from_source.jl — derive a family of notebooks (and manual pages) from ONE
# marked Julia source file, purely from its `#~` metadata.
#
# What it does, end to end:
#   1. runs `GoMeta.goMeta` on the source (trusted committed input — see the SECURITY
#      section of the README) and requires `PROCESS_OK`;
#   2. takes each line's EFFECTIVE fate from the engine's own VERDICTS: the `:visib`
#      rows of `GoMeta.altValues_evals` joined to source spans via
#      `GoMeta.content_fingerprint` — never from the render bytes (at the render grain
#      an engine-hidden line and an authored marker-headed line are
#      byte-INDISTINGUISHABLE, the ensure-token fidelity bound; the render serves only
#      as a one-directional consistency witness). Ancestry and conditions are the
#      engine's business, never re-derived here;
#   3. partitions the source into cells by the documented conventions (blank lines and
#      text/code type changes bound blocks; `#~` / `#]` metadata lines are consumed as
#      control AND carried invisibly — the transformation principle: the GoMeta data
#      travels with the artifact in SOURCE form, as HTML comments in markdown cells and
#      as `gometa` cell metadata in code cells; hidden content lines travel the same
#      way; DISCARDED lines never travel) and joins each cell to its evaluated labels
#      via `GoMeta.altValues_evals` + `GoMeta.content_fingerprint` (occurrence-keyed
#      rows; the fingerprint carries each cell's verbatim content bytes, same order);
#   4. writes one notebook per EDITION — full · student · report · slides — each a pure
#      function of the marks plus the edition's small policy table below, in
#      deterministic nbformat 4.5 JSON (fixed key order; content-derived cell ids;
#      a Julia kernelspec so standard executors pick the right kernel);
#   5. prints a content-free emission manifest per edition (counts and label names,
#      never removed content);
#   6. `--check` regenerates every GENERATED artifact and byte-compares it against the
#      committed file (the executed edition is produced by a standard notebook executor
#      afterwards and is deliberately outside this byte gate).
#
# Run from the repository root:
#   julia --startup-file=no --project=. notebooks_from_source.jl            # generate
#   julia --startup-file=no --project=. notebooks_from_source.jl --check    # verify
#
# The per-file label legend (which label means parameters, private, …) is DATA, declared
# per source file below — the five shipped labels are generic; the binding is this
# project's convention. A future dedicated Alterant vocabulary would carry these
# meanings first-class; regenerating from migrated sources must then reproduce these
# artifacts up to the documented normalization (see the notes in the notebooks folder).

import GoMeta
import SHA

# ── the source registry: file → legend + emitted targets ────────────────────────────────
const NB_DIR = joinpath(@__DIR__, "notebooks")

struct SourceSpec
    path::String                    # source file, relative to the repository root
    legend::Dict{Symbol,Symbol}     # label → meaning (parameters/expensive/solution/deep_dive/private)
    editions::Vector{Symbol}        # which notebook editions to emit
    pages::Bool                     # also emit the Documenter manual page pair?
end

const SOURCES = [
    SourceSpec(joinpath(NB_DIR, "src", "montecarlo.jl"),
        Dict(:label1 => :parameters, :label2 => :expensive, :label3 => :solution,
             :label4 => :deep_dive, :label5 => :private),
        [:full, :student, :report, :slides], true),
    SourceSpec(joinpath(NB_DIR, "src", "quickstart.jl"),
        Dict(:label1 => :parameters, :label2 => :expensive, :label3 => :solution,
             :label4 => :deep_dive, :label5 => :private),
        [:full], false),
]

# ── engine consumption ──────────────────────────────────────────────────────────────────

struct LineFate
    text::String     # the ORIGINAL source line (clean, unprefixed)
    fate::Symbol     # :show | :hide | :discard
end

# THE FATE SOURCE IS THE VERDICT SURFACE, never the render. Under the v0.3 ensure-token
# rule an authored `## `-headed line inside a hidden block renders AS-IS —
# byte-indistinguishable from a shown line — so any render walk mis-fates exactly that
# class SILENTLY (probe-proven). The `:visib` rows of `altValues_evals` carry the
# winning verdict per governed piece; `content_fingerprint` carries each piece's
# verbatim source bytes in the same order (the documented same-order contract, asserted
# below). Pieces overlap on inline-governed lines: a single-line piece's verdict
# OVERRIDES its containing block's (the engine's inner-wins precedence, probe-verified).
# Ungoverned lines default :show. Identical piece bytes are attributable only when the
# row count matches the occurrence count under ONE verdict — anything else refuses
# loudly (never a silent mis-fate).
function _find_spans(inl, piece)
    spans = Int[]
    m = length(piece)
    for s in 1:(length(inl) - m + 1)
        ok = true
        for k in 1:m
            if inl[s + k - 1] != piece[k]
                ok = false
                break
            end
        end
        ok && push!(spans, s)
    end
    return spans
end

function verdict_fates(input::String, evals, fingerprints)
    length(evals) == length(fingerprints) ||
        error("EMIT FAILURE: evals/fingerprint arity diverged — the accessors' contract broke")
    inl = split(input, '\n')
    n = length(inl)
    fates = Symbol[:show for _ in 1:n]
    locked = falses(n)
    # collect the :visib pieces, grouped by verbatim bytes
    groups = Dict{String,Vector{Symbol}}()
    for ((h, attr, val, pol), (fp_h, content)) in zip(evals, fingerprints)
        fp_h == h ||
            error("EMIT FAILURE: evals/fingerprint order diverged — the accessors' same-order contract broke")
        attr === :visib || continue
        # the verdict-domain whitelist (panel V1 MAJOR): this generator's carriage
        # semantics are DEFINED for show/hide/discard with polarity true (the v0
        # domain) — a future verdict family or a negated-verdict encoding must be
        # adopted deliberately, never silently emitted as visible text
        val in (:show, :hide, :discard) ||
            error("EMIT FAILURE: unknown visibility verdict :$(val) — the carriage semantics cover show/hide/discard only; verdict-domain evolution must be adopted deliberately, never silently")
        pol === true ||
            error("EMIT FAILURE: a non-true polarity on a :visib row — the reserved negated-verdict encoding must be adopted deliberately, never silently")
        c = String(copy(content))
        startswith(c, "\n") && (c = String(c[2:end]))   # mark pieces may lead with the detach byte
        push!(get!(groups, c, Symbol[]), val::Symbol)
    end
    # pass A — multi-line (block) pieces
    for (bytes, verdicts) in groups
        occursin('\n', bytes) || continue
        vs = unique(verdicts)
        piece = split(bytes, '\n')
        spans = _find_spans(inl, piece)
        (length(vs) == 1 && length(spans) == length(verdicts)) ||
            error("EMIT FAILURE: cannot attribute a block verdict piece unambiguously ($(length(verdicts)) row(s), $(length(spans)) span(s), verdict(s) $(join(vs, '/'))): " * repr(first(bytes, 50)))
        for s in spans, k in 0:(length(piece) - 1)
            if locked[s + k] && fates[s + k] !== vs[1]
                error("EMIT FAILURE: conflicting block verdicts on source line $(s + k) ($(fates[s + k]) vs $(vs[1]))")
            end
            fates[s + k] = vs[1]
            locked[s + k] = true
        end
    end
    # pass B — single-line pieces (inline-governed lines, one-line blocks, metaLine
    # marks); the inner verdict overrides the containing block's
    for (bytes, verdicts) in groups
        occursin('\n', bytes) && continue
        vs = unique(verdicts)
        idxs = findall(==(bytes), inl)
        (length(vs) == 1 && length(idxs) == length(verdicts)) ||
            error("EMIT FAILURE: cannot attribute a line verdict piece unambiguously ($(length(verdicts)) row(s), $(length(idxs)) match(es), verdict(s) $(join(vs, '/'))): " * repr(first(bytes, 50)))
        for i in idxs
            fates[i] = vs[1]
        end
    end
    return [LineFate(String(inl[i]), fates[i]) for i in 1:n]
end

# the render as a one-directional WITNESS, never a fate source: every discarded line is
# absent, every shown line appears verbatim in order, every hidden line appears in a
# hidden form (`## `-marked post-indent — the prefixed, ensure-token as-is, and
# inline-marked forms all satisfy the post-indent check). The comparison runs on the
# NON-BLANK grain: blank lines carry no verdicts, and discarding a whole block swallows
# an adjacent blank separator in the render (probe-observed), so blanks witness
# nothing. Divergence refuses loudly.
function witness_against_render(fates::Vector{LineFate}, render::String)
    rl = [l for l in split(render, '\n') if !isempty(strip(l))]
    j = 1
    for (i, lf) in enumerate(fates)
        (lf.fate === :discard || isempty(strip(lf.text))) && continue
        j <= length(rl) ||
            error("EMIT FAILURE: render witness exhausted at source line $i — verdict/render drift")
        # the hidden-form class mirrors the engine's fold: `## `-prefixed, PLUS the
        # ensure-token as-is shapes where the marker is bare `##` before horizontal
        # whitespace or end-of-line (panel V1: a hidden bare `##` line renders
        # markerless — the space-demanding check false-redded a legitimate shape)
        ok = lf.fate === :show ? rl[j] == lf.text :
             occursin(r"^##(?:[\h]|$)", lstrip(String(rl[j])))
        ok || error("EMIT FAILURE: render witness mismatch at source line $i (fate $(lf.fate)) against render line " * repr(first(String(rl[j]), 50)))
        j += 1
    end
    j == length(rl) + 1 ||
        error("EMIT FAILURE: render witness left $(length(rl) + 1 - j) unconsumed render line(s)")
end

## The token-delimiter law: only a ws-or-EOL-TERMINATED head
## is a token — glued shapes (`#~hide`, `#]x`, `##x`, `###+`) are PLAIN CONTENT. The
## head grammar mirrors the engine's `_RE_META_BODY_STR` (flavor.jl, single source
## in-tree; this overlay is out-of-tree and carries the derived line-anchored form).
## Indent handling: lstrip (Unicode-wide, matching the engine's _isspace_valid indent
## scan) — the head regex is anchored POST-indent (an `[ \t]*` prefix
## class silently dropped NBSP-indented metaLines the engine consumes).
## The whitespace alphabet: the delimiter class is Unicode
## horizontal whitespace (`[\h]`) — unified with the engine.
## The bang-first family `#~!N`/`#~!N!` is NOT matched here (not a token) — DELIBERATE:
## the ENGINE refuses that family at parse (§4.1, v0.3.1), and `goMeta` runs
## before `partition`, so a bang-first line can never reach this out-of-tree mirror
## alive (the correctness argument recorded in ENGINE-DESIGN_R-INERT-4.md §2).
const _TOKEN_HEAD_RE = r"^#(?:~+(?:[0-9]+!?|!)?|\])(?=[\h]|$)"
is_meta_line(t)  = occursin(_TOKEN_HEAD_RE, lstrip(t))
is_prose_line(t) = begin
    s = lstrip(t)
    ## The token-delimiter law: prose ⇔ a DELIMITED `#`/`##` head (Text lead / BLS comment); glued heads
    ## are content and belong to the neighbouring cell (line-local approximation —
    ## bare `#` stays prose here, as before, a recorded converter approximation).
    !is_meta_line(t) && !startswith(s, "#=") && occursin(r"^#{1,2}(?:[\h]|$)", s)
end
is_blank_line(t) = isempty(strip(t))

struct Cell
    kind::Symbol            # :markdown | :code | :carrier (a detached meta block —
                            # no visible lines; renders as nothing)
    lines::Vector{LineFate} # surviving + hidden lines (discarded lines dropped)
    original::String        # the block's ORIGINAL bytes (the engine's cell-handle key)
    labels::Set{Symbol}
    depth::Int              # the governing mark's depth, SCRAPED from the source text
                            # (0 = no preceding mark; depth is not on the evals surface
                            # at v0 — the slides mapping discloses this on the artifact)
    carried::Vector{LineFate} # the meta run this cell carries in SOURCE form (the
                            # transformation principle: metaLines travel invisibly with
                            # the artifact; DISCARDED metaLines never travel)
end

# partition the source into blocks the way the engine's documented conventions cut them:
# blank lines and text/code type changes bound blocks; meta lines are consumed
function mark_depth(t::String)
    ## The token-delimiter law: only a ws-or-EOL-terminated head is a mark; glued
    ## shapes return nothing (content). R-INERT-4 (v0.3.1): the inert
    ## trailing-bang form CARRIES ITS DEPTH — `#~N! …` ≡ `#~N` structurally (open/
    ## close/supersede), so the scrape reads the depth straight through the `!` and
    ## the dstack pushes/supersedes on an inert head exactly as on its live twin
    ## (pre-fix this returned nothing for `!` forms — the slides edition then mis-typed
    ## inert-governed cells and a deeper sibling escaped supersession). The digit form
    ## takes the FIRST digit (the engine's first-digit depth semantics); the tilde-run
    ## form — bare `#~`/`#~~~`, inert twins included — clamps to the window top
    ## (min(len, 8), the engine's clamp).
    m = match(r"^#(~+)([0-9]*)(!?)(?=[\h]|$)", lstrip(t))
    m === nothing && return nothing
    return m.captures[2] == "" ? min(length(m.captures[1]), 8) :
                                 parse(Int, string(first(m.captures[2])))
end

function partition(fates::Vector{LineFate})
    cells = Cell[]
    cur = LineFate[]; curkind = :none; orig = String[]
    metarun = LineFate[]              # the contiguous run of metaLines awaiting a home
    attach = LineFate[]               # the run attached to the block being built
    dstack = Int[]                    # scraped depth stack; #] pops to the parent scope
    depth() = isempty(dstack) ? 0 : last(dstack)
    carried_of(run) = [lf for lf in run if lf.fate !== :discard]   # discard never travels
    flush!() = begin
        if !isempty(cur)
            kept = [lf for lf in cur if lf.fate !== :discard]
            push!(cells, Cell(curkind, kept, join(orig, '\n'), Set{Symbol}(), depth(), attach))
            attach = LineFate[]
        end
        cur = LineFate[]; curkind = :none; orig = String[]
    end
    # a meta run separated from content by a blank line is DETACHED (a semantics-bearing
    # distinction — the corpus blankline fixture) and becomes its own carrier cell; a
    # run contiguous with following content attaches to that block's cell
    emit_detached!() = begin
        kept = carried_of(metarun)
        isempty(kept) || push!(cells, Cell(:carrier, LineFate[], "", Set{Symbol}(), depth(), kept))
        metarun = LineFate[]
    end
    for lf in fates
        t = lf.text
        if is_blank_line(t) || is_meta_line(t)
            flush!()
            if is_meta_line(t)
                push!(metarun, lf)
            else
                emit_detached!()
            end
            if startswith(lstrip(t), "#]")
                isempty(dstack) || pop!(dstack)   # the close-marker restores the parent depth
            else
                d = is_meta_line(t) ? mark_depth(t) : nothing
                if d !== nothing
                    # a mark at depth <= the top supersedes it (sibling); deeper nests
                    while !isempty(dstack) && last(dstack) >= d
                        pop!(dstack)
                    end
                    push!(dstack, d)
                end
            end
            continue
        end
        kind = is_prose_line(t) ? :markdown : :code
        kind == curkind || flush!()
        if isempty(cur) && !isempty(metarun)
            attach = carried_of(metarun)          # the run rides the block it governs
            metarun = LineFate[]
        end
        # a fresh heading block starts an unmarked section: the previous mark's depth
        # does not reach across it (the scrape stays honest for detached headings)
        kind === :markdown && isempty(cur) && startswith(lstrip(t), "# #") && empty!(dstack)
        curkind = kind
        push!(cur, lf)
        push!(orig, t)
    end
    flush!()
    emit_detached!()                              # a trailing meta run gets its own cell
    # cells whose every line was discarded stay in the list (their evaluated labels must
    # still find a home in the coverage join); editions skip them at emission time
    return cells
end

# join labels onto cells via each row's verbatim CONTENT bytes (the
# `content_fingerprint` sibling accessor — same sort order as `altValues_evals`, by
# contract). The evals KEY is the structural occurrence handle since v0.2 and is opaque
# here. HONEST SCOPE: an eval row with NO home fails red; the containment match may
# attach a label to more than one cell on shared bytes — editions treat labels as
# per-cell hints and EXACT occurrence attribution is deliberately not claimed (the join
# is content-keyed at this release; the registered limitation).
function join_labels!(cells::Vector{Cell}, evals, fingerprints)
    length(evals) == length(fingerprints) ||
        error("EMIT FAILURE: evals/fingerprint arity diverged — the accessors' contract broke")
    unmatched = String[]
    for ((handle, attr, value, _), (fp_handle, content)) in zip(evals, fingerprints)
        fp_handle == handle ||
            error("EMIT FAILURE: evals/fingerprint order diverged — the accessors' same-order contract broke")
        m = match(r"^label_(label[1-5])$", String(attr))
        (m !== nothing && value === true) || continue
        key = strip(String(copy(content)))
        label = Symbol(m.captures[1])
        hit = false
        for c in cells
            co = strip(c.original)
            # exact equality always joins; the containment FALLBACK carries an 8-byte
            # floor so degenerate fragments cannot attract every handle
            exact = key == co
            long_enough = min(length(key), length(co)) >= 8
            if exact || (long_enough && (occursin(key, co) || occursin(co, key)))
                push!(c.labels, label); hit = true
            end
        end
        hit || is_meta_line(key) || push!(unmatched, first(key, 60))
    end
    isempty(unmatched) || error("EMIT FAILURE: $(length(unmatched)) evaluated label handle(s) joined no cell — segmentation drift: " * repr(first(unmatched)))
end

# ── notebook writing (deterministic nbformat 4.5) ───────────────────────────────────────

function json_escape(s)
    t = replace(s, '\\' => "\\\\", '"' => "\\\"", '\n' => "\\n", '\r' => "\\r", '\t' => "\\t")
    # any remaining control character must be \u-escaped or the JSON is invalid
    return replace(t, r"[\x00-\x1f]" => c -> "\\u" * string(UInt16(only(c)), base = 16, pad = 4))
end

function source_array(lines::Vector{String})
    isempty(lines) && return "[]"
    parts = ["\"" * json_escape(l * (i == length(lines) ? "" : "\n")) * "\"" for (i, l) in enumerate(lines)]
    return "[" * join(parts, ", ") * "]"
end

cell_id(src::String, ordinal::Int) = bytes2hex(SHA.sha256(codeunits(src)))[1:16] * "-" * string(ordinal)

# ── the invisible carriers (the transformation principle, owner-ruled 2026-08-12) ──────
# The wrapper-only law: a carried line crosses into the artifact as its ORIGINAL BYTES
# wrapped in the target format's comment form — the wrapper is the only added
# transformation, so the GoMeta data can be read, modified, and re-evaluated in the
# output file exactly as in the input, and unwrapping restores the source line.
# HTML comments forbid `--`, so the payload rides a REVERSIBLE escape: `\` doubles,
# then every `-` directly before another `-` gains a `\` (no `--` survives); the
# mandatory single-space pads cure the leading `>`/`->` and trailing `-` spec edges.
# Unescape runs the dash rule to fixpoint, then undoubles backslashes.
carrier_escape(s::String) = replace(replace(s, "\\" => "\\\\"), r"-(?=-)" => "-\\")
function carrier_unescape(s::String)
    while occursin("-\\-", s)
        s = replace(s, "-\\-" => "--")
    end
    return replace(s, "\\\\" => "\\")
end
html_comment(s::String) = "<!-- " * carrier_escape(s) * " -->"

# the full markdown-cell source: the attached meta run travels at the cell's head,
# verbatim inside the wrapper, then the body lines
md_lines(c::Cell) = vcat([html_comment(lf.text) for lf in c.carried], md_lines_body(c))

# the DOCUMENTER PAGE view of a markdown cell: hidden lines DROP (owner-ruled
# 2026-08-12: pages are derived VIEWS like the reader/student editions — HTML comments
# do not survive the Documenter markdown pipeline, probe-proven, and the pages are also
# GitHub-browsable; the notebook full edition is the metadata-bearing artifact)
md_lines_page(c::Cell) = md_lines_body(c; hidden = :drop)

# the body alone; `hidden = :comment` carries hidden prose as wrapper-only HTML
# comments (the notebook path — verified pass-through in nbconvert HTML), `:drop`
# omits it (the page path)
function md_lines_body(c::Cell; hidden::Symbol = :comment)
    out = String[]
    for lf in c.lines
        if lf.fate === :hide
            # a hidden line must not appear in the RENDERED view; in notebooks the
            # wrapper-only HTML comment keeps it present in the artifact bytes (hide is
            # a visibility operation, never redaction — discard is the removing form)
            hidden === :comment && push!(out, html_comment(lf.text))
            continue
        end
        t = lstrip(lf.text)
        t = startswith(t, "# ") ? t[3:end] : (t == "#" ? "" : startswith(t, "#") ? lstrip(t[2:end]) : t)
        ## The quote escape convention: stripping
        ## the Text lead must never turn a mentioned-in-prose metaStatement into a live
        ## line-grain token in the generated markdown (the grain/scope-promotion class:
        ## `# #~ hide` — an inline metaSegment confined to its own Text line — would become
        ## a standalone metaLine governing the FOLLOWING content). Any stripped line that
        ## would begin with a marker-token shape is quote-GLUED per the documented convention —
        ## measured inert: a glued quote blocks dispatch (the before-lead whitespace law).
        if startswith(t, "#~") || startswith(t, "#]") || startswith(t, "//~") || startswith(t, "//]")
            t = "\"" * String(t) * "\""
        end
        push!(out, String(t))
    end
    return out
end

# a code cell's VISIBLE source carries shown lines only; hidden lines travel in the
# cell's `gometa` metadata (a code cell has no in-source invisible channel — anything
# in the source field is displayed by every viewer, and an HTML comment there would
# both show as literal text and break execution)
code_lines(c::Cell) = [lf.text for lf in c.lines if lf.fate !== :hide]

fully_hidden(c::Cell) = c.kind !== :carrier && !isempty(c.lines) &&
    all(lf.fate === :hide for lf in c.lines)
fully_hidden_code(c::Cell) = c.kind === :code && fully_hidden(c)

# the `gometa` cell-metadata carrier for code cells: each carried line rides with its
# 0-based index over the cell's reconstructable sequence [attached meta run..., content
# lines...] — re-interleaving `carried` into the shown lines restores the original
# block byte-exactly (discarded lines are excluded from the sequence: they never travel)
function gometa_meta(c::Cell; kind_note::Bool = false)
    entries = String[]
    idx = 0
    for lf in c.carried
        push!(entries, "{\"i\": " * string(idx) * ", \"text\": \"" * json_escape(lf.text) * "\"}")
        idx += 1
    end
    for lf in c.lines
        lf.fate === :hide &&
            push!(entries, "{\"i\": " * string(idx) * ", \"text\": \"" * json_escape(lf.text) * "\"}")
        idx += 1
    end
    parts = String["\"v\": 1"]
    kind_note && push!(parts, "\"kind\": \"code\"")
    isempty(entries) || push!(parts, "\"carried\": [" * join(entries, ", ") * "]")
    (length(parts) == 1) && return ""
    return "\"gometa\": {" * join(parts, ", ") * "}"
end

# a fully hidden cell must render as NOTHING — an empty code input box is a visible
# artifact — so it crosses over as an invisible markdown carrier cell; the original
# kind rides the metadata for reconstruction. Detached meta runs (:carrier cells)
# emit the same invisible way (their payloads are self-identifying metaLines).
is_carrierish(c::Cell) = c.kind === :carrier || fully_hidden(c)

# the cell's emitted source lines — the single authority the writer AND the self-check
# battery share
function cell_source_lines(c::Cell)
    is_carrierish(c) && return vcat([html_comment(lf.text) for lf in c.carried],
                                    [html_comment(lf.text) for lf in c.lines])
    return c.kind === :markdown ? md_lines(c) : code_lines(c)
end

function write_cell(io, c::Cell, ordinal::Int; extra_meta::String = "", tags::Vector{String} = String[])
    hidden_code = fully_hidden_code(c)
    kind = (c.kind === :markdown || is_carrierish(c)) ? "markdown" : "code"
    lines = cell_source_lines(c)
    src = source_array(lines)
    meta_parts = String[]
    isempty(tags) || push!(meta_parts, "\"tags\": [" * join(["\"" * t * "\"" for t in sort(tags)], ", ") * "]")
    isempty(extra_meta) || push!(meta_parts, extra_meta)
    gm = hidden_code ? gometa_meta(Cell(c.kind, LineFate[], c.original, c.labels, c.depth, LineFate[]); kind_note = true) :
         (kind == "code" ? gometa_meta(c) : "")
    isempty(gm) || push!(meta_parts, gm)
    meta = "{" * join(meta_parts, ", ") * "}"
    print(io, "  {\"cell_type\": \"", kind, "\", \"id\": \"", cell_id(join(lines, '\n'), ordinal), "\", \"metadata\": ", meta)
    kind == "code" && print(io, ", \"execution_count\": null, \"outputs\": []")
    print(io, ", \"source\": ", src, "}")
end

function write_notebook(path::String, cells::Vector{Tuple{Cell,String,Vector{String}}})
    io = IOBuffer()
    println(io, "{")
    println(io, " \"cells\": [")
    for (i, (c, extra, tags)) in enumerate(cells)
        write_cell(io, c, i; extra_meta = extra, tags = tags)
        println(io, i == length(cells) ? "" : ",")
    end
    println(io, " ],")
    println(io, " \"metadata\": {\"kernelspec\": {\"display_name\": \"Julia 1.12\", \"language\": \"julia\", \"name\": \"julia-1.12\"}, \"language_info\": {\"name\": \"julia\", \"version\": \"1.12.5\"}},")
    println(io, " \"nbformat\": 4,")
    println(io, " \"nbformat_minor\": 5")
    print(io, "}")
    return (path, String(take!(io)))
end

# ── the edition policies ────────────────────────────────────────────────────────────────

meaning(c::Cell, legend) = Set(get(legend, l, :none) for l in c.labels)

function edition_cells(cells::Vector{Cell}, legend, edition::Symbol)
    out = Tuple{Cell,String,Vector{String}}[]
    omitted = 0
    for c in cells
        # fully engine-discarded AND carrying nothing — never emitted; a cell whose
        # visible lines all discarded but whose meta run travels stays as a carrier
        isempty(c.lines) && isempty(c.carried) && continue
        ms = meaning(c, legend)
        tags = String[]
        extra = ""
        # carrier-rendering cells (detached meta runs, discarded-content cells with a
        # surviving meta run, fully hidden cells of ANY kind) are invisible: no edition
        # tags (an invisible cell is not a policy surface — papermill's singular
        # `parameters` anchor therefore falls to the first VISIBLE parameters cell,
        # disclosed in the README), slides mark them skip
        if c.kind === :carrier || isempty(c.lines) || fully_hidden(c)
            if edition === :student && c.kind !== :carrier && :solution in ms
                # Layer-2 (panel V2): the worksheet must not smuggle solution bytes —
                # an invisible solution cell is OMITTED entirely, no scaffold (the full
                # edition shows nothing at this spot either)
                omitted += 1
                continue
            end
            edition === :slides && (extra = "\"slideshow\": {\"slide_type\": \"skip\"}")
            # the student lock rides invisible cells too (panel V4): a deletable
            # invisible cell is silently destroyable carried GoMeta data
            edition === :student && (extra = "\"editable\": false, \"deletable\": false")
            push!(out, (isempty(c.lines) && c.kind !== :carrier ?
                        Cell(:carrier, LineFate[], c.original, c.labels, c.depth, c.carried) : c,
                        extra, tags))
            continue
        end
        if edition === :full
            :parameters in ms && push!(tags, "parameters")
            :expensive in ms && push!(tags, "skip-execution")
            :solution in ms && push!(tags, "solution")
            :deep_dive in ms && push!(tags, "deep-dive")
        elseif edition === :student
            if :solution in ms && c.kind === :code
                omitted += 1
                # Layer-2 policy omission: the replaced cell's bytes (solution AND its
                # meta run) deliberately do NOT travel — a worksheet must not smuggle
                # the solution in metadata
                scaffold = Cell(:code, [LineFate("# your solution here", :show)], "# your solution here", Set{Symbol}(), 0, LineFate[])
                push!(out, (scaffold, "", String[]))
                continue
            end
            :parameters in ms && push!(tags, "parameters")
            :expensive in ms && push!(tags, "skip-execution")
            c.kind === :markdown && (extra = "\"editable\": false, \"deletable\": false")
        elseif edition === :report
            if c.kind === :code
                push!(tags, "hide-input")
                extra = "\"jupyter\": {\"source_hidden\": true}"
            end
            :expensive in ms && push!(tags, "skip-execution")
        elseif edition === :slides
            # the sanctioned DEPTH SCRAPER: depth 1 → slide, depth 2 → subslide, deeper
            # or deep-dive → skip, ungoverned content → fragment; headings open slides.
            # Depth comes from the source marks (it is not on the evals surface at v0 —
            # the slides edition's footer cell discloses exactly that).
            slide = if is_heading(c)
                "slide"
            elseif :deep_dive in ms || c.depth >= 3
                "skip"
            elseif c.depth == 1
                "slide"
            elseif c.depth == 2
                "subslide"
            else
                "fragment"
            end
            extra = "\"slideshow\": {\"slide_type\": \"" * slide * "\"}"
            :expensive in ms && push!(tags, "skip-execution")
        end
        push!(out, (c, extra, tags))
    end
    # papermill treats the FIRST parameters-tagged cell as THE parameters cell — the tag
    # stays singular per notebook (later parameter-labeled cells keep their other tags)
    seen_params = false
    for (i, (c, extra, tags)) in enumerate(out)
        if "parameters" in tags
            seen_params && (out[i] = (c, extra, filter(!=("parameters"), tags)))
            seen_params = true
        end
    end
    return (out, omitted)
end

# ── the Documenter manual pages (the same marks choose content AND tests) ───────────────
# The execution-axis law these pages follow (three genuinely distinct states):
#   run + shown    → a named `@example` block (executes at every docs build)
#   run + hidden   → the same block with `# hide` on the hidden line (executes, display-hidden)
#   shown, NOT run → a plain fenced code block (the docs build never executes it)
# A `jldoctest` block present in an emitted page IS a test the docs build runs — the marks
# therefore choose the manual page's test selection (docstring doctests are separate: they
# ride the `modules` configuration, not these pages).

const DOCS_DIR = joinpath(@__DIR__, "docs")

struct Section
    heading::Union{Cell,Nothing}
    cells::Vector{Cell}
end

is_heading(c::Cell) = c.kind === :markdown && any(startswith(lstrip(lf.text), "# #") for lf in c.lines)

function sectionize(cells::Vector{Cell})
    sections = Section[]; cur = Cell[]; head = nothing
    for c in cells
        # The V4-panel guard, in its v0.3.1 form (ruled: metaLines RIDE the full
        # page — R-EXT-11's metaLine half reversed): line-less carrier cells now stay IN the
        # section stream so the FULL page can place their carriage envelope at the right
        # position — and the guard's invariant moves to drops(), which must NEVER see a
        # line-less cell's labels (the reader page's section selection stays byte-identical).
        if is_heading(c)
            (head !== nothing || !isempty(cur)) && push!(sections, Section(head, cur))
            head = c; cur = Cell[]
        else
            push!(cur, c)
        end
    end
    (head !== nothing || !isempty(cur)) && push!(sections, Section(head, cur))
    return sections
end

# ── the page-carriage envelope (v0.3.1: the ruled envelope law) ──────────
# The FULL page is a transformation artifact: every non-discarded metaLine and every hidden
# non-executed line rides INVISIBLY in a reserved-name `@setup`-class block at its cell's
# head — lines are `## ` + the ORIGINAL bytes (a comments-only block builds, renders nothing,
# and stays OUT of the site's search index — probed at v0.3.1; the `@raw html` alternative
# leaks into search_index.js and was REJECTED by ruling). The header line starts `##gometa`
# — NO space after `##`, a shape no payload can produce (payloads are always `## ` + bytes),
# so a decoder's envelope identity cannot be spoofed by PAYLOAD or stripped PROSE (the
# forged-envelope check below guards the prose side). Scope note (reconfirm wave 2): an
# authored Julia comment inside a generated CODE fence can still place the sigil bytes at
# a line start on the built page, so decoders identify envelopes NAME-FIRST (the reserved
# `gometa_carriage_`/`gometa_` namespaces are disjoint and stem-guarded), never by
# scanning for the sigil alone. Indices are 0-based over the cell's
# reconstructable sequence [attached meta run…, non-discarded content lines…]: `carried=`
# lists the envelope-carried entries, `hidden=` the natively-hidden-in-place executed lines
# (the ` # hide` suffix / `@setup` body — strip/locate by exactly these indices), every other
# index is a visible body line in order. The reader page is a VIEW: NO envelopes.
_carriage_name(chain::String) = "gometa_carriage_" * chain
# §4.3 edge (ii): partial fence hiding unbalances the page — refuse loudly. Covers heading
# AND body markdown cells (a heading cell can carry fences under its heading line).
# WAVE-5 FIXED POINT — a MIRROR OF THE MEASURED PARSER, not of any spec: the rules below
# were probed against Markdown.parse (julia flavor — what Documenter feeds pages through)
# and recorded in the development records. Measured law:
#   OPENER — a homogeneous run (3+) of backticks OR tildes at ANY indent (0/1/3/4-space
#   and TAB-led all open — the CommonMark 4-space-literal rule does NOT apply here),
#   with an info string; a line whose info contains the fence character is NOT a fence
#   (both flavors — `ch in flavor` in the stdlib fencedcode).
#   CLOSER — a ZERO-indent run of the SAME character of EXACTLY the opener's width
#   (a longer run is content; an indented exact run is content), with ANY suffix
#   (the parser closes on the run and ignores the rest of the line).
# Delimiters are classified from the SAME lead-stripped form the page emitter produces
# (_strip_lead byte-mirrors the md strip). Refusals: opener/closer FATE mismatch
# (partial hiding), and a fence still OPEN at cell end (stray opener; blank-split
# fragment; a DISCARDED closing delimiter — c.lines pre-excludes :discard, so a
# discarded closer leaves its opener dangling here). Disclosed residuals: a discarded
# delimiter PAIR passes as zero (authored whole-fence discard — the interior renders
# unfenced), and two interleaved blank-split fences can still pair up inside their
# fragments; neither occurs in the committed corpus. Fences inside NESTED Markdown
# contexts (blockquotes) are handled by a separate fail-closed refusal below.
_strip_lead(t) = begin
    s = lstrip(t)
    startswith(s, "# ") ? s[3:end] : (s == "#" ? "" : startswith(s, "#") ? lstrip(s[2:end]) : String(s))
end
function _fence_delims(lines)
    out = @NamedTuple{j::Int, fate::Symbol, ch::Char, width::Int, indented::Bool, info::String}[]
    for (j, lf) in enumerate(lines)
        m = match(r"^([\h]*)(`{3,}|~{3,})(.*)$", _strip_lead(lf.text))
        m === nothing && continue
        push!(out, (j = j, fate = lf.fate, ch = first(m.captures[2]),
                    width = length(m.captures[2]), indented = !isempty(m.captures[1]),
                    info = String(m.captures[3])))
    end
    return out
end
function _check_fence_pairing(c::Cell)
    # Nested-context bound (probe-verified: a blockquoted fence parses as a Code node
    # INSIDE the BlockQuote — MDPARSE-matrix.out rows blockquoted-*): fences inside `>`
    # contexts are invisible to this line-grain machine, so a cell mixing HIDDEN lines
    # with blockquoted fence runs cannot be fate-checked — refuse as unprovable.
    # DELIBERATE BREADTH (disclosed; wave-5b): ANY 3+ fence-char run on a blockquoted
    # line trips this — opener-shaped or mid-prose mention alike — because nested-context
    # fence shapes are exactly what this machine declines to model; mention fences
    # outside blockquotes (or un-hide the cell) to pass.
    if any(lf.fate === :hide for lf in c.lines) &&
       any((t = _strip_lead(lf.text); occursin(r"^[\h]*(?:>[\h]?)+", t) && occursin(r"`{3,}|~{3,}", t)) for lf in c.lines)
        error("notebooks_from_source: a fence inside a nested Markdown context (blockquote) ",
            "cannot be fate-checked at line grain (cell head: ", repr(first(c.lines).text),
            "); hide the whole cell or un-nest the fence")
    end
    open_w = 0
    open_ch = '`'
    open_fate = :show
    for d in _fence_delims(c.lines)
        if open_w == 0
            occursin(d.ch, d.info) && continue      # not a fence (measured: ch in info)
            open_w = d.width
            open_ch = d.ch
            open_fate = d.fate
        elseif d.ch == open_ch && d.width == open_w && !d.indented
            # the measured closer: same char, EXACT width, zero indent, any suffix
            if d.fate != open_fate
                error("notebooks_from_source: partial fence hiding — a markdown cell ",
                    "hides one fence delimiter while its pair is shown (cell head: ",
                    repr(first(c.lines).text), "); hide the whole fenced block or none")
            end
            open_w = 0
        end
    end
    open_w == 0 || error("notebooks_from_source: unbalanced fence delimiters — a fence ",
        "opened in this cell never closes (cell head: ", repr(first(c.lines).text),
        "); close every fence inside its cell (no blank line inside a fenced block, and ",
        "give both delimiters one fate)")
end
# The forged-envelope refusal (WAVE-5 FIXED POINT; probe-grounded): the page path strips
# the `# ` Text lead from prose, and the measured parser accepts fences at ANY indent, in
# BOTH flavors, and inside NESTED contexts — MDPARSE-matrix.out rows blockquoted-*: a
# blockquoted ```/~~~ `@setup gometa_…` parses as a directive-language Code node INSIDE
# the BlockQuote — so shape-matching authored forgeries is an arms race. The fixed point:
# the `gometa_` name family is RESERVED on generated pages — ANY authored line mentioning
# it refuses, in every Markdown context (§4.3 edge (iv) at the AUTHORED-page grain). The
# `##gometa` no-space sigil (unproducible by PAYLOAD lines — always `## ` + bytes)
# refuses likewise. To DISCUSS the mechanism on a page, write the names spaced or split;
# the tail template's own mentions are emitter-appended AFTER page_body — never authored,
# never scanned here. (Whether Documenter's expander EXECUTES a nested directive block
# was left unprobed — moot under this total refusal; recorded in the adjudication.)
# The cell-grain twin (wave-5b): scans ORIGINAL authored lines — every cell kind,
# carried metaLines included — so the reserved-mention law holds for code strings and
# hidden lines too, not only emitted visible Markdown. (The sigil rule stays on the
# STRIPPED scan below — the strip is what could mint the byte-exact header shape.)
function _check_reserved_mention(lines)
    for l in lines
        if occursin("gometa_", l)
            error("notebooks_from_source: an authored line mentions the reserved ",
                "`gometa_` namespace (", repr(l), ") — generated envelope/execution ",
                "names are reserved on pages in every Markdown context (§4.3 edge (iv)); ",
                "rewrite the line (spaced/split mention)")
        end
    end
end
function _check_forged_envelope(stripped)
    for l in stripped
        if occursin("gometa_", l)
            error("notebooks_from_source: an authored line mentions the reserved ",
                "`gometa_` namespace (", repr(l), ") — generated envelope/execution ",
                "names are reserved on pages in every Markdown context (§4.3 edge (iv)); ",
                "rewrite the line (spaced/split mention)")
        end
        if startswith(lstrip(l), "##gometa")
            error("notebooks_from_source: an authored line strips to the reserved ",
                "`##gometa` envelope-header sigil (", repr(l), ") — a page decoder ",
                "would mistake it for a generated carriage header; rewrite the line")
        end
    end
end
function _carriage_envelope(io, c::Cell, chain::String; hidden_idx::Vector{Int} = Int[])
    n = length(c.carried) + length(c.lines)
    carried_idx = Int[]
    payload = String[]
    for (i, lf) in enumerate(c.carried)
        push!(carried_idx, i - 1); push!(payload, lf.text)
    end
    if c.kind === :markdown || c.kind === :carrier
        for (j, lf) in enumerate(c.lines)
            if lf.fate === :hide || c.kind === :carrier
                push!(carried_idx, length(c.carried) + j - 1); push!(payload, lf.text)
            end
        end
    elseif c.kind === :code && !isempty(hidden_idx)
        # executed cells: hidden lines stay IN PLACE natively (`# hide`/@setup — §4.3(a));
        # only the meta run rides the envelope; `hidden=` records the in-place positions
    elseif c.kind === :code
        for (j, lf) in enumerate(c.lines)
            if lf.fate === :hide
                push!(carried_idx, length(c.carried) + j - 1); push!(payload, lf.text)
            end
        end
    end
    isempty(payload) && isempty(hidden_idx) && return false
    println(io, "```@setup ", _carriage_name(chain))
    println(io, "##gometa carriage v1 kind=", c.kind === :carrier ? "carrier" :
        (c.kind === :markdown ? "markdown" : "code"), " n=", n,
        " carried=", join(carried_idx, ","), " hidden=", join(sort(hidden_idx), ","))
    for t in payload
        println(io, "## ", t)
    end
    println(io, "```")
    println(io)
    return true
end
# a generated executed block's fence must outrun any backtick run in its body (§4.3 edge iii)
_fence(bodylines) = "`" ^ max(3, 1 + maximum(vcat(0,
    [length(match(r"^`*", lstrip(l)).match) for l in bodylines])))

function page_body(sections::Vector{Section}, legend, keep::Function, chain::String;
                   carriage::Bool = false)
    io = IOBuffer()
    exec_chain = "gometa_" * chain     # §4.3 edge (iv): reserved generated namespace —
                                       # an authored block can never share the sandbox
    for s in sections
        keep(s) || continue
        if s.heading !== nothing
            _check_reserved_mention([lf.text for lf in vcat(s.heading.carried, s.heading.lines)])
            _check_fence_pairing(s.heading)
            carriage && _carriage_envelope(io, s.heading, chain)
            # the same no-trace guard as body cells (reconfirm wave: a fully hidden
            # heading must not leave stray blanks)
            hl = md_lines_page(s.heading)
            _check_forged_envelope(hl)
            isempty(hl) || (println(io, join(hl, '\n')); println(io))
        end
        for c in s.cells
            _check_reserved_mention([lf.text for lf in vcat(c.carried, c.lines)])
            # FULL page (v0.3.1, §4.2): hidden content AND metaLines
            # ride in the carriage envelope; the READER page is a VIEW (carriage=false —
            # NO envelopes, and trimmed sections travel nowhere). Ruled bound, stated
            # exactly (reconfirm wave 2): hidden EXECUTED lines of a RETAINED section
            # still ride the reader NATIVELY (' # hide' / @setup — §4.3(a) preserves
            # execution continuity); the committed reader selection has zero hidden lines
            # today — if a future selection gains one, surface it to the owner first (the
            # adjudication ledger's reader-view row carries the re-raise trigger).
            # Carrier cells (detached meta runs) are envelope-only cells on the full
            # page and vanish from the reader.
            if c.kind === :carrier || isempty(c.lines)
                carriage && _carriage_envelope(io, c, chain)
                continue
            end
            ms = meaning(c, legend)
            if c.kind === :markdown
                _check_fence_pairing(c)
                carriage && _carriage_envelope(io, c, chain)
                pl = md_lines_page(c)
                _check_forged_envelope(pl)
                # a fully hidden markdown cell leaves NO trace on the page (panel V4:
                # no stray blank lines for an invisible cell)
                isempty(pl) || (println(io, join(pl, '\n')); println(io))
            elseif :expensive in ms
                # the branch order is load-bearing: expensive-BEFORE-all-hidden keeps
                # the never-execute law (an all-hidden expensive cell must not fall to
                # the executing @setup branch below); hidden lines of a NEVER-executed
                # cell ride the envelope (owner-ruled §4.3: only EXECUTED hidden code
                # stays in place natively)
                carriage && _carriage_envelope(io, c, chain)
                shown = code_lines(c)
                if !isempty(shown)
                    f = _fence(shown)
                    println(io, f, "julia")
                    foreach(l -> println(io, l), shown)       # shown lines only;
                    println(io, f)                            # hidden lines ride the envelope
                    println(io)
                    println(io, "*(Marked expensive in the source — shown here, deliberately NOT executed by the docs build.)*")
                    println(io)
                end
            elseif all(lf.fate === :hide for lf in c.lines)
                # execute-but-fully-hide → a NAMED @setup block (§4.3(a): the native
                # execute channel; `hidden=` indices record the in-place lines).
                # An authored trailing `# hide` in THIS branch is deliberately NOT
                # refused (unlike the @example branch below): no suffix is appended to
                # @setup body lines, the whole cell is already display-hidden, and
                # `hidden=` covers every body index — the marker is inert here and the
                # decoder's suffix-strip stays exact (disclosed; reconfirm wave).
                carriage && _carriage_envelope(io, c, chain;
                    hidden_idx = [length(c.carried) + j - 1 for j in eachindex(c.lines)])
                bodyl = [lf.text for lf in c.lines]
                f = _fence(bodyl)
                println(io, f, "@setup ", exec_chain)
                foreach(l -> println(io, l), bodyl)
                println(io, f)
                println(io)
            else
                # The §4.3(a) authored-marker refusal: an AUTHORED shown line already
                # ending in `# hide` would be display-hidden by Documenter AGAINST its
                # GoMeta fate — refuse loudly; a HIDDEN line ending in `# hide` would
                # double-suffix — refused outright too (stricter than edge (v)'s
                # hidden=-index answer: refusing keeps display fates byte-derivable).
                for lf in c.lines
                    if match(r"#\s*hide\s*$", lf.text) !== nothing
                        error("notebooks_from_source: a source line inside an executed cell ",
                            "ends in the Documenter-native '# hide' marker (", repr(lf.text),
                            ") — its display fate would no longer follow its GoMeta ",
                            "evaluation; rewrite the line (the marker is reserved on pages)")
                    end
                end
                # §4.3 edge (i) — the ruled byte-integrity refusal (WAVE-5 FIXED POINT):
                # appending ` # hide` to a hidden line whose EOL sits inside an OPEN
                # multiline literal (STRING or COMMAND — a Cmd's arguments are runtime
                # bytes exactly like string contents) would write the marker INTO the
                # literal's runtime bytes. IS: a LEXER-grounded check — the cell's lines
                # are tokenized with Base.JuliaSyntax (the real Julia lexer), so strings,
                # command literals, comments, and escapes are classified by the language
                # itself, not by a heuristic (the earlier toggle scans were
                # parity-poisonable by delimiter bytes inside comments and strings —
                # reconfirm rounds 1-2, probe-verified). DOES: refuses any hidden line
                # whose EOL byte falls inside a String/CmdString content token, and
                # refuses UNPROVABLE cells (an error token — e.g. a literal left open by
                # the blank-line cell split — or a tokenizer failure) instead of
                # guessing. A hidden line that CLOSES a literal is accepted (its EOL is
                # past the closing delimiter — the suffix lands as a plain comment).
                # Cells with no hidden lines never enter the check. PURPOSE: edge (i)
                # can never silently corrupt runtime bytes. REASONING: fail-closed at
                # the real lexer's grain ends the decoy arms race.
                if any(lf.fate === :hide for lf in c.lines)
                    _lsrc = join([lf.text for lf in c.lines], "\n") * "\n"
                    _eol = cumsum([sizeof(lf.text) + 1 for lf in c.lines])
                    _toks = try
                        collect(Base.JuliaSyntax.tokenize(_lsrc))
                    catch
                        nothing
                    end
                    if _toks === nothing ||
                       any(Base.JuliaSyntax.is_error(Base.JuliaSyntax.kind(t)) for t in _toks)
                        error("notebooks_from_source: line-grain hiding in an executed cell ",
                            "whose literal state cannot be proven (the Julia lexer reports ",
                            "an unterminated or unlexable region — cell head: ",
                            repr(first(c.lines).text), ") — the appended ' # hide' could ",
                            "land inside a literal's runtime bytes (§4.3 edge (i)); hide ",
                            "the whole cell or close the literal within the cell")
                    end
                    for (_j, lf) in enumerate(c.lines)
                        lf.fate === :hide || continue
                        for t in _toks
                            k = string(Base.JuliaSyntax.kind(t))
                            (k == "String" || k == "CmdString") || continue
                            if first(t.range) <= _eol[_j] <= last(t.range)
                                error("notebooks_from_source: line-grain hiding inside an ",
                                    "open multiline literal (string or command) (",
                                    repr(lf.text), ") — the appended ' # hide' would alter ",
                                    "the literal's runtime bytes (§4.3 edge (i)); hide the ",
                                    "whole cell or move the marker outside the literal")
                            end
                        end
                    end
                end
                carriage && _carriage_envelope(io, c, chain;
                    hidden_idx = [length(c.carried) + j - 1
                                  for (j, lf) in enumerate(c.lines) if lf.fate === :hide])
                bodyl = [lf.fate === :hide ? lf.text * " # hide" : lf.text for lf in c.lines]
                f = _fence(bodyl)
                println(io, f, "@example ", exec_chain)
                foreach(l -> println(io, l), bodyl)
                println(io, f)
                println(io)
            end
        end
    end
    return String(take!(io))
end

count_doctests(page::String) = length(collect(eachmatch(r"^```jldoctest"m, page)))

function derive_pages(spec::SourceSpec, cells::Vector{Cell})
    stem = splitext(basename(spec.path))[1]
    # Namespace injectivity (reconfirm wave): carriage blocks are `gometa_carriage_<stem>`
    # and execution blocks `gometa_<stem>` — a stem itself starting with `carriage_` would
    # alias the carriage namespace of ANOTHER stem in the same build (stem `carriage_x`'s
    # exec name == stem `x`'s carriage name). The prefix is reserved; refuse loudly.
    startswith(stem, "carriage_") && error("notebooks_from_source: the page stem ",
        repr(stem), " begins with the reserved prefix 'carriage_' — its execution ",
        "namespace gometa_", stem, " would alias the carriage namespace of stem ",
        repr(stem[10:end]), "; rename the source file")
    sections = sectionize(cells)
    keep_all(s) = true
    # the V4-guard invariant, relocated (see sectionize): line-less carrier cells are
    # placement-only — the reader page's section selection must not see their labels
    drops(s) = any(m in (:solution, :deep_dive) for c in vcat(s.heading === nothing ? Cell[] : [s.heading], s.cells) if !isempty(c.lines) for m in meaning(c, spec.legend))
    keep_reader(s) = !drops(s)
    full   = page_body(sections, spec.legend, keep_all, stem; carriage = true)
    reader = page_body(sections, spec.legend, keep_reader, stem; carriage = false)
    nfull, nreader = count_doctests(full), count_doctests(reader)
    tail_full = """
    ---

    ## How this page was made

    This page (and its reader twin) was derived from `notebooks/src/$stem.jl` by
    `notebooks_from_source.jl` — the `#~` marks in that one source file decided which
    sections appear here and which tests the docs build runs. This full page carries
    **$nfull** `jldoctest` block(s); the reader page carries **$nreader** — the marks
    chose the manual-page test selection (docstring doctests are a SEPARATE channel —
    a `makedocs(modules = …)` configuration this site does not enable). The execution
    axis has three distinct states:

    | state | mechanism | executed at docs build? |
    |---|---|---|
    | run + shown | a named `@example` block | yes |
    | run + hidden | `# hide` on the line (a fully hidden cell becomes a named `@setup`) | yes — the SOURCE line is hidden; a `# hide` line's output can still show |
    | shown, not run | a plain fenced block | no |

    This FULL page is a TRANSFORMATION artifact (v0.3.1): every
    non-discarded metaLine — `#~` marks and `#]` close-markers alike — and every
    hidden non-executed line rides INVISIBLY in the
    page's `@setup gometa_carriage_…` blocks (`## `-commented original bytes with an
    `##gometa carriage v1` index header — invisible on the built site and absent from its
    search index), while hidden lines of EXECUTED blocks stay in place natively
    (`# hide`-suffixed lines and whole `@setup` bodies: they run at the docs build,
    display-hidden, and their positions are recorded in each envelope's `hidden=`
    indices). The reader twin is a VIEW: its trimmed sections travel nowhere and it
    carries no envelopes. The FULL notebook edition is the same transformation in
    notebook form (HTML comments in markdown cells, `gometa` cell metadata in code
    cells); discarded lines travel nowhere in any edition.

    Regenerate and byte-compare every GENERATED file (notebooks and pages) yourself:
    `julia --startup-file=no --project=. notebooks_from_source.jl --check` — the executed
    notebook edition carries real kernel outputs and is validated separately, outside
    this byte gate.
    """
    tail_reader = """
    ---

    *A trimmed reading view derived from the same source as the
    [full page]($stem-full.md). The trim is SECTION-grain: a section whose marks say
    solution or deep-dive leaves whole — heading, prose, and any unmarked lines inside
    it included. This page carries $nreader `jldoctest` block(s) to the full page's
    $nfull — the marks chose.*
    """
    return [(joinpath(DOCS_DIR, "$stem-full.md"),   full * tail_full),
            (joinpath(DOCS_DIR, "$stem-reader.md"), reader * tail_reader)]
end

# ── driver ──────────────────────────────────────────────────────────────────────────────

derive(spec::SourceSpec) = derive_from_bytes(read(spec.path), spec)

function derive_from_bytes(bytes::Vector{UInt8}, spec::SourceSpec)
    r = GoMeta.goMeta(bytes)
    r.status == GoMeta.PROCESS_OK || error("EMIT FAILURE: processing failed for $(spec.path): $(r.status)")
    fates = verdict_fates(String(copy(bytes)), GoMeta.altValues_evals(r), GoMeta.content_fingerprint(r))
    witness_against_render(fates, String(copy(GoMeta.outputs(r).render_bytes)))
    cells = partition(fates)
    join_labels!(cells, GoMeta.altValues_evals(r), GoMeta.content_fingerprint(r))
    n_discarded = count(lf -> lf.fate === :discard, fates)
    n_hidden = count(lf -> lf.fate === :hide, fates)
    stem = splitext(basename(spec.path))[1]
    digest = bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(String(GoMeta.serialize_evals(GoMeta.altValues_evals(r)))))))[1:8]
    label_counts = join(sort(["$(l)×$(count(c -> l in c.labels, cells))" for l in Set(l for c in cells for l in c.labels)]), " ")
    println("  labels on cells: ", isempty(label_counts) ? "(none)" : label_counts, " · verdict digest ", digest)
    outputs = Tuple{String,String}[]
    for ed in spec.editions
        (ecells, omitted) = edition_cells(cells, spec.legend, ed)
        footer_lines = ["---",
            "*How this notebook was made:* derived from `notebooks/src/$stem.jl` by " *
            "`notebooks_from_source.jl` (edition **$ed**; $omitted cell(s) omitted by this " *
            "edition's policy; $n_discarded source line(s) removed and $n_hidden hidden by the " *
            "engine's own verdicts before any policy ran; verdict digest `$digest`). Hidden lines " *
            "and the source's `#~` metaLines travel INVISIBLY with this file — as HTML comments " *
            "in markdown cells and under the `gometa` key in code-cell metadata — so the GoMeta " *
            "data can be read and worked with in this artifact as in the source; discarded lines " *
            "do not travel" *
            (ed === :student ? ", and neither do this edition's policy omissions (solution " *
             "cells and their marks are deliberately absent from the worksheet)" : "") *
            ". Regenerate and byte-compare every " *
            "generated file: `julia --startup-file=no --project=. notebooks_from_source.jl --check` " *
            "— the executed edition is validated separately."]
        ed === :slides && push!(footer_lines,
            "*Slide dispositions are scraped from the source's depth marks — depth is not on " *
            "the evaluated-values surface at this release; a dedicated slide vocabulary is " *
            "future work.*")
        footer = Cell(:markdown, [LineFate(l, :show) for l in footer_lines], join(footer_lines, '\n'), Set{Symbol}(), 0, LineFate[])
        push!(ecells, (footer, ed === :slides ? "\"slideshow\": {\"slide_type\": \"skip\"}" : "", String[]))
        name = ed === :full ? "$stem.ipynb" : "$stem-$ed.ipynb"
        push!(outputs, write_notebook(joinpath(NB_DIR, name), ecells))
        println("  $name: $(length(ecells)) cells emitted, $omitted omitted by policy, $n_discarded source line(s) engine-discarded")
    end
    if spec.pages
        for (path, content) in derive_pages(spec, cells)
            push!(outputs, (path, content))
            println("  $(basename(path)): $(count_doctests(content)) jldoctest block(s)")
        end
    end
    return outputs
end

# ── the self-check battery (--check): the semantic guards behind the byte gate ──────────
# Inline fixtures pin the verdict-driven semantics the byte gate alone cannot see: the
# ensure-token trap (the exact class the old render walk mis-fated SILENTLY at v0.3),
# the inline show-override, discard absence (the security edge: discarded bytes never
# travel), carriage completeness (non-discarded metaLines travel exactly once), and the
# carrier-escape round-trip.
function run_selfchecks()
    fail(msg) = error("SELF-CHECK FAILED: " * msg)
    for s in ["---", "--", "-\\-", "a--b\\c", "\\", "-", "-\\--\\-", "x -- y -- z",
              "#~2 \"A -- B\" :label1", "\\--", "--\\-", "-\\", "----", "-- -->", "->x-"]
        carrier_unescape(carrier_escape(s)) == s || fail("escape round-trip broke on " * repr(s))
        occursin("--", carrier_escape(s)) && fail("escape left `--` inside a comment payload for " * repr(s))
    end
    legend = Dict(:label1 => :parameters, :label2 => :expensive, :label3 => :solution,
                  :label4 => :deep_dive, :label5 => :private)
    fixspec(name) = SourceSpec(name, legend, [:full], false)
    function fates_of(src::String)
        r = GoMeta.goMeta(Vector{UInt8}(codeunits(src)))
        r.status == GoMeta.PROCESS_OK || fail("fixture did not process: $(r.status)")
        f = verdict_fates(src, GoMeta.altValues_evals(r), GoMeta.content_fingerprint(r))
        witness_against_render(f, String(copy(GoMeta.outputs(r).render_bytes)))
        return f
    end
    nb_of(src::String, name::String) =
        last(only(derive_from_bytes(Vector{UInt8}(codeunits(src)), fixspec(name))))
    # the ensure-token trap — verdict-hidden despite render byte-identity
    trap = "#~ hide\nx = 1\n## authored comment line\ny = 2\n#]\nz = 3\n"
    tf = fates_of(trap)
    [lf.fate for lf in tf] == [:hide, :hide, :hide, :hide, :hide, :show, :show] ||
        fail("ensure-token trap fates wrong: " * string([lf.fate for lf in tf]))
    for c in partition(tf), l in cell_source_lines(c)
        occursin("authored comment line", l) && !startswith(l, "<!--") &&
            fail("ensure-token trap: a hidden authored line is VISIBLE in a cell source")
    end
    # presence, not just invisibility (reconfirm true-up: the loop above passes
    # vacuously if carriage vanishes) — the hidden authored line must BE in a carrier
    tnb = nb_of(trap, "fixture-trap.jl")
    occursin("<!-- ## authored comment line -->", tnb) ||
        fail("ensure-token trap: the hidden authored line did not travel in a carrier")
    # the inline show-override inside a hidden block (inner verdict wins)
    inline = "a = 1\nb = 2  #~ hide\nc = 3  #~ discard\n#~ hide\nd = 4\ne = 5  #~ show\nf = 6\n#]\ng = 7\n"
    fi = fates_of(inline)
    [lf.fate for lf in fi] == [:show, :hide, :discard, :hide, :hide, :show, :hide, :hide, :show, :show] ||
        fail("inline-override fates wrong: " * string([lf.fate for lf in fi]))
    nb = nb_of(inline, "fixture-inline.jl")
    for payload in ["\"text\": \"#~ hide\"", "\"text\": \"#]\"",
                    "\"text\": \"" * json_escape("b = 2  #~ hide") * "\""]
        length(findall(payload, nb)) == 1 ||
            fail("carriage: expected exactly one metadata carry of " * payload)
    end
    # exactly-once means across BOTH channels (reconfirm true-up): these ride code-cell
    # metadata here, so a duplicate COMMENT-form carry is a defect
    occursin("<!-- #~ hide -->", nb) &&
        fail("carriage: a metadata-carried metaLine ALSO traveled as a comment")
    # the reserved polarity encoding refuses loudly too (reconfirm hardening)
    pol_fired = try
        verdict_fates("x = 1\n", [(UInt8[0x01], :visib, :hide, false)],
                      [(UInt8[0x01], Vector{UInt8}(codeunits("x = 1")))])
        false
    catch err
        err isa ErrorException && occursin("non-true polarity", err.msg)
    end
    pol_fired || fail("the polarity guard did not refuse a non-true :visib row loudly")
    occursin("e = 5  #~ show", nb) || fail("inline-override: the shown line left the source")
    occursin("\"text\": \"" * json_escape("c = 3  #~ discard") * "\"", nb) &&
        fail("discard: a discarded line traveled in metadata")
    occursin("c = 3", nb) && fail("discard: discarded bytes present in the artifact")
    # the bare-`##` ensure-token shape: a hidden line that IS the bare marker renders
    # markerless as-is — the witness must accept it (panel V1: the space-demanding
    # check false-redded this legitimate corpus shape); fates_of runs the witness
    trap2 = "#~ hide\n##\nx = 1\n#]\ny = 2\n"
    t2 = fates_of(trap2)
    [lf.fate for lf in t2] == [:hide, :hide, :hide, :hide, :show, :show] ||
        fail("bare-## trap fates wrong: " * string([lf.fate for lf in t2]))
    # the verdict-domain whitelist refuses loudly on an unknown :visib value (panel V1
    # MAJOR: a future verdict family must never silently emit as visible text)
    whitelist_fired = try
        verdict_fates("x = 1\n", [(UInt8[0x01], :visib, :fold, true)],
                      [(UInt8[0x01], Vector{UInt8}(codeunits("x = 1")))])
        false
    catch err
        err isa ErrorException && occursin("unknown visibility verdict", err.msg)
    end
    whitelist_fired || fail("the unknown-verdict whitelist did not refuse :fold loudly")
    # the student worksheet never smuggles solution bytes — an INVISIBLE (fully hidden)
    # solution cell is omitted entirely, while the full edition carries it (panel V2)
    ssrc = "#~ hide{ :label3 }\n\n#~2 :label3\nsecret_solution = 42\n#]\n\nok = 1\n"
    sspec_full    = SourceSpec("fixture-solution.jl", legend, [:full], false)
    sspec_student = SourceSpec("fixture-solution.jl", legend, [:student], false)
    snb_full    = last(only(derive_from_bytes(Vector{UInt8}(codeunits(ssrc)), sspec_full)))
    snb_student = last(only(derive_from_bytes(Vector{UInt8}(codeunits(ssrc)), sspec_student)))
    occursin("secret_solution", snb_full) ||
        fail("full edition: a hidden solution cell must still travel invisibly")
    occursin("secret_solution", snb_student) &&
        fail("student edition: hidden solution bytes SMUGGLED into the worksheet")
    # discard absence at block grain + detached-rule carriage (the `#]` closes the
    # depth-2 scope — WITHOUT it the scope persists across the blank and `ok = 2`
    # would inherit :label5 and discard too; the engine's scope rule, fixture-learned)
    dsrc = "#~ discard{ :label5 }\n\n# # Kept section\nvisible = 1\n\n#~2 :label5\nSECRET_SENTINEL = 99\n#]\n\nok = 2\n"
    dnb = nb_of(dsrc, "fixture-discard.jl")
    occursin("SECRET_SENTINEL", dnb) && fail("discard: block-discarded bytes present in the artifact")
    occursin("#~2 :label5", dnb) && fail("discard: a discarded metaLine traveled")
    occursin("<!-- #~ discard{ :label5 } -->", dnb) ||
        fail("carriage: the detached file rule did not travel as a carrier comment")
    (occursin("visible = 1", dnb) && occursin("ok = 2", dnb)) ||
        fail("discard fixture: shown content missing")
    # ── page-carriage fixtures (v0.3.1: the ruled envelope law + §4.3 edges) ──
    function pages_of(src::String, name::String)
        spec = fixspec(name)
        bytes = Vector{UInt8}(codeunits(src))
        r = GoMeta.goMeta(bytes)
        r.status == GoMeta.PROCESS_OK || fail("page fixture did not process: $(r.status)")
        fates = verdict_fates(String(copy(bytes)), GoMeta.altValues_evals(r), GoMeta.content_fingerprint(r))
        cells = partition(fates)
        join_labels!(cells, GoMeta.altValues_evals(r), GoMeta.content_fingerprint(r))
        pages = derive_pages(spec, cells)
        return last(pages[1]), last(pages[2])            # full, reader
    end
    psrc = "#~ discard{ :label5 }\n\n#~2 :label1\n# # Params section\n# hidden note line #~ hide\nn = 10\n\n#~2 :label4\n# # Deep section\ndeep = 1\n"
    pfull, preader = pages_of(psrc, "fixture-pages.jl")
    # (1) the FULL page carries: the detached file rule as a carrier envelope, the attached
    # meta runs, and the hidden prose line — each as `## `-payload under the reserved @setup
    occursin("```@setup gometa_carriage_", pfull) || fail("carriage: no carriage envelope on the full page")
    occursin("## #~ discard{ :label5 }", pfull)   || fail("carriage: the detached file rule did not ride the full page")
    occursin("## #~2 :label1", pfull)             || fail("carriage: an attached meta run did not ride the full page")
    occursin("hidden note line", pfull)           || fail("carriage: a hidden prose line did not ride the full page")
    # (2) header shape: the unproducible `##gometa` sigil with index fields
    occursin(r"##gometa carriage v1 kind=(markdown|code|carrier) n=\d+ carried=[\d,]* hidden=[\d,]*", pfull) ||
        fail("carriage: envelope header malformed or missing")
    # (3) the READER page is a VIEW: zero envelopes, and the trimmed deep section's
    # bytes travel NOWHERE in it
    occursin("gometa_carriage_", preader) && fail("2c: the reader page carries an envelope")
    occursin("deep = 1", preader)         && fail("2c: a trimmed section's bytes are on the reader page")
    # (4) hidden prose stays INVISIBLE in the full page's visible body (the envelope is the
    # only carrier): the line must not appear outside a `## `-payload
    for l in split(pfull, '\n')
        occursin("hidden note line", l) && !startswith(l, "## ") &&
            fail("carriage: a hidden prose line is VISIBLE on the full page")
    end
    # (5) the §4.3(a) authored-marker refusal: an authored `# hide` tail inside an executed
    # cell refuses loudly (edge (v)'s double-suffix case is answered by this refusal too)
    hide_refused = try
        pages_of("#~2 :label1\nx = 1 # hide\n", "fixture-hidetail.jl"); false
    catch err
        err isa ErrorException && occursin("'# hide'", err.msg)
    end
    hide_refused || fail("§4.3(a): an authored '# hide' tail was not refused")
    # (6) §4.3 edge (ii): partial fence hiding in markdown refuses loudly
    fence_refused = try
        pages_of("#~2 hide{ :label1 }\n# # S\n# ```jldoctest #~ hide\n# julia> 1\n# 1\n# ```\n", "fixture-fence.jl"); false
    catch err
        err isa ErrorException && occursin("partial fence hiding", err.msg)
    end
    fence_refused || fail("edge (ii): partial fence hiding was not refused")
    # (7) Jupyter adversarial carriage (the §3.5 audit): a hidden md line carrying `-->` and
    # `<!--` travels carrier-ESCAPED inside its comment wrapper (never raw — a raw payload
    # `-->` would close the wrapper early), the escape provably inverts, and kind fidelity
    # for a fully hidden CODE cell rides the metadata
    jsrc = "# tricky --> and <!-- inside #~ hide\n\n#~2 hide{ isCode }\nhidden_code = 7\n"
    jnb = nb_of(jsrc, "fixture-jadv.jl")
    occursin("tricky", jnb) || fail("jupyter adversarial: the tricky hidden line vanished")
    # the ESCAPED payload form (`-\->` / `<!-\-`; JSON doubles each backslash) must be the
    # form on the artifact…
    occursin("tricky -\\\\-> and <!-\\\\- inside", jnb) ||
        fail("jupyter adversarial: the payload's `--` runs did not travel carrier-escaped")
    # …inside the exact comment WRAPPER (a broken html_comment emitting the escaped text
    # VISIBLY would satisfy the substring asserts alone), and exactly once:
    occursin("<!-- # tricky -\\\\-> and <!-\\\\- inside #~ hide -->", jnb) ||
        fail("jupyter adversarial: the exact escaped comment wrapper is missing")
    length(findall("tricky", jnb)) == 1 ||
        fail("jupyter adversarial: the tricky payload must appear exactly once (inside its wrapper)")
    # …and the raw form must NOT be (wrapper delimiters are the only raw `-->`s)
    occursin("tricky --> and", jnb) &&
        fail("jupyter adversarial: a raw payload `-->` leaked into the artifact")
    # reversibility, pinned on the artifact's own form: the decoder's documented inverse
    # recovers the original bytes from the escaped payload
    carrier_unescape("tricky -\\-> and <!-\\- inside") == "tricky --> and <!-- inside" ||
        fail("jupyter adversarial: carrier_unescape does not invert the escaped payload")
    occursin("\"kind\": \"code\"", jnb) || fail("jupyter adversarial: fully hidden code cell lost kind fidelity")
    # (8) the mark_depth ≡ law (R-INERT-4; reconfirm wave): an inert `#~2! x` head governs
    # its cell at depth 2 exactly like live `#~2` — identical slides-edition slide_type
    # sequences, subslide included (pre-fix the inert head scraped as no-depth → fragment)
    slidespec(name) = SourceSpec(name, legend, [:slides], false)
    slideseq(nb) = [m.captures[1] for m in eachmatch(r"\"slide_type\": \"(\w+)\"", nb)]
    snb_i = last(only(derive_from_bytes(Vector{UInt8}(codeunits("#~2! x\ncode9 = 1\n")), slidespec("fixture-slides-inert.jl"))))
    snb_l = last(only(derive_from_bytes(Vector{UInt8}(codeunits("#~2\ncode9 = 1\n")), slidespec("fixture-slides-live.jl"))))
    slideseq(snb_i) == slideseq(snb_l) || fail("slides ≡: inert vs live twin slide_type sequences differ")
    "subslide" in slideseq(snb_i) || fail("slides ≡: the inert depth-2 head did not scrape as depth 2")
    # the tilde-run and first-digit forms obey the same ≡ (a constant-depth mutant fails):
    for (isrc, lsrc, nm) in (("#~~! x\ncode8 = 1\n", "#~~\ncode8 = 1\n", "tilde2"),
                             ("#~31! x\ncode7 = 1\n", "#~31\ncode7 = 1\n", "digit31"))
        a8 = last(only(derive_from_bytes(Vector{UInt8}(codeunits(isrc)), slidespec("fixture-slides-" * nm * "-i.jl"))))
        b8 = last(only(derive_from_bytes(Vector{UInt8}(codeunits(lsrc)), slidespec("fixture-slides-" * nm * "-l.jl"))))
        slideseq(a8) == slideseq(b8) || fail("slides ≡ (" * nm * "): inert vs live twin sequences differ")
        nm == "tilde2" && ("subslide" in slideseq(a8) || fail("slides ≡ (tilde2): depth-2 tilde run must scrape as depth 2"))
    end
    # (9) exact-index envelope pinning (a PARTIALLY hidden executed cell): concrete
    # n=/carried=/hidden= VALUES + the in-place ` # hide` suffix on exactly the hidden line
    # (0-based over [carried…, lines…]: 0 = the metaLine, 2 = the hidden body line)
    p2full, _ = pages_of("#~2 :label1\nshown1 = 1\nhid = 2 #~ hide\nshown2 = 3\n", "fixture-hidx.jl")
    occursin("##gometa carriage v1 kind=code n=4 carried=0 hidden=2", p2full) ||
        fail("exact-index: the executed-cell envelope header indices are wrong")
    occursin("## #~2 :label1", p2full) || fail("exact-index: the carried metaLine payload is missing")
    occursin("hid = 2 #~ hide # hide", p2full) || fail("exact-index: the hidden line lost its in-place ' # hide' suffix")
    occursin("shown1 = 1 # hide", p2full) && fail("exact-index: a SHOWN line took a ' # hide' suffix")
    occursin("shown2 = 3 # hide", p2full) && fail("exact-index: a SHOWN line took a ' # hide' suffix")
    # (10) a FULLY hidden executed cell: the named @setup channel, all-indices hidden=,
    # body riding IN PLACE (not as envelope payload)
    p3full, _ = pages_of("#~2 hide{ isCode }\nsecret9 = 9\n", "fixture-fullhide.jl")
    occursin("```@setup gometa_fixture-fullhide", p3full) ||
        fail("full-hide: the fully hidden executed cell did not become a named @setup block")
    occursin("##gometa carriage v1 kind=code n=2 carried=0 hidden=1", p3full) ||
        fail("full-hide: the envelope header indices are wrong")
    occursin("\nsecret9 = 9\n", p3full) || fail("full-hide: the hidden body line is not riding in place")
    length(findall("secret9 = 9", p3full)) == 1 || fail("full-hide: the body must ride exactly once")
    first(findfirst("secret9 = 9", p3full)) > first(findfirst("```@setup gometa_fixture-fullhide", p3full)) ||
        fail("full-hide: the body must sit inside the named @setup block")
    occursin("```@setup gometa_fixture-fullhide\nsecret9 = 9\n```", p3full) ||
        fail("full-hide: the exact opener/body/closer block shape is broken")
    # (11) §4.3 edge (iii): a body backtick run forces a LONGER generated fence (4+)
    p4full, _ = pages_of("#~2 :label2\ns = \"\"\"\n```\n\"\"\"\n", "fixture-outrun.jl")
    occursin("````julia", p4full) || fail("edge (iii): the generated fence did not outrun the body's ``` run")
    p4b, _ = pages_of("#~2 :label2\ns6 = \"\"\"\n````\n\"\"\"\n", "fixture-outrun4.jl")
    occursin("`````julia", p4b) || fail("edge (iii): a 4-run body did not force a 5-backtick fence")
    p4c, _ = pages_of("#~2 :label1\ncmd9 = ```\necho ok line\n``` ## pad-close\n", "fixture-outrun-exec.jl")
    occursin("````@example", p4c) || fail("edge (iii): the EXECUTED branch fence did not outrun a ``` body line")
    # (12) the reserved-stem guard: a `carriage_`-prefixed stem refuses (namespace injectivity)
    stem_refused = try
        pages_of("#~2 :label1\nx = 1\n", "carriage_x.jl"); false
    catch err
        err isa ErrorException && occursin("reserved prefix", err.msg)
    end
    stem_refused || fail("reserved-stem: a carriage_-prefixed stem was not refused")
    # (13) the forged-envelope refusals: authored prose stripping to a reserved-namespace
    # fence opener, and to the `##gometa` sigil — both refuse loudly
    forge1 = try
        pages_of("#~2 :label1\n# # S\n# ```@setup gometa_carriage_evil\n# ## fake\n# ```\n", "fixture-forge1.jl"); false
    catch err
        err isa ErrorException && occursin("reserved `gometa_` namespace", err.msg)
    end
    forge1 || fail("forged-envelope: a reserved-namespace fence opener was not refused")
    forge2 = try
        pages_of("#~2 :label1\n# ##gometa carriage v1 kind=code n=1 carried= hidden=\n", "fixture-forge2.jl"); false
    catch err
        err isa ErrorException && occursin("sigil", err.msg)
    end
    forge2 || fail("forged-envelope: the ##gometa sigil was not refused")
    # (14) §4.3 edge (i): a hidden line inside an OPEN multiline string literal refuses
    str_refused = try
        pages_of("#~2 :label1\ns = \"\"\"\nline #~ hide\n\"\"\"\nafter_str = 10\n", "fixture-strhide.jl"); false
    catch err
        err isa ErrorException && occursin("open multiline literal", err.msg)
    end
    str_refused || fail("edge (i): hiding inside an open multiline string was not refused")
    # (15) the odd-delimiter-count refusal: an authored unclosed fence refuses
    odd_refused = try
        pages_of("#~2 :label1\n# # S\n# ```julia\n# x = 1\n", "fixture-oddfence.jl"); false
    catch err
        err isa ErrorException && occursin("unbalanced fence delimiters", err.msg)
    end
    odd_refused || fail("odd-count: an unclosed authored fence was not refused")
    # (16) forged-envelope BODY-site twins + tab-indent variant (reconfirm wave 2: the
    # The earlier fixtures both routed through the HEADING path; a body-site-only regression was
    # invisible to the battery)
    forge3 = try
        pages_of("#~2 :label1\n# prose line here\n#  ##gometa carriage v1 kind=code n=1 carried= hidden=\n", "fixture-forge3.jl"); false
    catch err
        err isa ErrorException && occursin("sigil", err.msg)
    end
    forge3 || fail("forged-envelope: the BODY-cell two-space sigil form was not refused")
    forge4 = try
        pages_of("#~2 :label1\n# prose line here\n# ```@example gometa_evil\n# ```\n", "fixture-forge4.jl"); false
    catch err
        err isa ErrorException && occursin("reserved `gometa_` namespace", err.msg)
    end
    forge4 || fail("forged-envelope: a BODY-cell @example gometa_* fence was not refused")
    forge5 = try
        pages_of("#~2 :label1\n# prose line here\n#\t```@setup gometa_carriage_evil\n#\t```\n", "fixture-forge5.jl"); false
    catch err
        err isa ErrorException && occursin("reserved `gometa_` namespace", err.msg)
    end
    forge5 || fail("forged-envelope: a TAB-led gometa_* fence was not refused")
    # (17) edge (i) toggle ORDER: a hidden OPENING delimiter refuses (update-then-check —
    # a check-then-update mutant passes fixture 14 yet injects on the opener); a hidden
    # CLOSING delimiter is ACCEPTED with its native suffix (lands after the close)
    stro_refused = try
        pages_of("#~2 :label1\ns4 = \"\"\" #~ hide\nbody line here\n\"\"\" ## pad-close\nafter_open = 10\n", "fixture-strhide-open.jl"); false
    catch err
        err isa ErrorException && occursin("open multiline literal", err.msg)
    end
    stro_refused || fail("edge (i): a hidden OPENING delimiter line was not refused (toggle order)")
    p14c, _ = pages_of("#~2 :label1\ns5 = \"\"\"\nbody line here\n\"\"\" #~ hide\nafter_close = 10\n", "fixture-strhide-close.jl")
    occursin("\"\"\" #~ hide # hide", p14c) || fail("edge (i): a hidden CLOSING delimiter must be accepted with its native suffix")
    # (18) edge (i) Cmd-literal family: a hidden line inside an open ``` command literal
    # refuses (its arguments are runtime bytes exactly like string contents)
    cmd_refused = try
        pages_of("#~2 :label1\ncmd0 = ```\necho hidden #~ hide\n``` ## pad-close\nafter_cmd = 12\n", "fixture-cmdhide.jl"); false
    catch err
        err isa ErrorException && occursin("open multiline literal", err.msg)
    end
    cmd_refused || fail("edge (i): a hidden line inside an open ``` Cmd literal was not refused")
    # (19) edge (i), lexer-grounded: block-comment and escaped-delimiter DECOYS ahead of
    # a REAL open literal — the lexer classifies the decoys away and refuses the hidden
    # line inside the actual literal (the retired toggle gate refused these as unprovable)
    conf1_refused = try
        pages_of("#~2 :label1\n#= \"\"\" =# note9 = 1\ns2 = \"\"\"\nhidden here #~ hide\n\"\"\" ## pad-close\nafter_conf = 10\n", "fixture-confound1.jl"); false
    catch err
        err isa ErrorException && occursin("open multiline literal", err.msg)
    end
    conf1_refused || fail("edge (i): hiding inside the real literal behind a block-comment decoy was not refused")
    conf2_refused = try
        pages_of("#~2 :label1\ns3 = \"\"\"\ninner \\\"\"\" quoted line\nhidden line #~ hide\n\"\"\" ## pad-close\nafter_esc = 10\n", "fixture-confound2.jl"); false
    catch err
        err isa ErrorException && occursin("open multiline literal", err.msg)
    end
    conf2_refused || fail("edge (i): hiding inside a literal with escaped delimiters was not refused")
    # (20) width/state-aware fence scan — POSITIVE control: a literal ``` payload inside
    # a wider authored fence passes and renders (the retired odd-count scan false-refused it)
    p16, _ = pages_of("#~2 :label1\n# # Wide\n# ````julia\n# ``` literal line\n# ````\n", "fixture-widefence.jl")
    occursin("``` literal line", p16) || fail("width-aware: a literal ``` payload inside a wider fence must pass and render")
    # (21) parser-mirror — a suffixed EXACT-width line IS a closer (measured: the parser
    # closes on the run and ignores the suffix), so a hidden one refuses as the
    # opener/closer FATE mismatch
    wmix_refused = try
        pages_of("#~2 :label1\n# # Wmix\n# ````julia\n# ``` inner line\n# ```` #~ hide\n", "fixture-widemix.jl"); false
    catch err
        err isa ErrorException && occursin("partial fence hiding", err.msg)
    end
    wmix_refused || fail("parser-mirror: a hidden exact-width suffixed CLOSER (measured: suffix allowed) must refuse the fate mismatch")
    # (22) TAB-led fence delimiters are classified (the retired literal-prefix scan missed
    # them entirely — a tab-led partial hide sailed through)
    tab_refused = try
        pages_of("#~2 hide{ :label1 }\n# # Tabf\n#\t```julia #~ hide\n# xx9 = 11\n#\t```\n", "fixture-tabfence.jl"); false
    catch err
        err isa ErrorException && occursin("partial fence hiding", err.msg)
    end
    tab_refused || fail("width-aware: a TAB-led hidden opener escaped the fence scan")
    # (23) three delimiters: a closed pair + a stray opener refuses as unbalanced
    odd3_refused = try
        pages_of("#~2 :label1\n# # Odd3\n# ```julia\n# aa1 = 1\n# ```\n# ```python\n# bb2 = 2\n", "fixture-odd3.jl"); false
    catch err
        err isa ErrorException && occursin("unbalanced fence delimiters", err.msg)
    end
    odd3_refused || fail("odd-count: a closed pair + stray opener was not refused")
    # (24) the TILDE fence flavor (compliance breaker MAJOR): Documenter parses ~~~ fences
    # identically — an authored tilde @setup forge refuses, and tilde partial hiding refuses
    forge6 = try
        pages_of("#~2 :label1\n# prose line here\n# ~~~@setup gometa_carriage_evil\n# ~~~\n", "fixture-forge6.jl"); false
    catch err
        err isa ErrorException && occursin("reserved `gometa_` namespace", err.msg)
    end
    forge6 || fail("forged-envelope: a TILDE-fence @setup gometa_* forge was not refused")
    # (measured nuance, MDPARSE-matrix.out row tilde-in-tilde-info: a tilde OPENER whose
    # info contains a tilde is NOT a fence — so an inline `#~` marker on the OPENER line
    # de-fences it; the mixed-fate tilde case is therefore a hidden CLOSER, whose suffix
    # is free)
    tilde_refused = try
        pages_of("#~2 :label1\n# # Tildef\n# ~~~text\n# body tilde line\n# ~~~ #~ hide\n", "fixture-tildefence.jl"); false
    catch err
        err isa ErrorException && occursin("partial fence hiding", err.msg)
    end
    tilde_refused || fail("width-aware: TILDE-fence partial hiding was not refused")
    # (25) lexer ground truth — the STRING-DECOY (round-2 counterexample): a single-quote
    # string containing ``` must not poison the Cmd state; the hidden line inside the REAL
    # Cmd literal refuses
    decoy1 = try
        pages_of("#~2 :label1\nnoteA = \"```\"\ncmdB = ```\necho secret9 #~ hide\n``` ## pad-close\nafter_x = 12\n", "fixture-decoy-string.jl"); false
    catch err
        err isa ErrorException && occursin("open multiline literal", err.msg)
    end
    decoy1 || fail("lexer: the string-decoy counterexample was not refused")
    # (26) the LINE-COMMENT decoy: `# \"\"\"` in a trailing comment must not poison the
    # string state; the hidden line inside the REAL string refuses
    decoy2 = try
        pages_of("#~2 :label1\nxA = 1 # \"\"\"\nsB = \"\"\"\nbody here #~ hide\n\"\"\" ## pad-close\nafter_y = 13\n", "fixture-decoy-comment.jl"); false
    catch err
        err isa ErrorException && occursin("open multiline literal", err.msg)
    end
    decoy2 || fail("lexer: the line-comment-decoy counterexample was not refused")
    # (27) ACCEPT control: a CLOSED one-line Cmd + a later hidden line outside every
    # literal — accepted, with the native suffix in place
    p27, _ = pages_of("#~2 :label1\ncmdA = ```echo x```\nplain_ln = 1\nhide_me = 2 #~ hide\n", "fixture-closedcmd.jl")
    occursin("hide_me = 2 #~ hide # hide", p27) || fail("lexer: a hidden line outside every literal must be accepted")
    # (28) parser-mirror ACCEPT: an exact-width SUFFIXED closer closes (measured:
    # closer-suffixed row) — same fate, no refusal, suffix rides the page
    p28, _ = pages_of("#~2 :label1\n# # Sfx\n# ```julia\n# code_q = 1\n# ``` trailing note\n", "fixture-sfxclose.jl")
    occursin("``` trailing note", p28) || fail("parser-mirror: a suffixed exact-width closer must close and render")
    # (29) parser-mirror: a 4-SPACE-led opener IS a fence (measured: opener-4space row —
    # the CommonMark literal-code rule does NOT apply); partial hiding refuses
    ind5_refused = try
        pages_of("#~2 hide{ :label1 }\n# # Ind5\n#     ```julia #~ hide\n# ind_code = 1\n# ```\n", "fixture-ind5.jl"); false
    catch err
        err isa ErrorException && occursin("partial fence hiding", err.msg)
    end
    ind5_refused || fail("parser-mirror: a 4-space-led hidden opener escaped the scan")
    # (30) the nested-context bound: a blockquoted fence + hidden lines refuses fail-closed
    bq_refused = try
        pages_of("#~2 hide{ :label1 }\n# # Bq\n# > ```julia #~ hide\n# > bq_code = 1\n# > ```\n", "fixture-bqfence.jl"); false
    catch err
        err isa ErrorException && occursin("nested Markdown context", err.msg)
    end
    bq_refused || fail("nested-context: a blockquoted fence with hidden lines was not refused")
    # (31) the reserved-mention refusal covers PROSE in any context (the fixed point that
    # closes the blockquote/list/indent forge family)
    mention_refused = try
        pages_of("#~2 :label1\n# See the gometa_carriage_montecarlo block for details.\n", "fixture-mention.jl"); false
    catch err
        err isa ErrorException && occursin("reserved `gometa_` namespace", err.msg)
    end
    mention_refused || fail("reserved-mention: an authored gometa_ mention was not refused")
    # (32) every ERROR KIND refuses (probe: ErrorInvalidEscapeSequence — a specific error
    # token REPLACES the String token, so a generic-"error" test alone would miss it)
    err_refused = try
        pages_of("#~2 :label1\ns8 = \"\"\"\nbad\\q line #~ hide\n\"\"\" ## pad\nafter_e = 14\n", "fixture-errkind.jl"); false
    catch err
        err isa ErrorException && occursin("cannot be proven", err.msg)
    end
    err_refused || fail("lexer: a specific error kind did not trigger the unprovable refusal")
    # (33) the reserved-mention law covers CODE lines too (wave-5b: original-lines scan)
    codemention_refused = try
        pages_of("#~2 :label1\nxg = \"gometa_evil\"\n", "fixture-codemention.jl"); false
    catch err
        err isa ErrorException && occursin("reserved `gometa_` namespace", err.msg)
    end
    codemention_refused || fail("reserved-mention: a code-line gometa_ mention was not refused")
    # (34) the nested-guard's DISCLOSED breadth: a blockquoted PROSE mention of ``` in a
    # hidden-line cell refuses (deliberate fail-closed breadth, pinned)
    bq2_refused = try
        pages_of("#~2 hide{ :label1 }\n# # Bq2\n# > prose mentions ``` inline\n# hidden line here #~ hide\n", "fixture-bqprose.jl"); false
    catch err
        err isa ErrorException && occursin("nested Markdown context", err.msg)
    end
    bq2_refused || fail("nested-context: the disclosed blockquote-mention breadth is unpinned")
    return nothing
end

function main()
    check = "--check" in ARGS
    check && (run_selfchecks(); println("--check: self-check battery green (escape · ensure-token trap · inline override · discard absence · carriage · carriage edges/forgery/≡-depth)"))
    failures = String[]
    for spec in SOURCES
        println(basename(spec.path), ":")
        for (path, content) in derive(spec)
            if check
                isfile(path) || (push!(failures, "$path: missing"); continue)
                read(path, String) == content || push!(failures, "$path: differs from regeneration")
            else
                write(path, content)
            end
        end
    end
    if check
        isempty(failures) || (foreach(f -> println(stderr, "CHECK FAILED: ", f), failures); exit(1))
        println("--check: every generated file (notebooks and pages) regenerates byte-identically")
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    try
        main()
    catch err
        err isa ErrorException || rethrow()
        println(stderr, "notebooks_from_source: ", err.msg)
        exit(1)
    end
end
