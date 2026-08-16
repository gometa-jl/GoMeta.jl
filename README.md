<div align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/assets/logo-dark.svg">
  <img src="docs/assets/logo.svg" alt="GoMeta" width="320">
</picture>
</div>

# GoMeta.jl

**Embed formalized meaning into comments.**

The core idea of GoMeta is to embed formalized meaning within all kinds of comments and
provide Extensions with its interpretations so they can act on them.

So on the one hand, GoMeta is a domain specific language for metadata and on the other a
framework with facilities which Extensions can build on.

> [!WARNING]
> 🚧 First, **heavily Claude assisted** draft — brand-new for JuliaCon 2026.
>
> Will be updated gradually. For now, check out the **JuliaCon slides [here](https://gometa.dev/talk/)**.

**Interpretable metadata for source files.** GoMeta makes accumulated files **retrievable,
interlinkable, re-renderable, and shareable-with-control** through `#~` **metaLines** — ordinary
comment lines that carry machine-interpretable metadata (labels, visibility actions, conditions)
beside the content they describe. GoMeta **evaluates** metadata; **it never executes the file** it
processes — conditions run in GoMeta's own closed interpreter, never through Julia's `eval`
(the one deliberate exception is an explicitly opt-in extension mode — see SECURITY below).

```julia
# An ordinary Julia file — with GoMeta metaLines in its comments:
#~ hide{ :label4 , isCode }   ## hide everything in scope that is code or carries :label4
x = 1                          # ...content...
```

> **License notice.** GoMeta is **Fair Source** — licensed under the Functional Source
> License, Version 1.1, MIT Future License (**FSL-1.1-MIT**; source-available, not
> OSI-approved open source): free for everyone's own use — at work, at university, in the
> public sector — including internal use and access, non-commercial education and research,
> and professional services provided to other licensees. Not licensed: offering GoMeta to
> others in a commercial product or service that competes with it or with the Licensor's
> own GoMeta-based offerings. Each release automatically becomes
> MIT-licensed open source on its second anniversary. Details: [License](#license) below and
> the [LICENSE](LICENSE) file.

## Status: alpha

`0.3.0` (alpha maturity) — a working, tested engine for the **v0 subset** of the GoMeta
language. The closed no-eval condition interpreter landed at `0.2.0`; `0.2.1` added the
token-delimiter law (every marker token requires whitespace-or-line-boundary on BOTH
sides of its head — an undelimited shape is plain content, never special, never refused)
with Unicode horizontal whitespace as the delimiter class; `0.2.2` makes the condition
scanner Unicode-correct — a multibyte-final atom flush against the closing brace takes
its ordinary vocabulary fate (flush ≡ spaced), and a multibyte final character survives
the verdict store whole; `0.2.3` converts the structural-directive adjacency crash class
(a `#-`/`#+`/`#[`/`#>`-form — including ordinary `#----` dividers and `#->` arrows —
directly adjacent to metadata) into stable, early refusals at both grains (the line-grain
message names the escapes); `0.3.0` arms **three content flavors** (`:julia` the default,
`:c` for the `//` line-comment family, `:latex` for `%` — selected explicitly via
`GoMetaConfig(flavor_tag = …)`, never inferred, with a fail-closed `ERR_UNKNOWN_FLAVOR`
refusal), makes the hide render **idempotent** (the ensure-token write:
`render ∘ ingest ∘ render == render` — see the canonical-output reference, rule 6), and
extends the label whitelist by a fixed **pictograph vocabulary** (byte-exact names like
`:💡`, `:📝`, `:🔥`).

**What works today** (the feature list below is test-pinned in this repository):

- **The `#~` metaLine language:** labels + conditional labels; the Visib actions `show` / `hide`
  / `discard` (incl. hide-aware rendering); section-title metaLines (`#~2 "Title"` → evaluated
  `head` entries; no render effect); `{}` condition expressions with `,`(OR) / `&&` / `!`
  / `()` grouping; nested metadata regions (depth + attachment scoping; author depths 1–8 at
  v0); the inert `#~!` form; inline `#~` on content lines; the `#]` close-marker; UTF-8-correct
  segment handling; CRLF→LF normalization.
- **The pipeline:** `goMeta` → `altValues_evals` / `GoMeta.outputs` — pure and deterministic for the
  engine's own operations (see SECURITY), with a byte-exact oracle: the 7 committed example pairs
  under `examples/` render **byte-identically**,
  pinned by the shipped **1140-test suite at this release** (the golden byte-oracle and
  unit layers, including the dual-mode, refusal-witness, token-delimiter-law,
  whitespace-alphabet, Unicode-correctness, and directive-adjacency families — green
  under a plain `Pkg.test()`).
- **Robustness:** no raw crash on the witnessed metaLine ACTION surface — extreme or
  malformed input gets a **stable, documented refusal** (slot capacity, malformed metaLines —
  including stray punctuation at the action position and tokens glued to a closing `)`/`}` —,
  unknown action, an out-of-whitelist label name in both the label-setting and the
  condition-query roles — where the condition is actually evaluated, `docs/public-api.md` §3.4 —,
  malformed action arguments, over-long conditions), catalogued in
  `docs/public-api.md` §3.
  The documented exceptions — an apply-path crash edge (a flagless-Visib write-back) and the
  guarded `#~9` depth refusal — are likewise catalogued honestly in `docs/public-api.md`
  §3.1/§3.2/§3.4 (the condition path itself is typed since the closed-interpreter flip).

**The language grows by design; the v0 subset forecloses none of it.** `using()` is a reserved
name.

## Install

```julia
using Pkg
Pkg.add(url = "https://github.com/gometa-jl/GoMeta.jl")   # GitHub-only at this release
```

Requires Julia **1.12** (or newer 1.x). The core has exactly two dependencies (StaticArrays +
InlineStrings, exact-pinned) — install into a **fresh environment** (`Pkg.activate` a new
directory, or `] activate --temp`) so the exact pins cannot conflict with versions already
resolved in an existing environment. `Pkg.add` gives you the package; to also run the committed
examples and the corpus driver below, **clone the repository** — the quickstart and the driver
read `examples/` by paths relative to the repository root, so run them from a checkout (an
installed copy also contains `examples/`, but buried in the package store).

## Quickstart

Clone the repository first — the quickstart and the corpus driver read the committed `examples/`
corpus relative to the repository root. Then process one committed example end-to-end:

```julia
import GoMeta

bytes  = read("examples/InFileFolder/file_for_Example_Proposal_JuliaCon.jl")
result = GoMeta.goMeta(bytes)             # parse → absorb → evaluate → apply → emit
result.status == GoMeta.PROCESS_OK || error("processing failed")   # typed status check
out    = GoMeta.outputs(result)           # (blsStructure_bytes, render_bytes)
print(String(copy(out.render_bytes)))     # the rendered share-view of the file

evals = GoMeta.altValues_evals(result)    # the evaluated Alterant values, per piece of the file
                                          # (`evals` = evaluated metadata values — unrelated
                                          #  to Julia's `eval`)
evals[1]                                  # (cell_handle, attr, value, polarity), e.g. (…, :label_label1, true, true)
```

(`blsStructure_bytes` is the render's structural twin — the parsed Block/Line/Segment tree serialized
deterministically; `docs/CANONICAL-OUTPUT.md` names both halves in §1 and defines them in §2
[tree] and §3 [render rules]. `altValues_evals` is the
queryable per-cell surface of evaluated Alterant values — `docs/public-api.md` §2.)

What the render does: the line marked `#~ discard` is **removed**, and the code line (which
inherits `hide{ … isCode }` from the file's first metaLine) is **commented out** with the `## `
hide marker. Input, lines 5–10 verbatim:

```julia
# This `Line` of text starts a new `Block` of text.
# This `Block` is NOT attached to metadata - it does NOT INHERIT metadata.
# However, this `Line` will get discarded due to: #~ discard

#~2 :label5 show{ !:label5} ## This is line 9. It is a one-line meta `Block`.
using Plots ## This `Line` starts a new `Block` of code.
```

The committed rendered output for the same region (the discarded line is gone; the code line is
hidden):

```julia
# This `Line` of text starts a new `Block` of text.
# This `Block` is NOT attached to metadata - it does NOT INHERIT metadata.

#~2 :label5 show{ !:label5} ## This is line 9. It is a one-line meta `Block`.
## using Plots ## This `Line` starts a new `Block` of code.
```

The full pair is committed at `examples/InFileFolder/file_for_Example_Proposal_JuliaCon.jl` →
`examples/OutFileFolder/file_for_Example_Proposal_JuliaCon.jl` — the same bytes the golden suite
pins, so the docs cannot drift from the engine. Run **all seven** examples and verify each render
byte-for-byte against the committed references:

```
julia --startup-file=no --project=. -e 'using Pkg; Pkg.instantiate()'   # once, resolves the package env
julia --startup-file=no --project=. run_examples.jl
```

A small query demo ships beside the driver — "find it again" over the same committed corpus:

```
julia --startup-file=no --project=. find_by_label.jl            # per-label overview
julia --startup-file=no --project=. find_by_label.jl label5     # which cells carry :label5, and
                                                                # each cell's evaluated visibility verdict
```

## SECURITY

GoMeta's condition expressions are parsed and evaluated by **GoMeta's own closed, bounded
interpreter** — a restricted grammar over label and state queries. **No condition text ever
reaches Julia's `eval` in a default-configured run**: this holds BY CONSTRUCTION (the shipped
`src/` contains no code evaluation — conditions parse to data the engine walks itself), the
shipped test suite carries a behavioral sentinel that would flip if any condition text were
ever evaluated, and the development repository additionally pins the law with static no-eval
gates. Condition text cannot execute code, read files, or have side effects. (Two caveats
remain: metaLine names intern as Julia `Symbol`s, which persist for the session — the symbol
table only grows as new names arrive, so a long session over many untrusted files accretes
entries; and the separate opt-in modes below.)

**The opt-in exception:** the `extensions/condition_modes_opt_in.jl` extension registers the
`:jl_share_v1_full_eval` profile, in which condition text beyond the safe grammar **is**
host-evaluated. Activation takes **two explicit operator acts** — `include`-ing that file AND
naming the profile in your config; neither act alone evaluates anything, neither is reachable
from document content, and no dependency can perform them for you (`src/` never includes the
file). With the mode active, **processing a file you did not write can execute arbitrary
code**, so use it only on input you trust. A default-configured run cannot reach this path:
naming the profile without the included extension refuses loudly with a stable message —
never a silent fallback.

Documented v0 limits (each refuses with a stable message rather than crashing): at most 7 actions
per meta-hierarchy slot; malformed metaLines are refused — including stray punctuation at the
action position and tokens glued to a closing `)`/`}`; malformed
action arguments are refused; label names are validated against the engine's closed whitelist in
BOTH roles — applying a label and querying one in a condition each refuse an out-of-whitelist
name (a condition-side label after an already-winning true atom in a `,`/`||` chain is not
queried, and in a region that carries no labels at all the query is never consulted — it simply
evaluates false). The corpus-documented labels are
`:label1`..`:label5`; since `0.3.0` the closed whitelist also accepts the fixed pictograph
vocabulary (byte-exact names — the refusal message lists the full accepted set). The full
catalogue: `docs/public-api.md` §3.

## Documentation

Three references, in reading order:

1. [`docs/SYNTAX-AND-SEMANTICS.md`](docs/SYNTAX-AND-SEMANTICS.md) — the language: every rule
   cites a runnable committed example.
2. [`docs/public-api.md`](docs/public-api.md) — the API: four exported names (plus eleven
   qualified-public names, reached as `GoMeta.*`), the error-mode catalogue, the refusal strings.
3. [`docs/CANONICAL-OUTPUT.md`](docs/CANONICAL-OUTPUT.md) — the two output halves
   (`blsStructure_bytes` + `render_bytes`) and the six render rules.

The docs site also carries a **derived manual** pair — two pages generated from ONE
marked Julia source file, where the `#~` marks choose the content AND which `jldoctest`
blocks each page carries (the docs build runs exactly the tests the marks kept). The
same pipeline derives the notebook family under [`notebooks/`](notebooks/README.md):
one source file, four notebook editions (full · student · report · slides), plus one
executed twin. Every GENERATED file regenerates byte-identically —
`julia --startup-file=no --project=. notebooks_from_source.jl --check` — while the
executed twin carries real kernel outputs and is validated separately, outside that
byte gate.

## The language: the v0 subset

The corpus-verified reference for what ships is
[`docs/SYNTAX-AND-SEMANTICS.md`](docs/SYNTAX-AND-SEMANTICS.md) — every rule cites a runnable
committed example. The API reference is [`docs/public-api.md`](docs/public-api.md) (four exported
names; the error-mode catalogue). The v0 argument forms are documented in the syntax
reference §10 (the heading form: the API reference §2); its honest out-of-scope list is
§13. Section titles are metadata too:
`#~2 "Title"` records a `head_2` entry on the evaluated surface (headings never change the
render); the grammar
and its refusal family are in the API reference.

The language grows by design; the v0 subset forecloses none of it. `using()` is a **reserved**
name.

## License

GoMeta ships under the **Functional Source License, Version 1.1, MIT Future License**
(**FSL-1.1-MIT**) — see [LICENSE](LICENSE). The operative terms, plainly:

- **Permitted: any purpose except Competing Use** — use, copy, modify, create derivative
  works, and redistribute; expressly including **internal use and access** (companies,
  institutions, government), non-commercial education, non-commercial research, and
  professional services provided to another licensee (License Grant + Permitted Purpose).
- **Not licensed (Competing Use):** making GoMeta available to others in a commercial
  product or service that substitutes for GoMeta, substitutes for any product or service
  the Licensor offers using GoMeta, or offers the same or substantially similar
  functionality. For such offerings, contact the Licensor for a separate license:
  hello@gometa.dev.
- **Each release opens automatically:** on the second anniversary of a version's release,
  that version becomes available under the **MIT license** — irrevocably (Grant of Future
  License).
- **Redistribution** keeps these terms and the copyright notices attached; **trademarks**
  are not licensed beyond displaying the license details and identifying the Software's
  origin. FSL-1.1-MIT is **not an OSI-approved license** (each release's aged
  MIT grant is).

At this release GoMeta is distributed via GitHub only (no General-registry install).

## JuliaCon 2026

GoMeta is presented at **JuliaCon 2026** — talk: *"#~ This is a metaline announcing the release
of `GoMeta`"*, 2026-08-14.

## Versioning + compatibility

The alpha status states the maturity honestly: the surface may still move before `1.0`. The
evolution intent is **additive-only** — an existing exported name is never silently removed or
repurposed; a breaking change means a deprecation under full re-validation
(`docs/public-api.md` §6). Compatibility: Julia **1.12**; core dependencies **StaticArrays** +
**InlineStrings** (exact-pinned).
