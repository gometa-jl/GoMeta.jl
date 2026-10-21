# notebooks_from_source.jl — derive the notebook (and the manual pages) from ONE
# marked Julia source file, purely from its `#~` metadata.
#
# What it does, end to end:
#   1. runs `GoMeta.goMeta` on the source (trusted committed input — see the SECURITY
#      section of the README) and requires `PROCESS_OK`;
#   2. takes each line's EFFECTIVE fate from the Engine's ANSWER for that line's Line
#      Component of the BLS Component tree — `GoMeta.evaluatedAltValue(delivery, line, :Visib)`:
#      the Component's own Visib rows, else its parent's up the tree, else the declared
#      default — never from the render bytes (at the
#      render grain an engine-hidden line and an authored marker-headed line are
#      byte-INDISTINGUISHABLE, the ensure-token fidelity bound) and never from a content
#      match. Ancestry and conditions are the Engine's business, never re-derived here;
#   3. partitions the source into cells by the documented conventions (blank lines and
#      text/code type changes bound blocks; `#~` / `#]` metadata lines are consumed as
#      control AND carried invisibly — the transformation principle: the GoMeta data
#      travels with the artifact in SOURCE form, as HTML comments in markdown cells and
#      as `gometa` cell metadata in code cells; hidden content lines travel the same
#      way; DISCARDED lines never travel) and joins each cell to its evaluated labels
#      through the tree: the Components that got label values (`GoMeta.scanAlterant(
#      delivery, :labels)`) attach to the cells whose source-line span they cover;
#   4. writes ONE notebook per source — the full edition: every surviving cell, with the
#      legend-driven tags (parameters · skip-execution · solution · deep-dive) — in
#      deterministic nbformat 4.5 JSON (fixed key order; content-derived cell ids;
#      a Julia kernelspec so standard executors pick the right kernel); the student,
#      report and slides editions were removed within the 0.4 development);
#   5. prints a content-free emission manifest per notebook (counts and label names,
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
## No development tool is loaded by this Extension: it consumes the Engine's answer through the
## delivered object and the BLS Component tree — through BLS's door — and nothing else.

# ── the source registry: file → legend + emitted targets ────────────────────────────────
const NB_DIR = joinpath(@__DIR__, "notebooks")

struct SourceSpec
    path::String                    # source file, relative to the repository root
    legend::Dict{Symbol,Symbol}     # label → meaning (parameters/expensive/solution/deep_dive/private)
    pages::Bool                     # also emit the Documenter manual page pair?
end

const SOURCES = [
    SourceSpec(joinpath(NB_DIR, "src", "montecarlo.jl"),
        Dict(:label1 => :parameters, :label2 => :expensive, :label3 => :solution,
             :label4 => :deep_dive, :label5 => :private),
        true),
    SourceSpec(joinpath(NB_DIR, "src", "quickstart.jl"),
        Dict(:label1 => :parameters, :label2 => :expensive, :label3 => :solution,
             :label4 => :deep_dive, :label5 => :private),
        false),
]

# ── engine consumption ──────────────────────────────────────────────────────────────────

struct LineFate
    text::String     # the ORIGINAL source line (clean, unprefixed)
    fate::Symbol     # :show | :hide | :discard
end

