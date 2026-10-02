# devtools.jl — the GoMeta developer print tools.
#   (2026-08-29, owner ruling R-V04B-17) This file lives in the GoMeta code home,
#   GoMetaEcosystem/GoMeta/devtools/; the Play keeps its own FROZEN COPY since 2026-09-12
#   (OWNER-WORDS §26 — a self-contained fork). Run under the project whose GoMeta you want
#   to print: `--project=GoMetaEcosystem/GoMeta/tests` = the v0.4 build. A DEVELOPMENT TOOL:
#   not part of the GoMeta process — the package never references this file. Docs: README.md
#   beside it; the canon AGENT-RULES_GoMeta.md §R4b.
#
# IS:   the two owner-ruled development printers for a `goMeta` result —
#         `print_BLS_Component_Tree`  (the BLS Component tree with every component's
#                                      settribute state; restores the February
#                                      `printComponentStates` capability, superseding it)
#         `print_altValues_evals`     (the evals rows placed IN the component tree /
#                                      as rows / as per-cell dossiers)
#       plus their file twins (`write_*_to_file`), the three surface writers (the tool's pair + the marked source),
#       the comparison form's producer and writer `comparisonForm` / `writeComparisonFormToFile` (§I — stage 4, R-V04B-36),
#         `writeBlsStructureToFile` / `writeRenderToFile` / `writeMarkedSourceToFile`
#         (§H — verbatim surface copies + the slide sidecar), and `devtools_selfcheck()`.
#       Every tool takes the §H `slide` keyword: print tools render the truecolor ANSI
#       slide preview; file tools additionally emit the `X.slideruns.json` colored-run
#       sidecar under one of the four SCHEMES.json schemes.
# DOES: renders — from the BLS component data of ONE `goMeta(bytes)` result, and only
#       as deep as the selected style/detail/filters ask —
#       (canon R1 — never re-derived from raw text): the guarded engine-true Block
#       census (the door's `children` of the File root — the legacy `2:numChildren+1` census is
#       extension-unsafe), per-component named-int + settribute dumps, and the
#       probe-proven cell_handle → Component resolution (design §1, 27/27) with the §6
#       defensive contract (root-anchor + parent-link + grain↔leaf + namespace checks;
#       unanchored rows rendered, never dropped; a row's text through the door's `BLS.content`).
# REASONING: the released v0.3.0 package deliberately ships no debug printer (e1c
#       strip) and the run's WORKING state is not delivered at all (R-V04B-28; 0.3.x delivered it as a field) — so the dev tools live PLAY-SIDE, on a
#       session-writable surface, honestly labeled (see the exemption below), instead
#       of re-entering the engine through the release pipeline. Package-proper
#       restoration is a friction-ledger motion (F-LED-16..19), never code from here.
# PURPOSE: let the owner SEE, at any moment of play, exactly what the engine built
#       (structure + settributes) and exactly which altValues_evals row landed on
#       which Component — including the metaSegment that caused it — in the terminal
#       (colored) or as .html / .txt files.
#
# ── The tree through THE DOOR (stage 2's commit 0; R-V04B-58, R-V04B-80) ─────────────────────
# These tools read `result.blsComponentTree` through BLS's public functions and types ONLY —
# `GoMeta.BLS.root` / `children` (the walk), `getElement` (every flag and position, by key, over a
# Component), `content` (the verbatim bytes at a Component's grain), `kind` (the flavor word),
# `flavor` (the record; five fields promised), `endsWithNewline`, `isHorizontalSpace` (the lexer's
# delimiter), the Component types and `keys` of the two named-element types (docs/public-api.md §1.2) —
# and no field of a BLS object. ONE RESIDUE read outside the door remains, marked at its site and
# asked for his word: the whole-document text of the File (`collectedLines` joined — `content` has no
# File arm, a question its docstring names); the slide classifier's source-line COUNT comes from the callers' own
# bytes since stage 2's commit 9b (R-V04B-85 (D)). The former exemption D-6(a) of 2026-08-20 covers that one
# residue alone now. Consumer code — an Extension — reads the tree the same way, through the door
# (docs/public-api.md §1.2; R-V04B-45).
# `devtools_selfcheck()` is the drift alarm: run it after every change under `src/` — a broken surface fails LOUDLY.
#
# ── Use ─────────────────────────────────────────────────────────────────────────────────
#   julia> include("run_play.jl")           # or directly: include("devtools.jl")
#   julia> result = goMeta(read("InFileFolder/some.jl"))
#   julia> print_BLS_Component_Tree(result)
#   julia> print_altValues_evals(result)
#   julia> write_altValues_evals_to_file("evals.html", result)
#   julia> print_BLS_Component_Tree(result; slide = :gometa_dark)      # slide preview
#   julia> writeRenderToFile("render.jl", result; slide = :gometa_dark) # + sidecar
#   (iterating on this file itself: `using Revise; includet("devtools.jl")` — a plain
#    include is not Revise-tracked.)
#
# ── Non-goals + recorded deviations ─────────────────────────────────────────────────────
# - No benchmarks: interactive dev printers carry no performance contract (the
#   documented decision — design §2 ¶No-benchmarks).
# - Excerpt quote-escaping (CrossReview T1-L2 #3) is DEFERRED: the owner ruled on the
#   rendered look with raw embedded quotes; only control bytes / invalid UTF-8 are
#   escaped (safety). `""` still renders zero-length content.
# - Non-ASCII typography in PLAIN sinks: Block spans use an en-dash (`L35–L49`) and
#   the reserved polarity marker a typographic minus (`(−)`, dead at v0) — byte-pinned
#   to the owner-approved mockups; grep with the literal characters (or `grep -P`).
# - Unanchored rows render their reason, a non-native namespace, and (for
#   non-document grains) their path ordinal; `show_handles` prints the full decoded
#   handle for them too (§6).
# - `detail` validation is STRICTER than a pure conflict rule: any explicit value for
#   a non-:tree style errors, even one naming the style's inherent detail — inherent
#   details are only ever selected via :auto (no silent no-op, no lookalike accept).
# - Excerpts truncate incrementally OUTPUT-side; the cell's content String is still
#   materialized input-side (bounded by one cell) — accepted for v1.
# - The extension-chain presence marker detects Block-grain `idExtension` in `:mix`
#   only (Line/File-capacity chains + the `:tree`/`:full` style stay unmarked);
#   physical extension-node rendering is deferred — no chain is mintable at play sizes.
# - Explicit per-Alterant DEFAULT values do not exist in the engine (R-DEV-6 →
#   friction-ledger row F-LED-20, GoMeta v0.4); absence renders as
#   "(no evals — defaults apply)" without asserting a value.
# - §H `slide` option (owner order 2026-08-20): print tools REPLACE their output with
#   the ANSI preview when `slide` is set (BRIEF §4.1's on-arm is re-encoded as the
#   battery's strip-assertion); the sidecar `roles` header = run_colors ∪
#   {"blank": payload} (the only reading satisfying BRIEF §2.3 + §2.5); .html twins'
#   sidecars describe the PLAIN view; sidecar styles are role-derived ONLY (§2.4 —
#   emitter bold is not carried); structure sidecars say border "tree" (the BRIEF §2
#   example's "usual" is a recorded erratum). Full ledger:
#   plan/2026-08-20-devtools-slide-output/DESIGN_slide-option.md §5.
# - Owner fix-orders 2026-08-21: structure-view slide runs are REFERENCE-TRUE
#   (scaffold=tree + §2.6 interiors, mirrored + byte-verified, whole-line-tree
#   fallback — DESIGN §5-bis.15) and the :mix/:tree dump rows carry parent→first-
#   child RAILS (│ at the child connector column; §5-bis.16; evals ● view
#   deliberately NOT extended — the ● occupies that column).
#
# Design + review record: plan/2026-08-19-gometa-dev-print-tools/DESIGN_dev-print-tools.md
# Slide option design record: plan/2026-08-20-devtools-slide-output/DESIGN_slide-option.md
# (§0 owner rulings R-DEV-1..8; §6 the binding contract; §8 the full review chain).
# Canon: GoMetaEcosystem/agent-doc/AGENT-RULES_GoMeta.md.

import GoMeta
include(joinpath(@__DIR__, "load_basic_renderer.jl"))   # the ONE path to the basic renderer (R-V04B-24 obligation 7)
const _DT_BLS = GoMeta.BLS

#########################################################################################
##  §A — palette + styled emission
#########################################################################################

## THE COMPUTED PALETTE (R-DEV-10, owner-directed research round 2026-08-20).
## IS: every identity-bearing color as a FIXED xterm-256 index (never theme-remapped,
##   never bold-as-bright-promoted — both mechanisms touch only base-16; probe-proven).
## DOES: passes the computed gates of the dataviz color method (Machado-2009 CVD
##   simulation, OKLab ΔE×100) over THIS tool's actual adjacency pairs (grain↔flavor,
##   flavor↔attr, attr↔value, grain↔grain, flavor↔flavor): min NORMAL ΔE 16.1 (floor
##   15), min CVD ΔE 9.9 (target 8); every color ≥3:1 on #1e2127 and ≥ΔE15 from chrome
##   AND default fg. Verified by eye on rendered output (normal + deutan-simulated).
## REASONING: three hand-picked rounds (R-DEV-7/8/9/9b/9c) each fixed one collision
##   and created another — base-16 theme remapping (bold :yellow → the owner's amber)
##   plus hue-family crowding made eyeballing unreliable; the assignment is COMPUTED
##   (optimizer + evidence banked in the plan dir) and the render was LOOKED AT.
## PURPOSE: every role nameable by color alone, for full-color AND red-green-deficient
##   vision, on any dark-background terminal/theme. Re-tint = one index, then re-run
##   the banked scorer (plan dir: score_roles.mjs) + probe 7b.
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
    220 => "#ffd700", 203 => "#ff5f5f", 245 => "#8a8a8a")   # R-DEV-10 computed palette

_dt_htmlesc(s) = replace(s, '&' => "&amp;", '<' => "&lt;", '>' => "&gt;")

## IS: the ONE styled-run emitter every renderer uses. DOES: routes a flat run to the
## slide-capture recorder (IOContext key :gm_sliderec, checked FIRST — plain bytes
## into the capture buffer + a byte-offset role span, §H), to the HTML sink
## (IOContext key :gm_html), to `printstyled` (only when the io carries
## :color=>true AND the run is actually styled), or to plain `print` — so plain runs
## emit ZERO escape bytes. REASONING: printstyled closers reset to terminal defaults,
## so runs are FLAT, never nested; `:normal`-unbold runs bypass printstyled entirely
## (ANSI hygiene). PURPOSE: one source of truth for terminal/plain/HTML/slide parity.
function _dt_sty(io, txt; color = nothing, bold::Bool = false)
    s = string(txt)
    cap = get(io, :gm_sliderec, nothing)
    if cap isa _DTSlideCap && _dt_slide_sink(io) === cap.buf
        ## slide-capture arm (§H, "Design B′"): the capture context is colorless by
        ## construction, so this arm writes PLAIN bytes and brackets them with byte
        ## offsets + the slide role; checked FIRST so no re-wrap can ever route a
        ## captured write through printstyled (escape bytes must never enter the
        ## capture). `bold` is deliberately NOT recorded — slide styles are
        ## role-derived only (§2.4). GUARDS (review L3#4): the arm activates only
        ## for a REAL capture record whose buffer IS the io's actual sink — a
        ## foreign :gm_sliderec value (wrong type, or a cap re-wrapped over a
        ## different io) is ignored and the run renders normally, never crashes,
        ## never records false offsets.
        lo = position(cap.buf)
        print(io, s)
        push!(cap.spans, _DTSlideSpan(lo, position(cap.buf), _dt_slide_role_of(color)))
        return
    end
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
## pictograph labels like `label_🍻` (probe-proven); this pads to WIDTH.
_dt_tpad(s, w) = s * ' '^max(0, w - textwidth(s))

## IS: the bounded excerpt maker. DOES: flattens in-cell newlines to '⏎' (the R4-CLI
## convention), escapes every OTHER control byte as ⟨0xNN⟩ (the terminal-forging class:
## \r, ESC, backspace…), renders malformed UTF-8 chars as per-char byte-hex ⟨0x…⟩
## (BYTE IDENTITY kept — the `!isvalid(c)` arm intercepts them on Julia 1.12.5), and
## truncates the OUTPUT incrementally at display width `maxw`. The byte-hex `catch` is
## a RESIDUAL belt for invalid-UTF-8 throw classes a future Julia might reintroduce —
## on 1.12.5 the char loop is total, so the fallback is defensively dead. REASONING:
## §6 excerpt-safety contract; the printer must survive every input the byte-faithful
## engine accepts.
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
##  §B — guarded tree access
#########################################################################################

## The door's walk (`BLS.children`) resolves the insert store's negative ids itself (owner ruling D-15's
## concern — the legacy printer's sign-blind mis-indexing — cannot recur: no id is indexed here).
## The Components of one grain in source order; `_dt_id` the Component's own id (the printed `#N`).
_dt_children(doc, c) = _DT_BLS.children(doc.ps, c)
_dt_id(c) = Int(_dt_ni(c, :idComponent))

## IS: the check of USER-SUPPLIED Block ids (`blocks=` requests). DOES: enforces membership in the
## File root's logical Block census (the ids of the Blocks the door's walk yields — the walk covers
## dummy-at-1, bounds and self-id). Returns `(valid_blocks, invalid_ids)` — the valid ids as their
## Block Components, in the request's order. PURPOSE: §6 — invalid requests are REPORTED, never
## silently rendered or crashed on.
function _dt_check_blocks(requested, blocks)
    byid = Dict(_dt_id(b) => b for b in blocks)
    valid = Any[]; invalid = Any[]
    for id in requested
        if !(id isa Bool) && id isa Integer && 1 <= id <= typemax(Int) && haskey(byid, Int(id))
            push!(valid, byid[Int(id)])
        else
            push!(invalid, id)
        end
    end
    (valid, invalid)
end

"""
IS: the per-call render context — one `goMeta` result opened for printing.
DOES: carries the result, its delivered tree (`blsComponentTree`), the ENGINE-TRUE Block census as
the Block Components the door's walk yields (`BLS.children` of the tree: the basic renderer's form,
devtools/basic_renderer.jl — the legacy `2:numChildren+1` census breaks on extension chains), and the
display name.
GUARDED: a damaged/absent File root yields an EMPTY census (`ok=false`) instead of a
throw — status/diagnostics always print first (§6 status-first law).
"""
struct DTDoc
    r::Any
    ps::Any
    blocks::Vector{Any}
    name::String
    ok::Bool
    ns::String      # THIS delivery's occurrence-key namespace, read off its own rows (the
                    # configuration is not delivered — R-V04B-28); rows anchor against it (a
                    # namespace=:other run's own rows anchor; only a row FOREIGN to the delivery
                    # stays unanchored)
end
## THIS delivery's occurrence-key namespace, read off its own rows — the configuration is not a part of the
## delivered object (R-V04B-28: four parts and nothing else); the first row's decoded key names it; a delivery
## with no rows anchors nothing ("?"). One run mints every key with one namespace, so the `:foreign_namespace`
## arm below now compares each row against the FIRST row's — an internal-consistency check on the store. What it
## can no longer catch is a store whose rows UNIFORMLY carry a namespace other than the run's configuration:
## the configuration is not delivered, so nothing in the delivery names it. And if the FIRST row's key does not
## decode, `ns` is "?": every decoded row of a DOCUMENT grain whose namespace is not itself "?" then lands in
## that arm (a decoded non-document grain still lands in `:non_document_grain` first, as ever; a row whose
## decoded namespace IS "?" passes), and the undecoded rows — their own `ns` "?" too — print no `ns=:?` suffix:
## a malformed store only (an ordinary run's rows all decode), a schema-drift case
## the self-check's anchoring pin catches.
function _dt_ns_of(result)
    recs = result.altValues_evals.records
    isempty(recs) && return "?"
    d = _dt_decode(recs[1].cell_handle)
    return d === nothing ? "?" : String(d.namespace)
end

function _dt_doc(result; name::AbstractString = "")
    # EVERY read guarded (§6 status-first: the caller prints status BEFORE this runs, and a
    # drifted/partial delivery must yield ok=false, not a throw). The door's `root` and `children`
    # throw on a damaged tree (BoundsError / UndefRefError) — caught here into ok=false.
    ps, blocks, ok, ns = try
        ps = result.blsComponentTree
        ns = _dt_ns_of(result)
        _DT_BLS.root(ps)
        (ps, Any[b for b in _DT_BLS.children(ps)], true, ns)
    catch
        (nothing, Any[], false, "?")
    end
    DTDoc(result, ps, blocks, String(name), ok, ns)
end

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
## File arm: the door's `content` has NO File arm (a question its docstring names for his word) — the
## whole-document content is the joined collectedLines (§6 layout-totality clause). RESIDUE outside the
## door (stage 2's commit 0; his word asked). The other grains: `BLS.content` (the former Engine call
## `cell_content_bytes`, byte-equal by construction of the copy).
_dt_content(doc, c) = c isa _DT_BLS.File ? join(doc.ps.collectedLines, '\n') :
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
## File-anchored row intersects every lines= range — never hidden by a line filter (§6).
_dt_intersects(c, r) = r === nothing || c isa _DT_BLS.File ||
    !isempty(intersect(_dt_spanrange(c), r))

