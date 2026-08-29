# devtools/ — the GoMeta development tools

**What this directory is.** Tools for *looking at* what a GoMeta run produced — the BLS
Component tree, every Component's settribute state, and the evaluated values
(`altValues_evals`) placed on the Components that carry them. They are **not part of the
GoMeta process**: nothing under `src/` references them, the package runs identically without
them, and they never change a result. They `import GoMeta`, run one file, and print. Ruled by
the owner: the print tools on 2026-08-20 (R-DEV-1..9, `plan/2026-08-19-gometa-dev-print-tools/
DESIGN_dev-print-tools.md`), the directory and the move here on 2026-08-29 (R-V04B-17; the
directory itself was ruled on 2026-08-28, D-2a, as the future home of the basic renderer and
`run_examples.jl` — D-2b pending). Origin: `00_GoMeta-Play/`, whose `devtools.jl` and
`gometa.jl` are now forwarding stubs.

**The rule (canon `GoMetaEcosystem/agent-doc/AGENT-RULES_GoMeta.md` §R4/§R4b):** no claim
about what a run evaluated, for which Component, without one of these printouts. Probe, then
say.

## One-liners from a shell

```
GM=/home/fido/Dropbox/_01_Crypto_Dropbox/07_Claude/GoMetaEcosystem/GoMeta
julia --startup-file=no --project=$GM/tests $GM/devtools/gometa.jl <verb> <file>
```
`--project` selects WHICH GoMeta runs (`$GM/tests` = this v0.4 build; the Play project = its
0.3.0 snapshot). Status and diagnostics go to stderr, the printout to stdout. Verbs:

| verb | prints |
|---|---|
| `tree` | the BLS Component tree, one row per input line (`outputs(result).blsStructure_bytes`) |
| `segments` | the same rows with input line numbers in front — "what is line N?" |
| `evals` | the evaluated values, one row per line: `attr => value (polarity) "cell excerpt"` — the compact census form |
| `trace` | `evals` plus each row's decoded key: namespace · grain · path · origin |
| `render` | the share-view bytes (the basic renderer's output) |
| `evals-tree` | **`print_altValues_evals`, the FULL form** — the rows placed in the Component tree, every Component shown, absence labelled `(no evals — defaults apply)`, every row with its decoded handle and the Segment that caused it |
| `bls-tree` | **`print_BLS_Component_Tree`** (`style=:mix`) — the tree with every Component's typed named-int and settribute dumps |

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
devtools_selfcheck()          # the drift alarm — must return true after any engine change
```
Keywords of `print_altValues_evals`: `layout` (`:tree` | `:rows` | `:cells`), `include_empty`
(`:tree` only — `false` compact, `true` full), `show_handles`, `attrs` (`:all` | a Symbol | a
Vector), `lines` (an input-line range), `color` (`:auto` | `:always` | `:never`), `slide` (a
colour scheme for slide previews; the write twins emit a `.slideruns.json` sidecar). The full
docstrings are in `devtools.jl`.

## What they read, and the alarm

The tools read the Engine's internal state (`result.state.parse`) and a few non-public helpers
under the owner's exemption D-6(a) of 2026-08-20 — allowed for THESE tools only; consumer code
must not copy the pattern. `devtools_selfcheck()` is the drift alarm: if the internal surface
changes, it fails loudly. Run it after every change to `src/`. Their assertion battery,
`probes/probe_devtools.jl`, stays in `00_GoMeta-Play/` (its two fixture inputs live there) and
runs through the stub.

## Where they are used

- The local site, page "The authored tests": `GoMetaEcosystem/agent-doc/site/capture-devtools.jl`
  and `capture-traces.sh` run these tools on every authored draft and embed the output
  unabridged (byte-checked by `embed-traces.py --check`).
- The JuliaCon talk deck's dev-tool slides (2026-08-22/23) and the demo deck
  `plan/2026-08-20-devtools-slide-output/consumer/compset/compset_devtools_demo.pptx`
  (slides 7–9) were produced from `write_altValues_evals_to_file` output
  (`consumer/SOP_slide-production.md`).
