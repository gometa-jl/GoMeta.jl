# annotations.jl — the evals surface: the per-cell verdict map + its canonical serialization.
#
# IS: the home of GoMeta's `altValues_evals` surface — the deterministic, content-hashable,
#     final-verdicts-only per-cell verdict map `(cell_handle, attr, value, polarity)` a `goMeta`
#     run yields alongside the development tool's (tree, render) pair (`devtools/basic_renderer.jl`)
#     (docs/public-api.md §1.3; docs/CANONICAL-OUTPUT.md §4). Verdicts have no manifestation in
#     either tuple half (the tree is verdict-free; the render reflects only Visib effects), so
#     this surface is where label / Visib / Id outcomes become observable — the query-facing
#     write payload, GoMeta's semantic deliverable.
# DOES: (1) `cell_content_bytes(parse, component)` — the grain-aware `cell_handle` extractor:
#     the VERBATIM content bytes of a BLS cell (Block = its joined line span, Line = its full
#     source line, Segment = a byte-offset slice of its own line), byte-sliced so non-ASCII
#     content stays byte-faithful, NO hashing core-side (the core stays dependency-free); empty
#     for a structural cell that addresses no content. (2) `capture_verdicts!(st, cell)` —
#     called from the apply sites right after a cell's alterant state is finalized and BEFORE
#     the next slot reset wipes it; records the cell's final label / Visib / Id verdicts into
#     the `EvalStore`, deduped per `(cell_handle, attr)` with later-wins supersede.
#     (3) `altValues_evals(result)` — the exported accessor: sorts by `(cell_handle, attr, value)`,
#     returns the pinned `Vector{Tuple{Vector{UInt8},Symbol,Any,Bool}}` — empty when no metaLine
#     exists on any surface (the fed profile is a metaLine body; un-fed meta-free input yields
#     the empty vector) — and is pure + read-only on `result`. (4) `serialize_evals` — the
#     canonical, deterministic, binary-safe byte forms (one verdict per line, hex-encoded
#     handle; the golden layer's form appends the content-fingerprint hex column) pinned by the
#     read-side golden tests.
# REASONING: final results are observable, deterministic, and hash-stable.
#     The store keys by a NORMALIZED STRUCTURAL occurrence handle (src/occurrence.jl), so two
#     distinct cells never share a slot even with byte-identical content; the verbatim content
#     bytes ride each record as its find-again fingerprint, and a value-CHANGING re-apply of
#     the SAME occurrence emits the non-fatal `WARN_VERDICT_COLLISION` diagnostic rather than
#     masking the supersede (docs/public-api.md §3). A
#     verdict on a cell nested in a `:discard`-skipped ancestor still appears here even though
#     the render omits that cell — `altValues_evals` is the verdict truth; the render is the
#     share-target bytes.
# PURPOSE: the machine-readable RESULTS surface of a `goMeta` run — pinned, attributed,
#     deterministic, hash-stable; its determinism + totality laws are asserted by
#     the golden layer (tests/golden/golden_tests.jl), and its
#     serialization anchors the annotations goldens read by tests/golden/golden_tests.jl.