## Guarded census walk through the door (`children` at each grain).
function _dt_census(doc)
    doc.ok || return (0, 0, 0)     # damaged tree: never walk it (§6)
    nl = 0; ns = 0
    for b in doc.blocks, l in _dt_children(doc, b)
        nl += 1
        ns += length(_dt_children(doc, l))
    end
    (length(doc.blocks), nl, ns)
end

_dt_plural(n, w) = "$n $w" * (n == 1 ? "" : "s")

## §6 status-first law, HARD form (impl CrossReview T1-L3 #1): the entry points call
## _dt_status_result — which reads ONLY the stable `result` fields — BEFORE any
## parse-tree access, so a drifted/partial internal surface can never throw ahead of
## the diagnostics; _dt_status_tree reports a damaged tree AFTER guarded construction.
## A debug tool must not refuse exactly when debugging is needed.
function _dt_status_result(io, result)
    result.status == GoMeta.PROCESS_OK && return
    _dt_sty(io, "status: $(result.status)\n", color = _DT_C_BAD, bold = true)
    for d in result.diagnostics
        _dt_sty(io, "  diagnostic: $(d.code) ($(d.severity)) $(d.message)\n", color = _DT_C_BAD)
    end
end
_dt_status_tree(io, doc) = doc.ok ||
    _dt_sty(io, "(no parse tree — the File root is absent or damaged)\n",
            color = _DT_C_BAD, bold = true)

#########################################################################################
##  §C — cell_handle decode + resolution (the §6 resolver contract)
#########################################################################################
## Layout (src/occurrence.jl docblock; probe-proven 27/27 — design §1): schema 0x01 ·
## namespace (u16-BE length + UTF-8) · grain byte · path steps (store byte + u32-BE
## GLOBAL-store-index ordinal = abs(idComponent)) · origin steps (same shape).
## NOTE: this decode duplicates what F-LED-1 wants public (`GoMeta.decode_handle`) —
## retire it when the engine ships the accessor.

_dt_u16(b, i) = (UInt16(b[i]) << 8) | UInt16(b[i+1])
_dt_u32(b, i) = (UInt32(b[i]) << 24) | (UInt32(b[i+1]) << 16) | (UInt32(b[i+2]) << 8) | UInt32(b[i+3])
function _dt_steps(b, i)
    n = Int(_dt_u16(b, i)); i += 2
    v = Tuple{UInt8,UInt32}[]
    for _ in 1:n
        push!(v, (b[i], _dt_u32(b, i + 1))); i += 5
    end
    return v, i
end

## IS: the schema-gated handle decoder. DOES: rejects (→ `nothing`) on any of: schema
## byte ≠ 0x01, short/truncated bytes (BoundsError caught), TRAILING GARBAGE (the whole
## byte vector must be consumed), invalid-UTF-8 namespace. REASONING: §6 — a handle
## that does not decode CLEANLY renders as unanchored; it must never half-decode into a
## wrong anchor.
function _dt_decode(b::Vector{UInt8})
    (isempty(b) || b[1] != 0x01) && return nothing
    try
        i = 2
        nslen = Int(_dt_u16(b, i)); i += 2
        nsb = b[i:i+nslen-1]; i += nslen
        isvalid(String, nsb) || return nothing
        ns = String(nsb)
        grain = b[i]; i += 1
        path, i = _dt_steps(b, i)
        origin, i = _dt_steps(b, i)
        i == length(b) + 1 || return nothing
        return (; namespace = ns, grain, path, origin)
    catch e
        e isa BoundsError && return nothing
        rethrow()
    end
end

_dt_grainname(g) = g == 0x01 ? "Segment" : g == 0x0a ? "Line" : g == 0x46 ? "Block" :
                   g == 0xd2 ? "File" : g == 0xe0 ? "USER_CONTEXT" :
                   "grain-0x" * string(g, base = 16)
const _DT_LADDER = (_DT_BLS.File, _DT_BLS.Block, _DT_BLS.Line, _DT_BLS.Segment)
_dt_graintype(g) = g == 0x01 ? _DT_BLS.Segment : g == 0x0a ? _DT_BLS.Line :
                   g == 0x46 ? _DT_BLS.Block : g == 0xd2 ? _DT_BLS.File : nothing

## IS: the defensive path resolver, through the door. DOES (§6 contract, each violation ⇒ `nothing` =
## unanchored, NEVER a wrong anchor): ladder-length gate · `path[1] == (direct, 1)` = the File root
## anchor · per step: direct-store byte only (0x00 TRUNCATED / 0x02 insert / unknown reject — the v0
## engine cannot mint 0x02: occurrence keys read the POSITIVE idComponent, the engine-side identity
## gap of ledger motion (v)) · the step's ordinal must name a LOGICAL child of the previous step's
## Component: the door's `children` walks each Component's extension chain and yields the chain's
## children flattened (occurrence keys normalize extension components to their chain root — impl
## CrossReview T2-L1 #1), so a child found among `children(parent)` has that parent as its logical
## parent, and a chain root alone carries `idExtended == 0` (handles name chain ROOTS only) · the
## grain of the found Component is the ladder's. A damaged tree throws out of the door's walk and
## resolves to unanchored, never a wrong anchor.
function _dt_resolve(doc, steps)
    (isempty(steps) || length(steps) > length(_DT_LADDER)) && return nothing
    steps[1] == (0x01, UInt32(1)) || return nothing
    doc.ps === nothing && return nothing
    try
        comp = nothing
        for (j, (store, ord)) in enumerate(steps)
            store == 0x01 || return nothing
            if j == 1
                comp = _DT_BLS.root(doc.ps)
                _dt_id(comp) == Int(ord) || return nothing
            else
                kids = _dt_children(doc, comp)
                k = findfirst(c -> _dt_id(c) == Int(ord), kids)
                k === nothing && return nothing
                comp = kids[k]
            end
            comp isa _DT_LADDER[j] || return nothing
            Int(_dt_ni(comp, :idExtended)) == 0 || return nothing   # handles name chain ROOTS only
        end
        return comp
    catch e   # damaged parse surfaces resolve to unanchored, never crash mid-diagnosis
        e isa Union{KeyError, BoundsError, UndefRefError} && return nothing
        rethrow()
    end
end

"""
IS: one evals row, resolved for rendering.
DOES: carries the evals row (`attr`, `value`, `polarity` — polarity is constant `true`
at v0, a reserved field, so it renders DIM), the resolved target Component (`comp`;
`nothing` = unanchored), the origin metaSegment with its VERIFICATION state
(`origin_status` ∈ `:none` — no origin steps (or an undecodable handle) ·
`:unverifiable` — the row is UNANCHORED yet carries origin steps: verification is
defined only against THIS document's tree, so the origin is never resolved locally
(no false provenance) and a dim marker renders instead · `:verified` —
`origin[1:end-1] == path` AND the leaf is a Meta-flavor Segment · `:failed` — present
on an ANCHORED row but failing verification, rendered as a warning, never silently
dropped), the decoded grain
byte + namespace (the per-row fingerprint self-check left with the Engine's stored copy at stage 2's
commit 9b, R-V04B-43 (1) — a row's text is the door's `BLS.content` of its resolved Component), and the retained
UNANCHORED REASON (`reason` ∈ `:ok` anchored · `:undecoded` schema/short/garbage/
bad-ns bytes · `:non_document_grain` the 0xd3–0xfe plane incl. USER_CONTEXT ·
`:foreign_namespace` · `:unknown_grain` an unrecognized byte ≤ 0xd2 ·
`:unresolved_path` any resolver-gate failure incl. grain↔leaf disagreement —
rendered dim in the unanchored section, §6).
"""
struct DTEvalRow
    attr::Symbol
    value::Any
    polarity::Bool
    comp::Any
    origin::Any
    origin_status::Symbol
    handle::Vector{UInt8}      # the raw occurrence-handle bytes — row identity, cell
                               # grouping/counting, decode + optional display source
    grain::UInt8
    ns::String
    path::Vector{Tuple{UInt8,UInt32}}   # decoded path steps (empty when undecoded) —
                               # distinguishes e.g. USER_CONTEXT feeds by ordinal
    origin_steps::Vector{Tuple{UInt8,UInt32}}
    reason::Symbol
end

## IS: the row builder. DOES: decodes + resolves EVERY `altValues_evals` row, applying
## the §6 gates — the non-document grain PLANE (byte > 0xd2, incl. USER_CONTEXT 0xe0)
## never walks the ladder; a namespace differing from this delivery's own (`doc.ns`, read
## off its first row — the configuration is not delivered, R-V04B-28) never resolves against
## THIS document's tree (it stays unanchored WITH its namespace shown); the
## decoded grain
## must equal the resolved leaf's type; the origin is verified or flagged. PURPOSE:
## layout totality — every row reaches a renderer, anchored or not.
function _dt_eval_rows(doc)
    rows = DTEvalRow[]
    nosteps = Tuple{UInt8,UInt32}[]
    for (h, attr, v, pol) in GoMeta.readAltValuesEvals(doc.r.altValues_evals)
        d = _dt_decode(h)
        if !doc.ok           # damaged/absent tree: rows render unanchored, honestly
            dd = d === nothing ? nothing : d
            push!(rows, DTEvalRow(attr, v, pol, nothing, nothing,
                                  dd === nothing || isempty(dd.origin) ? :none : :unverifiable,
                                  h, dd === nothing ? 0x00 : dd.grain,
                                  dd === nothing ? "?" : dd.namespace,
                                  dd === nothing ? nosteps : dd.path,
                                  dd === nothing ? nosteps : dd.origin, :no_parse_tree))
            continue
        end
        if d === nothing
            push!(rows, DTEvalRow(attr, v, pol, nothing, nothing, :none, h, 0x00, "?",
                                  nosteps, nosteps, :undecoded))
            continue
        end
        gt = _dt_graintype(d.grain)
        # rows anchor against THIS delivery's namespace (doc.ns, read off its rows) — a
        # namespace=:other run's own rows are native, not foreign (impl CrossReview)
        comp, why = d.grain > 0xd2         ? (nothing, :non_document_grain) :
                    d.namespace != doc.ns  ? (nothing, :foreign_namespace) :
                    gt === nothing         ? (nothing, :unknown_grain) :       # §6: reject, never guess
                    ((c = _dt_resolve(doc, d.path);
                      c === nothing ? (nothing, :unresolved_path) :
                      !(c isa gt)   ? (nothing, :unresolved_path) :            # grain↔leaf disagreement
                      (c, :ok)))
        # ORIGIN verification is defined ONLY for rows anchored in THIS document's tree;
        # an UNANCHORED row that carries origin steps gets :unverifiable (visible dim —
        # never silently dropped, §6), with the raw steps under show_handles
        # (impl CrossReview T2-L3/T2-L1 HIGH: resolving a foreign/unanchored row's origin
        # ordinals against the local tree could mint FALSE provenance); the raw decoded
        # origin steps stay available via origin_steps/show_handles either way.
        orig = (why !== :ok && !isempty(d.origin)) ? :unverifiable : :none
        oc = nothing
        if why === :ok && !isempty(d.origin)
            oc = _dt_resolve(doc, d.origin)
            orig = (oc !== nothing && length(d.origin) == length(d.path) + 1 &&
                    d.origin[1:length(d.path)] == d.path && oc isa _DT_BLS.Segment &&
                    _dt_flavor(oc) == "Meta") ? :verified : :failed
            orig == :failed && (oc = nothing)
        end
        push!(rows, DTEvalRow(attr, v, pol, comp, oc, orig, h, d.grain, d.namespace,
                              d.path, d.origin, why))
    end
    rows
end

_dt_akey(c) = (typeof(c), Int(_dt_ni(c, :idComponent)))
## (the tree attachment map — incl. the Segment→owning-Line remap and the File split —
## is built INLINE in _dt_t2_tree; keeping a second generic builder here proved a
## dead-surface hazard and was removed at the impl reconfirm)
_dt_unanchored(rows) = [r for r in rows if r.comp === nothing]

## visib values carry semantic colors; every other attr's value prints neutral-BOLD —
## polarity is constant true at v0, so a polarity-driven color would be constant fake
## signal (CrossReview-verified against annotations.jl:188).
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
    row.origin_status == :failed &&
        _dt_sty(io, "  ⚠ origin unverified", color = _DT_C_BAD, bold = true)
    println(io)
end

function _dt_print_unanchored(io, doc, rows; show_handles::Bool = false)
    isempty(rows) && return
    _dt_sty(io, "\nunanchored rows (no document tree position):\n", color = _DT_C_BAD, bold = true)
    for row in rows
        # non-document-plane rows carry their first path ordinal (e.g. USER_CONTEXT #1)
        # so distinct feeds stay distinguishable (impl CrossReview T2-L3/T2-L1)
        ordtag = (row.grain > 0xd2 && !isempty(row.path)) ? " #$(Int(row.path[1][2]))" : ""
        _dt_sty(io, "  [" * _dt_grainname(row.grain) * ordtag *
                    (row.ns == doc.ns ? "" : "  ns=:$(row.ns)") * "]  ", color = _DT_C_BAD)
        _dt_sty(io, _dt_tpad(string(row.attr), 12), color = _DT_C_ATTR, bold = true)
        _dt_sty(io, " => ")
        _dt_sty(io, repr(row.value), color = _dt_vcolor(row), bold = true)
        _dt_sty(io, row.polarity ? "  (+)" : "  (−)", color = _DT_C_CHROME)
        row.reason != :ok && _dt_sty(io, "  ($(row.reason))", color = _DT_C_CHROME)   # §6: reason rendered
        row.origin_status == :failed &&
            _dt_sty(io, "  ⚠ origin unverified", color = _DT_C_BAD, bold = true)
        row.origin_status == :unverifiable &&
            _dt_sty(io, "  (origin unverifiable — row unanchored)", color = _DT_C_CHROME)
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

Print the BLS Component tree of one `goMeta` result — every Block/Line/Segment with
its named-int record and TRUE settribute flags, hierarchically. The restored-and-
superseding successor of the February `GoMeta.BLS.printComponentStates()` (owner
ruling R-DEV-2; existing script call sites need a one-line edit to this form).

METHOD DISPATCH — which call form triggers what:
- `(io, result)` — the CORE method (Julia print convention): renders into `io` exactly
  as configured; every other method funnels here.
- `(result)` — REPL convenience: identical, `io = stdout` (colors auto-resolve from
  the terminal).
- `write_BLS_Component_Tree_to_file(path, result)` — opens `path`, renders, closes.
  `format = :auto` infers from the extension (`.html` ⇒ the self-contained HTML page,
  anything else ⇒ text); `:html` / `:txt` override the inference. Text files default
  `color = :never` (plain, grep-friendly); pass `color = :always` to write ANSI bytes
  (view with `less -R`). The HTML sink is ALWAYS styled — `color` does not apply to it.

PARAMETERS (each names the METHOD BEHAVIOR it selects):
- `color::Symbol = :auto` — `:auto` passes the io's own `:color` property through
  (a deliberate `IOContext(io, :color=>true)` is honored; `stdout` resolves from the
  tty and `--color=yes`/`FORCE_COLOR`/`NO_COLOR`); `:always`/`:never` WRAP the io via
  `IOContext(io, :color => true/false)`.
- `style::Symbol = :mix` — selects the renderer:
  `:mix`    (owner-ruled default, R-DEV-1): guide-line tree; under EACH component two
            dump lines labeled by the REAL element types (`Int64` named-int pairs,
            `Bool` TRUE-flag names; values in default fg — R-DEV-7); a blank line
            between Blocks; every string printed ONLY at the component that CONTAINS
            it (a Line with Segments shows no excerpt — its Segments do; Blocks never).
  `:legacy` — the February look (banners, `key=>1` yellow dumps, frozen header
            without the old `@L/@F` self-location — D-14) on the sound census.
  `:tree`   — the compact baseline: one line per component, TRUE flags inline;
            `detail=:full` appends the typed dump pair per component.
  `:banner` — `##`-chromed banners + source text + one-line `ints`/`flags` dumps.
- `detail::Symbol = :auto` — resolution table. The rule is strict: ANY explicit value
  for a non-`:tree` style ERRORS — even one naming the style's inherent detail — so a
  detail request can never silently no-op; inherent details are selected only via
  `:auto`. `:mix` ⇒ inherent (the typed dump lines ARE its detail) · `:legacy` ⇒
  inherent full · `:banner` ⇒ inherent (its co-located dumps) · `:tree` ⇒
  `:auto`→`:compact`; explicit `:compact`/`:full` valid — `:full` keeps the `:tree`
  rows (inline flags + every content string) and APPENDS the typed dump pair under
  each component.
- `blocks = :all` — or a `Vector{Int}` of Block ids (the legacy Block-subset
  precedent). Ids are CHECKED against the engine census; invalid ids are reported in
  red and skipped, never guessed at.
- `lines = nothing` — an input-line range (e.g. `5:12`): a component renders iff its
  input-line span INTERSECTS the range; a partially-overlapping Block keeps its full
  span label while its children clip to the range.
- `grain::Symbol = :segment` — the deepest grain printed: `:block` | `:line` |
  `:segment`. In `:mix`, a string prints at the deepest DISPLAYED owner — with
  `grain = :line` the Line shows its string even when Segments exist (they are not
  displayed; the print-once law R-DEV-1(iii) binds displayed components).
