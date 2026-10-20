# GoMeta.jl — the top module: the include spine + the public `goMeta` entry
#
# IS: the GoMeta package top module. It holds the ordered include spine — config.jl, result.jl,
#     bls/BLS.jl, occurrence.jl, state.jl, alterants/registry.jl, annotations.jl, absorb/absorb_meta.jl,
#     absorb/walk.jl, alterants/apply.jl, answer.jl, scan.jl, childdiff.jl — and declares the
#     exported semver surface: `goMeta`, `readAltValuesEvals`, `GoMetaConfig`, `GoMetaDelivery`
#     (docs/public-api.md §1.1; asserted by tests/unit/public_surface_tests.jl), plus the
#     declared `public` tier of qualified names (docs/public-api.md §1.2 — e.g. `GoMeta.serialize_evals`,
#     `GoMeta.PROCESS_OK`).
# DOES: `goMeta(bytes; config::GoMetaConfig = GoMetaConfig(), registry::AlterantRegistry =
#     DEFAULT_REGISTRY) -> GoMetaDelivery` runs the pipeline parse -> Absorb-walk (enqueue alterant
#     actions) -> Apply (evaluate conditions + apply); the evaluated values are the product. The registry door fail-closes
#     an unpublished or post-publication-mutated registry into a `PROCESS_ERROR` `GoMetaDelivery` carrying a coded
#     `Diagnostic` BEFORE any parse work (the input bytes are never touched) — the ONE entry refusal since stage 5's E13
#     (the config-time `ERR_UNKNOWN_PROFILE` row, E-03, left at E13 with the grammar profile — census row 30's arm). The coded
#     flavor and range refusals left at stage 5's E8 of the v0.4 build (census row 30): an unknown `flavor_tag`
#     throws raw at `BLS.flavor_for` (the closed inventory, no fallback — a stable message, docs/public-api.md §3.4)
#     and a given `parse_range` is taken plain (`first` never read; `to = last`; a non-positive `to` parses the
#     whole file, the parser's contract). The absorb-walk + apply run inside one per-call dynamic scope, `with(STATE =>
#     init_state(parse_state, config, registry))`, so two
#     concurrent calls never share state; the driver walk enters each file-level Block, absorbs its
#     metaLines, applies the queued alterant actions and captures per-cell evals rows (the Block's Visib
#     among them; nothing is written into the Components since stage 3's commit 4, R-V04B-42 (1)) for
#     `readAltValuesEvals(result.altValues_evals)`. The tool's `outputs` pair — the BLS Component tree's print and the render — is the
#     development tool's — `devtools/basic_renderer.jl`, loaded through `devtools/load_basic_renderer.jl`,
#     never by the Engine (R-V04B-24, 2026-09-12). The optional
#     `config.user_mh_profile` seeds the reserved user slot of the meta-hierarchy before the walk
#     (`feed_user_mh!`; a heading in the profile meets the one refusal at the read — his §D242, stage 1 of the Alterants
#     build; docs/public-api.md §2; experimental).
# REASONING: the public contract (docs/public-api.md §2) requires `goMeta` to be pure and
#     deterministic FOR THE ENGINE'S OWN OPERATIONS (no filesystem / clock / environment read; a `{…}` condition is
#     Julia text evaluated by Julia since stage 5's E13 — his design, §120 and §D174 — so what a condition body reads or
#     does is the author's act, as a custom registry's callables are: README SECURITY), and TOTAL over the entry
#     surface — non-OK implies non-empty diagnostics. Honest edges: the E-06 absorb-path guarded refusal is documented
#     but not yet coded (its conversion deferred; the E-04 apply-path crash origin LEFT with the Visib write-back at stage 3's
#     commit 4, R-V04B-42); the condition path keeps THREE refusals of GoMeta's — the unknown condition key (the vocabulary's),
#     the no-expression guard of an empty block or a bare literal and, since s5c31 (his §366), the one scanner's unterminated `(`
#     inside a body — and a body Julia cannot parse is Julia's own
#     `Meta.ParseError` (the condition codes left with the interpreter at E13).
#     The full honest-edges catalogue: docs/public-api.md §3.
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
using StaticArrays  # stack-allocated fixed-size arrays; the slot tensors and the work vectors are plain Vector/Array (registry.jl, apply.jl)