# --------------------------------------------------------------------------------------------------------
# The cell_handle — the verbatim content bytes of a cell (COMPONENT-grain; no hashing core-side)
# --------------------------------------------------------------------------------------------------------
"""
    cell_content_bytes(parse::BLS.ParseState, component) -> Vector{UInt8}

The VERBATIM content bytes of a BLS `component` — its `cell_handle`. The handle is
the raw content bytes (NOT a hash — the core stays dependency-free, not even the SHA stdlib; an adapter layer
can wrap the SAME bytes as `CellID(sha256(bytes))` without re-extraction). The grain is COMPONENT-grain
(Block / Line / Segment); "Segment-else-Line" is the LEAF-grain phrasing — a Block-level verdict keys on
whole-block content (per-block verdicts). Grain-aware extraction, because `:startMainStr`/`:stopMainStr` mean
DIFFERENT things per grain:

- **Block** (`Component{70}`): `:idxString == 0`; `:startMainStr`/`:stopMainStr` are the block's LINE-NUMBER
  range (the Block start/stopMainStr writes in parseBLS) ⇒ the content is `collectedLines[startMainStr:stopMainStr]` joined with `\\n`.
  Block bounds are COMPLETE when the parse returns (the parse-side CLOSURE law closes the final Block at
  the effective parsed end); an unfinalized/out-of-range span addresses no content (fail-closed, empty).
- **Line** (`Component{10}`): the cell is the FULL source line. `:inputLineNum` maps the Line to its source
  line robustly — even a MULTI-SEGMENT line (`:idxString == 0`, content split into Segments) carries its
  source-line number in `:inputLineNum` (the addChildComponentTo idNum writes in parseBLS), where `:idxString` cannot. (A single-segment
  line's `:idxString` equals its `:inputLineNum`, so this is uniform.) The whole source line, including any
  inline `#~` meta, is the verbatim content the verdict addresses.
- **Segment** (`Component{1}`) and any other grain: a byte-offset span into its own source line —
  `codeunits(collectedLines[idxString])[startMainStr:stopMainStr]` (negative `idxString` ⇒ the `addedStrings`
  insert-store). BYTE-sliced (not char-indexed) so a non-ASCII line is byte-faithful — the slicing is
  UTF-8-correct on multi-byte lines. (The corpus capture path never passes a bare Segment — a Segment-grain verdict is
  keyed on its Line.)

Returns an empty `Vector{UInt8}` for a structural component that addresses no content (a Block with a `0`/
out-of-range line span, or a Segment placeholder with no string) — `capture_verdicts!` skips those. A genuinely
empty source line (a blank line) is also empty here; the corpus apply never leaves a verdict on a blank line
(blank lines detach / start new blocks — SYNTAX-AND-SEMANTICS §3), so no real verdict is lost.
"""
function cell_content_bytes(parse::BLS.ParseState, component::BLS.AbstractComponent)
    cni       = component.cmpntNamedInt
    startMain = BLS.getElement(cni, :startMainStr)
    stopMain  = BLS.getElement(cni, :stopMainStr)
    if component isa BLS.Block
        # Block: the span is a LINE-NUMBER range into collectedLines. Block bounds are COMPLETE
        # when the parse returns (the parse-side CLOSURE law closes the final Block at the
        # effective parsed end), so an unfinalized 0 bound addresses NO content (fail-CLOSED via
        # the range guard below) — never expanded to EOF: excluded lines cannot leak in here.
        stop = stopMain
        (1 <= startMain && startMain <= stop && stop <= length(parse.collectedLines)) || return UInt8[]
        return Vector{UInt8}(codeunits(join(view(parse.collectedLines, startMain:stop), '\n')))
    elseif component isa BLS.Line
        # Line: the FULL source line. A NEGATIVE idxString is an INSERTED Line — its content lives in the
        # addedStrings insert-store (symmetric with the Segment branch). Otherwise the source line via
        # :inputLineNum (robust for multi-segment lines where idxString == 0, where idxString cannot locate it).
        idxString = BLS.getElement(cni, :idxString)
        if idxString < 0
            (-idxString <= length(parse.addedStrings)) || return UInt8[]
            return Vector{UInt8}(codeunits(parse.addedStrings[-idxString]))
        end
        iln = BLS.getElement(cni, :inputLineNum)
        (1 <= iln <= length(parse.collectedLines)) || return UInt8[]
        return Vector{UInt8}(codeunits(parse.collectedLines[iln]))
    end
    # Segment (and any other grain): a byte-offset span into its own source line.
    idxString = BLS.getElement(cni, :idxString)
    (idxString != 0 && 1 <= startMain && startMain <= stopMain) || return UInt8[]
    # bounds-guard the store lookup so a malformed idxString returns UInt8[] (the docstring's total-return
    # contract), never a BoundsError.
    inbounds = idxString > 0 ? idxString <= length(parse.collectedLines) : -idxString <= length(parse.addedStrings)
    inbounds || return UInt8[]
    src = idxString > 0 ? parse.collectedLines[idxString] : parse.addedStrings[-idxString]
    cu  = codeunits(src)
    stopMain <= length(cu) || return UInt8[]
    # stopMain is the final character's START byte (IV-1); widen to its LAST byte so a
    # multibyte final character is kept whole (raw codeunit ranges do not widen the way
    # String ranges do). nextind is total from any in-bounds byte index, malformed included.
    return Vector{UInt8}(cu[startMain:(nextind(src, stopMain) - 1)])
end

