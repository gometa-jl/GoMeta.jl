# Changelog

The version history of GoMeta.jl, newest first — what each release brought. Every removal,
rename or addition of a public name is written, with its ground, its replacement and what an older caller
sees, in the breaking-change register of the API reference, [`docs/public-api.md`](docs/public-api.md) §6.
**No backward compatibility and no deprecation until at least v0.7**: every change of the public surface is
a clean cut. A date is the day of the version's tag (since 0.3.0) or, before 0.3.0, of the day the version reached `main` (those versions carry no tag).

## 0.4.2 — unreleased

- **The Labels Alterant's vocabulary statements.** A file at `#~0` or the user's profile adds names to the Labels
  Alterant's vocabulary for the run and removes names from it: `:++x` / `:(++, x, y)` add, `:--x` / `:(--, x)` remove. A
  vocabulary statement is consumed at the read — no label applied, no row; it holds from its own metaBlock onward; the place is
  checked first (`#~0` or the profile, nothing else), then the malformed shapes are refused. The shipped list (39 names) is the
  base behind `base_vocabulary()`; a run's additions and removals are kept apart from it, the effective set the base plus the
  additions minus the removals. The unknown-label refusal reads "not in the Labels Alterant's vocabulary", the printed set the
  run's. The user level's vocabulary statements are read first and a file's later statement wins for the same name.
- **The registration record's ninth field.** `Alterant.onRead`, the read-time hook, `nothing` by default and for every other
  shipped Alterant; `ProcessState.alt_run` holds an Alterant's per-run state; the instance constructor is given that state where
  the hook minted one (`altConstructor(run)`), called bare otherwise. `LabelsInstance` is the Labels Alterant's instance type: the
  applied labels and the run's vocabulary. The register's row: "The Labels Alterant's VOCABULARY STATEMENTS".

## 0.4.1 — 2026-10-20

- **One behaviour under a fed user profile changed** (`GoMetaConfig(user_mh_profile = …)`, experimental): a
  Component's own metadata applies in written order, as without a profile — a condition no longer sees a label
  stated after it. The profile's labels are collected first, as the outermost level; its other statements are
  evaluated after the Component's own, and an applicable profile value overrides the value the Component's own
  metadata decided. Without a profile nothing changed. The register's row: "The user level's place in the apply
  loop".

## 0.4.0 — 2026-10-18

- **A `{…}` condition is Julia.** GoMeta rewrites its own parts of the body to Julia text, Julia's parser
  reads the result once, and Julia evaluates the stored expression when the statement is applied. The closed
  no-eval condition interpreter of 0.2.0–0.3.x, its opt-in condition modes and the grammar profile were
  removed; a body Julia cannot parse is Julia's own parse error. See the README's SECURITY section.
- **The delivered object.** `GoMetaResult` renamed `GoMetaDelivery` and re-shaped: four parts, read by name
  — `blsComponentTree`, `altValues_evals`, `status`, `diagnostics`; the working state is no longer delivered.
  The function `altValues_evals` renamed `readAltValuesEvals`: the name `altValues_evals` belongs to the data
  container. `EvalRecord.decided_by` added — the handles of the statements that produced a row, in application
  order. `EvalRecord.content`, `GoMeta.content_fingerprint` and the five-column
  `serialize_evals(::GoMetaDelivery)` removed; the four-column form's `attr` column encoded.
- **The BLS module.** `GoMeta.BLS` is public: an Extension travels the BLS Component tree with `children`,
  `parent`, `root`, `kind`, `content`, `flavor`, `getElement`, `isHorizontalSpace`, `endsWithNewline`, and the
  Component types `File`, `Block`, `Line`, `Segment` (with `ComponentSettribute` and `CmpntNamedInt`).
- **The answers.** `evaluatedAltValue` / `EvaluatedAltValue`, `evaluatedAltValues`, `scanAlterant` and
  `childDiffers` added (package-public): the Engine's answer for one Component and one Alterant — the value and
  its source (`:own`, `:indirect` through a named Component, `:user`, `:default`, …) — and the views over it. A
  Line decided by its own trailing metaSegment answers `:own`, its Segments `:indirect` through the Line; a
  whole-line heading is keyed on its metaBlock and an inline heading on its Line (0.3.2: the metaLine's Line and
  the Segment); a metaLine split by a trailing `##` comment records its metaBlock as the deciding statement.
