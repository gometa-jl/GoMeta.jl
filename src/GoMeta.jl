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
#     `Diagnostic` BEFORE any parse work (the input bytes are never touched) — the ONE entry refusal since 0.4.0
#     (the config-time `ERR_UNKNOWN_PROFILE` row, E-03, was removed with the grammar profile). The coded
#     flavor and range refusals were removed within the 0.4 development: an unknown `flavor_tag`
#     throws raw at `BLS.flavor_for` (the closed inventory, no fallback — a stable message, docs/public-api.md §3.4)
#     and a given `parse_range` is taken plain (`first` never read; `to = last`; a non-positive `to` parses the
#     whole file, the parser's contract). The absorb-walk + apply run inside one per-call dynamic scope, `with(STATE =>
#     init_state(parse_state, config, registry))`, so two
#     concurrent calls never share state; the driver walk enters each file-level Block, absorbs its
#     metaLines, applies the queued alterant actions and captures per-cell evals rows (the Block's Visib
#     among them; nothing is written into the Components) for
#     `readAltValuesEvals(result.altValues_evals)`. The tool's `outputs` pair — the BLS Component tree's print and the render — is the
#     development tool's — `devtools/basic_renderer.jl`, loaded through `devtools/load_basic_renderer.jl`,
#     never by the Engine. The optional
#     `config.user_mh_profile` seeds the reserved user slot of the meta-hierarchy before the walk
#     (`feed_user_mh!`; a heading in the profile meets the one refusal at the read — the creator's decision;
#     docs/public-api.md §2; experimental).
# REASONING: the public contract (docs/public-api.md §2) requires `goMeta` to be pure and
#     deterministic FOR THE ENGINE'S OWN OPERATIONS (no filesystem / clock / environment read; a `{…}` condition is
#     Julia text evaluated by Julia since 0.4.0 — the creator's design — so what a condition body reads or
#     does is the author's act, as a custom registry's callables are: README SECURITY), and TOTAL over the entry
#     surface — non-OK implies non-empty diagnostics. Honest edges: the E-06 absorb-path guarded refusal is documented
#     but not yet coded (its conversion deferred; the E-04 apply-path crash origin was removed with the Visib
#     write-back); the condition path keeps THREE refusals of GoMeta's — the unknown condition key (the vocabulary's),
#     the no-expression guard of an empty block or a bare literal and the one scanner's unterminated `(`
#     inside a body — and a body Julia cannot parse is Julia's own
#     `Meta.ParseError` (the condition codes were removed with the closed interpreter).
#     The full honest-edges catalogue: docs/public-api.md §3.
# PURPOSE: the single auditable entry point — bytes in, a typed `GoMetaDelivery` out, with the package's
#     canonical observable output = `altValues_evals` (+ `serialize_evals`); the Engine's
#     delivered surface = the run and the evaluated values; the (tree, render) pair is the
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
include("arguments.jl") # THE ARGUMENT-EDGE CLASS `is_argument_space` — the characters the reader trims at every bare argument's edges, for every Alterant (package-public; since 0.4.3)
include("bls/BLS.jl")
include("occurrence.jl")            # the normalized occurrence handle (since v0.2) — depends
                                    # on BLS ONLY; everything downstream may
                                    # reference OccurrenceKey/occurrence_key/key_bytes
import .BLS
include("state.jl")     # per-call ProcessState + the typed GoMetaDelivery surface + the AlterantRegistry type + the STATE/ctx() seam
include("alterants/registry.jl")    # the Alterants + CnS layers, combined (Alterants BEFORE CnS)
using .CnS: getState, getAltState   # the two names a re-written condition calls by BARE name under `Core.eval(GoMeta, ex)` —
                                    #   the original engine's GoMeta.jl :18 (the closed interpreter's include was removed with it)
include("annotations.jl")           # the evals surface — evals capture +
                                    #   readAltValuesEvals(result.altValues_evals). AFTER registry.jl (Alterants.Visib/Id) + state.jl
                                    #   (ProcessState/GoMetaDelivery/EvalStore); BEFORE walk.jl + the driver below
                                    #   (which call captureEvals!). Holds no eval, no render-write.
