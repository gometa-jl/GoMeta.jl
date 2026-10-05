# annotations.jl — the evals surface: the evals map + its canonical serialization.
#
# IS: the home of GoMeta's `altValues_evals` surface — the deterministic, content-hashable,
#     final-evals-only evals map `(cell_handle, attr, value, polarity)` a `goMeta`
#     run yields alongside the development tool's (tree, render) pair (`devtools/basic_renderer.jl`)
#     (docs/public-api.md §1.3; docs/CANONICAL-OUTPUT.md §4). Evals rows have no manifestation in
#     either tuple half (the BLS Component tree is evals-free; the render reflects only Visib effects), so
#     this surface is where label / Visib / Id outcomes become observable — the query-facing
#     write payload, GoMeta's semantic deliverable.
# DOES: (1) the capture predicate — a cell is captured iff its content through the door (`BLS.content`) is
#     non-empty (a structural cell that addresses no content is skipped); the Engine stores NO copy of a piece's
#     text since stage 2's commit 9b (R-V04B-43 (1)). (2) `captureEvals!(st, cell)` —
#     called from the apply sites right after a cell's alterant state is finalized and BEFORE
#     the next slot reset wipes it; records the cell's final label / Visib / Id evals rows into
#     the `EvalStore`, deduped per `(cell_handle, attr)` with later-wins supersede.
#     (3) `readAltValuesEvals(result.altValues_evals)` — the exported accessor: sorts by `(cell_handle, attr, value)`,
#     returns the pinned `Vector{Tuple{Vector{UInt8},Symbol,Any,Bool}}` — empty when no metaLine
#     exists on any surface (the fed profile is a metaLine body; un-fed meta-free input yields
#     the empty vector) — and is pure + read-only on the store it is given. (4) `serialize_evals` — the
#     canonical, deterministic, binary-safe four-column byte form (one evals row per line, hex-encoded
#     handle); the golden layer's five-column form is the TEST layer's (`tests/support/derive_annotations.jl`),
#     its fifth column derived through the BLS Component tree.
# REASONING: final results are observable, deterministic, and hash-stable.
#     The store keys by the row's handle — a NORMALIZED STRUCTURAL occurrence handle (src/occurrence.jl)
#     or a fed profile's user-context handle — so two distinct cells never share a slot even with
#     byte-identical content; a value-CHANGING re-apply of
#     the SAME occurrence emits the non-fatal `WARN_VERDICT_COLLISION` diagnostic rather than
#     masking the supersede (docs/public-api.md §3). A row is recorded for every captured cell —
#     the evals rows are the Engine's recorded truth of the run; the render is the development
#     tool's own concern (`devtools/basic_renderer.jl`), not this surface's.
# PURPOSE: the machine-readable RESULTS surface of a `goMeta` run — pinned, attributed,
#     deterministic, hash-stable; its determinism + totality laws are asserted by
#     the golden layer (tests/golden/golden_tests.jl), and its
#     serialization anchors the annotations goldens read by tests/golden/golden_tests.jl.

