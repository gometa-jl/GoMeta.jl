# src/result.jl — the typed result-support types: ProcessStatus, Diagnostic, EvalStore.
#
# IS: the dep-free pieces of the public `GoMetaDelivery` surface — the run status (set at the delivery,
#     never stored on `ProcessState` — `goMeta` computes it from the diagnostics at its exit), the coded
#     diagnostic record (the coded form of the DELIVERED errors and warnings — the partition below), and the evals store (these two embedded in
#     `ProcessState`). (The top-level `GoMetaDelivery` aggregate is defined in `state.jl`, AFTER
#     `ProcessState` — the run builds it from the state's own pieces at exit; the two the state embeds must
#     precede `ProcessState`, and the status enum lives beside them, so all three live here.)
# DOES: declares `ProcessStatus` (the OK/non-OK enum), `Diagnostic` (`{code, severity, message, context}`),
#     and `EvalStore` (a growable set of `EvalRecord`s) + its empty constructor.
# REASONING: catalogued failures surface as coded `Diagnostic`s where they are DELIVERED — the registry door's refusals
#     (`REG_UNPUBLISHED`, `POST_SEAL_MUTATION`; the capture-floor warnings were removed with the Heading's separate
#     path); the config-time row E-03 was removed
#     with the grammar profile, the condition rows (E-01/E-02, the arg-domain and parse rows, E-07) with
#     the closed interpreter (a condition is Julia's since 0.4.0 — GoMeta's own refusals the unknown condition key, the no-expression
#     guard and the unterminated `(` inside a body, `ErrorException`s at the absorb seam; a body Julia cannot parse its own `Meta.ParseError`), E-08 as well; the E-06 row
#     still throws (docs/public-api.md §3; E-04 was removed with the Visib write-back). `captureEvals!` (the apply sites, before the
#     slot wipe) records the evals rows — every Alterant's, the Heading's included —
#     feeding `readAltValuesEvals`.
# PURPOSE: the stable, total, machine-inspectable result vocabulary.

"""
    @enum ProcessStatus PROCESS_OK PROCESS_ERROR

IS: the run status of a delivery — the two-valued enum every consumer checks first.

DOES: The run status. `PROCESS_OK` ⇒ no error-severity diagnostics (a meta-free input on the no-feed
path is still OK — E-05; a refusal-carrying feed aborts regardless of document meta-freeness);
`PROCESS_ERROR` ⇒ at least one error-severity `Diagnostic` (non-OK ⇒ non-empty diagnostics). This
invariant is enforced when `goMeta` constructs the `GoMetaDelivery`. The
set is intentionally small; any change to it is a clean cut under the versioning policy (docs/public-api.md §6 — no
compatibility promise until at least v0.7).

REASONING: a consumer needs one total signal that says whether the evals rows may be trusted before it reads a diagnostic — the invariant non-OK ⇒ non-empty diagnostics makes the enum sufficient.

PURPOSE: the fail-closed signal of the delivered object (one of its four parts).
"""
@enum ProcessStatus PROCESS_OK PROCESS_ERROR

"""
    Diagnostic(code, severity, message, context)

IS: a coded, non-throwing diagnostic — the form in which a run DELIVERS its errors and warnings
(`GoMetaDelivery.diagnostics`); not every refusal is delivered — some still throw at v0 (the partition,
docs/public-api.md §3).

DOES: `code::Symbol` is a catalogue code (e.g. `:REG_UNPUBLISHED`; the registry door's codes arm at `goMeta`'s entry —
the config-time and condition-path codes were removed with the closed interpreter, the capture-floor warnings with the Heading's separate
path; docs/public-api.md §3); `severity::Symbol ∈ {:error,:warning,:info}` — the declared set;
under `src/` the rows minted are `:error` (`REG_UNPUBLISHED`, `POST_SEAL_MUTATION` — delivered; `REG_PROTOCOL`,
`REG_SLOT_EXHAUSTED`, `REG_DERIVED_TABLES` — returned by `validate` as data or carried by a thrown `RegistrationRefused`);
no `:warning` row is minted under `src/` (`WARN_CAPTURE_FLOOR` / `WARN_CAPTURE_UNREADABLE`
were removed with the Heading's separate path — the §6 row); `message::String` is human-readable; `context` is
optional structured context — what the minters pass: a record's name (an Alterant's `altName`, an action's `name`),
a rendered path text, a field name, or `nothing` when absent (the three-argument outer constructor supplies it).
`goMeta` computes the status from the severity: `PROCESS_ERROR` iff an `:error` row exists; `RegistrationRefused`'s
`showerror` counts its `:error` rows the same way.

REASONING: catalogued failures surface as rows with stable codes where they are delivered, so a consumer reads
a code, never a message, and the status invariant (non-OK ⇒ non-empty diagnostics) holds by construction.

PURPOSE: the element of the delivered object's `diagnostics` part and of `RegistrationRefused`.
"""
struct Diagnostic
    code::Symbol
    severity::Symbol
    message::String
    context::Any
