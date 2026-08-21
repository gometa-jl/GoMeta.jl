# GoMeta.jl — the top module: the include spine + the public `goMeta` entry
#
# IS: the GoMeta package top module. It holds the ordered include spine — config.jl, result.jl,
#     bls/BLS.jl, state.jl, alterants/registry.jl, annotations.jl,
#     absorb/absorb_meta.jl, absorb/walk.jl, alterants/apply.jl, emit/emit.jl — and declares the
#     exported semver surface: `goMeta`, `altValues_evals`, `GoMetaConfig`, `GoMetaResult`
#     (docs/public-api.md §1.1; asserted by tests/unit/public_surface_tests.jl), plus the
#     declared `public` tier of qualified names (docs/public-api.md §1.2 — e.g. `GoMeta.outputs`,
#     `GoMeta.PROCESS_OK`).
# DOES: `goMeta(bytes; config::GoMetaConfig = GoMetaConfig(), registry::AlterantRegistry =
#     DEFAULT_REGISTRY) -> GoMetaResult` runs the pipeline parse -> Absorb-walk (enqueue alterant
#     actions) -> Apply (evaluate conditions + apply) -> lazy render. `validate_config` fail-closes
#     an invalid config into a `PROCESS_ERROR` `GoMetaResult` carrying typed `Diagnostic`s BEFORE any
#     parse or render work (the input bytes are never touched): `ERR_UNKNOWN_PROFILE` (E-03 — the
#     three profile names are `:jl_share_v1` + the two opt-in names, docs/public-api.md §3.1)
#     and `ERR_RANGE_INVALID` (E-08 — a given `parse_range` requires `first == 1` and a non-empty
#     range). The absorb-walk + apply run inside one per-call dynamic scope, `with(STATE =>
#     init_state(parse_state, config, registry))`, so two
#     concurrent calls never share state; the driver walk enters each file-level Block, absorbs its
#     metaLines, applies the queued alterant actions, writes back the Block-grain Visib verdict,
#     and captures per-cell verdicts for `altValues_evals(result)`. `outputs(result)` yields
#     `(blsStructure_bytes, render_bytes)` — the verdict-free structural tree + the jl-share-v1 render —
#     and yields the EMPTY pair on a non-OK result ("no render attempted"). The optional
#     `config.user_mh_profile` seeds the reserved user slot of the meta-hierarchy before the walk
#     (`feed_user_mh!`; a fed explicit `head` records one row against the minted user-context
#     handle — docs/public-api.md §1.4/§2; experimental).
# REASONING: the public contract (docs/public-api.md §2) requires `goMeta` to be pure and
#     deterministic FOR THE ENGINE'S OWN OPERATIONS (no filesystem / clock / environment read; a v0
#     condition body runs in the closed no-eval interpreter — only under the opt-in
#     `:full_eval_v1` extension mode can it read or have effects — README SECURITY),
#     and TOTAL over the config-time
#     catalogued surface — non-OK implies non-empty diagnostics. Honest edges: the
#     E-04 apply-path crash-origin and the E-06 absorb-path guarded refusal are documented but
#     not yet typed (conversion deferred); the condition-path refusals are TYPED since the
#     closed-interpreter flip, with E-07's mint PENDING (the unqueryable-alt shape still aborts
#     raw). The full honest-edges catalogue: docs/public-api.md §3.
# PURPOSE: the single auditable entry point — bytes in, a typed `GoMetaResult` out, with all observable
#     output flowing through `outputs` / `altValues_evals`.
module GoMeta

"""
    GoMeta

Interpretable `#~` metadata for source files: `goMeta(bytes)` parses the input into the
BLS tree (File → Block → Line → Segment), absorbs the metadata, applies the registered
Alterants, and renders the share view — bytes in, bytes out; it **evaluates, never
executes**.

# The metaLine marker family

| marker              | meaning                                                           |
|:--------------------|:------------------------------------------------------------------|
| `#~`, `#~N`, `#~~…` | a metaLine — meta content at depth 1, `N`, or the tilde-run count |
| `#~N!`, bare `#~!`  | the INERT metaLine — structurally live, its content ignored       |
| `#~!N`              | a refused mistake (transposed inert marker) — loud parse error    |
| `#]`                | the close-marker — closes the innermost metaBlock, detaches after |
| trailing `#~ …`     | an inline metaSegment applying to its own content line            |

The authoritative reference ships at `docs/SYNTAX-AND-SEMANTICS.md`.

# `#~N!` — the inert metaLine (`#~!` is the depth-1 form)

**IS**: the in-grammar "ignore the meta content following this `!`" toggle — `#~N`
remains valid in terms of the BLS structure. **DOES**: `#~N! <content>` ≡ `#~N` — depth,
block role, close/supersede participation, and attachment all behave exactly like the
live marker; only the content after the `!` is ignored. Holds at both grains (whole
metaLines and inline metaSegments); the depth digit is still validated (`#~9!` refuses
out-of-window exactly like `#~9`). **REASONING**: if the marker also lost its BLS place,
components following `#~2!` could inherit things they were not meant to inherit —
inheritance routes through the last metaBlock whose depth is less than the component's
own, so the inert marker must keep its depth for the usual rules to hold (detaching
instead would merely duplicate `#]`). **PURPOSE**: toggle a metaLine's effect off while
editing, without disturbing the structure around it — remove the `!` and the same line
is live again.

The transposed spelling `#~!N` is flagged loudly as a mistake: it throws
`GoMeta parse: bang-first meta marker …`, naming the corrected spelling. To MENTION a
marker in prose, quote-glue it: `"#~!2"`.

# `#]` — the close-marker

**IS**: the explicit end of the innermost open metaBlock. **DOES**: closes the innermost
open metaBlock (outer blocks stay open) and DETACHES the components following it — they
do not inherit anything at all anymore, until the next metaLine that heads its own
block. In settribute terms: starts a new block, counts as meta, carries no content of
its own, and stops attachment (`:startNewBlock`, `:containsMeta`, `:ignoreThisMeta`,
`:stopAttachmentToMeta`). **PURPOSE**: bound a metadata scope exactly, where an implicit
close (a following shallower-or-equal marker, a blank line, end-of-file) is not what the
author means. Demonstrated end-to-end in `examples/` (`feature_explicit_close.jl`).
"""
GoMeta