# --------------------------------------------------------------------------------------------------------
# Evals capture — record a cell's FINAL evals rows before the slot wipe (called from the apply sites)
# --------------------------------------------------------------------------------------------------------
"""
    _putEval!(st::ProcessState, handle, attr::Symbol, value, polarity::Bool, decided_by) -> nothing

IS: the deduped put of ONE final evals row into `st.evals` — the one door into the store.

DOES: records the row `(handle, attr, value, polarity, decided_by)`, DEDUPED per `(cell_handle, attr)`: a later put
for the same occurrence+attribute SUPERSEDES the earlier one (later wins), so the store holds at most one record
per `(cell_handle, attr)` by construction. **Occurrence-addressing + the collision signal.** `handle` is the
`key_bytes` of the row's handle — a cell's NORMALIZED STRUCTURAL occurrence key (src/occurrence.jl), or a fed
profile's user-context key for its heading rows (`capture_heading!`) — two DISTINCT cells never
share a slot, even with byte-identical content (the distinct-cell content-collision class of a purely
content-keyed store cannot occur by construction; PRECISE BOUND: this holds for WELL-FORMED keys — two DEGENERATE
truncated-walk keys could alias each other, a case no real parse produces). A slot match here is therefore the
SAME occurrence re-applied; a value-CHANGING supersede is a genuine conflicting re-apply (applied-state-wins) and
still records the non-fatal `:warning` Diagnostic (`WARN_VERDICT_COLLISION` — the code's name unchanged) —
surfaced, never masked. No copy of the piece's text rides the record (R-V04B-43 (1), stage 2's commit 9b).

REASONING: the surface promises final evals only — one row per `(cell_handle, attr)` — so the put dedupes at
write time, a later put superseding, rather than by a later pass, and the reader sorts without resolving
repeats; the linear scan — O(n) per put, n = the rows already in the store — is accepted at v0 for the corpus's
small files, a Dict-keyed store being the O(1) successor.

PURPOSE: the single primitive both `captureEvals!` (the apply sites' rows) and `capture_heading!` (the absorb
seam's heading rows) write through — every evals row a run records enters the store here.
"""
function _putEval!(st::ProcessState, handle::Vector{UInt8}, attr::Symbol, value, polarity::Bool,
                       decided_by::Vector{Vector{UInt8}})
    recs = st.evals.records
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
            recs[i] = EvalRecord(handle, attr, value, polarity, decided_by)   # supersede (later wins)
            return nothing
        end
    end
    push!(recs, EvalRecord(handle, attr, value, polarity, decided_by))
    return nothing
end

