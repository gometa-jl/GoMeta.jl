# CANONICAL-OUTPUT.md — GoMeta's canonical observable output

- **IS:** the record of GoMeta's **canonical observable output** — the single, deterministic,
  content-hashable artifact a golden test or a downstream consumer obtains from a
  `goMeta(bytes; config)` run: the `(blsStructure_bytes, render_bytes)` pair from `GoMeta.outputs`,
  plus the `altValues_evals` surface. (This document's name — CANONICAL-OUTPUT — names that
  canonical observable pair; `GoMeta.outputs` is the function that returns it.) **Trust note:**
  a default-configured `goMeta` run evaluates no condition text (the closed interpreter); only
  the explicitly opt-in full-eval mode can execute code — `docs/public-api.md` §2/§3.2 and the
  SECURITY section of `README.md` state the posture.
- **DOES:** (1) names the observable surface; (2) defines each half; (3) states the hide/discard
  render rules of the `jl-share-v1` profile; (4) defines the evals surface; (5) carries
  the invariant register the shipped suite asserts; (6) states the CRLF normalization convention;
  (7) walks one example end-to-end.
- **REASONING:** the observable surface is pinned and deterministic, and this document is that
  pin's public statement. A change to the surface is a conscious, versioned change — never silent
  drift.
- **PURPOSE:** GoMeta's observable behavior is **pinned, deterministic, and hash-stable** (engine
  operations; conditions run in the closed no-eval interpreter, so in a default-configured run a
  condition body cannot read or have effects — the explicitly opt-in `:full_eval_v1` extension
  mode is the one exception, see the SECURITY section of `README.md`); the committed example
  corpus and the golden test layer prove it byte-for-byte.

---

## §1 — The observable surface

`GoMeta.outputs(result) -> (blsStructure_bytes, render_bytes)` + `altValues_evals(result)`:

- **the tree half** — the parse-stage, verdict-free structural serialization (the parse-defect
  discriminator);
- **the render half** — the post-apply share-target file bytes under the `jl-share-v1` profile,
  complete over **`:discard` AND `:hide`**;
- **the evals surface** — the deterministic, final-verdicts-only per-cell map of evaluated
  Alterant values (GoMeta's semantic deliverable; the query-facing write payload).

The render half is GoMeta's **reference / verification render** — verification tooling that
doubles as the conformance anchor. The core's primary *semantic* deliverable is the
values-as-data surface (`altValues_evals`). The two are core outputs in different roles.

## §2 — The tree half

The deterministic structural serialization of the final parse tree. It is **parse-stage** and
**verdict-free**: identical pre- and post-apply — it carries **no** verdict information. Its
role is discriminating parse defects: two engines that parse identically produce identical tree
bytes regardless of their alterant behavior.

## §3 — The render half (`jl-share-v1`) — the hide/discard rules

The render half completes the share-target emit over both non-show verdicts (`:hide` /
`:discard`). The six rules:

1. **`:discard` (any grain)** → **zero subtree bytes**.
2. **`:hide` at Line grain** → literal **`## ` prefix + the line's rendered bytes** (indentation
   preserved *after* the marker). On a hidden line with MULTIPLE rendered segments, **each
   rendered segment carries its own `## ` marker UNLESS the segment already heads with the
   marker's bytes** (the ensure-token rule — a trailing `## `-comment segment renders as-is;
   *dated true-up 2026-08-12 for `0.3.0`, superseding the `0.2.3` per-segment doubling*) —
   pinned by the committed pairs: the code line
   `using Plots ## This …` renders hidden as `## using Plots ## This …` (the line-start marker;
   the trailing comment segment already carries `## `), and a line with a trailing inline
   metaLine renders it `## `-marked too (`… ## #~ hide`).
3. **`:hide` at Block grain** → **every emitted NON-EMPTY subtree line** prefixed.
4. **`:hide` at Segment grain** → **lift-to-Line at v0** — a mid-line `## ` would comment out all
   following shown segments (a correctness hazard); inline segment-hide is reserved as a
   profile-versioned extension.