#########################################################################################
########### Imports #####################################################################
using StaticArrays, InlineStrings  # stack-allocated fixed-size arrays + inline string types; the slot tensors and the work vectors are plain Vector/Array (registry.jl, apply.jl)

#########################################################################################
############ Includes ###################################################################

include("config.jl")    # GoMetaConfig (the public input options)
include("textlaw.jl")   # the GoMeta-owned text-law kernel (pinned alphabets + nfc_key)
include("grammar_profile.jl")       # v0.2 CH-2/CH-4: the versioned grammar-profile substrate (caps/precedence/
                                    #   grants + provenance digests as DATA; the pre-parse error oracle) — its
                                    #   DEFINITIONS depend on GoMetaConfig only, so it sits after config.jl;
                                    #   the DEFAULT profile CONST is built at the registry tail (its
                                    #   registration digest folds the declared record; call-time-bound refs).
include("result.jl")    # ProcessStatus / Diagnostic / EvalStore (the GoMetaResult support types)
include("bls/BLS.jl")
include("occurrence.jl")            # v0.2 CH-1 (step 1): the normalized occurrence handle — depends
                                    # on BLS ONLY; everything downstream may
                                    # reference OccurrenceKey/occurrence_key/key_bytes
import .BLS
include("state.jl")     # per-call ProcessState + the typed GoMetaResult surface + the AlterantRegistry type + the STATE/ctx() seam
include("alterants/registry.jl")    # the Alterants + CnS layers, combined (Alterants BEFORE CnS)
using .CnS: getState, getAltState
include("condition.jl")             # the closed condition interpreter (bounded intake + algebra +
                                    #   printer + evaluate) — after registry.jl (the query dispatch
                                    #   surface) + state.jl; inert until the engine flips to it.
include("annotations.jl")           # the per-cell verdict surface — verdict capture +
                                    #   altValues_evals(result). AFTER registry.jl (Alterants.Visib/Id) + state.jl
                                    #   (ProcessState/GoMetaResult/EvalStore); BEFORE walk.jl + the driver below
                                    #   (which call capture_verdicts!). Holds no eval, no render-write.
include("absorb/absorb_meta.jl")
using .AbsorbMeta
include("absorb/walk.jl")           # goMetaAddOns absorb-half — absorbMeta (above) must precede it
include("alterants/apply.jl")       # goMetaAddOns apply-half — late-bound from walk, so OK after walk
include("emit/emit.jl")
import .WriteOutFile: render_bytes


#########################################################################################
########### Public API (the declared semver surface — re-exported) #####################
# The four names below ARE GoMeta's declared public API (documented in docs/public-api.md §1.1).
# `export` re-exports them — all are defined directly in this
# module via the include spine above — so `using GoMeta` brings exactly these into scope and
# `names(GoMeta)` IS the machine-checkable semver surface (asserted by tests/unit/public_surface_tests.jl).
# EVERYTHING else stays PACKAGE-PUBLIC (reached qualified, e.g. GoMeta.PROCESS_OK / .Diagnostic):
# the supporting types (ProcessStatus/Diagnostic/EvalStore/AlterantRegistry),
# DEFAULT_REGISTRY, serialize_evals, outputs, content_fingerprint, EvalRecord, and the PROCESS_OK/PROCESS_ERROR values
# — the eleven names on the `public` line below.
# Qualified import (`import GoMeta as GM`) is UNAFFECTED by these exports and remains canonical for namespace
# hygiene + multi-implementation use; exporting serves the single-implementation `using` convenience only.
export goMeta, altValues_evals, GoMetaConfig, GoMetaResult
public outputs, serialize_evals, content_fingerprint, EvalRecord, EvalStore, ProcessStatus, PROCESS_OK, PROCESS_ERROR, Diagnostic, AlterantRegistry, DEFAULT_REGISTRY

#########################################################################################
#~~ Config-time validation