- **The basic renderer is a development tool.** `GoMeta.outputs` removed; the renderer is loaded through
  `devtools/load_basic_renderer.jl`. The Visib write-back into the BLS Components and the three Visib
  declarations removed.
- **Alterants.** The registration surface is public: `RegistryBuilder`, `register!`, `validate`, `publish`,
  `next_plugin_index` and `RegistrationRefused`, with the record types `Alterant` and `ActionSpec` (keyword
  forms), `CaptureDecl` and `DefaultSlot` / `NoDefault` / `Declared`; `RegistryBuilder(DEFAULT_REGISTRY)`
  extends the shipped inventory, and `goMeta` accepts a published registry only. Each Alterant declares one
  default, `Alterant.default` — Visib `:show`, Labels the empty set, Heading `nothing`, Id the zero compound.
  The Heading is an Alterant like any other and goes through the apply loop (its separate delivery removed).
  The Labels vocabulary — `:label1`..`:label5`, the pictographs and, new, `:doc` — is hard-coded in the Labels
  Alterant's own file, `src/alterants-std/labels.jl`; a queried unknown label answers false. The Id Alterant's
  `ids(c, p, f)` action added; the slot capacity is a named constant, `SLOT_CAPACITY = 8` actions per
  meta-hierarchy slot, decoupled from the registered action count.
- **The grammar made explicit.** A metaStatement is a head — a name, a `:` label or the region's first quoted
  heading — then at most one `()`, then at most one `{}`, and ends at white space; any other character meets
  the one refusal `GoMeta absorb: unexpected character …`; a ninth action in a slot meets "more than 8 actions
  in one meta-hierarchy slot". The four guarded refusals added to the metaLine parser at 0.2–0.3 — the punctuation wall, the glued-token wall, the no-token guard and the slot-capacity guard — were removed (the refusals of 0.2.3 and 0.3.1 above stand); the
  `ERR_UNKNOWN_FLAVOR` refusal replaced by a stable error message; `GoMetaConfig.profile` removed with the grammar profile, and a `parse_range` taken plain — its `last` the parse end line (the `ERR_RANGE_INVALID` refusal removed); malformed action arguments are Julia's own
  error out of the `goMeta` call.
- **Generated editions.** The notebook's student, report and slides editions removed: one notebook plus its
  executed twin, and the two derived manual pages, from one marked source file.

## 0.3.2 — 2026-08-21

- Marker docstrings: `?GoMeta` and `?goMeta` answer at the REPL. The syntax reference states the full meta
  hierarchy — the ladder from the user level through `#~0` (the file level) and `#~` (= `#~1`) to `#~8`.

## 0.3.1 — 2026-08-20

- The inert trailing-bang form `#~N!` pinned: `#~N! <content>` ≡ `#~N` — structurally live, its content not
  processed; an inert line does not end a contiguous meta run. Three stable refusals added: the transposed
  marker `#~!N` (the known mistake for `#~N!`), the empty label list (`#~ :`, `#~ :()`) and the empty label
  query (`{ :() }`), each of which had passed silently before.

## 0.3.0 — 2026-08-12

- Three content flavors: `:julia` (the default), `:c` for the `//` line-comment family, `:latex` for `%` —
  selected explicitly via `GoMetaConfig(flavor_tag = …)`, never inferred.
- The hide render is idempotent: `render ∘ ingest ∘ render == render`.
- The label whitelist extended by the fixed pictograph vocabulary (`:💡`, `:📝`, `:🔥`, …).

## 0.2.3 — 2026-08-09

- A structural directive adjacent to metadata — a `#-` / `#+` / `#[` / `#>` form, including `#----` dividers
  and `#->` arrows — meets a stable, early refusal at both grains instead of a crash.

## 0.2.2 — 2026-08-08

- Unicode-correct condition reading: a multibyte final character survives whole, and an atom flush against
  the closing brace takes its ordinary fate.

## 0.2.1 — 2026-08-08

- The token-delimiter law: every marker token requires whitespace or a line boundary on both sides of its
  head; an undelimited shape is plain content — never special, never refused. Unicode horizontal whitespace is
  the delimiter class.

## 0.2.0 — 2026-08-04

- The closed no-eval condition interpreter (removed at 0.4.0: a condition is Julia).

## 0.1.0-alpha — 2026-07-30

- The initial public alpha.
