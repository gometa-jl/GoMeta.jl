# notebooks/ — one file, many faces

Everything in this folder derives from the TWO source files under `src/` — purely from
their `#~` marks, by the shipped generator `notebooks_from_source.jl` at the repository
root. Regenerate and byte-compare every generated file yourself:

```
julia --startup-file=no --project=. notebooks_from_source.jl --check
```

| artifact | what it is |
|---|---|
| `src/montecarlo.jl` | the hero source: an ordinary, runnable Julia file (`include` it) whose marks derive every artifact below |
| `montecarlo.ipynb` | the full edition — every surviving cell, with legend-driven tags (`parameters`, `skip-execution`, `solution`, `deep-dive`); the GoMeta data travels with it (see below) |
| `montecarlo-student.ipynb` | the worksheet — the solution cell is ABSENT (verify: `grep -c estimate_pi_fused montecarlo-student.ipynb` prints `0`), a scaffold cell stands in, and instruction cells are locked (`editable: false`) |
| `montecarlo-report.ipynb` | the reading view — every code input folded (`jupyter.source_hidden` + the `hide-input` tag) |
| `montecarlo-slides.ipynb` | the deck — `slideshow.slide_type` per cell, scraped from the source's depth marks; `jupyter nbconvert --to slides` turns it into a reveal.js deck |
| `montecarlo-executed.ipynb` | the ONE executed edition: real outputs from a standard `jupyter nbconvert --execute` run under the `julia-1.12` kernel, deterministic via the seeded source; volatile execution-timing metadata removed. Outside the `--check` byte gate (it carries kernel outputs), validated separately |
| `src/quickstart.jl` + `quickstart.ipynb` | one source, two faces: the quickstart runs as a script from the checkout root AND as the derived notebook from this folder — the onboarding artifact demonstrates the pipeline it teaches |

The same marks also derive the two manual pages `docs/montecarlo-full.md` and
`docs/montecarlo-reader.md` — where they additionally decide which `jldoctest` blocks
exist per page (the docs build runs exactly the tests the marks kept).

**How hide and the metadata travel (the transformation principle).** A verdict-HIDDEN
line is never visible when a notebook is viewed, and it is never lost: in markdown
cells it rides a wrapper-only HTML comment (`<!-- <original line> -->`, invisible in
every rendered view, present in the file); in code cells it rides the cell's `gometa`
metadata (`{"v": 1, "carried": [{"i": <position>, "text": "<original line>"}]}` —
re-interleaving `carried` into the shown lines restores the original block). The
source's `#~` metaLines travel the same two ways — a meta run contiguous with its
block rides that cell, a detached run becomes its own invisible carrier cell — so the
GoMeta data can be read and worked with in the notebook as in the source, and the
derivation is a format transformation, not a projection. A fully hidden code cell
becomes an invisible markdown carrier cell with `"gometa": {"kind": "code"}`. Comment
payloads containing `--` ride a reversible escape (`\` doubles, then a `\` lands
between every dash pair; unescape reverses). Hidden lines do NOT execute in notebooks
(carriers don't run — code a source so shown code never depends on hidden
definitions). An INVISIBLE cell is not a policy surface: it takes no edition tags, so
papermill's singular `parameters` anchor falls to the first VISIBLE parameters cell;
in the student edition invisible cells are locked like every instruction cell, and an
invisible SOLUTION cell is omitted from the worksheet entirely. A DISCARDED line
travels nowhere — discard is the removing form, hide the visibility form. The two derived manual pages are VIEWS: hidden lines are simply
not on them (except the lines of EXECUTED blocks — `# hide`-marked `@example` lines
and whole `@setup` bodies — which Documenter runs and display-hides on the built page
while they remain present in the raw page markdown), and metaLines do not ride them.

**Honesty notes.**
- In real use the marked `.jl` source stays private and only derived views are shared.
  Here BOTH halves ship so you can diff source against views yourself — the "private"
  block in each source is a synthetic sentinel demonstrating the mechanism, and it is
  absent from every derived artifact (verify: `grep -c stratified *.ipynb` prints `0`
  for each).
- The label legend (which of the five generic labels means parameters, solution,
  private, …) is per-file DATA, declared in each source's header and in the generator's
  registry — two files may bind the same label differently. A dedicated, named Alterant
  vocabulary is the planned replacement; when it lands, regeneration from migrated
  sources must reproduce these artifacts up to the documented normalization: cell ids
  hash each EMITTED cell's content plus its ordinal, and verdict digests hash the
  serialized evaluations — both therefore shift whenever the annotation syntax shifts,
  so they are EXCLUDED from the migration comparison; semantic cell content, metadata,
  and structure must match exactly.
- Slide dispositions come from the source's depth marks, scraped textually — depth is
  not on the evaluated-values surface at this release.
- Automated execution targets the `julia-1.12` kernelspec by name; with a newer Julia
  kernel installed, pass your kernel's name explicitly (e.g.
  `--ExecutePreprocessor.kernel_name=julia-1.x`).
