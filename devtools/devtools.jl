# devtools.jl — the GoMeta developer print tools.
#   This file lives in this repository's devtools/.
#   Run under the project whose GoMeta you want
#   to print: `--project=$GM/tests` (GM = this repository's root) = its test environment. A DEVELOPMENT TOOL:
#   not part of the GoMeta process — the package never references this file. Docs: README.md
#   beside it.
#
# IS:   the two development printers for a `goMeta` result —
#         `print_BLS_Component_Tree`  (the BLS Component tree with every component's
#                                      settribute state; restores the February
#                                      `printComponentStates` capability, superseding it)
#         `print_altValues_evals`     (the evals rows placed IN the component tree /
#                                      as the evals-rows-by-Component view / as the per-cell view)
#       plus their file twins (`write_*_to_file`) and
#       the comparison form's producer and writer `comparisonForm` / `writeComparisonFormToFile` (§I).
#       (The `slide` output option and its three surface writers were removed within the 0.4 development.)
# DOES: renders — from the BLS component data of ONE `goMeta(bytes)` result, and only
#       as deep as the selected style/detail/filters ask —
#       (never re-derived from raw text): the engine-true Block census (the door's
#       `children` of the File root — the original engine's `2:numChildren+1` census is extension-unsafe),
#       per-component named-int + settribute dumps, and the cell_handle → Component resolution
#       (the shared decoder; a plain walk through the door; a row's text through the
#       door's `BLS.content`). A former defensive contract — the resolver's gates, the
#       origin states, the unanchored reasons, the guarded context, the status-first law, the
#       checked blocks= fetch — was removed within the 0.4 development.
# REASONING: the released v0.3.0 package deliberately ships no debug printer
#       and the run's WORKING state is not delivered at all (0.3.x delivered it as a field) — so the dev tools live BESIDE THE PACKAGE, on a
#       surface of their own, honestly labeled (the development tools', not the Engine's), instead
#       of re-entering the engine through the release pipeline. Package-proper
#       restoration would be a change of the package itself, never code from here.
# PURPOSE: let the creator SEE, at any moment, exactly what the engine built
#       (structure + settributes) and exactly which altValues_evals row landed on
#       which Component — including the metaSegment that caused it — in the terminal
#       (colored) or as .html / .txt files.
#
# ── The tree through THE DOOR ─────────────────────
# These tools read `result.blsComponentTree` through BLS's public functions and types ONLY —
# `GoMeta.BLS.root` / `children` (the walk), `getElement` (every flag and position, by key, over a
# Component), `content` (the verbatim bytes at a Component's grain), `kind` (the flavor word),
# `flavor` (the record; five fields promised), `endsWithNewline`, `isHorizontalSpace` (the lexer's
# delimiter), the Component types and `keys` of the two named-element types (docs/public-api.md §1.2) —
# and no field of a BLS object; the File's text (its lines joined) through the one-argument `content(tree)`
# — the read it replaced, one of the last two reads outside the door, was removed within the 0.4 development with the texts of the
# former exemption. Consumer code — an Extension — reads the tree the same way, through the door
# (docs/public-api.md §1.2).
# The battery `devtools/probes/probe_devtools.jl` is the drift alarm (the tools' former self-check was removed within the 0.4
# development): run it after every change under `src/` — a broken surface fails LOUDLY.
#
# ── Use ─────────────────────────────────────────────────────────────────────────────────
#   julia> include("devtools.jl")
#   julia> result = goMeta(read("InFileFolder/some.jl"))
#   julia> print_BLS_Component_Tree(result)
#   julia> print_altValues_evals(result)
#   julia> write_altValues_evals_to_file("evals.html", result)
#   (iterating on this file itself: `using Revise; includet("devtools.jl")` — a plain
#    include is not Revise-tracked.)
#
# ── Non-goals + recorded deviations ─────────────────────────────────────────────────────
# - No benchmarks: interactive dev printers carry no performance contract (the
#   documented decision).
# - Excerpt quote-escaping is DEFERRED: the creator decided on the
#   rendered look with raw embedded quotes; only control bytes / invalid UTF-8 are
#   escaped (safety — by the excerpt's own loop; the `strip` before it decodes an overlong invalid sequence at a content's head or tail and throws: a recorded limit at v0.4, the BLS flag and the door's text read at v0.5). `""` still renders zero-length content.
# - Non-ASCII typography in PLAIN sinks: Block spans use an en-dash (`L35–L49`) and
#   the reserved polarity marker a typographic minus (`(−)`, dead at v0) — byte-pinned
#   to the design mockups; grep with the literal characters (or `grep -P`).
# - A row the tools cannot place — a handle that does not decode, a grain above the File grain
#   (> 0xd2: the user-context plane, the plane law of src/occurrence.jl), a path step with no such
#   child — renders in the `unanchored rows` section: its grain name (`?` for a handle that does not
#   decode) and, for a grain above the File grain, its first path ordinal; `show_handles` adds the
#   handle note (the decoded handle, or the raw bytes marked UNDECODED). No shipped path keys an evals
#   row on the user-context plane since 0.4.0 (the creator's decision):
#   a statement of a `localOnly` Alterant fed through the profile is refused at the read
#   (src/absorb/absorb_meta.jl — the condition keys on the set mode with a user context present, so
#   every registry's — the reach beyond the Heading by the creator's decision), and the user-context handle is
#   read once, into the fed rows' `decided_by` — no writer of a row's key reads it. The section is the
#   tools' totality guard: WITNESSED at b70d5b7 over eleven inputs — ten runs with zero unanchored rows,
#   the fed heading refused (measured 2026-10-17) — a witness beside the structural
#   basis above, not a proof over every shipped path.
# - `detail` validation is STRICTER than a pure conflict rule: any explicit value for
#   a non-:tree style errors, even one naming the style's inherent detail — inherent
#   details are only ever selected via :auto (no silent no-op, no lookalike accept).
# - Excerpts truncate incrementally OUTPUT-side; the cell's content String is still
#   materialized input-side (bounded by one cell) — accepted for v1.
# - The extension-chain presence marker detects Block-grain `idExtension` in `:mix`
#   only (Line/File-capacity chains + the `:tree`/`:full` style stay unmarked);
#   physical extension-node rendering is deferred — no chain is mintable at interactive input sizes.
# - An Alterant's declared DEFAULT value is the answer function's (`GoMeta.evaluatedAltValue`), never a row; the absence of a row renders as
#   "(no evals — defaults apply)" without asserting a value.
# - The :mix/:tree dump rows carry parent→first-
#   child RAILS (│ at the child connector column; evals ● view
#   deliberately NOT extended — the ● occupies that column). (The
#   reference-true structure slide runs were removed with the slide option.)
#

import GoMeta
include(joinpath(@__DIR__, "load_basic_renderer.jl"))   # the ONE path to the basic renderer
const _DT_BLS = GoMeta.BLS

#########################################################################################
##  §A — palette + styled emission
#########################################################################################

## THE COMPUTED PALETTE (2026-08-20).
## IS: every identity-bearing color as a FIXED xterm-256 index (never theme-remapped,
##   never bold-as-bright-promoted — both mechanisms touch only base-16; probe-proven).
## DOES: passes the computed gates of the dataviz color method (Machado-2009 CVD
##   simulation, OKLab ΔE×100) over THIS tool's actual adjacency pairs (grain↔flavor,
##   flavor↔attr, attr↔value, grain↔grain, flavor↔flavor): min NORMAL ΔE 16.1 (floor
##   15), min CVD ΔE 9.9 (target 8); every color ≥3:1 on #1e2127 and ≥ΔE15 from chrome
##   AND default fg. Verified by eye on rendered output (normal + deutan-simulated).
## REASONING: three hand-picked rounds each fixed one collision
##   and created another — base-16 theme remapping (bold :yellow → the creator's amber)
##   plus hue-family crowding made eyeballing unreliable; the assignment is COMPUTED
##   (by an optimizer over the gates above) and the render was LOOKED AT.
## PURPOSE: every role nameable by color alone, for full-color AND red-green-deficient
##   vision, on any dark-background terminal/theme. Re-tint = one index, then re-run
##   the gates above (their scorer is not part of this repository) + probe 7b.
const _DT_C_CHROME = 245            # guides/spans/labels — fixed gray #8a8a8a
                                    #   (theme :light_black is Solarized-invisible)
const _DT_C_BLOCK  = 205            # Block grain, bold — pink #ff5faf
const _DT_C_LINE   = 51             # Line grain — bright cyan #00ffff
const _DT_C_SEG    = 111            # Segment grain — periwinkle #87afff
const _DT_C_ATTR   = 75             # attr names, bold — azure #5fafff (the eyes-target;
                                    #   ΔE 21.7 vs the ubiquitous Line cyan; its one
                                    #   soft spot — vs Segment 111 — co-occurs only on
                                    #   rare Segment-anchored :rows lines, self-labeled)
const _DT_C_LEGACY_DUMP = :yellow   # the ARCHIVAL dump color of the :legacy/:banner
                                    #   styles — historical fidelity, never re-tinted
const _DT_C_META_F = 172            # Meta flavor — muted gold-orange #d78700 (muted so
                                    #   the signal color never out-shouts the attr target)
const _DT_C_CODE_F = 149            # Code flavor — lime-sage #afd75f (vivid green is
                                    #   ceded to the :show semantic)
const _DT_C_TEXT_F = 134            # Text flavor — purple #af5fd7
const _DT_C_GOOD   = 41             # :show — emerald #00d75f
const _DT_C_WARN   = 220            # :hide — gold #ffd700
const _DT_C_BAD    = 203            # :discard/errors — light red #ff5f5f (protan
                                    #   darkens pure red 196; 203 stays legible)

const _DT_HTML_COLORS = Dict{Any,String}(
    :magenta => "#c678dd", :cyan => "#56b6c2", :blue => "#61afef", :yellow => "#e5c07b",
    :green => "#98c379", :red => "#e06c75", :light_black => "#7f848e", :normal => "#d7dae0",
    205 => "#ff5faf", 51 => "#00ffff", 111 => "#87afff", 172 => "#d78700",
    149 => "#afd75f", 134 => "#af5fd7", 75 => "#5fafff", 41 => "#00d75f",
    220 => "#ffd700", 203 => "#ff5f5f", 245 => "#8a8a8a")   # the computed palette

_dt_htmlesc(s) = replace(s, '&' => "&amp;", '<' => "&lt;", '>' => "&gt;")

## IS: the ONE styled-run emitter every renderer uses. DOES: routes a flat run to the HTML sink
## (IOContext key :gm_html), to `printstyled` (only when the io carries
## :color=>true AND the run is actually styled), or to plain `print` — so plain runs
## emit ZERO escape bytes. REASONING: printstyled closers reset to terminal defaults,
## so runs are FLAT, never nested; `:normal`-unbold runs bypass printstyled entirely
## (ANSI hygiene). PURPOSE: one source of truth for terminal/plain/HTML parity.
function _dt_sty(io, txt; color = nothing, bold::Bool = false)
    s = string(txt)
    if get(io, :gm_html, false)
        css = String[]
        color !== nothing && push!(css, "color:" * get(_DT_HTML_COLORS, color, _DT_HTML_COLORS[:normal]))
        bold && push!(css, "font-weight:700")
        isempty(css) ? print(io, _dt_htmlesc(s)) :
            print(io, "<span style=\"", join(css, ";"), "\">", _dt_htmlesc(s), "</span>")
    elseif get(io, :color, false) && ((color !== nothing && color !== :normal) || bold)
        printstyled(io, s; color = color === nothing ? :normal : color, bold)
    else
        print(io, s)
    end
end

## textwidth-aware padding — `rpad` counts chars, not display width, and mis-aligns
## pictograph labels like `label_label🍻` (probe-proven); this pads to WIDTH.
_dt_tpad(s, w) = s * ' '^max(0, w - textwidth(s))

