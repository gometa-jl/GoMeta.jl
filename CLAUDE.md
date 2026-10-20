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
julia --startup-file=no --project=$GM/tests $GM/devtools/devtools.jl evals-tree <file>   # print_altValues_evals, the FULL delivery view
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
- **Code-home facts from the lessons pool** (its GoMeta entries, landed by the pool-lessons sitting of 2026-10-20 on
  the owner's phrase; each clause names its entry, the entry's evidence path and line — relative to `07_Claude/` —
  and the day it was learned): a FRESH git worktree of this code home needs `Pkg.instantiate()` on its tests
  project before any proof runs on it (`JULIA_LOAD_PATH=@:@stdlib julia --startup-file=no
  --project=<worktree>/tests -e 'using Pkg; Pkg.instantiate()'` — the dev dependency on the package is recorded
  per environment; a load failure is never banked as a proof receipt)
  (20261016T190744Z_2e199e3b_fresh-worktree-instantiate-first; plan/2026-10-15-gometa-alterants-build/03_process_log.md:261;
  2026-10-16); the release push is the OWNER's command, over the SSH alias `github-metaglobi` (`~/.ssh/config` →
  `~/.gometa-keys/metaglobi`, IdentitiesOnly; the passphrase his, no agent holds it, no credential helper, no `gh`)
  with the explicit alias URL, because the configured push remote is `no_push` by design — a session may, on his
  word, create the tag and fast-forward the local main, and hands him the one command that asks for the passphrase
  (20261018T130049Z_b47b00ac_package-push-over-metaglobi-alias;
  GoMetaEcosystem/GoMetaPublic/dev-logs/2026-10-16_website-v04-recut.md:1077; 2026-10-18); every predicate over
  bytes a user controls (a profile string, a metaLine's bytes) is the Engine's ONE white-space predicate
  (`_isspace_valid` — his §342/§343), never Base's `strip`/`isspace`, which throw at decode on an invalid UTF-8
  edge byte where the Engine's guarded walk refuses (20261016T165022Z_2e199e3b_engine-one-predicate-on-user-bytes;
  plan/2026-10-15-gometa-alterants-build/receipts/stage2/AFTER_scratch-uncured-L08/ORACLE-MANIFEST.tsv:38;
  2026-10-16); a test addresses a registry record (an action spec) by its NAME
  (`findfirst(s -> s.name === :head, b.action_specs)`), never by its position — a newly registered action shifts
  the positions and the test silently tests another record (20261017T115621Z_2e199e3b_positional-spec-index-brittle;
  GoMetaEcosystem/GoMeta/tests/unit/seam_envelope_tests.jl:52; 2026-10-17); a Segment-carried evals row's cell
  handle carries the Segment as its ORIGIN, so a test never keys a Line's rows by the Line's plain occurrence key —
  compare the rows directly or decode the handle; the plain key matches Block-carried rows only
  (20261020T063139Z_346a4218_segment-row-handle-origin; GoMetaEcosystem/GoMeta/tests/unit/fed_profile_order_tests.jl:84;
  2026-10-19).
