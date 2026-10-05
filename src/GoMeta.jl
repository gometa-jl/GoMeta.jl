# GoMeta.jl — the top module: the include spine + the public `goMeta` entry
#
# IS: the GoMeta package top module. It holds the ordered include spine — config.jl, result.jl,
#     bls/BLS.jl, state.jl, alterants/registry.jl, annotations.jl,
#     absorb/absorb_meta.jl, absorb/walk.jl, alterants/apply.jl — and declares the
#     exported semver surface: `goMeta`, `readAltValuesEvals`, `GoMetaConfig`, `GoMetaDelivery`
#     (docs/public-api.md §1.1; asserted by tests/unit/public_surface_tests.jl), plus the
#     declared `public` tier of qualified names (docs/public-api.md §1.2 — e.g. `GoMeta.serialize_evals`,
#     `GoMeta.PROCESS_OK`).
# DOES: `goMeta(bytes; config::GoMetaConfig = GoMetaConfig(), registry::AlterantRegistry =
#     DEFAULT_REGISTRY) -> GoMetaDelivery` runs the pipeline parse -> Absorb-walk (enqueue alterant
#     actions) -> Apply (evaluate conditions + apply); the evaluated values are the product. `validate_config` fail-closes
#     an invalid config into a `PROCESS_ERROR` `GoMetaDelivery` carrying typed `Diagnostic`s BEFORE any
#     parse work (the input bytes are never touched): `ERR_UNKNOWN_PROFILE` (E-03 — the
#     three profile names are `:jl_share_v1` + the two opt-in names, docs/public-api.md §3.1),
#     `ERR_UNKNOWN_FLAVOR` (the closed three-flavor set `:julia`/`:c`/`:latex`, selected never
#     inferred) and `ERR_RANGE_INVALID` (E-08 — a given `parse_range` requires `first == 1` and a non-empty
#     range). The absorb-walk + apply run inside one per-call dynamic scope, `with(STATE =>
#     init_state(parse_state, config, registry))`, so two
#     concurrent calls never share state; the driver walk enters each file-level Block, absorbs its
#     metaLines, applies the queued alterant actions and captures per-cell evals rows (the Block's Visib
#     among them; nothing is written into the Components since stage 3's commit 4, R-V04B-42 (1)) for
#     `readAltValuesEvals(result.altValues_evals)`. The tool's `outputs` pair — the BLS Component tree's print and the render — is the
#     development tool's — `devtools/basic_renderer.jl`, loaded through `devtools/load_basic_renderer.jl`,
#     never by the Engine (R-V04B-24, 2026-09-12). The optional
#     `config.user_mh_profile` seeds the reserved user slot of the meta-hierarchy before the walk
#     (`feed_user_mh!`; a fed explicit `head` records one row against the minted user-context
#     handle — docs/public-api.md §2; experimental).
# REASONING: the public contract (docs/public-api.md §2) requires `goMeta` to be pure and
#     deterministic FOR THE ENGINE'S OWN OPERATIONS (no filesystem / clock / environment read; a v0
#     condition body runs in the closed no-eval interpreter — only under the opt-in
#     `:full_eval_v1` extension mode can it read or have effects — README SECURITY),
#     and TOTAL over the config-time
#     catalogued surface — non-OK implies non-empty diagnostics. Honest edges: the
#     E-06 absorb-path guarded refusal is documented but not yet typed (conversion deferred; the E-04
#     apply-path crash origin LEFT with the Visib write-back at stage 3's commit 4, R-V04B-42); the condition-path refusals are MINTED typed since the
#     closed-interpreter flip, though the statement still aborts at the absorb seam, with E-07's mint
#     PENDING (the unqueryable-alt shape still aborts raw). The full honest-edges catalogue:
#     docs/public-api.md §3.
# PURPOSE: the single auditable entry point — bytes in, a typed `GoMetaDelivery` out, with the package's
#     canonical observable output = `altValues_evals` (+ `serialize_evals`); the Engine's
#     delivered surface = the run and the evaluated values (R-V04B-24); the (tree, render) pair is the
#     development tool's.
module GoMeta