# --------------------------------------------------------------------------------------------------------
# Verdict capture — record a cell's FINAL verdicts before the slot wipe (called from the apply sites)
# --------------------------------------------------------------------------------------------------------
"""
    _put_verdict!(st::ProcessState, handle, attr::Symbol, value, polarity::Bool, content) -> nothing

Record one final verdict into `st.verdicts`, DEDUPED per `(cell_handle, attr)`: a later put for the same
occurrence+attribute SUPERSEDES the earlier one (later wins). The store therefore holds at most one record
per `(cell_handle, attr)` by construction.

**Occurrence-addressing + the collision signal.** `handle` is the `key_bytes` of the cell's NORMALIZED
STRUCTURAL occurrence key (src/occurrence.jl) — two DISTINCT cells never share a slot, even with
byte-identical content (the distinct-cell content-collision class of a purely content-keyed store cannot
occur by construction; PRECISE BOUND: this holds for WELL-FORMED keys — two DEGENERATE truncated-walk
keys could alias each other, a case no real parse produces). A slot match here is therefore the SAME
occurrence re-applied; a value-CHANGING supersede is a genuine conflicting re-apply (applied-state-wins)
and still records the non-fatal `:warning` Diagnostic (`WARN_VERDICT_COLLISION`) — surfaced, never
masked. The verbatim `content` bytes ride each record as the demoted find-again fingerprint (plain
bytes — no hashing core-side; an adapter layer that wraps handles as digests is the natural home for a
hashing scheme). O(n) per put (a linear scan); acceptable at v0 (small files; a Dict-keyed store gives
O(1) later).
"""
function _put_verdict!(st::ProcessState, handle::Vector{UInt8}, attr::Symbol, value, polarity::Bool,
                       content::Vector{UInt8})
    recs = st.verdicts.records
    @inbounds for i in eachindex(recs)
        r = recs[i]
        if r.attr === attr && r.cell_handle == handle
            # v0.2 KEY SWAP: `handle` is now the OCCURRENCE-key bytes, so a slot match here is the
            # SAME structural occurrence by construction — the distinct-cell content-collision arm
            # of the old WARN_VERDICT_COLLISION is IMPOSSIBLE by construction (asserted by the
            # constructed rr48 fixtures in tests/golden);
            # what remains is the true same-cell conflicting re-apply (a value-CHANGING supersede =
            # a genuine re-apply under applied-state-wins, int-6) — still surfaced, never masked.
            if !isequal(r.value, value) || r.polarity != polarity
                push!(st.diagnostics, Diagnostic(:WARN_VERDICT_COLLISION, :warning,
                    "altValues_evals: occurrence received conflicting verdicts for attr=$(attr) " *
                    "($(repr(r.value)) -> $(repr(value))); a same-occurrence conflicting re-apply " *
                    "(later wins; applied-state-wins).",
                    handle))
            end
            recs[i] = EvalRecord(handle, attr, value, polarity, content)   # supersede (later wins)
            return nothing
        end
    end
    push!(recs, EvalRecord(handle, attr, value, polarity, content))
    return nothing
end

