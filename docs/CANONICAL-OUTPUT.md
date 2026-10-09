# CANONICAL-OUTPUT.md — GoMeta's canonical observable output

- **IS:** the record of GoMeta's **canonical observable output** — the single, deterministic,
  content-hashable artifact a golden test or a downstream consumer obtains from a
  `goMeta(bytes; config)` run: the evaluated values, `altValues_evals` (+ `serialize_evals`; a piece's text
  through `GoMeta.BLS.content` — `content_fingerprint` REMOVED at 0.4.0's stage-2 commit 9b, R-V04B-43 (1)) — the Engine's delivered surface — and, beside it, the DEVELOPMENT TOOL's
  `(blsStructure_bytes, render_bytes)` pair (`Main.BasicRenderer.outputs`, `devtools/basic_renderer.jl`,
  loaded through `devtools/load_basic_renderer.jl`; R-V04B-24, 2026-09-12) which the golden layer pins.
  (This document's name — CANONICAL-OUTPUT — predates the move; it kept its name.) **Trust note:**
  a `{…}` condition is Julia text evaluated by Julia (since `0.4.0`, stage 5's E13 of the v0.4 build) — a run over a
  file executes its conditions; `docs/public-api.md` §2/§3.2 and the SECURITY section of `README.md` state the posture.
- **DOES:** (1) names the observable surface; (2) defines each half of the tool's pair; (3) states the hide/discard
  render rules of the `jl-share-v1` profile; (4) defines the evals surface; (5) carries
  the invariant register the shipped suite asserts; (6) states the CRLF normalization convention;
  (7) walks one example end-to-end.
- **REASONING:** the observable surface is pinned and deterministic, and this document is that
  pin's public statement. A change to the surface is a conscious, versioned change — never silent
  drift.
- **PURPOSE:** GoMeta's observable behavior is **pinned, deterministic, and hash-stable** for the Engine's
  own operations and for conditions free of side effects and of reads of changing state (a condition body is Julia, evaluated by Julia since
  `0.4.0` — what it reads or does is the author's act; see the SECURITY section of `README.md`); the committed example
  corpus and the golden test layer prove it byte-for-byte.

---

## §1 — The observable surface

**In R-V04B-24's own words: "the package's canonical observable output = `altValues_evals` (+
`serialize_evals`, `content_fingerprint`)" and "the Engine's delivered surface after the move = the run and
the evaluated values".** `readAltValuesEvals(result.altValues_evals)` is the deterministic, final-verdicts-only per-cell map of
evaluated Alterant values (GoMeta's semantic deliverable; the query-facing write payload; §4).

**The development tool's pair** — `Main.BasicRenderer.outputs(result) -> (blsStructure_bytes, render_bytes)`,
the basic renderer's own function (`devtools/basic_renderer.jl`, reached only through the loader):

- **the tree half** — the parse-stage, verdict-free tree print (the parse-defect discriminator);
- **the render half** — the post-apply share-target file bytes under the `jl-share-v1` profile,
  complete over **`:discard` AND `:hide`**.

The render is the basic renderer's **reference / verification render** — a development tool's output that
doubles as the conformance anchor, pinned by the golden layer; it is NOT an Engine output. **No Extension takes
the pair** (R-V04B-56 — the owner's word of 2026-09-24: "no Extension takes the pair"): an Extension consumes the
Engine's answer through the delivered object and the BLS Component tree (the part `blsComponentTree`, BLS's own
delivery, R-V04B-45); the pair is the tool's own, proved by its seven render reference files, never by an Extension.

## §2 — The tree half (the tool's tree print)

The deterministic tree print of the final parse tree (`structural_serialization`, in the basic renderer since
2026-09-12). It is **parse-stage** and
**verdict-free**: identical pre- and post-apply — it carries **no** verdict information. Its
role is discriminating parse defects: two engines that parse identically produce identical tree
bytes regardless of their alterant behavior.

## §3 — The render half (`jl-share-v1`) — the hide/discard rules

The render half completes the share-target emit over both non-show verdicts (`:hide` /
`:discard`). The six rules:

1. **`:discard` (any grain)** → **zero subtree bytes**.
2. **`:hide` at Line grain** → literal **`## ` prefix + the line's rendered bytes** (on a segmented line the first
   segment's indentation is restored as SPACES *after* the marker when that segment is emitted — his legacy's test,
   since stage 5's R1 of the v0.4 build, census row 60). On a hidden line with MULTIPLE rendered segments, **each
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
the rule-5 empty-line fact and the rule-6 ensure-token fact ride it too — the `Extended` pair's hidden text block
carries the blank input line (L40, rendered as a bare empty line) and the `## `-headed narration lines (L46–L49,
rendered as-is, no doubling; `docs/SYNTAX-AND-SEMANTICS.md` §7 cites them); the rule-6 one-way fact and
re-ingestion idempotence are NOT exercised by the corpus — they are proven by a standing differential in the
development fork. *(Dated true-up
2026-08-12 for `0.3.0`: the former sentence grounded the rule-6 DOUBLING in the corpus; the
doubling died with the ensure-token rule and the corpus outputs carry no doubled shapes.)*

**Share-profiles** parametrize the render half (one source, N profile-keyed outputs);
`jl-share-v1` is the v0 profile and the only one at this release.

## §4 — The evals surface

`readAltValuesEvals(result.altValues_evals) -> Vector{(cell_handle, attr, value, polarity)}` — the evaluated
Alterant values, per piece of the file: **deterministic,
content-hashable, final-verdicts-only**. Sorted by
`(cell_handle, attr, value)`; deduped at capture; **empty when no metaLine exists on ANY
surface** (the fed profile is a metaLine body).
`GoMeta.serialize_evals(readAltValuesEvals(result.altValues_evals))` is its canonical byte form. It is the
query-facing write payload; it does **not** enter the `(tree, render)` pair.

## §5 — The invariant register (asserted by the shipped suite)

| Invariant | Falsification | Enforced by |
|---|---|---|
| same `(bytes, profile, config)` ⇒ a byte-identical (tree, render) pair from the development tool's `Main.BasicRenderer.outputs`, across fresh processes (the tool's property over the Engine's stored values; see README SECURITY) | any byte diff | the golden layer (`tests/golden/golden_tests.jl`) — every fresh run must reproduce the pinned golden bytes byte-for-byte (the test layer's property) |
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