## IS: the bounded excerpt maker. DOES: flattens in-cell newlines to '⏎' (the command-line entry's
## convention), escapes every OTHER control byte as ⟨0xNN⟩ (the terminal-forging class:
## \r, ESC, backspace…), renders malformed UTF-8 chars as per-char byte-hex ⟨0x…⟩
## (BYTE IDENTITY kept — the `!isvalid(c)` arm intercepts them on Julia 1.12.5), and
## truncates the OUTPUT incrementally at display width `maxw`. The byte-hex `catch` is
## a RESIDUAL belt for invalid-UTF-8 throw classes a future Julia might reintroduce —
## on 1.12.5 the char loop is total, so the fallback is defensively dead. REASONING:
## the excerpt's safety: the printer must survive every input the byte-faithful
## engine accepts — with ONE recorded exception at v0.4: the `strip` the callers apply before this excerpt decodes an overlong invalid UTF-8 sequence at a content's head or tail and throws; cured at v0.5 by the BLS flag and the door's text read, not here.
function _dt_excerpt(s::AbstractString, maxw::Int = 48)
    try
        out = IOBuffer(); w = 0
        for c in s                                  # in-loop mapping — no whole-string copy
            frag = c == '\n' ? "⏎" :
                   !isvalid(c) ? "⟨0x" * bytes2hex(codeunits(string(c))) * "⟩" :
                   iscntrl(c) ? "⟨0x" * string(UInt32(c), base = 16, pad = 2) * "⟩" :
                   string(c)
            cw = textwidth(frag)
            if w + cw > maxw - 1
                return String(take!(out)) * "…"
            end
            print(out, frag); w += cw
        end
        return String(take!(out))
    catch e                                 # residual invalid-UTF-8 classes ⇒ hex fallback;
        e isa Union{StringIndexError, Base.InvalidCharError} || rethrow()   # never mask real bugs
        b = codeunits(s)
        n = min(length(b), max(4, (maxw - 3) ÷ 2))
        return "0x" * bytes2hex(b[1:n]) * (length(b) > n ? "…" : "")
    end
end

#########################################################################################
##  §B — the tree through the door
#########################################################################################

## The door's walk (`BLS.children`) resolves the insert store's negative ids itself (an earlier
## concern — the original printer's sign-blind mis-indexing — cannot recur: no id is indexed here).
## The Components of one grain in source order; `_dt_id` the Component's own id (the printed `#N`).
_dt_children(doc, c) = _DT_BLS.children(doc.ps, c)
_dt_id(c) = Int(_dt_ni(c, :idComponent))

"""
    DTDoc

IS: the per-call render context — one `goMeta` result opened for printing; built by `_dt_doc(result; name)`.
DOES: carries the result (`r`), its delivered tree (`ps` — the part `blsComponentTree`), the Block Components the door's
    walk yields (`blocks` — `BLS.children` of the tree, materialised once: the basic renderer's form,
    devtools/basic_renderer.jl — the original engine's `2:numChildren+1` census breaks on extension chains), and the display name
    (`name`, printed in the `File` header line).
REASONING: the result and the tree are held untyped (`Any`): the tools name no Julia type of the delivered part (the basic
    renderer's note at its own read: that type is an open point of the design — not named there either) and dispatch on the Component
    types through the door alone. One context per call keeps every printer on the same tree and the same Block census.
PURPOSE: the context every printer opens first — `print_BLS_Component_Tree`, `print_altValues_evals`, `comparisonForm` and
    the command-line verbs `evals` and `trace`; the tools work on the run's two MAIN PRODUCTS (the creator's term), the BLS Component tree and
    `altValues_evals`.
"""
struct DTDoc
    r::Any
    ps::Any
    blocks::Vector{Any}
    name::String
end

_dt_doc(result; name::AbstractString = "") =
    DTDoc(result, result.blsComponentTree, Any[b for b in _DT_BLS.children(result.blsComponentTree)], String(name))

_dt_ni(c, k)    = _DT_BLS.getElement(c, k)      # a named integer or a flag, by key, through the door
_dt_grain(c)    = c isa _DT_BLS.Block ? "Block" : c isa _DT_BLS.Line ? "Line" :
                  c isa _DT_BLS.Segment ? "Segment" : "File"
_dt_gcolor(c)   = c isa _DT_BLS.Block ? _DT_C_BLOCK : c isa _DT_BLS.Line ? _DT_C_LINE : _DT_C_SEG
## The flavor word through the door (`kind`: :Meta / :Code / :Text — the same bytes the former
## `nameof(c.contentType)` gave). A File has no flavor (`kind` answers `nothing`; the field carried
## the store's constructor default "Meta" before) — the word "File" is printed in that column.
_dt_flavor(c)   = (k = _DT_BLS.kind(c); k === nothing ? "File" : string(k))
_dt_fcolor(f)   = f == "Meta" ? _DT_C_META_F : f == "Code" ? _DT_C_CODE_F : _DT_C_TEXT_F
_dt_trueflags(c) = [k for k in keys(_DT_BLS.ComponentSettribute) if _DT_BLS.getElement(c, k)]
## The File's text (its lines joined) through the door's one-argument `content(tree)` (the layout-totality
## clause); the other grains through `BLS.content(tree, c)` (the former Engine call `cell_content_bytes`, byte-equal by
## construction of the copy).
_dt_content(doc, c) = c isa _DT_BLS.File ? String(_DT_BLS.content(doc.ps)) :
                      String(_DT_BLS.content(doc.ps, c))

## Input-line span label: Blocks span `startMainStr:stopMainStr` LINE numbers
## (probe-proven semantics); Lines/Segments locate by :inputLineNum.
function _dt_span(c)
    c isa _DT_BLS.File && return "file"      # the File root's locator fields are the dummy hack
    a = _dt_ni(c, :inputLineNum)
    if c isa _DT_BLS.Block
        lo, hi = _dt_ni(c, :startMainStr), _dt_ni(c, :stopMainStr)
        return lo == hi ? "L$(lo)" : "L$(lo)–L$(hi)"
    end
    return "L$(a)"
end
_dt_spanrange(c) = c isa _DT_BLS.Block ?
    (_dt_ni(c, :startMainStr):_dt_ni(c, :stopMainStr)) :
    (_dt_ni(c, :inputLineNum):_dt_ni(c, :inputLineNum))
## The File root spans the WHOLE document (its locator fields are the dummy hack), so a
## File-anchored row intersects every lines= range — never hidden by a line filter.
_dt_intersects(c, r) = r === nothing || c isa _DT_BLS.File ||
    !isempty(intersect(_dt_spanrange(c), r))

## The census walk through the door (`children` at each grain).
function _dt_census(doc)
    nl = 0; ns = 0
    for b in doc.blocks, l in _dt_children(doc, b)
        nl += 1
        ns += length(_dt_children(doc, l))
    end
    (length(doc.blocks), nl, ns)
end

_dt_plural(n, w) = "$n $w" * (n == 1 ? "" : "s")

#########################################################################################
##  §C — the handle's decode and the path's resolution
#########################################################################################
## Layout (src/occurrence.jl docblock; probe-proven 27/27): schema 0x01 ·
## namespace (u16-BE length + UTF-8) · grain byte · path steps (store byte + u32-BE
## GLOBAL-store-index ordinal = abs(idComponent)) · origin steps (same shape).
## THE DECODER IS SHARED: `decode_handle` lives in
## handle_decoder.jl beside this file and serves the authored test runner too — ONE copy; the tools' former
## private `_dt_decode` family (`_dt_u16`, `_dt_u32`, `_dt_steps`, `_dt_decode`) retired with it. A handle that
## does not decode cleanly returns `nothing` and renders as unanchored here.
isdefined(@__MODULE__, :decode_handle) || include(joinpath(@__DIR__, "handle_decoder.jl"))

_dt_grainname(g) = g == 0x01 ? "Segment" : g == 0x0a ? "Line" : g == 0x46 ? "Block" :
                   g == 0xd2 ? "File" : g == 0xe0 ? "USER_CONTEXT" :
                   "grain-0x" * string(g, base = 16)

## The path's resolution through the door: the walk from the File root (the first step), each further step the child
## whose id is the step's ordinal (`children` walks a Component's extension chain and yields the chain's children
## flattened — handles name chain roots). A step with no such child resolves to `nothing`: the row renders unanchored.
function _dt_resolve(doc, steps)
    comp = _DT_BLS.root(doc.ps)
    for (_, ord) in steps[2:end]
        kids = _dt_children(doc, comp)
        k = findfirst(c -> _dt_id(c) == Int(ord), kids)
        k === nothing && return nothing
        comp = kids[k]
    end
    comp
end

"""
    DTEvalRow

IS: one evals row of `altValues_evals`, resolved for rendering; built by `_dt_eval_rows(doc)` — one per row of
    `GoMeta.readAltValuesEvals`.
DOES: carries the evals row (`attr`, `value`, `polarity` — polarity is constant `true` at v0, a reserved field, so it
    renders DIM), the resolved target Component (`comp`; `nothing` = unanchored — a row the tools cannot place: a handle
    that does not decode, a grain above the File grain 0xd2 (the user-context plane — no shipped path keys a row on it
    since 0.4.0), a path step with no such child),
    the origin metaSegment (`origin`; `nothing` when the key carries no origin steps), the raw
    occurrence-handle bytes (`handle` — row identity, cell grouping) and the decoded key (`key` — the shared decoder's
    named tuple `(; namespace, grain, path, origin)`; `nothing` when the bytes do not decode). A row's text is the door's
    `BLS.content` of its resolved Component.
REASONING: a row is decoded (the shared `decode_handle`) and resolved ONCE — the plain path walk `_dt_resolve`
    from the File root through the door's `children`, a step with no such child giving `nothing` — and every layout reads
    the resolved fields. The seven fields are what remains of a former twelve-field row: the decoded key's
    named tuple in place of grain, namespace, path and origin steps; the resolver's gates and the origin states were removed with
    a former defensive contract.
PURPOSE: the unit the three layouts of `print_altValues_evals` (`:tree`, `:rows`, `:cells`), the `unanchored rows`
    section, the bullet `_dt_eval_bullet` and the handle note render.
"""
struct DTEvalRow
    attr::Symbol
    value::Any
    polarity::Bool
    comp::Any
    origin::Any
    handle::Vector{UInt8}
    key::Any
end

## The row builder: every `altValues_evals` row decoded (the shared decoder) and resolved through the door. A grain
## above the File grain (> 0xd2 — the user-context plane, the plane law of src/occurrence.jl) has no document tree
## position, and the user-context key's one path step would walk to the File root — so the branch stays as the guard;
## no shipped path produces such a row since 0.4.0.
function _dt_eval_rows(doc)
    rows = DTEvalRow[]
    for (h, attr, v, pol) in GoMeta.readAltValuesEvals(doc.r.altValues_evals)
        d = decode_handle(h)
        comp = (d === nothing || d.grain > 0xd2) ? nothing : _dt_resolve(doc, d.path)
        orig = (d === nothing || isempty(d.origin)) ? nothing : _dt_resolve(doc, d.origin)
        push!(rows, DTEvalRow(attr, v, pol, comp, orig, h, d))
    end
    rows
end

_dt_akey(c) = (typeof(c), Int(_dt_ni(c, :idComponent)))
## (the tree attachment map — incl. the Segment→owning-Line remap and the File split —
## is built INLINE in _dt_t2_tree; keeping a second generic builder here proved a
## dead-surface hazard and was removed)
_dt_unanchored(rows) = [r for r in rows if r.comp === nothing]

## visib values carry semantic colors; every other attr's value prints neutral-BOLD —
## polarity is constant true at v0, so a polarity-driven color would be constant fake
## signal (verified against annotations.jl:188).
_dt_vcolor(row) = row.attr === :visib ?
    (row.value === :show ? _DT_C_GOOD : row.value === :discard ? _DT_C_BAD : _DT_C_WARN) : :normal

function _dt_eval_bullet(io, doc, row; indent = "", target_tag::String = "")
    _dt_sty(io, indent)
    _dt_sty(io, "● ", color = _DT_C_CHROME)
    isempty(target_tag) || _dt_sty(io, target_tag * " ", color = _DT_C_CHROME)
    _dt_sty(io, _dt_tpad(string(row.attr), 12), color = _DT_C_ATTR, bold = true)
    _dt_sty(io, " => ")
    _dt_sty(io, _dt_tpad(repr(row.value), 8), color = _dt_vcolor(row), bold = true)
    _dt_sty(io, row.polarity ? "  (+)" : "  (−)", color = _DT_C_CHROME)
    if row.origin !== nothing
        _dt_sty(io, "   ← $(_dt_grain(row.origin)) #$(_dt_ni(row.origin, :idComponent)) \"" *
                _dt_excerpt(strip(_dt_content(doc, row.origin)), 24) * "\"", color = _DT_C_CHROME)
    end
    println(io)