- `slide::Union{Nothing,Symbol} = nothing` — `nothing` (default): no effect, output
  byte-identical to before the option existed. A scheme Symbol (`:gometa_dark` |
  `:cvd_dark` | `:light` | `:cvd_light` (the full-CVD light variant — THE scheme
  for color-blind viewers) | `:projector`, per the embedded SCHEMES.json authority)
  REPLACES the normal paint with the ANSI slide preview of the SAME configured view
  (all view kwargs still apply): truecolor scheme colors on the scheme background +
  a synthetic line-number gutter — what the slide box will look like (§H). Requires
  `color = :auto`: an explicit `:always`/`:never` with `slide` is an ArgumentError
  (the preview replaces the very stream `color` governs — no lookalike accept, the
  `detail=` precedent). The preview always emits truecolor escape bytes, even to a
  non-tty/NO_COLOR sink — an explicit slide request IS the color consent. Unknown
  Symbol ⇒ ArgumentError naming the five supported
  values. On the write twin, `slide` instead leaves the file byte-identical and
  emits the `path * ".slideruns.json"` sidecar (border `"tree"`) describing this
  call's PLAIN view — `slide` is consumed by the twin, never forwarded; a twin
  call WITHOUT `slide` retires a stale sidecar beside the path (F5).
- `_name::AbstractString = ""` — the display name in the `File` header line (an
  internal-ish kwarg: the write twins default it to `basename(path)`; REPL calls may
  set it for a labeled header).