"""
    captureEvals!(st::ProcessState, cell; origin = nothing) -> nothing

IS: the capture of a cell's FINAL evals rows from `st.working` into `st.evals` before the slot wipe — the apply
sites' write path into the store.

DOES: captures `cell`'s FINAL Alterant values from `st.working` into `st.evals`, keyed by the cell's
NORMALIZED STRUCTURAL occurrence key (v0.2 CH-1: `key_bytes(occurrence_key(parse, cell; origin,
namespace = config.namespace))`; the row carries no copy of the piece's text — R-V04B-43 (1), commit 9b).
`origin` carries the target/origin split: the walk's Segment-grain site passes the SEGMENT while
`cell` is the owning LINE, so two same-kind inline Segment evals on one Line stay distinct. The CAPTURE
PREDICATE is the interim span-validity policy (the door's `BLS.content` empty-return arms — zero/
out-of-range Block span · Segment idxString==0/invalid span · blank Line ⇒ no capture; population
identical to the pre-swap engine, probe-proven). Called from the two apply sites immediately after
`applyAltActionFns` finalizes `st.working` for the cell (the Visib write-back that followed it left at stage 3's commit 4), and BEFORE the next
`detAltValuesForSetOfSlots` wipes `st.working` (apply.jl). The
capture is UNCONDITIONAL on Visib (a label-only or Id-only cell is captured too), reading whichever
alterant instances the apply left in `st.working`:

- **Labels** (`:accumulate`, `Dict{Symbol,Bool}`): one row PER set label — `(handle, :label_<name>, true, true)`
  (the accumulated union of the cell's own + all inherited scopes; e.g.
  `(cell_h, :label_tracking, true, +)`).
- **Visib** (`:mutExclusive`, `@namedElement … Bool`): one row for the WINNING action —
  `(handle, :visib, :hide|:show|:discard, true)` (`keys(Visib)[inst.array][1]`, the form the former Visib write-back used — gone at stage 3's commit 4;
  guarded against the flagless `keys(Visib)[all-false]` case — the former write-back's E-04 crash origin, gone with it at stage 3's commit 4 — rather than tripping a bare `error()`).
- **Id** (`:mutExclusivePerField`, `@namedElement … Int16`): one row per NON-default field —
  `(handle, :id_<name>, value::Int16, true)`. The corpus does NOT exercise Id (SYNTAX-AND-SEMANTICS §13;
  no read site), so this path is contract-completeness ("total over the applied evals rows").

`polarity` is `true` for every applied evals row at v0 (all captured evals rows are "set/on"); the field is in
the pinned tuple to distinguish on/off and is reserved for a future negated-row encoding — an evals row with
`polarity == false`. The dispatch iterates the per-call `st.registry.plugins` and reads each plugin's declared
`CaptureDecl` (its instance type, scheme, gate and stem — NOT the global `DEFAULT_REGISTRY`), so a custom
registry threads through.

Each row's `decided_by` (R-V04B-35 (d); stage 2's commit 2) is the list the apply recorded for the Alterant in
`st.working_origin`: the handles of the statements it APPLIED, in application order — ONE for a single-valued mode
(the deciding statement), the contributing statements' for an accumulating one (which statement contributed which
label stays Q4 (ii)), the applied fields' for the compound; own when it names the row's own Component (a Block's: the entry equals the
row's handle; a Segment-carried row's: the entry is the Segment's own key — its row is keyed on the Line with the
Segment as the key's origin — and the answer function reads that entry as the LINE's own statement, the Segment being its
carrier: the Line answers `:own`, the Segment its Line's answer marked `:indirect` (his words of 2026-10-02, OWNER-WORDS
§286/§288, R-V04B-93), indirect otherwise — MEASURED, never inferred from a row's presence.

REASONING: the store is keyed by the normalized structural occurrence key so two distinct cells never share a
slot, and the capture happens between the apply's finalization and the next wipe because `st.working` is
transient — what is not captured here is gone with the wipe.

PURPOSE: the write path for a Component's evals rows from the APPLY — the rows of every Alterant the apply
left in `st.working` (the shipped Labels, Visib and Id), put from the two apply sites: `src/GoMeta.jl` (the
Block grain) and `src/absorb/walk.jl` (the Segment grain, `origin` = the Segment, the row keyed on the owning
Line). The heading rows — a metaLine region's, keyed on the Component the statement is APPLIED TO and decided by the
carrier (the metaBlock a whole-line or a comment-split metaLine forms, R-V04B-50; the LINE with the Segment as the key's origin for an
inline metaSegment, R-V04B-98), and the fed
profile's, keyed on the user-context handle — are NOT put here: `capture_heading!` puts them from the absorb
seam's flush (its one call in `src/absorb/absorb_meta.jl`). Both writers go through the one primitive
`_putEval!`.
"""
function captureEvals!(st::ProcessState, cell::BLS.AbstractComponent;
                           origin::Union{Nothing,BLS.AbstractComponent} = nothing)
    isempty(st.working) && return nothing
    # SPAN-VALIDITY POLICY (the interim capture predicate): the CAPTURE decision keys on the
    # content-addressability arms of the door's `BLS.content` (zero/out-of-range Block span · Segment
    # idxString==0/invalid span · blank Line ⇒ empty ⇒ NO capture) — the captured POPULATION is
    # IDENTICAL to the pre-swap engine (probe-verified, decision-instrumented, re-asserted
    # post-swap). The rows are keyed by the normalized structural occurrence handle; the piece's text is
    # NOT stored (R-V04B-43 (1), stage 2's commit 9b) — read here through the door for the predicate only.
    content = BLS.content(st.parse, cell)
    isempty(content) && return nothing
    k = occurrence_key(st.parse, cell; origin = origin, namespace = st.config.namespace)
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
        decided = get(st.working_origin, idx8, Vector{UInt8}[])   # R-V04B-35 (d): the applied statements' handles
        stem = p.capture.attr_stem === nothing ?
            Symbol(lowercase(String(p.altName))) : p.capture.attr_stem
        ## the identity law left at stage 5's E4: a declared mismatch, like a post-publication
        ## mutation, floor-routes here rather than mis-reads (measured: WARN_CAPTURE_UNREADABLE)
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
                            _putEval!(st, handle, Symbol(stem, :_, kk), vv, true, decided)
                        else
                            bad = true
                        end
                    end
                    bad && _capture_floor!(st, p, :WARN_CAPTURE_UNREADABLE)
                else
                    _capture_floor!(st, p, :WARN_CAPTURE_UNREADABLE)
                end
            elseif sch === :single
                # the NamedElements-shaped single evals row; the capability gate is STATIC
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
                            _putEval!(st, handle, stem, el, true, decided) :
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
                            _putEval!(st, handle, Symbol(stem, :_, name), v, true, decided)
                    end
                else
                    _capture_floor!(st, p, :WARN_CAPTURE_UNREADABLE)
                end
            elseif sch === :per_occurrence
                # the ungated fifth arm: one presence row per governed cell — the
                # occurrence handle IS the locus (the value = `true` at v0.4; T11's row)
                _putEval!(st, handle, stem, true, true, decided)
            end
        catch e
            e isa InterruptException && rethrow()
            (e isa ErrorException && startswith(e.msg, "GoMeta ")) && rethrow()
            _capture_floor!(st, p, :WARN_CAPTURE_UNREADABLE)
        end
        # `multiplicity` is CARRIED, not consumed, at v0.4 (its consumer = the T11
        # catalogue); a scheme outside the four arms with gate `nothing` publishes since stage 5's
        # E4 (the closed-set row left) and falls through here — no row, no floor (measured:
        # PROBES-e4-seat-notes [c]); T11's catalogue row.
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