include("absorb/absorb_meta.jl")
using .AbsorbMeta
include("absorb/walk.jl")           # goMetaAddOns absorb-half — absorbMeta (above) must precede it
include("alterants/apply.jl")       # goMetaAddOns apply-half — late-bound from walk, so OK after walk
include("answer.jl")                # THE ONE ANSWER FUNCTION `evaluatedAltValue` + its record
                                    #   `EvaluatedAltValue` — derived at the call from the delivered rows and `decided_by`; after apply.jl (nothing below depends on it)
include("scan.jl")                  # THE SCAN BY ALTERANT `scanAlterant` + THE ACCESS BY COMPONENT
                                    #   `evaluatedAltValues` — thin reads over `evaluatedAltValue`; after answer.jl
include("childdiff.jl")             # THE CHILD-DIFFERS SIGNAL `childDiffers` — computed from
                                    #   `evaluatedAltValue` at the call; a stored form is a later question; after scan.jl


#########################################################################################
########### Public API (the declared semver surface — re-exported) #####################
# The four names below ARE GoMeta's declared public API (docs/public-api.md §1.1); `export` re-exports them — all defined directly in
# this module via the include spine above — so `using GoMeta` brings exactly these into scope and `names(GoMeta)` IS the
# machine-checkable semver surface (asserted by tests/unit/public_surface_tests.jl). EVERYTHING else stays PACKAGE-PUBLIC (reached
# qualified, e.g. GoMeta.PROCESS_OK / .Diagnostic): the names on the `public` lines below — TWENTY-EIGHT since 0.4.3 (twenty-seven at 0.4.0; `is_argument_space` added at 0.4.3);
# the former `PlugIn` alias is not among them; docs/public-api.md §1.2 is the mirror
# and its §6 register carries every change of the set as a row.
# Qualified import (`import GoMeta as GM`) is UNAFFECTED by these exports and remains canonical for namespace
# hygiene + multi-implementation use; exporting serves the single-implementation `using` convenience only.
export goMeta, readAltValuesEvals, GoMetaConfig, GoMetaDelivery
public serialize_evals, EvalRecord, EvalStore, ProcessStatus, PROCESS_OK, PROCESS_ERROR, Diagnostic, AlterantRegistry, DEFAULT_REGISTRY,
       RegistryBuilder, register!, next_plugin_index, validate, publish, RegistrationRefused,   # the registration lifecycle (docs/public-api.md §1.2)
       Alterant, ActionSpec, CaptureDecl, DefaultSlot, NoDefault, Declared   # the record vocabulary a third-party author constructs (docs/public-api.md §1.2)
public BLS   # the parser module public by name — its door of travel / access functions declared INSIDE it (src/bls/BLS.jl; docs/public-api.md §1.2 + §6)
public evaluatedAltValue, EvaluatedAltValue   # THE ONE ANSWER FUNCTION and its record — package-public, NOT exported (docs/public-api.md §1.2; its row in §6)
public scanAlterant, evaluatedAltValues   # THE SCAN BY ALTERANT and THE ACCESS BY COMPONENT — package-public, NOT exported (docs/public-api.md §1.2; its row in §6); functions of their own, not methods of the reader
public childDiffers   # THE CHILD-DIFFERS SIGNAL computed from the answer — the per-child primitive; a Boolean beside a PARENT's entry is `any` of it over the children — package-public, NOT exported (docs/public-api.md §1.2; its row in §6)
public is_argument_space   # THE ARGUMENT-EDGE CLASS — the one predicate over the characters the Engine's reader trims at the two edges of every bare argument, for every Alterant and every reader of names (src/arguments.jl; docs/public-api.md §1.2; its row in §6)

