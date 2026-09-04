# The scenario catalogue — what the authored-truth set must eventually cover

*R-V04B-15 (c): "gradually expanded … capture any possible scenario". Spine: the sections of `docs/SYNTAX-AND-SEMANTICS.md` (0–13) and the rulings of 2026-08. A row is DONE when a confirmed scenario file exists; DRAFT when a session has drafted the expectation for the owner to confirm; OPEN otherwise. Sessions add rows; only the owner confirms.*

| # | scenario (plain words) | doc section | status | file |
|---|---|---|---|---|
| 1 | A Block says hide; a plain Line inside inherits hide; a Line with inline `#~ show` overrides (Line over Block) | 7, 8 | DRAFT | `001_block_hide_inherits` |
| 2 | A Block says discard; a nested (depth-2) show RESURFACES its own Block and the code under it — nearest wins, the ruled direction of changelist R-1 / Q-009 (2026-08-07); the depth-1 lines are absent from the share-view *(row wording corrected 2026-09-04 by S4: the earlier text stated the opposite of the ruled direction; the draft's stem still says "no_resurface" and is renamed on the owner's confirmation)* | 7, 8 | DRAFT | `002_block_discard_no_resurface` |
| 3 | No meta at all: every Component's Visib is the default (show); the evaluated values are empty | 0, 7 | DRAFT | `003_no_meta_defaults` |
| 4 | Labels accumulate down the meta hierarchy: a depth-1 metaLine adds `:label1`, a depth-2 metaLine adds `:label2`; the depth-2 Block and the code under it carry both *(row wording corrected 2026-09-04 by S4: the draft tests Block-to-Block accumulation; the Line/Segment case is row 22)* | 5 | DRAFT | `004_labels_accumulate` |
| 5 | A Heading applies once, where it stands, and is not inherited by the Lines below (the localOnly set mode) | 9, 10 | DRAFT | `005_heading_local_only` |
| 6 | Two Visib verdicts on one Component: the Engine refuses (the multiplicity law; R-5 of 2026-08-07) | 7 | OPEN | |
| 7 | A condition true / false on a label applied earlier in the same metaLine (order of application) | 6 | OPEN | (`feature_order_of_application.jl` exists as a golden; needs the authored expectations) |
| 8 | Explicit close of a Block (`#~-`) and the ATTACH axis: the two axes are orthogonal | 3, 4 | OPEN | (`feature_explicit_close.jl` golden; needs expectations) |
| 9 | Depth: a `#~2` metaLine inside a `#~1` Block; which Block a Line belongs to | 2 | OPEN | |
| 10 | The inert `#~N!` metaLine: structure kept, content ignored (R-INERT-1/-4, 2026-08-19) | 9 | OPEN | |
| 11 | Inline meta on a Line (Segments): a Segment's own value applies to its Segment (reserved plane; your canvas of 2026-07-24) — expectation to be ruled | 1 | OPEN — needs the D-5 ruling | |
| 12 | A fenced code block (```) with a metaLine after it: metadata applies again after the fence | 9 | OPEN | (`feature_triple_tilde.jl` golden) |
| 13 | A contiguous meta block and a blank line inside it | 1, 3 | OPEN | (`feature_contiguous_metablock*.jl` goldens) |
| 14 | The C-family flavor: `//` lead, `//#` hide marker — same tree, same values as the Julia twin | 13 | OPEN | |
| 15 | The LaTeX flavor: `%` lead, `%%` hide marker — same tree, same values as the Julia twin | 13 | OPEN | |
| 16 | An Id Alterant with two fields set in two metaLines (`mutExclusivePerField`) — expectation to be ruled (per-field semantics deferred) | 10 | OPEN — needs a ruling | |
| 17 | Invalid bytes (not UTF-8) in content: parsed as content, no crash (R-REL-21) | 13 | OPEN | |
| 18 | An empty file; a file without a terminal newline (RC-1) | 13 | OPEN | |
| 19 | The opt-in modes: the same file under `:closed_v1` and `:jl_share_v1_full_parse` gives identical values (R-V04B-14) | 6 | OPEN | |
| 20 | A third-party Alterant registered in a custom registry: its values appear in the evaluated values without an Engine edit (the T5 promise) | 10 | OPEN | |
| 21 | The File as a Component: its Visib answer when nothing governs it (the default), and under a file-level `#~0` metaLine | 0, 2 | OPEN — needs the D-4 ruling (File governable or not at v0.4) | |
| 22 | Accumulation onto a Line with inline meta: a Block adds a label, a Line inside adds another; the Line carries both, the Block does not | 5, 1 | OPEN — needs the D-5 ruling (the Segment plane) | |
| 23 | A default on one Component while a metaLine governs another: `a = 1` · `#~ hide` · `b = 2` — line 1 keeps the default show, the Block below hides | 7 | OPEN | |

Rows 1–5 are drafted below the line as expectation files for the owner to confirm; the input files are tiny and self-explanatory. Rows marked "needs a ruling" wait for the sitting. Rows 21–23 added 2026-09-04 by S4 (the coverage the first sitting's own questions imply); the set keeps expanding under R-V04B-15 (c) — every new feature, ruling or cure adds its row.
