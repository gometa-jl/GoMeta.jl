# src/result.jl — the typed result-support types: ProcessStatus, Diagnostic, EvalStore.
#
# IS: the dep-free pieces of the public `GoMetaResult` surface that `ProcessState` itself embeds — the run
#     status, the typed diagnostic record (which replaces every bare `error()`), and the per-cell
#     verdict store. (The top-level `GoMetaResult` aggregate is defined in `state.jl`, AFTER
#     `ProcessState` — its first field; these three types must precede `ProcessState`, so they live here.)
# DOES: declares `ProcessStatus` (the OK/non-OK enum), `Diagnostic` (`{code, severity, message, context}`),
#     and `EvalStore` (a growable set of `EvalRecord`s) + its empty constructor.
# REASONING: catalogued failures surface as typed `Diagnostic`s (E-01..E-08); the E-04/E-06 rows
#     still throw and the condition-path rows (E-01/E-02/E-07) stay deferred at v0
#     (docs/public-api.md §3). `capture_verdicts!` records per-cell verdicts
#     before the slot wipe, feeding `altValues_evals`.
# PURPOSE: the stable, total, machine-inspectable result vocabulary.

"""
    @enum ProcessStatus PROCESS_OK PROCESS_ERROR

The run status. `PROCESS_OK` ⇒ no error-severity diagnostics (a meta-free input on the no-feed
path is still OK — E-05; a refusal-carrying feed aborts regardless of document meta-freeness);
`PROCESS_ERROR` ⇒ at least one error-severity `Diagnostic` (non-OK ⇒ non-empty diagnostics). This
invariant is enforced when `goMeta` constructs the `GoMetaResult`; these types are additive until then. The
set is intentionally small + extensible (a new status value would slot in here without
breaking the read-window).
"""
@enum ProcessStatus PROCESS_OK PROCESS_ERROR

"""
    Diagnostic(code, severity, message, context)

A typed, non-throwing diagnostic — the total surface that replaces every bare `error()`/silent exit.
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

One final per-cell verdict captured before the slot wipe. `cell_handle::Vector{UInt8}` holds the
`key_bytes` of the cell's NORMALIZED STRUCTURAL occurrence handle (`occurrence_key`,
src/occurrence.jl; a Segment-carried verdict keys on its owning Line with the Segment recorded as the
key's origin), so two distinct cells NEVER share a slot. The verbatim CONTENT bytes ride in the
`content` metadata field (the find-again fingerprint — plain bytes, no hashing core-side);
`attr::Symbol` the attribute; `value::Any` its value; `polarity::Bool` the on/off polarity. Feeds
`altValues_evals(result)` (sorted `(cell_handle, attr, value)` — key-bytes order) + the
`content_fingerprint` sibling accessor.
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

The per-call store of final `EvalRecord`s (deduped per `(cell_handle, attr)` during Apply — a
re-applied cell supersedes, so the store holds final-verdicts-only). `EvalStore()` starts empty;
`capture_verdicts!` (`src/annotations.jl`) populates it at the two apply-site write-backs BEFORE the
slot wipe; the `altValues_evals(result)` accessor sorts them by `(cell_handle, attr, value)`.
"""
struct EvalStore
    records::Vector{EvalRecord}
end
EvalStore() = EvalStore(EvalRecord[])