IS: the typed capture-floor diagnostic — the disclosure that an Alterant's applied state minted no evals rows
(`WARN_CAPTURE_FLOOR`: no capture row declared) or that some or all of them were not minted
(`WARN_CAPTURE_UNREADABLE`: a live value outside the declared readable shape — under `:per_key` the admitted
entries are still put before the floor fires).

DOES: The typed capture-floor diagnostic (T5-DESIGN §3; the silent skip retires). Both arms
WARNING-severity (non-fatal — totality) and deduped ONCE PER CALL per (alterant, code)
by scanning `st.diagnostics` — the O(n) linear-scan policy `_putEval!` already
ratifies; ZERO state-shape change.

REASONING: the silent skip retires: an evals-invisible applied state, or the unreadable part of one, is
disclosed as a non-fatal WARNING, once per call per (alterant, code), so totality holds without a throw.

PURPOSE: to make the capture floor visible — an Alterant that declares no capture row, or a live value outside
its declared readable shape — to whoever reads the diagnostics.
"""
function _capture_floor!(st::ProcessState, p, code::Symbol)
    any(d -> d.code === code && d.context === p.altName, st.diagnostics) && return nothing
    msg = code === :WARN_CAPTURE_FLOOR ?
        string("GoMeta capture: alterant ", repr(p.altName), " produced applied state but ",
            "declares no capture row — its outcomes mint NO evals rows (the capture floor; ",
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
one row per captured entry, KEYED to the Component the statement is APPLIED TO and DECIDED BY the carrier
(R-V04B-98; stage 5's E1). TWO sources: the DOCUMENT surface supplies both through the walk's record — `st.meta_context.applied`,
the applied Component's handle (the metaBlock a whole-line metaLine forms, R-V04B-50; the LINE for a Code Line's trailing
metaSegment, keyed as the apply path keys it with the Segment as the key's origin; the metaBlock for the statement Segment of a
metaLine split by a trailing comment), and `st.meta_context.handle`, the carrier's own handle (the metaBlock; the Segment of an
inline metaSegment) — the row's deciding statement; the userMH FEED supplies the minted user-context handle (`st.user_context`)
for both. No copy of the carrier's text rides the row (R-V04B-43 (1), commit 9b). One shared fold/dedup
body serves both sources, so the evals surface stays uniformly `(cell_handle, attr, value, polarity)`. BOTH sources
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
    local handle::Vector{UInt8}; local applied::Vector{UInt8}
    if st.meta_context !== nothing
        handle = (st.meta_context::MetaContext).handle      # the carrier — the row's deciding statement
        applied = (st.meta_context::MetaContext).applied    # R-V04B-98: the Component the statement is applied to — the row's KEY
    elseif st.user_context !== nothing
        handle = (st.user_context::UserContext).handle; applied = handle
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
        _putEval!(st, applied, attr, text, true, [copy(handle)])   # keyed on the APPLIED Component (R-V04B-98); the never-enqueued :localOnly Heading's deciding statement: its own carrier (R-V04B-35 (d))
    end
    return nothing
end

# --------------------------------------------------------------------------------------------------------
# The public accessor — readAltValuesEvals(result.altValues_evals)
# --------------------------------------------------------------------------------------------------------
"""
    readAltValuesEvals(altValues_evals::EvalStore) -> Vector{Tuple{Vector{UInt8},Symbol,Any,Bool}}

