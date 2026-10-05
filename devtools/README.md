# devtools/ — the GoMeta development tools

**What this directory is.** Tools for *looking at* what a GoMeta run produced — the BLS
Component tree, every Component's settribute state, and the evaluated values
(`altValues_evals`) placed on the Components that carry them. They are **not part of the
GoMeta process**: nothing under `src/` references them, the package runs identically without
them, and they never change a result. They `import GoMeta`, run one file, and print. Ruled by
the owner: the print tools on 2026-08-20 (R-DEV-1..9, `plan/2026-08-19-gometa-dev-print-tools/
DESIGN_dev-print-tools.md`), the directory and the move here on 2026-08-29 (R-V04B-17; the
directory itself was ruled on 2026-08-28, D-2a, as the future home of the basic renderer and
`run_examples.jl` — D-2b EXECUTED on 2026-09-12, R-V04B-24). Origin: `00_GoMeta-Play/`, which keeps its own FROZEN
copies of `devtools.jl` and `gometa.jl` since 2026-09-12 (OWNER-WORDS §26; the 2026-08-29
forwarding stubs are gone).

**What is in this directory (since 2026-09-12, R-V04B-24).** `devtools.jl` — the print tools;
the command-line entry at its end (the eight verbs — `comparison` since stage 4; the former `gometa.jl`, folded 2026-09-12); `basic_renderer.jl` — the basic renderer (module
`BasicRenderer`: the share-view render, the tree print and the (tree, render) pair `outputs`),
formerly `src/emit/emit.jl` inside the Engine; `load_basic_renderer.jl` — THE ONE PATH by which the
renderer is loaded (include it at the consumer's top level, never inside a function, never
`basic_renderer.jl` directly — the LOAD-ORDER law); `handle_decoder.jl` — THE ONE decoder of an occurrence handle's bytes, shared by the tools and the authored test runner (his word of 2026-10-03, R-V04B-102); `run_examples.jl` — the corpus driver;
`probes/` — the tools' assertion battery and its fixtures.

**The rule (canon `GoMetaEcosystem/agent-doc/AGENT-RULES_GoMeta.md` §R4/§R4b):** no claim
about what a run evaluated, for which Component, without one of these printouts. Probe, then
say.

## One-liners from a shell (the command-line entry of `devtools.jl`; the former `gometa.jl` was folded into it on 2026-09-12, R-V04B-24's tidy-up row)

```
GM=/home/fido/Dropbox/_01_Crypto_Dropbox/07_Claude/GoMetaEcosystem/GoMeta
julia --startup-file=no --project=$GM/tests $GM/devtools/devtools.jl <verb> <file>
```
`--project` selects WHICH GoMeta runs (`$GM/tests` = this v0.4 build; the Play project = its
0.3.2 snapshot, driven since 2026-09-12 by the Play's OWN frozen copies of the tools — OWNER-WORDS §26,
as the paragraph above says — not from this entry). Status and diagnostics go to stderr, the printout to stdout. Verbs:

