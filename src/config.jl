# src/config.jl — the public input configuration `GoMetaConfig`.
#
# IS: the v0 public input-options type for `goMeta(bytes; config) -> GoMetaDelivery` (docs/public-api.md §2).
# DOES: declares `GoMetaConfig` with its v0 fields + a keyword constructor with the documented
#     defaults.
# REASONING: this is part of the declared public API (docs/public-api.md §2; its versioning policy §6 — clean cuts until at least v0.7, R-V04B-61). `parse_range` is
#     taken plain: `nothing` ⇒ whole input; a given range's `last` is the parse end line and its `first` is never
#     read (the coded range refusal left at stage 5's E8 of the v0.4 build — census row 30).
# PURPOSE: the stable, documented surface a caller uses to drive one `goMeta` call.

"""
    GoMetaConfig(; flavor_tag=:julia, parse_range=nothing, user_mh_profile=nothing, namespace=:default)

IS: the v0 public input options for `goMeta` (docs/public-api.md §2; the versioning policy §6) — an immutable
four-field struct with one keyword constructor, exported with `goMeta`.

DOES: carries the four fields, read by the run as named:

- (the `profile::Symbol` field — the selector of the closed condition grammar's profile and its two opt-in names — left
  at E13, stage 5's E13 of the v0.4 build, with the grammar profile — census rows 1 and 30; his order §319, R-V04B-106
  (2); the EXPORTED type re-shaped, R-V04B-61's clean cut — `GoMetaConfig(profile = …)` is a MethodError since; the
  RENDER's share-profile `jl-share-v1` is the development tool's and was never this field.)
- `flavor_tag::Symbol` — the content flavor, a CLOSED inventory: `:julia` (the default — the `#` lead
  alphabet, byte-untouched) or `:c` (the C-family `//` line-comment flavor: C, Rust & Co.) or `:latex`
  (the `%` lead alphabet, `.tex`); any other value throws at `BLS.flavor_for` (a stable message naming the
  inventory, no fallback — docs/public-api.md §3.4; the coded config-time refusal left at stage 5's E8 of the v0.4
  build, census row 30). Selected, never inferred — the engine never sniffs file extensions or content to choose a
  flavor. Read once, by `goMeta` before the parse (`BLS.flavor_for(config.flavor_tag)`); the profile then rides the
  parse state.
- `parse_range::Union{Nothing,UnitRange{Int}}` — `nothing` ⇒ the whole input; a given range is taken PLAIN:
  `last` is the parse end line and `first` is never read (a start line other than 1 was never implemented —
  `5:10` parses lines 1..10); a non-positive `last` (`1:0`) parses the whole file (the parser's contract). Read once,
  by `goMeta` (`to = last(range)`, `-1` for `nothing`).
- `user_mh_profile::Union{Nothing,String}` — `nothing` (the default) ⇒ NO feed, byte-identical to the
  no-feed path — and so an EMPTY or whitespace-only `String` (inert like `nothing` since stage 2 of the Alterants build; his
  word of 2026-10-16, R-ALT-18 / R-ALT-22 — white space as the absorb's ONE
  predicate `_isspace_valid` reads it, R-ALT-25: an invalid byte sequence is content); any other `String` ⇒ the metaLine BODY
  seeded into the reserved user meta-hierarchy slot
  (`userMHIdx`, state.jl) BEFORE the walk, via the standard `absorbMeta` intake (queued actions
  enqueue; a heading in any form REFUSES at the read with his message — docs/public-api.md §2 and §3.4; before stage 1
  of the Alterants build an explicit `head` recorded against the minted user-context handle; e.g. the profile
  `"discard{ :label1 } show"`). Scope at v0 is deliberately MINIMAL: a single feed entry, NOT a general
  user-level configuration system (deliberately scope-limited at v0). Read by `goMeta` and `feed_user_mh!`.
- `namespace::Symbol` — the occurrence-key namespace every `altValues_evals` cell handle is scoped
  under (`:default` by default; encoded as the key's length-prefixed namespace segment — docs/public-api.md
  §2). One constructor-time guard: a namespace over 65535 bytes throws an `ArgumentError` AT
  CONSTRUCTION by the keyword form (a `GoMetaConfig(; …)` call error, before any `goMeta` run; the generated positional form carries no guard; no config-time refusal remains since
  stage 5's E13 — the entry refusals are the registry door's). Read wherever a key is minted: the capture
  (`captureEvals!`), the walk's context record, the user-context mint (`st.config.namespace`).

The whole value rides the run as `ProcessState.config` (`init_state`); nothing of it is delivered.

REASONING: this is part of the declared public API (docs/public-api.md §2; its versioning policy §6 — clean cuts
until at least v0.7, R-V04B-61): the options are selected by the caller, never inferred by the Engine, and the one
bound that would break a key's serialization is refused at the keyword constructor (the generated positional form carries no guard).

PURPOSE: the stable, documented surface a caller uses to drive one `goMeta` call.
"""
struct GoMetaConfig
    flavor_tag::Symbol
    parse_range::Union{Nothing,UnitRange{Int}}
    user_mh_profile::Union{Nothing,String}
    namespace::Symbol   # v0.2 CH-1: the occurrence-key document namespace — an OPAQUE PURE input
                        # (IDB constraint (5): supplied, never inferred; per-call store, so
                        # cross-document uniqueness is the caller/adapter's obligation)
end
function GoMetaConfig(; flavor_tag::Symbol = :julia,
                       parse_range::Union{Nothing,UnitRange{Int}} = nothing,
                       user_mh_profile::Union{Nothing,String} = nothing,
                       namespace::Symbol = :default)
    # v0.2 CH-1 boundary guard: key_bytes length-prefixes the namespace with a UInt16 — a >65535-byte
    # namespace would break the serialization framing (the injectivity-by-construction law). Bounded
    # HERE (the config boundary — occurrence_key itself stays total/never-throws on parsed cells).
    ncodeunits(String(namespace)) <= 65535 ||
        throw(ArgumentError("GoMetaConfig: namespace exceeds 65535 bytes — the occurrence-key " *
                            "serialization bound (choose a shorter namespace symbol)"))
    return GoMetaConfig(flavor_tag, parse_range, user_mh_profile, namespace)
end
