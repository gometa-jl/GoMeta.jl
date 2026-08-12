# src/grammar_profile.jl — the versioned grammar profile: the pinned, pre-parse-resolved data
# that parameterizes the closed condition interpreter (caps, precedence, grammar grants).
#
# IS:  the grammar-profile substrate — a plain, immutable data record resolved ONCE per call
#      from the public configuration BEFORE any parsing, so every grammar-dependent decision
#      (scan caps, operator precedence, grammar grants) is pinned + reproducible. The full-arming
#      build extends the skeleton with the two PROVENANCE digests (the canonicalized snapshot of
#      the declared registration record + the profile's own grammar data — the forward-provisioned
#      cache-key components; no result cache ships at v0.2). The resolution law is fixed from
#      day one: a loud stable-message PRE-PARSE refusal on any resolution failure, NEVER a silent fallback to a
#      default — now TOTAL over the four refusal classes (unknown · missing opt-in · corrupt ·
#      incompatible schema; the error oracle `_profile_wellformed_check`).
# DOES: (1) `GrammarProfile` — {schema_version, name, grants (CLOSED at two: the colon→Labels
#      grant and the quoted-first→heading grant), the two dimension-faithful scan caps (outer
#      29-step scan · inner 29-codeunit atom scan — replicating the engine's as-built
#      condition-scanner envelope EXACTLY), the two safety bounds (max_condition_bytes ·
#      max_parser_depth — both far above anything the scan caps let through; they exist as hard
#      walls, not as the envelope), the operator PRECEDENCE table as DATA (five levels,
#      replicating how Julia parses the engine's built condition strings: prefix-not > eager-and
#      '&' > eager-or '|' > short-circuit-and '&&' > short-circuit-or '||'/','-lowering), the
#      condition-intake mode, and the two digests}. (2) `resolve_profile(config)` — resolves the
#      config's profile name through the error oracle; the three known names resolve (the closed
#      default to the pinned constant; the two opt-in names to their dynamically built profiles
#      once their mode is registered); ANY other name meets the loud pre-parse refusal. (3) `cache_key(profile)`
#      — the ONE composition point a future result cache must use (never invent its own).
# REASONING: grammar behavior must be a pure function of pinned data — never of ambient state
#      (resolution touches NO per-call state and NO dynamic scope), never of a fallback default
#      (a mis-named profile is a configuration error, loudly refused before any text is parsed).
#      The digests are computed from the DECLARED registration record and the pinned grammar
#      constants — NEVER from live method tables (snapshot-not-live: the reflection memo's law
#      at the profile seam; the fold is a plain FNV-1a over a canonical serialization, so the
#      value is deterministic across sessions and Julia versions, not hostage to `Base.hash`).
# PURPOSE: the determinism substrate of the closed interpreter — the caps, precedence, and
#      registration inventory a condition parses under are readable, versioned DATA.

"""
    GrammarProfile

The immutable, versioned grammar-profile record (resolved pre-parse; plain data):

- `schema_version::UInt8` — the profile RECORD's schema (this layout = 3; 1 = the pre-mode
  skeleton, 2 = the `mode` field, 3 = the digest fields).
- `name::Symbol` — the resolved profile's name.
- `grants::NTuple{2,Symbol}` — the CLOSED grammar-grant set: `:colon_labels` (the `:` label
  vocabulary) and `:quoted_first_heading` (reserved; inert until the heading recognizer lands).
- `outer_scan_cap::Int` / `inner_scan_cap::Int` — the dimension-faithful condition-scanner caps
  (one outer step per operator char, whitespace char, or WHOLE atom; the inner cap bounds one
  atom's scan) — byte-compatible with the engine's as-built envelope.
- `max_condition_bytes::Int` / `max_parser_depth::Int` — hard safety walls (unreachable through
  the scan caps by construction; they bound raw input size and grouping depth).
- `precedence::NTuple{5,Pair{Symbol,Int}}` — operator precedence as DATA, tightest first:
  `:not`, `:and` (`&`, eager), `:or` (`|`, eager), `:sc_and` (`&&`), `:sc_or` (`||` and the
  `,` lowering) — replicating how Julia parses the engine's built condition strings.
- `registration_digest::UInt64` / `grammar_digest::UInt64` — the canonicalized provenance
  fingerprints (declared registration record · the profile's own grammar data); computed from
  DECLARED data only, never from live method tables (snapshot-not-live).
"""
struct GrammarProfile
    schema_version::UInt8
    name::Symbol
    grants::NTuple{2,Symbol}
    outer_scan_cap::Int
    inner_scan_cap::Int
    max_condition_bytes::Int
    max_parser_depth::Int
    precedence::NTuple{5,Pair{Symbol,Int}}
    mode::Symbol      # v0.2 the condition-intake MODE (:closed_v1 = the safe
                      # default; any other mode resolves ONLY through the opt-in registry)
    registration_digest::UInt64   # the full-arming provenance fields (schema 3):
    grammar_digest::UInt64        #   the two cache-key components, digests of pinned DATA