"""
    validate_config(config::GoMetaConfig) -> Vector{Diagnostic}

Config-time validation of the public `GoMetaConfig`, returning the (possibly empty) typed
diagnostics that `goMeta` fail-closes on. A non-empty result means `goMeta` returns a `PROCESS_ERROR`
`GoMetaResult` BEFORE any parse or render work is attempted (the input bytes are never touched;
the docs/public-api.md §2 "no render attempted" contract).

The three v0 config-time error rows of the documented error catalogue (docs/public-api.md §3):

- `ERR_UNKNOWN_PROFILE` (E-03) — `config.profile` must be one of the three profile names: `:jl_share_v1`
  (the closed default) or the two OPT-IN names `:jl_share_v1_full_parse` / `:jl_share_v1_full_eval` (which
  additionally require the explicitly-included opt-in extension — the two-act law; naming one passes THIS
  guard and refuses later at profile resolution if the extension is absent); anything else fail-closes.
- `ERR_RANGE_INVALID` (E-08) — a given `config.parse_range` REQUIRES `first == 1` AND a NON-EMPTY range (a
  start line other than 1 is not implemented; see docs/SYNTAX-AND-SEMANTICS.md). `nothing` (whole input) and
  any NON-EMPTY `1:n` range (n ≥ 1) pass; an EMPTY range (e.g. `1:0`) is REJECTED — otherwise
  `to = last(1:0) = 0` hits the parser's "non-positive ⇒ whole file" contract and a
  degenerate empty intent would silently render the WHOLE file.
- `ERR_UNKNOWN_FLAVOR` — `config.flavor_tag` must be one of the three armed flavor names: `:julia` (the
  `#` lead alphabet — the default) / `:c` (the C-family `//` line-comment flavor: C, Rust & Co.) /
  `:latex` (the `%` lead alphabet, `.tex`); anything else fail-closes. Selected, never inferred — no
  file-extension or content sniffing exists anywhere.

Pure + total (never throws): all three checks (profile, parse_range, flavor_tag) are a comparison /
membership over the typed `GoMetaConfig` fields. The non-config-time codes are intentionally absent here, with the honest partition
(docs/public-api.md §3): the condition-path refusals (E-01/E-02 + the arg-domain and parse rows) are
TYPED at their origins in the closed interpreter; E-07's typed mint is PENDING (the unqueryable-alt
shape still aborts raw); E-04 is the apply-path crash-origin and E-06 the GUARDED absorb-path depth
refusal (both un-typed, conversion deferred).
"""
function validate_config(config::GoMetaConfig)
    diags = Diagnostic[]
    # the closed default + the two OPT-IN profile names. Naming an opt-in profile
    # passes THIS guard but still refuses at `resolve_profile` unless the operator has
    # explicitly included the opt-in extension — the two-act law (see grammar_profile.jl).
    if config.profile !== :jl_share_v1 && !haskey(_PROFILE_MODES, config.profile)
        push!(diags, Diagnostic(:ERR_UNKNOWN_PROFILE, :error,
            "unknown profile $(repr(config.profile)); the v0.2 profiles are :jl_share_v1 " *
            "(the closed default), :jl_share_v1_full_parse and :jl_share_v1_full_eval " *
            "(both OPT-IN — they additionally require including " *
            "\"extensions/condition_modes_opt_in.jl\" explicitly)"))
    end
    if !isnothing(config.parse_range) && (first(config.parse_range) != 1 || isempty(config.parse_range))
        push!(diags, Diagnostic(:ERR_RANGE_INVALID, :error,
            "parse_range must be a NON-EMPTY range starting at 1 (got $(repr(config.parse_range)); require first==1 and last>=1) — a start line other than 1 is not implemented, and an EMPTY range like 1:0 is rejected because `to = last(1:0) = 0` would otherwise fail OPEN to a whole-file parse"))
    end
    # The armed flavor inventory: :julia = the `#` lead alphabet (the default,
    # byte-untouched); :c = the C-family `//` line-comment flavor (C, Rust & Co. —
    # the ONE parse loop over its FlavorProfile record); :latex = the `%` lead
    # alphabet (.tex). Closed set, no fallback (the profile law's shape). SELECTED,
    # NEVER INFERRED: the flavor is exactly the caller's explicit config value — no
    # file-extension or content sniffing exists anywhere, which is what keeps the
    # additive compatibility claim alive.
    if config.flavor_tag !== :julia && config.flavor_tag !== :c &&
       config.flavor_tag !== :latex
        push!(diags, Diagnostic(:ERR_UNKNOWN_FLAVOR, :error,
            "unknown flavor_tag $(repr(config.flavor_tag)); the armed flavors are :julia " *
            "(the `#` lead alphabet — the default), :c (the C-family `//` line-comment " *
            "flavor: C, Rust & Co.) and :latex (the `%` lead alphabet, .tex)"))
    end
    return diags
end

"""
    _config_error_result(parse_state, config, registry, config_diags) -> GoMetaResult

Build the fail-closed `PROCESS_ERROR` `GoMetaResult` for an invalid `GoMetaConfig`. `@noinline` + cold:
it is reached ONLY when `validate_config` returned a non-empty diagnostics vector, so its `init_state` +
`GoMetaResult` construction never perturb the byte-exact, low-allocation main `goMeta` path. A per-call
`ProcessState` is built (container SIZING only — no parse content is read, no `parseBLS`/absorb-walk/render
runs) so the `GoMetaResult` carries the standard state shape; the typed `config_diags` are appended; the unparsed
`parse_state` — the caller passes one built from EMPTY bytes, since validation now pre-empts touching the
input — then makes `outputs` yield the empty non-OK output ("no render attempted").
"""
@noinline function _config_error_result(parse_state::BLS.ParseState, config::GoMetaConfig,
                                        registry::AlterantRegistry, config_diags::Vector{Diagnostic})
    st = init_state(parse_state, config, registry)
    append!(st.diagnostics, config_diags)
    return GoMetaResult(st, PROCESS_ERROR, st.diagnostics, st.verdicts)
end