"""
    GoMeta

Interpretable `#~` metadata for source files: `goMeta(bytes)` parses the input into the
BLS tree (File → Block → Line → Segment), absorbs the metadata, applies the registered
Alterants and records the evaluated values as data (`altValues_evals`); it **evaluates, never
executes** — and never renders (the share view is a development tool's, `devtools/basic_renderer.jl`).

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
include("result.jl")    # ProcessStatus / Diagnostic / EvalStore (the GoMetaDelivery support types)
include("bls/BLS.jl")
include("occurrence.jl")            # v0.2 CH-1 (step 1): the normalized occurrence handle — depends
                                    # on BLS ONLY; everything downstream may
                                    # reference OccurrenceKey/occurrence_key/key_bytes
import .BLS
include("state.jl")     # per-call ProcessState + the typed GoMetaDelivery surface + the AlterantRegistry type + the STATE/ctx() seam
include("alterants/registry.jl")    # the Alterants + CnS layers, combined (Alterants BEFORE CnS)
using .CnS: getState, getAltState
include("condition.jl")             # the closed condition interpreter (bounded intake + algebra +
                                    #   printer + evaluate) — after registry.jl (the query dispatch
                                    #   surface) + state.jl; inert until the engine flips to it.
include("annotations.jl")           # the evals surface — evals capture +
                                    #   readAltValuesEvals(result.altValues_evals). AFTER registry.jl (Alterants.Visib/Id) + state.jl
                                    #   (ProcessState/GoMetaDelivery/EvalStore); BEFORE walk.jl + the driver below
                                    #   (which call captureEvals!). Holds no eval, no render-write.
include("absorb/absorb_meta.jl")
using .AbsorbMeta
include("absorb/walk.jl")           # goMetaAddOns absorb-half — absorbMeta (above) must precede it
include("alterants/apply.jl")       # goMetaAddOns apply-half — late-bound from walk, so OK after walk
include("answer.jl")                # stage 2's commit 4 of the v0.4 build (R-V04B-35 (c)): THE ONE ANSWER FUNCTION `evaluatedAltValue` + its record
                                    #   `EvaluatedAltValue` — derived at the call from the delivered rows and `decided_by`; after apply.jl (nothing below depends on it)
include("scan.jl")                  # stage 2's commit 5 (his §6 9.A; the plan :57): THE SCAN BY ALTERANT `scanAlterant` + THE ACCESS BY COMPONENT
                                    #   `evaluatedAltValues` — thin reads over `evaluatedAltValue`; after answer.jl
include("childdiff.jl")             # stage 2's commit 6 (R-V04B-35 (e); the plan :58): THE CHILD-DIFFERS SIGNAL `childDiffers` — computed from
                                    #   `evaluatedAltValue` at the call; its stored form the benchmark phase's; after scan.jl


#########################################################################################
########### Public API (the declared semver surface — re-exported) #####################
# The four names below ARE GoMeta's declared public API (documented in docs/public-api.md §1.1).
# `export` re-exports them — all are defined directly in this
# module via the include spine above — so `using GoMeta` brings exactly these into scope and
# `names(GoMeta)` IS the machine-checkable semver surface (asserted by tests/unit/public_surface_tests.jl).
# EVERYTHING else stays PACKAGE-PUBLIC (reached qualified, e.g. GoMeta.PROCESS_OK / .Diagnostic):
# the supporting types (ProcessStatus/Diagnostic/EvalStore/AlterantRegistry),
# DEFAULT_REGISTRY, serialize_evals, EvalRecord, and the PROCESS_OK/PROCESS_ERROR values
# — the names on the `public` lines below (eleven at 0.3.x; thirty-six since v0.4 T2: + the
#   registration lifecycle incl. `next_plugin_index` + the record vocabulary; thirty-seven since
#   the v0.4 `Alterant` rename — `Alterant` is the record's canonical name and `PlugIn` its
#   PUBLIC 0.4.x deprecation alias (R-V04B-5); FORTY since v0.4 T4: + the G-VOC query triple
#   `vocabulary`/`vocabulary_member`/`vocabulary_queryable`; THIRTY-NINE since R-V04B-24 (2026-09-12):
#   `outputs` REMOVED with the basic renderer — a development tool; the register row in docs/public-api.md §6;
#   FORTY since stage 2's commit 0 of the v0.4 build (R-V04B-58): + the parser module `BLS`, its door inside it;
#   FORTY-FIVE after stage 2's commits 4–6 (`evaluatedAltValue`, `EvaluatedAltValue`, `scanAlterant`, `evaluatedAltValues`, `childDiffers`);
#   FORTY-FOUR since stage 2's commit 9b (R-V04B-43 (1)): `content_fingerprint` REMOVED — a piece's text is read from the
#   BLS Component tree through the door (`BLS.content`), never from the Engine; the register row in docs/public-api.md §6;
#   docs/public-api.md §1.2 is the mirror).
# Qualified import (`import GoMeta as GM`) is UNAFFECTED by these exports and remains canonical for namespace
# hygiene + multi-implementation use; exporting serves the single-implementation `using` convenience only.
export goMeta, readAltValuesEvals, GoMetaConfig, GoMetaDelivery
public serialize_evals, EvalRecord, EvalStore, ProcessStatus, PROCESS_OK, PROCESS_ERROR, Diagnostic, AlterantRegistry, DEFAULT_REGISTRY,
       RegistryBuilder, register!, next_plugin_index, validate, publish, RegistrationRefused,   # v0.4 T2: the registration lifecycle (docs/public-api.md §1.2)
       Alterant, PlugIn, ActionSpec, ActionOverload, DomainRef, CaptureDecl, DefaultSlot, NoDefault, Declared,   # v0.4 T2 (cure batch 1) + the rename: the record
       EffectRow, RenderDecl, VocabularySlot, InlineVocabulary, VocabularyRef, MutEx, ConditionAtom,   #   VOCABULARY a third-party author
       SugarRow, Provenance, SignatureRecord, PermissionManifest,                                     #   constructs (docs/public-api.md §1.2)
       vocabulary, vocabulary_member, vocabulary_queryable   # v0.4 T4: the G-VOC query surface (the ONE vocabulary read the three planes share; docs/public-api.md §3.4)
public BLS   # stage 2's commit 0 of the v0.4 build (R-V04B-33/45/58): the parser module public by name — its door of travel / access functions declared INSIDE it (src/bls/BLS.jl; docs/public-api.md §1.2 + §6)
public evaluatedAltValue, EvaluatedAltValue   # stage 2's commit 4 of the v0.4 build (R-V04B-35 (c)): THE ONE ANSWER FUNCTION and its record — package-public, NOT exported (docs/public-api.md §1.2; the register row §6); the name his word of 2026-10-03 (OWNER-WORDS §305; R-V04B-95); the tier carried past the branch (the review's C23)
public scanAlterant, evaluatedAltValues   # stage 2's commit 5 of the v0.4 build (his §6 9.A; the plan :57): THE SCAN BY ALTERANT and THE ACCESS BY COMPONENT — package-public, NOT exported (docs/public-api.md §1.2; the register row §6); the names his word of 2026-10-03 (§305; R-V04B-95); the form — functions of their own — stands, its alternative (methods of the reader) banked
public childDiffers   # stage 2's commit 6 of the v0.4 build (R-V04B-35 (e); his §37 item 4.2): THE CHILD-DIFFERS SIGNAL computed from the answer — the per-child primitive; his (ii) Boolean beside a PARENT's entry is `any` of it over the children (the seat of commit 6, F-3) — package-public, NOT exported (docs/public-api.md §1.2; the register row §6); the name kept by his word of 2026-10-03 (R-V04B-95); the Block-against-File reading carried past the branch (the review's C23)

#########################################################################################
#~~ Config-time validation

"""
    validate_config(config::GoMetaConfig) -> Vector{Diagnostic}

