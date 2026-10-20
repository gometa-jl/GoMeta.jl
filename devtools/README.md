# devtools/ — the GoMeta development tools

**What this directory is.** Tools for *looking at* what a GoMeta run produced — the BLS
Component tree, every Component's settribute state, and the evaluated values
(`altValues_evals`) placed on the Components that carry them. They are **not part of the
GoMeta process**: nothing under `src/` references them, the package runs identically without
them, and they never change a result. They `import GoMeta`, run one file, and print. By the
creator's decisions: the print tools exist since 2026-08-20; this directory is their home since
2026-08-29, and since 2026-09-12 also the home of the basic renderer and of `run_examples.jl`.

**What is in this directory (since 2026-09-12).** `devtools.jl` — the print tools;
the command-line entry at its end (the eight verbs; the former `gometa.jl`, folded into it 2026-09-12); `basic_renderer.jl` — the basic renderer (module
`BasicRenderer`: the share-view render, the tree print and the (tree, render) pair `outputs`),
formerly `src/emit/emit.jl` inside the Engine; `load_basic_renderer.jl` — THE ONE PATH by which the
renderer is loaded (include it at the consumer's top level, never inside a function, never
`basic_renderer.jl` directly — the LOAD-ORDER law); `handle_decoder.jl` — THE ONE decoder of an occurrence handle's bytes, shared by the tools and the authored test runner; `run_examples.jl` — the corpus driver;
`probes/` — the tools' assertion battery and its fixtures.

**The rule:** no claim
about what a run evaluated, for which Component, without one of these printouts. Probe, then
say.

## One-liners from a shell (the command-line entry of `devtools.jl`; the former `gometa.jl` was folded into it on 2026-09-12)

```
GM=/path/to/GoMeta          # this repository's root
julia --startup-file=no --project=$GM/tests $GM/devtools/devtools.jl <verb> <file>
```
`--project` selects WHICH GoMeta runs (`$GM/tests` = this repository's test environment, which holds the package).
Status and diagnostics go to stderr, the printout to stdout. Verbs:

| verb | prints |
|---|---|
| `tree` | the BLS Component tree, one row per input line (`Main.BasicRenderer.outputs(result).blsStructure_bytes`) |
| `segments` | the same rows with input line numbers in front — "what is line N?" |
| `evals` | the evaluated values, one row per line: `attr => value (polarity) "cell excerpt"` — the evals-rows-only view (no Component identity) |
| `trace` | the evals-rows-with-keys view: `evals` plus each row's decoded key: namespace · grain · path · origin |
| `render` | the share-view bytes (the basic renderer's output) |
| `evals-tree` | **`print_altValues_evals`, the FULL delivery view** — the rows placed in the Component tree, every Component shown, absence labelled `(no evals — defaults apply)`, every row with its decoded handle and the Segment that caused it |
| `bls-tree` | **`print_BLS_Component_Tree`** (`style=:mix`) — the Component-tree view: the tree with every Component's typed named-int and settribute dumps |
| `comparison` | **`comparisonForm`** — the comparison form: one line per Component and one per Component per Alterant, sorted; the definition `tests/comparison/README.md` |

## From Julia (the REPL, a script, a test)

```julia
using GoMeta
include(joinpath(pkgdir(GoMeta), "devtools", "devtools.jl"))
result = GoMeta.goMeta(read("some.jl"))

print_altValues_evals(result)                                      # the compact delivery view (the default)
print_altValues_evals(result; include_empty = true, show_handles = true)   # the FULL delivery view
print_altValues_evals(result; layout = :cells)                     # the per-cell view
print_altValues_evals(result; layout = :rows, attrs = :visib)      # the evals-rows-by-Component view, filtered
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

**Two facts for reading the printouts.** A byte comparison of a printout against a banked comparator runs the
tool with the colour variable unset (`env -u FORCE_COLOR julia …`) — a shell environment carrying `FORCE_COLOR`
makes Julia print ANSI escapes and the comparison then reports differences that are not differences of the
evaluation. The views right-pad a short name before its arrow, so a value cut from a printout column by a regex has
its padding stripped before it is compared with a name list.

## What they read, and the alarm

The tools AND the moved basic renderer (`basic_renderer.jl`, the tree print included) read the
delivered part `result.blsComponentTree` (public by name) THROUGH THE DOOR since 0.4.0:
BLS's public functions and types — `GoMeta.BLS.root`, `children`, `getElement`,
`content` (a Component's text; the File's text, its lines joined, as the one-argument `content(tree)`), `kind`, `flavor`, `endsWithNewline`,
`isHorizontalSpace`, the Component types, `keys` of the two named-element types (`docs/public-api.md` §1.2) — and no field of
a BLS object. No read outside the door remains since 0.4.0 (the renderer's
whitespace guard before the hide marker reads `isHorizontalSpace`; the tools read the File's text through `content(tree)`); the
former exemption of the tools from the door, and its texts, were removed at the same time. Consumer code — an Extension — reads the tree the same way, through the door
(`docs/public-api.md` §1.2).
A recorded limit at v0.4 (measured 2026-10-14): the evals printouts (`evals-tree`, `evals`, `trace`, the per-cell layout) turn a Component's content bytes into text for the excerpt and throw Julia's InvalidCharError when an invalid UTF-8 sequence that needs decoding (a 3- or 4-byte overlong encoding) stands at a content's head or tail; the Component-tree view (`bls-tree`, `tree`) does not. By the creator's decision the guarantee is to move to BLS in a later version — a flag `containsInvalidUTF8` on every Component and one text read of the door that never throws — and these tools will take that read.
The assertion battery
`devtools/probes/probe_devtools.jl` is the drift alarm: if the surface changes, it fails loudly. Run it after every change to `src/`. It lives beside them since 2026-09-12;
its fixture inputs are `devtools/probes/fixtures/` and `examples/InFileFolder/`;
run it with `julia --startup-file=no --project=$GM/tests $GM/devtools/probes/probe_devtools.jl`
— exit 0 = `probe_devtools: ALL GREEN`.

## Where they are used

- A page or a deck that shows what a run produced embeds these tools' output unabridged — never a retyped excerpt (the rule above: probe, then say).
- The JuliaCon 2026 talk deck's dev-tool slides (2026-08-22/23) were produced from `write_altValues_evals_to_file`
  output with the tools' former `slide` option; the option and its three surface writers were removed within the 0.4
  development.

## The comparison form

`comparisonForm(result; name, at)` returns, and `writeComparisonFormToFile(path, result; name, at)` writes, the
content-keyed TEXT form by which GoMetaRetro's output is compared with v0.4's reference — one line per Component
(kind, span, parent key, position, children keys, content type, flags) and one line per Component per Alterant (the
value and its source as the deciding Component's own key or its level), sorted by code point under one header line.
The definition and the grammar: `tests/comparison/README.md`; the twelve forms beside it — v0.4's reference altValues in
the creator's term (not reference files; `regenerate.jl` writes or checks them); the first comparator
`devtools/compare_forms.sh` (a sorted-text diff). The verb `comparison`
prints one form to stdout. Pinned by the battery's §18.
