# src/result.jl — the typed result-support types: ProcessStatus, Diagnostic, EvalStore.
#
# IS: the dep-free pieces of the public `GoMetaDelivery` surface — the run status (set at the delivery,
#     never stored on `ProcessState` — the seam computes it from the diagnostics at its exit), the typed
#     diagnostic record (the typed form of the DELIVERED errors and warnings — the partition below), and the evals store (these two embedded in
#     `ProcessState`). (The top-level `GoMetaDelivery` aggregate is defined in `state.jl`, AFTER
#     `ProcessState` — the run builds it from the state's own pieces at exit; the two the state embeds must
#     precede `ProcessState`, and the status enum lives beside them, so all three live here.)
# DOES: declares `ProcessStatus` (the OK/non-OK enum), `Diagnostic` (`{code, severity, message, context}`),
#     and `EvalStore` (a growable set of `EvalRecord`s) + its empty constructor.
# REASONING: catalogued failures surface as typed `Diagnostic`s (E-01..E-08): the config-time rows and the
#     seam's refusals are DELIVERED typed; the condition-path rows (E-01/E-02 and the arg-domain and parse
#     rows) are MINTED typed in the closed interpreter, but the statement still ABORTS at the absorb seam
#     (`absorb_meta.jl`: the refusal rethrown as a raw `ErrorException`, its code and context dropped — the
#     routing into the delivered diagnostics a later, separately-gated motion), E-07's mint is pending, and
#     the E-04/E-06 rows still throw (docs/public-api.md §3). `captureEvals!` (the apply sites, before the
#     slot wipe) and `capture_heading!` (the absorb seam's flush) record the evals rows, feeding
#     `readAltValuesEvals`.
# PURPOSE: the stable, total, machine-inspectable result vocabulary.

"""
    @enum ProcessStatus PROCESS_OK PROCESS_ERROR

IS: the run status of a delivery — the two-valued enum every consumer checks first.

DOES: The run status. `PROCESS_OK` ⇒ no error-severity diagnostics (a meta-free input on the no-feed
path is still OK — E-05; a refusal-carrying feed aborts regardless of document meta-freeness);
`PROCESS_ERROR` ⇒ at least one error-severity `Diagnostic` (non-OK ⇒ non-empty diagnostics). This
invariant is enforced when `goMeta` constructs the `GoMetaDelivery`. The
set is intentionally small; any change to it is a clean cut under the versioning policy (docs/public-api.md §6 — no
compatibility promise until at least v0.7; R-V04B-61).

REASONING: a consumer needs one total signal that says whether the evals rows may be trusted before it reads a diagnostic — the invariant non-OK ⇒ non-empty diagnostics makes the enum sufficient.

PURPOSE: the fail-closed signal of the delivered object (R-V04B-28: one of its four parts).
"""
@enum ProcessStatus PROCESS_OK PROCESS_ERROR

"""
    Diagnostic(code, severity, message, context)

A typed, non-throwing diagnostic — the form in which a run DELIVERS its errors and warnings (`GoMetaDelivery.diagnostics`);
not every refusal is delivered — some still throw at v0 (the partition, docs/public-api.md §3).
`code::Symbol` is an E-0x catalogue code (e.g. `:ERR_UNKNOWN_PROFILE`, `:ERR_RANGE_INVALID`;
the config-time codes arm during profile/range validation and the condition-path codes arm in the
closed condition interpreter — the apply-path codes are documented but deferred, docs/public-api.md §3);
`severity::Symbol ∈ {:error,:warning,:info}`; `message::String` is human-readable; `context` is optional
structured context (e.g. a `component_ref` tuple or a slot index), `nothing` when absent.
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
    EvalRecord(cell_handle, attr, value, polarity, content)

IS: one final evals row — a Component's (keyed by its occurrence handle), a metaLine region's heading row
(keyed by the metaLine's own handle) or a fed profile's heading row (keyed by the minted user-context
handle) — the element of `EvalStore`.

DOES: One final evals row. `cell_handle::Vector{UInt8}` holds the `key_bytes` of the row's handle: for a
Component's row the NORMALIZED STRUCTURAL occurrence handle (`occurrence_key`, src/occurrence.jl; a
Segment-carried evals row keys on its owning Line with the Segment recorded as the key's origin), for a
fed profile's heading row the user-context key (`user_context_key`) — so two distinct cells NEVER share a
slot. The verbatim CONTENT bytes ride in the
`content` metadata field (the find-again fingerprint — plain bytes, no hashing core-side);
`attr::Symbol` the attribute; `value::Any` its value; `polarity::Bool` the on/off polarity. Feeds
`readAltValuesEvals(result.altValues_evals)` (sorted `(cell_handle, attr, value)` — key-bytes order) + the
`content_fingerprint` sibling accessor.

REASONING: keyed by the row's handle — a Component's or the metaLine's normalized structural occurrence handle,
a fed profile's minted user-context handle — so that two distinct cells never share a slot; the verbatim
content bytes ride as the find-again fingerprint rather than as the key.

PURPOSE: the record `readAltValuesEvals` delivers as `(cell_handle, attr, value, polarity)` and
`content_fingerprint` as `(cell_handle → content)`.
"""
struct EvalRecord
    cell_handle::Vector{UInt8}
    attr::Symbol
    value::Any
    polarity::Bool
    content::Vector{UInt8}
end

"""
    EvalStore()

IS: the per-call store of final `EvalRecord`s — the container behind the evals rows.

DOES: The per-call store of final `EvalRecord`s, deduped per `(cell_handle, attr)` at every put
(`_putEval!`; a re-put supersedes, so the store holds final-evals-only). `EvalStore()` starts empty;
`captureEvals!` (`src/annotations.jl`) populates it at the two apply-site write-backs BEFORE the
slot wipe and `capture_heading!` at the absorb seam's flush (a metaLine region's rows; the fed profile's
rows during the feed, before the walk); the `readAltValuesEvals(result.altValues_evals)` accessor sorts them by
`(cell_handle, attr, value)`.

REASONING: deduped per `(cell_handle, attr)` at every put (a re-put supersedes) so that the store holds
final evals only and the reader need not resolve repeats.

PURPOSE: the store `_putEval!` writes and `readAltValuesEvals` sorts.
"""
struct EvalStore
    records::Vector{EvalRecord}
end
EvalStore() = EvalStore(EvalRecord[])