end

function _dt_print_unanchored(io, doc, rows; show_handles::Bool = false)
    isempty(rows) && return
    _dt_sty(io, "\nunanchored rows (no document tree position):\n", color = _DT_C_BAD, bold = true)
    for row in rows
        d = row.key   # a row of a grain above the File grain would carry its first path ordinal (e.g. USER_CONTEXT #1); none is produced by a shipped path since 0.4.0 — the tag stays with the guard
        tag = d === nothing ? "?" : _dt_grainname(d.grain) * (d.grain > 0xd2 && !isempty(d.path) ? " #$(Int(d.path[1][2]))" : "")
        _dt_sty(io, "  [" * tag * "]  ", color = _DT_C_BAD)
        _dt_sty(io, _dt_tpad(string(row.attr), 12), color = _DT_C_ATTR, bold = true)
        _dt_sty(io, " => ")
        _dt_sty(io, repr(row.value), color = _dt_vcolor(row), bold = true)
        _dt_sty(io, row.polarity ? "  (+)" : "  (−)", color = _DT_C_CHROME)
        println(io)
        show_handles && _dt_handle_note(io, row, "      ")
    end
end

#########################################################################################
##  §D — tool 1: print_BLS_Component_Tree
#########################################################################################

const _DT_T1_STYLES = (:mix, :legacy, :tree, :banner)

"""
    print_BLS_Component_Tree(io::IO, result::GoMetaDelivery; kwargs...)   # core method
    print_BLS_Component_Tree(result::GoMetaDelivery; kwargs...)           # → stdout
    write_BLS_Component_Tree_to_file(path, result; format=:auto, kwargs...)

IS: the first of the two print tools — the BLS
    Component tree of one `goMeta` result, every Block/Line/Segment with its named-int record and TRUE settribute flags,
    hierarchically. The restored-and-superseding successor of the February `GoMeta.BLS.printComponentStates()`
    (existing script call sites need a one-line edit to this form). A development tool: nothing under
    `src/` reads it.
DOES: prints the tree of `result.blsComponentTree`, read through the door alone (`BLS.children`, `getElement`, `kind`,
    `content`), as deep as the selected style, detail and filters ask.
    METHOD DISPATCH — which call form triggers what:
    - `(io, result)` — the CORE method (Julia print convention): renders into `io` exactly as configured; every other
      method funnels here.
    - `(result)` — REPL convenience: identical, `io = stdout` (colors auto-resolve from the terminal).
    - `write_BLS_Component_Tree_to_file(path, result)` — opens `path`, renders, closes. `format = :auto` infers from the
      extension (`.html` ⇒ the self-contained HTML page, anything else ⇒ text); `:html` / `:txt` override the inference.
      Text files default `color = :never` (plain, grep-friendly); pass `color = :always` to write ANSI bytes (view with
      `less -R`). The HTML sink is ALWAYS styled — `color` does not apply to it.
    PARAMETERS (each names the METHOD BEHAVIOR it selects):
    - `color::Symbol = :auto` — `:auto` passes the io's own `:color` property through (a deliberate
      `IOContext(io, :color=>true)` is honored; `stdout` resolves from the tty and `--color=yes`/`FORCE_COLOR`/`NO_COLOR`);
      `:always`/`:never` WRAP the io via `IOContext(io, :color => true/false)`.
    - `style::Symbol = :mix` — selects the renderer (the four of `_DT_T1_STYLES`):
      `:mix`    (the default): guide-line tree; under EACH component two dump lines labeled by the REAL
                element types (`Int64` named-int pairs, `Bool` TRUE-flag names; values in default fg); a blank
                line between Blocks; every string printed ONLY at the component that CONTAINS it (a Line with Segments
                shows no excerpt — its Segments do; Blocks never).
      `:legacy` — the February look (banners, `key=>1` yellow dumps, frozen header without the old `@L/@F`
                self-location) on the sound census.
      `:tree`   — the compact baseline: one line per component, TRUE flags inline; `detail=:full` appends the typed dump
                pair per component.
      `:banner` — `##`-chromed banners + source text + one-line `ints`/`flags` dumps.
    - `detail::Symbol = :auto` — resolution table. The rule is strict: ANY explicit value for a non-`:tree` style ERRORS —
      even one naming the style's inherent detail — so a detail request can never silently no-op; inherent details are
      selected only via `:auto`. `:mix` ⇒ inherent (the typed dump lines ARE its detail) · `:legacy` ⇒ inherent full ·
      `:banner` ⇒ inherent (its co-located dumps) · `:tree` ⇒ `:auto`→`:compact`; explicit `:compact`/`:full` valid —
      `:full` keeps the `:tree` rows (inline flags + every content string) and APPENDS the typed dump pair under each
      component.
    - `blocks = :all` — or a Vector of Integer Block ids (any `AbstractVector` of non-`Bool` `Integer`s; the original engine's
      Block-subset precedent): the named Blocks in census order; an id that names no Block selects nothing.
    - `lines = nothing` — an input-line range (e.g. `5:12`): a component renders iff its input-line span INTERSECTS the
      range; a partially-overlapping Block keeps its full span label while its children clip to the range.
    - `grain::Symbol = :segment` — the deepest grain printed: `:block` | `:line` | `:segment`. In `:mix`, a string prints
      at the deepest DISPLAYED owner — with `grain = :line` the Line shows its string even when Segments exist (they are
      not displayed; the print-once law binds displayed components).
    - `_name::AbstractString = ""` — the display name in the `File` header line (an internal-ish kwarg: the write twins
      default it to `basename(path)`; REPL calls may set it for a labeled header).
    An unknown `style`, `grain`, `color`, `detail`, `blocks` or `lines` value ERRORS with a message naming the accepted
    forms. With no Block selected (an empty document, or a `blocks=` request matching none) the styles other than
    `:legacy` print the `File` summary line and the reason; `:legacy` keeps its frozen chrome. In `:mix` a shown
    Block whose `idExtension` is not 0 prints a one-line extension-chain notice (the logical walk flattens the chain).
    The two `print_BLS_Component_Tree` methods return `nothing`; `write_BLS_Component_Tree_to_file` returns `path`. The
    delivery's status is not printed here (the command-line entry prints it to stderr): an error delivery carries the
    tree of empty bytes and prints as the empty document.
REASONING: the released package ships no debug printer and the run's WORKING state is not delivered, so the
    printer lives beside the package as a development tool and reads only the delivered part — through the door, never a
    field of a BLS object (the tools' last reads outside the door were removed within the 0.4
    development). The census is the door's `children` of the File root, never the original `2:numChildren+1`
    (extension-unsafe). The strict `detail` rule and the typed dump labels are the design's: no silent no-op, no lookalike
    accept, the REAL element types shown. The full-content REFERENCE style — the same bytes every run, on
    a finished run AND on a bare parse — is decided and still to come; it is not in this
    file: the four styles above take a delivery.
PURPOSE: the tools' instrument (the verb `bls-tree` = `style = :mix`): what the Engine built —
    the structure and the settribute state the conditions tested — is stated from this printout, never re-derived from
    raw text; the next step of `print_altValues_evals`' "why NOT" path (the settribute state the conditions
    tested). The tools work on the run's MAIN PRODUCTS (the creator's term).
"""
function print_BLS_Component_Tree(io::IO, result::GoMeta.GoMetaDelivery;
        color::Symbol = :auto, style::Symbol = :mix, detail::Symbol = :auto,
        blocks = :all, lines = nothing, grain::Symbol = :segment,
        _name::AbstractString = "")
    style in _DT_T1_STYLES ||
        error("print_BLS_Component_Tree: unknown style=:$style (one of $(_DT_T1_STYLES))")
    grain in (:block, :line, :segment) ||
        error("print_BLS_Component_Tree: unknown grain=:$grain (:block | :line | :segment)")
    color in (:auto, :always, :never) ||
        error("print_BLS_Component_Tree: unknown color=:$color (:auto | :always | :never)")
    if style === :tree
        detail in (:auto, :compact, :full) ||
            error("print_BLS_Component_Tree: detail=:$detail is not valid for style=:tree (:auto | :compact | :full)")
    else
        detail === :auto ||
            error("print_BLS_Component_Tree: style=:$style carries its own inherent detail — pass detail=:auto (got :$detail)")
    end
    blocks === :all ||
        (blocks isa AbstractVector && all(x -> x isa Integer && !(x isa Bool), blocks)) ||
        error("print_BLS_Component_Tree: blocks must be :all or a Vector of Integer Block ids (got $(repr(blocks)))")
    lines === nothing || lines isa AbstractUnitRange{<:Integer} ||
        error("print_BLS_Component_Tree: lines must be nothing or an integer range like 5:12 (got $(repr(lines)))")
    io = color === :auto ? io : IOContext(io, :color => (color === :always))
    doc = _dt_doc(result; name = _name)
    sel = blocks === :all ? doc.blocks : Any[b for b in doc.blocks if _dt_id(b) in blocks]
    if isempty(sel) && style !== :legacy   # :legacy keeps its frozen chrome;
                                           # the other styles get the File summary + reason
        nb, nl, ns2 = _dt_census(doc)
        _dt_sty(io, "File  ", bold = true); _dt_sty(io, doc.name, bold = true)
        _dt_sty(io, "  —  $nb Blocks · $nl Lines · $ns2 Segments\n", color = _DT_C_CHROME)
        _dt_sty(io, isempty(doc.blocks) ? "(no Blocks — empty document)\n" :
                    "(no Blocks — nothing matched the blocks= request)\n", color = _DT_C_CHROME)
        return nothing
    end
    if style === :mix
        _dt_t1_mix(io, doc, sel, lines, grain)
    elseif style === :tree
        _dt_t1_tree(io, doc, sel, lines, grain; dumps = detail === :full)
    elseif style === :legacy
        _dt_t1_legacy(io, doc, sel, lines, grain)
    else
        _dt_t1_banner(io, doc, sel, lines, grain)
    end
    nothing
end

## The typed dump pair: one line per element store, labeled by the REAL
## Julia element type; VALUES in the default foreground (distinguishable from the
## yellow Meta flavor word), type labels dim. Shared by :mix and :tree detail=:full.
function _dt_dumplines(io, c, indent)
    _dt_sty(io, indent, color = _DT_C_CHROME)
    _dt_sty(io, _dt_tpad(string(eltype(_DT_BLS.CmpntNamedInt)), 7), color = _DT_C_CHROME)
    _dt_sty(io, join(["$k=$(_dt_ni(c, k))" for k in keys(_DT_BLS.CmpntNamedInt)], " "))
    println(io)
    _dt_sty(io, indent, color = _DT_C_CHROME)
    _dt_sty(io, _dt_tpad(string(eltype(_DT_BLS.ComponentSettribute)), 7), color = _DT_C_CHROME)
    _dt_sty(io, join(string.(_dt_trueflags(c)), " "))
    println(io)
end

"REPL convenience — `print_BLS_Component_Tree(stdout, result; kwargs...)`. See the core docstring."
print_BLS_Component_Tree(result::GoMeta.GoMetaDelivery; kwargs...) =
    print_BLS_Component_Tree(stdout, result; kwargs...)