The two `print_BLS_Component_Tree` methods return `nothing`;
`write_BLS_Component_Tree_to_file` returns `path`. On `PROCESS_ERROR` the status +
diagnostics banner prints FIRST — read directly from the stable `result` fields,
before any parse-tree access — and rendering continues over whatever parse state
exists (§6 status-first law).
"""
function print_BLS_Component_Tree(io::IO, result::GoMeta.GoMetaDelivery;
        color::Symbol = :auto, style::Symbol = :mix, detail::Symbol = :auto,
        blocks = :all, lines = nothing, grain::Symbol = :segment,
        slide::Union{Nothing,Symbol} = nothing,
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
    if slide !== nothing
        ## §H: the ANSI slide preview REPLACES the normal paint (recorded §4.1
        ## re-encoding — the plain content is still byte-exact inside the preview's
        ## runs, battery-asserted). Validation FIRST, before any byte is written.
        color === :auto || throw(ArgumentError(
            "print_BLS_Component_Tree: slide= replaces the very stream color= governs — " *
            "pass color=:auto (got color=:$color)"))
        sid, sch = _dt_slide_resolve(slide)
        capr = _dt_slide_cap()
        print_BLS_Component_Tree(_dt_slide_capio(capr), result;
                                 color = :auto, style, detail, blocks, lines, grain, _name)
        lr, _fnl = _dt_slide_lines(capr)
        _dt_slide_preview(io, "print_BLS_Component_Tree", sid, sch, lr, "tree")
        return nothing
    end
    io = color === :auto ? io : IOContext(io, :color => (color === :always))
    _dt_status_result(io, result)          # status FIRST — before ANY parse-tree access
    doc = _dt_doc(result; name = _name)
    _dt_status_tree(io, doc)
    sel, invalid = blocks === :all ? (doc.blocks, Any[]) :
                   (doc.ok ? _dt_check_blocks(blocks, doc.blocks) :
                             (Any[], Any[]))
    for id in invalid
        _dt_sty(io, "requested Block id $(repr(id)) is not a valid File-census Block — skipped\n",
                color = _DT_C_BAD, bold = true)
    end
    if isempty(sel) && style !== :legacy   # :legacy keeps its frozen chrome (D-14);
                                           # the other styles get the File summary + reason
        nb, nl, ns2 = _dt_census(doc)
        _dt_sty(io, "File  ", bold = true); _dt_sty(io, doc.name, bold = true)
        _dt_sty(io, "  —  $nb Blocks · $nl Lines · $ns2 Segments\n", color = _DT_C_CHROME)
        _dt_sty(io, !doc.ok ? "(no Blocks — no parse tree)\n" :
                    isempty(doc.blocks) ? "(no Blocks — empty document)\n" :
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

## The typed dump pair (R-DEV-1/7): one line per element store, labeled by the REAL
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

## ── :mix (R-DEV-1) — the owner-ruled default ──────────────────────────────────────────
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
        bi > 1 && println(io)                        # R-DEV-1 (ii): blank line between Blocks
        lastb = bi == length(shown)
        row(b, lastb ? "└─ " : "├─ ", _DT_C_BLOCK, "Block")
        gB = lastb ? "   " : "│  "
        lines = grain === :block ? Any[] :
                [l for l in _dt_children(doc, b) if _dt_intersects(l, lines_r)]
        ## RAILS (owner fix-order #2 Part B, 2026-08-21): an attribute row of a
        ## component with a printed child carries │ at the first child's connector
        ## column — the parent→first-child rail is unbroken; childless stays blank
        dumplines(b, gB * (isempty(lines) ? "   " : "│  "))
        grain === :block && continue
        for (li, l) in enumerate(lines)
            lastl = li == length(lines)
            segs = grain === :line ? Any[] : _dt_children(doc, l)
            # R-DEV-1 (iii): print the string once, at the DEEPEST DISPLAYED owner — the
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

## ── :tree (plain compact — the pre-rulings B style, kept as an option; `dumps=true` =
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
        ## rails (owner fix-order #2 Part B): │ at the first child's connector column
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

## ── :legacy — the February look on the sound census (frozen header, D-14) ─────────────
function _dt_t1_legacy(io, doc, sel, lines_r, grain)
    H(n) = repeat('#', n)
    _dt_sty(io, "\n$(H(90))\n$(H(90))\n###### printComponentStates(...):\n", bold = true)
    isempty(sel) && _dt_sty(io, "\n(no Blocks)", color = _DT_C_CHROME)   # empty-file law (§3)
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

Print the `altValues_evals` rows of one `goMeta` result — each evals row placed AT its
BLS Component (which label landed WHERE, which metaSegment caused it), with the
input-line spans the raw rows lack (the F-LED-7 gap). Absence is explicit: a shown
component with no rows reads `(no evals — defaults apply)` — the engine has NO
explicit per-Alterant default surface yet (R-DEV-6 → GoMeta v0.4), so no value is
asserted.

METHOD DISPATCH — which call form triggers what: exactly as
`print_BLS_Component_Tree` (core `(io, result)`; `(result)` = stdout convenience;
the write twin infers `format` from the extension, `.html` ⇒ styled HTML page,
else text with `color = :never` default).

PARAMETERS:
- `color::Symbol = :auto` — as in `print_BLS_Component_Tree`.
- `layout::Symbol = :tree` — selects the renderer:
  `:tree`  (default): the component-tree skeleton with eval bullets attached AT their
           Components. The skeleton's NODES stop at the Line grain, and rows anchor
           accordingly: label/visib rows key on the owning Line/Block (the causing
           metaSegment rides the `← Segment #N` origin tag) — but Segment-grain rows
           DO exist (an inline metaSegment `head("…", N)` mints grain 0x01,
           probe-proven 2026-08-20) and attach to their owning Line with a dim
           `[Segment #N]` target tag; File-grain rows render at a `[File]` bullet
           under the header. Every counted row renders somewhere (§6 totality).
           Segment STRUCTURE questions belong to `print_BLS_Component_Tree`.
  `:rows`  — one line per eval, input-line span first: THE grep/census form.
  `:cells` — per-cell dossiers with the decoded handle (ns · grain · path · origin).
           Unanchored rows appear as red `### CELL (… no document tree position)`
           dossiers (this layout has no counting header and no separate section).
- `include_empty = nothing` — `:tree` ONLY; any other layout ERRORS on an explicit
  `true`/`false` (the `nothing` sentinel is HOW that is detected: unset means "the
  R-DEV-4 default `false`", so only a deliberate value can conflict with the layout).
  `false` collapses to evals-bearing subtrees with dim IN-PLACE elision rows
  (`… N Blocks/Lines (no evals)`); `true` keeps every node visible, making ABSENCE
  readable ("why did `:label1` NOT apply?"). With a filter active the absence labels
  say `(no matching evals)` — never asserting engine-level absence for filtered rows.
- `attrs = :all` — a `Symbol` or `Vector{Symbol}` filter (e.g. `:visib`,
  `[:label_label3]` — the label census). The header echoes the filter with per-attr
  match counts; a requested attr with NO rows prints an explicit
  "0 matches — :attr never minted" line, never silence.
- `lines = nothing` — an input-line range: keeps rows whose target span intersects;
  unanchored rows have no span and are NEVER hidden by `lines` (only `attrs` can);
  in `:tree` the range also acts as a FOCUS (matching targets + their ancestors stay,
  unrelated empty subtrees collapse).
- `show_handles::Bool = false` — `:cells` always shows decoded handles; `:rows`/`:tree`
  add them per row when `true`.
- `slide::Union{Nothing,Symbol} = nothing` — `nothing` (default): no effect, output
  byte-identical to before the option existed. A scheme Symbol (`:gometa_dark` |
  `:cvd_dark` | `:light` | `:cvd_light` | `:projector`) REPLACES the normal paint with the ANSI
  slide preview of the SAME configured view (all view kwargs still apply; §H).
  Requires `color = :auto` (explicit `:always`/`:never` + `slide` ⇒ ArgumentError);
  the preview always emits truecolor escape bytes, even to a non-tty/NO_COLOR sink.
  Unknown Symbol ⇒ ArgumentError naming the five supported values. On the write
  twin, `slide` instead leaves the file byte-identical and emits the
  `path * ".slideruns.json"` sidecar (border `"accent"`) describing this call's
  PLAIN view — `slide` is consumed by the twin, never forwarded; a twin call
  WITHOUT `slide` retires a stale sidecar beside the path (F5).
- `_name::AbstractString = ""` — the display name in the header line (internal-ish;
  the write twin defaults it to `basename(path)`).

The "why NOT" companion: when a label/action you expected is ABSENT here, the next
step is the canon-R4 command-line entry `devtools.jl trace <file>` (evals rows + decoded handles) and
`print_BLS_Component_Tree` (the settribute state the conditions tested).

Every row is accounted for in every layout (§6 totality): rows that do not anchor in
THIS document's tree (USER_CONTEXT feeds, foreign namespaces, undecodable handles)
are never dropped — `:rows`/`:tree` render them in a red `unanchored rows` section
(with the retained reason, and headers count them); `:cells` renders each as a red
`### CELL (… no document tree position; reason)` dossier of its own.
The two `print_altValues_evals` methods return `nothing`;
`write_altValues_evals_to_file` returns `path`.
"""
function print_altValues_evals(io::IO, result::GoMeta.GoMetaDelivery;
        color::Symbol = :auto, layout::Symbol = :tree,
        include_empty::Union{Bool,Nothing} = nothing,
        attrs = :all, lines = nothing, show_handles::Bool = false,
        slide::Union{Nothing,Symbol} = nothing,
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
    inc = include_empty === nothing ? false : include_empty      # R-DEV-4 default
    if slide !== nothing
        ## §H: the ANSI slide preview REPLACES the normal paint (recorded §4.1
        ## re-encoding); validation FIRST, before any byte is written.
        color === :auto || throw(ArgumentError(
            "print_altValues_evals: slide= replaces the very stream color= governs — " *
            "pass color=:auto (got color=:$color)"))
        sid, sch = _dt_slide_resolve(slide)
        capr = _dt_slide_cap()
        print_altValues_evals(_dt_slide_capio(capr), result;
                              color = :auto, layout, include_empty, attrs, lines,
                              show_handles, _name)
        lr, _fnl = _dt_slide_lines(capr)
        _dt_slide_preview(io, "print_altValues_evals", sid, sch, lr, "accent")
        return nothing
    end
    io = color === :auto ? io : IOContext(io, :color => (color === :always))
    _dt_status_result(io, result)          # status FIRST — before ANY parse-tree access
    doc = _dt_doc(result; name = _name)
    _dt_status_tree(io, doc)
    rows = _dt_eval_rows(doc)
    frows, echo, filtered = _dt_filter_rows(rows, attrs, lines)
    if isempty(rows)
        _dt_echo(io, echo)      # active filters echo (incl. "never minted") even here
        _dt_sty(io, "(no evals rows — no metaLine on any surface)\n", color = _DT_C_CHROME)
        return nothing
    end
    if layout === :rows
        _dt_t2_rows(io, doc, frows, rows, echo; show_handles)
    elseif layout === :tree
        _dt_t2_tree(io, doc, frows, rows, echo; include_empty = inc, lines_r = lines,
                    show_handles, filtered)
    else
        _dt_t2_cells(io, doc, frows, rows, echo)
    end
    nothing
end

"REPL convenience — `print_altValues_evals(stdout, result; kwargs...)`. See the core docstring."
print_altValues_evals(result::GoMeta.GoMetaDelivery; kwargs...) =
    print_altValues_evals(stdout, result; kwargs...)

## IS: the §4 filter contract. DOES: normalizes `attrs` (:all | Symbol | Vector),
## validates + filters BEFORE layout, keeps unanchored rows immune to `lines`, and
## returns `(filtered_rows, echo_lines)` — the echo lines carry the active filters,
## per-attr match counts and the EXPLICIT never-minted state.
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
    active &&                                            # §4: filtered/total ALWAYS echoed
        push!(echo, ("showing $(length(fr)) of $(length(rows)) rows", nothing))
    (fr, echo, active)      # `active` is THE filter flag — single source for the labels
end

function _dt_echo(io, echo)
    for (txt, kind) in echo
        _dt_sty(io, txt * "\n", color = kind === :bad ? _DT_C_BAD : _DT_C_CHROME,
                bold = kind === :bad)
    end
end

## The ONE decoded-handle formatter (impl CrossReview T2-L2 #1): namespace, grain,
## FULL path + origin steps — used by show_handles in every layout and by :cells.
_dt_fmtsteps(v) = "[" * join(["(" * (st == 0x01 ? "direct" : st == 0x02 ? "insert" :
                                     st == 0x00 ? "TRUNCATED" :
                                     "unknown-store-0x" * string(st, base = 16)) *
                              ",$(Int(o)))" for (st, o) in v], " ") * "]"
function _dt_handle_note(io, row, indent)
    body = isempty(row.path) ?
        "handle UNDECODED ($(row.reason)) raw=0x" * bytes2hex(row.handle[1:min(end, 16)]) *
            (length(row.handle) > 16 ? "…" : "") :
        "handle ns=:$(row.ns)  grain=$(_dt_grainname(row.grain))  path=$(_dt_fmtsteps(row.path))" *
            (isempty(row.origin_steps) ? "" : "  origin=$(_dt_fmtsteps(row.origin_steps))")
    _dt_sty(io, indent * body * "\n", color = _DT_C_CHROME)
end

## ── :rows — the grep/census form ───────────────────────────────────────────────────────
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
        ## R-DEV-9: the dedicated flavor triple (supersedes R-DEV-8's dim chrome —
        ## flavors must be distinct from each other AND from every other used color)
        _dt_sty(io, _dt_tpad(_dt_flavor(c), 6), color = _dt_fcolor(_dt_flavor(c)))
        _dt_sty(io, _dt_tpad(string(row.attr), 12), color = _DT_C_ATTR, bold = true)
        _dt_sty(io, " => ")
        _dt_sty(io, _dt_tpad(repr(row.value), 8), color = _dt_vcolor(row), bold = true)
        _dt_sty(io, row.polarity ? " (+)" : " (−)", color = _DT_C_CHROME)
        row.origin !== nothing && _dt_sty(io, "  ← $(_dt_grain(row.origin)) #$(_dt_ni(row.origin,:idComponent)) \"" *
            _dt_excerpt(strip(_dt_content(doc, row.origin)), 20) * "\"", color = _DT_C_CHROME)
        _dt_sty(io, "  \"" * _dt_excerpt(strip(_dt_content(doc, c)), 36) * "\"")
        row.origin_status == :failed && _dt_sty(io, "  ⚠ origin unverified", color = _DT_C_BAD, bold = true)
        println(io)
        show_handles && _dt_handle_note(io, row, "         ")
    end
    _dt_print_unanchored(io, doc, _dt_unanchored(frows); show_handles)
end

## ── :tree — evals AT their Components (default layout) ────────────────────────────────
## Layout totality (§6): Segment-anchored rows (REACHABLE — an inline metaSegment
## `#~ head("…",N)` mints grain 0x01, probe-proven 2026-08-20) attach to their OWNING
## LINE with a dim `[Segment #N]` target tag; File-anchored rows render at a File node
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
    if !doc.ok
        _dt_print_unanchored(io, doc, _dt_unanchored(frows); show_handles)
        return
    end
    # with a filter active, an absence label must not assert "no evals" — rows may
    # simply be filtered out (impl-panel adversary finding)
    nolabel  = filtered ? "   (no matching evals)" : "   (no evals — defaults apply)"
    eliword  = filtered ? "(no matching evals)" : "(no evals)"
    node(c, guide, name) = begin
        has = haskey(am, _dt_akey(c))
        _dt_sty(io, guide, color = _DT_C_CHROME)
        _dt_sty(io, _dt_tpad("$name #$(_dt_id(c))", 10), color = _dt_gcolor(c), bold = has)
        _dt_sty(io, _dt_tpad(_dt_flavor(c), 5), color = _dt_fcolor(_dt_flavor(c)))  # R-DEV-9
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
        _dt_eval_bullet(io, doc, row; indent, target_tag = tag)   # guide + "● " (T2-L2)
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

## ── :cells — per-cell dossiers with decoded handles ────────────────────────────────────
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
        grp = groups[h]; c = grp[1].comp
        d = _dt_decode(h)
        _dt_sty(io, "\n$(H(78))\n", color = _DT_C_CHROME)
        if c === nothing
            g = _dt_grainname(grp[1].grain)
            _dt_sty(io, "### CELL  ($g — no document tree position; $(grp[1].reason))\n",
                    color = _DT_C_BAD, bold = true)
        else
            _dt_sty(io, "### CELL  ", color = _dt_gcolor(c), bold = true)
            _dt_sty(io, "$(_dt_grain(c)) #$(_dt_ni(c,:idComponent))  ",
                    color = _dt_gcolor(c), bold = true)
            _dt_sty(io, _dt_flavor(c), color = _dt_fcolor(_dt_flavor(c)), bold = true)  # R-DEV-9
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
##  §F — the file twins (owner ruling R-DEV-3/4 + D-17 format inference)
#########################################################################################

## The HTML page wrapper — byte-identical to the mockup generator's, so .html output
## stays comparable to the approved mockups.
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

The file twin of [`print_BLS_Component_Tree`](@ref) (February `print*`/`write*` pair
convention). `format` selects the sink: `:auto` (default) infers from the extension —
`.html` (case-insensitive) ⇒ the self-contained styled HTML page, ANY other extension
(or none) ⇒ text; an explicit `:html` / `:txt` OVERRIDES the extension entirely.
`color` does not apply to the HTML sink (always styled). Text default
`color=:never` (plain, grep-friendly); `color=:always` writes ANSI escape bytes
(view with `less -R`). `title` is the HTML page's `<title>` (ignored for text output).
The rendered `File` header uses `basename(path)` as the document name unless `_name`
is passed explicitly. `slide` (a scheme Symbol; see the printer's docstring) leaves
the written file byte-identical and ADDITIONALLY emits the
`path * ".slideruns.json"` slide-run sidecar (border `"tree"`) — consumed here,
never forwarded to the printer; X and the sidecar publish as a staged PAIR, and a
call WITHOUT `slide` retires a stale sidecar beside the path (F4/F5).
All other kwargs pass through. Returns `path`.
"""
function write_BLS_Component_Tree_to_file(path::AbstractString, result::GoMeta.GoMetaDelivery;
        format::Symbol = :auto, color::Symbol = :never,
        title::AbstractString = "print_BLS_Component_Tree",
        slide::Union{Nothing,Symbol} = nothing,
        _name::AbstractString = basename(path), kwargs...)
    sr = slide === nothing ? nothing : _dt_slide_resolve(slide)   # validate FIRST (§H)
    renderX(p) = _dt_resolve_format(path, format) === :html ?
        _dt_write_html(p, io -> print_BLS_Component_Tree(io, result; _name, kwargs...), title) :
        open(p, "w") do f
            print_BLS_Component_Tree(f, result; color, _name, kwargs...)
        end
    if sr === nothing
        _dt_slide_retire_sidecar(path)   # F5: retire FIRST — a failing render must
        renderX(path)                    # never leave a stale claim beside partial X
        return path
    end
    apath = abspath(String(path))        # ONE resolution for every fs op (L3#10)
    _dt_slide_check_dest("write_BLS_Component_Tree_to_file", apath)
    ## §H: `slide` is consumed HERE, never forwarded to the printer (the main file
    ## X stays byte-identical — §4.1). The sidecar describes the PLAIN render of
    ## this call's view, independent of `format`/`color` (D3 R4). Pair publication
    ## (F4): capture + classify FIRST, stage X and the sidecar as exclusive temps,
    ## then publish X → sidecar (DESIGN §5-bis.13).
    capr = _dt_slide_cap()
    print_BLS_Component_Tree(_dt_slide_capio(capr), result; _name, kwargs...)
    lr, fnl = _dt_slide_lines(capr)
    sctmp = _dt_slide_stage_sidecar(apath * ".slideruns.json", "write_BLS_Component_Tree_to_file",
                                    sr[1], sr[2], lr, fnl, "tree")
    xtmp = try
        xt, xio = mktemp(dirname(apath); cleanup = false)
        close(xio)
        xt
    catch
        isfile(sctmp) && rm(sctmp; force = true)   # FR1#2: no one-sided orphan
        rethrow()
    end
    try
        renderX(xtmp)
    catch
        rm(xtmp; force = true)
        isfile(sctmp) && rm(sctmp; force = true)
        rethrow()
    end
    _dt_slide_publish_pair(apath, xtmp, sctmp)
    path
end

"""
    write_altValues_evals_to_file(path, result; format=:auto, color=:never,
                                  title=..., kwargs...)

The file twin of [`print_altValues_evals`](@ref) — same format/color/title/_name/slide
rules as [`write_BLS_Component_Tree_to_file`](@ref) (its sidecar border is
`"accent"`). Returns `path`.
"""
function write_altValues_evals_to_file(path::AbstractString, result::GoMeta.GoMetaDelivery;
        format::Symbol = :auto, color::Symbol = :never,
        title::AbstractString = "print_altValues_evals",
        slide::Union{Nothing,Symbol} = nothing,
        _name::AbstractString = basename(path), kwargs...)
    sr = slide === nothing ? nothing : _dt_slide_resolve(slide)   # validate FIRST (§H)
    renderX(p) = _dt_resolve_format(path, format) === :html ?
        _dt_write_html(p, io -> print_altValues_evals(io, result; _name, kwargs...), title) :
        open(p, "w") do f
            print_altValues_evals(f, result; color, _name, kwargs...)
        end
    if sr === nothing
        _dt_slide_retire_sidecar(path)   # F5: retire FIRST — a failing render must
        renderX(path)                    # never leave a stale claim beside partial X
        return path
    end
    apath = abspath(String(path))        # ONE resolution for every fs op (L3#10)
    _dt_slide_check_dest("write_altValues_evals_to_file", apath)
    ## §H: as the tree twin — slide consumed here, plain-view sidecar, pair
    ## publication (F4); border "accent" (owner register row 1, ratified R6).
    capr = _dt_slide_cap()
    print_altValues_evals(_dt_slide_capio(capr), result; _name, kwargs...)
    lr, fnl = _dt_slide_lines(capr)
    sctmp = _dt_slide_stage_sidecar(apath * ".slideruns.json", "write_altValues_evals_to_file",
                                    sr[1], sr[2], lr, fnl, "accent")
    xtmp = try
        xt, xio = mktemp(dirname(apath); cleanup = false)
        close(xio)
        xt
    catch
        isfile(sctmp) && rm(sctmp; force = true)   # FR1#2: no one-sided orphan
        rethrow()
    end
    try
        renderX(xtmp)
    catch
        rm(xtmp; force = true)
        isfile(sctmp) && rm(sctmp; force = true)
        rethrow()
    end
    _dt_slide_publish_pair(apath, xtmp, sctmp)
    path
end

#########################################################################################
##  §H — the `slide` output option (owner order 2026-08-20; BRIEF + DESIGN_slide-option
##  in plan/2026-08-20-devtools-slide-output/). One runs model, two sinks: the
##  `X.slideruns.json` sidecar (file writers) and the ANSI slide preview (print tools).
##  Recorded deviations (full ledger: DESIGN_slide-option.md §5): the §2 brief example's
##  border "usual" on a structure sidecar is an erratum (§2.7 wins → "tree"); the roles
##  header = run_colors ∪ {"blank": payload} (the only reading satisfying §2.3 + §2.5);
##  print tools REPLACE their output with the preview when `slide` is set (§4.1's
##  on-arm becomes the strip-assertion); .html twins' sidecars describe the PLAIN view;
##  styles are role-derived ONLY (§2.4: hideprefix bold 14, everything else regular 13).
#########################################################################################

## THE COLOR AUTHORITY EMBED — generated from SCHEMES.json (plan dir
## 2026-08-20-devtools-slide-output, format_version 1) by gen_schemes_embed.py.
## NEVER edit by hand: regenerate (the script emits THIS ENTIRE BLOCK incl. the
## caveat comments below — F8), then run the authority-drift gate: the plan dir's
## validate_sidecars.py compares the embed (via slide_sweep.jl's consts_dump.json)
## against a fresh SCHEMES.json read.
## REASONING for embedding (not runtime-reading SCHEMES.json): devtools.jl is
## play-side and must work in a bare play checkout; the authority file lives in a
## session plan dir — a runtime cross-tree read would couple the surfaces and add an
## I/O failure mode to a print tool. Scheme caveats carried per BRIEF §3: cvd-dark's
## brand colors never appear inside code boxes; in cvd-dark, payload/code/neutral
## co-occurring in one box are partly structure-distinguished BY DESIGN.
const _DT_SLIDE_FONT = (name = "JetBrains Mono", size_pt = 13)
const _DT_SLIDE_SYMBOLS = Dict{Symbol,String}(:cvd_dark => "cvd-dark", :cvd_light => "cvd-light", :gometa_dark => "gometa-dark", :light => "light", :projector => "projector")
const _DT_SLIDE_SCHEMES = Dict{String,NamedTuple}(
    "gometa-dark" => (
        name = "GoMeta Deck (current, frozen)",
        background = "201D1D",
        run_colors = Dict{String,String}("gutter" => "706D6D", "marker" => "FF1FA9", "payload" => "FFD6D6", "text" => "FFE994", "code" => "96EFBE", "comment" => "5EB91E", "tree" => "7BC4DC", "hideprefix" => "FFD21F", "neutral" => "E8E6E3"),
        border_colors = Dict{String,String}("usual" => "FFD6D6", "accent" => "FF1FA9", "tree" => "7BC4DC"),
        hideprefix_bold = true, hideprefix_size_pt = 14),
    "cvd-dark" => (
        name = "Okabe-Ito Dark Deck Palette",
        background = "201D1D",
        run_colors = Dict{String,String}("gutter" => "8D8989", "marker" => "FF7BC1", "payload" => "FFD6D6", "text" => "FFE994", "code" => "96EFD6", "comment" => "3CCA90", "tree" => "A8BEF7", "hideprefix" => "E69F00", "neutral" => "E8E6E3"),
        border_colors = Dict{String,String}("usual" => "FFD6D6", "accent" => "FF7BC1", "tree" => "A8BEF7"),
        hideprefix_bold = true, hideprefix_size_pt = 14),
    "light" => (
        name = "GoMeta Website Light",
        background = "F1E6D2",
        run_colors = Dict{String,String}("gutter" => "7A5F6E", "marker" => "B80074", "payload" => "4B3421", "text" => "7A5C00", "code" => "157554", "comment" => "35690E", "tree" => "066374", "hideprefix" => "8F3500", "neutral" => "6A533C"),
        border_colors = Dict{String,String}("usual" => "8A6F4D", "accent" => "B80074", "tree" => "066374"),
        hideprefix_bold = true, hideprefix_size_pt = 14),
    "cvd-light" => (
        name = "GoMeta CVD Light",
        background = "F1E6D2",
        run_colors = Dict{String,String}("gutter" => "776068", "marker" => "8D277F", "payload" => "382625", "text" => "332800", "code" => "043540", "comment" => "4F6A3C", "tree" => "064AC2", "hideprefix" => "8F5D00", "neutral" => "34302C"),
        border_colors = Dict{String,String}("usual" => "8A6F4D", "accent" => "8D277F", "tree" => "064AC2"),
        hideprefix_bold = true, hideprefix_size_pt = 14),
    "projector" => (
        name = "GoMeta Projector High-Vis",
        background = "201D1D",
        run_colors = Dict{String,String}("gutter" => "B5A78E", "marker" => "FF85C2", "payload" => "FFE0E0", "text" => "FFE994", "code" => "ACF5CA", "comment" => "7CC24E", "tree" => "88C8F4", "hideprefix" => "FFC93F", "neutral" => "F0EEEB"),
        border_colors = Dict{String,String}("usual" => "FFE0E0", "accent" => "FF85C2", "tree" => "88C8F4"),
        hideprefix_bold = true, hideprefix_size_pt = 14),
)

## The closed §2.5 role vocabulary in its FIXED emission order — the sidecar `roles`
## map and every checker iterate THIS tuple, never a Dict (determinism law; the
## brief's own per-scheme run_colors orders differ, so SCHEMES.json order is not
## usable — DESIGN §1 / seat-D3 E-4).
const _DT_SLIDE_ROLE_ORDER = ("gutter", "blank", "marker", "payload", "text", "code",
                              "comment", "tree", "hideprefix", "neutral")

## IS: the devtools-color → slide-role map (the ONE taste call of the order; DESIGN §2,
## owner-sample-gated). DOES: totalizes every paint value that can reach the _dt_sty
## gate into the closed role vocabulary. REASONING per row: chrome → gutter (the
## scheme's only de-emphasis role); the three grain colors → tree (grain labels ARE
## BLS-tree scaffold — the terminal's Block/Line/Segment hue triple deliberately
## collapses on slides, the deck has ONE scaffold color); attr → payload (an evals
## attr is the evaluated meaning of a metaSegment payload — the metaLine-payload
## family); the flavor triple → the content roles (Meta → marker: the meta-family
## SIGNAL color, keeping the flavor words mutually distinct on slides; Code → code;
## Text → text); GOOD/WARN/BAD and the archival legacy yellow → neutral (NO honest
## role exists — the closed vocabulary has no status colors; `:hide`→hideprefix was
## REJECTED because §2.4 forces hideprefix bold 14pt, which would ripple line height
## mid-row). PURPOSE: devtools' own views (both print tools + both write twins)
## become deck-ready runs without a single semantic lie.
_dt_slide_role_of(color) =
    color === _DT_C_CHROME ? "gutter" :
    (color === _DT_C_BLOCK || color === _DT_C_LINE || color === _DT_C_SEG) ? "tree" :
    color === _DT_C_ATTR   ? "payload" :
    color === _DT_C_META_F ? "marker" :
    color === _DT_C_CODE_F ? "code" :
    color === _DT_C_TEXT_F ? "text" :
    "neutral"   # GOOD/WARN/BAD, legacy :yellow, :normal, nothing, and any future value

## role → (bold, size_pt) — §2.4 verbatim: styles are functions of ROLE ONLY. The
## emitters' own terminal bold is deliberately NOT carried (DESIGN §5.8): a devtools
## `tree` run is regular 13pt on slides even where the terminal shows it bold.
_dt_slide_style(role::String) = role == "hideprefix" ? (true, 14) : (false, 13)

_dt_slide_role_hex(sch, role::String) =
    role == "blank" ? sch.run_colors["payload"] : sch.run_colors[role]

## IS: the slide-kwarg validator. DOES: maps the public Symbol (`:gometa_dark` |
## `:cvd_dark` | `:light` | `:cvd_light` | `:projector`) to its scheme id + record; throws
## ArgumentError NAMING all four on anything else (BRIEF §1 mandates ArgumentError,
## deliberately unlike the neighboring error() validations). Validation runs before
## any byte is written by every caller. PURPOSE: one gate, one message, greppable.
function _dt_slide_resolve(slide::Symbol)
    haskey(_DT_SLIDE_SYMBOLS, slide) || throw(ArgumentError(
        "slide=:$slide is not a supported slide scheme — supported: " *
        ":gometa_dark, :cvd_dark, :light, :cvd_light, :projector"))
    id = _DT_SLIDE_SYMBOLS[slide]
    return id, _DT_SLIDE_SCHEMES[id]
end

## ── run capture at the _dt_sty gate (devtools' own views; DESIGN §1 "Design B′") ──────
## IS: the recording state for one plain render pass. DOES: _dt_sty brackets every
## styled write with byte offsets into `buf` (see the gate's capture arm); gap bytes
## (bare `println(io)` newlines and any future un-gated print) become `neutral` runs
## in the post-pass — totality by construction: the run list is a total annotation of
## the plain byte stream, never a parallel reconstruction. REASONING: `buf` is held
## RAW (never a wrapper) so `position(buf)` is byte-exact; the capture context carries
## no `:color`/`:gm_html`, so _dt_sty's capture arm always prints PLAIN bytes.
struct _DTSlideSpan
    lo::Int          # 0-based byte offset, half-open [lo, hi)
    hi::Int
    role::String
end
mutable struct _DTSlideCap
    buf::IOBuffer
    spans::Vector{_DTSlideSpan}
end
_dt_slide_cap() = _DTSlideCap(IOBuffer(), _DTSlideSpan[])
_dt_slide_capio(cap::_DTSlideCap) = IOContext(cap.buf, :gm_sliderec => cap)

## unwrap an IOContext chain to its raw sink — the capture arm's identity guard
## (a :gm_sliderec key on a context whose sink is NOT the cap's buffer is foreign
## and must be ignored, never trusted for offsets).
_dt_slide_sink(io) = io isa IOContext ? _dt_slide_sink(io.io) : io

## IS: the capture post-pass. DOES: turns (bytes, spans) into the per-line runs model —
## `lines::Vector{Vector{Tuple{String,String}}}` of (text, role) content runs (synthetic
## gutter/blank are the SINKS' business) + `final_newline`. Gap bytes → "neutral";
## spans are split at '\n' (the :legacy style writes newlines INSIDE styled runs);
## adjacent same-role pieces coalesce; zero-length runs are never emitted. Every run
## text must decode as valid UTF-8 (run boundaries are write/newline boundaries, never
## mid-char) — a malformed surface throws ArgumentError rather than emitting a lying
## sidecar (DESIGN §6.3, owner-vetoable).
function _dt_slide_lines(cap::_DTSlideCap)
    bytes = take!(cap.buf)
    spans = cap.spans
    cap.spans = _DTSlideSpan[]   # ONE-SHOT (review L3#5): a reused cap starts clean —
                                 # stale spans can never pair with a fresh buffer
    isempty(bytes) && return Vector{Vector{Tuple{String,String}}}(), false
    fnl = bytes[end] == 0x0a
    ## totalize: ordered (lo, hi, role) covering [0, length) — gaps become neutral;
    ## overlap/out-of-bounds spans are internal-error loud (they would duplicate or
    ## invent bytes — fidelity must fail closed, never silently)
    total = _DTSlideSpan[]
    pos = 0
    for sp in spans
        sp.lo == sp.hi && continue
        (sp.lo >= pos && sp.hi >= sp.lo && sp.hi <= length(bytes)) ||
            throw(ErrorException("slide capture: non-monotonic or out-of-bounds span [$(sp.lo),$(sp.hi)) at pos $pos"))
        sp.lo > pos && push!(total, _DTSlideSpan(pos, sp.lo, "neutral"))
        push!(total, sp)
        pos = sp.hi
    end
    pos < length(bytes) && push!(total, _DTSlideSpan(pos, length(bytes), "neutral"))
    lines = Vector{Vector{Tuple{String,String}}}()
    cur = Vector{Tuple{String,String}}()
    piece(lo, hi, role) = begin   # append bytes[lo+1:hi] to the current line
        lo == hi && return
        s = String(bytes[lo+1:hi])
        isvalid(s) || throw(ArgumentError(
            "slide capture: the rendered view is not valid UTF-8 near byte $(lo + 1) — no sidecar/preview emitted"))
        if !isempty(cur) && cur[end][2] == role
            cur[end] = (cur[end][1] * s, role)
        else
            push!(cur, (s, role))
        end
    end
    for sp in total
        lo = sp.lo
        for k in sp.lo:sp.hi-1
            if bytes[k+1] == 0x0a
                piece(lo, k, sp.role)
                push!(lines, cur); cur = Vector{Tuple{String,String}}()
                lo = k + 1
            end
        end
        piece(lo, sp.hi, sp.role)
    end
    (isempty(cur) && fnl) || push!(lines, cur)
    return lines, fnl
end

## ── the content classifier (marked source / render / structure; seat-D1 spec) ─────────
## Everything below reads the delivered tree (`result.blsComponentTree`) THROUGH THE DOOR — `root`,
## `children`, `getElement`, `content`, `flavor`, `isHorizontalSpace` (stage 2's commit 0) — with NO
## residue outside it since stage 2's commit 9b (R-V04B-85 (D)): the source-line COUNT that sizes the per-line
## output comes from the callers' own bytes (the marked-source writer's line split; the render tier's lines).
## devtools_selfcheck() pins every read (the fates — the Engine's answer per Line since stage 3's commit 2 —, :comment grains,
## the flavor record, byte offsets, the Line texts) so a drifted engine fails LOUDLY.

## first char of the engine's own horizontal-whitespace class ([\h]; includes NBSP) —
## the marker-token delimiter, through the door (`isHorizontalSpace`). Returns the byte index AFTER
## the token, or 0 if none.
function _dt_sl_token_end(txt::AbstractString)
    i = firstindex(txt)
    while i <= lastindex(txt)
        _DT_BLS.isHorizontalSpace(txt[i]) && return i
        i = nextind(txt, i)
    end
    return 0
end

## SEG-CLASSIFY (D1 §a.1): one engine segment (or a whole single-segment line) → runs.
## Precedence: engine `:comment` settribute FIRST (covers Text comments, Code-flavor
## comments, and Meta comment tails uniformly — flavor alone does not decide the
## role); then Meta → marker token (validated against the flavor's OWN anchored
## grammar `re_meta_leaded`, or the close-marker `lead * "]"`) + payload (the
## delimiter char BELONGS to the payload); then Code → code; else Text → text.
function _dt_sl_seg(F, isMeta::Bool, isCode::Bool, iscomment::Bool, txt::AbstractString)
    runs = Tuple{String,String}[]
    isempty(txt) && return runs
    if iscomment
        push!(runs, (String(txt), "comment"))
    elseif isMeta
        t = _dt_sl_token_end(txt)
        token = t == 0 ? String(txt) : String(txt[1:prevind(txt, t)])
        if occursin(F.re_meta_leaded, token) || token == F.lead * "]"
            push!(runs, (token, "marker"))
            rest = t == 0 ? "" : String(txt[t:end])
            isempty(rest) || push!(runs, (rest, "payload"))
        else
            push!(runs, (String(txt), "payload"))   # defensive: unreachable for engine-minted S-Meta
        end
    elseif isCode
        push!(runs, (String(txt), "code"))
    else
        push!(runs, (String(txt), "text"))
    end
    return runs
end

_dt_sl_flags(c) = (_DT_BLS.getElement(c, :isMeta),
                   _DT_BLS.getElement(c, :isCode),
                   _DT_BLS.getElement(c, :comment))

## byte-exact slice of the GAPS and TAILS of a line (the pieces no Segment covers): `a`..`b` are
## inclusive BYTE offsets. A Segment's OWN bytes come through the door's `content` since stage 2's
## commit 0: a Segment's `:stopMainStr` is its final character's START byte (IV-1), so a byte slice
## `a:stopMainStr` cut a multibyte final character short — the classifier's former read.
_dt_sl_bslice(s::AbstractString, a::Int, b::Int) =
    a > b ? "" : String(Vector{UInt8}(codeunits(s)[a:b]))

## LINE-CLASSIFY (D1 §a.2): one source line → content runs, tiling-exact. Segment
## offsets are 1-based inclusive BYTE offsets into the line; segments do NOT cover
## indentation (probe-proven), so uncovered gaps are merged: a line-leading gap
## prepends to the first run unless that run is a `marker` (then the gap stands as
## `neutral`); interior/trailing gaps append to the last run — this keeps every Meta
## segment's run starting exactly at `startMainStr`, the aligner's cut point. The
## byte-concat invariant (runs == line) is asserted by the callers' degrade guard.
function _dt_sl_line(F, ps, line, s::AbstractString)
    isempty(s) && return Tuple{String,String}[]
    segs = _DT_BLS.children(ps, line)   # the Line's Segments through the door (the insert store resolved by BLS itself)
    if isempty(segs)
        m, c, k = _dt_sl_flags(line)
        return _dt_sl_seg(F, m, c, k, s)
    end
    runs = Tuple{String,String}[]
    pos = 1
    for seg in segs
        a = Int(_DT_BLS.getElement(seg, :startMainStr))
        b = Int(_DT_BLS.getElement(seg, :stopMainStr))
        (1 <= a && a <= b + 1 && b <= ncodeunits(s)) ||
            throw(ErrorException("slide classifier: segment span [$a:$b] outside line ($(ncodeunits(s)) bytes)"))
        gap = _dt_sl_bslice(s, pos, a - 1)
        m, c, k = _dt_sl_flags(seg)
        segtxt = String(_DT_BLS.content(ps, seg))   # the Segment's bytes through the door — its final character WHOLE (`b` is that character's START byte, IV-1; the former byte slice `a:b` cut it short)
        segruns = _dt_sl_seg(F, m, c, k, segtxt)
        if !isempty(gap)
            if isempty(runs)
                if !isempty(segruns) && segruns[1][2] == "marker"
                    push!(runs, (gap, "neutral"))
                elseif !isempty(segruns)
                    segruns[1] = (gap * segruns[1][1], segruns[1][2])
                else
                    push!(runs, (gap, "neutral"))
                end
            else
                runs[end] = (runs[end][1] * gap, runs[end][2])
            end
        end
        append!(runs, segruns)
        pos = a + ncodeunits(segtxt)   # past the Segment's whole final character
    end
    if pos <= ncodeunits(s)
        tail = _dt_sl_bslice(s, pos, ncodeunits(s))
        isempty(runs) ? push!(runs, (tail, "neutral")) : (runs[end] = (runs[end][1] * tail, runs[end][2]))
    end
    join(first.(runs)) == s ||
        throw(ErrorException("slide classifier: tiling concat mismatch"))
    return runs
end

## FATE (D1 §a.3): a Line's fate is THE ENGINE's ANSWER for that Line — `answerFor(result, line, :Visib).value`, one of
## :discard / :hide / :show (the Line's own rows, else its Block's, else the declared default `show`; stage 3's commit 2 of the
## v0.4 build, R-V04B-16 (1)). The former ladder over the three settribute flags of the Line, its Block and the File (first
## flagged grain decides) left with it — MEASURED equal to the answer on every Line of the corpus and the authored scenarios
## before the change (plan `receipts/S8-branch/precheck-s3c1/PROBES-s3-consumer-equivalence.txt`, P5). Drops are KNOWN
## (:discard), never inferred.
_dt_sl_fate(result, line) = GoMeta.answerFor(result, line, :Visib).value

## the shared File→Block→Line walk through the door (`root`, `children`; the insert store's negative
## ids are resolved by BLS itself — the former positive-id guards are gone). The callback receives the
## Line, its Block, the File and the Line's input line number.
function _dt_sl_walk(f, ps)
    file = _DT_BLS.root(ps)
    for block in _DT_BLS.children(ps, file)
        for line in _DT_BLS.children(ps, block)
            ln = Int(_DT_BLS.getElement(line, :inputLineNum))
            f(line, block, file, ln)
        end
    end
end

## SOURCE surface (D1 §a.4): classify the parsed source's own lines. `hideprefix` is
## NEVER emitted here — brief rule 6.1 is a render-only re-cut. Returns the runs
## lines, or `nothing` to degrade (caller emits whole-file neutral). `nsrc` = the source-line COUNT from the
## CALLER's own bytes (R-V04B-85 (D), stage 2's commit 9b: the marked-source writer's line split; the render tier's
## `renderlines`) — the former `length(collectedLines)` read outside the door is gone.
function _dt_sl_source_lines(result, nsrc::Int)
    try
        result.status == GoMeta.PROCESS_OK || return nothing
        ps = result.blsComponentTree
        F = _DT_BLS.flavor(ps)
        out = Vector{Union{Nothing,Vector{Tuple{String,String}}}}(nothing, nsrc)
        _dt_sl_walk(ps) do line, block, file, ln
            1 <= ln <= nsrc || throw(ErrorException("slide classifier: inputLineNum $ln outside 1:$nsrc"))
            out[ln] === nothing || throw(ErrorException("slide classifier: line $ln visited twice"))
            out[ln] = _dt_sl_line(F, ps, line, String(_DT_BLS.content(ps, line)))   # the Line's text through the door (its source line by `:inputLineNum`)
        end
        any(x -> x === nothing, out) && return nothing
        return Vector{Vector{Tuple{String,String}}}(out)
    catch err
        err isa InterruptException && rethrow()
        return nothing
    end
end

## RENDER surface tier T0 (D1 §a.5, the fate-ladder DERIVATION — no re-parse, no
## search): fates decide consume-vs-skip; the ≤3 candidate byte-forms are GENERATED
## from the source line + its first Meta-flavor segment offset and byte-verified
## against the actual render line (mutually exclusive by length — never a tie):
##   IDENT       r == s            (shown lines, blanks, comment-hidden ensure-token)
##   WHOLEHIDE   r == hm * s       (fate :hide only)
##   INLINE-TAIL r == hm * s[1:m-1] * hm * s[m:end]   (fate :hide, non-Meta line)
## hideprefix is asserted ONLY on a fate-:hide byte-match (false provenance is
## structurally impossible); the mid-inserted hm is role `comment` (rule 6.3 — the
## render-inserted and source-authored mid marks paint alike). ANY mismatch returns
## nothing → tier T1. Probe-proven: 32/32 corpus files reconstruct byte-exactly.
function _dt_sl_render_lines_T0(result, renderlines)
    try
        result.status == GoMeta.PROCESS_OK || return nothing
        ps = result.blsComponentTree
        F = _DT_BLS.flavor(ps)
        hm = F.hide_marker
        out = Vector{Vector{Tuple{String,String}}}()
        ok = Ref(true)
        j = Ref(1)
        _dt_sl_walk(ps) do line, block, file, ln
            ok[] || return
            f = _dt_sl_fate(result, line)
            f === :discard && return
            s = String(_DT_BLS.content(ps, line))   # the Line's text through the door (empty for an out-of-range Line — the byte comparison below degrades; the former range check gone, R-V04B-85 (D))
            if j[] > length(renderlines)
                ok[] = false; return
            end
            r = renderlines[j[]]; j[] += 1
            base = _dt_sl_line(F, ps, line, s)
            if r == s
                push!(out, base)
            elseif f === :hide && r == hm * s
                push!(out, vcat([(hm, "hideprefix")], base))
            elseif f === :hide && !_DT_BLS.getElement(line, :isMeta)
                segs = _DT_BLS.children(ps, line)
                k = findfirst(sg -> _DT_BLS.getElement(sg, :isMeta), segs)
                if k === nothing
                    ok[] = false; return
                end
                m = Int(_DT_BLS.getElement(segs[k], :startMainStr))
                if r != hm * _dt_sl_bslice(s, 1, m - 1) * hm * _dt_sl_bslice(s, m, ncodeunits(s))
                    ok[] = false; return
                end
                ## split `base` at the byte where the first Meta segment starts — a run
                ## boundary by LINE-CLASSIFY construction (gaps merge backwards).
                ## m == 1 (a Meta segment at byte 1 of a non-Meta line) is engine-
                ## unreachable (such a line IS a metaLine); if it ever occurred, cut
                ## stays 0 and the file DEGRADES to T1 — never wrong bytes (P1#6).
                cut = 0; acc = 0
                for (i, run) in enumerate(base)
                    acc += ncodeunits(run[1])
                    acc == m - 1 && (cut = i; break)
                    acc > m - 1 && break
                end
                if cut == 0
                    ok[] = false; return
                end
                push!(out, vcat([(hm, "hideprefix")], base[1:cut], [(hm, "comment")], base[cut+1:end]))
            else
                ok[] = false; return
            end
        end
        (ok[] && j[] == length(renderlines) + 1) || return nothing
        return out
    catch err
        err isa InterruptException && rethrow()
        return nothing
    end
end

## RENDER tier T1 (whole-file degradation; D1 §d.R1): re-parse the RENDER bytes as
## their own document under the ORIGINATING FLAVOR, rebuilt from the delivered tree
## (`BLS.flavor(blsComponentTree).flavor_tag`; the configuration is not delivered — R-V04B-28: the
## namespace, the profile, a fed profile and a parse range do not carry — the tiling reads
## structure and flavor, never a handle, and the render bytes are a whole document of their own) and
## classify per the source procedure — leading/mid hide marks classify `comment` via
## their :comment settributes; hideprefix is NEVER asserted (rule 6.1 needs an input
## to compare, and T1 has none). T1 failing too → R2: whole-file neutral.
## split written bytes into content lines per the §2.1 pinned model: split on '\n',
## drop exactly one trailing empty element iff the bytes end with '\n' (recorded as
## final_newline); zero bytes ⇒ zero lines.
function _dt_sl_splitlines(bytes)
    isempty(bytes) && return SubString{String}[], false
    ls = split(String(copy(bytes)), "\n")
    fnl = bytes[end] == 0x0a
    fnl && pop!(ls)
    return ls, fnl
end

_dt_sl_wholeline(ls, role) =
    Vector{Vector{Tuple{String,String}}}([isempty(l) ? Tuple{String,String}[] :
        Tuple{String,String}[(String(l), role)] for l in ls])

function _dt_sl_render_lines(result, renderbytes)
    renderlines, fnl = _dt_sl_splitlines(renderbytes)
    t0 = _dt_sl_render_lines_T0(result, renderlines)
    t0 !== nothing && return t0, fnl, :component
    t1 = try
        r2 = GoMeta.goMeta(copy(renderbytes); config = GoMeta.GoMetaConfig(flavor_tag = _DT_BLS.flavor(result.blsComponentTree).flavor_tag))
        _dt_sl_source_lines(r2, length(renderlines))   # the count from the render tier's own line split (R-V04B-85 (D))
    catch err
        err isa InterruptException && rethrow()
        nothing
    end
    ## T1 acceptance is FIDELITY-GATED (review P1#3): the re-parse tiles ITS OWN
    ## collectedLines — accept only if every line's run concat reproduces the actual
    ## render line byte-for-byte; a drifted engine whose collectedLines diverge from
    ## the written bytes falls to R2 instead of emitting a lying sidecar.
    if t1 !== nothing && length(t1) == length(renderlines) &&
       all(join(first.(t1[i])) == renderlines[i] for i in eachindex(renderlines))
        return t1, fnl, :reparse
    end
    return _dt_sl_wholeline(renderlines, "neutral"), fnl, :neutral
end

## STRUCTURE surface fallback: whole-line `tree` runs (the original v1 rule-6.5
## reading — now the DEGRADE tier under the 2026-08-21 owner fix-order #1, which
## rules reference-true segment-interior coloring; see _dt_sl_structure_runs).
function _dt_sl_structure_lines(bytes)
    ls, fnl = _dt_sl_splitlines(bytes)
    return _dt_sl_wholeline(ls, "tree"), fnl
end

## IS: the REFERENCE-TRUE structure-view classifier (owner fix-order #1,
## 2026-08-21; run-exact reference banked at
## plan/2026-08-20-devtools-slide-output/reference-tree-coloring.md).
## DOES: rebuilds each `{:B-X:L-Y […]}` structure line as runs by MIRRORING the
## engine's serialization walk over the component data (canon R1 — never a regex
## over the serialized text): every scaffold token (`{:B-X`, `{       `, `:L-Y [`,
## `{:S-F [`, `]}`) is role `tree`; every segment/line INTERIOR is classified by
## the standard §2.6 content rules via `_dt_sl_seg` (comment settribute wins
## inside any flavor — the reference's precedence); blank lines stay
## gutter+filler. Every rebuilt line is BYTE-VERIFIED against the actual
## structure bytes; ANY mismatch (or any walk surprise) returns `nothing` and the
## caller degrades to the whole-line-`tree` fallback — fidelity can never lie.
## PURPOSE: structure boxes on slides match the reference talk slides s13-18
## token-for-token, in every scheme, for every flavor family.
function _dt_sl_structure_runs(result, bytes)
    try
        result.status == GoMeta.PROCESS_OK || return nothing
        actual, _ = _dt_sl_splitlines(bytes)
        ps = result.blsComponentTree
        F = _DT_BLS.flavor(ps)
        out = Vector{Vector{Tuple{String,String}}}()
        pushrun!(runs, txt, role) = begin
            isempty(txt) && return
            if !isempty(runs) && runs[end][2] == role
                runs[end] = (runs[end][1] * txt, role)
            else
                push!(runs, (String(txt), role))
            end
        end
        for b in _DT_BLS.children(ps)   # the walk through the door (mirrors the serialization walk of the basic renderer)
            newBlock = true
            for line in _DT_BLS.children(ps, b)
                if _DT_BLS.getElement(line, :includeInOutFile) &&
                   _DT_BLS.getElement(line, :isEmpty)
                    length(out) < length(actual) && isempty(actual[length(out) + 1]) ||
                        return nothing
                    push!(out, Tuple{String,String}[])
                    continue
                end
                runs = Tuple{String,String}[]
                pushrun!(runs, newBlock ? "{:B-" * _dt_flavor(b) : "{       ", "tree")
                pushrun!(runs, ":L-" * _dt_flavor(line) * " [", "tree")
                if _DT_BLS.getElement(line, :includeInOutFile)
                    m, c, k = _dt_sl_flags(line)
                    for r in _dt_sl_seg(F, m, c, k, String(_DT_BLS.content(ps, line)))   # the Line's text through the door
                        pushrun!(runs, r[1], r[2])
                    end
                elseif _dt_ni(line, :numChildren) != 0
                    for seg in _DT_BLS.children(ps, line)
                        _DT_BLS.getElement(seg, :includeInOutFile) || continue
                        pushrun!(runs, "{:S-" * _dt_flavor(seg) * " [", "tree")
                        m, c, k = _dt_sl_flags(seg)
                        for r in _dt_sl_seg(F, m, c, k, String(_DT_BLS.content(ps, seg)))   # the Segment's byte span through the door (the bytes the serialization writes)
                            pushrun!(runs, r[1], r[2])
                        end
                        pushrun!(runs, "]}", "tree")
                    end
                end
                pushrun!(runs, "]}", "tree")
                length(out) < length(actual) || return nothing
                join(first.(runs)) == actual[length(out) + 1] || return nothing
                push!(out, runs)
                newBlock = false
            end
        end
        length(out) == length(actual) || return nothing
        return out
    catch err
        err isa InterruptException && rethrow()
        return nothing
    end
end

## whole-file neutral (tier R0/R2): the honest floor — never an error (rule 6.6).
function _dt_sl_neutral_lines(bytes)
    ls, fnl = _dt_sl_splitlines(bytes)
    return _dt_sl_wholeline(ls, "neutral"), fnl
end

## IS: the UTF-8 preflight of a slide-enabled surface (the shipped decision — owner
## register: invalid-UTF-8 surface ⇒ ArgumentError, never a lying sidecar; found
## unenforced on the writer paths by all three CrossReview seats). DOES: throws the
## documented ArgumentError BEFORE anything is written when `slide` is set; the
## byte-faithful non-slide paths never call it. The sidecar contract §2.1
## presupposes UTF-8 decode; rule 6.6's "never an error" covers CLASSIFICATION,
## not undecodable bytes.
function _dt_sl_utf8_preflight(tool::String, bytes)
    s = String(Vector{UInt8}(bytes))   # the constructor materializes a fresh copy
                                       # (takeover-safe; R1#5: no double copy)
    isvalid(s) || throw(ArgumentError(
        "$tool: slide= requires a UTF-8-decodable surface — the bytes are not " *
        "valid UTF-8; nothing was written (drop slide= for the byte-faithful copy)"))
    nothing
end

## ── sink 1: the X.slideruns.json sidecar (hand-rolled deterministic JSON) ─────────────

## the ONE JSON string escaper: `\` `"` named escapes, \b\t\n\f\r, other C0 controls
## and DEL as lowercase \u00xx; emoji and all other non-ASCII stay RAW UTF-8 (§4.6).
function _dt_sl_jesc(s::AbstractString)
    buf = IOBuffer()
    for c in s
        if c == '\\';     print(buf, "\\\\")
        elseif c == '"';  print(buf, "\\\"")
        elseif c == '\b'; print(buf, "\\b")
        elseif c == '\t'; print(buf, "\\t")
        elseif c == '\n'; print(buf, "\\n")
        elseif c == '\f'; print(buf, "\\f")
        elseif c == '\r'; print(buf, "\\r")
        elseif c < ' ' || c == '\x7f'
            print(buf, "\\u00", string(UInt32(c), base = 16, pad = 2))
        else
            print(buf, c)
        end
    end
    String(take!(buf))
end

function _dt_sl_run_json(text::String, role::String, sch; synthetic::Bool = false)
    bold, pt = _dt_slide_style(role)
    "{ \"text\": \"" * _dt_sl_jesc(text) * "\", \"role\": \"" * role *
    "\", \"color\": \"" * _dt_slide_role_hex(sch, role) * "\", \"bold\": " *
    (bold ? "true" : "false") * ", \"size_pt\": " * string(pt) *
    (synthetic ? ", \"synthetic\": true" : "") * " }"
end

## IS: the pair-publication primitives (verification order F3/F4/F5 + the F-wave
## reconfirm hardening; DESIGN §5-bis.12-13). The invariant they buy: A SIDECAR,
## WHEN PRESENT, DESCRIBES THE X BESIDE IT — guaranteed for the PLAY contract's
## SINGLE WRITER PER DESTINATION (the turn-rules law) across every crash window;
## concurrent same-destination writers/readers are OUT OF CONTRACT (exclusive
## temps prevent staging collisions, but the retire→publish sequence is not
## serialized — a per-path lock/generation protocol is the recorded future option,
## DESIGN §5-bis.13). Local-filesystem semantics; Dropbox/NFS sync the two names
## independently (caveat recorded).
## DOES: staging writes to EXCLUSIVE same-directory temps (Julia mktemp —
## kernel-exclusive create; temps stay 0600 until publication); publication uses
## `Base.rename` — the RAW atomic-replace syscall, never `mv(force=true)` (whose
## fallback RECURSIVELY DELETES an existing directory destination and can degrade
## to copy+delete — Base file.jl's own warning; reconfirm FR1#1). A directory or
## symlink destination is rejected up front (`_dt_slide_check_dest`): the off-arm
## writes THROUGH a symlink, publication would REPLACE it — divergence refused,
## never silent. Modes at publication: X keeps an existing destination's mode,
## else 0o666 minus the process umask; the sidecar is never more permissive than
## X (and never executable). Crash windows (kill -9): staged temps only · old X +
## no sidecar · new X + no sidecar — always "no claim", never a mismatched pair;
## orphaned `jl_*` temps in the destination directory are the documented kill-9
## residue (scavenge by age).
function _dt_slide_check_dest(tool::String, path::AbstractString)
    (isdir(path) || endswith(String(path), '/')) && throw(ArgumentError(
        "$tool: the destination $(repr(String(path))) is a DIRECTORY — pass a file path"))
    islink(path) && throw(ArgumentError(
        "$tool: the destination is a SYMLINK — slide publication would replace the " *
        "link itself (the non-slide arm writes through it); pass the resolved target"))
    nothing
end

function _dt_slide_stage_bytes(neardir::AbstractString, bytes)
    tmp, io = mktemp(isempty(neardir) ? "." : neardir; cleanup = false)
    try
        write(io, bytes)
        close(io)
        return tmp
    catch
        try close(io) catch end   # non-masking (FR1#2): the ORIGINAL error survives
        rm(tmp; force = true)
        rethrow()
    end
end

function _dt_slide_retire_sidecar(path::AbstractString)
    sc = path * ".slideruns.json"
    isfile(sc) && rm(sc; force = true)
    nothing
end

## stage the sidecar (validated + serialized + exclusive temp) — publication is the
## caller's last step. The central UTF-8 belt stays (defense in depth behind the
## writers' preflight): a malformed run text must NEVER reach the JSON.
## `_dt_slide_emit_sidecar` (below) is the FORMAT: pinned top-level key order
## (format_version · tool · scheme · background · font · roles · border ·
## final_newline · lines), roles = run_colors ∪ {"blank": payload-hex} in the fixed
## vocabulary order, one physical line per line-object, the synthetic gutter +
## blank-filler runs, integers bare, exactly one trailing newline — a pure
## function of its arguments (no clock/paths/Dict iteration), which is what makes
## §4.5 cross-process idempotence hold.
function _dt_slide_stage_sidecar(scpath::AbstractString, tool::String, sid::String,
                                 sch, lines, fnl::Bool, border::String)
    gw = max(2, ndigits(length(lines)))
    for runs in lines, (text, _) in runs
        isvalid(text) || throw(ArgumentError(
            "$tool: slide sidecar run text is not valid UTF-8 — no sidecar emitted"))
    end
    buf = IOBuffer()
    _dt_slide_emit_sidecar(buf, tool, sid, sch, lines, fnl, border, gw)
    _dt_slide_stage_bytes(dirname(scpath), take!(buf))
end

## the destination-mode policy (reconfirm L1#4/L3#6): an existing X keeps its
## mode; a new X gets 0o666 minus the process umask (read-and-restore); the
## sidecar = X's mode with execute bits stripped, never more permissive.
function _dt_slide_dest_mode(path::AbstractString)
    isfile(path) && return filemode(path) & 0o7777
    um = ccall(:umask, UInt32, (UInt32,), UInt32(0o022))
    ccall(:umask, UInt32, (UInt32,), um)
    return 0o666 & ~Int(um)
end

## publish a staged (X?, sidecar) pair: chmod at the last moment, retire the stale
## sidecar, `Base.rename` X, then the sidecar. `xtmp === nothing` = the caller's X
## is already in place (the off-arms never come here).
function _dt_slide_publish_pair(path::AbstractString, xtmp, sctmp::AbstractString)
    try
        xmode = _dt_slide_dest_mode(path)
        xtmp === nothing || chmod(xtmp, xmode)
        chmod(sctmp, xmode & 0o666)
        _dt_slide_retire_sidecar(path)
        xtmp === nothing || Base.rename(xtmp, path)
        Base.rename(sctmp, path * ".slideruns.json")
    catch
        xtmp !== nothing && isfile(xtmp) && rm(xtmp; force = true)
        isfile(sctmp) && rm(sctmp; force = true)
        rethrow()
    end
    path
end

function _dt_slide_emit_sidecar(f::IO, tool::String, sid::String,
                                sch, lines, fnl::Bool, border::String, gw::Int)
    let
        print(f, "{\n")
        print(f, " \"format_version\": 1,\n")
        print(f, " \"tool\": \"", tool, "\",\n")
        print(f, " \"scheme\": \"", sid, "\",\n")
        print(f, " \"background\": \"", sch.background, "\",\n")
        print(f, " \"font\": { \"name\": \"", _DT_SLIDE_FONT.name,
              "\", \"size_pt\": ", _DT_SLIDE_FONT.size_pt, " },\n")
        print(f, " \"roles\": { ",
              join(["\"" * r * "\": \"" * _dt_slide_role_hex(sch, r) * "\""
                    for r in _DT_SLIDE_ROLE_ORDER], ", "), " },\n")
        print(f, " \"border\": \"", border, "\",\n")
        print(f, " \"final_newline\": ", fnl ? "true" : "false", ",\n")
        if isempty(lines)
            print(f, " \"lines\": [] }\n")
        else
            print(f, " \"lines\": [\n")
            for (n, runs) in enumerate(lines)
                parts = [_dt_sl_run_json(lpad(string(n), gw) * " ", "gutter", sch; synthetic = true)]
                if isempty(runs)
                    push!(parts, _dt_sl_run_json(" ", "blank", sch; synthetic = true))
                else
                    for (text, role) in runs
                        push!(parts, _dt_sl_run_json(text, role, sch))
                    end
                end
                print(f, "  { \"n\": ", n, ", \"runs\": [ ", join(parts, ", "), " ] }",
                      n == length(lines) ? "\n" : ",\n")
            end
            print(f, " ] }\n")
        end
    end
    nothing
end

## ── sink 2: the ANSI slide preview (print tools; truecolor) ───────────────────────────

function _dt_sl_rgb(hex::String)
    parse(Int, hex[1:2]; base = 16), parse(Int, hex[3:4]; base = 16), parse(Int, hex[5:6]; base = 16)
end
_dt_sl_bgseq(hex) = (t = _dt_sl_rgb(hex); "\e[48;2;$(t[1]);$(t[2]);$(t[3])m")
_dt_sl_fgseq(hex) = (t = _dt_sl_rgb(hex); "\e[38;2;$(t[1]);$(t[2]);$(t[3])m")

## IS: the slide preview renderer — what the slide box will look like, in the
## terminal. DOES: paints every line on the scheme background (explicit space padding
## to the box width — never \e[K, background-color-erase is terminal-dependent) with
## truecolor per-run reset-then-set SGR discipline (\e[0m + bg + [bold] + fg + text;
## flat runs, never nested; full \e[0m before every newline — safe under less -R and
## partial copies); a synthetic right-aligned line-number gutter; exactly ONE header
## and ONE trailer frame line (border-variant foreground) naming the tool, scheme,
## background, and font so the viewer knows what they see and what ANSI cannot show
## (size_pt is sidecar-only). Blank-line fillers are NOT printed (strip decidability).
## Bold renders only via role — i.e. hideprefix runs; devtools views have none.
## REASONING: truecolor escapes are theme-immune and never remapped (the R-DEV-10
## lesson); the preview REPLACES the tool's normal output when slide= is set, and the
## §4.1 obligation becomes the battery's strip-assertion (non-synthetic run bytes ==
## the same call's slide=nothing output). PURPOSE: judge any scheme on any view with
## one keyword, no deck round-trip.
function _dt_slide_preview(io, tool::String, sid::String, sch, lines, border::String)
    gw = max(2, ndigits(length(lines)))
    ## CONTROL-BYTE GUARD (review L3#2 — the terminal-forging class): run text is
    ## written raw into the ANSI stream, so ESC/CR/C0/C1/DEL in a run (reachable via
    ## a hostile `_name`; the renderers themselves escape content controls) could
    ## rewrite the gutter, frames, or later terminal output. Reject loudly — the
    ## preview never renders forgeable bytes, and the strip-assertion stays honest.
    for runs in lines, (text, _) in runs, c in text
        if c < ' ' || c == '\x7f' || ('\u80' <= c <= '\u9f')
            throw(ArgumentError("$tool: slide preview run text carries the control " *
                                "character $(repr(c)) — refusing to render it into " *
                                "the terminal stream (check _name and view inputs)"))
        end
    end
    head = "── slide preview · $tool · scheme $sid · bg #$(sch.background) · " *
           "$(_DT_SLIDE_FONT.name) $(_DT_SLIDE_FONT.size_pt) pt (size_pt: sidecar-only) ──"
    tail = "── end preview · $(length(lines)) lines ──"
    W = max(textwidth(head), textwidth(tail),
            maximum(vcat([gw + 1 + sum(textwidth(t) for (t, _) in l; init = 0) for l in lines], [0]))) + 1
    bg = _dt_sl_bgseq(sch.background)
    bhex = sch.border_colors[border]
    pad(w) = ' '^max(0, w)
    frame(s) = (print(io, "\e[0m", bg, _dt_sl_fgseq(bhex), s, pad(W - textwidth(s)), "\e[0m\n"))
    frame(head)
    for (n, runs) in enumerate(lines)
        print(io, "\e[0m", bg, _dt_sl_fgseq(_dt_slide_role_hex(sch, "gutter")),
              lpad(string(n), gw), " ")
        w = gw + 1
        for (text, role) in runs
            bold, _ = _dt_slide_style(role)
            print(io, "\e[0m", bg, bold ? "\e[1m" : "", _dt_sl_fgseq(_dt_slide_role_hex(sch, role)), text)
            w += textwidth(text)
        end
        print(io, "\e[0m", bg, pad(W - w), "\e[0m\n")
    end
    frame(tail)
    nothing
end

## ── the three surface writers (the `writeBlsStructureToFile` class: the tool's pair + the marked source) ──

"""
    writeBlsStructureToFile(path, result; slide=nothing) -> path

IS: the structure-surface file writer — writes THE BLS structure view
(`Main.BasicRenderer.outputs(result).blsStructure_bytes`, line-mapped 1:1 to the input) of one
`goMeta` result to `path`, VERBATIM. The name deliberately revives the February
parser-side `writeBlsStructureToFile(path)` serialization, now fed from the development
tool's pair (`Main.BasicRenderer.outputs`; same output, new plumbing).
DOES: byte-copies the tool's surface; with `slide` set, additionally emits
`path * ".slideruns.json"` — the slide-run sidecar (contract: BRIEF §2 in
plan/2026-08-20-devtools-slide-output/): REFERENCE-TRUE runs per the owner
fix-order of 2026-08-21 (DESIGN §5-bis.15) — scaffold tokens are role `tree`,
segment/line INTERIORS carry the standard content roles (marker/payload/comment/
code/text; the comment settribute wins inside any flavor), rebuilt by mirroring
the engine's serialization walk over the component data and BYTE-VERIFIED per
line (any mismatch degrades the whole file to the original whole-line-`tree`
reading — never a lying run). Empty lines carry the synthetic gutter + blank
filler; the box border is `"tree"` (the structure variant; the BRIEF §2 example's
`"usual"` on a structure sidecar is a recorded erratum — §2.7 wins).
REASONING: the structure box is the debugging anchor (BLS-structure-first law), and
slides need it with the deck's scaffold color, not a re-derivation. PURPOSE: one
command turns any play structure view into deck-ready colored-run data.

PARAMETERS — which behavior each triggers:
- `path::AbstractString` — the output file; the sidecar lands beside it as
  `path * ".slideruns.json"` (X keeps its extension: `t.jl` → `t.jl.slideruns.json`).
- `result::GoMeta.GoMetaDelivery` — the ONE `goMeta` result whose structure is written.
- `slide::Union{Nothing,Symbol} = nothing` — `nothing`: write X only, byte-identical
  to today, no sidecar; a stale `X.slideruns.json` sitting beside the path is
  RETIRED (removed — F5: a sidecar, when present, describes the X beside it). One of
  `:gometa_dark` (the deck default) | `:cvd_dark` | `:light` | `:cvd_light` |
  `:projector`: also
  emit the sidecar under that scheme. Any other Symbol ⇒ ArgumentError naming these
  five (validated BEFORE any byte is written); a non-Symbol ⇒ TypeError at the call
  boundary (typed kwarg).
"""
function writeBlsStructureToFile(path::AbstractString, result::GoMeta.GoMetaDelivery;
                                 slide::Union{Nothing,Symbol} = nothing)
    sr = slide === nothing ? nothing : _dt_slide_resolve(slide)
    bytes = copy(Main.BasicRenderer.outputs(result).blsStructure_bytes)
    if sr === nothing
        _dt_slide_retire_sidecar(path)   # F5: retire FIRST — a failing write must
        write(path, bytes)               # never leave a stale claim beside partial X
        return path
    end
    apath = abspath(String(path))        # ONE resolution for every fs op (L3#10)
    _dt_slide_check_dest("writeBlsStructureToFile", apath)
    _dt_sl_utf8_preflight("writeBlsStructureToFile", bytes)
    ## owner fix-order #1 (2026-08-21): reference-true runs from the component
    ## mirror; ANY mismatch degrades to the original whole-line-tree reading
    lr = _dt_sl_structure_runs(result, bytes)
    fnl = !isempty(bytes) && bytes[end] == 0x0a
    lr === nothing && ((lr, fnl) = _dt_sl_structure_lines(bytes))   # THE degrade tier
    xtmp = _dt_slide_stage_bytes(dirname(apath), bytes)
    sctmp = try
        _dt_slide_stage_sidecar(apath * ".slideruns.json", "writeBlsStructureToFile",
                                sr[1], sr[2], lr, fnl, "tree")
    catch
        rm(xtmp; force = true)           # FR1#2: no one-sided temp orphan
        rethrow()
    end
    _dt_slide_publish_pair(apath, xtmp, sctmp)
    path
end

"""
    writeRenderToFile(path, result; slide=nothing) -> path

IS: the render-surface file writer — writes the reference render
(`Main.BasicRenderer.outputs(result).render_bytes`: show / hide via the flavor's hide marker /
discard) of one `goMeta` result to `path`, VERBATIM.
DOES: byte-copies the engine surface; with `slide` set, additionally emits
`path * ".slideruns.json"`. Classification is a fate-ladder DERIVATION from the
originating result (canon R1 — never a regex over raw lines): the Engine's ANSWER per Line
(`answerFor(result, line, :Visib)` — :discard / :hide / :show) decides which source lines the
render kept, and each kept line is byte-verified against the ≤3 derivable forms
(identical · whole-line-hidden `hm * line` · inline-tail
`hm * line[1:m-1] * hm * line[m:end]` at the first Meta-flavor segment). The
render-added leading hide marker classifies `hideprefix` (bold 14pt, the scheme's
hideprefix color); the
mid-inserted one classifies `comment` (rule 6.3 — source-authored and
render-inserted mid marks paint alike). Any mismatch (e.g. a future engine changing
render surfaces) degrades WHOLE-FILE to a re-parse of the render bytes under a
config REBUILT from the delivered tree's flavor
(`GoMetaConfig(flavor_tag = BLS.flavor(result.blsComponentTree).flavor_tag)` — the
originating configuration is not delivered, R-V04B-28; the tier-T1 comment
`## RENDER tier T1 (whole-file degradation; D1 §d.R1)` above `_dt_sl_splitlines`
names what does not carry) (hide marks then classify `comment`; `hideprefix` is
never asserted without an input to compare) and, failing that too, to whole-line
`neutral` — the sidecar never errors on content and never lies about provenance.
REASONING: the deck's output boxes are renders; hideprefix-vs-comment is exactly
the distinction slides must show, and only the fate derivation can make it without
false provenance. PURPOSE: any play render becomes deck-ready colored-run data.

PARAMETERS — which behavior each triggers:
- `path::AbstractString` — the output file; sidecar at `path * ".slideruns.json"`.
- `result::GoMeta.GoMetaDelivery` — the ONE `goMeta` result whose render is written;
  its delivered tree's BLS internals (`blsComponentTree`) feed the derivation (D-6(a) exemption surface, pinned by
  `devtools_selfcheck()`).
- `slide::Union{Nothing,Symbol} = nothing` — as [`writeBlsStructureToFile`](@ref):
  `nothing` = X only AND a stale `X.slideruns.json` beside the path is RETIRED
  (removed — F5); a scheme Symbol = X + sidecar published as a staged pair (border
  `"usual"`); unknown Symbol ⇒ ArgumentError naming the five supported values.
"""
function writeRenderToFile(path::AbstractString, result::GoMeta.GoMetaDelivery;
                           slide::Union{Nothing,Symbol} = nothing)
    sr = slide === nothing ? nothing : _dt_slide_resolve(slide)
    bytes = copy(Main.BasicRenderer.outputs(result).render_bytes)
    if sr === nothing
        _dt_slide_retire_sidecar(path)   # F5: retire FIRST — a failing write must
        write(path, bytes)               # never leave a stale claim beside partial X
        return path
    end
    apath = abspath(String(path))        # ONE resolution for every fs op (L3#10)
    _dt_slide_check_dest("writeRenderToFile", apath)
    _dt_sl_utf8_preflight("writeRenderToFile", bytes)
    lr, fnl, _tier = _dt_sl_render_lines(result, bytes)   # classify FIRST (F4)
    xtmp = _dt_slide_stage_bytes(dirname(apath), bytes)
    sctmp = try
        _dt_slide_stage_sidecar(apath * ".slideruns.json", "writeRenderToFile",
                                sr[1], sr[2], lr, fnl, "usual")
    catch
        rm(xtmp; force = true)           # FR1#2: no one-sided temp orphan
        rethrow()
    end
    _dt_slide_publish_pair(apath, xtmp, sctmp)
    path
end

"""
    writeMarkedSourceToFile(path, bytes; config=GoMeta.GoMetaConfig(), slide=nothing) -> path

IS: the marked-source file writer — writes the given source `bytes` (a GoMeta-marked
file: metaLines, inline metaSegments, content) to `path`, VERBATIM byte-copy.
DOES: with `slide` set, additionally emits `path * ".slideruns.json"` from its OWN
`goMeta(bytes; config)` parse: marker tokens (`#~`, `#~2`, `#~!`, close-marker `#]`,
and the cfam/latex families under their configs) → `marker`; the rest of the
metaSegment → `payload`; engine-`:comment` segments (incl. comment tails inside
metaLines) → `comment`; Code → `code`; Text → `text`; indentation joins its
segment's run. `hideprefix` is NEVER emitted here — rule 6.1 is render-only (a
source line beginning with the hide marker IS a comment). A refused or thrown parse
(e.g. a malformed metaLine) degrades to whole-line `neutral` — the file is still
written, the sidecar never errors on content.
REASONING: the deck's input boxes show marked SOURCE; the §4.4 fixture's
"`#~2` = a single marker run" is satisfiable only on this surface (the render shows
`## #~2`). PURPOSE: any marked input becomes deck-ready colored-run data.