"""
    capture_verdicts!(st::ProcessState, cell; origin = nothing) -> nothing

Capture `cell`'s FINAL alterant verdicts from `st.working` into `st.verdicts`, keyed by the cell's
NORMALIZED STRUCTURAL occurrence key (v0.2 CH-1: `key_bytes(occurrence_key(parse, cell; origin,
namespace = config.namespace))` — the verbatim content bytes DEMOTE to each record's fingerprint field).
`origin` carries the target/origin split: the walk's Segment-grain site passes the SEGMENT while
`cell` is the owning LINE, so two same-kind inline Segment evals on one Line stay distinct. The CAPTURE
PREDICATE is the interim span-validity policy (the `cell_content_bytes` empty-return arms — zero/
out-of-range Block span · Segment idxString==0/invalid span · blank Line ⇒ no capture; population
identical to the pre-swap engine, probe-proven). Called from the two apply sites immediately after
`applyAltActionFns` finalizes `st.working` for the cell + its Visib write-back, and BEFORE the next
`detAltValuesForSetOfSlots` wipes `st.working` (apply.jl). The
capture is UNCONDITIONAL on Visib (a label-only or Id-only cell is captured too), reading whichever
alterant instances the apply left in `st.working`:

- **Labels** (`:accumulate`, `Dict{Symbol,Bool}`): one row PER set label — `(handle, :label_<name>, true, true)`
  (the accumulated union of the cell's own + all inherited scopes; e.g.
  `(cell_h, :label_tracking, true, +)`).
- **Visib** (`:mutExclusive`, `@namedElement … Bool`): one row for the WINNING action —
  `(handle, :visib, :hide|:show|:discard, true)` (`keys(Visib)[inst.array][1]`, the proven write-back form;
  guarded against the flagless `keys(Visib)[all-false]` E-04 case rather than tripping a bare `error()`).
- **Id** (`:mutExclusivePerField`, `@namedElement … Int16`): one row per NON-default field —
  `(handle, :id_<name>, value::Int16, true)`. The corpus does NOT exercise Id (SYNTAX-AND-SEMANTICS §13;
  no read site), so this path is contract-completeness ("total over applied verdicts").

`polarity` is `true` for every applied verdict at v0 (all captured verdicts are "set/on"); the field is in the
pinned tuple to distinguish on/off and is reserved for a future negated-verdict encoding. The dispatch reads
the per-call `st.registry.alt_index` (NOT the global `DEFAULT_REGISTRY`), so a custom registry threads through.
"""
function capture_verdicts!(st::ProcessState, cell::BLS.AbstractComponent;
                           origin::Union{Nothing,BLS.AbstractComponent} = nothing)
    isempty(st.working) && return nothing
    # SPAN-VALIDITY POLICY (the interim capture predicate): the CAPTURE decision keeps keying on the
    # content-addressability arms of `cell_content_bytes` (zero/out-of-range Block span · Segment
    # idxString==0/invalid span · blank Line ⇒ empty ⇒ NO capture) — the captured POPULATION is
    # IDENTICAL to the pre-swap engine (probe-verified, decision-instrumented, re-asserted
    # post-swap). What CHANGED is the KEY: rows are keyed by the normalized structural
    # occurrence handle; the content bytes DEMOTE to the record's fingerprint field.
    content = cell_content_bytes(st.parse, cell)
    isempty(content) && return nothing
    k = occurrence_key(st.parse, cell; origin = origin, namespace = st.config.namespace)
    # A DEGENERATE (truncated-walk) key entering the store is NEVER silent (two degenerate keys
    # could alias each other, so the store's impossibility guarantee is scoped to well-formed
    # keys): loud non-fatal diagnostic, capture still proceeds (totality).
    # Unreachable on real parses (zero TRUNCATED steps recorded corpus-wide, chain-256 probed).
    # (Payload convention: THIS diagnostic carries the CONTENT bytes — a degenerate key is
    # unreliable identity, so content is the honest locator; WARN_VERDICT_COLLISION carries the
    # handle because there the key IS reliable. Deliberate asymmetry.)
    if any(s -> s.store == 0x00, k.path) || any(s -> s.store == 0x00, k.origin)
        push!(st.diagnostics, Diagnostic(:WARN_DEGENERATE_OCCURRENCE_KEY, :warning,
            "altValues_evals: a truncated-walk (degenerate) occurrence key entered the store — the " *
            "parse tree has a broken/over-deep link chain; per-occurrence identity is not " *
            "guaranteed among degenerate keys.",
            copy(content)))
    end
    handle = key_bytes(k)

    ## v0.4 T5 — THE REGISTRATION-DRIVEN WALK (T5-DESIGN §2; [C-W6-CE-6]: "keyed on
    ## declared instance type, never an alt-name ladder"). The retired 3-name ladder's
    ## rows re-derive byte-for-byte from the DEFAULT's declared rows (probe P100: the
    ## enumerate(keys)+array read reproduces the old getElement index-for-index;
    ## "setLabels only sets true" verified at the bytes — registry.jl:89 is the sole
    ## write). Byte-identity is the ROW SET plus the surface's own sort — the
    ## plugin-index order coinciding with the ladder's literal order is incidental.
    ## The CAPTURE-SIDE VALUE ALGEBRA (the round's A2=B6=C2 BLOCKER cure): only the
    ## closed leaf set enters the store, so the accessor's string-sort / repr-serialize
    ## / isequal-dedupe stay inside the pre-T5 value universe — no caller method can
    ## dispatch downstream. Out-of-shape/out-of-algebra ⇒ the typed capture floor
    ## (WARN, once per call per alterant), NEVER a raw throw and NEVER a silent skip.
    for (i, p) in pairs(st.registry.plugins)
        idx8 = Int8(i)
        p.capture === nothing && continue
        p.capture.mode_gate === nothing || continue      # :localOnly delivers at the absorb seam
        haskey(st.working, idx8) || continue
        inst = st.working[idx8]
        stem = p.capture.attr_stem === nothing ?
            Symbol(lowercase(String(p.altName))) : p.capture.attr_stem
        ## defense-in-depth (tier 1's identity law makes a mismatch lifecycle-unreachable;
        ## a post-publication mutation still floor-routes rather than mis-reads)
        if !(inst isa p.capture.instance_type)
            _capture_floor!(st, p, :WARN_CAPTURE_UNREADABLE)
            continue
        end
        ## (the crx-t5 second cure batch, three seats convergent) every arm runs under
        ## its OWN mini-envelope: any residual throw class from a registrable-but-exotic
        ## store (a missing custom `keys(T)` method, a shape the static gates cannot
        ## see) FLOORS typed instead of escaping post-latch; InterruptException and the
        ## engine's own "GoMeta "-prefixed refusals (the multiplicity refuse) rethrow —
        ## the uniform T3 arm order. The VALUE ALGEBRA gates EVERY arm's minted values
        ## (`:per_key` was the only guarded arm pre-cure); `:per_field`'s element gate
        ## narrows to the MACHINE-INT union (every Number admitted Float64/BigInt/custom
        ## Numbers into the closed store and dispatched extensible zero/!=); the
        ## `:single`/`:per_field` reads preflight the array/keys LENGTH parity.
        try
            sch = p.capture.attr_scheme
            if sch === :per_key
                if inst isa Dict
                    bad = false
                    for (kk, vv) in inst
                        if kk isa Symbol && _capture_value_leaf(vv)
                            _put_verdict!(st, handle, Symbol(stem, :_, kk), vv, true, content)
                        else
                            bad = true
                        end
                    end
                    bad && _capture_floor!(st, p, :WARN_CAPTURE_UNREADABLE)
                else
                    _capture_floor!(st, p, :WARN_CAPTURE_UNREADABLE)
                end
            elseif sch === :single
                # the NamedElements-shaped single verdict; the capability gate is STATIC
                # on the declared type (Base.eltype on the abstract root — probes
                # P101/P102), the array/keys parity preflighted, the minted value
                # algebra-checked
                T = p.capture.instance_type
                ks = eltype(T) === Bool && hasfield(T, :array) ? keys(T) : nothing
                arr = ks === nothing ? nothing : getfield(inst, :array)
                if ks !== nothing && arr isa AbstractVector{Bool} && length(arr) == length(ks)
                    set_acts = ks[arr]
                    if length(set_acts) > 1
                        # the shipped Visib row's refuse text is a DECLARED literal (the
                        # "(show/hide/discard)" parenthetical is not derivable); the
                        # generic arm names the alterant
                        p.altName === :Visib ?
                            error("GoMeta capture: more than one Visib value set for one component — v0's Visib ",
                                "actions (show/hide/discard) are mutually exclusive per component ",
                                "(see docs/public-api.md §3.4)") :
                            error("GoMeta capture: more than one ", String(p.altName), " value set for one ",
                                "component — a :single capture row is mutually exclusive per component ",
                                "(see docs/public-api.md §3.4)")
                    end
                    if !isempty(set_acts)
                        el = set_acts[1]
                        _capture_value_leaf(el) ?
                            _put_verdict!(st, handle, stem, el, true, content) :
                            _capture_floor!(st, p, :WARN_CAPTURE_UNREADABLE)
                    end
                else
                    _capture_floor!(st, p, :WARN_CAPTURE_UNREADABLE)
                end
            elseif sch === :per_field
                # one row per non-default MACHINE-INT field (the crx-t5 narrowing); the
                # field read is index-exact vs the retired per-module getElement (P100);
                # zero computed ONCE from the DECLARED element type
                T = p.capture.instance_type
                ET = eltype(T)
                ks = (ET isa Type &&
                      ET <: Union{Int8,Int16,Int32,Int64,Int128,UInt8,UInt16,UInt32,UInt64,UInt128} &&
                      hasfield(T, :array)) ? keys(T) : nothing
                arr = ks === nothing ? nothing : getfield(inst, :array)
                if ks !== nothing && arr isa AbstractVector && length(arr) == length(ks)
                    z = zero(ET)
                    for (fi, name) in enumerate(ks)
                        v = arr[fi]
                        (v isa ET && v != z) &&
                            _put_verdict!(st, handle, Symbol(stem, :_, name), v, true, content)
                    end
                else
                    _capture_floor!(st, p, :WARN_CAPTURE_UNREADABLE)
                end
            elseif sch === :per_occurrence
                # the ungated fifth arm: one presence row per governed cell — the
                # occurrence handle IS the locus (the value = `true` at v0.4; T11's row)
                _put_verdict!(st, handle, stem, true, true, content)
            end
        catch e
            e isa InterruptException && rethrow()
            (e isa ErrorException && startswith(e.msg, "GoMeta ")) && rethrow()
            _capture_floor!(st, p, :WARN_CAPTURE_UNREADABLE)
        end
        # `multiplicity` is CARRIED, not consumed, at v0.4 (its consumer = the T11
        # catalogue); every other (scheme, gate) cell is refused at tier 1.
    end
    # the FIRST floor arm: applied state whose plugin declares NO capture row — the
    # registration is legal, its evals-invisibility must be DISCLOSED (the anti-T1 cure)
    for (i, p) in pairs(st.registry.plugins)
        if p.capture === nothing && haskey(st.working, Int8(i))
            _capture_floor!(st, p, :WARN_CAPTURE_FLOOR)
        end
    end
    return nothing