#########################################################################################
############ Includes ###################################################################

include("config.jl")    # GoMetaConfig (the public input options)
include("result.jl")    # ProcessStatus / Diagnostic / EvalStore (the GoMetaDelivery support types)
include("bls/BLS.jl")
include("occurrence.jl")            # v0.2 CH-1 (step 1): the normalized occurrence handle — depends
                                    # on BLS ONLY; everything downstream may
                                    # reference OccurrenceKey/occurrence_key/key_bytes
import .BLS
include("state.jl")     # per-call ProcessState + the typed GoMetaDelivery surface + the AlterantRegistry type + the STATE/ctx() seam
include("alterants/registry.jl")    # the Alterants + CnS layers, combined (Alterants BEFORE CnS)
using .CnS: getState, getAltState   # the two names a re-written condition calls by BARE name under `Core.eval(GoMeta, ex)` —
                                    #   his legacy's GoMeta.jl :18 (the closed interpreter's include left at stage 5's E13)
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
# The four names below ARE GoMeta's declared public API (docs/public-api.md §1.1); `export` re-exports them — all defined directly in
# this module via the include spine above — so `using GoMeta` brings exactly these into scope and `names(GoMeta)` IS the
# machine-checkable semver surface (asserted by tests/unit/public_surface_tests.jl). EVERYTHING else stays PACKAGE-PUBLIC (reached
# qualified, e.g. GoMeta.PROCESS_OK / .Diagnostic): the names on the `public` lines below — TWENTY-SEVEN since stage 5's E14 of the
# v0.4 build (census row 54: the tier at its ruled names; the `PlugIn` alias left, R-V04B-62); docs/public-api.md §1.2 is the mirror
# and its §6 register carries every change of the set as a row.
# Qualified import (`import GoMeta as GM`) is UNAFFECTED by these exports and remains canonical for namespace
# hygiene + multi-implementation use; exporting serves the single-implementation `using` convenience only.
export goMeta, readAltValuesEvals, GoMetaConfig, GoMetaDelivery
public serialize_evals, EvalRecord, EvalStore, ProcessStatus, PROCESS_OK, PROCESS_ERROR, Diagnostic, AlterantRegistry, DEFAULT_REGISTRY,
       RegistryBuilder, register!, next_plugin_index, validate, publish, RegistrationRefused,   # the registration lifecycle (docs/public-api.md §1.2)
       Alterant, ActionSpec, CaptureDecl, DefaultSlot, NoDefault, Declared   # the record vocabulary a third-party author constructs (docs/public-api.md §1.2)
public BLS   # stage 2's commit 0 of the v0.4 build (R-V04B-33/45/58): the parser module public by name — its door of travel / access functions declared INSIDE it (src/bls/BLS.jl; docs/public-api.md §1.2 + §6)
public evaluatedAltValue, EvaluatedAltValue   # stage 2's commit 4 of the v0.4 build (R-V04B-35 (c)): THE ONE ANSWER FUNCTION and its record — package-public, NOT exported (docs/public-api.md §1.2; the register row §6); the name his word of 2026-10-03 (OWNER-WORDS §305; R-V04B-95); the tier carried past the branch (the review's C23)
public scanAlterant, evaluatedAltValues   # stage 2's commit 5 of the v0.4 build (his §6 9.A; the plan :57): THE SCAN BY ALTERANT and THE ACCESS BY COMPONENT — package-public, NOT exported (docs/public-api.md §1.2; the register row §6); the names his word of 2026-10-03 (§305; R-V04B-95); the form — functions of their own — stands, its alternative (methods of the reader) banked
public childDiffers   # stage 2's commit 6 of the v0.4 build (R-V04B-35 (e); his §37 item 4.2): THE CHILD-DIFFERS SIGNAL computed from the answer — the per-child primitive; his (ii) Boolean beside a PARENT's entry is `any` of it over the children (the seat of commit 6, F-3) — package-public, NOT exported (docs/public-api.md §1.2; the register row §6); the name kept by his word of 2026-10-03 (R-V04B-95); the Block-against-File reading carried past the branch (the review's C23)