IS: the config-time validator of the public `GoMetaConfig` — the fail-closed gate every `goMeta` run passes BEFORE any parse.

DOES: Config-time validation of the public `GoMetaConfig`, returning the (possibly empty) typed
diagnostics that `goMeta` fail-closes on. A non-empty result means `goMeta` returns a `PROCESS_ERROR`
`GoMetaDelivery` BEFORE any parse work is attempted (the input bytes are never touched; the
docs/public-api.md §2 fail-closed contract — downstream, the development tool's `outputs` yields its empty non-OK pair).

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
shape still aborts raw); E-06 is the GUARDED absorb-path depth refusal (un-typed, conversion deferred; the
E-04 apply-path crash origin left with the Visib write-back at stage 3's commit 4).

REASONING: an invalid configuration must never reach the parser or the apply — the three config-time rows are decided by comparison and membership over typed fields, so the check is pure and total and the input bytes are never touched.

PURPOSE: the one place a caller's configuration is refused with typed diagnostics, the empty vector being the pass.
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
            "\"optin/condition_modes_opt_in.jl\" explicitly)"))
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
    # file-extension or content sniffing exists anywhere — so a flavor added later can
    # never change how an existing input is read.
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
    _configErrorDelivery(parse_state, config, registry, config_diags) -> GoMetaDelivery