"""
    feed_user_mh!(st::ProcessState) -> nothing

Seed the RESERVED user slot of the meta-hierarchy (`userMHIdx` in `state.jl` — defined + scanned FIRST by
both `applyAltActionFns` walks, and fed by no other call site) with the metaLine-body profile in
`st.config.user_mh_profile`, BEFORE the absorb walk. Reuses the standard machinery VERBATIM — no parallel
intake — queued actions enqueue, the localOnly heading class diverts to absorb-seam delivery and an
explicit `head` RECORDS against the minted user-context handle (grain 0xe0; the profile's verbatim
bytes as the fingerprint): `updateMetaHierarchy(userMHIdx)` allocates + occupies the slot (its `10..12` branch; the
depth-window wipes at `<10` never touch it, so the fed slot SURVIVES the whole file walk), then `absorbMeta`
routes the profile's actions through the SAME parseAlt path authored metaLines use; the meta-hierarchy
cursor is restored so the walk starts exactly as un-fed. First-wins per non-accumulate alterant across the
user-slot-first scans ⇒ the fed profile OVERRIDES authored Visib (e.g. `"discard{ :label1 } show"`).
SCOPE: a minimal caller-supplied feed ONLY — not a general user-level configuration system; internal (NOT
exported); called from `goMeta` iff `config.user_mh_profile !== nothing`. An action name outside the
registry errors loudly inside `absorbMeta` (the same crash-loud class as an authored non-member).
Experimental — see docs/public-api.md §2.
"""
function feed_user_mh!(st::ProcessState)
    prev_idx = st.crnt_idx
    CnS.updateMetaHierarchy(userMHIdx)
    # This surface has NO document line/component behind it, so the MetaContext record is
    # NULLED — a derived-context action (the quoted-first heading) fed through here meets
    # the TYPED applicability refusal in absorbMeta, never a fabricated context (hd-6).
    # The content scratch nulls WITH it; the feed's OWN identity rides `user_context`
    # below: the explicit head records against the minted user-context handle with the
    # profile's verbatim bytes as the row's fingerprint (the user-context build).
    st.meta_context = nothing
    st.meta_content = UInt8[]
    # The stack-disciplined bracket: save prior, set, restore in the finally (never merely
    # null) — re-entry-safe before any nested-feed path exists, and the restore runs even
    # when a refusal escapes the absorb (the per-call state dies with the aborted call;
    # the finally keeps the leaves-no-residue law total anyway).
    prior_uc = st.user_context
    st.user_context = UserContext(
        key_bytes(user_context_key(st.config.namespace, 1)),
        copy(codeunits(st.config.user_mh_profile)))
    try
        absorbMeta(SubString(st.config.user_mh_profile))
    finally
        st.user_context = prior_uc
    end
    st.crnt_idx = prev_idx
    return nothing
end

#########################################################################################
#~~ `goMeta` — the pipeline driver