end

"the closed CAPTURE-SIDE VALUE ALGEBRA (T5-DESIGN §1): the leaf set the evals surface renders deterministically"
_capture_value_leaf(@nospecialize v) =
    v isa Bool || v isa Symbol || v isa String ||
    v isa Union{Int8,Int16,Int32,Int64,Int128,UInt8,UInt16,UInt32,UInt64,UInt128}

"""
    _capture_floor!(st, p, code) -> nothing

The typed capture-floor diagnostic (T5-DESIGN §3; the silent skip retires). Both arms
WARNING-severity (non-fatal — totality) and deduped ONCE PER CALL per (alterant, code)
by scanning `st.diagnostics` — the O(n) linear-scan policy `_put_verdict!` already
ratifies; ZERO state-shape change.
"""
function _capture_floor!(st::ProcessState, p, code::Symbol)
    any(d -> d.code === code && d.context === p.altName, st.diagnostics) && return nothing
    msg = code === :WARN_CAPTURE_FLOOR ?
        string("GoMeta capture: alterant ", repr(p.altName), " produced applied state but ",
            "declares no capture row — its verdicts mint NO evals rows (the capture floor; ",
            "declare a CaptureDecl to lift it)") :
        string("GoMeta capture: alterant ", repr(p.altName), " declares scheme ",
            repr(p.capture === nothing ? :none : p.capture.attr_scheme),   # (crx-t5 A1) defensive — the UNREADABLE arm must never itself throw
            " but the live instance/value is outside the ",
            "scheme's readable shape — the affected rows are not minted (the capture ",
            "floor's second arm)")
    push!(st.diagnostics, Diagnostic(code, :warning, msg, p.altName))
    return nothing