# THE FATE SOURCE IS THE ENGINE's ANSWER, per Line Component of the BLS Component tree — never the
# render (under the v0.3 ensure-token rule an authored `## `-headed line inside a hidden block
# renders AS-IS, byte-indistinguishable from a shown line — a render walk mis-fates exactly that
# class SILENTLY, probe-proven) and never a content match (the
# former join of the `:visib` rows to source spans by their verbatim bytes went with the Engine's
# stored copy of those bytes). Each source line's Line Component is found through the door by its
# input line number; its fate is `evaluatedAltValue(delivery, line, :Visib).value` — the Line's own Visib
# rows if any (an inline-governed line's verdict overrides its Block's: the Engine's inner-wins
# precedence), else its Block's, else the declared default `:show`. A source line with no Line
# Component (the empty tail after a final newline) is :show. A blank line inside a hidden or
# discarded Block now carries the Block's fate (the content match left it :show) — `partition`
# reads no blank line's fate. The verdict-domain whitelist stays: this generator's carriage
# semantics are DEFINED for show/hide/discard — a future verdict family must be adopted
# deliberately, never silently emitted as visible text.
function verdict_fates(input::String, delivery)
    inl = split(input, '\n')
    ps = delivery.blsComponentTree
    bynum = Dict{Int,Any}()
    for b in GoMeta.BLS.children(ps), l in GoMeta.BLS.children(ps, b)
        i = GoMeta.BLS.getElement(l, :inputLineNum)
        haskey(bynum, i) && error("EMIT FAILURE: two Line Components carry input line $i — the tree's line numbering broke")
        bynum[i] = l
    end
    fates = Symbol[]
    for i in eachindex(inl)
        l = get(bynum, i, nothing)
        f = l === nothing ? :show : GoMeta.evaluatedAltValue(delivery, l, :Visib).value
        f in (:show, :hide, :discard) ||
            error("EMIT FAILURE: unknown visibility verdict :$(f) — the carriage semantics cover show/hide/discard only; verdict-domain evolution must be adopted deliberately, never silently")
        push!(fates, f)
    end
    return [LineFate(String(inl[i]), fates[i]) for i in eachindex(inl)]
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
## the ENGINE refuses that family at parse (since v0.3.1), and `goMeta` runs
## before `partition`, so a bang-first line can never reach this out-of-tree mirror
## alive.
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
    span::UnitRange{Int}    # the cell's source-line span (input line numbers) — what the
                            # tree-keyed label join intersects with the Components' spans
                            # through the door (empty for a carrier cell)
    labels::Set{Symbol}
    carried::Vector{LineFate} # the meta run this cell carries in SOURCE form (the
                            # transformation principle: metaLines travel invisibly with
                            # the artifact; DISCARDED metaLines never travel)
end

# partition the source into blocks the way the engine's documented conventions cut them:
# blank lines and text/code type changes bound blocks; meta lines are consumed

function partition(fates::Vector{LineFate})
    cells = Cell[]
    cur = LineFate[]; curkind = :none; orig = Int[]
    metarun = LineFate[]              # the contiguous run of metaLines awaiting a home
    attach = LineFate[]               # the run attached to the block being built
    carried_of(run) = [lf for lf in run if lf.fate !== :discard]   # discard never travels
    flush!() = begin
        if !isempty(cur)
            kept = [lf for lf in cur if lf.fate !== :discard]
            push!(cells, Cell(curkind, kept, first(orig):last(orig), Set{Symbol}(), attach))
            attach = LineFate[]
        end
        cur = LineFate[]; curkind = :none; orig = Int[]
    end
    # a meta run separated from content by a blank line is DETACHED (a semantics-bearing
    # distinction — the corpus blankline fixture) and becomes its own carrier cell; a
    # run contiguous with following content attaches to that block's cell
    emit_detached!() = begin
        kept = carried_of(metarun)
        isempty(kept) || push!(cells, Cell(:carrier, LineFate[], 1:0, Set{Symbol}(), kept))
        metarun = LineFate[]
    end
    for (i, lf) in enumerate(fates)
        t = lf.text
        if is_blank_line(t) || is_meta_line(t)
            flush!()
            if is_meta_line(t)
                push!(metarun, lf)
            else
                emit_detached!()
            end
            continue
        end
        kind = is_prose_line(t) ? :markdown : :code
        kind == curkind || flush!()
        if isempty(cur) && !isempty(metarun)
            attach = carried_of(metarun)          # the run rides the block it governs
            metarun = LineFate[]
        end
        curkind = kind
        push!(cur, lf)
        push!(orig, i)
    end
    flush!()
    emit_detached!()                              # a trailing meta run gets its own cell
    # cells whose every line was discarded stay in the list (their evaluated labels must
    # still find a home in the coverage join); `full_cells` skips them at emission time
    return cells
end

# join labels onto cells THROUGH THE TREE: the Components that got
# label values — `scanAlterant(delivery, :labels)`, each with its sorted label names — attach to every
# content cell whose source-line span the Component's own span touches (a Block's line span through
# the door; a Line's input line; an inline Segment's owning Line). A Meta Component (the metaBlock a
# metaLine forms) carries labels for the content it governs; its own span holds no content line and
# joins no cell — by design, not a failure. A CONTENT Component with labels that joins no cell fails
# red (segmentation drift). Attribution is the tree's: a Block covering a prose run and a code run
# labels both cells — the Block's labels are the Block's (the former content-keyed containment join,
# with its registered limitation, went with the Engine's stored copy of the content bytes). The five
# generic labels this generator's legends bind are joined; the pictograph vocabulary carries no legend.
function _component_span(ps, c)
    c isa GoMeta.BLS.Block && return GoMeta.BLS.getElement(c, :startMainStr):GoMeta.BLS.getElement(c, :stopMainStr)
    c isa GoMeta.BLS.Line && return (i = GoMeta.BLS.getElement(c, :inputLineNum); i:i)
    c isa GoMeta.BLS.Segment && return (i = GoMeta.BLS.getElement(GoMeta.BLS.parent(ps, c), :inputLineNum); i:i)
    return 1:0