"""
    goMeta(bytes::Vector{UInt8};
            config::GoMetaConfig = GoMetaConfig(),
            registry::AlterantRegistry = DEFAULT_REGISTRY) -> GoMetaResult

Run the GoMeta pipeline over `bytes` and return a typed `GoMetaResult` — the package's primary public entry
(docs/public-api.md §2). PURE + DETERMINISTIC: the same `(bytes, config, registry)` always yields
the same `GoMetaResult`, with no filesystem / clock / environment read — conditions run in the
closed no-eval interpreter, so in a default-configured run a condition body cannot read or have
effects (only the explicitly opt-in `:full_eval_v1` extension mode host-evaluates condition text —
README SECURITY). The pipeline is parse -> Absorb-walk (enqueue alterant
actions) -> Apply (evaluate conditions + apply) -> lazy render, run inside one per-call dynamic scope
(`STATE`), so two concurrent calls never share state.

Arguments:
- `bytes` — the input document as raw bytes. Line ENDINGS normalize to LF (CRLF is chomped — documented, not an
  error; see `docs/CANONICAL-OUTPUT.md`); content bytes are preserved faithfully for arbitrary bytes, including invalid UTF-8; non-ASCII inside a META line parses character-safely, a non-ASCII label or action meeting the stable unknown-label/unknown-action refusal (docs/public-api.md §4).
- `config::GoMetaConfig` — the v0 input options (profile / flavor_tag / parse_range / user_mh_profile; see `GoMetaConfig`).
  An invalid profile, flavor_tag, or parse_range fail-closes into a `PROCESS_ERROR` `GoMetaResult` carrying typed
  `Diagnostic`s BEFORE any parse or render — the input bytes are never touched (`ERR_UNKNOWN_PROFILE` /
  `ERR_UNKNOWN_FLAVOR` / `ERR_RANGE_INVALID`).
- `registry::AlterantRegistry` — the alterant inventory; defaults to the deterministic `DEFAULT_REGISTRY`.

The `GoMetaResult` is `{state, status::ProcessStatus, diagnostics::Vector{Diagnostic}, verdicts::EvalStore}` and is
TOTAL over the CONFIG-TIME catalogued surface (an invalid profile or parse_range never throws uncaught); absorb/apply-plane catalogued failures can still throw at v0 (see below): `status` is
`PROCESS_OK` (no error diagnostics) or `PROCESS_ERROR` (>=1 error `Diagnostic`; non-OK => non-empty diagnostics).
Obtain output via `outputs(result)` (tree + render bytes) and `altValues_evals(result)` (the per-cell
verdict map). These are
the SOLE output surfaces. The config-time error rows are armed + typed; the condition-path refusals
(the unknown-key, cap, argument-domain and grammar rows) are typed at their own origins in the closed
condition interpreter — E-07's typed mint is PENDING (the unqueryable-alt shape still aborts raw) —
and the E-04 apply-path crash-origin and the E-06 absorb-path guarded depth refusal stay un-typed for
now (the honest partition — docs/public-api.md §3). The full honest-edges catalogue: docs/public-api.md §3.4.

# The marker syntax (short form)

`#~` / `#~N` / `#~~…` open metadata at a depth · `#~N!` (bare `#~!`) is the INERT form —
structurally identical, content ignored · the transposed `#~!N` refuses loudly · `#]`
closes the innermost metaBlock and detaches what follows · a trailing `#~ …` applies to
its own line. Full family + laws: the module docstring and `docs/SYNTAX-AND-SEMANTICS.md`.
"""
function goMeta(
    bytes::Vector{UInt8};
    config::GoMetaConfig = GoMetaConfig(),
    registry::AlterantRegistry = DEFAULT_REGISTRY,
)

    ## Config-time fail-closed validation — typed Diagnostics BEFORE any parse or render
    ## work (docs/public-api.md §2: ERR_UNKNOWN_PROFILE / ERR_UNKNOWN_FLAVOR / ERR_RANGE_INVALID,
    ## "no render attempted"); on an invalid config the input bytes are never touched — the error-path
    ## GoMetaResult carries a parse state built from EMPTY bytes (container sizing only). A VALID
    ## config ⇒ an empty vector ⇒ the pipeline below runs unchanged; an INVALID config ⇒ a fail-closed
    ## PROCESS_ERROR GoMetaResult built in the `@noinline` cold `_config_error_result` helper (its `init_state` +
    ## `GoMetaResult` construction stay OUT of this hot path). The E-04 (apply) crash-origin, the E-06
    ## (absorb) guarded refusal and the condition-path crash-origins remain untyped at v0
    ## (their typed conversion sits at the apply.jl seam).
    config_diags = validate_config(config)
    isempty(config_diags) ||
        return _config_error_result(BLS.setUpToProcessFromBytes(UInt8[]), config, registry, config_diags)

    ## Resolve the flavor ONCE, strictly AFTER the config validation above (an invalid tag
    ## must keep its typed ERR_UNKNOWN_FLAVOR PROCESS_ERROR, never a raw throw), and thread
    ## the record through the ParseState — every downstream flavor read rides
    ## `parse_state.flavor` (zero `config.flavor_tag` reads downstream of setup).
    flavor = BLS.flavor_for(config.flavor_tag)
    parse_state = BLS.setUpToProcessFromBytes(bytes; flavor = flavor)

    ## The public contract form — `goMeta(bytes; config::GoMetaConfig, registry::AlterantRegistry)
    ## -> GoMetaResult` (docs/public-api.md §2). The parse range is the typed `config.parse_range`: `nothing` ⇒
    ## the WHOLE file (mapped to `to = -1`); a `1:N` range ⇒ lines 1..N
    ## (`to = last(range)`). `parseBLS` ignores `fromLine` + breaks on `lineNum > toLine`
    ## (docs/SYNTAX-AND-SEMANTICS.md), so a non-positive `to` parses the whole file. (`config.parse_range`
    ## REQUIRES `first == 1`; `validate_config` above fail-closes an invalid profile/flavor/range BEFORE this
    ## point, so the code here always sees a valid config.)
    ## Sub-range note: for a `parse_range = 1:N` run the render is an exact PREFIX of the whole-file render
    ## for the same input — the divergence is purely the parse range, not the caps. The parse store is read
    ## off `parse_state` below; `parseBLS` is called for its parse SIDE-EFFECT (its return is discarded).
    to = isnothing(config.parse_range) ? -1 : last(config.parse_range)
    ## ONE parse call for EVERY armed flavor: the record threaded at setup carries
    ## the whole divergence — the table rows, the policies, the strictness, the lead
    ## bytes, the content-model Bool — and `parseBLS` reads it (the
    ## flavor-equivalence witness is the standing differential harness). Two further
    ## flavor READS exist, both riding the state's FlavorProfile record (walk.jl's
    ## introducer regex; the output-assembly hide marker) — keep it that way: adding
    ## a flavor means extending validate_config's inventory AND flavor_for, never a
    ## parse-site branch (the table-only law).
    BLS.parseBLS(parse_state, 1, to)

    ## The tree half is the PURE `BLS.structural_serialization(parse_state)` surfaced by
    ## `outputs` — the pipeline writes no file anywhere; `parseBLS` above is called purely
    ## for its parse side-effect.

    ## The CALLABLE DRIVER SEAM — the absorb/apply driver body lives in
    ## `run_absorb_apply!` (the next function). goMeta = validate → setup → parse →
    ## seam, and is the seam's FIRST CONSUMER.
    return run_absorb_apply!(parse_state; config = config, registry = registry)
end