IS: the cold constructor of the fail-closed `PROCESS_ERROR` `GoMetaDelivery` — reached ONLY on an ENTRY
refusal — before any absorb or apply work of the refused call, and at `goMeta` before its parse: a
non-empty `validate_config` vector or the registry door's diagnostics (the callable seam that ran the door too, and its
state ledger's refusals of an injected parse state, left at stage 5's E2 of the v0.4 build).

DOES: builds a per-call `ProcessState` by `init_state` (container SIZING only — no parse content is read, no
`parseBLS` / absorb-walk runs), appends the typed `config_diags`, and hands back the delivery's four parts taken
from that state: the EMPTY store `st.evals` as `altValues_evals`; the unparsed `parse_state` — the caller passes
one built from EMPTY bytes, since the validation pre-empts touching the input — as `blsComponentTree`; `PROCESS_ERROR`;
the diagnostics. The working state itself is not delivered (R-V04B-28).

REASONING: `@noinline` + cold, so its `init_state` and the construction never perturb the byte-exact,
low-allocation main `goMeta` path; the empty-bytes tree keeps the delivery total (the development tool's `outputs`,
`devtools/basic_renderer.jl`, yields its empty non-OK pair on it).

PURPOSE: ONE fail-closed outcome for every entry refusal — typed diagnostics, never a throw.
"""
@noinline function _configErrorDelivery(parse_state::BLS.ParseState, config::GoMetaConfig,
                                        registry::AlterantRegistry, config_diags::Vector{Diagnostic})
    st = init_state(parse_state, config, registry)
    append!(st.diagnostics, config_diags)
    return GoMetaDelivery(st.parse, st.evals, PROCESS_ERROR, st.diagnostics)   # the field order R-V04B-89
end

"""
    feed_user_mh!(st::ProcessState) -> nothing

Seed the RESERVED user slot of the meta-hierarchy (`userMHIdx` in `state.jl` — defined + scanned FIRST by
both `applyAltActionFns` walks, and fed by no other call site) with the metaLine-body profile in
`st.config.user_mh_profile`, BEFORE the absorb walk. Reuses the standard machinery VERBATIM — no parallel
intake — queued actions enqueue, the localOnly heading class diverts to absorb-seam delivery and an
explicit `head` RECORDS against the minted user-context handle (grain 0xe0; no copy of the profile's bytes on the
row since commit 9b, R-V04B-43 (1)): `updateMetaHierarchy(userMHIdx)` allocates + occupies the slot (its `10..12` branch; the
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
    # The feed's OWN identity rides `user_context` below: the explicit head records against the
    # minted user-context handle (the user-context build; no copy of the profile's bytes rides the row
    # since commit 9b, R-V04B-43 (1)).
    st.meta_context = nothing
    # The stack-disciplined bracket: save prior, set, restore in the finally (never merely
    # null) — re-entry-safe before any nested-feed path exists, and the restore runs even
    # when a refusal escapes the absorb (the per-call state dies with the aborted call;
    # the finally keeps the leaves-no-residue law total anyway).
    prior_uc = st.user_context
    st.user_context = UserContext(key_bytes(user_context_key(st.config.namespace, 1)))
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
            registry::AlterantRegistry = DEFAULT_REGISTRY) -> GoMetaDelivery

IS: the pipeline driver — the package's primary public entry, `goMeta(bytes; config, registry) -> GoMetaDelivery`
(docs/public-api.md §2): the run whose evals rows `readAltValuesEvals` reads.