end

# ── the pinned base grammar DATA (the one source every profile construction reads) ───────────────
const _BASE_GRANTS = (:colon_labels, :quoted_first_heading)
const _BASE_OUTER_SCAN_CAP = 29      # the as-built 29-step wall (refusal, never truncation)
const _BASE_INNER_SCAN_CAP = 29      # the as-built 29-codeunit atom wall
const _BASE_MAX_CONDITION_BYTES = 4096  # raw-byte wall (a condition body is a metaLine slice;
                                        # the scan caps bind first)
const _BASE_MAX_PARSER_DEPTH = 32    # grouping depth; ≤ the outer step count by construction
const _BASE_PRECEDENCE = (:not => 5, :and => 4, :or => 3, :sc_and => 2, :sc_or => 1)
const _SUPPORTED_PROFILE_SCHEMAS = (0x03,)   # schema 3: the two digest fields (layout change)
const _PROFILE_MODE_SET = (:closed_v1, :full_julia_parse_v1, :full_eval_v1)

# ── the canonical digest fold: FNV-1a over UTF-8 codeunits (deterministic across sessions and
# Julia versions — deliberately NOT `Base.hash`, whose String seed is version-scoped) ─────────────
const _FNV_OFFSET = 0xcbf29ce484222325
function _digest_fold(h::UInt64, s::AbstractString)::UInt64
    for b in codeunits(s)
        h = (h ⊻ b) * 0x00000100000001b3
    end
    return h
end

"""
    _fold_parts(h::UInt64, parts...) -> UInt64

The INJECTIVE component fold (external-review-commissioned): every part is folded as
`<codeunit-length>:<bytes>;` — so no arrangement of delimiter-bearing field values (a
`|` inside an identifier, say) can make two distinct part sequences serialize to one byte
stream. Both digests fold their meaning-bearing components exclusively through this.
"""
function _fold_parts(h::UInt64, parts...)::UInt64
    for p in parts
        s = string(p)
        h = _digest_fold(h, string(ncodeunits(s), ":"))
        h = _digest_fold(h, s)
        h = _digest_fold(h, ";")
    end
    return h
end

"""
    _grammar_digest(name, mode, grants, outer, inner, max_bytes, max_depth, precedence) -> UInt64

The fingerprint of a profile's GRAMMAR data, folded over the FIELD VALUES passed (a canonical
`|`-delimited serialization) — deliberately value-parameterized, not const-reading, so the
error oracle can RE-FOLD any profile record's own fields and compare against its stored
digest (a deserialized future profile with drifted caps, or a lying stored digest, is caught
— the digest-consistency arm below). Pure — reads only its arguments.
"""
function _grammar_digest(name::Symbol, mode::Symbol, grants::NTuple{2,Symbol},
                         outer::Int, inner::Int, max_bytes::Int, max_depth::Int,
                         precedence::NTuple{5,Pair{Symbol,Int}})::UInt64
    h = _digest_fold(_FNV_OFFSET, "gometa-grammar-v1")
    h = _fold_parts(h, name, mode, grants[1], grants[2],
        outer, inner, max_bytes, max_depth)
    for pr in precedence
        h = _fold_parts(h, first(pr), last(pr))
    end
    return h
end

"The re-fold of a CONSTRUCTED record's own grammar fields (the oracle's consistency probe)."
_grammar_digest(p::GrammarProfile)::UInt64 =
    _grammar_digest(p.name, p.mode, p.grants, p.outer_scan_cap, p.inner_scan_cap,
        p.max_condition_bytes, p.max_parser_depth, p.precedence)

"""
    _mk_profile(name::Symbol, mode::Symbol, registration_digest::UInt64) -> GrammarProfile

The ONE profile constructor every resolution path uses — pinned base grammar data + the
passed registration digest + the grammar digest folded from THE SAME VALUES it constructs
with. (The default profile const is built in the registry file, AFTER the default registry
exists — the registration digest is a fold over its declared record.)
"""
function _mk_profile(name::Symbol, mode::Symbol, registration_digest::UInt64)::GrammarProfile
    GrammarProfile(0x03, name, _BASE_GRANTS,
        _BASE_OUTER_SCAN_CAP, _BASE_INNER_SCAN_CAP,
        _BASE_MAX_CONDITION_BYTES, _BASE_MAX_PARSER_DEPTH,
        _BASE_PRECEDENCE, mode,
        registration_digest,
        _grammar_digest(name, mode, _BASE_GRANTS, _BASE_OUTER_SCAN_CAP,
            _BASE_INNER_SCAN_CAP, _BASE_MAX_CONDITION_BYTES,
            _BASE_MAX_PARSER_DEPTH, _BASE_PRECEDENCE))