## ── :mix — the default ──────────────────────────────────────────────────────────────
function _dt_t1_mix(io, doc, sel, lines_r, grain)
    nb, nl, ns = _dt_census(doc)
    _dt_sty(io, "File  ", bold = true); _dt_sty(io, doc.name, bold = true)
    _dt_sty(io, "  —  $nb Blocks · $nl Lines · $ns Segments\n", color = _DT_C_CHROME)
    isempty(sel) && (_dt_sty(io, "(no Blocks)\n", color = _DT_C_CHROME); return)
    dumplines(c, indent) = _dt_dumplines(io, c, indent)
    row(c, guide, gcol, name; content = nothing) = begin
        _dt_sty(io, guide, color = _DT_C_CHROME)
        _dt_sty(io, _dt_tpad("$name #$(_dt_id(c))", 12), color = gcol, bold = (name == "Block"))
        _dt_sty(io, _dt_tpad(_dt_flavor(c), 5), color = _dt_fcolor(_dt_flavor(c)))
        _dt_sty(io, "  " * _dt_tpad(_dt_span(c), 8), color = _DT_C_CHROME)
        content !== nothing && _dt_sty(io, " \"" * _dt_excerpt(content, 44) * "\"")
        println(io)
    end
    shown = [b for b in sel if _dt_intersects(b, lines_r)]
    isempty(shown) &&
        (_dt_sty(io, "(no Blocks matched the lines= range)\n", color = _DT_C_CHROME); return)
    any(_dt_ni(b, :idExtension) != 0 for b in shown) &&
        _dt_sty(io, "… extension chain present — physical extension components are " *
                "flattened by the logical walk (see the Int64 idExtension/idExtended values)\n",
                color = _DT_C_WARN, bold = true)
    for (bi, b) in enumerate(shown)
        bi > 1 && println(io)                        # a blank line between Blocks
        lastb = bi == length(shown)
        row(b, lastb ? "└─ " : "├─ ", _DT_C_BLOCK, "Block")
        gB = lastb ? "   " : "│  "
        lines = grain === :block ? Any[] :
                [l for l in _dt_children(doc, b) if _dt_intersects(l, lines_r)]
        ## RAILS: an attribute row of a
        ## component with a printed child carries │ at the first child's connector
        ## column — the parent→first-child rail is unbroken; childless stays blank
        dumplines(b, gB * (isempty(lines) ? "   " : "│  "))
        grain === :block && continue
        for (li, l) in enumerate(lines)
            lastl = li == length(lines)
            segs = grain === :line ? Any[] : _dt_children(doc, l)
            # the print-once law: print the string once, at the DEEPEST DISPLAYED owner — the
            # Line shows it whenever its Segments are not displayed (incl. grain=:line)
            row(l, gB * (lastl ? "└─ " : "├─ "), _DT_C_LINE, "Line";
                content = isempty(segs) ? _dt_content(doc, l) : nothing)
            gL = gB * (lastl ? "   " : "│  ")
            dumplines(l, gL * (isempty(segs) ? "   " : "│  "))   # rails (Part B)
            for (si, s) in enumerate(segs)
                lasts = si == length(segs)
                row(s, gL * (lasts ? "└─ " : "├─ "), _DT_C_SEG, "Segment";
                    content = _dt_content(doc, s))
                dumplines(s, gL * (lasts ? "   " : "│  ") * "   ")   # leaf: blank rail column
            end
        end
    end
end

## ── :tree (plain compact — kept as an option; `dumps=true` =
##    detail=:full: the SAME tree rows with the typed dump pair appended per component) ──
function _dt_t1_tree(io, doc, sel, lines_r, grain; dumps::Bool = false)
    nb, nl, ns = _dt_census(doc)
    _dt_sty(io, "File  ", bold = true); _dt_sty(io, doc.name, bold = true)
    _dt_sty(io, "  —  $nb Blocks · $nl Lines · $ns Segments\n", color = _DT_C_CHROME)
    isempty(sel) && (_dt_sty(io, "(no Blocks)\n", color = _DT_C_CHROME); return)
    row(c, guide, gcol, name; content = nothing) = begin
        _dt_sty(io, guide, color = _DT_C_CHROME)
        _dt_sty(io, _dt_tpad("$name #$(_dt_id(c))", 12), color = gcol, bold = (name == "Block"))
        _dt_sty(io, _dt_tpad(_dt_flavor(c), 5), color = _dt_fcolor(_dt_flavor(c)))
        _dt_sty(io, "  " * _dt_tpad(_dt_span(c), 8), color = _DT_C_CHROME)
        content !== nothing && _dt_sty(io, " \"" * _dt_excerpt(content, 40) * "\"")
        _dt_sty(io, "  {" * join(string.(_dt_trueflags(c)), " ") * "}", color = _DT_C_CHROME)
        println(io)
    end
    shown = [b for b in sel if _dt_intersects(b, lines_r)]
    isempty(shown) &&
        (_dt_sty(io, "(no Blocks matched the lines= range)\n", color = _DT_C_CHROME); return)
    for (bi, b) in enumerate(shown)
        lastb = bi == length(shown)
        row(b, lastb ? "└─ " : "├─ ", _DT_C_BLOCK, "Block")
        lines = grain === :block ? Any[] :
                [l for l in _dt_children(doc, b) if _dt_intersects(l, lines_r)]
        ## rails: │ at the first child's connector column
        dumps && _dt_dumplines(io, b, (lastb ? "   " : "│  ") *
                                      (isempty(lines) ? "   " : "│  "))
        grain === :block && continue
        for (li, l) in enumerate(lines)
            lastl = li == length(lines)
            g1 = lastb ? "   " : "│  "
            row(l, g1 * (lastl ? "└─ " : "├─ "), _DT_C_LINE, "Line";
                content = _dt_content(doc, l))
            segs = grain === :line ? Any[] : _dt_children(doc, l)
            dumps && _dt_dumplines(io, l, g1 * (lastl ? "   " : "│  ") *
                                          (isempty(segs) ? "   " : "│  "))   # rails
            grain === :line && continue
            for (si, s) in enumerate(segs)
                g2 = g1 * (lastl ? "   " : "│  ")
                row(s, g2 * (si == length(segs) ? "└─ " : "├─ "), _DT_C_SEG, "Segment";
                    content = _dt_content(doc, s))
                dumps && _dt_dumplines(io, s, g2 * (si == length(segs) ? "   " : "│  ") * "   ")
            end
        end
    end
end

## ── :legacy — the February look on the sound census (frozen header) ───────────────────
function _dt_t1_legacy(io, doc, sel, lines_r, grain)
    H(n) = repeat('#', n)
    _dt_sty(io, "\n$(H(90))\n$(H(90))\n###### printComponentStates(...):\n", bold = true)
    isempty(sel) && _dt_sty(io, "\n(no Blocks)", color = _DT_C_CHROME)   # the empty-file law
    dump_named(c, ::Type{T}, boolstore) where T = begin
        _dt_sty(io, "\n###### Type of NamedElement: $(nameof(T))", color = _DT_C_LEGACY_DUMP, bold = true)
        parts = String[]
        for k in keys(T)
            v = _DT_BLS.getElement(c, k)   # by key, through the door (the key names the container)
            boolstore ? (v && push!(parts, "$k=>1")) : push!(parts, "$k=>$v")
        end
        _dt_sty(io, "\n##" * (isempty(parts) ? "" : " " * join(parts, ", ")), color = _DT_C_LEGACY_DUMP)
    end
    dumps(c) = (dump_named(c, _DT_BLS.CmpntNamedInt, false);
                dump_named(c, _DT_BLS.ComponentSettribute, true))
    for b in sel
        _dt_intersects(b, lines_r) || continue
        blockId = _dt_id(b)
        _dt_sty(io, "\n\n$(H(90))\n$(H(6)) :inputLineNum = $(_dt_ni(b,:inputLineNum)) $(H(35)) blockId = $blockId $(H(16))\n$(H(35)) $(_dt_flavor(b)) $(H(33))",
                color = _DT_C_BLOCK, bold = true)
        dumps(b)
        grain === :block && continue
        for l in _dt_children(doc, b)
            _dt_intersects(l, lines_r) || continue
            lineId = _dt_id(l)
            _dt_sty(io, "\n\n$(H(6)) :inputLineNum = $(_dt_ni(l,:inputLineNum)) $(H(35)) lineId = $lineId $(H(16))\n$(H(35)) $(_dt_flavor(l)) $(H(33))",
                    color = _DT_C_LINE, bold = true)
            dumps(l)
            grain === :line && continue
            for s in _dt_children(doc, l)
                segId = _dt_id(s)
                _dt_sty(io, "\n\n$(H(6)) :inputLineNum = $(_dt_ni(s,:inputLineNum)) $(H(9)) $(_dt_flavor(s)) $(H(9)) segmentId = $segId $(H(10))",
                        color = _DT_C_SEG, bold = true)
                dumps(s)
            end
        end
    end
    _dt_sty(io, "\n$(H(90))\n$(H(90))\n", bold = true)
end

## ── :banner — ##-chromed banners + source text + one-line compact dumps ───────────────
function _dt_t1_banner(io, doc, sel, lines_r, grain)
    H(n) = repeat('#', n)
    isempty(sel) && (_dt_sty(io, "(no Blocks)\n", color = _DT_C_CHROME); return)
    compact(c; indent = "") = begin
        _dt_sty(io, indent * "ints  ", color = _DT_C_CHROME)
        _dt_sty(io, join(["$k=$(_dt_ni(c,k))" for k in keys(_DT_BLS.CmpntNamedInt)], " "), color = _DT_C_LEGACY_DUMP)
        println(io)
        _dt_sty(io, indent * "flags ", color = _DT_C_CHROME)
        _dt_sty(io, join(string.(_dt_trueflags(c)), " "), color = _DT_C_LEGACY_DUMP)
        println(io)
    end
    for b in sel
        _dt_intersects(b, lines_r) || continue
        _dt_sty(io, "\n$(H(78))\n", color = _DT_C_BLOCK, bold = true)
        _dt_sty(io, "###### Block #$(_dt_id(b))  $(_dt_flavor(b))  $(_dt_span(b))\n", color = _DT_C_BLOCK, bold = true)
        _dt_sty(io, "\"" * _dt_excerpt(_dt_content(doc, b), 66) * "\"\n")
        compact(b)
        grain === :block && continue
        for l in _dt_children(doc, b)
            _dt_intersects(l, lines_r) || continue
            _dt_sty(io, "\n  ### Line #$(_dt_id(l))  $(_dt_flavor(l))  $(_dt_span(l))  ", color = _DT_C_LINE, bold = true)
            _dt_sty(io, "\"" * _dt_excerpt(_dt_content(doc, l), 44) * "\"\n")
            compact(l; indent = "  ")
            grain === :line && continue
            for s in _dt_children(doc, l)
                _dt_sty(io, "\n    ## Segment #$(_dt_id(s))  $(_dt_flavor(s))  $(_dt_span(s))  ", color = _DT_C_SEG, bold = true)
                _dt_sty(io, "\"" * _dt_excerpt(_dt_content(doc, s), 40) * "\"\n")
                compact(s; indent = "    ")
            end
        end
    end
end

#########################################################################################
##  §E — tool 2: print_altValues_evals
#########################################################################################

const _DT_T2_LAYOUTS = (:tree, :rows, :cells)

