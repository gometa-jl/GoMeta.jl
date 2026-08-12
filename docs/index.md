# GoMeta

**Interpretable metadata for source files.** GoMeta makes accumulated files retrievable,
interlinkable, re-renderable, and shareable-with-control through `#~` **metaLines** — ordinary
comment lines that carry machine-interpretable metadata (labels, visibility actions, conditions)
beside the content they describe. GoMeta **evaluates** metadata; **it never executes the file**
it processes (with one honest v0 exception at the condition seam — see Security below).

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
2. [Public API + error modes](public-api.md) — the API: four exported names (plus eleven
   qualified-public names, reached as `GoMeta.*`), the error-mode catalogue, the refusal
   strings.
3. [Canonical output](CANONICAL-OUTPUT.md) — the two output halves (`blsStructure_bytes` +
   `render_bytes`) and the six render rules.

## Install

```julia
using Pkg
Pkg.add(url = "https://github.com/gometa-jl/GoMeta.jl")   # GitHub-only at this release
```

Requires Julia **1.12** (or newer 1.x). Install into a **fresh environment** — the two core
dependencies (StaticArrays + InlineStrings) are exact-pinned. The quickstart and the committed
example corpus live in the repository: clone it and start from the README's Quickstart section.

## Security

GoMeta's condition expressions run in **GoMeta's own closed, bounded interpreter** — no
condition text reaches Julia's `eval` in a default-configured run, so conditions cannot execute
code, read files, or have side effects. The one deliberate exception is the explicitly opt-in
`:full_eval_v1` extension mode (host evaluation; only process trusted input with it loaded).
The full statement, with the documented limits, is in the README's SECURITY section and the
error-mode catalogue ([Public API + error modes](public-api.md) §3).

## Status

`0.3.0` (alpha maturity) — a working, tested engine for the **v0 subset** of the GoMeta language, with a
byte-exact oracle: the seven committed example pairs under `examples/` render byte-identically,
pinned by the shipped test suite under a plain `Pkg.test()`. The language grows by design; the
v0 subset forecloses none of it.