5. **A hidden EMPTY line renders as a BARE empty line** — the hide marker is applied only to
   non-empty lines (the emit's hide write sits in the non-empty branch). There is NO `## `-only encoding for hidden empties at v0.
6. **Ensure-token, render-idempotent** *(dated true-up 2026-08-12 for `0.3.0` — supersedes the
   `0.2.3` "prefix doubling" rule: a line already starting `## ` used to become `## ## …`)*: a
   hide write is skipped when the source line's POST-INDENT head already begins with the
   flavor's hide marker, so a line already starting `## ` renders AS-IS and
   `render ∘ ingest ∘ render == render` holds over the hide battery (a standing idempotence
   differential in the development fork proves it per armed flavor, with a stacking-forgery
   negative control). THE FIDELITY BOUND, disclosed: an authored marker-headed line under hide
   renders AS-IS — byte-indistinguishable from engine-hidden output; the bound only NARROWS
   distinguishability. **Recovery is NOT a v0 behavior:** the hide render remains ONE-WAY — no
   `## `-strip function exists; do not expect a render→original round-trip (reversibility never
   existed under the doubling rule either).

**Two senses, never conflated:** the *input* `##` human-comment convention (§1 of the syntax
reference) and the *output* `## ` hide-marker are distinct senses of the same two characters.

**Inline metaLine segments are rendered, never silently dropped:** verbatim on SHOWN lines (the
committed Proposal pair keeps `… #~ show` in its output) and `## `-marked on HIDDEN lines (rule
2) — both pinned by the committed pairs.

**Metadata is ALIVE in the render — a stated DESIGN PROPERTY.** Hide is
a VISIBILITY operation: hidden metadata remains live metadata. Re-processing a share render
therefore re-yields verdicts — a hidden metaLine's rendered form `## #~ …` re-parses on
re-ingestion (at segment grain: same liveness, shifted scope). One carve-out: a hidden metaLine
that re-ingests as a `## ` comment INSIDE a live meta block reads as block commentary — inert by
the same rule that makes `## ` comments inert between metaLines. DISCARDED metadata, by contrast,
is absent from the render and therefore gone on re-ingestion. This is by design, not a defect:
choose `discard` when metadata must not survive the share; choose `hide` when the share should
stay a living GoMeta document.

These rules are **oracle-grounded where exercised**: rules 1–4 ride the
committed corpus (`examples/`), whose renders the golden test layer pins **byte-for-byte** (7/7);
the rule-5 empty-line fact and the rule-6 ensure-token + one-way facts are engine behavior
documented here (the corpus exercises neither a hidden empty line nor a marker-headed input
line — the idempotence facts are proven by a standing differential in the development fork). *(Dated true-up
2026-08-12 for `0.3.0`: the former sentence grounded the rule-6 DOUBLING in the corpus; the
doubling died with the ensure-token rule and the corpus outputs carry no doubled shapes.)*

**Share-profiles** parametrize the render half (one source, N profile-keyed outputs);
`jl-share-v1` is the v0 profile and the only one at this release.

## §4 — The evals surface

`altValues_evals(result) -> Vector{(cell_handle, attr, value, polarity)}` — the evaluated
Alterant values, per piece of the file: **deterministic,
content-hashable, final-verdicts-only**. Sorted by
`(cell_handle, attr, value)`; deduped at capture; **empty when no metaLine exists on ANY
surface** (the fed profile is a metaLine body).
`GoMeta.serialize_evals(altValues_evals(result))` is its canonical byte form. It is the
query-facing write payload; it does **not** enter the `(tree, render)` pair.

## §5 — The invariant register (asserted by the shipped suite)

| Invariant | Falsification | Enforced by |
|---|---|---|
| same `(bytes, profile, config)` ⇒ byte-identical `GoMeta.outputs`, across fresh processes (engine operations; see README SECURITY) | any byte diff | the golden layer (`tests/golden/golden_tests.jl`) — every fresh run must reproduce the pinned golden bytes byte-for-byte |
| discard ⇒ zero subtree bytes; hide ⇒ all NON-EMPTY subtree lines `## `-prefixed (§3 rules 3+5) | a leak or an absence | the golden render-polarity + not-tree-only canary testsets (`tests/golden/golden_tests.jl`) |
| tree half identical pre/post-apply (verdict-free) | verdict leakage into tree bytes | the verdict-free-tree testset (`tests/golden/golden_tests.jl`) |
| the evals surface deterministic + total over applied verdicts | nondeterminism / a dropped verdict | the golden layer's net-new-surface testsets (`tests/golden/golden_tests.jl`) — serialized evals against pinned shas + a double-run equality |

**Design rule (no single named test):** no identity is ever derived from an output hash — an
output hash names a *behavior* (of an engine on an input under a config); it never names an
object.

## §6 — CRLF normalization (documented convention, NOT an error)

Both setup paths **chomp `\r\n`** → line **ENDINGS** normalize to **LF**; line **CONTENT bytes
stay faithful** (invalid UTF-8 preserved). **Goldens are LF.** This is a documented normalization
convention, not a defect: it does not alter content bytes, only the line terminator. The
hide-prefix rules (§3) respect LF endings.

## §7 — Worked example (hide + discard, end-to-end)

Input `examples/InFileFolder/file_for_Example_Extended.jl` line 14
(``# This `Line` should still be "hidden"… #~ hide``) → parse (a text Line with a trailing inline
metaLine) → absorb enqueues hide → apply (Visib = hide wins) → emit under `jl-share-v1`:
``## # This `Line`…`` with the trailing inline metaLine segment ALSO rendered, `## `-marked — the
committed line ends `… ## #~ hide` (rule 2's per-segment marker). Line 15 (`#~ discard`) → zero
bytes in the output — the narration *"Input line 15 will be missing from the output file!"* is
itself the committed expectation. The committed corpus pair pins both outcomes byte-for-byte.