"""
    print_altValues_evals(io::IO, result::GoMetaDelivery; kwargs...)      # core method
    print_altValues_evals(result::GoMetaDelivery; kwargs...)              # → stdout
    write_altValues_evals_to_file(path, result; format=:auto, kwargs...)

IS: the second of the two print tools — the
    `altValues_evals` rows of one `goMeta` result, each evals row placed AT its BLS Component (which label landed WHERE,
    which metaSegment caused it), with the input-line spans the raw rows lack. The FULL delivery view — every
    Component shown, absence labelled, every row with its decoded handle — is `layout = :tree, include_empty = true,
    show_handles = true` (the verb `evals-tree`); the compact tree (the default) is the compact delivery view — a reading form for
    a quick look. Both tree views end with THE RUN SECTION (since 0.4.3): the run's status line and its diagnostics folded as
    `print_diagnostics` folds them — printed also where the view has no evals rows; the `:rows` and `:cells` layouts carry none.
    A development tool: nothing under `src/` reads it.
DOES: reads the rows through the public reader `GoMeta.readAltValuesEvals(result.altValues_evals)`, decodes each handle
    with the shared `decode_handle` and resolves its Component by the plain path walk through the door (`DTEvalRow`); a
    row's text is the door's `BLS.content` of that Component. Absence is explicit: a shown component with no rows reads
    `(no evals — defaults apply)` — the printer reads the Engine's rows alone, never the answer function, so it asserts no
    value where no row exists (an Alterant's declared default — `Alterant.default`, Visib's `:show`, the explicit default
    carried by the Engine since 0.4.0 — is the answer function's, `GoMeta.evaluatedAltValue`,
    never a row). With no rows at all it prints `(no evals rows — no Alterant value recorded on any surface)` after the filters' echo.
    METHOD DISPATCH — which call form triggers what: exactly as `print_BLS_Component_Tree` (core `(io, result)`;
    `(result)` = stdout convenience; the write twin infers `format` from the extension, `.html` ⇒ styled HTML page, else
    text with `color = :never` default).
    PARAMETERS:
    - `color::Symbol = :auto` — as in `print_BLS_Component_Tree`.
    - `layout::Symbol = :tree` — selects the renderer:
      `:tree`  (default): the component-tree skeleton with eval bullets attached AT their Components. The skeleton's
               NODES stop at the Line grain, and rows anchor accordingly: `:label_<name>`/`:visib` rows key on the owning
               Line/Block (the causing metaSegment rides the `← Segment #N` origin tag — the inline head row too since
               0.4.0: keyed on its Line, grain 0x0a, the Segment its origin); a Segment-grain row, were
               one minted (none by the default registry), would attach to its owning Line with a dim
               `[Segment #N]` target tag; File-grain rows render at a `[File]` bullet under the header. Every counted row
               renders somewhere. Segment STRUCTURE questions belong to `print_BLS_Component_Tree`.
      `:rows`  — one line per eval, input-line span first, sorted by input line then attr: the evals-rows-by-Component view.
      `:cells` — the per-cell view: dossiers with the decoded handle (ns · grain · path · origin), one dossier per handle in
               input-line order. Unanchored rows appear as red `### CELL (… no document tree position)` dossiers (this
               layout has no counting header and no separate section).
    - `include_empty = nothing` — `:tree` ONLY; any other layout ERRORS on an explicit `true`/`false` (the `nothing`
      sentinel is HOW that is detected: unset means "the default `false`", so only a deliberate value can
      conflict with the layout). `false` collapses to evals-bearing subtrees with dim IN-PLACE elision rows
      (`… N Blocks/Lines (no evals)`); `true` keeps every node visible, making ABSENCE readable ("why did `:label1` NOT
      apply?"). With a filter active the absence labels say `(no matching evals)` — never asserting engine-level absence
      for filtered rows.
    - `attrs = :all` — a `Symbol` or `Vector{Symbol}` filter (e.g. `:visib`, `[:label_label3]` — the label rows alone). The
      header echoes the filter with per-attr match counts; a requested attr with NO rows prints an explicit
      "0 matches — :attr never minted" line, never silence.
    - `lines = nothing` — an input-line range: keeps rows whose target span intersects; unanchored rows have no span and
      are NEVER hidden by `lines` (only `attrs` can); in `:tree` the range also acts as a FOCUS (matching targets + their
      ancestors stay, unrelated empty subtrees collapse). With any filter active the header echoes `showing N of M rows`.
    - `show_handles::Bool = false` — `:cells` always shows decoded handles; `:rows`/`:tree` add them per row when `true`.
    - `_name::AbstractString = ""` — the display name in the header line (internal-ish; the write twin defaults it to
      `basename(path)`).
    An unknown `layout`, `color`, `attrs` or `lines` value ERRORS with a message naming the accepted forms. Every row
    renders in every layout: a row the tools cannot place (a handle that does not decode; a grain above the File grain —
    the user-context plane, on which no shipped path keys a row since 0.4.0;
    a path step with no such child) is never dropped — `:rows`/`:tree` render it in a red
    `unanchored rows` section (the headers count it); `:cells` renders it as a red `### CELL (… no document tree position)`
    dossier of its own. The two `print_altValues_evals` methods return `nothing`; `write_altValues_evals_to_file`
    returns `path`.
REASONING: what a run evaluated, for which Component, is stated from the Engine's rows (`altValues_evals`) and the
    delivered tree — the run's two MAIN PRODUCTS (the creator's term) — never re-derived
    from raw text. The row's Component is resolved by the plain walk (a former
    defensive contract was removed); `polarity` renders DIM because it is constant `true` at v0 — a polarity-driven color would
    be constant fake signal. An absence label never asserts a value the Engine did not record.
PURPOSE: the tools' rule (devtools/README.md): no claim about what a run evaluated, for which Component, without
    one of these printouts — the FULL delivery view for any published claim, any view naming the Component for a quick look — and the printout goes,
    unabridged, into any page or record that carries the claim. The "why NOT" companion: when a label/action you expected
    is ABSENT here, the next step is the command-line entry `devtools.jl trace <file>` (evals rows + decoded
    handles) and `print_BLS_Component_Tree` (the settribute state the conditions tested).
"""
function print_altValues_evals(io::IO, result::GoMeta.GoMetaDelivery;
        color::Symbol = :auto, layout::Symbol = :tree,
        include_empty::Union{Bool,Nothing} = nothing,
        attrs = :all, lines = nothing, show_handles::Bool = false,
        _name::AbstractString = "")
    layout in _DT_T2_LAYOUTS ||
        error("print_altValues_evals: unknown layout=:$layout (one of $(_DT_T2_LAYOUTS))")
    color in (:auto, :always, :never) ||
        error("print_altValues_evals: unknown color=:$color (:auto | :always | :never)")
    layout !== :tree && include_empty !== nothing &&
        error("print_altValues_evals: include_empty applies to layout=:tree only (got layout=:$layout)")
    attrs === :all || attrs isa Symbol ||
        (attrs isa AbstractVector && all(x -> x isa Symbol, attrs)) ||
        error("print_altValues_evals: attrs must be :all, a Symbol, or a Vector of Symbols (got $(repr(attrs)))")
    lines === nothing || lines isa AbstractUnitRange{<:Integer} ||
        error("print_altValues_evals: lines must be nothing or an integer range like 5:12 (got $(repr(lines)))")
    inc = include_empty === nothing ? false : include_empty      # the default
    io = color === :auto ? io : IOContext(io, :color => (color === :always))
    doc = _dt_doc(result; name = _name)
    rows = _dt_eval_rows(doc)
    frows, echo, filtered = _dt_filter_rows(rows, attrs, lines)
    if isempty(rows)
        _dt_echo(io, echo)      # active filters echo (incl. "never minted") even here
        _dt_sty(io, "(no evals rows — no Alterant value recorded on any surface)\n", color = _DT_C_CHROME)
        layout === :tree && _dt_run_section(io, result, _name)   # the run section even without rows — an unknown label's run has none and carries its warning rows
        return nothing
    end
    if layout === :rows
        _dt_t2_rows(io, doc, frows, rows, echo; show_handles)
    elseif layout === :tree
        _dt_t2_tree(io, doc, frows, rows, echo; include_empty = inc, lines_r = lines,
                    show_handles, filtered)
        _dt_run_section(io, result, _name)   # THE RUN SECTION (since 0.4.3): the status line and the diagnostics folded — the view self-contained
    else
        _dt_t2_cells(io, doc, frows, rows, echo)
    end
    nothing
end

"REPL convenience — `print_altValues_evals(stdout, result; kwargs...)`. See the core docstring."
print_altValues_evals(result::GoMeta.GoMetaDelivery; kwargs...) =
    print_altValues_evals(stdout, result; kwargs...)

## THE RUN SECTION of the tree views (since 0.4.3 — the creator's decision: the FULL delivery view and the compact tree end with the run's
## status line and its diagnostics, so a view carries what the run reported): one chrome line — the status and the count of diagnostic rows
## (or "no diagnostics") — then, where rows exist, the diagnostics folded EXACTLY as the end-of-run print `print_diagnostics` folds them (the
## same function; its text routed through the one styled-run emitter, so the HTML sink escapes it); printed also where the view has no evals
## rows; the `:rows` and `:cells` layouts untouched.
function _dt_run_section(io, result, name)
    n = length(result.diagnostics)
    _dt_sty(io, "── the run: status " * string(result.status) * (n == 0 ? " · no diagnostics" : " · " * _dt_plural(n, "diagnostic row")) * "\n", color = _DT_C_CHROME)
    if n > 0
        b = IOBuffer(); print_diagnostics(b, result; name = name)
        _dt_sty(io, String(take!(b)))
    end
    nothing
end

## IS: the filter contract. DOES: normalizes `attrs` (:all | Symbol | Vector),
## validates + filters BEFORE layout, keeps unanchored rows immune to `lines`, and
## returns `(filtered_rows, echo_lines, active)` — the echo lines carry the active filters, per-attr match counts and the EXPLICIT never-minted state;
## `active` is true when an attrs or lines filter was supplied (the one flag the absence labels read — `nolabel` / `eliword` in `_dt_t2_tree`).
function _dt_filter_rows(rows, attrs, lines_r)
    echo = Vector{Tuple{String,Union{Symbol,Nothing}}}()   # (text, color-key) pairs
    fr = rows
    if attrs !== :all
        want = attrs isa Symbol ? [attrs] : collect(Symbol.(attrs))
        fr = [r for r in fr if r.attr in want]
        for a in want
            n = count(r -> r.attr == a, rows)
            if n == 0
                push!(echo, ("filter attrs — 0 matches — :$a never minted", :bad))
            else
                push!(echo, ("filter attrs — :$a: $n match" * (n == 1 ? "" : "es"), nothing))
            end
        end
    end
    if lines_r !== nothing
        fr = [r for r in fr if r.comp === nothing || _dt_intersects(r.comp, lines_r)]
        push!(echo, ("filter lines=$(lines_r) (unanchored rows are never hidden by lines)", nothing))
    end
    active = attrs !== :all || lines_r !== nothing
    active &&                                            # filtered/total ALWAYS echoed
        push!(echo, ("showing $(length(fr)) of $(length(rows)) rows", nothing))
    (fr, echo, active)      # `active` is THE filter flag — single source for the labels
end

function _dt_echo(io, echo)
    for (txt, kind) in echo
        _dt_sty(io, txt * "\n", color = kind === :bad ? _DT_C_BAD : _DT_C_CHROME,
                bold = kind === :bad)
    end
end

## The ONE decoded-handle formatter: namespace, grain,
## FULL path + origin steps — used by show_handles in every layout and by :cells.
_dt_fmtsteps(v) = "[" * join(["(" * (st == 0x01 ? "direct" : st == 0x02 ? "insert" :
                                     st == 0x00 ? "TRUNCATED" :
                                     "unknown-store-0x" * string(st, base = 16)) *
                              ",$(Int(o)))" for (st, o) in v], " ") * "]"
function _dt_handle_note(io, row, indent)
    d = row.key
    body = d === nothing ?
        "handle UNDECODED raw=0x" * bytes2hex(row.handle[1:min(end, 16)]) * (length(row.handle) > 16 ? "…" : "") :
        "handle ns=:$(d.namespace)  grain=$(_dt_grainname(d.grain))  path=$(_dt_fmtsteps(d.path))" *
            (isempty(d.origin) ? "" : "  origin=$(_dt_fmtsteps(d.origin))")
    _dt_sty(io, indent * body * "\n", color = _DT_C_CHROME)
end