end

"""
    capture_heading!(st::ProcessState, heading, stem::Symbol) -> nothing

The localOnly delivery's capture (the outline model): called ONCE per (meta region ×
localOnly plugin) from the absorb seam's REGISTRY-DRIVEN flush (v0.4 T5 — the flush
checks the declared row's gate, the instance shape, and the entries protocol BEFORE
this call; the Heading typing retired with the re-home, and the four attr spellings
re-derive from the DECLARED `stem` — byte-identical for the shipped `:head`), minting
one row per captured entry, keyed to the region's OWN identity. TWO (handle, content)
sources: the DOCUMENT surface supplies the metaLine's own
occurrence handle (`st.meta_context.handle`) + its verbatim bytes
(`st.meta_content`); the userMH FEED supplies the minted user-context handle +
the fed profile's verbatim bytes (`st.user_context`). One shared fold/dedup body serves both sources, so the evals
surface stays uniformly `(cell_handle, attr, value, polarity)`. BOTH sources
populated at once is an INTERNAL-INVARIANT ERROR (unreachable by construction —
the feed nulls the document context and the walk never sets the user context; a
defect that made it reachable gets the loud rejection, never a silent pick).
Neither source ⇒ no row. The attr is the ATTR-FOLD: the level rides the attr
NAME; a `:depth` record column is deliberately deferred.
"""
function capture_heading!(st::ProcessState, heading, stem::Symbol)
    if st.meta_context !== nothing && st.user_context !== nothing
        error("GoMeta internal invariant violated: document context AND user context ",
            "both populated at a heading capture — please report this ",
            "(not reachable from any input by construction)")
    end
    local handle::Vector{UInt8}, content::Vector{UInt8}
    if st.meta_context !== nothing
        handle  = (st.meta_context::MetaContext).handle
        content = st.meta_content
    elseif st.user_context !== nothing
        handle  = (st.user_context::UserContext).handle
        content = (st.user_context::UserContext).content
    else
        return nothing
    end
    # INJECTIVITY over entries (review-found MAJOR, two seats convergent; carried
    # verbatim from the retired per-cell arm): the store dedupes per (handle, attr),
    # so two same-level headings on one metaLine would collapse later-wins WITH a
    # bogus conflict warning. The attr is therefore injective per (metaLine, level):
    # the FIRST entry at a level keeps the plain `head_<level>`, repeats gain a
    # source-order ordinal (`head_<level>_2`, …) — distinct rows, no supersede, no
    # spurious WARN_VERDICT_COLLISION, deterministic.
    lvlseen = Dict{Union{Nothing,Int},Int}()
    for (text, lvl) in getfield(heading, :entries)   # (crx-t5 A4) getfield — the flush's concrete-Vector gate makes this iteration Base-concrete
        k = (lvlseen[lvl] = get(lvlseen, lvl, 0) + 1)
        # the nothing-level arm (dead on live paths — every metaLine path
        # materializes a level; kept defensive) spells its repeats :head_u<k>, NOT
        # Symbol(:head, :_, k): the latter aliases the genuine :head_<k> level attr
        # (delta-review latent-collision cure). Leveled repeats stay :head_<lvl>_<k>
        # — collision-free among leveled attrs since levels are Ints and k ≥ 2.
        attr = lvl === nothing ?
            (k == 1 ? stem : Symbol(stem, :_u, k)) :
            (k == 1 ? Symbol(stem, :_, lvl) : Symbol(stem, :_, lvl, :_, k))
        _put_verdict!(st, handle, attr, text, true, content)
    end
    return nothing