PARAMETERS — which behavior each triggers:
- `path::AbstractString` — the output file; sidecar at `path * ".slideruns.json"`.
- `bytes::AbstractVector{UInt8}` — the EXACT source bytes (pass `read(file)`);
  written verbatim; `final_newline` is read from them.
- `config::GoMeta.GoMetaConfig = GoMeta.GoMetaConfig()` — the parse config for the
  sidecar's classification pass ONLY (the written bytes are untouched). Selects the
  comment/marker family: the default parses julia-flavor (`#~` / `## `); pass e.g.
  `GoMetaConfig(flavor_tag = :c)` for `//~` / `//# ` sources or `:latex` for
  `%~` / `%% ` (live v0.3 surfaces — classification is flavor-generic, never
  extension-inferred).
- `slide::Union{Nothing,Symbol} = nothing` — as [`writeBlsStructureToFile`](@ref):
  `nothing` = X only AND a stale `X.slideruns.json` beside the path is RETIRED
  (removed — F5); a scheme Symbol = X + sidecar published as a staged pair (border
  `"usual"`); unknown Symbol ⇒ ArgumentError naming the five supported values.
"""
function writeMarkedSourceToFile(path::AbstractString, bytes::AbstractVector{UInt8};
                                 config::GoMeta.GoMetaConfig = GoMeta.GoMetaConfig(),
                                 slide::Union{Nothing,Symbol} = nothing)
    sr = slide === nothing ? nothing : _dt_slide_resolve(slide)
    ## F6: snapshot the caller's (possibly mutable/aliased) vector ONCE at entry;
    ## every later stage uses `snap` — and still copies per goMeta call (the
    ## String-takeover class lives inside the engine; snapshot-once ≠ hand it out)
    snap = Vector{UInt8}(bytes)
    if sr === nothing
        _dt_slide_retire_sidecar(path)   # F5: retire FIRST — a failing write must
        write(path, snap)                # never leave a stale claim beside partial X
        return path
    end
    apath = abspath(String(path))        # ONE resolution for every fs op (L3#10)
    _dt_slide_check_dest("writeMarkedSourceToFile", apath)
    _dt_sl_utf8_preflight("writeMarkedSourceToFile", snap)
    lr = nothing
    fnl = !isempty(snap) && snap[end] == 0x0a
    r = try
        GoMeta.goMeta(copy(snap); config)
    catch err
        err isa InterruptException && rethrow()
        nothing
    end
    ls, _ = _dt_sl_splitlines(copy(snap))   # the file's OWN line split: the classifier's source-line count (R-V04B-85 (D)) and the fidelity gate's yardstick
    r === nothing || (lr = _dt_sl_source_lines(r, length(ls)))
    ## fidelity-gate the classification against the WRITTEN bytes (R1#2 — the
    ## same principle as the T1 gate): a drifted engine whose collectedLines
    ## diverge from the file's own line split degrades to neutral, never lies
    if lr !== nothing
        (length(lr) == length(ls) &&
         all(join(first.(lr[i])) == ls[i] for i in eachindex(ls))) || (lr = nothing)
    end
    if lr === nothing
        lr, fnl = _dt_sl_neutral_lines(copy(snap))
    end
    xtmp = _dt_slide_stage_bytes(dirname(apath), snap)   # classify-first done (F4)
    sctmp = try
        _dt_slide_stage_sidecar(apath * ".slideruns.json", "writeMarkedSourceToFile",
                                sr[1], sr[2], lr, fnl, "usual")
    catch
        rm(xtmp; force = true)           # FR1#2: no one-sided temp orphan
        rethrow()
    end
    _dt_slide_publish_pair(apath, xtmp, sctmp)
    path
end

#########################################################################################
##  §G — the drift alarm
#########################################################################################

"""
    devtools_selfcheck() -> true