## ── :rows — the evals-rows-by-Component view ───────────────────────────────────────────────────────
function _dt_t2_rows(io, doc, frows, allrows, echo; show_handles::Bool = false)
    ncells = length(unique(r.handle for r in allrows))
    _dt_sty(io, "altValues_evals  ", bold = true); _dt_sty(io, doc.name, bold = true)
    _dt_sty(io, "  —  $(length(allrows)) rows on $ncells cells\n", color = _DT_C_CHROME)
    _dt_echo(io, echo)
    anchored = [r for r in frows if r.comp !== nothing]
    sorted = sort(anchored; by = r -> (_dt_ni(r.comp, :inputLineNum), string(r.attr)))
    for row in sorted
        c = row.comp
        _dt_sty(io, _dt_tpad(_dt_span(c), 9), color = _DT_C_CHROME)
        _dt_sty(io, _dt_tpad("$(_dt_grain(c)) #$(_dt_ni(c,:idComponent))", 11),
                color = _dt_gcolor(c), bold = c isa _DT_BLS.Block)
        ## the dedicated flavor triple (supersedes the former dim chrome —
        ## flavors must be distinct from each other AND from every other used color)
        _dt_sty(io, _dt_tpad(_dt_flavor(c), 6), color = _dt_fcolor(_dt_flavor(c)))
        _dt_sty(io, _dt_tpad(string(row.attr), 12), color = _DT_C_ATTR, bold = true)
        _dt_sty(io, " => ")
        _dt_sty(io, _dt_tpad(repr(row.value), 8), color = _dt_vcolor(row), bold = true)
        _dt_sty(io, row.polarity ? " (+)" : " (−)", color = _DT_C_CHROME)
        row.origin !== nothing && _dt_sty(io, "  ← $(_dt_grain(row.origin)) #$(_dt_ni(row.origin,:idComponent)) \"" *
            _dt_excerpt(strip(_dt_content(doc, row.origin)), 20) * "\"", color = _DT_C_CHROME)
        _dt_sty(io, "  \"" * _dt_excerpt(strip(_dt_content(doc, c)), 36) * "\"")
        println(io)
        show_handles && _dt_handle_note(io, row, "         ")
    end
    _dt_print_unanchored(io, doc, _dt_unanchored(frows); show_handles)
end

## ── :tree — evals AT their Components (default layout) ────────────────────────────────
## Layout totality: an inline metaSegment's head row is LINE-anchored since 0.4.0 (keyed on its Line:
## grain 0x0a, the Segment its origin, shown by the `← Segment #N` tag); a Segment-anchored row, were one minted
## (none by the default registry), would attach to its OWNING LINE with a dim `[Segment #N]` target tag; File-anchored rows render at a File node
## right under the header. Headers therefore never count a row the body omits.
function _dt_t2_tree(io, doc, frows, allrows, echo;
                     include_empty::Bool, lines_r, show_handles::Bool = false,
                     filtered::Bool = false)
    am = Dict{Tuple{DataType,Int},Vector{DTEvalRow}}()
    fileRows = DTEvalRow[]
    for r in frows
        r.comp === nothing && continue
        if r.comp isa _DT_BLS.File
            push!(fileRows, r)
        elseif r.comp isa _DT_BLS.Segment
            push!(get!(() -> DTEvalRow[],
                       am, (_DT_BLS.Line, Int(_dt_ni(r.comp, :idParent)))), r)
        else
            push!(get!(() -> DTEvalRow[], am, _dt_akey(r.comp)), r)
        end
    end
    nb, nl, _ = _dt_census(doc)
    ncells = length(unique(r.handle for r in allrows))
    _dt_sty(io, "File  ", bold = true); _dt_sty(io, doc.name, bold = true)
    _dt_sty(io, "  —  $(length(allrows)) evals rows on $ncells cells  (of $nb Blocks · $nl Lines)\n",
            color = _DT_C_CHROME)
    _dt_echo(io, echo)
    for row in fileRows                      # File-anchored rows: the document-root node
        _dt_eval_bullet(io, doc, row; target_tag = "[File]")
        show_handles && _dt_handle_note(io, row, "    ")
    end
    # with a filter active, an absence label must not assert "no evals" — rows may
    # simply be filtered out
    nolabel  = filtered ? "   (no matching evals)" : "   (no evals — defaults apply)"
    eliword  = filtered ? "(no matching evals)" : "(no evals)"
    node(c, guide, name) = begin
        has = haskey(am, _dt_akey(c))
        _dt_sty(io, guide, color = _DT_C_CHROME)
        _dt_sty(io, _dt_tpad("$name #$(_dt_id(c))", 10), color = _dt_gcolor(c), bold = has)
        _dt_sty(io, _dt_tpad(_dt_flavor(c), 5), color = _dt_fcolor(_dt_flavor(c)))  # the flavor triple
        _dt_sty(io, " " * _dt_tpad(_dt_span(c), 8), color = _DT_C_CHROME)
        _dt_sty(io, " \"" * _dt_excerpt(strip(_dt_content(doc, c)), 38) * "\"")
        has || _dt_sty(io, nolabel, color = _DT_C_CHROME)
        println(io)
        has
    end
    elision(guide, n, word) = (_dt_sty(io, guide, color = _DT_C_CHROME);
                               _dt_sty(io, "… " * _dt_plural(n, word) * " " * eliword * "\n",
                                       color = _DT_C_CHROME))
    emit_rows(c, indent) = for row in get(am, _dt_akey(c), DTEvalRow[])
        tag = row.comp isa _DT_BLS.Segment ?
              "[Segment #$(_dt_ni(row.comp, :idComponent))]" : ""
        _dt_eval_bullet(io, doc, row; indent, target_tag = tag)   # guide + "● "
        show_handles && _dt_handle_note(io, row, indent * "    ")
    end
    empty_ok(c) = include_empty && _dt_intersects(c, lines_r)   # lines= is also the focus
    block_shown(b) = empty_ok(b) || haskey(am, _dt_akey(b)) ||
                     any(haskey(am, _dt_akey(l)) for l in _dt_children(doc, b))
    shownBlocks = filter(block_shown, doc.blocks)
    if isempty(shownBlocks)
        isempty(doc.blocks) && _dt_sty(io, "(no Blocks)\n", color = _DT_C_CHROME)
    end
    pending = 0
    for b in doc.blocks
        if !block_shown(b)
            pending += 1; continue
        end
        pending > 0 && (elision("├─ ", pending, "Block"); pending = 0)
        blockId = _dt_id(b)
        lastb = blockId == _dt_id(last(shownBlocks)) && blockId == _dt_id(last(doc.blocks))
        node(b, lastb ? "└─ " : "├─ ", "Block")
        emit_rows(b, (lastb ? "   " : "│  "))
        lines = _dt_children(doc, b)
        line_shown(l) = empty_ok(l) || haskey(am, _dt_akey(l))
        shownL = filter(line_shown, lines)
        g1 = lastb ? "   " : "│  "
        pendL = 0
        for l in lines
            if !line_shown(l)
                pendL += 1; continue
            end
            pendL > 0 && (elision(g1 * "├─ ", pendL, "Line"); pendL = 0)
            lineId = _dt_id(l)
            lastl = lineId == _dt_id(last(shownL)) && lineId == _dt_id(last(lines))
            node(l, g1 * (lastl ? "└─ " : "├─ "), "Line")
            emit_rows(l, g1 * (lastl ? "   " : "│  "))
        end
        pendL > 0 && elision(g1 * "└─ ", pendL, "Line")
    end
    pending > 0 && elision("└─ ", pending, "Block")
    _dt_print_unanchored(io, doc, _dt_unanchored(frows); show_handles)
end

## ── :cells — the per-cell view: dossiers with decoded handles ────────────────────────────────────
function _dt_t2_cells(io, doc, frows, allrows, echo)
    H(n) = repeat('#', n)
    groups = Dict{Vector{UInt8},Vector{DTEvalRow}}()
    order = Vector{Vector{UInt8}}()
    for r in frows
        haskey(groups, r.handle) || push!(order, r.handle)
        push!(get!(() -> DTEvalRow[], groups, r.handle), r)
    end
    sort!(order; by = h -> (c = groups[h][1].comp; c === nothing ? typemax(Int) : _dt_ni(c, :inputLineNum)))
    _dt_sty(io, "altValues_evals — per-cell  ", bold = true); _dt_sty(io, doc.name * "\n", bold = true)
    _dt_echo(io, echo)
    for h in order
        grp = groups[h]; c = grp[1].comp; d = grp[1].key
        _dt_sty(io, "\n$(H(78))\n", color = _DT_C_CHROME)
        if c === nothing
            g = d === nothing ? "?" : _dt_grainname(d.grain)
            _dt_sty(io, "### CELL  ($g — no document tree position)\n",
                    color = _DT_C_BAD, bold = true)
        else
            _dt_sty(io, "### CELL  ", color = _dt_gcolor(c), bold = true)
            _dt_sty(io, "$(_dt_grain(c)) #$(_dt_ni(c,:idComponent))  ",
                    color = _dt_gcolor(c), bold = true)
            _dt_sty(io, _dt_flavor(c), color = _dt_fcolor(_dt_flavor(c)), bold = true)  # the flavor triple
            _dt_sty(io, "  $(_dt_span(c))\n", color = _dt_gcolor(c), bold = true)
            _dt_sty(io, "### content  ", color = _DT_C_CHROME)
            _dt_sty(io, "\"" * _dt_excerpt(strip(_dt_content(doc, c)), 60) * "\"\n")
        end
        if d !== nothing
            _dt_sty(io, "### handle   ns=:$(d.namespace)  grain=$(_dt_grainname(d.grain))  path=$(_dt_fmtsteps(d.path))" *
                        (isempty(d.origin) ? "" : "  origin=$(_dt_fmtsteps(d.origin))") * "\n", color = _DT_C_CHROME)
        end
        for row in grp
            _dt_eval_bullet(io, doc, row; indent = "    ")
        end
    end
end

#########################################################################################
##  §F — the file twins (the format inferred from the sink's extension)
#########################################################################################

## The HTML page wrapper — byte-identical to the mockup generator's, so .html output
## stays comparable to the design mockups.
function _dt_write_html(path, renderfn, title)
    open(path, "w") do f
        print(f, "<!doctype html><meta charset=\"utf-8\"><title>", _dt_htmlesc(title),
              "</title><body style=\"background:#1e2127;margin:1.5em\"><pre style=\"color:#d7dae0;font:14px/1.45 monospace\">")
        renderfn(IOContext(f, :gm_html => true))
        print(f, "</pre></body>")
    end
end

function _dt_resolve_format(path, format)
    format in (:auto, :html, :txt) ||
        error("write_*_to_file: unknown format=:$format (:auto | :html | :txt)")
    format === :auto ? (lowercase(splitext(path)[2]) == ".html" ? :html : :txt) : format
end

"""
    write_BLS_Component_Tree_to_file(path, result; format=:auto, color=:never,
                                     title="print_BLS_Component_Tree", kwargs...)

IS: the file twin of [`print_BLS_Component_Tree`](@ref) (the February `print*`/`write*` pair convention, with its file sinks
    and the format inferred from the extension) — the `.html` / `.txt` twin of the print tool
    (a development tool).
DOES: `format` selects the sink: `:auto` (default) infers from the extension — `.html` (case-insensitive) ⇒ the
    self-contained styled HTML page, ANY other extension (or none) ⇒ text; an explicit `:html` / `:txt` OVERRIDES the
    extension entirely; any other value ERRORS (`write_*_to_file: unknown format=…`). `color` does not apply to the HTML
    sink (always styled). Text default `color=:never` (plain, grep-friendly); `color=:always` writes ANSI escape bytes
    (view with `less -R`). `title` is the HTML page's `<title>` (ignored for text output). The rendered `File` header
    uses `basename(path)` as the document name unless `_name` is passed explicitly. All other kwargs pass through to the
    core method. Opens `path` for writing, renders, closes; returns `path`.
REASONING: the HTML sink is the core method rendered into an `IOContext` carrying `:gm_html => true`, which the one
    styled-run emitter `_dt_sty` routes to `<span>` styles — one renderer, three sinks (terminal, plain text, HTML); the
    page wrapper is byte-identical to the mockup generator's, so `.html` output stays comparable to the design mockups.
PURPOSE: a printout as a file — a page that shows what a run produced carries the
    `:mix` tree as `.html` through it; the `.txt` form is the grep-friendly record.
"""
function write_BLS_Component_Tree_to_file(path::AbstractString, result::GoMeta.GoMetaDelivery;
        format::Symbol = :auto, color::Symbol = :never,
        title::AbstractString = "print_BLS_Component_Tree",
        _name::AbstractString = basename(path), kwargs...)
    if _dt_resolve_format(path, format) === :html
        _dt_write_html(path, io -> print_BLS_Component_Tree(io, result; _name, kwargs...), title)
    else
        open(path, "w") do f
            print_BLS_Component_Tree(f, result; color, _name, kwargs...)
        end
    end
    path
end

