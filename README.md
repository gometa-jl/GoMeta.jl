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
processes — the actions its evaluation calls for are carried out by the renderer or an Extension. A `{…}`
condition is Julia: read by Julia's parser, evaluated by Julia (since `0.4.0` — see SECURITY below).

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

`0.4.1` (alpha maturity) — a working, tested engine for the **v0 subset** of the GoMeta
language. `0.2.0` brought a closed no-eval condition interpreter (REMOVED at `0.4.0` —
a condition is read by Julia's parser and evaluated by Julia, as the original engine did; `docs/public-api.md` §3.2); `0.2.1` added the
token-delimiter law (every marker token requires whitespace-or-line-boundary on BOTH
sides of its head — an undelimited shape is plain content, never special, never refused)
with Unicode horizontal whitespace as the delimiter class; `0.2.2` made the condition
reading Unicode-correct — a multibyte-final atom flush against the closing brace takes
its ordinary vocabulary fate (flush ≡ spaced; the law holds in `0.4.0`'s char walk), and a multibyte final character survives
the verdict store whole; `0.2.3` converts the structural-directive adjacency crash class
(a `#-`/`#+`/`#[`/`#>`-form — including ordinary `#----` dividers and `#->` arrows —
directly adjacent to metadata) into stable, early refusals at both grains (the line-grain
message names the escapes); `0.3.0` arms **three content flavors** (`:julia` the default,
`:c` for the `//` line-comment family, `:latex` for `%` — selected explicitly via
`GoMetaConfig(flavor_tag = …)`, never inferred, with a fail-closed `ERR_UNKNOWN_FLAVOR` refusal — that coded refusal was removed at `0.4.0`:
an unknown tag throws a stable error message instead), makes the hide render **idempotent** (the ensure-token write:
`render ∘ ingest ∘ render == render` — see the canonical-output reference, rule 6), and
extends the label whitelist by a fixed **pictograph vocabulary** (byte-exact names like
`:💡`, `:📝`, `:🔥`); since `0.4.0` the whole list — those names, `:label1`..`:label5` and `:doc` — is
hard-coded in the Labels Alterant's own file (`src/alterants-std/labels.jl`), where a further name is one line.
`0.4.1` changes one behaviour under a fed profile (`GoMetaConfig.user_mh_profile`): the Component's own slot applies in
written order with or without a feed, and the user level's other statements are evaluated after it, with priority
(`docs/public-api.md` §6, its last row).

**What works today** (the feature list below is test-pinned in this repository):

- **The `#~` metaLine language:** labels + conditional labels; the Visib actions `show` / `hide`
  / `discard` (incl. hide-aware rendering); section-title metaLines (`#~2 "Title"` → evaluated
  `head` entries; no render effect); `{}` condition expressions with `,`(OR) / `&&` / `!`
  / `()` grouping — and, since `0.4.0`, any Julia Boolean expression over the GoMeta names (Julia's parser reads
  the body; `docs/public-api.md` §3.2); nested metadata regions (depth + attachment scoping; author depths 1–8 at
  v0); the inert `#~!` form; inline `#~` on content lines; the `#]` close-marker; UTF-8-correct
  segment handling; CRLF→LF normalization.
- **The pipeline:** the input file → BLS parses it into the BLS Component tree → the GoMeta Engine evaluates the
  altValues over it (`altValues_evals`) → the Extensions use both MAIN PRODUCTS; ONE run, `goMeta`, delivers
  both in `GoMetaDelivery` (the (tree, render) pair is a development tool's, `devtools/basic_renderer.jl`) — pure and deterministic for the
  engine's own operations (see SECURITY), with a byte-exact oracle: the 7 committed example pairs
  under `examples/` render **byte-identically**,
  pinned by the shipped test suite (the golden byte-oracle and
  unit layers, including the refusal-witness, token-delimiter-law,
  whitespace-alphabet, Unicode-correctness, directive-adjacency and condition-path families — green
  under a plain `Pkg.test()`).
- **Robustness:** the metaLine GRAMMAR surface refuses out-of-vocabulary input with **stable, documented refusals** —
  an unknown action, an unknown condition key — (a malformed metaLine meets the grammar's one refusal naming the character at fault —
  "GoMeta absorb: unexpected character '<c>' <where> …" — and a ninth action in one meta-hierarchy slot the stable "GoMeta absorb:
  more than 8 actions in one meta-hierarchy slot …", both since `0.4.0`; the four guarded refusals of v0.2–v0.3 were removed at
  `0.4.0`), and the Labels Alterant's own
  unknown-label refusal (`GoMeta apply: unknown
  label …` on an applied out-of-whitelist name; a queried unknown label answers false since `0.4.0` —
  `docs/public-api.md` §3.4), catalogued in `docs/public-api.md` §3. Malformed action ARGUMENTS are Julia's own
  error out of the `goMeta` call since `0.4.0` (the apply seam's former guarded refusal was removed; the original engine
  called the setters directly).
  The documented exception — the guarded `#~9` depth refusal — is likewise catalogued honestly in `docs/public-api.md`
  §3.1/§3.2/§3.4 (a condition is Julia's since `0.4.0`: GoMeta's own refusals are the unknown condition key, the
  block that carries no condition expression and a `(` left open inside the body; a body
  Julia cannot parse is Julia's own parse error — §3.2). The former second exception — the apply-path crash
  edge, a flagless-Visib write-back — was removed with the write-back at `0.4.0`.

**The language grows by design; the v0 subset forecloses none of it.** `using()` is a reserved
name.

## Install

```julia
using Pkg
Pkg.add(url = "https://github.com/gometa-jl/GoMeta.jl")   # GitHub-only at this release
```

Requires Julia **1.12** (or newer 1.x). The core has exactly one registered dependency (StaticArrays,
exact-pinned; SHA is a standard library) — install into a **fresh environment** (`Pkg.activate` a new
directory, or `] activate --temp`) so the exact pin cannot conflict with a version already
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
result = GoMeta.goMeta(bytes)             # ONE run: BLS parses the file into the BLS Component tree; the GoMeta Engine evaluates
                                          # the altValues over it — ONE object delivered, `GoMetaDelivery`, carrying both MAIN PRODUCTS
result.status == GoMeta.PROCESS_OK || error("processing failed")   # the part `status` (typed), read by name

tree = result.blsComponentTree            # the part `blsComponentTree` (the object, not printed): the BLS Component tree the
                                          # run was evaluated over — provided by BLS itself; it reaches an Extension as the
                                          # part `blsComponentTree`, not through any function of the GoMeta Engine; an
                                          # Extension travels it with BLS's own public functions — THE DOOR (`docs/public-api.md` §1.2):
for block in GoMeta.BLS.children(tree)                      # the File's Blocks, in source order …
    for line in GoMeta.BLS.children(tree, block)            # … a Block's Lines (a Line's Segments the same way)
        GoMeta.BLS.kind(line) === :Meta || continue         # the Component's flavor: :Meta / :Code / :Text — a metaLine is a Line of flavor Meta
        println(String(GoMeta.BLS.content(tree, line)))     # the verbatim text of the piece, from the tree and nothing else
    end
end
evals = GoMeta.readAltValuesEvals(result.altValues_evals)    # the part `altValues_evals`: the evaluated Alterant values, per piece
                                          # of the file, read through the Engine's reader (`evals` = evaluated metadata
                                          # values — unrelated to Julia's `eval`)
evals[1]                                  # (cell_handle, attr, value, polarity), e.g. (…, :label_label1, true, true)
result.diagnostics                        # the part `diagnostics`: the run's coded diagnostics (a non-OK status ⇒ non-empty)

include(joinpath(pkgdir(GoMeta), "devtools", "load_basic_renderer.jl"))   # the basic renderer — a DEVELOPMENT TOOL, not part of
                                          # the Engine's output — loaded through its ONE path, at the top level
out    = Main.BasicRenderer.outputs(result)  # the tool's (blsStructure_bytes, render_bytes) pair
print(String(copy(out.render_bytes)))     # the rendered share-view of the file — the way to inspect a run by eye
```

(`blsStructure_bytes` is the render's structural twin — the parsed Block/Line/Segment tree serialized
deterministically; `docs/CANONICAL-OUTPUT.md` names both halves in §1 and defines them in §2
[tree] and §3 [render rules]. `altValues_evals` is the
queryable surface of evaluated Alterant values, keyed by (handle, attr) — `docs/public-api.md` §2.)

What the render shows — the Alterant Visib as the example; the principle holds for every Alterant: if an
altValue of an Alterant applies to a Block, it applies indirectly to the Block's children. The line marked
`#~ discard` is **removed**, and the code line — a child of the Code Block to which the `hide{ … isCode }`
stated on the file's first metaLine applies, hence hidden indirectly, through that Block — is **commented out**
with the `## ` hide marker. Input, lines 5–10 verbatim:

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
julia --startup-file=no --project=. devtools/run_examples.jl
```

A small query demo ships under `extensions/` — "find it again" over the same committed corpus (an Extension of GoMeta, not the Engine):

```
julia --startup-file=no --project=. extensions/find_by_label.jl            # per-label overview
julia --startup-file=no --project=. extensions/find_by_label.jl label5     # which cells carry :label5, and
                                                                # each cell's evaluated visibility verdict
```

## SECURITY

A `{…}` condition is **Julia** — since `0.4.0`, by the decision of GoMeta's creator, as the
original engine read it: at absorb the body's GoMeta-specific parts are re-written to Julia text (a settribute key to its
state read, a queryable Alterant action or a label test to its query call, GoMeta's `,` (OR) to `||`; the rest verbatim),
Julia's parser reads the result once, and Julia evaluates the stored expression at apply in GoMeta's module. This is the
creator's design: a full parser must be available to those who, for instance, work only with their own GoMeta statements, provided there is no security
risk. **Processing a file you did not write therefore runs its
conditions as Julia code** — a condition body can read files, take time or have effects, exactly as a custom Alterant's
callables can: use GoMeta on input you trust, as you would any Julia file you `include`. The Engine's own operations stay
pure and deterministic (`docs/public-api.md` §2). The vocabulary stays GoMeta's: a bare name inside `{}` must be a
settribute key or an action of an Alterant that answers queries, else the stable `GoMeta absorb: unknown condition key …`
refusal; a body Julia cannot parse is Julia's own `Meta.ParseError` (§3.2). One caveat remains: metaLine names intern
as Julia `Symbol`s, which persist for the Julia session — the symbol table only grows as new names arrive, so a long session
over many untrusted files accretes entries. (The closed no-eval interpreter of `0.2.0`–`0.3.x` and its opt-in modes were removed at
`0.4.0`; `docs/public-api.md` §6.)

Documented v0 limits: the queue tensor holds 8 actions per meta-hierarchy slot (`SLOT_CAPACITY` in `src/state.jl` — a named constant,
decoupled from the registered action count, 9 with the `ids` action) —
a further action meets the stable message "GoMeta absorb: more than 8 actions in one meta-hierarchy slot …";
a malformed metaLine meets the grammar's one refusal naming the character at fault — "GoMeta absorb: unexpected
character '<c>' <where> …" (a metaStatement is a name, a ':' label or the region's first
quoted heading, then at most one `()`, then at most one `{}`, and ends at white space; `docs/public-api.md` §3.4); malformed
action arguments are Julia's own error out of the `goMeta` call; label names are validated against the engine's closed whitelist when
APPLIED — an out-of-whitelist name refuses; a label QUERIED in a condition answers false when it is unknown
or unset (as the original engine answered; since `0.4.0`). The corpus-documented labels are
`:label1`..`:label5`; since `0.3.0` the closed whitelist also accepts the fixed pictograph
vocabulary (byte-exact names — the refusal message lists the full accepted set), and, since `0.4.0`,
`:doc` — the whole list hard-coded in the Labels Alterant's own file
`src/alterants-std/labels.jl`. The full catalogue: `docs/public-api.md` §3.

## Documentation

Three references, in reading order:

1. [`docs/SYNTAX-AND-SEMANTICS.md`](docs/SYNTAX-AND-SEMANTICS.md) — the language: every rule
   cites a runnable committed example.
2. [`docs/public-api.md`](docs/public-api.md) — the API: four exported names (plus twenty-seven
   qualified-public names, reached as `GoMeta.*`), the error-mode catalogue, the refusal strings.
3. [`docs/CANONICAL-OUTPUT.md`](docs/CANONICAL-OUTPUT.md) — the package's canonical observable output
   (`altValues_evals`) and the development tool's (tree, render) pair with its six render rules.

The docs site also carries a **derived manual** pair — two pages generated from ONE
marked Julia source file, where the `#~` marks choose the content AND which `jldoctest`
blocks each page carries (the docs build runs exactly the tests the marks kept). The
same pipeline derives the notebook under [`notebooks/`](notebooks/README.md): one
source file, one notebook (the full edition) plus one executed twin (the former student, report and
slides editions were removed at `0.4.0`). Every GENERATED file regenerates byte-identically —
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

The alpha status states the maturity honestly: the surface may still move. **No backward
compatibility and no deprecation until at least GoMeta v0.7** (the creator's
policy): every change of the public surface is a clean cut — the old name removed; no stub,
no alias, no leftover of an older version in a newer one — and every removal or rename is written
into the breaking-change register (`docs/public-api.md` §6) with its ground, its replacement and
what an older caller sees. The policy will change at a later stage — maybe v0.8, maybe later — by
the creator's decision. Compatibility: Julia **1.12**; the core dependency **StaticArrays**
(exact-pinned; SHA is a standard library).