IS: the internal-surface drift alarm (design §2). DOES: runs `goMeta` on a tiny inline
marked input and asserts, LOUDLY, everything these tools stand on: the walkable
`result.blsComponentTree` tree + engine-true census, evals rows present and 100%
anchored, each with content through the door, and both printers rendering non-empty output to
plain AND colored IO without throwing. REASONING: the tools read the delivered part's BLS internals
— parser names non-public until the door of stage 2 (R-V04B-45; R-V04B-58) — and the package snapshot is refreshed wholesale — after every refresh, RUN THIS; a
broken internal surface must fail here, not silently mis-render during play.
"""
function devtools_selfcheck()
    ## the one-path checks (R-V04B-24 obligation 7): the basic renderer is loaded through
    ## devtools/load_basic_renderer.jl, once, as Main.BasicRenderer, with ONE `outputs` method
    (isdefined(Main, :BasicRenderer) && isdefined(Main, :_BASIC_RENDERER_LOADED)) ||
        error("devtools_selfcheck: the basic renderer is not loaded through devtools/load_basic_renderer.jl")
    length(methods(Main.BasicRenderer.outputs)) == 1 ||
        error("devtools_selfcheck: BasicRenderer.outputs has more than one method")
    parentmodule(only(methods(Main.BasicRenderer.outputs))) === Main.BasicRenderer ||
        error("devtools_selfcheck: BasicRenderer.outputs is not defined in Main.BasicRenderer")
    # :label1 = whitelist member; the inline head(…) metaSegment mints a Segment-grain
    # (0x01) row — keeping the Segment-attachment path under the drift alarm too
    src = "#~1 :label1\n# a Text line\nx = 1 #~ head(\"selfcheck head\", 2)\n"
    r = GoMeta.goMeta(Vector{UInt8}(codeunits(src)))
    r.status == GoMeta.PROCESS_OK || error("devtools_selfcheck: PROCESS_ERROR on the inline input")
    doc = _dt_doc(r; name = "selfcheck")
    doc.ok || error("devtools_selfcheck: File root not walkable")
    # EXACT pins for the fixed inline fixture (impl CrossReview T1-L3 #6: a weakened
    # census / dropped rows / shrunk key set must RED here, not render silently thinner)
    _dt_census(doc) == (3, 3, 2) ||
        error("devtools_selfcheck: census drifted (got $(_dt_census(doc)), pinned (3, 3, 2))")
    length(keys(_DT_BLS.CmpntNamedInt)) == 9 ||
        error("devtools_selfcheck: CmpntNamedInt key census changed (pinned 9, got " *
              "$(length(keys(_DT_BLS.CmpntNamedInt)))) — REVIEW the tools, then re-pin")
    ## re-pinned 44 -> 45 at the v0.3.1 snapshot refresh (the new :ignoreMetaContent
    ## inert-marker flag; reviewed: _dt_trueflags iterates keys() dynamically — no
    ## positional assumption anywhere in the tools).
    length(keys(_DT_BLS.ComponentSettribute)) == 45 ||
        error("devtools_selfcheck: ComponentSettribute key census changed (pinned 45, got " *
              "$(length(keys(_DT_BLS.ComponentSettribute)))) — REVIEW the tools, then re-pin")
    rows = _dt_eval_rows(doc)
    all(x -> x.comp !== nothing, rows) ||
        error("devtools_selfcheck: unanchored row — handle resolution drifted")
    sort([string(x.attr) for x in rows]) ==
        ["head_2", "label_label1", "label_label1", "label_label1", "label_label1"] ||
        error("devtools_selfcheck: evals rows drifted (attrs = $(sort([string(x.attr) for x in rows])))")
    sort([_dt_grain(x.comp) for x in rows]) == ["Block", "Block", "Block", "Line", "Segment"] ||
        error("devtools_selfcheck: row anchoring drifted (got " *
              "$(sort([_dt_grain(x.comp) for x in rows])))")
    all(x -> !isempty(_DT_BLS.content(doc.ps, x.comp)), rows) ||
        error("devtools_selfcheck: a row's Component has no content through the door — content derivation drifted")
    for renderer in (print_BLS_Component_Tree, print_altValues_evals)
        for colored in (false, true)
            buf = IOBuffer()
            renderer(IOContext(buf, :color => colored), r)
            position(buf) > 0 || error("devtools_selfcheck: empty render from $renderer (colored=$colored)")
        end
    end
    buf = IOBuffer()
    print_altValues_evals(buf, r; include_empty = true)
    out = String(take!(buf))
    occursin("[Segment #", out) && occursin("head_2", out) ||
        error("devtools_selfcheck: the :tree render lost the Segment-attachment path")
    occursin("Int64", (buf2 = IOBuffer(); print_BLS_Component_Tree(buf2, r); String(take!(buf2)))) ||
        error("devtools_selfcheck: the MIX typed dump lines vanished")

    ## ── §H slide-surface pins (D-6(a) rider: every NEW internal read the slide path
    ## adds is pinned here or battery-covered — T1's re-parse arm lives in probe §16 —
    ## so a drifted engine fails LOUDLY, never mis-roles) ─────────────────────────────
    F = _DT_BLS.flavor(r.blsComponentTree)   # the record through the door; the five promised fields pinned
    (F.lead == "#" && F.hide_marker == "## " && F.hide_fold_prefix isa AbstractString && F.re_meta_leaded isa Regex &&
     F.flavor_tag === :julia) ||
        error("devtools_selfcheck: the flavor record drifted (lead/hide_marker/hide_fold_prefix/re_meta_leaded/flavor_tag)")
    _DT_BLS.endsWithNewline(r.blsComponentTree) isa Bool ||
        error("devtools_selfcheck: BLS.endsWithNewline drifted")
    (_DT_BLS.isHorizontalSpace(' ') && _DT_BLS.isHorizontalSpace('\t') && _DT_BLS.isHorizontalSpace('\u00a0') &&
     !_DT_BLS.isHorizontalSpace('x') && !_DT_BLS.isHorizontalSpace('\n')) ||
        error("devtools_selfcheck: the engine [\\h] delimiter class drifted (isHorizontalSpace, the door's name; NBSP must delimit)")
    (F.flavor_tag in (:julia, :c, :latex) &&   # the registry identity (`flavor_for`) left the self-check at commit 0 — a parser-internal read (R-V04B-80 (2)(iii))
     isempty(GoMeta.validate_config(GoMeta.GoMetaConfig(flavor_tag = F.flavor_tag)))) ||
        error("devtools_selfcheck: the delivered tree's flavor record does not round-trip through its flavor_tag into a valid config (the T1 re-parse arm rebuilds its config from it)")
    ## fate ladder + render transformation classes (the render writer's derivation)
    rf = GoMeta.goMeta(Vector{UInt8}(codeunits("#~ discard{ isCode }\nx = 1 #~ hide\ny = 2\n")))
    rf.status == GoMeta.PROCESS_OK || error("devtools_selfcheck: fate fixture refused")
    String(copy(Main.BasicRenderer.outputs(rf).render_bytes)) == "#~ discard{ isCode }\n## x = 1 ## #~ hide\n" ||
        error("devtools_selfcheck: the hide/discard render transformation drifted — REVIEW the slide derivation, then re-pin")
    fates = Tuple{Int,Symbol}[]
    _dt_sl_walk(rf.blsComponentTree) do line, block, file, ln
        push!(fates, (ln, _dt_sl_fate(rf, line)))
    end
    sort(fates) == [(1, :show), (2, :hide), (3, :discard)] ||
        error("devtools_selfcheck: the fate ladder drifted (got $(sort(fates)))")
    ## :comment settribute at Line grain, julia strictness split
    rc = GoMeta.goMeta(Vector{UInt8}(codeunits("## c\n### banner\n")))
    ccm = Bool[]
    _dt_sl_walk(rc.blsComponentTree) do line, block, file, ln
        push!(ccm, _DT_BLS.getElement(line, :comment))
    end
    ccm == [true, false] ||
        error("devtools_selfcheck: the :comment settribute strictness drifted (got $ccm)")
    ## segment byte offsets (1-based inclusive; emoji multi-byte pin) + the Line texts through the door
    re = GoMeta.goMeta(Vector{UInt8}(codeunits("x = \"🍒🍒\" #~ hide\n")))
    spans = Tuple{Int,Int}[]
    texts = String[]
    _dt_sl_walk(re.blsComponentTree) do line, block, file, ln
        push!(texts, String(_DT_BLS.content(re.blsComponentTree, line)))
        for seg in _DT_BLS.children(re.blsComponentTree, line)
            push!(spans, (Int(_DT_BLS.getElement(seg, :startMainStr)),
                          Int(_DT_BLS.getElement(seg, :stopMainStr))))
        end
    end
    spans == [(1, 15), (16, 22)] ||
        error("devtools_selfcheck: segment byte offsets drifted (got $spans, pinned [(1,15),(16,22)])")
    texts == ["x = \"🍒🍒\" #~ hide"] ||
        error("devtools_selfcheck: the Line texts through the door (BLS.content) drifted")
    ## capture smoke: the run annotation is TOTAL — concat of runs+newlines == the
    ## plain render of the same call, byte-for-byte; roles stay in the closed set
    capr = _dt_slide_cap()
    print_BLS_Component_Tree(_dt_slide_capio(capr), r)
    lr, fnl = _dt_slide_lines(capr)
    plainb = IOBuffer(); print_BLS_Component_Tree(IOContext(plainb, :color => false), r)
    join([join(first.(l)) for l in lr], "\n") * (fnl ? "\n" : "") == String(take!(plainb)) ||
        error("devtools_selfcheck: slide capture lost bytes (concat != plain render)")
    all(role in _DT_SLIDE_ROLE_ORDER for l in lr for (_, role) in l) ||
        error("devtools_selfcheck: slide capture emitted a role outside the closed vocabulary")
    ## sidecar smoke (the FULL byte gold lives in the battery's python sweep): the
    ## §4.4-shaped micro fixture through the source writer, key pins + marker run
    mktempdir() do tmp
        p = joinpath(tmp, "m.jl")
        writeMarkedSourceToFile(p, Vector{UInt8}(codeunits("#~2\n")); slide = :gometa_dark)
        read(p) == Vector{UInt8}(codeunits("#~2\n")) ||
            error("devtools_selfcheck: writeMarkedSourceToFile changed the written bytes")
        sc = read(p * ".slideruns.json", String)
        for pin in ("\"format_version\": 1", "\"tool\": \"writeMarkedSourceToFile\"",
                    "\"scheme\": \"gometa-dark\"", "\"background\": \"201D1D\"",
                    "\"blank\": \"FFD6D6\"", "\"border\": \"usual\"", "\"final_newline\": true",
                    "{ \"text\": \"#~2\", \"role\": \"marker\", \"color\": \"FF1FA9\", \"bold\": false, \"size_pt\": 13 }",
                    "{ \"text\": \" 1 \", \"role\": \"gutter\", \"color\": \"706D6D\", \"bold\": false, \"size_pt\": 13, \"synthetic\": true }")
            occursin(pin, sc) || error("devtools_selfcheck: sidecar smoke lost the pin $(repr(pin))")
        end
        endswith(sc, "] }\n") || error("devtools_selfcheck: sidecar must end '] }' + one newline")
    end
    ## ── §I comparison-form pins (stage 4; R-V04B-36): the form is deterministic, carries one C line per Component and
    ## four A lines per non-File Component on the inline fixture, names a Segment by its line and CHARACTER span, and is
    ## sorted — a drifted serializer fails LOUDLY here before the twelve forms (the reference altValues) move ──────────
    cf = comparisonForm(r; name = "selfcheck", at = "-")
    cf == comparisonForm(r; name = "selfcheck", at = "-") ||
        error("devtools_selfcheck: the comparison form is not deterministic")
    cfl = split(chomp(cf), '\n')
    startswith(cfl[1], "# GoMeta comparison form v1 | selfcheck | produced by GoMeta v0.4 at - | 9 Components | 32 answer lines") ||
        error("devtools_selfcheck: the comparison form's header drifted ($(cfl[1]))")
    (count(l -> startswith(l, "C | "), cfl) == 9 && count(l -> startswith(l, "A | "), cfl) == 32) ||
        error("devtools_selfcheck: the comparison form's line census drifted (pinned 9 C + 32 A)")
    cfl[2:end] == sort(cfl[2:end]) || error("devtools_selfcheck: the comparison form's lines are not sorted")
    occursin("\nC | Segment | 3:7-34 | Line 3-3 | 2 | - | Meta | ", cf) && occursin("\nC | Segment | 3:1-6 | Line 3-3 | 1 | - | Code | ", cf) ||
        error("devtools_selfcheck: the comparison form's Segment keys drifted (pinned 3:1-6 and 3:7-34 under Line 3-3)")
    occursin("\nC | File | 1-3 | - | - | Block 1-1;Block 2-2;Block 3-3 | - | ", cf) ||
        error("devtools_selfcheck: the comparison form's File line drifted")
    occursin("\nA | Segment | 3:7-34 | heading | \"selfcheck head\" | Segment 3:7-34\n", cf) && occursin("\nA | Line | 3-3 | heading | null | default\n", cf) ||
        error("devtools_selfcheck: the inline heading's answer lines drifted (pinned on the MEASURED behaviour: the Segment answers by its OWN key; its Line does not carry it — R-V04B-50 leaves the inline arm untouched; the build's sitting item A6 asks his word)")
    occursin("\nA | Block | 1-1 | labels | {label1} | Block 1-1\n", cf) ||
        error("devtools_selfcheck: the Labels answer line drifted (pinned: the set {label1}, own)")
    cfe = comparisonForm(re; name = "emoji", at = "-")
    occursin("C | Segment | 1:1-9 | ", cfe) && occursin("C | Segment | 1:10-16 | ", cfe) ||
        error("devtools_selfcheck: the comparison form's Segment spans are not in characters (pinned 1:1-9 and 1:10-16 on the emoji fixture)")
    true
end

#########################################################################################
##  §I — THE COMPARISON FORM (stage 4 of the v0.4 build; R-V04B-36 — the reference set's comparison form, so that
##  GoMetaRetro is compared with v0.4 by CONTENT, never by bytes or Julia types; his §68–§71 of 2026-09-17; the
##  definition: tests/comparison/README.md — written ONCE, the grammar fixed by what this section emits).
##  IS:   the v0.4 lane's adapter (R-V04B-36 (c)): ONE content-keyed TEXT form per input — one line per Component
##        (kind, span, the parent's key, the position among the parent's children, the children's keys, the content
##        type, the flags of his approved table) and one line per Component per Alterant (the resolved value and its
##        SOURCE as the deciding Component's own key, or its level: user / file / default); ordinals, ids, handles and
##        Julia types never appear. The File has its Component line and NO answer lines (the session's narrowing of
##        R-V04B-36 (a) — nothing is built for the File before his word, card 6 / Q10).
##  DOES: walks the delivered tree through the door (`root`, `children`, `parent`, `kind`, `content`, `getElement`),
##        asks the Engine's answer through `answersFor` (= `answerFor` per registered Alterant), and emits the lines
##        SORTED by code point under one header line that names the input, the producing commit and the counts.
##  REASONING: the two lanes may deliver different shapes and types (his §70 (1)); only a projection keyed by
##        content can be compared. A Segment's span is given in CHARACTERS of its line (the parser's byte offsets
##        converted on the line's own bytes — the definition's recommended unit, his to confirm).
##  PURPOSE: the twelve forms under tests/comparison/ — v0.4's reference altValues in his terms of 2026-09-29 (`regenerate.jl`) — and the first comparator
##        `devtools/compare_forms.sh` (a sorted-text diff). A development tool: nothing under src/ reads it.
#########################################################################################
const _CF_VERSION = 1
const _CF_SEP = " | "
const _CF_EXCLUDED_FLAGS = (:hide, :show, :discard)   # Visib in the BLS tree — not compared (his §69 item 5; D-R-7)

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

## the flags of his approved table that are TRUE on the Component: every ComponentSettribute flag but hide/show/discard,
## qualified `component.<name>`, sorted by code point, joined by `,`; `-` when none. The content flag vector
## (`contentSettributeBitVec`) has no read through the door and no writer in the parser (measured 2026-10-02,
## receipts/S8-branch/PROBES-s4-form-facts.txt) — no `content.<name>` flag can be emitted today (a question for his word).
function _cf_flags(c)
    names = String[]
    for k in keys(_DT_BLS.ComponentSettribute)
        k in _CF_EXCLUDED_FLAGS && continue
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
    for (alt, a) in GoMeta.answersFor(doc.r, c)
        push!(lines, join(["A", _cf_kind(c), _cf_span(doc, c), String(alt), _cf_value(a.value), _cf_source(doc, c, a)], _CF_SEP))
        n += 1
    end
    n
end

"""
    comparisonForm(result; name = "", at = "-") -> String