"""
    run_absorb_apply!(parse_state::BLS.ParseState;
                      config::GoMetaConfig = GoMetaConfig(),
                      registry::AlterantRegistry = DEFAULT_REGISTRY) -> GoMetaResult

The CALLABLE DRIVER SEAM. ONE callable exposes, indivisibly: the absorb WALK plane
(both grains), the CONDITIONS plane (the closed interpreter via the per-call state),
the ALTERANTS/APPLY plane (registry + slot tensors + write-backs), and the EVALS
plane (capture → `altValues_evals`). An adapter never composes them individually.
Package-public, NOT exported, and deliberately carrying NO `public` declaration
(`names(GoMeta)` stays byte-stable).

THE CONTRACT (normative rows):
1. INPUT: a `ParseState` whose four channels (`collectedLines` · `addedStrings` ·
   `componentsPDict` · `endsWithNewline`) are coherent, whose `flavor` field names
   the profile the store was ACTUALLY built under, and whose components obey the
   flag laws — incl. the invariant: a component typed Meta WITHOUT a `:depthN` flag
   MUST set `:ignoreThisMeta` (flavor.jl's record mint guard owns it). Store
   construction goes through `BLS.addChildComponentTo`/`BLS.createExtensionFor` —
   never hand-assembled vectors.
2. ENFORCEMENT GRAIN: every meta-flagged slice must match
   `parse_state.flavor.re_meta_leaded` from its
   `:startMainStr` byte; the walk's typed internal error enforces this on the FIRST
   ABSORBED META UNIT AT EITHER GRAIN (Line or Segment). A store whose metadata is
   entirely absent or inert never consults the flavor record and renders
   byte-identically under any record (no hide verdict can exist without an absorbed
   meta unit); `validate_carrier_state` (below) reports a wrong-record pairing
   UNCONDITIONALLY — the standing check for exactly that class.
3. VALIDATION ASYMMETRY (a contract row, not a footnote): `goMeta` validates config
   and refuses unknown flavor tags BEFORE this seam; `run_absorb_apply!`
   deliberately does NOT re-validate — the adapter package owns its input legality,
   so a carrier profile can run the seam WITHOUT being armed in `validate_config`.
   Corollary (the config-error path): an invalid config never reaches this seam —
   goMeta's fail-closed error result carries an EMPTY parse state with the DEFAULT
   flavor record, unread on that path.
4. ONE ProcessState per call — the seam builds it FRESH (the reset-safe law), so the
   PER-CALL state is never shared across concurrent calls. The `parse_state` INPUT,
   by contrast, is caller-owned and MUTATED by the seam (the resolved Visib
   write-backs land on its component settributes at both grains): two concurrent
   calls must never share ONE parse_state — that ownership is row 1's caller
   obligation, not something the seam re-checks.
5. A meta-free store ⇒ `PROCESS_OK` with ZERO evals rows (the E-05 class — the
   Office pilot's first gate).
6. The seam parses NOTHING and renders NOTHING; `outputs(result)` stays the sole
   output surface.
"""
function run_absorb_apply!(parse_state::BLS.ParseState;
                           config::GoMetaConfig = GoMetaConfig(),
                           registry::AlterantRegistry = DEFAULT_REGISTRY)::GoMetaResult
    ## Build the FRESH per-call `ProcessState` (`init_state` is reset-safe, so neither the slot
    ## tensors nor the cursors leak between calls) + open the per-call
    ## dynamic scope. `STATE => st` carries the per-call state so the eval'd bare-name `getState`/`getAltState`
    ## reach it (`ctx() = STATE[]`). The whole absorb-walk
    ## + apply runs INSIDE this scope.
    st = init_state(parse_state, config, registry)
    with(STATE => st) do
        ## Seed the reserved user slot of the meta-hierarchy BEFORE the walk iff configured — the
        ## default-`nothing` no-feed path takes one `isnothing` branch and is otherwise untouched.
        if !isnothing(config.user_mh_profile)
            feed_user_mh!(st)
        end
        crntFileComponent::BLS.File = parse_state.componentsPDict[BLS.File][1][1]
        local metaEnvInt::Int = BLS.orderedComponentTypesNamedT[:noMetaEnvYet]
        local childComponent::BLS.Block
        for childId in BLS.eachchildid(crntFileComponent, parse_state.componentsPDict[BLS.File][1])
            if childId > 0
                childComponent = parse_state.componentsPDict[BLS.Block][1][childId]
            else
                childId *= -1
                childComponent = parse_state.componentsPDict[BLS.Block][2][childId]
            end
            if !BLS.getElement(childComponent.componentSettribute, :depricated)
                if BLS.getElement(childComponent.componentSettribute, :containsMeta) &&
                   !BLS.getElement(childComponent.componentSettribute, :ignoreThisMeta)

                    metaEnvInt = BLS.orderedComponentTypesNamedT[:noMetaEnvYet]
                    metaEnvInt = absorbWalk(parse_state, childComponent::BLS.Block, metaEnvInt)
                end
            end
            if BLS.getElement(childComponent.componentSettribute, :attachedToMeta)
                applyAltActionFns(childComponent::BLS.Block)
                # Block-grain Visib write-back, resolved through the per-call state: the alterant index
                # `st.registry.alt_index[:Visib]` + the working set `st.working` carry the
                # resolution, and the resolved Visib action maps through the per-call registry's
                # `visib_to_settribute` settribute-key table (an identity mapping at v0). BOTH grains use
                # the Pair-form `=> true` — the Block form here, and the Segment grain in walk.jl.
                # The driver IS the per-call state producer — `st` (the `init_state` result above, captured
                #   by this `with(STATE=>st) do` closure) === `ctx()` === `STATE[]` — so the write-back reads
                #   the in-scope `st` instead of repeating the `ctx()` lookup once per iteration.
                ## The Visib-action → settribute-key map is read off the PER-CALL registry
                ## (`st.registry.visib_to_settribute`), not the module-global alias, so a custom
                ## `registry` kwarg's mapping is honored at the Block grain.
                if st.registry.alt_index[:Visib] ∈ keys(st.working)
                    BLS.setElement(
                        childComponent.componentSettribute,
                        st.registry.visib_to_settribute[
                            keys(Alterants.Visib)[
                                st.working[
                                    st.registry.alt_index[:Visib]
                                ].array][1]
                        ] => true)
                end
                # Capture this Block's FINAL verdicts (Labels + Visib + Id) into st.verdicts BEFORE the
                #   next apply wipes st.working — the cell is this Block. Render-neutral: it only reads
                #   st.working + appends to st.verdicts (no parse-tree or render mutation).
                capture_verdicts!(st, childComponent)
            end
        end
    end

    ## The typed `GoMetaResult` supersedes the original `(render_bytes, tree_bytes, configDict)` NamedTuple
    ## (the historical field name `tree_bytes` predates the `blsStructure_bytes` rename; kept verbatim in this
    ## comment only). `status` is computed from the accumulated diagnostics (empty HERE — a config-time
    ## error fail-closes via goMeta's early return before this seam is reached, and the apply-path bare
    ## `error()`s still throw — their typed conversion is deferred), so this valid-config path is
    ## `PROCESS_OK`. The render/tree bytes are surfaced LAZILY by `outputs(result)` (a pure function
    ## of the final `result.state.parse`, which the in-`with` absorb-walk + apply has fully mutated).
    status = any(d -> d.severity === :error, st.diagnostics) ? PROCESS_ERROR : PROCESS_OK
    return GoMetaResult(st, status, st.diagnostics, st.verdicts)