end

# The ENGINE-identity cache-key component (external-review-commissioned: declaration
# digests alone are blind to implementation changes — a new engine version must never
# reuse a cached result). Read once at load from the loading package's own version.
const _ENGINE_VERSION = string(pkgversion(@__MODULE__))

"""
    cache_key(p::GrammarProfile) -> String

The composed provenance key
(`gometa/v<engine>/<name>/<mode>/s<schema>/g<grammar>/r<registration>`) — the ONE public
composition point: a future result cache must key through this, never invent its own
composition. The engine VERSION component carries implementation identity (the digests
fingerprint DECLARATIONS only). RECORDED OBLIGATIONS for any future cache, as PRINCIPLE
(never a closed list): EVERY result-affecting input joins the key, keyed by CONTENT and
never by reference — config identity today (namespace, user_mh_profile, parse_range,
profile — the share-profile selector; flavor_tag — the ARMED content-flavor selector,
result-affecting: its `FlavorProfile` record carries its own injective FNV-1a `digest`
for exactly this join) and whatever future
surfaces add (cascaded feeds, lifted feed state); fed and unfed runs must never alias.
The 64-bit digests are key components, not identity proofs — verify the canonical
identity on a cache hit before reuse. No result cache ships at v0.2 (forward provision
only).
"""
cache_key(p::GrammarProfile)::String =
    string("gometa/v", _ENGINE_VERSION, "/", p.name, "/", p.mode,
        "/s", Int(p.schema_version),
        "/g", string(p.grammar_digest, base = 16),
        "/r", string(p.registration_digest, base = 16))

"""
    _profile_wellformed_check(p::GrammarProfile) -> p

The profile ERROR ORACLE's corrupt/incompatible arms — a loud stable-message PRE-PARSE refusal for any
profile record whose data violates the closed grammar laws. Runs on EVERY `resolve_profile`
return path. ARM ORDERING is the precedence rule (external-review-ratified; stated AS
SHIPPED — delta-trued): schema compatibility FIRST (a future-schema record classifies
INCOMPATIBLE even where its shape would also fail the corrupt arms), then the positivity
shapes, then the cap/wall cross-field relation, then the remaining per-field shapes
(grants, mode, precedence), then the digest re-fold LAST (so a corrupt field trips its own
arm before the re-fold reads it — the two hard edges are schema-first and re-fold-last;
the middle arms all classify CORRUPT and differ only in message).
RECORDED OBLIGATION for any future DESERIALIZER: decode a minimal envelope (schema field
first, required-field presence without throwing) BEFORE constructing a record for this
oracle — truncation is the decoder's refusal class, not this oracle's. For the pinned
constant the check is always-true TODAY — the wall exists for future profile SOURCES; the
corrupt-class tests construct bad records directly, so the arms are witnessed, not vacuous.
"""
function _profile_wellformed_check(p::GrammarProfile)::GrammarProfile
    p.schema_version in _SUPPORTED_PROFILE_SCHEMAS ||
        error("GoMeta config: INCOMPATIBLE grammar-profile schema ", Int(p.schema_version),
            " — the supported schema set is ", Int.(_SUPPORTED_PROFILE_SCHEMAS),
            "; there is NO fallback profile (the pre-parse error oracle)")
    (p.outer_scan_cap > 0 && p.inner_scan_cap > 0 &&
     p.max_condition_bytes > 0 && p.max_parser_depth > 0) ||
        error("GoMeta config: CORRUPT grammar profile ", repr(p.name),
            " — every scan cap and safety wall must be positive ",
            "(the pre-parse error oracle; no fallback)")
    p.max_condition_bytes >= p.inner_scan_cap ||
        error("GoMeta config: CORRUPT grammar profile ", repr(p.name),
            " — the raw-byte wall sits BELOW the inner scan cap (the walls exist ",
            "as hard bounds ABOVE the cap-reachable envelope; a profile whose ",
            "fields are individually valid but mutually inconsistent is corrupt — ",
            "the cross-field arm of the pre-parse error oracle; no fallback)")
    all(g in _BASE_GRANTS for g in p.grants) ||
        error("GoMeta config: CORRUPT grammar profile ", repr(p.name),
            " — unknown grammar grant (the closed grant set is ", _BASE_GRANTS,
            "; the pre-parse error oracle; no fallback)")
    p.mode in _PROFILE_MODE_SET ||
        error("GoMeta config: CORRUPT grammar profile ", repr(p.name),
            " — unknown condition-intake mode ", repr(p.mode),
            " (the closed mode set is ", _PROFILE_MODE_SET,
            "; the pre-parse error oracle; no fallback)")
    (Tuple(first(pr) for pr in p.precedence) === (:not, :and, :or, :sc_and, :sc_or) &&
     sort!([last(pr) for pr in p.precedence]) == [1, 2, 3, 4, 5]) ||
        error("GoMeta config: CORRUPT grammar profile ", repr(p.name),
            " — the precedence table must carry the five closed operator names with ",
            "levels a permutation of 1..5 (the pre-parse error oracle; no fallback)")
    p.grammar_digest == _grammar_digest(p) ||
        error("GoMeta config: CORRUPT grammar profile ", repr(p.name),
            " — the stored grammar digest does not re-fold from the record's own ",
            "fields (drifted fields or a lying stored digest; the digest-consistency ",
            "arm of the pre-parse error oracle; no fallback)")
    return p
