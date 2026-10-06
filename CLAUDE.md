# GoMeta (the v0.4 code home) — CLAUDE.md

This directory is the GoMeta v0.4 package repository (branch `v04-build`; origin = the public
`gometa-jl/GoMeta.jl`, **push disabled**). The program's orientation, mandate and unified
documentation live one level up in `GoMetaEcosystem/` (read its `CLAUDE.md` and
`unified-doc/U0-orientation.md` first; launch sessions THERE — that directory arms the
project memory, this one does not). For any question about the design — what the owner
decided, leans to, or left open — the Unified Documentation FIRST (`../unified-doc/U8-design.md`,
then its loci, the original transcripts, other files): his law, OWNER-WORDS §173–§174, 2026-09-22; the
canon's R5. The build record: `plan/2026-08-24-gometa-v04-build/`
(`RULINGS.md`, `03_process_log.md` — append-only).

## THE DEVELOPMENT TOOLS — use them before any claim about a run (owner order 2026-08-29)

`devtools/README.md` documents them; the canon is `../agent-doc/AGENT-RULES_GoMeta.md` §R4/§R4b. Since 2026-09-12
(R-V04B-24's tidy-up row) the one-line command tool is the entry at the end of `devtools.jl`; `gometa.jl` is gone.

```
GM=/home/fido/Dropbox/_01_Crypto_Dropbox/07_Claude/GoMetaEcosystem/GoMeta
julia --startup-file=no --project=$GM/tests $GM/devtools/devtools.jl evals-tree <file>   # print_altValues_evals, FULL form
julia --startup-file=no --project=$GM/tests $GM/devtools/devtools.jl bls-tree   <file>   # print_BLS_Component_Tree (:mix)
julia --startup-file=no --project=$GM/tests $GM/devtools/devtools.jl segments   <file>   # the tree with line numbers
julia --startup-file=no --project=$GM/tests $GM/devtools/devtools.jl trace      <file>   # evals rows + decoded keys
```
From Julia: `include(joinpath(pkgdir(GoMeta), "devtools", "devtools.jl"))` then
`print_altValues_evals(result; include_empty = true, show_handles = true)` /
`print_BLS_Component_Tree(result)`. **The rule:** what a run evaluated, for which Component,
is stated from these printouts — never re-derived from raw text (canon R1) and never asserted
from memory (canon R3). Put the tool's output, unabridged, into any page or record that makes
such a claim. The battery `devtools/probes/probe_devtools.jl` must print ALL GREEN after every change under `src/`.

## Standing rules for this repository

- **Tests never change the Engine, the parser or the Extensions** (owner, 2026-08-28,
  R-V04B-15): every test artefact lives under `tests/`; the authored truth set
  `tests/authored/` is written implementation-neutral (positions, not handles) and is the shared
  specification of this build and the parallel new-GoMeta effort.
- **The suite:** `JULIA_LOAD_PATH="@:@stdlib" julia --project=tests tests/runtests.jl`
  (`Pkg.test()` uses the `test/` target; `Random` is declared in both test environments since stage 1
  commit 5 — green under `Pkg.test()`, measured at its pre-check). The twelve annotation pins in `tests/golden/MANIFEST.toml` are
  append-only.
- **Commits:** pathspec-only, never `-am`, never bare; never push (origin is the public repo).
- **The boundary law (owner, 2026-08-27):** the GoMeta Engine EVALUATES and records values as
  data; it never renders; the basic renderer is a development aid acting on evaluated values;
  Extensions consume the evaluated values (each in its own way). The sitting's decisions
  D-1…D-21 are in the build record's `RULINGS.md`.
- **Opt-in condition modes** (`:full_julia_parse_v1`, `:full_eval_v1`) live in `optin/`
  (R-V04B-14) and are loaded only by an explicit `include` — never by default.
- **Terminology (canon R2):** metaLine (never "mark line") · Block / Line / Segment ·
  flavors Code / Meta / Text · Alterants capitalised (Visib · Labels · Heading · Id), actions
  lowercase (hide · show · discard) · evals · Extension · settribute.
- **Code-home traps** (the lessons pool's hand-off H13 — this build's own lessons of 2026-10-01/02; the owner's
  phrase of 2026-10-06, OWNER-WORDS §346 of the build record): a new cross-module read gets a witness test on
  EVERY path that reaches it; a test over a hand-built parse state runs the set-up, then `parseBLS(ps, 1, -1)`,
  then the seam or the walk (the set-up alone yields a File with zero Blocks); every loop of assertions over a
  collection is preceded by an assertion on its size; a reader of the Engine's rows derives each key as the
  Engine's writer does, never from the declared field the writer only starts from; before a signature or
  field-list change, grep every caller — the out-of-suite probes, the root scripts and the plan repository's
  instruments included; a pre-check instrument that calls a removed function is re-derived for the post-commit
  tree before it runs; a Julia probe run as a file keeps its accumulating loops inside a function (Julia's soft
  scope); a new branch placed above existing returns is probed on every case those returns distinguish; a plain
  Line has no Segment children — a test that needs one builds a Line with an inline metaSegment
  (`x = 1 #~ discard`).
- **Notebook regeneration** (the same hand-off, the flagged tenth): the line-classifying generator turns an
  INDENTED `# ` continuation line inside a code run into a standalone markdown cell — a pre-check of a source
  edit asserts the regenerated notebook's CELL STRUCTURE (the cell count; no prose cell holding a comment
  fragment), not only that `--check` regenerates byte-identically (a green check proves idempotence, not layout).