"""
    _entryErrorDelivery(parse_state, config, registry, diags) -> GoMetaDelivery

IS: the cold constructor of the fail-closed `PROCESS_ERROR` `GoMetaDelivery` — reached ONLY on an ENTRY
refusal — before any absorb or apply work of the refused call, and at `goMeta` before its parse: the registry door's
diagnostics (the config-time `validate_config` vector was removed with the grammar profile — no configuration
field is refusable since: an unknown `flavor_tag` throws `flavor_for`'s own message, a range is taken plain; the
callable seam that ran the door too, and its state ledger's refusals of an injected parse state, were removed as well).

DOES: builds a per-call `ProcessState` by `init_state` (container SIZING only — no parse content is read, no
`parseBLS` / absorb-walk runs), appends the coded `diags`, and hands back the delivery's four parts taken
from that state: the EMPTY store `st.evals` as `altValues_evals`; the unparsed `parse_state` — the caller passes
one built from EMPTY bytes, since the validation pre-empts touching the input — as `blsComponentTree`; `PROCESS_ERROR`;
the diagnostics. The working state itself is not delivered.

REASONING: `@noinline` + cold, so its `init_state` and the construction never perturb the byte-exact,
low-allocation main `goMeta` path; the empty-bytes tree keeps the delivery total (the development tool's `outputs`,
`devtools/basic_renderer.jl`, yields its empty non-OK pair on it).

PURPOSE: ONE fail-closed outcome for every entry refusal — coded diagnostics, never a throw.
"""
@noinline function _entryErrorDelivery(parse_state::BLS.ParseState, config::GoMetaConfig,
                                       registry::AlterantRegistry, diags::Vector{Diagnostic})
    st = init_state(parse_state, config, registry)
    append!(st.diagnostics, diags)
    return GoMetaDelivery(st.parse, st.evals, PROCESS_ERROR, st.diagnostics)   # the field order: the creator's pipeline order
end