end

# --------------------------------------------------------------------------------------------------------
# The public accessor — altValues_evals(result)
# --------------------------------------------------------------------------------------------------------
"""
    altValues_evals(result::GoMetaResult) -> Vector{Tuple{Vector{UInt8},Symbol,Any,Bool}}

The evals surface (docs/CANONICAL-OUTPUT.md §4; docs/public-api.md §1.3): the per-cell final
verdict map `(cell_handle, attr, value, polarity)`, **sorted by `(cell_handle, attr, value)`** for a
deterministic, content-hashable order. **Final-verdicts-only** (the store is deduped at capture). **Total
over applied verdicts** — exactly one row per final `(cell, attr)` verdict the apply produced (count == the
deduped `EvalStore`). **Empty when no metaLine exists on ANY surface** (the fed profile IS a
metaLine body; a passthrough render of an un-fed meta-free input captures no verdicts). This
surface is OUTSIDE the `(tree, render)` output pair at v0 (folding it in later is a purely additive,
consciously versioned change); it IS the DB-interface write payload.

Pure + read-only on `result` (it sorts the already-final store without mutating it, and each returned
`cell_handle` is a COPY of the store's bytes — mutating a returned handle never perturbs a later accessor
or serializer call on the same result), so it is safe to call any number of times and
outside the per-call `STATE` scope — `result.verdicts` was fully populated by the in-`with` apply. The sort key stringifies `attr`/`value` for a total order over the
heterogeneous `value::Any` within the CLOSED capture value set (Bool for Labels, Symbol for Visib, Int16 for Id, String for heading text — the v0.4 T5 capture value algebra: Bool · Symbol · the machine ints · String); `cell_handle::Vector{UInt8}`
sorts lexicographically.

**Cross-surface note (the discard component-skip divergence).** On an input exercising the discard
component-skip divergence (`devtools/basic_renderer.jl`, the basic renderer — a development tool since
R-V04B-24; a known, deliberate divergence, documented there),
a captured `:show`/`:hide` verdict on a cell nested in a `:discard`-skipped ancestor APPEARS in
`altValues_evals` even though that cell is OMITTED from the basic renderer's `render_bytes` — `altValues_evals`
follows the apply semantics (verdict-faithful), the render follows the component-skip. A DB/agent consumer
should read `altValues_evals` as the verdict truth and the render as the share-target bytes; the two can
legitimately disagree only on this documented-divergence shape.
"""
function altValues_evals(result::GoMetaResult)
    recs   = result.verdicts.records
    order  = sortperm(recs; by = r -> (r.cell_handle, string(r.attr), string(r.value)))
    ## Each returned cell_handle is a COPY — the accessor never aliases the store's byte vectors,
    ## so a caller mutating a returned handle cannot corrupt a later accessor/serialize call.
    ## v0.2 CH-1: the first element is now the OCCURRENCE-KEY bytes (the id-5 INTERIM 4-tuple
    ## arity stands — same shape, new key semantics); content via `content_fingerprint`.
    return Tuple{Vector{UInt8},Symbol,Any,Bool}[
        (copy(recs[i].cell_handle), recs[i].attr, recs[i].value, recs[i].polarity) for i in order
    ]