"""
    _entryErrorDelivery(parse_state, config, registry, diags) -> GoMetaDelivery

IS: the cold constructor of the fail-closed `PROCESS_ERROR` `GoMetaDelivery` — reached ONLY on an ENTRY
refusal — before any absorb or apply work of the refused call, and at `goMeta` before its parse: the registry door's
diagnostics (the config-time `validate_config` vector left at stage 5's E13 with the grammar profile — no configuration
field is refusable since: an unknown `flavor_tag` throws `flavor_for`'s own message, a range is taken plain, E8; the
callable seam that ran the door too, and its state ledger's refusals of an injected parse state, left at stage 5's E2).

DOES: builds a per-call `ProcessState` by `init_state` (container SIZING only — no parse content is read, no
`parseBLS` / absorb-walk runs), appends the coded `diags`, and hands back the delivery's four parts taken
from that state: the EMPTY store `st.evals` as `altValues_evals`; the unparsed `parse_state` — the caller passes
one built from EMPTY bytes, since the validation pre-empts touching the input — as `blsComponentTree`; `PROCESS_ERROR`;
the diagnostics. The working state itself is not delivered (R-V04B-28).

REASONING: `@noinline` + cold, so its `init_state` and the construction never perturb the byte-exact,
low-allocation main `goMeta` path; the empty-bytes tree keeps the delivery total (the development tool's `outputs`,
`devtools/basic_renderer.jl`, yields its empty non-OK pair on it).

PURPOSE: ONE fail-closed outcome for every entry refusal — coded diagnostics, never a throw.
"""
@noinline function _entryErrorDelivery(parse_state::BLS.ParseState, config::GoMetaConfig,
                                       registry::AlterantRegistry, diags::Vector{Diagnostic})
    st = init_state(parse_state, config, registry)
    append!(st.diagnostics, diags)
    return GoMetaDelivery(st.parse, st.evals, PROCESS_ERROR, st.diagnostics)   # the field order R-V04B-89
end

"""
    feed_user_mh!(st::ProcessState) -> nothing

IS: the feed of the RESERVED user slot of the meta-hierarchy (`userMHIdx` in `state.jl` — THE USER LEVEL: placed FIRST in the
eligible-slot order by both `applyAltActionFns` walks (its PRIORITY) and, since stage 0 of the Labels lane (0.4.1, R-LAB-8 /
R-LAB-15), EVALUATED after the Component's own slot — its accumulating rows collected first as the outermost level, its other
rows decided with full sight of the Component's own labels and with the override; fed by no other call site) with the metaLine-body profile in
`st.config.user_mh_profile`, BEFORE the absorb walk. SCOPE: a minimal caller-supplied feed ONLY — not a general
user-level configuration system; internal (NOT exported); called from `goMeta` iff `config.user_mh_profile` is a String
holding at least one character of content — one the absorb's ONE white-space predicate `AbsorbMeta._isspace_valid` does not
read as white space, an invalid byte sequence among them (R-ALT-25); an empty or whitespace-only profile is inert like
`nothing` — stage 2 of the Alterants build, R-ALT-18 / R-ALT-22.
Experimental — see docs/public-api.md §2.

DOES: reuses the standard machinery VERBATIM — no parallel intake — queued actions enqueue; a heading (an action of an
Alterant of the set mode `localOnly`) REFUSES at the read with his message (§D242; R-ALT-9: no Component of the file levels
to be local to — stage 1 of the Alterants build; before it the separate lane recorded one row against the minted
user-context handle, grain 0xe0): saves the meta-hierarchy cursor `st.crnt_idx`;
`updateMetaHierarchy(userMHIdx)` allocates + occupies the slot (its `10..12` branch; the depth-window wipes at `<10`
never touch it, so the fed slot SURVIVES the whole file walk); NULLS `st.meta_context` (no document line stands behind
this surface); sets `st.user_context` to the minted handle `UserContext(key_bytes(user_context_key(namespace, 1)))`
inside a try/finally that restores the prior value; then `absorbMeta` routes the profile's actions through the SAME
parseAlt path authored metaLines use; the meta-hierarchy cursor is restored so the walk starts exactly as un-fed.
The user level's OVERRIDE per non-accumulate alterant (evaluated after the Component's own slot, with priority over it —
stage 0 of the Labels lane) ⇒ the fed profile OVERRIDES authored Visib (e.g. `"discard{ :label1 } show"`), and a fed
condition sees the Component's own labels. An action name outside the registry errors loudly inside `absorbMeta` (the same
crash-loud class as an authored non-member). Returns `nothing`.

REASONING: one intake for authored and fed metadata — the fed profile is a metaLine body read by the same parser and
queued into a slot the depth-window wipes never reach; the save/set/restore bracket (never a bare null) is re-entry
safe and runs even when a refusal escapes the absorb, so the per-call state leaves no residue.

PURPOSE: a caller-supplied profile applied over the whole file from the user level of the meta-hierarchy.
"""
function feed_user_mh!(st::ProcessState)
    prev_idx = st.crnt_idx
    CnS.updateMetaHierarchy(userMHIdx)
    # This surface has NO document line/component behind it, so the MetaContext record is
    # NULLED. The feed's OWN identity rides `user_context` below: the queued actions' `decided_by`, and the trigger of
    # the one refusal a heading meets here (his §D242; stage 1 of the Alterants build; no copy of the profile's bytes
    # rides any row since commit 9b, R-V04B-43 (1)).
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
(docs/public-api.md §2). PURE + DETERMINISTIC for the ENGINE'S OWN OPERATIONS under `DEFAULT_REGISTRY`: the same
`(bytes, config, registry)` always yields the same `GoMetaDelivery`, with no filesystem / clock / environment read by the
Engine. A `{…}` condition is Julia text evaluated by Julia (stage 5's E13 of the v0.4 build; his §120 and §D174 — the
full parser, for those who work with their own GoMeta statements), so what a condition body reads or does is the
author's act, outside the Engine's guarantee — as a custom registry's own callables are (the trust model; README
SECURITY). The pipeline is parse -> Absorb-walk (enqueue alterant
actions) -> Apply (evaluate conditions + apply), run inside one per-call dynamic scope
(`STATE`), so two concurrent calls never share state.