end

# ── the dual-mode OPT-IN mode registry (DATA + plumbing ONLY — no mode implementation, no
# parser, no evaluator lives in src/). The two opt-in modes ship OUTSIDE the package source,
# in `extensions/condition_modes_opt_in.jl`, which the OPERATOR must `include` explicitly
# after loading the package (the first explicit act); selecting an opt-in profile in the
# GoMetaConfig is the second. Without BOTH acts every document parses under the closed
# default — the engine is never unconditionally restricted (the ruling), and the default is
# never silently widened (the security law).
const _CONDITION_MODES = Dict{Symbol,Function}()

"""
    register_condition_mode!(mode::Symbol, parse_fn) -> mode

Register an OPT-IN condition-intake mode (called by the explicitly-included extension file,
never by the package itself). `parse_fn(text, registry, profile)` must be TOTAL: it returns
a condition node the evaluator accepts OR a typed refusal `Diagnostic` — never throws.
"""
function register_condition_mode!(mode::Symbol, parse_fn::Function)
    _CONDITION_MODES[mode] = parse_fn
    return mode
end

"""
    condition_mode_fn(mode::Symbol) -> Function

The registered intake function for an OPT-IN mode. Unregistered ⇒ a loud stable-message error naming the
required operator act (defense in depth: `resolve_profile` already refuses such a config,
so reaching here means a mis-wired opt-in — it fails LOUD, never silently closed-parses).
"""
function condition_mode_fn(mode::Symbol)
    haskey(_CONDITION_MODES, mode) ||
        error("GoMeta absorb: the condition mode ", repr(mode), " is not registered — ",
            "include \"extensions/condition_modes_opt_in.jl\" explicitly to opt in ",
            "(see docs/public-api.md §2; the dual-mode ruling)")
    return _CONDITION_MODES[mode]
end

const _PROFILE_MODES = Dict(
    :jl_share_v1             => :closed_v1,
    :jl_share_v1_full_parse  => :full_julia_parse_v1,
    :jl_share_v1_full_eval => :full_eval_v1,
)

"""
    resolve_profile(config::GoMetaConfig) -> GrammarProfile

Resolve the configuration's grammar profile BEFORE any parsing. `:jl_share_v1` resolves to
the pinned closed default. The two OPT-IN profiles (`:jl_share_v1_full_parse`,
`:jl_share_v1_full_eval`) resolve ONLY when their mode implementation has been registered
by the explicitly-included extension file — an opt-in name without the extension loaded
meets a loud stable-message PRE-PARSE refusal naming the required act. Any other name is a configuration
error — there is NO fallback profile (a mis-named profile must never silently parse under
different grammar data). Every return path passes the error oracle
(`_profile_wellformed_check` — the corrupt/incompatible arms; unknown + missing-opt-in are
the two arms below). Touches no per-call state and no dynamic scope.
"""
function resolve_profile(config::GoMetaConfig)::GrammarProfile
    config.profile === :jl_share_v1 &&
        return _profile_wellformed_check(DEFAULT_GRAMMAR_PROFILE)
    if haskey(_PROFILE_MODES, config.profile)
        mode = _PROFILE_MODES[config.profile]
        haskey(_CONDITION_MODES, mode) ||
            error("GoMeta config: the profile ", repr(config.profile), " is an OPT-IN mode ",
                "and its implementation is not loaded — include ",
                "\"extensions/condition_modes_opt_in.jl\" explicitly AFTER loading the ",
                "package to opt in (see docs/public-api.md §2; the dual-mode ruling)")
        # the opt-in profile shares the default REGISTRATION digest (the registry is the
        # default one; a custom-registry profile story is a later-version concern) — the
        # grammar digest folds the opt-in name+mode, so the two cache keys never collide.
        return _profile_wellformed_check(_mk_profile(config.profile, mode,
            DEFAULT_GRAMMAR_PROFILE.registration_digest))
    end
    error("GoMeta config: unknown grammar profile ", repr(config.profile),
        " — the profile inventory is (:jl_share_v1, :jl_share_v1_full_parse, ",
        ":jl_share_v1_full_eval); there is NO fallback profile ",
        "(see docs/public-api.md §2)")
end
