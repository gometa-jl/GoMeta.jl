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
    ## shapes return nothing (content). The `!` tail = the inert form (no depth); the
    ## digit form takes the FIRST digit (the engine's first-digit depth semantics);
    ## the tilde-run form clamps to the window top (min(len, 8), the engine's clamp).
    m = match(r"^#(~+)([0-9]*)(!?)(?=[\h]|$)", lstrip(t))
    m === nothing && return nothing
    m.captures[3] == "!" && return nothing           # inert form — carries no depth
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
        # panel V4: line-less cells stay OUT of sectionize — pages are views
        # (R-EXT-11), and a surviving meta run must not steer the reader page's
        # label-based section selection (drops() would newly see its labels)
        isempty(c.lines) && continue
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

function page_body(sections::Vector{Section}, legend, keep::Function, chain::String)
    io = IOBuffer()
    for s in sections
        keep(s) || continue
        if s.heading !== nothing
            # the same no-trace guard as body cells (reconfirm wave: a fully hidden
            # heading must not leave stray blanks)
            hl = md_lines_page(s.heading)
            isempty(hl) || (println(io, join(hl, '\n')); println(io))
        end
        for c in s.cells
            # PAGES ARE VIEWS (owner-ruled 2026-08-12): carrier cells and carried meta
            # runs do not ride pages — the notebook full edition is the
            # metadata-bearing artifact; hidden lines DROP here (HTML comments render
            # VISIBLY through the Documenter markdown pipeline, probe-proven)
            (c.kind === :carrier || isempty(c.lines)) && continue
            ms = meaning(c, legend)
            if c.kind === :markdown
                pl = md_lines_page(c)
                # a fully hidden markdown cell leaves NO trace on the page (panel V4:
                # no stray blank lines for an invisible cell)
                isempty(pl) || (println(io, join(pl, '\n')); println(io))
            elseif :expensive in ms
                # the branch order is load-bearing: expensive-BEFORE-all-hidden keeps
                # the never-execute law (an all-hidden expensive cell must not fall to
                # the executing @setup branch below); when every line is hidden the
                # cell leaves no trace (panel V2/V4: no empty fence + caption)
                shown = code_lines(c)
                if !isempty(shown)
                    println(io, "```julia")
                    foreach(l -> println(io, l), shown)       # shown lines only;
                    println(io, "```")                        # hidden lines drop
                    println(io)
                    println(io, "*(Marked expensive in the source — shown here, deliberately NOT executed by the docs build.)*")
                    println(io)
                end
            elseif all(lf.fate === :hide for lf in c.lines)
                # execute-but-fully-hide → a NAMED @setup block (the # hide suffix hides
                # source only; a fully hidden cell must not leak its output either)
                println(io, "```@setup ", chain)
                foreach(l -> println(io, l), (lf.text for lf in c.lines))
                println(io, "```")
                println(io)
            else
                println(io, "```@example ", chain)
                for lf in c.lines
                    println(io, lf.fate === :hide ? lf.text * " # hide" : lf.text)
                end
                println(io, "```")
                println(io)
            end
        end
    end
    return String(take!(io))
end

count_doctests(page::String) = length(collect(eachmatch(r"^```jldoctest"m, page)))

function derive_pages(spec::SourceSpec, cells::Vector{Cell})
    stem = splitext(basename(spec.path))[1]
    sections = sectionize(cells)
    keep_all(s) = true
    drops(s) = any(m in (:solution, :deep_dive) for c in vcat(s.heading === nothing ? Cell[] : [s.heading], s.cells) for m in meaning(c, spec.legend))
    keep_reader(s) = !drops(s)
    full   = page_body(sections, spec.legend, keep_all, stem)
    reader = page_body(sections, spec.legend, keep_reader, stem)
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

    This page is a derived VIEW: verdict-hidden lines are simply not on it (except the
    lines of EXECUTED blocks — `# hide`-marked lines and whole `@setup` bodies — which
    run at the docs build and stay display-hidden on the built page, though they are
    plainly present in this page's raw markdown), and the source's `#~` metaLines do
    not ride it. The metadata-bearing artifact is the FULL
    notebook edition, where hidden lines and every metaLine travel invisibly (HTML
    comments in markdown cells, `gometa` cell metadata in code cells) in source form;
    discarded lines travel nowhere.

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
    return nothing
end

function main()
    check = "--check" in ARGS
    check && (run_selfchecks(); println("--check: self-check battery green (escape · ensure-token trap · inline override · discard absence · carriage)"))
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