Arguments:
- `bytes` — the input document as raw bytes. Line ENDINGS normalize to LF (CRLF is chomped — documented, not an
  error; see `docs/CANONICAL-OUTPUT.md`); content bytes are preserved faithfully for arbitrary bytes, including invalid UTF-8; non-ASCII inside a META line parses character-safely, a non-ASCII label APPLIED from outside the shipped set or a non-ASCII action meeting the stable unknown-label/unknown-action refusal (docs/public-api.md §4).
- `config::GoMetaConfig` — the v0 input options (flavor_tag / parse_range / user_mh_profile / namespace; see `GoMetaConfig`;
  the `profile` field left at stage 5's E13 with the grammar profile it selected). An unknown `flavor_tag` throws raw at
  `BLS.flavor_for` (the closed inventory, no fallback — a stable message, docs/public-api.md §3.4); a given `parse_range`
  is taken plain: `first` is never read, `last` is the parse end line, a non-positive `last` parses the whole file
  (the coded flavor and range refusals left at stage 5's E8 of the v0.4 build — census row 30).
- `registry::AlterantRegistry` — the alterant inventory; defaults to the deterministic `DEFAULT_REGISTRY`.

The `GoMetaDelivery` is `{blsComponentTree::BLS.ParseState, altValues_evals::EvalStore, status::ProcessStatus, diagnostics::Vector{Diagnostic}}` — the four public parts, read by name (R-V04B-28/29/30), in his pipeline order (R-V04B-89) — and is
TOTAL over the ENTRY surface (the registry door's refusals are delivered coded; an unknown flavor_tag throws its stable message, §3.4); absorb/apply-plane catalogued failures can still throw at v0 (see below): `status` is
`PROCESS_OK` (no error diagnostics) or `PROCESS_ERROR` (>=1 error `Diagnostic`; non-OK => non-empty diagnostics).
Obtain the Engine's output via `readAltValuesEvals(result.altValues_evals)` (the evals map, keyed by (handle, attr); its byte form
`serialize_evals`; a piece's text through `BLS.content`) — with the run itself, the Engine's delivered surface
after the move (R-V04B-24: "the run and the evaluated values"). The (tree, render) pair is the development
tool's: `Main.BasicRenderer.outputs`, applied to the result after `include(joinpath(pkgdir(GoMeta), "devtools", "load_basic_renderer.jl"))`
at the caller's top level. The entry refusals (the registry door's `REG_UNPUBLISHED` / `POST_SEAL_MUTATION`) are coded and
delivered; the condition path keeps THREE refusals of GoMeta's — the unknown condition key, the no-expression guard of an
empty block or a bare literal and the one scanner's unterminated `(` inside a body (s5c31, his §366), `ErrorException`s at the
absorb seam — a body Julia cannot parse is Julia's own `Meta.ParseError`,
a condition that fails at evaluation Julia's own error
(the condition codes and E-07's pending mint left with the closed interpreter at stage 5's E13); the E-06 absorb-path
guarded depth refusal stays without a code for now (the honest partition — docs/public-api.md §3; the E-04 apply-path crash origin
left with the Visib write-back at stage 3's commit 4).
The full honest-edges catalogue: docs/public-api.md §3.4.

# The marker syntax (short form)

`#~` / `#~N` / `#~~…` open metadata at a depth · `#~N!` (bare `#~!`) is the INERT form —
structurally identical, content ignored · the transposed `#~!N` refuses loudly · `#]`
closes the innermost metaBlock and detaches what follows · a trailing `#~ …` applies to
its own line. Full family + laws: the module docstring and `docs/SYNTAX-AND-SEMANTICS.md`.

REASONING: the Engine's own operations are pure and deterministic — no filesystem, clock or environment read — so that
the same `(bytes, config, registry)` always yields the same result (the byte law's ground); the trust model bounds the
guarantee: a condition body (Julia, evaluated by Julia — his §120) and a custom registry's own callables are the
author's, outside it.

PURPOSE: the one route from a document's bytes to the delivered object — the run and the evaluated values
(R-V04B-24) — for an Extension, a test, a development tool or a DB-interface.
"""
function goMeta(
    bytes::Vector{UInt8};
    config::GoMetaConfig = GoMetaConfig(),
    registry::AlterantRegistry = DEFAULT_REGISTRY,
)

    ## v0.4 T2 — THE STRICT DOOR (R-V04-34), the ONE entry refusal since stage 5's E13 (the config-time arm — `validate_config`'s
    ## profile check, E-03 — left at E13 with the grammar profile; no configuration field is refusable since: an unknown `flavor_tag`
    ## throws `flavor_for`'s own message below, a range is taken plain — E8): the registry must be PUBLISHED; an unpublished value
    ## refuses coded (`REG_UNPUBLISHED`, naming RegistryBuilder → validate → publish) and a published value mutated after
    ## publication refuses `POST_SEAL_MUTATION` (the live fields against the publish-time snapshot — the real freeze gate). The
    ## fail-closed PROCESS_ERROR GoMetaDelivery is built in the `@noinline` cold `_entryErrorDelivery` helper (its `init_state` +
    ## `GoMetaDelivery` construction stay OUT of this hot path); the input bytes are never touched — the error-path delivery
    ## carries a parse state built from EMPTY bytes (container sizing only). The E-06 (absorb) guarded refusal remains without a code
    ## at v0 (the E-04 apply crash origin left with the write-back, stage 3's commit 4); the condition path's three refusals of
    ## GoMeta's — the unknown condition key, the no-expression guard, the unterminated `(` inside a body (s5c31) — abort the statement at the absorb seam (`absorb_meta.jl`).
    door_diags = _registry_door_check(registry)
    isempty(door_diags) ||
        return _entryErrorDelivery(BLS.setUpToProcessFromBytes(UInt8[]), config, registry, door_diags)

    ## Resolve the flavor ONCE, after the door above (an unknown tag throws raw
    ## HERE — `flavor_for`'s stable message naming the closed inventory; its coded refusal left at
    ## stage 5's E8 of the v0.4 build, census row 30), and thread
    ## the record through the ParseState — every downstream flavor read rides
    ## `parse_state.flavor` (zero `config.flavor_tag` reads downstream of setup).
    flavor = BLS.flavor_for(config.flavor_tag)
    parse_state = BLS.setUpToProcessFromBytes(bytes; flavor = flavor)

    ## The public contract form — `goMeta(bytes; config::GoMetaConfig, registry::AlterantRegistry)
    ## -> GoMetaDelivery` (docs/public-api.md §2). The parse range is the typed `config.parse_range`: `nothing` ⇒
    ## the WHOLE file (mapped to `to = -1`); a `1:N` range ⇒ lines 1..N
    ## (`to = last(range)`). `parseBLS` ignores `fromLine` + breaks on `lineNum > toLine`
    ## (parseBLS.jl: `fromLine` has no use but its signature; a non-positive `toLine` becomes the line count — the seat's F2: the
    ## former citation of docs/SYNTAX-AND-SEMANTICS.md named a page that holds no range contract), so a non-positive `to` parses the whole file. The range is taken
    ## PLAIN, as his legacy took its arguments: `first` is never read (`5:10` parses lines 1..10; `3:2` lines
    ## 1..2; `1:0` the whole file) — the coded range refusal left at stage 5's E8 of the v0.4 build, census row 30.
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
    ## a flavor means extending `flavor_for`'s inventory, never a
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
        ## Seed the reserved user slot of the meta-hierarchy BEFORE the walk iff a profile is FED — `nothing` (the default) and,
        ## since stage 2 of the Alterants build, an EMPTY or whitespace-only String are the no-feed path (inert: the user slot is
        ## neither allocated nor occupied, so the loop's order is the un-fed one — his word of 2026-10-16, R-ALT-18 / R-ALT-22; the
        ## CrossReview set alt-stage1's E2 had traced an empty profile occupying the slot).
        ## (white space as the absorb reads it — its ONE predicate `_isspace_valid`, his §359 (10): Julia's bare `isspace` throws at decode
        ## on an overlong sequence, so an invalid edge byte is content here too — the profile is FED; the one-character overlong profile the
        ## absorb refuses, as at the stage-2 base 9bde47d (the lane's oracle L08); an invalid sequence glued to the label sugar `:` it does not
        ## refuse (L09) — R-ALT-25)
        if !isnothing(config.user_mh_profile) && !isempty(strip(AbsorbMeta._isspace_valid, config.user_mh_profile))
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
                # Capture this Block's FINAL evals rows (Labels + Visib + Id + Heading) into st.evals BEFORE the
                #   next apply wipes st.working — the cell is this Block. Render-neutral: it reads
                #   st.working and puts or supersedes rows in st.evals (no parse-tree or render mutation; no diagnostic).
                captureEvals!(st, childComponent)
            end
        end
    end

    ## The typed `GoMetaDelivery` supersedes the original three-field NamedTuple (render, tree, configDict)
    ## (the historical field name `tree_bytes` predates the `blsStructure_bytes` rename; kept verbatim in this
    ## comment only). `status` is computed from the accumulated diagnostics: `PROCESS_ERROR` iff an `:error` row
    ## exists, else `PROCESS_OK`. On this path no `:error` row is ever pushed (the door's
    ## refusal fail-closes through `_entryErrorDelivery` before the parse; the absorb/apply-path refusals still
    ## THROW — the unknown-condition-key refusal at the absorb seam, Julia's own ParseError for a body it cannot read,
    ## the E-06 row raw), so a run that returns
    ## here is `PROCESS_OK`, its diagnostics vector empty — the two capture-floor warnings of the Heading's separate lane left
    ## with that lane at stage 1 of the Alterants build (the type's docstring). The evaluated values are read by `readAltValuesEvals(result.altValues_evals)`; the development tool's
    ## (tree, render) pair (`Main.BasicRenderer.outputs`) is a pure function of the delivery — the tree READ, never written
    ## (stage 3's commit 4), every Visib value the Engine's answer (`evaluatedAltValue`; stage 3's commit 1).
    status = any(d -> d.severity === :error, st.diagnostics) ? PROCESS_ERROR : PROCESS_OK
    return GoMetaDelivery(st.parse, st.evals, status, st.diagnostics)   # the field order R-V04B-89
end

end # module GoMeta
