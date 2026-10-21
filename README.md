<div align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/assets/logo-dark.svg">
  <img src="docs/assets/logo.svg" alt="GoMeta" width="320">
</picture>
</div>

# GoMeta.jl

**Embed formalized meaning into comments.**

[![Docs](https://img.shields.io/badge/docs-gometa.dev-1f6feb)](https://gometa.dev/)
[![CI](https://github.com/gometa-jl/GoMeta.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/gometa-jl/GoMeta.jl/actions/workflows/CI.yml)
[![License: FSL-1.1-MIT](https://img.shields.io/badge/license-FSL--1.1--MIT-blue)](LICENSE)
[![Julia 1.12](https://img.shields.io/badge/julia-1.12-9558B2)](https://julialang.org/)

The core idea of GoMeta is to embed formalized meaning within all kinds of comments and
provide Extensions with its interpretations so they can act on them.

So on the one hand, GoMeta is a domain specific language for metadata and on the other a
framework with facilities which Extensions can build on.

```julia
# An ordinary Julia file — with GoMeta metaLines in its comments:
#~ hide{ :label4 , isCode }   ## hide everything in scope that is code or carries :label4
x = 1                          # ...content...
```

A `#~` line is a **metaLine**: an ordinary comment that carries machine-interpretable metadata —
labels, visibility actions, conditions — right beside the content it describes. The host file stays
an ordinary file of its format; the host language sees nothing but a comment. GoMeta **evaluates** the
metadata; the Extensions **act** on the evaluations. *GoMeta evaluates — Extensions act.*

## Learn more at [gometa.dev](https://gometa.dev/)

GoMeta's creator explains GoMeta by three questions. The website answers them, then takes you through
one complete run:

- [What is GoMeta?](https://gometa.dev/concepts/what-is-gometa) · [Why use GoMeta?](https://gometa.dev/concepts/why-use-gometa) · [How does GoMeta work?](https://gometa.dev/concepts/how-does-gometa-work)
- [Getting started](https://gometa.dev/tutorials/getting-started) — the install and one run, from the file to what the Extensions receive
- [Examples](https://gometa.dev/examples/) — the committed example files, each input beside its rendered output
- [Syntax & semantics](https://gometa.dev/reference/syntax-and-semantics) · [Public API](https://gometa.dev/reference/public-api) · [Development tools](https://gometa.dev/reference/development-tools)
- [The JuliaCon 2026 talk](https://gometa.dev/talk/) — the slides, web version

## Install

```julia
using Pkg
Pkg.add(url = "https://github.com/gometa-jl/GoMeta.jl")   # GitHub only; see Status
```

Requires Julia **1.12** (or newer 1.x). Install into a **fresh environment** (`] activate --temp`, or
`Pkg.activate` a new directory): the one core dependency, StaticArrays, is exact-pinned. To run the
committed examples, clone the repository — they are read by paths relative to its root.

## Quickstart

```julia
import GoMeta

bytes    = read("examples/InFileFolder/file_for_Example_Proposal_JuliaCon.jl")
delivery = GoMeta.goMeta(bytes)             # one run: BLS parses the file, the GoMeta Engine evaluates the metadata
delivery.status == GoMeta.PROCESS_OK || error("processing failed")

tree  = delivery.blsComponentTree           # the BLS Component tree — the file as BLS parsed it: Blocks, Lines, Segments
evals = GoMeta.readAltValuesEvals(delivery.altValues_evals)   # the evaluated Alterant values, one row per piece of the file
evals[1]                                    # (handle, attribute, value, polarity), e.g. (…, :visib, :discard, true)
```

One call delivers one object carrying both main products: the BLS Component tree and the evaluated
Alterant values, `altValues_evals`. Extensions read both and act. The walk through this run — the
tree's traversal, the rows' meaning, a first look through the basic renderer — is the website's
[Getting started](https://gometa.dev/tutorials/getting-started). From a checkout,
`julia --startup-file=no --project=. devtools/run_examples.jl` renders the seven committed example
pairs under `examples/` and verifies each byte for byte, and `extensions/find_by_label.jl` answers
which pieces of the corpus carry a label.

## SECURITY

A `{…}` condition is **Julia**: GoMeta rewrites its own parts of the body to Julia text, Julia's parser
reads it once, and Julia evaluates it when the statement is applied. **Processing a file you did not
write therefore runs its conditions as Julia code.** Use GoMeta on input you trust, as you would any
Julia file you `include`. The full statement and the documented limits: [`docs/public-api.md`](docs/public-api.md) §3.

## Status

`0.4.1`, **alpha**: a working, tested engine for the **v0 subset** of the GoMeta language. The seven
committed example pairs render byte for byte, pinned by the shipped test suite. The surface may still
move: **no backward compatibility and no deprecation until at least v0.7**, by the creator's policy —
every change of the public surface is a clean cut, written into the breaking-change register,
[`docs/public-api.md`](docs/public-api.md) §6. The version history: [CHANGELOG.md](CHANGELOG.md).
GoMeta is distributed through GitHub only: its license is not OSI-approved, which the General registry
requires. The language grows by design; the v0 subset forecloses none of it.

> [!NOTE]
> A first, **heavily Claude assisted** draft of the package and its documents, updated gradually.

## Documentation

The website is the reading version. The references in this repository, in reading order:

1. [`docs/SYNTAX-AND-SEMANTICS.md`](docs/SYNTAX-AND-SEMANTICS.md) — the language: every rule cites a runnable committed example.
2. [`docs/public-api.md`](docs/public-api.md) — the API: the exported and the public names, the error-mode catalogue, the refusal strings, the breaking-change register.
3. [`docs/CANONICAL-OUTPUT.md`](docs/CANONICAL-OUTPUT.md) — the canonical observable output, `altValues_evals`, and the development tool's (tree, render) pair with its six render rules.

The derived manual pair under `docs/` and the notebook under [`notebooks/`](notebooks/README.md) are
generated from ONE marked source file — the `#~` marks choose the content of each edition.
`julia --startup-file=no --project=. notebooks_from_source.jl --check` verifies every generated file byte for byte.

## License

GoMeta is **Fair Source**: the Functional Source License, Version 1.1, MIT Future License
(**FSL-1.1-MIT**; source-available, not OSI-approved open source). Free for everyone's own use — at work,
at university, in the public sector — including internal use and access, non-commercial education and
research, and professional services provided to other licensees. Not licensed: offering GoMeta to others
in a commercial product or service that competes with it or with the Licensor's own GoMeta-based
offerings; for that, contact hello@gometa.dev. Each release becomes **MIT-licensed** on its second
anniversary, irrevocably. The terms: [LICENSE](LICENSE).

## JuliaCon 2026

GoMeta was presented at **JuliaCon 2026** on 2026-08-14 — the talk *"#~ This is a metaline announcing
the release of `GoMeta`"*. The slides, web version: [gometa.dev/talk](https://gometa.dev/talk/).

## Questions

hello@gometa.dev, or an [issue](https://github.com/gometa-jl/GoMeta.jl/issues) in this repository.