end
function join_labels!(cells::Vector{Cell}, delivery)
    ps = delivery.blsComponentTree
    unmatched = String[]
    for (c, a) in GoMeta.scanAlterant(delivery, :labels)
        sp = _component_span(ps, c)
        hit = false
        for cell in cells
            (cell.kind === :carrier || isempty(intersect(sp, cell.span))) && continue
            for l in a.value
                l in (:label1, :label2, :label3, :label4, :label5) && push!(cell.labels, l)
            end
            hit = true
        end
        hit || GoMeta.BLS.kind(c) === :Meta || push!(unmatched, "$(nameof(typeof(c))) at source lines $(sp)")
    end
    isempty(unmatched) || error("EMIT FAILURE: $(length(unmatched)) labelled Component(s) joined no cell — segmentation drift: " * repr(first(unmatched)))
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

# ── the invisible carriers (the transformation principle, the creator's decision of 2026-08-12) ──────
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

# the DOCUMENTER PAGE body of a markdown cell: hidden lines DROP from the body on BOTH pages
# (the creator's decision of 2026-08-12 for the then-views: HTML comments do not survive the Documenter markdown
# pipeline, probe-proven, and the pages are also GitHub-browsable); since v0.3.1 the FULL page carries
# them in its carriage envelope instead (`_carriage_envelope`, below) — the READER page alone is the
# envelope-free view; the student edition was removed
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

# the cell's emitted source lines — the writer's single authority
function cell_source_lines(c::Cell)
    is_carrierish(c) && return vcat([html_comment(lf.text) for lf in c.carried],
                                    [html_comment(lf.text) for lf in c.lines])
    return c.kind === :markdown ? md_lines(c) : code_lines(c)
end

function write_cell(io, c::Cell, ordinal::Int; tags::Vector{String} = String[])
    hidden_code = fully_hidden_code(c)
    kind = (c.kind === :markdown || is_carrierish(c)) ? "markdown" : "code"
    lines = cell_source_lines(c)
    src = source_array(lines)
    meta_parts = String[]
    isempty(tags) || push!(meta_parts, "\"tags\": [" * join(["\"" * t * "\"" for t in sort(tags)], ", ") * "]")
    gm = hidden_code ? gometa_meta(Cell(c.kind, LineFate[], c.span, c.labels, LineFate[]); kind_note = true) :
         (kind == "code" ? gometa_meta(c) : "")
    isempty(gm) || push!(meta_parts, gm)
    meta = "{" * join(meta_parts, ", ") * "}"
    print(io, "  {\"cell_type\": \"", kind, "\", \"id\": \"", cell_id(join(lines, '\n'), ordinal), "\", \"metadata\": ", meta)
    kind == "code" && print(io, ", \"execution_count\": null, \"outputs\": []")
    print(io, ", \"source\": ", src, "}")
end

function write_notebook(path::String, cells::Vector{Tuple{Cell,Vector{String}}})
    io = IOBuffer()
    println(io, "{")
    println(io, " \"cells\": [")
    for (i, (c, tags)) in enumerate(cells)
        write_cell(io, c, i; tags = tags)
        println(io, i == length(cells) ? "" : ",")
    end
    println(io, " ],")
    println(io, " \"metadata\": {\"kernelspec\": {\"display_name\": \"Julia 1.12\", \"language\": \"julia\", \"name\": \"julia-1.12\"}, \"language_info\": {\"name\": \"julia\", \"version\": \"1.12.5\"}},")
    println(io, " \"nbformat\": 4,")
    println(io, " \"nbformat_minor\": 5")
    print(io, "}")
    return (path, String(take!(io)))
end

# ── the full edition (the ONE notebook per source; the student, report and slides editions were removed) ─────────────

meaning(c::Cell, legend) = Set(get(legend, l, :none) for l in c.labels)