end

"""
    content_fingerprint(result::GoMetaResult) -> Vector{Tuple{Vector{UInt8},Vector{UInt8}}}

The SIBLING accessor of the occurrence-key store: the per-record
`(cell_handle → content)` pairs — the demoted verbatim content bytes (the layered find-again
fingerprint; plain bytes, NO hashing core-side) keyed by the same occurrence-key bytes
`altValues_evals` returns, in the SAME sort order. Pure + copying, like `altValues_evals`.
"""
function content_fingerprint(result::GoMetaResult)
    recs  = result.verdicts.records
    order = sortperm(recs; by = r -> (r.cell_handle, string(r.attr), string(r.value)))
    return Tuple{Vector{UInt8},Vector{UInt8}}[
        (copy(recs[i].cell_handle), copy(recs[i].content)) for i in order
    ]
end

"""
    serialize_evals(ann) -> Vector{UInt8}

The deterministic, binary-safe 4-COLUMN byte form of an `altValues_evals(result)` vector — one
already-sorted verdict per line, `<attr>\\t<repr(value)>\\t<polarity>\\t<hex(cell_handle)>`, under a
fixed header (`cell_handle` = the occurrence-key bytes, hex — v0.2 CH-1). **BACK-COMPAT form** kept
on the public surface; the GOLDEN layer's write+read sides both use the 5-COLUMN `GoMetaResult` method
below (which appends the content-fingerprint hex column for reviewability + per-fixture
discrimination) — see that method's docstring. Hashing either form's bytes gives a stable behaviour
digest (the "content-hashable" property; docs/CANONICAL-OUTPUT.md §4).
"""
function serialize_evals(ann)::Vector{UInt8}
    # Built via string/join (NOT `print`/`write`-to-stdout) — src/ never prints unconditionally to stdout
    # (the Engine has no stdout channel; the share render is a development tool's), and a static
    # check cannot tell a buffer-print from a stdout-print.
    parts = String[
        "# annotations golden — sorted (cell_handle, attr, value); final-verdicts-only.\n",
        "# columns: <attr>\\t<value>\\t<polarity>\\t<cell_handle = occurrence-key bytes, hex>\n",
    ]
    for (h, attr, val, pol) in ann
        push!(parts, string(attr, '\t', repr(val), '\t', pol, '\t', bytes2hex(h), '\n'))
    end
    return Vector{UInt8}(codeunits(join(parts)))
end

"""
    serialize_evals(result::GoMetaResult) -> Vector{UInt8}

The GOLDEN form of the serializer (the golden layer's write+read sides use THIS method): the 4-column
key form PLUS the demoted content fingerprint as a fifth hex column — the golden stays REVIEWABLE in a
plain diff (a reviewer sees WHICH cell each row addresses) and per-fixture DISCRIMINATING (two
structurally-identical inputs with different content produce different goldens). The ann-vector method
above keeps the key-only 4-column form (public back-compat; an adapter's payload concerns are the
adapter's, not this dev-side golden).
"""
function serialize_evals(result::GoMetaResult)::Vector{UInt8}
    ann = altValues_evals(result)
    fp  = content_fingerprint(result)
    parts = String[
        "# annotations golden — sorted (cell_handle, attr, value); final-verdicts-only.\n",
        "# columns: <attr>\\t<value>\\t<polarity>\\t<cell_handle = occurrence-key bytes, hex>\\t<content fingerprint, hex>\n",
    ]
    for ((h, attr, val, pol), (_, c)) in zip(ann, fp)
        push!(parts, string(attr, '\t', repr(val), '\t', pol, '\t', bytes2hex(h), '\t', bytes2hex(c), '\n'))
    end
    return Vector{UInt8}(codeunits(join(parts)))
end
