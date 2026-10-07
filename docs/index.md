# GoMeta

**Interpretable metadata for source files.** GoMeta makes accumulated files retrievable,
interlinkable, re-renderable, and shareable-with-control through `#~` **metaLines** — ordinary
comment lines that carry machine-interpretable metadata (labels, visibility actions, conditions)
beside the content they describe. GoMeta **evaluates** metadata; **it never executes the file**
it processes — the actions its evaluation calls for are carried out by the renderer or an Extension (a `{…}`
condition is Julia, evaluated by Julia — see Security below).

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
> MIT-licensed open source on its second anniversary. Details: the `LICENSE` file at the
> repository root, summarized in the README's License section.

## The three references

In reading order:

1. [Syntax & semantics](SYNTAX-AND-SEMANTICS.md) — the language: every rule cites a runnable
   committed example.
2. [Public API + error modes](public-api.md) — the API: four exported names (plus thirty-nine
   qualified-public names, reached as `GoMeta.*`), the error-mode catalogue, the refusal
   strings.
3. [Canonical output](CANONICAL-OUTPUT.md) — the package's canonical observable output (`altValues_evals`)
   and the development tool's (tree, render) pair with its six render rules.

## Install

```julia
using Pkg
Pkg.add(url = "https://github.com/gometa-jl/GoMeta.jl")   # GitHub-only at this release
```

Requires Julia **1.12** (or newer 1.x). Install into a **fresh environment** — the one core
dependency (StaticArrays) is exact-pinned. The quickstart and the committed
example corpus live in the repository: clone it and start from the README's Quickstart section.

## Security

A `{…}` condition is **Julia** since `0.4.0`: its GoMeta-specific parts are re-written to Julia text at absorb, Julia's
parser reads the body once, and Julia evaluates it at apply — the owner's design, as the original engine did. A condition
body can therefore execute code, read files or have effects: process input you trust, as you would any Julia file you
`include`. The full statement, with the documented limits, is in the README's SECURITY section and the
error-mode catalogue ([Public API + error modes](public-api.md) §3).

## Status

`0.3.0` (alpha maturity) — a working, tested engine for the **v0 subset** of the GoMeta language, with a
byte-exact oracle: the seven committed example pairs under `examples/` render byte-identically,
pinned by the shipped test suite under a plain `Pkg.test()`. The language grows by design; the
v0 subset forecloses none of it.