"""
    write_altValues_evals_to_file(path, result; format=:auto, color=:never,
                                  title=..., kwargs...)

IS: the file twin of [`print_altValues_evals`](@ref) — the `.html` / `.txt` twin of the print tool
    (a development tool; the format inferred from the sink's extension).
DOES: same format/color/title/_name rules as [`write_BLS_Component_Tree_to_file`](@ref): `format` `:auto` infers the sink
    from the extension (`.html`, case-insensitive ⇒ the styled HTML page; else text), `:html` / `:txt` override it, any
    other value ERRORS; `color` applies to the text sink only (default `:never`); `title` defaults to
    `"print_altValues_evals"`; `_name` defaults to `basename(path)`; all other kwargs pass through to the core method
    (`layout`, `include_empty`, `show_handles`, `attrs`, `lines`). Returns `path`.
REASONING: one renderer, three sinks — the HTML sink is the core method rendered into an `IOContext` carrying
    `:gm_html => true`, routed by the one styled-run emitter `_dt_sty`; the page wrapper is the mockup generator's,
    byte-identical.
PURPOSE: the FULL delivery view as a file for the creator (`include_empty = true, show_handles = true`): a page that shows
    what a run produced carries it as `.html` through this twin; the JuliaCon deck's
    dev-tool slides and the demo deck were produced from its output with the tools' former `slide` option (removed within the
    0.4 development).
"""
function write_altValues_evals_to_file(path::AbstractString, result::GoMeta.GoMetaDelivery;
        format::Symbol = :auto, color::Symbol = :never,
        title::AbstractString = "print_altValues_evals",
        _name::AbstractString = basename(path), kwargs...)
    if _dt_resolve_format(path, format) === :html
        _dt_write_html(path, io -> print_altValues_evals(io, result; _name, kwargs...), title)
    else
        open(path, "w") do f
            print_altValues_evals(f, result; color, _name, kwargs...)
        end
    end
    path
end

#########################################################################################
##  §I — THE COMPARISON FORM (the reference set's comparison form, so that
##  GoMetaRetro is compared with v0.4 by CONTENT, never by bytes or Julia types; the
##  definition: tests/comparison/README.md — written ONCE, the grammar fixed by what this section emits).
##  IS:   the v0.4 engine's adapter: ONE content-keyed TEXT form per input — one line per Component
##        (kind, span, the parent's key, the position among the parent's children, the children's keys, the content
##        type, the flags of the creator's approved table) and one line per Component per Alterant (the resolved value and its
##        SOURCE as the deciding Component's own key, or its level: user / file / default); ordinals, ids, handles and
##        Julia types never appear. The File has its Component line and NO answer lines (nothing is built for the
##        File before the creator's decision).
##  DOES: walks the delivered tree through the door (`root`, `children`, `parent`, `kind`, `content`, `getElement`),
##        asks the Engine's answer through `evaluatedAltValues` (= `evaluatedAltValue` per registered Alterant), and emits the lines
##        SORTED by code point under one header line that names the input, the producing commit and the counts.
##  REASONING: the two variants may deliver different shapes and types; only a projection keyed by
##        content can be compared. A Segment's span is given in CHARACTERS of its line (the parser's byte offsets
##        converted on the line's own bytes — the definition's recommended unit, an open point).
##  PURPOSE: the twelve forms under tests/comparison/ (`regenerate.jl`) — v0.4's reference altValues, the creator's term — and the first comparator
##        `devtools/compare_forms.sh` (a sorted-text diff). A development tool: nothing under src/ reads it.
#########################################################################################
const _CF_VERSION = 1
const _CF_SEP = " | "

_cf_kind(c) = c isa _DT_BLS.File ? "File" : c isa _DT_BLS.Block ? "Block" : c isa _DT_BLS.Line ? "Line" : "Segment"

## a Segment's span in CHARACTERS of its own line: the parser's byte offsets (1-based; the stop byte is the final
## character's START byte, as `BLS.content` documents) converted on the line's bytes. (0, 0) for an unlocatable span.
function _cf_charspan(linebytes::Vector{UInt8}, startb::Int, stopb::Int)
    (startb >= 1 && stopb >= startb && stopb <= length(linebytes)) || return (0, 0)
    s = String(copy(linebytes))
    isvalid(s, startb) && isvalid(s, stopb) || return (0, 0)
    (length(s[1:prevind(s, startb)]) + 1, length(s[1:stopb]))
end

## the span field: Block `a-b` and Line `n-n` in input-line numbers; Segment `n:s-e` (its line's number, then the
## within-line character span); the File `a-b` from the first Block's start to the last Block's stop (the File's own
## locator fields are the parser's dummy — the span is derived from its Blocks, stated in the README; `0-0` without a Block)
function _cf_span(doc, c)
    if c isa _DT_BLS.File
        isempty(doc.blocks) && return "0-0"
        lo = minimum(Int(_dt_ni(b, :startMainStr)) for b in doc.blocks)
        hi = maximum(Int(_dt_ni(b, :stopMainStr)) for b in doc.blocks)
        return "$(lo)-$(hi)"
    elseif c isa _DT_BLS.Block
        return "$(Int(_dt_ni(c, :startMainStr)))-$(Int(_dt_ni(c, :stopMainStr)))"
    elseif c isa _DT_BLS.Line
        n = Int(_dt_ni(c, :inputLineNum))
        return "$(n)-$(n)"
    end
    n = Int(_dt_ni(c, :inputLineNum))
    line = _DT_BLS.parent(doc.ps, c)
    lb = line === nothing ? UInt8[] : _DT_BLS.content(doc.ps, line)
    a, b = _cf_charspan(lb, Int(_dt_ni(c, :startMainStr)), Int(_dt_ni(c, :stopMainStr)))
    return "$(n):$(a)-$(b)"
end

## the Component's content KEY — its kind and span; the form's only way of naming a Component (never an id or a handle)
_cf_key(doc, c) = _cf_kind(c) * " " * _cf_span(doc, c)

## the flags of the creator's approved table that are TRUE on the Component: every ComponentSettribute flag (the three Visib flags
## were removed from the record within the 0.4 development — the former exclusion of them is dead and gone),
## qualified `component.<name>`, sorted by code point, joined by `,`; `-` when none. The content flag vector
## (`contentSettributeBitVec`) has no read through the door and no writer in the parser (measured 2026-10-02)
## — no `content.<name>` flag can be emitted today (an open point).
function _cf_flags(c)
    names = String[]
    for k in keys(_DT_BLS.ComponentSettribute)
        _dt_ni(c, k) && push!(names, "component." * String(k))
    end
    isempty(names) ? "-" : join(sort!(names), ",")
end

## the VALUE grammar (no Julia type or container name): nothing → `null`; a Bool → `true`/`false`; a Symbol → its
## name; a text → double-quoted with `\\`, `\"`, `\n`, `\r`, `\t` escapes; an integer → decimal; a set (a Vector) →
## `{a,b}` with the members' texts sorted; a compound (a NamedTuple) → `(k=v,k=v)` with the fields sorted by name.
## The four built-in Alterants reach the first six arms (measured on the twelve inputs); the fallback quotes `repr`.
_cf_esc(s::AbstractString) = "\"" * replace(String(s), "\\" => "\\\\", "\"" => "\\\"", "\n" => "\\n", "\r" => "\\r", "\t" => "\\t") * "\""
function _cf_value(v)
    v === nothing && return "null"
    v isa Bool && return v ? "true" : "false"
    v isa Symbol && return String(v)
    v isa AbstractString && return _cf_esc(v)
    v isa Integer && return string(v)
    v isa AbstractVector && return "{" * join(sort!([_cf_value(x) for x in v]), ",") * "}"
    v isa NamedTuple && return "(" * join(["$(k)=$(_cf_value(getfield(v, k)))" for k in sort!(collect(keys(v)))], ",") * ")"
    return _cf_esc(repr(v))
end

## the SOURCE field: the deciding Component's own key — the Component itself for `:own`, the Component the answer
## came through for `:indirect` — or the level word (`user`, `file`, `default`); `:none` prints as `none` (the File has
## no answer lines; a custom registry's undeclared Alterant would)
function _cf_source(doc, c, a)
    a.source === :own && return _cf_key(doc, c)
    a.source === :indirect && return a.via === nothing ? "indirect" : _cf_key(doc, a.via)
    a.source === :user && return "user"
    a.source === :file && return "file"
    a.source === :default && return "default"
    return String(a.source)
end

function _cf_component_line(doc, c, parentkey::String, pos::String)
    kids = c isa _DT_BLS.Segment ? _DT_BLS.Segment[] : _DT_BLS.children(doc.ps, c)
    kidkeys = isempty(kids) ? "-" : join([_cf_key(doc, k) for k in kids], ";")
    ctype = c isa _DT_BLS.File ? "-" : string(_DT_BLS.kind(c))
    join(["C", _cf_kind(c), _cf_span(doc, c), parentkey, pos, kidkeys, ctype, _cf_flags(c)], _CF_SEP)
end

function _cf_answer_lines!(lines::Vector{String}, doc, c)
    n = 0
    for (alt, a) in GoMeta.evaluatedAltValues(doc.r, c)
        push!(lines, join(["A", _cf_kind(c), _cf_span(doc, c), String(alt), _cf_value(a.value), _cf_source(doc, c, a)], _CF_SEP))
        n += 1
    end
    n
end

"""
    comparisonForm(result; name = "", at = "-") -> String

IS: the comparison form of ONE `goMeta` result (the definition `tests/comparison/README.md`) — the text
    the twelve forms under `tests/comparison/` hold (v0.4's reference altValues, the creator's term); v0.4's
    adapter, a development tool: nothing under `src/` reads it.
DOES: one header line `# GoMeta comparison form v1 | <name> | produced by GoMeta v0.4 at <at> | <nC> Components |
    <nA> answer lines`, then every line of the form SORTED by code point: `C | kind | span | parent key | position |
    children keys | content type | flags` per Component, `A | kind | span | Alterant | value | source` per Component
    per Alterant (the File has its `C` line and none). The tree is walked through the door (`root`, `children`, `parent`,
    `kind`, `content`, `getElement`); the answers are the Engine's, `GoMeta.evaluatedAltValues` per Component; the source
    is the deciding Component's own key (`:own`; the `via` Component's key for `:indirect`, a bare `indirect` when the
    delivery names none) or the level word `user` / `file` / `default` (any other source its name). A Segment's span is
    given in CHARACTERS of its line (the parser's byte offsets converted on the line's own bytes); the File's span runs
    from its first Block's start to its last Block's stop, `0-0` without a Block. Throws (the door's own throw) on a
    delivery whose tree cannot be walked.
REASONING: the two variants may deliver different shapes and types; only a projection keyed by content can be
    compared — ordinals, ids, handles and Julia types never appear — and the lines carry content keys only, so two variants'
    projections compare as text; sorting makes the order a non-fact.
PURPOSE: `writeComparisonFormToFile`, the `comparison` verb, `tests/comparison/regenerate.jl` (which writes or checks the
    twelve), the battery's §18 and the first comparator `devtools/compare_forms.sh` (a sorted-text diff).
"""
function comparisonForm(result::GoMeta.GoMetaDelivery; name::AbstractString = "", at::AbstractString = "-")
    doc = _dt_doc(result; name = name)
    lines = String[]
    nA = 0
    f = _DT_BLS.root(doc.ps)
    push!(lines, _cf_component_line(doc, f, "-", "-"))
    fkey = _cf_key(doc, f)
    for (i, b) in enumerate(doc.blocks)
        push!(lines, _cf_component_line(doc, b, fkey, string(i)))
        nA += _cf_answer_lines!(lines, doc, b)
        bkey = _cf_key(doc, b)
        for (j, l) in enumerate(_DT_BLS.children(doc.ps, b))
            push!(lines, _cf_component_line(doc, l, bkey, string(j)))
            nA += _cf_answer_lines!(lines, doc, l)
            lkey = _cf_key(doc, l)
            for (k, s) in enumerate(_DT_BLS.children(doc.ps, l))
                push!(lines, _cf_component_line(doc, s, lkey, string(k)))
                nA += _cf_answer_lines!(lines, doc, s)
            end
        end
    end
    nC = length(lines) - nA
    sort!(lines)
    header = join(["# GoMeta comparison form v$(_CF_VERSION)", String(name), "produced by GoMeta v0.4 at " * String(at),
                   "$(nC) Components", "$(nA) answer lines"], _CF_SEP)
    return header * "\n" * join(lines, "\n") * "\n"