DOES: Run the GoMeta pipeline over `bytes` and return a typed `GoMetaDelivery` — the package's primary public entry
(docs/public-api.md §2). PURE + DETERMINISTIC for a DEFAULT-CONFIGURED run under `DEFAULT_REGISTRY`
(the closed interpreter; the opt-in full-eval mode and a custom registry's own callables are outside
the guarantee — the trust model): the same `(bytes, config, registry)` always yields
the same `GoMetaDelivery`, with no filesystem / clock / environment read — conditions run in the
closed no-eval interpreter, so in a default-configured run a condition body cannot read or have
effects (only the explicitly opt-in `:full_eval_v1` extension mode host-evaluates condition text —
README SECURITY). The pipeline is parse -> Absorb-walk (enqueue alterant
actions) -> Apply (evaluate conditions + apply), run inside one per-call dynamic scope
(`STATE`), so two concurrent calls never share state.

Arguments:
- `bytes` — the input document as raw bytes. Line ENDINGS normalize to LF (CRLF is chomped — documented, not an
  error; see `docs/CANONICAL-OUTPUT.md`); content bytes are preserved faithfully for arbitrary bytes, including invalid UTF-8; non-ASCII inside a META line parses character-safely, a non-ASCII label OUTSIDE the governing vocabulary or a non-ASCII action meeting the stable unknown-label/unknown-action refusal (docs/public-api.md §4).
- `config::GoMetaConfig` — the v0 input options (profile / flavor_tag / parse_range / user_mh_profile; see `GoMetaConfig`).
  An invalid profile, flavor_tag, or parse_range fail-closes into a `PROCESS_ERROR` `GoMetaDelivery` carrying typed
  `Diagnostic`s BEFORE any parse — the input bytes are never touched (`ERR_UNKNOWN_PROFILE` /
  `ERR_UNKNOWN_FLAVOR` / `ERR_RANGE_INVALID`).
- `registry::AlterantRegistry` — the alterant inventory; defaults to the deterministic `DEFAULT_REGISTRY`.