end
Diagnostic(code::Symbol, severity::Symbol, message::AbstractString) =
    Diagnostic(code, severity, String(message), nothing)

"""
    EvalRecord(cell_handle, attr, value, polarity, decided_by)

IS: one final evals row — a Component's, keyed by its occurrence handle (a heading's row among them: the metaBlock the
metaLine forms, a metaLine split by a trailing comment included; an inline metaSegment's by its Line with the Segment as
the key's origin) — the element of `EvalStore`.

DOES: One final evals row. `cell_handle::Vector{UInt8}` holds the `key_bytes` of the row's handle: for a
Component's row the NORMALIZED STRUCTURAL occurrence handle (`occurrence_key`, src/occurrence.jl; a
Segment-carried evals row keys on its owning Line with the Segment recorded as the key's origin) — so two distinct cells
NEVER share a slot (the user-context key, `user_context_key`, rides the fed actions' `decided_by`; no row is keyed on it since
0.4.0 — a heading in the profile refuses at the read). A piece's text is NOT stored on the row since 0.4.0: it is read from the
BLS Component tree through BLS's own access function `BLS.content` (the test layer derives the reference files' fifth column that way).
`attr::Symbol` the attribute; `value::Any` its value; `polarity::Bool` the on/off polarity.
`decided_by::Vector{Vector{UInt8}}` — THE ONE PROVENANCE FIELD:
the `key_bytes` handles of the statements that PRODUCED the row, in application order — the Component that
STATED each applied action (the metaBlock a whole-line metaLine forms, the Segment of an inline one; on
the userMH feed the minted user-context handle): one entry for a single-valued mode (the deciding statement — OWN when it names the row's own Component,
INDIRECT otherwise: for a Block's row own means the entry equals `cell_handle`; for a Segment-carried row — keyed
on its Line with the Segment as the KEY's origin — the entry is the Segment's own occurrence key, which differs from
`cell_handle` by construction: the answer function reads it as the LINE's own statement (the trailing metaSegment's statement is
applied DIRECTLY to its Line — the creator's decision; the Line answers `:own`, the Segment its
Line's answer marked `:indirect`), the contributing
statements' entries for an accumulating one
(Labels; which statement contributed which label stays open — tests/comparison/README.md, Q4), the applied fields' entries for the compound (Id);
a heading row's the carrier of its own `head` statement (the i-th entry the i-th applied statement). MEASURED at the enqueue and the apply, never inferred from a row's presence. The
name is the authored set's word (the creator's confirmed scenarios' `decided_by`; considered alternatives:
`origin`, `source`). Feeds
`readAltValuesEvals(result.altValues_evals)` (sorted `(cell_handle, attr, value)` — key-bytes order).

REASONING: keyed by the row's handle — a Component's normalized structural occurrence handle — so that two distinct cells never share a slot; the row names its
Component by the handle and carries no copy of its text.

PURPOSE: the record `readAltValuesEvals` delivers as `(cell_handle, attr, value, polarity)`.
"""
struct EvalRecord
    cell_handle::Vector{UInt8}
    attr::Symbol
    value::Any
    polarity::Bool
    decided_by::Vector{Vector{UInt8}}
end

"""
    EvalStore()

IS: the per-call store of final `EvalRecord`s — the container behind the evals rows.

DOES: The per-call store of final `EvalRecord`s, deduped per `(cell_handle, attr)` at every put
(`_putEval!`; a re-put supersedes, so the store holds final-evals-only). `EvalStore()` starts empty;
`captureEvals!` (`src/annotations.jl`) populates it at the two apply sites BEFORE the
slot wipe — every Alterant's rows, the Heading's included; the `readAltValuesEvals(result.altValues_evals)` accessor sorts them by
`(cell_handle, attr, value)`.

REASONING: deduped per `(cell_handle, attr)` at every put (a re-put supersedes) so that the store holds
final evals only and the reader need not resolve repeats.

PURPOSE: the store `_putEval!` writes and `readAltValuesEvals` sorts.
"""
struct EvalStore
    records::Vector{EvalRecord}
end
EvalStore() = EvalStore(EvalRecord[])