"""
    feed_user_mh!(st::ProcessState) -> nothing

IS: the feed of the RESERVED user slot of the meta-hierarchy (`userMHIdx` in `state.jl` — THE USER LEVEL: placed FIRST in the
eligible-slot order by both `applyAltActionFns` walks (its PRIORITY) and, since 0.4.1,
EVALUATED after the Component's own slot — its accumulating rows collected first as the outermost level, its other
rows decided with full sight of the Component's own labels and with the override — the one exception, UNMEASURED, as the code reads
(`apply.jl` S1): a Component whose only eligible slot is the user level's has no own slot and runs the un-fed path, the profile's rows
in written order, its labels not collected first; fed by no other call site) with the metaLine-body profile in
`st.config.user_mh_profile`, BEFORE the absorb walk — a VOCABULARY statement in the profile (`:++x` / `:--x`, since 0.4.2) is consumed at this
read by the Labels Alterant's hook and precedes every statement of the file. SCOPE: a minimal caller-supplied feed ONLY — not a general
user-level configuration system; internal (NOT exported); called from `goMeta` iff `config.user_mh_profile` is a String
holding at least one character of content — one the absorb's ONE white-space predicate `AbsorbMeta._isspace_valid` does not
read as white space, an invalid byte sequence among them; an empty or whitespace-only profile is inert like
`nothing` — since 0.4.0.
Experimental — see docs/public-api.md §2.

DOES: reuses the standard machinery VERBATIM — no parallel intake — queued actions enqueue; a heading (an action of an
Alterant of the set mode `localOnly`) REFUSES at the read with the creator's message (no Component of the file levels
to be local to — since 0.4.0; before 0.4.0, the Heading's separate path recorded one row against the minted
user-context handle, grain 0xe0): saves the meta-hierarchy cursor `st.crnt_idx`;
`updateMetaHierarchy(userMHIdx)` allocates + occupies the slot (its `10..12` branch; the depth-window wipes at `<10`
never touch it, so the fed slot SURVIVES the whole file walk); NULLS `st.meta_context` (no document line stands behind
this surface); sets `st.user_context` to the minted handle `UserContext(key_bytes(user_context_key(namespace, 1)))`
inside a try/finally that restores the prior value; then `absorbMeta` routes the profile's actions through the SAME
parseAlt path authored metaLines use; the meta-hierarchy cursor is restored so the walk starts exactly as un-fed.
The user level's OVERRIDE per non-accumulate alterant (evaluated after the Component's own slot, with priority over it —
since 0.4.1) ⇒ the fed profile OVERRIDES authored Visib (e.g. `"discard{ :label1 } show"`), and a fed
non-accumulate condition sees the Component's own labels (measured); a fed CONDITIONAL label does not — it is
collected in pass 1, as the outermost level, before the file's labels (measured). An action name outside the registry errors loudly inside `absorbMeta` (the same
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
    # the one refusal a heading meets here (the creator's decision; no copy of the profile's bytes
    # rides any row).
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
Engine — one exception since 0.4.3, the shipped Labels Alterant's vocabulary files: the Labels Alterant reads the user level's
vocabulary file and its vocabulary statements edit it, so a run's labels and diagnostics depend on that file (docs/public-api.md §2,
THE VOCABULARY FILES). A `{…}` condition is Julia text evaluated by Julia (since 0.4.0, the creator's design — the
full parser, for those who work with their own GoMeta statements), so what a condition body reads or does is the
author's act, outside the Engine's guarantee — as a custom registry's own callables are (the trust model; README
SECURITY). The pipeline is parse -> Absorb-walk (enqueue alterant
actions) -> Apply (evaluate conditions + apply), run inside one per-call dynamic scope
(`STATE`), so two concurrent calls never share state.

Arguments:
- `bytes` — the input document as raw bytes. Line ENDINGS normalize to LF (CRLF is chomped — documented, not an
  error; see `docs/CANONICAL-OUTPUT.md`); content bytes are preserved faithfully for arbitrary bytes, including invalid UTF-8; non-ASCII inside a META line parses character-safely, a non-ASCII label APPLIED from outside the run's vocabulary (the user level's vocabulary file's names with the run's vocabulary statements folded in, docs/public-api.md §2) is reported by the unknown label's warning diagnostic and skipped (since 0.4.3; a refusal before), a non-ASCII action meets the stable unknown-action refusal (docs/public-api.md §4).
- `config::GoMetaConfig` — the v0 input options (flavor_tag / parse_range / user_mh_profile / namespace; see `GoMetaConfig`;
  the `profile` field was removed with the grammar profile it selected). An unknown `flavor_tag` throws raw at
  `BLS.flavor_for` (the closed inventory, no fallback — a stable message, docs/public-api.md §3.4); a given `parse_range`
  is taken plain: `first` is never read, `last` is the parse end line, a non-positive `last` parses the whole file
  (the coded flavor and range refusals were removed within the 0.4 development).
- `registry::AlterantRegistry` — the alterant inventory; defaults to the deterministic `DEFAULT_REGISTRY`.

The `GoMetaDelivery` is `{blsComponentTree::BLS.ParseState, altValues_evals::EvalStore, status::ProcessStatus, diagnostics::Vector{Diagnostic}}` — the four public parts, read by name, in the creator's pipeline order — and is
TOTAL over the ENTRY surface (the registry door's refusals are delivered coded; an unknown flavor_tag throws its stable message, §3.4); absorb/apply-plane catalogued failures can still throw at v0 (see below): `status` is
`PROCESS_OK` (no error diagnostics) or `PROCESS_ERROR` (>=1 error `Diagnostic`; non-OK => non-empty diagnostics).
Obtain the Engine's output via `readAltValuesEvals(result.altValues_evals)` (the evals map, keyed by (handle, attr); its byte form
`serialize_evals`; a piece's text through `BLS.content`) — with the run itself, the Engine's delivered surface
("the run and the evaluated values"). The (tree, render) pair is the development
tool's: `Main.BasicRenderer.outputs`, applied to the result after `include(joinpath(pkgdir(GoMeta), "devtools", "load_basic_renderer.jl"))`
at the caller's top level. The entry refusals (the registry door's `REG_UNPUBLISHED` / `POST_SEAL_MUTATION`) are coded and
delivered; the condition path keeps THREE refusals of GoMeta's — the unknown condition key, the no-expression guard of an
empty block or a bare literal and the one scanner's unterminated `(` inside a body, `ErrorException`s at the
absorb seam — a body Julia cannot parse is Julia's own `Meta.ParseError`,
a condition that fails at evaluation Julia's own error
(the condition codes were removed with the closed interpreter); the E-06 absorb-path
guarded depth refusal stays without a code for now (the honest partition — docs/public-api.md §3; the E-04 apply-path crash origin
was removed with the Visib write-back).
The full honest-edges catalogue: docs/public-api.md §3.4.

# The marker syntax (short form)

`#~` / `#~N` / `#~~…` open metadata at a depth · `#~N!` (bare `#~!`) is the INERT form —
structurally identical, content ignored · the transposed `#~!N` refuses loudly · `#]`
closes the innermost metaBlock and detaches what follows · a trailing `#~ …` applies to
its own line. Full family + laws: the module docstring and `docs/SYNTAX-AND-SEMANTICS.md`.

REASONING: the Engine's own operations are pure and deterministic — no filesystem, clock or environment read — so that
the same `(bytes, config, registry)` always yields the same result (the byte law's ground) — the shipped Labels Alterant's user-level
vocabulary file the one state beside the bytes since 0.4.3 (docs/public-api.md §2); the trust model bounds the
guarantee: a condition body (Julia, evaluated by Julia) and a custom registry's own callables are the
author's, outside it.

PURPOSE: the one route from a document's bytes to the delivered object — the run and the evaluated values
— for an Extension, a test, a development tool or a DB-interface.
"""
function goMeta(
    bytes::Vector{UInt8};
    config::GoMetaConfig = GoMetaConfig(),
    registry::AlterantRegistry = DEFAULT_REGISTRY,
)

    ## THE STRICT DOOR, the ONE entry refusal since 0.4.0 (the config-time arm — `validate_config`'s
    ## profile check, E-03 — was removed with the grammar profile; no configuration field is refusable since: an unknown `flavor_tag`
    ## throws `flavor_for`'s own message below, a range is taken plain): the registry must be PUBLISHED; an unpublished value
    ## refuses coded (`REG_UNPUBLISHED`, naming RegistryBuilder → validate → publish) and a published value mutated after
    ## publication refuses `POST_SEAL_MUTATION` (the live fields against the publish-time snapshot — the real freeze gate). The
    ## fail-closed PROCESS_ERROR GoMetaDelivery is built in the `@noinline` cold `_entryErrorDelivery` helper (its `init_state` +
    ## `GoMetaDelivery` construction stay OUT of this hot path); the input bytes are never touched — the error-path delivery
    ## carries a parse state built from EMPTY bytes (container sizing only). The E-06 (absorb) guarded refusal remains without a code
    ## at v0 (the E-04 apply crash origin was removed with the write-back); the condition path's three refusals of
    ## GoMeta's — the unknown condition key, the no-expression guard, the unterminated `(` inside a body — abort the statement at the absorb seam (`absorb_meta.jl`).
    door_diags = _registry_door_check(registry)
    isempty(door_diags) ||
        return _entryErrorDelivery(BLS.setUpToProcessFromBytes(UInt8[]), config, registry, door_diags)

    ## Resolve the flavor ONCE, after the door above (an unknown tag throws raw
    ## HERE — `flavor_for`'s stable message naming the closed inventory; its coded refusal was removed within
    ## the 0.4 development), and thread
    ## the record through the ParseState — every downstream flavor read rides
    ## `parse_state.flavor` (zero `config.flavor_tag` reads downstream of setup).
    flavor = BLS.flavor_for(config.flavor_tag)
    parse_state = BLS.setUpToProcessFromBytes(bytes; flavor = flavor)

    ## The public contract form — `goMeta(bytes; config::GoMetaConfig, registry::AlterantRegistry)
    ## -> GoMetaDelivery` (docs/public-api.md §2). The parse range is the typed `config.parse_range`: `nothing` ⇒
    ## the WHOLE file (mapped to `to = -1`); a `1:N` range ⇒ lines 1..N
    ## (`to = last(range)`). `parseBLS` ignores `fromLine` + breaks on `lineNum > toLine`
    ## (parseBLS.jl: `fromLine` has no use but its signature; a non-positive `toLine` becomes the line count;
    ## docs/SYNTAX-AND-SEMANTICS.md holds no range contract), so a non-positive `to` parses the whole file. The range is taken
    ## PLAIN, as the original engine took its arguments: `first` is never read (`5:10` parses lines 1..10; `3:2` lines
    ## 1..2; `1:0` the whole file) — the coded range refusal was removed within the 0.4 development.
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
    ## itself writes no file anywhere — the one file a run writes is the shipped Labels Alterant's own, the user level's vocabulary file, created
    ## at the first need and edited by a vocabulary statement (src/alterants-std/labels.jl; docs/public-api.md §2); `parseBLS` above is called purely for its parse side-effect.

    ## The absorb/apply driver — ONE function again since 0.4.0 (the creator's words on the callable driver seam of
    ## v0.3.2: a seam serving the
    ## .fodt adapter alone "will eventually have to be removed from the GoMeta engine" — the original engine was one function,
    ## GoMetaRetro's src/GoMeta.jl :26–:113: the parse, then the File loop). Build the FRESH per-call `ProcessState`
    ## (`init_state` is reset-safe, so neither the slot tensors nor the cursors leak between calls) + open the per-call
    ## dynamic scope: `STATE => st` carries the per-call state so the eval'd bare-name `getState`/`getAltState` reach it
    ## (`ctx() = STATE[]`). The whole absorb-walk + apply runs INSIDE this scope; the parse state is READ, never written;
    ## one parse state per call by construction — the seam ledger that enforced it
    ## for injected states was removed with the seam.
    st = init_state(parse_state, config, registry)
    with(STATE => st) do
        ## Seed the reserved user slot of the meta-hierarchy BEFORE the walk iff a profile is FED — `nothing` (the default) and,
        ## since 0.4.0, an EMPTY or whitespace-only String are the no-feed path (inert: the user slot is
        ## neither allocated nor occupied, so the loop's order is the no-feed one — the creator's decision; before 0.4.0
        ## an empty profile occupied the slot).
        ## (white space as the absorb reads it — its ONE predicate `_isspace_valid`: Julia's bare `isspace` throws at decode
        ## on an overlong sequence, so an invalid edge byte is content here too — the profile is FED; the one-character overlong profile the
        ## absorb refuses (measured); an invalid sequence glued to the label sugar `:` it does not
        ## refuse (measured))
        if !isnothing(config.user_mh_profile) && !isempty(strip(AbsorbMeta._isspace_valid, config.user_mh_profile))
            feed_user_mh!(st)
        end
        ## The File loop (the original engine's; a `_walk_and_apply!` factoring of the 0.4 development was removed —
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
                ## The Block-grain Visib write-back was REMOVED here: the Engine writes NOTHING into the caller's BLS
                ## Components — the Block's Visib is CAPTURED (below) and read through the one answer function.
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
    ## exists, else `PROCESS_OK`. On this path the Engine itself pushes no `:error` row (the registry door's
    ## refusal fail-closes through `_entryErrorDelivery` before the parse; the absorb/apply-path refusals still
    ## THROW — the unknown-condition-key refusal at the absorb seam, Julia's own ParseError for a body it cannot read,
    ## the E-06 row raw); its diagnostics vector carries the rows the Engine's one door delivered from an Alterant's return — a setter's at the apply (since 0.4.3),
    ## a read-time hook's at the read (since 0.4.3 too, with the vocabulary files) — each with the
    ## severity its Alterant gave it — a custom Alterant's `:error` row makes the run `PROCESS_ERROR` with the tree and the rows delivered; under the
    ## shipped registry a run that returns here is `PROCESS_OK` and its vector carries the Labels Alterant's rows alone (`:warning`:
    ## `LABEL_NOT_APPLIED_WITHHELD`, a plain `:x` met by a withhold; `LABEL_NOT_APPLIED_UNKNOWN`, a name outside the run's vocabulary under any verb;
    ## `LABELS_VOCABULARY_FILE_NOT_WRITTEN`; `:info`: `LABELS_VOCABULARY_FILE_CHANGED`, a `++` / `--` that edited the user level's vocabulary file;
    ## `_deliver_diagnostics!`, state.jl) and is empty otherwise — the two capture-floor warnings of the Heading's separate path were removed
    ## with that path within the 0.4 development (the type's docstring). The evaluated values are read by `readAltValuesEvals(result.altValues_evals)`; the development tool's
    ## (tree, render) pair (`Main.BasicRenderer.outputs`) is a pure function of the delivery — the tree READ, never written
    ## — every Visib value the Engine's answer (`evaluatedAltValue`).
    status = any(d -> d.severity === :error, st.diagnostics) ? PROCESS_ERROR : PROCESS_OK
    return GoMetaDelivery(st.parse, st.evals, status, st.diagnostics)   # the field order: the creator's pipeline order
end

end # module GoMeta