The `GoMetaDelivery` is `{altValues_evals::EvalStore, blsComponentTree::BLS.ParseState, status::ProcessStatus, diagnostics::Vector{Diagnostic}}` — the four public parts, read by name (R-V04B-28/29/30) — and is
TOTAL over the CONFIG-TIME catalogued surface (an invalid profile or parse_range never throws uncaught); absorb/apply-plane catalogued failures can still throw at v0 (see below): `status` is
`PROCESS_OK` (no error diagnostics) or `PROCESS_ERROR` (>=1 error `Diagnostic`; non-OK => non-empty diagnostics).
Obtain the Engine's output via `readAltValuesEvals(result.altValues_evals)` (the evals map, keyed by (handle, attr); its byte form
`serialize_evals`; a piece's text through `BLS.content`) — with the run itself, the Engine's delivered surface
after the move (R-V04B-24: "the run and the evaluated values"). The (tree, render) pair is the development
tool's: `Main.BasicRenderer.outputs`, applied to the result after `include("devtools/load_basic_renderer.jl")`
at the caller's top level. The config-time error rows are armed + typed; the condition-path refusals
(the unknown-key, cap, argument-domain and grammar rows) are typed at their own origins in the closed
condition interpreter, though the statement still ABORTS at the absorb seam (the refusal rethrown raw;
its routing into the delivered diagnostics a later, separately-gated motion) — E-07's typed mint is
PENDING (the unqueryable-alt shape still aborts raw) — and the E-06 absorb-path guarded depth refusal stays
un-typed for now (the honest partition — docs/public-api.md §3; the E-04 apply-path crash origin left with the
Visib write-back at stage 3's commit 4).
The full honest-edges catalogue: docs/public-api.md §3.4.

# The marker syntax (short form)

`#~` / `#~N` / `#~~…` open metadata at a depth · `#~N!` (bare `#~!`) is the INERT form —
structurally identical, content ignored · the transposed `#~!N` refuses loudly · `#]`
closes the innermost metaBlock and detaches what follows · a trailing `#~ …` applies to
its own line. Full family + laws: the module docstring and `docs/SYNTAX-AND-SEMANTICS.md`.

REASONING: the Engine's own operations are pure and deterministic — no filesystem, clock or environment read; the
closed condition interpreter — so that the same `(bytes, config, registry)` always yields the same result (the
byte law's ground); the trust model bounds the guarantee: the opt-in full-eval mode and a custom registry's own
callables are outside it.

PURPOSE: the one route from a document's bytes to the delivered object — the run and the evaluated values
(R-V04B-24) — for an Extension, a test, a development tool or a DB-interface.
"""
function goMeta(
    bytes::Vector{UInt8};
    config::GoMetaConfig = GoMetaConfig(),
    registry::AlterantRegistry = DEFAULT_REGISTRY,
)

    ## Config-time fail-closed validation — typed Diagnostics BEFORE any parse
    ## work (docs/public-api.md §2: ERR_UNKNOWN_PROFILE / ERR_UNKNOWN_FLAVOR / ERR_RANGE_INVALID;
    ## the development tool's `outputs` then yields its empty non-OK pair); on an invalid config the input bytes are never touched — the error-path
    ## GoMetaDelivery carries a parse state built from EMPTY bytes (container sizing only). A VALID
    ## config ⇒ an empty vector ⇒ the pipeline below runs unchanged; an INVALID config ⇒ a fail-closed
    ## PROCESS_ERROR GoMetaDelivery built in the `@noinline` cold `_configErrorDelivery` helper (its `init_state` +
    ## `GoMetaDelivery` construction stay OUT of this hot path). The E-06 (absorb) guarded refusal remains
    ## untyped at v0 (the E-04 apply crash origin left with the write-back, stage 3's commit 4); the condition-path refusals are minted typed
    ## in the closed interpreter (E-07's mint pending) but the statement still aborts at the absorb seam
    ## (`absorb_meta.jl`: the refusal rethrown raw — its routing into the delivered diagnostics a later,
    ## separately-gated motion, docs/public-api.md §3).
    config_diags = validate_config(config)
    ## v0.4 T2 — THE STRICT DOOR (R-V04-34): the registry must be PUBLISHED (validated + sealed);
    ## an unpublished value refuses typed (`REG_UNPUBLISHED`, naming RegistryBuilder → validate →
    ## publish) and a published value mutated after publication refuses `POST_SEAL_MUTATION`
    ## (the recomputed seal ≠ the stored one — the real freeze gate). FULL COLLECTION before the
    ## ONE terminal outcome: config-time AND registry-time diagnostics ride ONE fail-closed
    ## PROCESS_ERROR result (config first, then registry); the input bytes are never touched.
    append!(config_diags, _registry_door_check(registry))
    isempty(config_diags) ||
        return _configErrorDelivery(BLS.setUpToProcessFromBytes(UInt8[]), config, registry, config_diags)

    ## Resolve the flavor ONCE, strictly AFTER the config validation above (an invalid tag
    ## must keep its typed ERR_UNKNOWN_FLAVOR PROCESS_ERROR, never a raw throw), and thread
    ## the record through the ParseState — every downstream flavor read rides
    ## `parse_state.flavor` (zero `config.flavor_tag` reads downstream of setup).
    flavor = BLS.flavor_for(config.flavor_tag)
    parse_state = BLS.setUpToProcessFromBytes(bytes; flavor = flavor)

    ## The public contract form — `goMeta(bytes; config::GoMetaConfig, registry::AlterantRegistry)
    ## -> GoMetaDelivery` (docs/public-api.md §2). The parse range is the typed `config.parse_range`: `nothing` ⇒
    ## the WHOLE file (mapped to `to = -1`); a `1:N` range ⇒ lines 1..N
    ## (`to = last(range)`). `parseBLS` ignores `fromLine` + breaks on `lineNum > toLine`
    ## (docs/SYNTAX-AND-SEMANTICS.md), so a non-positive `to` parses the whole file. (`config.parse_range`
    ## REQUIRES `first == 1`; `validate_config` above fail-closes an invalid profile/flavor/range BEFORE this
    ## point, so the code here always sees a valid config.)
    ## Sub-range note: for a `parse_range = 1:N` run the development tool's render is an exact PREFIX of its whole-file render
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

    ## The tree print is the development tool's (`structural_serialization` in
    ## `devtools/basic_renderer.jl`, a pure function of `parse_state` after the run) — the pipeline
    ## writes no file anywhere; `parseBLS` above is called purely for its parse side-effect.

    ## The absorb/apply driver — ONE function again since stage 5's E2 of the v0.4 build (census rows 21, 42, 44 and 23,
    ## his §317 mark, R-V04B-105; his verbatim of R-V04-31 on the callable driver seam of v0.3.2/T3: a seam serving the
    ## .fodt adapter alone "will eventually have to be removed from the GoMeta engine" — his legacy was one function,
    ## GoMetaRetro's src/GoMeta.jl :26–:113: the parse, then the File loop). Build the FRESH per-call `ProcessState`
    ## (`init_state` is reset-safe, so neither the slot tensors nor the cursors leak between calls) + open the per-call
    ## dynamic scope: `STATE => st` carries the per-call state so the eval'd bare-name `getState`/`getAltState` reach it
    ## (`ctx() = STATE[]`). The whole absorb-walk + apply runs INSIDE this scope; the parse state is READ, never written
    ## (stage 3's commit 4, R-V04B-42 (1)); one parse state per call by construction — the seam ledger that enforced it
    ## for injected states left with the seam.
    st = init_state(parse_state, config, registry)
    with(STATE => st) do
        ## Seed the reserved user slot of the meta-hierarchy BEFORE the walk iff configured — the
        ## default-`nothing` no-feed path takes one `isnothing` branch and is otherwise untouched.
        if !isnothing(config.user_mh_profile)
            feed_user_mh!(st)
        end
        ## The File loop (the legacy's; its `_walk_and_apply!` factoring of stage 2's commit 3a left at stage 5's E2 —
        ## the fallBack test it served carries its own copy of the loop): per child Block, the absorb walk of its
        ## metaLines (when it carries meta and the Block is not deprecated — the `!depricated` guard wraps the absorb
        ## walk alone), the apply at the Block grain (when attached to meta) and the capture of its final evals rows
        ## before the next apply wipes `st.working`.
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
                ## The Block-grain Visib write-back LEFT here (stage 3's commit 4 of the v0.4 build, R-V04B-42 (1)): the Engine writes NOTHING into the caller's BLS
                ## Components — the Block's Visib is CAPTURED (below) and read through the one answer function (R-V04B-16 (1)).
                # Capture this Block's FINAL evals rows (Labels + Visib + Id) into st.evals BEFORE the
                #   next apply wipes st.working — the cell is this Block. Render-neutral: it reads
                #   st.working, puts or supersedes rows in st.evals and may append warning diagnostics
                #   (no parse-tree or render mutation).
                captureEvals!(st, childComponent)
            end
        end
    end

    ## The typed `GoMetaDelivery` supersedes the original three-field NamedTuple (render, tree, configDict)
    ## (the historical field name `tree_bytes` predates the `blsStructure_bytes` rename; kept verbatim in this
    ## comment only). `status` is computed from the accumulated diagnostics: `PROCESS_ERROR` iff an `:error` row
    ## exists, else `PROCESS_OK`. On this path no `:error` row is ever pushed (a config-time or door
    ## refusal fail-closes through `_configErrorDelivery` before the parse; the absorb/apply-path refusals still
    ## THROW — the condition refusal rethrown at the absorb seam, the E-06 row raw), so a run that returns
    ## here is `PROCESS_OK` — but the vector need NOT be empty: the walk's and the capture's `:warning` rows
    ## (`WARN_VERDICT_COLLISION`, the capture-floor codes) ride the delivery
    ## (the type's docstring). The evaluated values are read by `readAltValuesEvals(result.altValues_evals)`; the development tool's
    ## (tree, render) pair (`Main.BasicRenderer.outputs`) is a pure function of the delivery — the tree READ, never written
    ## (stage 3's commit 4), every Visib verdict the Engine's answer (stage 3's commit 1).
    status = any(d -> d.severity === :error, st.diagnostics) ? PROCESS_ERROR : PROCESS_OK
    return GoMetaDelivery(st.parse, st.evals, status, st.diagnostics)   # the field order R-V04B-89
end

end # module GoMeta