| verb | prints |
|---|---|
| `tree` | the BLS Component tree, one row per input line (`Main.BasicRenderer.outputs(result).blsStructure_bytes`) |
| `segments` | the same rows with input line numbers in front — "what is line N?" |
| `evals` | the evaluated values, one row per line: `attr => value (polarity) "cell excerpt"` — the compact census form |
| `trace` | `evals` plus each row's decoded key: namespace · grain · path · origin |
| `render` | the share-view bytes (the basic renderer's output) |
| `evals-tree` | **`print_altValues_evals`, the FULL form** — the rows placed in the Component tree, every Component shown, absence labelled `(no evals — defaults apply)`, every row with its decoded handle and the Segment that caused it |
| `bls-tree` | **`print_BLS_Component_Tree`** (`style=:mix`) — the tree with every Component's typed named-int and settribute dumps |
| `comparison` | **`comparisonForm`** — the comparison form of R-V04B-36 (stage 4): one line per Component and one per Component per Alterant, sorted; the definition `tests/comparison/README.md` |

## From Julia (the REPL, a script, a test)

```julia
using GoMeta
include(joinpath(pkgdir(GoMeta), "devtools", "devtools.jl"))
result = GoMeta.goMeta(read("some.jl"))

print_altValues_evals(result)                                      # compact tree (R-DEV-4 default)
print_altValues_evals(result; include_empty = true, show_handles = true)   # the FULL form
print_altValues_evals(result; layout = :cells)                     # per-cell dossiers
print_altValues_evals(result; layout = :rows, attrs = :visib)      # one line per row, filtered
print_BLS_Component_Tree(result)                                   # :mix — tree + typed dumps
print_BLS_Component_Tree(result; style = :tree, detail = :full)    # plain tree + dumps

write_altValues_evals_to_file("evals.html", result; include_empty = true)   # .html / .txt twins
write_BLS_Component_Tree_to_file("tree.html", result)
# the drift alarm is the battery devtools/probes/probe_devtools.jl (below) — ALL GREEN after any engine change
```
Keywords of `print_altValues_evals`: `layout` (`:tree` | `:rows` | `:cells`), `include_empty`
(`:tree` only — `false` compact, `true` full), `show_handles`, `attrs` (`:all` | a Symbol | a
Vector), `lines` (an input-line range), `color` (`:auto` | `:always` | `:never`). The full
docstrings are in `devtools.jl`.

## What they read, and the alarm

The tools AND the moved basic renderer (`basic_renderer.jl`, the tree print included) read the
delivered part `result.blsComponentTree` (public by name, R-V04B-29) THROUGH THE DOOR since stage 2's commit 0 of the
v0.4 build (R-V04B-58, R-V04B-80): BLS's public functions and types — `GoMeta.BLS.root`, `children`, `getElement`,
`content` (a Component's text; the File's text, its lines joined, as the one-argument `content(tree)`), `kind`, `flavor`, `endsWithNewline`,
`isHorizontalSpace`, the Component types, `keys` of the two named-element types (`docs/public-api.md` §1.2) — and no field of
a BLS object. No read outside the door remains since stage 5's s5c8 (his word of 2026-10-05, R-V04B-116 (3): the renderer's
whitespace guard before the hide marker reads `isHorizontalSpace`; the tools read the File's text through `content(tree)`); the
texts of the former exemption D-6(a) of 2026-08-20 left with it. Consumer code — an Extension — reads the tree the same way, through the door
(`docs/public-api.md` §1.2; R-V04B-45).
The assertion battery
`devtools/probes/probe_devtools.jl` is the drift alarm: if the surface changes, it fails loudly. Run it after every change to `src/` (the tools' own self-check left at stage 5's T1 — R-V04B-111). It lives beside them since 2026-09-12 (OWNER-WORDS §26 of the
build record: the play became a self-contained fork and keeps its own frozen copy of the tools and
of the battery; its fixture inputs are `devtools/probes/fixtures/` and `examples/InFileFolder/`);
run it with `julia --startup-file=no --project=$GM/tests $GM/devtools/probes/probe_devtools.jl`
— exit 0 = `probe_devtools: ALL GREEN`.

## Where they are used

- The local site, page "The authored tests": `GoMetaEcosystem/agent-doc/site/capture-devtools.jl`
  and `capture-traces.sh` run these tools on every authored draft and embed the output
  unabridged (byte-checked by `embed-traces.py --check`).
- The JuliaCon talk deck's dev-tool slides (2026-08-22/23) and the demo deck
  `plan/2026-08-20-devtools-slide-output/consumer/compset/compset_devtools_demo.pptx`
  (slides 7–9) were produced from `write_altValues_evals_to_file` output with the tools' former
  `slide` option (`consumer/SOP_slide-production.md`) — the option and the three surface writers left
  at stage 5's T2 (census rows 2 and 9, his §317); the deck and its record stand.

## The comparison form (stage 4 of the v0.4 build; R-V04B-36)

`comparisonForm(result; name, at)` returns, and `writeComparisonFormToFile(path, result; name, at)` writes, the
content-keyed TEXT form by which GoMetaRetro's output is compared with v0.4's reference — one line per Component
(kind, span, parent key, position, children keys, content type, flags) and one line per Component per Alterant (the
value and its source as the deciding Component's own key or its level), sorted by code point under one header line.
The definition and the grammar: `tests/comparison/README.md`; the twelve forms beside it — v0.4's reference altValues in
his terms of 2026-09-29, not reference files (`regenerate.jl` writes or checks them); the first comparator
`devtools/compare_forms.sh` (a sorted-text diff). The verb `comparison`
prints one form to stdout. Pinned by the battery's §18.