end

"""
    validate_carrier_state(parse_state::BLS.ParseState) -> Vector{String}

The seam's OPTIONAL gate/debug-mode carrier-store checker — the carrier-store
legality argument as an executable check; the twin-parity gate's cheap
precondition. NEVER called on the hot path; package-
public, NOT exported. Returns human-readable issue strings (empty = no issue FOUND —
a clean return is NOT a legality proof). Checks EXACTLY three laws, REPORTING (never
throwing) on breach:
1. the FLAG INVARIANT — a component whose `contentType` is Meta with NO `:depth0`…
   `:depth9` flag MUST carry `:ignoreThisMeta`;
2. the INTRODUCER LAW — every `:hasMetaStr` component's main slice must match
   `parse_state.flavor.re_meta_leaded` (the walk enforces this only on ABSORBED meta
   units; this check covers every `:hasMetaStr` component REACHABLE from the File
   root, absorbed or not — the standing check for exactly a wrong-record pairing;
   an orphaned mint outside the tree is outside this traversal
   AND outside every output surface; the slot-1 File root itself is a constructor
   DUMMY — Meta-typed with no flags by construction — and is deliberately not
   checked);
3. STORE COHERENCE — every child id reachable from the File root dereferences within
   its component store's bounds (positive id = the primary store, negative = the
   `[2]` insert store — the driver's own sign convention; the insert stores are
   trap-9 dormant at v0 but the convention is checked, not assumed), and extension
   chains are PRE-VALIDATED with guarded steps — a corrupted or cyclic
   `:idExtension` link is REPORTED, never thrown on and never hung on; the shared
   iterator runs only over validated chains (the
   no-raw-childwalk gate's discipline — reconciled, not bypassed). Chain
   validation covers the levels whose children are iterated (File/Block/Line
   heads); a Segment's own chain is never followed by this walk and is outside
   its scope.
NOT a total store validator: laws the walk/apply enforce loudly themselves stay
theirs (the honest-edges partition).
"""
function validate_carrier_state(parse_state::BLS.ParseState)::Vector{String}
    issues = String[]
    pd = parse_state.componentsPDict
    ## Bounds-checked deref per the driver's sign convention; reports + returns
    ## `nothing` on breach (the checker REPORTS incoherence — it never throws on it).
    function _vcs_deref(T, id::Int, label::String)
        vecs = pd[T]
        v = id > 0 ? vecs[1] : vecs[2]
        k = abs(id)
        if !(1 <= k <= length(v)) || !isassigned(v, k)
            push!(issues, "store coherence: $label id $id does not dereference in the $(nameof(T)) store (bounds 1:$(length(v)))")
            return nothing
        end
        return v[k]
    end
    function _vcs_check!(comp, label::String)
        cs = comp.componentSettribute
        if comp.contentType == BLS.Meta &&
           !any(BLS.getElement(cs, Symbol("depth", i)) for i in 0:9) &&
           !BLS.getElement(cs, :ignoreThisMeta)
            push!(issues, "flag invariant: $label is Meta-typed with no :depthN flag and no :ignoreThisMeta")
        end
        if BLS.getElement(cs, :hasMetaStr)
            ok = try
                stringIdx = BLS.getElement(comp.cmpntNamedInt, :idxString)
                s = stringIdx > 0 ? parse_state.collectedLines[stringIdx] :
                                    parse_state.addedStrings[-stringIdx]
                lo = BLS.getElement(comp.cmpntNamedInt, :startMainStr)
                hi = BLS.getElement(comp.cmpntNamedInt, :stopMainStr)
                slice = SubString(s)[lo:hi]
                match(parse_state.flavor.re_meta_leaded, slice) !== nothing
            catch e
                ## Only the extraction's own breach classes convert to a report
                ## (corrupt indices ⇒ BoundsError; a mid-codepoint boundary ⇒
                ## StringIndexError); everything else — InterruptException,
                ## StackOverflowError, … — RETHROWS (the mis-attribution hazard:
                ## a Ctrl-C must never read as a breach).
                e isa Union{BoundsError, StringIndexError} || rethrow()
                false
            end
            ok || push!(issues, "introducer law: $label carries :hasMetaStr but its main slice does not match the flavor's leaded grammar (or the slice is unextractable)")
        end
        return nothing
    end
    ## Guarded extension-chain PRE-VALIDATION: the shared `eachchildid` iterator
    ## derefs `:idExtension` UNGUARDED (BLS.jl's iterate), so a corrupted extension
    ## link would THROW (BoundsError / UndefRefError) or HANG (a cycle) inside the
    ## checker, falsifying the reports-never-throws contract. The chain is therefore
    ## validated FIRST — reading ONLY `:idExtension` + the chain store's bounds,
    ## never raw child slots (the no-raw-childwalk gate's discipline) — with steps
    ## capped at the chain store's length + 1 (a longer chain must revisit a slot,
    ## i.e. a cycle). The shared iterator then runs ONLY over a validated chain, so
    ## its unguarded deref is unreachable-by-construction; every breach is REPORTED
    ## and that component's children are conservatively skipped.
    function _vcs_chain_ok(comp, chainVec, label::String)::Bool
        crnt = comp
        steps = 0
        while true
            steps += 1
            if steps > length(chainVec) + 1
                push!(issues, "store coherence: $label extension chain exceeds its chain store's size (a cycle or runaway chain)")
                return false
            end
            extId = BLS.getElement(crnt.cmpntNamedInt, :idExtension)
            extId == 0 && return true
            if !(1 <= extId <= length(chainVec)) || !isassigned(chainVec, extId)
                push!(issues, "store coherence: $label extension id $extId does not dereference in its chain store (bounds 1:$(length(chainVec)))")
                return false
            end
            crnt = chainVec[extId]
        end
    end
    _vcs_ids(comp, chainVec, label::String) =
        _vcs_chain_ok(comp, chainVec, label) ?
            collect(BLS.eachchildid(comp, chainVec)) : Int[]
    fileC = _vcs_deref(BLS.File, 1, "File root")
    fileC === nothing && return issues
    for blockId in _vcs_ids(fileC, pd[BLS.File][1], "File root")
        blockC = _vcs_deref(BLS.Block, blockId, "Block child")
        blockC === nothing && continue
        _vcs_check!(blockC, "Block $(blockId)")
        for lineId in _vcs_ids(blockC, pd[BLS.Block][1], "Block $(blockId)")
            lineC = _vcs_deref(BLS.Line, lineId, "Line child")
            lineC === nothing && continue
            _vcs_check!(lineC, "Line $(lineId)")
            for segId in _vcs_ids(lineC, pd[BLS.Line][1], "Line $(lineId)")
                segC = _vcs_deref(BLS.Segment, segId, "Segment child")
                segC === nothing && continue
                _vcs_check!(segC, "Segment $(segId)")
            end
        end
    end
    return issues