IS: the core's reader over the part `altValues_evals` of a delivery — the evals rows a run recorded — the
production surface of the GoMeta Engine (docs/CANONICAL-OUTPUT.md §4; docs/public-api.md §1.3). GIVEN THE PART,
never the whole delivered object: `readAltValuesEvals(delivery.altValues_evals)` (a reader takes the PART —
R-V04B-29's record; the branch's default under R-V04B-40 (2)). Named by the owner's ruling R-V04B-32
(2026-09-16): the name `altValues_evals` belongs to the DATA CONTAINER — the evals rows a run delivers — never to
a function.

DOES: returns one row `(cell_handle, attr, value, polarity)` per final evaluation recorded for a handle and an
attribute — the per-cell rows (a Component's: put at the two apply sites, and a metaLine's own heading rows at
the absorb seam's flush) plus the handle-classed non-cell rows the explicit headings of a fed profile record
against the user-context handle, one per entry (docs/public-api.md §2, the reader's own section) — **sorted by
`(cell_handle, attr, value)`** so that the order is deterministic and content-hashable; final evals only (the
store is deduped at capture); total over the recorded evals (the row count == the deduped `EvalStore`); empty
when no metaLine exists on ANY surface (the fed profile IS a metaLine body; a run over an un-fed meta-free input
records no evals rows). Pure and read-only on the store it is given: it sorts the already-final store without
mutating it, and each returned `cell_handle` is a COPY of the store's bytes, so a caller mutating a returned
handle never perturbs a later reader or serializer call on the same store; safe to call any number of times,
also outside the per-call `STATE` scope (the part was fully populated by the in-`with` apply). The sort key
stringifies `attr` and `value` for a total order over the heterogeneous `value::Any` within the CLOSED capture
value set — the T5 capture value algebra: Bool · Symbol · the machine ints · String (`_capture_value_leaf`);
the shipped four use Bool for Labels, Symbol for Visib, Int16 for Id, String for heading text;
`cell_handle::Vector{UInt8}` sorts lexicographically. The first element is the OCCURRENCE-KEY bytes (v0.2
CH-1); a piece's text is read from the BLS Component tree through `BLS.content`, never from a row (R-V04B-43 (1)).

REASONING: the GoMeta Engine EVALUATES and records values as data (the boundary law, 2026-08-27); this reader
is the one core-provided route from a run to those values. It is given the PART and not the delivered object
around it so that whoever holds an `EvalStore` reads it the same way — the delivery's part, the seam's, and
the rows of a File, User or `fallBack` level once the Engine's apply records them: such a row is a row of this
same store under its own grain code (`src/occurrence.jl`), so a level's entry needs no new part and no new
signature (R-V04B-53's room — stated here, not built). Its order is fixed so that two runs over the
same input bytes, configuration (the fed profile included) and registry serialize identically — for a
default-configured run under `DEFAULT_REGISTRY`, the closed interpreter (the opt-in `:full_eval_v1` mode and a
custom registry's own callables are outside the guarantee — `goMeta`'s docstring, the trust model): the
Engine's determinism supplies equal rows, the sort their equal order. This surface is the Engine's; the
development tool's `outputs` pair — the BLS Component tree's print and the render
(`Main.BasicRenderer.outputs`, R-V04B-24) — is the tool's own, and no ruling foresees the two joined.

PURPOSE: what an Extension, a test, a development tool or a DB-interface reads to learn the final Alterant
values a run recorded and for which handle — a Component's rows from the apply, a metaLine region's heading
rows from the absorb seam's flush, and the non-cell rows the explicit headings of a fed profile record against
the user-context handle, one per entry — the evals rows as the recorded truth of the run.
"""
function readAltValuesEvals(altValues_evals::EvalStore)
    recs   = altValues_evals.records
    order  = sortperm(recs; by = r -> (r.cell_handle, string(r.attr), string(r.value)))
    ## Each returned cell_handle is a COPY — the accessor never aliases the store's byte vectors,
    ## so a caller mutating a returned handle cannot corrupt a later accessor/serialize call.
    ## v0.2 CH-1: the first element is now the OCCURRENCE-KEY bytes (the id-5 INTERIM 4-tuple
    ## arity stands — same shape, new key semantics); a piece's text through `BLS.content`.
    return Tuple{Vector{UInt8},Symbol,Any,Bool}[
        (copy(recs[i].cell_handle), recs[i].attr, recs[i].value, recs[i].polarity) for i in order
    ]
end

## the ATTR column of the four-column public form, ENCODED (stage 2's commit 7a; the CrossReview set REAL-1 R1 #2): a backslash, tab,
## newline or carriage return in an attribute name — a third-party Alterant's stem or member name may carry one; the registry refuses
## none of them (his §120 defers the hardening, R-V04B-37) — is escaped as a doubled backslash, backslash-t, backslash-n and
## backslash-r, so one row stays one line and
## four columns; the shipped families (`visib`, `label_<name>`, `id_<name>`, `head_<level>`) carry none and serialize byte-identically.
## The five-column golden form is the TEST layer's since commit 9b (`tests/support/derive_annotations.jl`); the twelve pins unmoved.
_attr_encoded(attr::Symbol) = replace(String(attr), "\\" => "\\\\", "\t" => "\\t", "\n" => "\\n", "\r" => "\\r")

"""
    serialize_evals(ann) -> Vector{UInt8}

IS: the deterministic, binary-safe 4-COLUMN byte form of a reader vector — THE public serialization
of the evals rows (no compatibility form exists — R-V04B-61).

DOES: The deterministic, binary-safe 4-COLUMN byte form of a `readAltValuesEvals(result.altValues_evals)` vector — one
already-sorted evals row per line, `<attr>\\t<repr(value)>\\t<polarity>\\t<hex(cell_handle)>`, under a
fixed header (`cell_handle` = the occurrence-key bytes, hex — v0.2 CH-1); the `attr` column ENCODED since stage 2's
commit 7a — a backslash, tab, newline or carriage return in an attribute name escaped as `\\\\`, `\\t`, `\\n`, `\\r`
(the CrossReview set REAL-1 R1 #2: one row stays one line and four columns; the shipped families carry none and
serialize byte-identically; the registry refuses no delimiter — his §120 defers that hardening, R-V04B-37). **THE PUBLIC form**, the Engine's
only serialization since stage 2's commit 9b; the GOLDEN layer's five-column form (the fifth column a piece's text
through the BLS Component tree) is the TEST layer's `derive_annotations_golden` (`tests/support/derive_annotations.jl`).
Hashing the bytes gives a stable behaviour
digest (the "content-hashable" property; docs/CANONICAL-OUTPUT.md §4).

REASONING: a fixed header and one row per line, hex-encoded handles, make the bytes hash-stable and
diff-reviewable; the golden layer's five-column form is derived in the test layer.

PURPOSE: the byte form a consumer hashes for a behaviour digest (docs/CANONICAL-OUTPUT.md §4) and the notebook
generator's digest source.
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
        push!(parts, string(_attr_encoded(attr), '\t', repr(val), '\t', pol, '\t', bytes2hex(h), '\n'))   # the attr column encoded (commit 7a; R1 #2)
    end
    return Vector{UInt8}(codeunits(join(parts)))
end