IS: the comparison form of ONE `goMeta` result (R-V04B-36; the definition `tests/comparison/README.md`) — the text
the twelve forms under `tests/comparison/` hold (v0.4's reference altValues, his term of 2026-09-29).
DOES: one header line `# GoMeta comparison form v1 | <name> | produced by GoMeta v0.4 at <at> | <nC> Components |
<nA> answer lines`, then every line of the form SORTED by code point: `C | kind | span | parent key | position |
children keys | content type | flags` per Component, `A | kind | span | Alterant | value | source` per Component
per Alterant (the File has none). Throws on a delivery whose tree cannot be walked.
REASONING: the lines carry content keys only, so two lanes' projections compare as text; sorting makes the
order a non-fact. PURPOSE: `writeComparisonFormToFile`, the `comparison` verb, `tests/comparison/regenerate.jl`.
"""
function comparisonForm(result::GoMeta.GoMetaDelivery; name::AbstractString = "", at::AbstractString = "-")
    doc = _dt_doc(result; name = name)
    doc.ok || error("comparisonForm: the delivered tree cannot be walked (status $(result.status))")
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

IS: the comparison form's file writer (the reference set's producer — stage 4 of the v0.4 build; R-V04B-36).
DOES: writes `comparisonForm(result; name, at)` to `path`, verbatim; returns `path`. No slide keyword — the form is
a comparison surface, not a share-view. PURPOSE: `tests/comparison/regenerate.jl` writes the twelve through it.
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
##  2026-09-12 — R-V04B-24's tidy-up row, the owner's OWNER-WORDS §18 item 2 "we may remove
##  'devtools/gometa.jl' entirely?"; the file is deleted): the eight verbs (the eighth, `comparison`, since stage 4 of the v0.4 build)
##      julia --startup-file=no --project=$GM/tests $GM/devtools/devtools.jl <verb> <file>
##      tree · segments · evals · render · trace · evals-tree · bls-tree · comparison (stage 4, R-V04B-36: the comparison form, §I)
##  IS: the smallest complete consumer of the two containers — `altValues_evals` (the excerpts through the
##  door: `BLS.content` of each row's resolved Component, since commit 9b) and the development tool's (tree, render) pair (`Main.BasicRenderer.outputs`,
##  loaded through the ONE path at this file's top). DOES: runs goMeta on ONE file; status + diagnostics
##  to stderr, the surface to stdout; exit 0 = PROCESS_OK, 1 = a non-OK result, 2 = usage. The `trace`
##  verb decodes each row's cell_handle with the tool's OWN `_dt_decode` (§C) — the former CLI's
##  duplicate decoders (its rd_u16/rd_u32/rd_steps/decode_handle) are gone: ONE copy. REASONING: the
##  block runs ONLY when this file is the program (`abspath(PROGRAM_FILE) == @__FILE__`), never when it
##  is `include`d (the Play's frozen copy, the battery, the site's capture script include this file and
##  see definitions only). Evaluates, never executes.
#########################################################################################
const _DT_VERBS = ("tree", "segments", "evals", "render", "trace", "evals-tree", "bls-tree", "comparison")

function _dt_cli_usage()
    println(stderr, "usage: devtools.jl <", join(_DT_VERBS, "|"), "> <file>")
    exit(2)
end

_dt_cli_grain_name(g) = g == 0x01 ? "Segment" : g == 0x0a ? "Line" : g == 0x46 ? "Block" :
                        g == 0xd2 ? "File" : g == 0xe0 ? "USER_CONTEXT" : ""
_dt_cli_store_name(s) = s == 0x01 ? "direct" : s == 0x02 ? "insert" : s == 0x00 ? "TRUNCATED" : "?"
_dt_cli_fmt_steps(v) = "[" * join(["($(_dt_cli_store_name(s)),$(Int(o)))" for (s, o) in v], " ") * "]"

function _dt_cli_main(args)
    length(args) == 2 || _dt_cli_usage()
    cmd, path = args[1], args[2]
    cmd in _DT_VERBS || _dt_cli_usage()
    isfile(path) || (println(stderr, "devtools: no such file: ", path); exit(2))

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
        doc = _dt_doc(r; name = basename(path))                 # the rows resolved to their Components (§C); the excerpt through the door
        rows = _dt_eval_rows(doc)
        isempty(rows) && println(stderr, "(no evals rows — no LIVE metaLine on any surface)")
        for row in rows
            cell = replace(row.comp === nothing ? "" : _dt_content(doc, row.comp), '\n' => '⏎')   # an unanchored row (the user-context plane): no piece in the tree
            println(rpad(String(row.attr), 14), " => ", rpad(repr(row.value), 40), " (", row.polarity, ")  \"",
                    first(cell, 60), length(cell) > 60 ? "…\"" : "\"")
        end
    elseif cmd == "comparison"
        ## the comparison form (stage 4; R-V04B-36; §I): the header names the input, the producing commit unknown here (`-`)
        print(comparisonForm(r; name = basename(path), at = "-"))
    elseif cmd == "evals-tree"
        ## the owner's print tool, FULL form (R-DEV-4's option): every Component visible,
        ## absence labelled "(no evals — defaults apply)", every row with its decoded handle
        print_altValues_evals(stdout, r; layout = :tree, include_empty = true,
                              show_handles = true, _name = basename(path))
    elseif cmd == "bls-tree"
        ## the owner's tree printer (R-DEV-1 :mix): tree rows + typed named-int / settribute dumps
        print_BLS_Component_Tree(stdout, r; style = :mix, _name = basename(path))
    elseif cmd == "trace"
        doc = _dt_doc(r; name = basename(path))                 # the rows resolved to their Components (§C); the excerpt through the door
        rows = _dt_eval_rows(doc)
        isempty(rows) && println(stderr, "(no evals rows — no LIVE metaLine on any surface)")
        for row in rows
            cell = replace(row.comp === nothing ? "" : _dt_content(doc, row.comp), '\n' => '⏎')   # an unanchored row (the user-context plane): no piece in the tree
            println(rpad(String(row.attr), 14), " => ", rpad(repr(row.value), 40), " (", row.polarity, ")  \"",
                    first(cell, 60), length(cell) > 60 ? "…\"" : "\"")
            d = _dt_decode(row.handle)
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