function full_cells(cells::Vector{Cell}, legend)
    out = Tuple{Cell,Vector{String}}[]
    for c in cells
        # fully engine-discarded AND carrying nothing — never emitted; a cell whose
        # visible lines all discarded but whose meta run travels stays as a carrier
        isempty(c.lines) && isempty(c.carried) && continue
        # carrier-rendering cells (detached meta runs, discarded-content cells with a
        # surviving meta run, fully hidden cells of ANY kind) are invisible: no tags
        # (an invisible cell is not a policy surface — papermill's singular `parameters`
        # anchor therefore falls to the first VISIBLE parameters cell, disclosed in the README)
        if c.kind === :carrier || isempty(c.lines) || fully_hidden(c)
            push!(out, (isempty(c.lines) && c.kind !== :carrier ?
                        Cell(:carrier, LineFate[], c.span, c.labels, c.carried) : c, String[]))
            continue
        end
        ms = meaning(c, legend)
        tags = String[]
        :parameters in ms && push!(tags, "parameters")
        :expensive in ms && push!(tags, "skip-execution")
        :solution in ms && push!(tags, "solution")
        :deep_dive in ms && push!(tags, "deep-dive")
        push!(out, (c, tags))
    end
    # papermill treats the FIRST parameters-tagged cell as THE parameters cell — the tag
    # stays singular per notebook (later parameter-labeled cells keep their other tags)
    seen_params = false
    for (i, (c, tags)) in enumerate(out)
        if "parameters" in tags
            seen_params && (out[i] = (c, filter(!=("parameters"), tags)))
            seen_params = true
        end
    end
    return out
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
        # The carrier-cell guard, in its v0.3.1 form (the decision: metaLines RIDE the full
        # page): line-less carrier cells now stay IN the
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

# ── the page-carriage envelope (v0.3.1: the envelope law) ──────────
# The FULL page is a transformation artifact: every non-discarded metaLine and every hidden
# non-executed line rides INVISIBLY in a reserved-name `@setup`-class block at its cell's
# head — lines are `## ` + the ORIGINAL bytes (a comments-only block builds, renders nothing,
# and stays OUT of the site's search index — probed at v0.3.1; the `@raw html` alternative
# leaks into search_index.js and was REJECTED). The header line starts `##gometa`
# — NO space after `##`, a shape no payload can produce (payloads are always `## ` + bytes),
# so a decoder's envelope identity cannot be spoofed by PAYLOAD; an authored prose line
# stripping to the sigil is no longer refused (the forged-envelope and reserved-mention
# refusals were removed). Scope note: an
# authored Julia comment inside a generated CODE fence can still place the sigil bytes at
# a line start on the built page, so decoders identify envelopes NAME-FIRST (the two names
# differ for the shipped stems; a stem beginning `carriage_` would collide — the former stem-prefix refusal was
# removed), never by
# scanning for the sigil alone. Indices are 0-based over the cell's
# reconstructable sequence [attached meta run…, non-discarded content lines…]: `carried=`
# lists the envelope-carried entries, `hidden=` the natively-hidden-in-place executed lines
# (the ` # hide` suffix / `@setup` body — strip/locate by exactly these indices), every other
# index is a visible body line in order. The reader page is a VIEW: NO envelopes.
_carriage_name(chain::String) = "gometa_carriage_" * chain
# (The fence-pairing, reserved-mention and forged-envelope refusals — former fail-closed guards —
# with `_strip_lead`, which served them alone, were removed within the 0.4 development;
# the carriage envelope below is the transformation's own.)
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
        # executed cells: hidden lines stay IN PLACE natively (`# hide`/@setup);
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
# a generated executed block's fence must outrun any backtick run in its body
_fence(bodylines) = "`" ^ max(3, 1 + maximum(vcat(0,
    [length(match(r"^`*", lstrip(l)).match) for l in bodylines])))

