# Changelog

The version history of GoMeta.jl, newest first — what each release brought. Every removal,
rename or addition of a public name is written, with its ground, its replacement and what an older caller
sees, in the breaking-change register of the API reference, [`docs/public-api.md`](docs/public-api.md) §6.
**No backward compatibility and no deprecation until at least v0.7**: every change of the public surface is
a clean cut. A date is the day of the version's tag (since 0.3.0) or, before 0.3.0, of the day the version reached `main` (those versions carry no tag).

## 0.4.3 — unreleased

- **The Labels Alterant's withhold and explicit apply.** `:-x` / `:(-, x, y)` WITHHOLDS a label from the current set of labels applied
  to the current Component and to everything under its metaBlock until a later metaBlock of the same or a shallower depth replaces the
  slot; `:+x` / `:(+, x)` APPLIES it explicitly, after a withhold or not; within one metaBlock the written order decides. A plain `:x` met
  by a withhold applies nothing and the run completes `PROCESS_OK` with ONE `:warning` diagnostic for each such statement and name at each affected Component (a name a statement writes twice is reported twice)
  (`LABEL_NOT_APPLIED_WITHHELD`: the label, the Component, the statement and the Labels statements applied there so far in the row's
  context; the message names the ways out) — the user informed, the run proceeding, the file never rewritten for one run. A withheld
  label read by a condition answers false. The malformed shapes are refused at the apply: the prefixed sign with several names, a sign
  with no name, an empty member of a signed list, a name beginning with a sign — after a prefixed sign (`:+-x`) or inside a list, signed or plain (`:(x, -y)`, refused before
  as an unknown label, keeps its refusal with another message). The apply loop reads a setter's RETURN for one purpose: a
  `Vector{Diagnostic}` is delivered with the place merged into each row's context, the severity copied; anything else is ignored as before.
  The development tools print a run's diagnostics at the end of the run (`print_diagnostics`); `extensions/find_by_label.jl` reports the
  count per file. The register's row: "The Labels Alterant's WITHHOLD and EXPLICIT APPLY".
- **The unknown label is reported, not refused.** A label applied from outside the run's vocabulary — never declared, removed, misspelled, or
  with an invisible separator swallowed inside — applies nothing under any form (plain, withhold, explicit) and the run completes
  `PROCESS_OK` with ONE `:warning` diagnostic per name occurrence at each affected Component (`LABEL_NOT_APPLIED_UNKNOWN`: the statement's
  form and the remedy named, the accepted set not listed); a list applies its other names; the empty member of a plain list (a stray
  comma) is a shape refusal. The register's row: "The Labels Alterant's UNKNOWN LABEL".
- **The vocabulary lives in a data file; `++` and `--` persist.** The shipped vocabulary is the data file
  `data/alterants-std/labels-vocabulary.txt` — 46 names: `label1` … `label5`, `doc`, the 33 pictograph names in the glued form (`label🍀`),
  and the everyday names `warning`, `note`, `info`, `definition`, `todo`, `public`, `private`; the bare pictographs left the list. A run reads
  the user level's copy `~/.gometa/labels-vocabulary.txt` (created from the shipped file at the first need; another path through
  `GOMETA_LABELS_VOCABULARY`), and the vocabulary statements EDIT that copy when they are read — every change of a run that completes reported by an `:info` diagnostic
  (`LABELS_VOCABULARY_FILE_CHANGED`; a file that cannot be written: ONE `:warning` per change, `LABELS_VOCABULARY_FILE_NOT_WRITTEN`, the change holding for the run); the shipped file is never written and is the revert source. A declared name carrying white space or an invisible separator inside, or beginning with `#`, is refused (the inner character accepted at 0.4.2); a vocabulary file whose line carries an inner one refuses the run. The literal
  `GoMeta.Alterants.LABELS_VOCABULARY` is gone (`base_vocabulary()` reads the file). The register's row: "The Labels Alterant's VOCABULARY FILES".
- **Two facilities of the Engine, for every Alterant.** The reader trims every bare argument's two edges of the ordinary white space and
  six invisible separators (U+2028, U+2029, U+180E, U+200B, U+2060, U+FEFF) before the Alterant sees it — the class the new package-public
  `GoMeta.is_argument_space` names (a quoted text untouched). A read-time hook's return is read in one grammar: `nothing`, a vector of
  diagnostics alone (delivered, the statement enqueued), a state, or a state with a vector of diagnostics (consumed and delivered) — the
  rows pass the one door with the read-time place (the stating statement, the level, the statement's text). The register's rows:
  "`GoMeta.is_argument_space`" and "The read-time hook's return".
- **The development tools.** The tree views of `print_altValues_evals` — the FULL delivery view and the compact tree, their `.html` / `.txt`
  twins — end with the run section: the status line and the diagnostics folded as the end-of-run print folds them, printed also where the
  view has no evals rows; the command line's one-liner takes the user level's profile as an optional third argument
  (`devtools.jl <verb> <file> [profile]`); `print_diagnostics` prints every other key of a row's context as data.

## 0.4.2 — 2026-10-22

- **The Labels Alterant's vocabulary statements.** A file at `#~0` or the user's profile adds names to the Labels
  Alterant's vocabulary for the run and removes names from it: `:++x` / `:(++, x, y)` add, `:--x` / `:(--, x)` remove. A
  vocabulary statement is consumed at the read — no label applied, no row; it holds from its own metaBlock onward; the place is
  checked first (`#~0` or the profile, nothing else), then the malformed shapes are refused. The shipped list (39 names) is the
  base behind `base_vocabulary()`; a run's additions and removals are kept apart from it, the effective set the base plus the
  additions minus the removals. The unknown-label refusal reads "not in the Labels Alterant's vocabulary" (before: "not in v0's closed label whitelist"), the printed set the
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
