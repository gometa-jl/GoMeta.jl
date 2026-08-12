# src/config.jl — the public input configuration `GoMetaConfig`.
#
# IS: the v0 public input-options type for `goMeta(bytes; config) -> GoMetaResult` (docs/public-api.md §2).
# DOES: declares `GoMetaConfig` with its v0 fields + a keyword constructor with the documented
#     defaults.
# REASONING: this is part of the declared semver public API (additive evolution only). `parse_range` is
#     explicit about what it accepts: `nothing` ⇒ whole input; a given range REQUIRES
#     `first == 1`, else a fail-closed `ERR_RANGE_INVALID` diagnostic
#     (`validate_config` in `GoMeta.jl`).
# PURPOSE: the stable, documented surface a caller uses to drive one `goMeta` call.

"""
    GoMetaConfig(; profile=:jl_share_v1, flavor_tag=:julia, parse_range=nothing,
                  user_mh_profile=nothing, namespace=:default)

The v0 public input options for `goMeta` (additive evolution only; docs/public-api.md §2):

- `profile::Symbol` — the share-profile. The closed default is `:jl_share_v1`; the two OPT-IN names
  `:jl_share_v1_full_parse` / `:jl_share_v1_full_eval` are also config-valid and additionally require the
  explicitly-included opt-in extension (the two-act law — `grammar_profile.jl`); any other name is a
  fail-closed `ERR_UNKNOWN_PROFILE` diagnostic (`validate_config` in `GoMeta.jl`).
- `flavor_tag::Symbol` — the content flavor; validation is ARMED: `:julia` (the default — the `#` lead
  alphabet, byte-untouched) or `:c` (the C-family `//` line-comment flavor: C, Rust & Co.) or `:latex`
  (the `%` lead alphabet, `.tex`); any other value is a fail-closed `ERR_UNKNOWN_FLAVOR` diagnostic
  (`validate_config` in `GoMeta.jl`). Selected, never inferred — the engine never sniffs file
  extensions or content to choose a flavor.
- `parse_range::Union{Nothing,UnitRange{Int}}` — `nothing` ⇒ the whole input; a given range REQUIRES
  `first(parse_range) == 1` (from≠1 was never implemented — `ERR_RANGE_INVALID`), and `last` maps to
  the parse end line.
- `user_mh_profile::Union{Nothing,String}` — `nothing` (the default) ⇒ NO feed, byte-identical to the
  no-feed path; a `String` ⇒ the metaLine BODY seeded into the reserved user meta-hierarchy slot
  (`userMHIdx`, state.jl) BEFORE the walk, via the standard `absorbMeta` intake (queued actions
  enqueue; an explicit `head` RECORDS against the minted user-context handle; e.g. the profile
  `"discard{ :label1 } show"`). Scope at v0 is deliberately MINIMAL: a single feed entry, NOT a general
  user-level configuration system (deliberately scope-limited at v0).
- `namespace::Symbol` — the occurrence-key namespace every `altValues_evals` cell handle is scoped
  under (`:default` by default; the key's length-prefixed namespace segment — docs/public-api.md
  §1.4). One constructor-time guard: a namespace over 65535 bytes throws an `ArgumentError` AT
  CONSTRUCTION (a `GoMetaConfig(...)` call error, before any `goMeta` run — distinct from the
  config-time fail-close rows, which require a constructed config).
"""
struct GoMetaConfig
    profile::Symbol
    flavor_tag::Symbol
    parse_range::Union{Nothing,UnitRange{Int}}
    user_mh_profile::Union{Nothing,String}
    namespace::Symbol   # v0.2 CH-1: the occurrence-key document namespace — an OPAQUE PURE input
                        # (IDB constraint (5): supplied, never inferred; per-call store, so
                        # cross-document uniqueness is the caller/adapter's obligation)
end
function GoMetaConfig(; profile::Symbol = :jl_share_v1,
                       flavor_tag::Symbol = :julia,
                       parse_range::Union{Nothing,UnitRange{Int}} = nothing,
                       user_mh_profile::Union{Nothing,String} = nothing,
                       namespace::Symbol = :default)
    # v0.2 CH-1 boundary guard: key_bytes length-prefixes the namespace with a UInt16 — a >65535-byte
    # namespace would break the serialization framing (the injectivity-by-construction law). Bounded
    # HERE (the config boundary — occurrence_key itself stays total/never-throws on parsed cells).
    ncodeunits(String(namespace)) <= 65535 ||
        throw(ArgumentError("GoMetaConfig: namespace exceeds 65535 bytes — the occurrence-key " *
                            "serialization bound (choose a shorter namespace symbol)"))
    return GoMetaConfig(profile, flavor_tag, parse_range, user_mh_profile, namespace)
end
