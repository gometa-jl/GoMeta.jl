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
#     the next slot reset wipes it; records the cell's final label / Visib / Id / heading evals rows into
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
#     (no row is keyed on a fed profile's user-context handle since stage 1 of the Alterants build — that handle rides
#     the fed actions' `decided_by` only) — so two distinct cells never share a slot even with
#     byte-identical content; a value-CHANGING re-apply of
#     the SAME occurrence supersedes, later wins (the collision warning left at stage 5's E5 of the v0.4
#     build — census row 66). A row is recorded for every captured cell —
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
per `(cell_handle, attr)` by construction. **Occurrence-addressing.** `handle` is the
`key_bytes` of the row's handle — a cell's NORMALIZED STRUCTURAL occurrence key (src/occurrence.jl) — two DISTINCT cells never
share a slot, even with byte-identical content (the distinct-cell content-collision class of a purely
content-keyed store cannot occur by construction; PRECISE BOUND: this holds for WELL-FORMED keys — two DEGENERATE
truncated-walk keys could alias each other, a case no real parse produces). A slot match here is therefore the
SAME occurrence re-applied; a value-CHANGING supersede is a conflicting re-apply (applied-state-wins; the
collision warning that accompanied it left at stage 5's E5 of the v0.4 build — census row 66). No copy of the piece's text rides the record (R-V04B-43 (1), stage 2's commit 9b).

REASONING: the surface promises final evals only — one row per `(cell_handle, attr)` — so the put dedupes at
write time, a later put superseding, rather than by a later pass, and the reader sorts without resolving
repeats; the linear scan — O(n) per put, n = the rows already in the store — is accepted at v0 for the corpus's
small files, a Dict-keyed store being the O(1) successor.

PURPOSE: the single primitive `captureEvals!` (the apply sites' rows — every Alterant's, the Heading's included since stage 1
of the Alterants build) writes through — every evals row a run records enters the store here.
"""
function _putEval!(st::ProcessState, handle::Vector{UInt8}, attr::Symbol, value, polarity::Bool,
                       decided_by::Vector{Vector{UInt8}})
    recs = st.evals.records
    @inbounds for i in eachindex(recs)
        r = recs[i]
        if r.attr === attr && r.cell_handle == handle
            # a slot match is the SAME structural occurrence by construction (the occurrence-key bytes); a later put
            # supersedes, later wins — the collision warning left at stage 5's E5 of the v0.4 build (census row 66)
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
  the flagless `keys(Visib)[all-false]` case mints no row).
- **Id** (`:mutExclusivePerField`, `@namedElement … Int16`): one row per NON-default field —
  `(handle, :id_<name>, value::Int16, true)`. The corpus does NOT exercise Id (SYNTAX-AND-SEMANTICS §13;
  no read site), so this path is contract-completeness ("total over the applied evals rows").
- **Heading** (`:localOnly`, `Heading.entries`; `:per_entry`): one row PER ENTRY `(text, level)` of the store —
  `(handle, :head_<level>, text::String, true)`, a same-level repeat `:head_<level>_<k>` (k ≥ 2, source order); the apply loop's
  one rule for the set mode `localOnly` applies the statement only at the Component it is applied to, so the row is keyed on the
  metaBlock, or on the Line with the Segment as the key's origin (R-V04B-98); each row's `decided_by` the carrier of its own
  `head` statement (the i-th entry the i-th applied statement).

`polarity` is `true` for every applied evals row at v0 (all captured evals rows are "set/on"); the field is in
the pinned tuple to distinguish on/off and is reserved for a future negated-row encoding — an evals row with
`polarity == false`. The dispatch iterates the per-call `st.registry.plugins` and reads each plugin's declared
`CaptureDecl` (its scheme and stem; the store's shape the record's own `altConstructor` — NOT the global `DEFAULT_REGISTRY`), so a custom
registry threads through.

Each row's `decided_by` (R-V04B-35 (d); stage 2's commit 2) is the list the apply recorded for the Alterant in
`st.working_origin`: the handles of the statements it APPLIED, in application order — ONE for a single-valued mode
(the deciding statement), the contributing statements' for an accumulating one (which statement contributed which
label stays Q4 (ii)), the applied fields' for the compound — and for a `:per_entry` row ONE element of it, the origin of the row's own applied statement (the Heading bullet above; under the scheme's contract of one entry per applied call — a surplus entry carries the whole list, the `:per_entry` arm below); own when it names the row's own Component (a Block's: the entry equals the
row's handle; a Segment-carried row's: the entry is the Segment's own key — its row is keyed on the Line with the
Segment as the key's origin — and the answer function reads that entry as the LINE's own statement, the Segment being its
carrier: the Line answers `:own`, the Segment its Line's answer marked `:indirect` (his words of 2026-10-02, OWNER-WORDS
§286/§288, R-V04B-93), indirect otherwise — MEASURED, never inferred from a row's presence.

REASONING: the store is keyed by the normalized structural occurrence key so two distinct cells never share a
slot, and the capture happens between the apply's finalization and the next wipe because `st.working` is
transient — what is not captured here is gone with the wipe.

PURPOSE: the write path for a Component's evals rows from the APPLY — the rows of every Alterant the apply
left in `st.working` (the shipped Labels, Visib, Id and, since stage 1 of the Alterants build, the Heading — ONE process for
every Alterant, his §D241), put from the two apply sites: `src/GoMeta.jl` (the Block grain) and `src/absorb/walk.jl` (the
Segment grain, `origin` = the Segment, the row keyed on the owning Line). A heading's row is thereby keyed on the Component
the statement is applied to by the machinery itself (the metaBlock a whole-line or a comment-split metaLine forms, R-V04B-50;
the LINE with the Segment as the key's origin for an inline metaSegment, R-V04B-98); a heading in the profile feed records
no row — it meets the one refusal at the read (his §D242). The one primitive is `_putEval!`.
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

    ## v0.4 T5 — THE REGISTRATION-DRIVEN WALK (T5-DESIGN §2): the rows re-derive from each plugin's declared capture row (its
    ## scheme and stem), never from an alt-name ladder; the shipped Labels, Visib and Id mint byte-for-byte the rows the retired
    ## 3-name ladder minted (probe P100). The walk reads the stores BARE, as his legacy's Visib write did
    ## (`keys(Alterants.Visib)[…array][1]`): the hardening of stage 5's census row 33 — the instance-type check, the per-arm
    ## try/catch, the value algebra, the shape and length gates and the walk's two capture-floor calls — left at E5 of the v0.4
    ## build (his §317 mark; his §120: a basic framework BEFORE HARDENING). A store outside its declared scheme's shape errors as
    ## Julia does; a plugin without a capture row mints nothing.
    for (i, p) in pairs(st.registry.plugins)
        idx8 = Int8(i)
        p.capture === nothing && continue
        haskey(st.working, idx8) || continue
        inst = st.working[idx8]
        decided = get(st.working_origin, idx8, Vector{UInt8}[])   # R-V04B-35 (d): the applied statements' handles
        stem = _capture_stem(p)
        sch = p.capture.attr_scheme
        if sch === :per_key
            for (kk, vv) in inst
                _putEval!(st, handle, Symbol(stem, :_, kk), vv, true, decided)
            end
        elseif sch === :single
            # the NamedElements-shaped single evals row: the names of the set flags, at most one set
            set_acts = keys(p.altConstructor)[getfield(inst, :array)]
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
            isempty(set_acts) || _putEval!(st, handle, stem, set_acts[1], true, decided)
        elseif sch === :per_field
            # one row per non-default field (the field read index-exact vs the retired per-module getElement, P100);
            # zero computed once from the store's element type
            ks = keys(p.altConstructor)
            arr = getfield(inst, :array)
            z = zero(eltype(p.altConstructor))
            for (fi, name) in enumerate(ks)
                arr[fi] != z && _putEval!(st, handle, Symbol(stem, :_, name), arr[fi], true, decided)
            end
        elseif sch === :per_entry
            # one row per entry `(text, level)` of a Heading-shaped store (stage 1 of the Alterants build — the separate
            # recorder `capture_heading!` folded into this one walk): THE ATTR-FOLD — the level rides the attr NAME, the FIRST
            # entry at a level `<stem>_<level>`, a repeat at the same level `<stem>_<level>_<k>` (k ≥ 2, source order; the store
            # dedupes per (handle, attr), so the fold keeps same-level repeats distinct — the v0.2 build's injectivity law); an
            # entry without a level `<stem>`, its repeats `<stem>_u<k>` (dead on live paths — every path materialises a level at
            # the enqueue; kept defensive); the VALUE the text; each entry's deciding statement is its own applied row's origin
            # (the i-th entry ← the i-th applied statement: `_record_origin!` and the setter push in one order — the scheme's CONTRACT is a
            # setter appending EXACTLY ONE entry per applied call, as `setHead` does; a setter appending none or several is not refused
            # and mis-pairs, a surplus entry taking the whole origin list — docs/public-api.md §1.2).
            lvlseen = Dict{Union{Nothing,Int},Int}()
            for (ei, (text, lvl)) in enumerate(getfield(inst, :entries))
                k = (lvlseen[lvl] = get(lvlseen, lvl, 0) + 1)
                attr = lvl === nothing ?
                    (k == 1 ? stem : Symbol(stem, :_u, k)) :
                    (k == 1 ? Symbol(stem, :_, lvl) : Symbol(stem, :_, lvl, :_, k))
                _putEval!(st, handle, attr, text, true, ei <= length(decided) ? [copy(decided[ei])] : decided)
            end
        end
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
attribute — the per-cell rows (a Component's, put at the two apply sites — every Alterant's, the Heading's rows keyed on the
Component the statement is applied to; a heading in the profile feed records no row — it meets the one refusal at the read,
his §D242; docs/public-api.md §2, the reader's own section) — **sorted by
`(cell_handle, attr, value)`** so that the order is deterministic and content-hashable; final evals only (the
store is deduped at capture); total over the recorded evals (the row count == the deduped `EvalStore`); empty
when no metaLine exists on ANY surface (the fed profile IS a metaLine body; a run over an un-fed meta-free input
records no evals rows). Pure and read-only on the store it is given: it sorts the already-final store without
mutating it, and each returned `cell_handle` is a COPY of the store's bytes, so a caller mutating a returned
handle never perturbs a later reader or serializer call on the same store; safe to call any number of times,
also outside the per-call `STATE` scope (the part was fully populated by the in-`with` apply). The sort key
stringifies `attr` and `value` for a total order over the heterogeneous `value::Any` within the CLOSED capture
value set the shipped Alterants mint — Bool · Symbol · the machine ints · String (the capture-side algebra that gated them left at stage 5's E5);
the shipped four use Bool for Labels, Symbol for Visib, Int16 for Id, String for heading text;
`cell_handle::Vector{UInt8}` sorts lexicographically. The first element is the OCCURRENCE-KEY bytes (v0.2
CH-1); a piece's text is read from the BLS Component tree through `BLS.content`, never from a row (R-V04B-43 (1)).

REASONING: the GoMeta Engine EVALUATES and records values as data (the boundary law, 2026-08-27); this reader
is the one core-provided route from a run to those values. It is given the PART and not the delivered object
around it so that whoever holds an `EvalStore` reads it the same way — the delivery's part, the seam's, and
the rows of a File, User or `fallBack` level once the Engine's apply records them: such a row is a row of this
same store under its own grain code (`src/occurrence.jl`), so a level's entry needs no new part and no new
signature (R-V04B-53's room — stated here, not built). Its order is fixed so that two runs over the
same input bytes, configuration (the fed profile included) and registry serialize identically — for the Engine's
own operations under `DEFAULT_REGISTRY` (a condition body — Julia, evaluated by Julia since stage 5's E13 — and a
custom registry's own callables are the author's, outside the guarantee — `goMeta`'s docstring, the trust model): the
Engine's determinism supplies equal rows, the sort their equal order. This surface is the Engine's; the
development tool's `outputs` pair — the BLS Component tree's print and the render
(`Main.BasicRenderer.outputs`, R-V04B-24) — is the tool's own, and no ruling foresees the two joined.

PURPOSE: what an Extension, a test, a development tool or a DB-interface reads to learn the final Alterant
values a run recorded and for which handle — a Component's rows from the apply, the Heading's among them
— the evals rows as the recorded truth of the run.
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