end

"""
    outputs(result::GoMetaResult) -> (blsStructure_bytes::Vector{UInt8}, render_bytes::Vector{UInt8})

The NATIVE, always-available output surface (docs/public-api.md §2). `blsStructure_bytes` is the verdict-free
`BLS.structural_serialization` of the final parse tree; `render_bytes` is the jl-share-v1 emit
(docs/CANONICAL-OUTPUT.md). Both are PURE functions of `result.state.parse` (the per-call parse state the
in-`with` absorb-walk + apply fully mutated), so this accessor is correct OUTSIDE the per-call
`STATE` scope. Total on any OK result (one documented qualification — the multi-Visib
render guard: docs/public-api.md §2/§3.4; the render plane's string indexing is character-safe,
docs/public-api.md §4, GUARDED); on a non-OK result the contract is
`(tree-if-parse-succeeded-else-empty, empty render)` — for the config-time path both are empty, because the
parse never ran. The NamedTuple field order is `(blsStructure_bytes, render_bytes)`.
"""
function outputs(result::GoMetaResult)
    ## The non-OK output contract. A fail-closed PROCESS_ERROR GoMetaResult — at v0 the only source is a
    ## config-time validation error, which pre-empts the parse — yields an EMPTY (tree, render):
    ## "no render attempted", and a parse that never ran ⇒ an empty tree. `render_bytes` is NOT invoked
    ## (the emit path stays untriggered). Once an apply-path error can arise AFTER a successful parse, this
    ## branch will surface the parse-so-far tree per the "tree-if-parse-succeeded" half of the contract.
    if result.status === PROCESS_ERROR
        return (blsStructure_bytes = UInt8[], render_bytes = UInt8[])
    end
    ## The hide marker rides the PARSE STATE's own FlavorProfile, never the config —
    ## under a carrier-constructed store (the `run_absorb_apply!` seam) the config
    ## need not name the flavor the store was parsed under; reading
    ## `state.parse.flavor` keeps `outputs` stamping the CORRECT flavor's marker by
    ## construction.
    rendered = let fl = result.state.parse.flavor
        render_bytes(result.state.parse;
            hide_marker = fl.hide_marker, hide_fold_prefix = fl.hide_fold_prefix)
    end
    tree     = BLS.structural_serialization(result.state.parse)
    return (blsStructure_bytes = tree, render_bytes = rendered)
end

end # module GoMeta