function page_body(sections::Vector{Section}, legend, keep::Function, chain::String;
                   carriage::Bool = false)
    io = IOBuffer()
    exec_chain = "gometa_" * chain     # the generated execution namespace (its former mention refusal was removed)
    for s in sections
        keep(s) || continue
        if s.heading !== nothing
            carriage && _carriage_envelope(io, s.heading, chain)
            # the same no-trace guard as body cells (a fully hidden
            # heading must not leave stray blanks)
            hl = md_lines_page(s.heading)
            isempty(hl) || (println(io, join(hl, '\n')); println(io))
        end
        for c in s.cells
            # FULL page (v0.3.1): hidden content AND metaLines
            # ride in the carriage envelope; the READER page is a VIEW (carriage=false —
            # NO envelopes, and trimmed sections travel nowhere). The bound, stated
            # exactly: hidden EXECUTED lines of a RETAINED section
            # still ride the reader NATIVELY (' # hide' / @setup preserves
            # execution continuity); the committed reader selection has zero hidden lines
            # today — if a future selection gains one, surface it to the creator first.
            # Carrier cells (detached meta runs) are envelope-only cells on the full
            # page and vanish from the reader.
            if c.kind === :carrier || isempty(c.lines)
                carriage && _carriage_envelope(io, c, chain)
                continue
            end
            ms = meaning(c, legend)
            if c.kind === :markdown
                carriage && _carriage_envelope(io, c, chain)
                pl = md_lines_page(c)
                # a fully hidden markdown cell leaves NO trace on the page (the guard:
                # no stray blank lines for an invisible cell)
                isempty(pl) || (println(io, join(pl, '\n')); println(io))
            elseif :expensive in ms
                # the branch order is load-bearing: expensive-BEFORE-all-hidden keeps
                # the never-execute law (an all-hidden expensive cell must not fall to
                # the executing @setup branch below); hidden lines of a NEVER-executed
                # cell ride the envelope (the creator's decision: only EXECUTED hidden code
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
                # execute-but-fully-hide → a NAMED @setup block (the native
                # execute channel; `hidden=` indices record the in-place lines).
                # An authored trailing `# hide` in THIS branch is deliberately NOT
                # refused (unlike the @example branch below): no suffix is appended to
                # @setup body lines, the whole cell is already display-hidden, and
                # `hidden=` covers every body index — the marker is inert here and the
                # decoder's suffix-strip stays exact (disclosed).
                carriage && _carriage_envelope(io, c, chain;
                    hidden_idx = [length(c.carried) + j - 1 for j in eachindex(c.lines)])
                bodyl = [lf.text for lf in c.lines]
                f = _fence(bodyl)
                println(io, f, "@setup ", exec_chain)
                foreach(l -> println(io, l), bodyl)
                println(io, f)
                println(io)
            else
                # The authored-marker refusal: an AUTHORED shown line already
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
    fates = verdict_fates(String(copy(bytes)), r)      # the Engine's answer per Line Component; no render witness
    cells = partition(fates)
    join_labels!(cells, r)                              # the labelled Components' spans through the door
    # the two counts over NON-BLANK source lines: a blank line inside a discarded or hidden Block carries the Block's verdict
    # since the re-route, but it is no content line — it travels nowhere either way (the former content-keyed
    # fates left such a line :show, so these counts always meant the content lines)
    n_discarded = count(lf -> lf.fate === :discard && !is_blank_line(lf.text), fates)
    n_hidden = count(lf -> lf.fate === :hide && !is_blank_line(lf.text), fates)
    stem = splitext(basename(spec.path))[1]
    digest = bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(String(GoMeta.serialize_evals(GoMeta.readAltValuesEvals(r.altValues_evals)))))))[1:8]
    label_counts = join(sort(["$(l)×$(count(c -> l in c.labels, cells))" for l in Set(l for c in cells for l in c.labels)]), " ")
    println("  labels on cells: ", isempty(label_counts) ? "(none)" : label_counts, " · verdict digest ", digest)
    outputs = Tuple{String,String}[]
    ecells = full_cells(cells, spec.legend)
    # the footer's text is the committed notebooks' — byte-identical since the three further editions were removed
    # (the full edition omits no cell: "0 cell(s) omitted by this edition's policy" stays true)
    footer_lines = ["---",
        "*How this notebook was made:* derived from `notebooks/src/$stem.jl` by " *
        "`notebooks_from_source.jl` (edition **full**; 0 cell(s) omitted by this " *
        "edition's policy; $n_discarded source line(s) removed and $n_hidden hidden by the " *
        "engine's own verdicts before any policy ran; verdict digest `$digest`). Hidden lines " *
        "and the source's `#~` metaLines travel INVISIBLY with this file — as HTML comments " *
        "in markdown cells and under the `gometa` key in code-cell metadata — so the GoMeta " *
        "data can be read and worked with in this artifact as in the source; discarded lines " *
        "do not travel" *
        ". Regenerate and byte-compare every " *
        "generated file: `julia --startup-file=no --project=. notebooks_from_source.jl --check` " *
        "— the executed edition is validated separately."]
    footer = Cell(:markdown, [LineFate(l, :show) for l in footer_lines], 1:0, Set{Symbol}(), LineFate[])   # synthetic: no source span
    push!(ecells, (footer, String[]))
    name = "$stem.ipynb"
    push!(outputs, write_notebook(joinpath(NB_DIR, name), ecells))
    println("  $name: $(length(ecells)) cells emitted, $n_discarded source line(s) engine-discarded")
    if spec.pages
        for (path, content) in derive_pages(spec, cells)
            push!(outputs, (path, content))
            println("  $(basename(path)): $(count_doctests(content)) jldoctest block(s)")
        end
    end
    return outputs
end

function main()
    check = "--check" in ARGS
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