end

"""
    writeComparisonFormToFile(path, result; name = basename(path), at = "-") -> path

IS: the comparison form's file writer (the reference set's producer); a
    development tool.
DOES: writes `comparisonForm(result; name, at)` to `path`, verbatim (`write(path, text)`); returns `path`. `name`
    defaults to `basename(path)` and lands in the header; `at` is the producing commit the header names (the caller
    states it; `-` when unknown). The form is a comparison surface, not a share-view.
REASONING: the committed form's body must equal the producer's byte for byte — `regenerate.jl --check` compares each
    committed file's body (the lines after the header) with the form produced in memory; a changed body is re-made
    through this writer with `--at <the re-making commit's parent sha>` (the commit it builds on — a commit cannot carry its own sha; tests/comparison/README.md §2) in the commit that changes it, never edited.
PURPOSE: `tests/comparison/regenerate.jl` writes the twelve through it (`--at <sha>`, optionally `--out <dir>`); the
    battery's §18 writes one per fixture through it.
"""
function writeComparisonFormToFile(path::AbstractString, result::GoMeta.GoMetaDelivery;
                                   name::AbstractString = basename(String(path)), at::AbstractString = "-")
    write(path, comparisonForm(result; name = name, at = at))
    path
end

"REPL convenience — `comparisonForm(result)` printed to `io`."
printComparisonForm(io::IO, result::GoMeta.GoMetaDelivery; kwargs...) = print(io, comparisonForm(result; kwargs...))
printComparisonForm(result::GoMeta.GoMetaDelivery; kwargs...) = printComparisonForm(stdout, result; kwargs...)

#########################################################################################
##  §Z — THE COMMAND-LINE ENTRY (the former one-line command tool devtools/gometa.jl, FOLDED here on
##  2026-09-12; the file is deleted): the eight verbs
##      julia --startup-file=no --project=$GM/tests $GM/devtools/devtools.jl <verb> <file>
##      tree · segments · evals · render · trace · evals-tree · bls-tree · comparison (the comparison form, §I)
##  IS: the smallest complete consumer of the two containers — `altValues_evals` (the excerpts through the
##  door: `BLS.content` of each row's resolved Component) and the development tool's (tree, render) pair (`Main.BasicRenderer.outputs`,
##  loaded through the ONE path at this file's top). DOES: runs goMeta on ONE file; status + diagnostics
##  to stderr, the surface to stdout; exit 0 = PROCESS_OK, 1 = a non-OK result, 2 = usage. The `trace`
##  verb decodes each row's cell_handle with the SHARED `decode_handle` (handle_decoder.jl, §C) — the former CLI's
##  duplicate decoders (its rd_u16/rd_u32/rd_steps/decode_handle) are gone: ONE copy. REASONING: the
##  block runs ONLY when this file is the program (`abspath(PROGRAM_FILE) == @__FILE__`), never when it
##  is `include`d (the battery and other consumers include this file and
##  see definitions only). Evaluates, never executes.
#########################################################################################
"""
    print_diagnostics(io, delivery; name = "")

THE DIAGNOSTICS OF A RUN FOR A HUMAN (a `PROCESS_OK` run may carry `:warning` rows — the Labels Alterant's `LABEL_NOT_APPLIED_WITHHELD`,
a plain `:x` met by a withhold): the rows FOLDED by (code, severity, label, stating statement) — each group once: the code and the
severity, the label where the row's context carries one, the count, the message (each distinct message of the group once), the stating statement's place and the places the row
stands at (`L<n>` / `L<a>–L<b>`, decoded through the door from the handles the Engine attached — the applying Component's key, the stating
statement's handle, the Alterant's statements applied at that Component so far — each distinct history of the group once, with its places where the group holds more than one; "the user level's profile" for a fed statement, whose text
is not in the tree), every OTHER key of the context as data (a row minted at the read carries no Component key but the statement's text and
its level — `statement`, `level`; the Labels Alterant's vocabulary-file rows `file` and `change`; a custom Alterant's own keys — the tools know no Alterant's keys), a count line last; nothing printed for an empty vector; an error delivery's rows (a string or `nothing` context) print
their context as is. Reads the delivered object alone; evaluates nothing; the Engine prints nothing itself — this is the development tools'
print, the command line's end-of-run one.
"""
function print_diagnostics(io::IO, r; name::AbstractString = "")
    isempty(r.diagnostics) && return nothing
    doc = _dt_doc(r; name = name)
    function place(h)
        h isa Vector{UInt8} || return repr(h)
        d = decode_handle(h)
        d === nothing && return "UNDECODED"
        d.grain == 0xe0 && return "the user level's profile"
        c = _dt_resolve(doc, d.path)
        c === nothing ? _dt_cli_fmt_steps(d.path) : _dt_span(c)
    end
    groups = Dict{Any,Vector{Any}}(); order = Any[]
    for d in r.diagnostics
        ctx = d.context
        lab = ctx isa NamedTuple && haskey(ctx, :label) ? ctx.label : nothing
        sb  = ctx isa NamedTuple && haskey(ctx, :stated_by) ? ctx.stated_by : nothing
        k = (d.code, d.severity, lab, sb)
        haskey(groups, k) || (groups[k] = Any[]; push!(order, k))
        push!(groups[k], d)
    end
    for k in order
        rows = groups[k]; d = rows[1]; ctx = d.context
        println(io, "diagnostic: ", d.code, " (", d.severity, ")", k[3] === nothing ? "" : string(" — label ", escape_string(string(k[3]))), " — ", length(rows), " occurrence(s)")
        for m in unique(x.message for x in rows)
            println(io, "   ", m)
        end
        if ctx isa NamedTuple
            haskey(ctx, :stated_by) && println(io, "   stated by: ", place(ctx.stated_by))
            haskey(ctx, :cell) && println(io, "   at: ", join([place(x.context.cell) for x in rows], ", "))
            if haskey(ctx, :statements)
                hs = unique(x.context.statements for x in rows if x.context isa NamedTuple && haskey(x.context, :statements))
                for sts in hs
                    println(io, "   the ", haskey(ctx, :label) ? "Labels " : "", "statements applied there so far: ", join([place(h) for h in sts], ", "),
                            length(hs) == 1 ? "" : string(" (at: ", join([place(x.context.cell) for x in rows if x.context isa NamedTuple && haskey(x.context, :cell) && haskey(x.context, :statements) && x.context.statements == sts], ", "), ")"))
                end
            end
            for ac in unique(x.context.alterant_context for x in rows if x.context isa NamedTuple && haskey(x.context, :alterant_context))
                println(io, "   context: ", repr(ac))
            end
            ## every other key of the context — a read-time row's `level` and `statement`, the Labels Alterant's `file` and `change`, a custom
            ## Alterant's own keys — printed as data, each distinct value of the group once (the tools know no Alterant's keys)
            for k in keys(ctx)
                k in (:label, :cell, :stated_by, :statements, :alterant_context) && continue
                for v in unique(getfield(x.context, k) for x in rows if x.context isa NamedTuple && haskey(x.context, k))
                    println(io, "   ", k, ": ", repr(v))
                end
            end
        elseif ctx !== nothing
            for c in unique(x.context for x in rows)
                println(io, "   context: ", repr(c))
            end
        end
    end
    println(io, length(r.diagnostics), " diagnostic row(s) in ", length(order), " group(s)")
    return nothing
end

const _DT_VERBS = ("tree", "segments", "evals", "render", "trace", "evals-tree", "bls-tree", "comparison")

function _dt_cli_usage()
    println(stderr, "usage: devtools.jl <", join(_DT_VERBS, "|"), "> <file> [profile]   — [profile]: the user level's profile text, optional (since 0.4.3)")
    exit(2)
end

_dt_cli_grain_name(g) = g == 0x01 ? "Segment" : g == 0x0a ? "Line" : g == 0x46 ? "Block" :
                        g == 0xd2 ? "File" : g == 0xe0 ? "USER_CONTEXT" : ""
_dt_cli_store_name(s) = s == 0x01 ? "direct" : s == 0x02 ? "insert" : s == 0x00 ? "TRUNCATED" : "?"
_dt_cli_fmt_steps(v) = "[" * join(["($(_dt_cli_store_name(s)),$(Int(o)))" for (s, o) in v], " ") * "]"

function _dt_cli_main(args)
    length(args) in (2, 3) || _dt_cli_usage()
    cmd, path = args[1], args[2]
    profile = length(args) == 3 ? args[3] : nothing   # the user level's profile text (since 0.4.3): fed as `GoMetaConfig(user_mh_profile = …)`
    cmd in _DT_VERBS || _dt_cli_usage()
    isfile(path) || (println(stderr, "devtools: no such file: ", path); exit(2))

    r = GoMeta.goMeta(read(path); config = GoMeta.GoMetaConfig(user_mh_profile = profile))
    println(stderr, "status: ", r.status)
    print_diagnostics(stderr, r; name = basename(path))   # the end-of-run print: the rows folded, the places decoded

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
        doc = _dt_doc(r; name = basename(path))                 # the rows resolved to their Components (§C); the excerpt through the door
        rows = _dt_eval_rows(doc)
        isempty(rows) && println(stderr, "(no evals rows — no Alterant value recorded on any surface)")
        for row in rows
            cell = replace(row.comp === nothing ? "" : _dt_content(doc, row.comp), '\n' => '⏎')   # a row the tools cannot place (no Component): no piece in the tree — none produced by a shipped path since 0.4.0
            println(rpad(String(row.attr), 14), " => ", rpad(repr(row.value), 40), " (", row.polarity, ")  \"",
                    first(cell, 60), length(cell) > 60 ? "…\"" : "\"")
        end
    elseif cmd == "comparison"
        ## the comparison form (§I): the header names the input, the producing commit unknown here (`-`)
        print(comparisonForm(r; name = basename(path), at = "-"))
    elseif cmd == "evals-tree"
        ## the print tool's FULL delivery view: every Component visible,
        ## absence labelled "(no evals — defaults apply)", every row with its decoded handle
        print_altValues_evals(stdout, r; layout = :tree, include_empty = true,
                              show_handles = true, _name = basename(path))
    elseif cmd == "bls-tree"
        ## the tree printer (:mix): tree rows + typed named-int / settribute dumps
        print_BLS_Component_Tree(stdout, r; style = :mix, _name = basename(path))
    elseif cmd == "trace"
        doc = _dt_doc(r; name = basename(path))                 # the rows resolved to their Components (§C); the excerpt through the door
        rows = _dt_eval_rows(doc)
        isempty(rows) && println(stderr, "(no evals rows — no Alterant value recorded on any surface)")
        for row in rows
            cell = replace(row.comp === nothing ? "" : _dt_content(doc, row.comp), '\n' => '⏎')   # a row the tools cannot place (no Component): no piece in the tree — none produced by a shipped path since 0.4.0
            println(rpad(String(row.attr), 14), " => ", rpad(repr(row.value), 40), " (", row.polarity, ")  \"",
                    first(cell, 60), length(cell) > 60 ? "…\"" : "\"")
            d = decode_handle(row.handle)
            if d === nothing
                println("    handle: UNDECODED (schema != 0x01) — the excerpt above is the only locator")
                continue
            end
            g = _dt_cli_grain_name(d.grain)
            trunc = any(s -> s[1] == 0x00, d.path) || any(s -> s[1] == 0x00, d.origin)
            println("    handle: ns=:", d.namespace, "  grain=0x", string(d.grain, base = 16, pad = 2),
                    isempty(g) ? "" : " ($g)", "  path=", _dt_cli_fmt_steps(d.path),
                    trunc ? "  !! TRUNCATED step — degenerate walk !!" : "")
            println("    origin: ", isempty(d.origin) ? "[] — the key addresses the cell itself" :
                    _dt_cli_fmt_steps(d.origin) * " — Segment-carried remap")
        end
    end
    exit(r.status == GoMeta.PROCESS_OK ? 0 : 1)
end

if abspath(PROGRAM_FILE) == @__FILE__
    _dt_cli_main(ARGS)
end
