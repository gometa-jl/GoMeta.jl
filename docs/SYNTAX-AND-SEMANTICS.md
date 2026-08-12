# GoMeta — Syntax & Semantics Reference

**What this IS** — the authoritative, verified reference for the GoMeta `#~` metaLine syntax and its rendering
semantics. **What it DOES** — defines every construct of the language and the rules by which GoMeta decides each
line's fate, with every claim cited to a runnable example in this corpus and its captured output.
**REASONING** — a metadata language is only as trustworthy as its ground-truth; prose drifts, rendered examples
do not, so each rule here points at a file you can re-run and confirm. **PURPOSE** — one place a human author
can learn GoMeta exactly, and verify it, before writing or changing a metaLine.
*(New to a term? Each is defined in the Glossary just below §0.)*

> Verification: every behaviour claim below is cited to the committed corpus in `examples/` — a runnable
> input (`InFileFolder/`) and its committed rendered output (`OutFileFolder/`). Citations of the form
> `Extended L7` mean line 7 of `InFileFolder/file_for_Example_Extended.jl`; `→ Out` means the rendered
> `OutFileFolder/` counterpart. Structural claims (which block sits at which depth, what inherited what) are
> engine-verified: the shipped test suite pins every corpus render byte-for-byte, and `run_examples.jl`
> (repository root) re-runs and re-verifies the whole set locally (§12).

---

## 0. What GoMeta does (the mental model)

- **IS** — GoMeta is an *interpretable-metadata* engine. A source file (here, `.jl`) carries ordinary content
  plus `#~` **metaLines**. GoMeta **absorbs** the metaLines, **evaluates** which *alterants* apply to each piece
  of content, and a renderer **applies** the result. GoMeta **evaluates; it never executes** the file.
- **The pipeline** — `parse (BLS)` → `absorb (read metaLines)` → `evaluate (which alterants apply per component)`
  → `render (apply Visib)`.
- **BLS** parses a file into a tree of components: **File → Block → Line → Segment**. A *Block* is the unit that
  carries metadata scope; it is typed **Meta**, **Text**, or **Code**.
- The **Visib** (visibility) alterant decides each component's fate when rendered: **show**,
  **hide**, or **discard**.
- **Posture.** Several behavioural surfaces are engine-defined at v0 (this reference marks them
  where they occur, and §13 collects them); the committed corpus is normative, and the golden
  test layer is the oracle — where prose and a committed render could ever disagree, the render wins.

## Glossary (terms used throughout)

- **BLS** — the *Block-Line-Segment* parser; it decomposes a source file into the component tree.
- **Component / Block / Line / Segment** — the tree levels. A **Line** is one source line; a **Segment** is a
  substring within a line (e.g. the meta part vs. the trailing `## ` comment); a **Block** is a contiguous run of
  same-type lines and is the unit that carries metadata scope. Each is typed **Meta**, **Text**, or **Code**
  (a line is Meta if it starts with a DELIMITED `#~` head — `#~` followed by whitespace, a depth marker, or
  end of line; Code if it is executable source; Text otherwise. An undelimited `#~hide` is NOT Meta — see
  the token-delimiter law below).
- **metaBlock** — a Block of type Meta; the unit that carries metadata scope for alterants. One or more
  *contiguous* metaLines form a single metaBlock (§3).
- **metaLine** — a `#~`-prefixed line carrying metadata (labels + actions).
- **alterant** — a directive GoMeta applies to a component: the **Visib** alterant (show/hide/discard), **labels**,
  and other engine actions (see §10 and §13).
- **cell** — the component a verdict attaches to (a Block, a Line, or a Segment); its **cell_handle**
  is that cell's verbatim content bytes.
- **meta-hierarchy / slot** — the engine's per-depth store of pending alterant actions: one slot per
  open depth, capacity 7 actions at v0.
- **verdict** — a final evaluated alterant value for one cell.
- **State-refs** — built-in predicates that query a BLS component's type/content (`isCode`, `isText`, `isMeta`,
  `containsMeta`), used inside conditions to decide whether an alterant applies (§6).
- **settribute** — a component's flag record (its settings/attributes: e.g. `depthN`, `isCode`, the Visib
  verdict), carried per BLS component (`componentSettribute` in the source) and read by State-refs and the
  render. The coinage joins *settings* + *attribute*.
- **depth** — a metaBlock's nesting level (1, 2, 3, …), set by tilde-count or a digit (§2); v0 supports
  depths 1 through 8, and the digit `0` addresses the file level — `#~0` is **accepted**, not
  refused: it processes to `PROCESS_OK` with no diagnostic (the form is outside the committed
  corpus; the corpus is the reference — §13). *Notation:* `depthN`
  in backticks is the literal settribute flag; "depth N" in prose is the level; "depth-N" is its adjective form.
- **attachment** — a content block is *attached* to the meta above it **iff there is no blank line between them**;
  an attached block *inherits* the open metaBlocks' alterants; a blank line *detaches* it (no inheritance) (§4).
- **metadata scope** — the set of components that inherit a metaBlock's alterants, governed by depth + attachment.

---

## 1. The metaLine — anatomy

**IS** — a metaLine is a `#~`-prefixed line with up to three parts: an optional depth marker, the labels and
actions, and an optional human comment. Its general shape:

```
#~[<depth>]  <labels and actions>   ## <human comment, ignored by the meta-parser>
```

(`[<depth>]` is optional; if omitted, depth defaults to 1.)

- The leading `#~` (plus optional depth marker), **followed by whitespace or end of line**, identifies it
  as meta — the token-delimiter law below governs the boundary.
- The middle carries **labels** (`:labelN`) and **actions** (`discard{…}` / `hide{…}` / `show{…}`), processed
  **left to right** (see §8 rule 4).
- Anything after a `## ` on the same line is a **human comment** — the meta-parser ignores it.
  Cite: `Extended L7` `#~ discard{ :label2 , isCode} ## This is a comment within a meta Block.` → the
  `## …` part has no effect.

**MetaLines have three syntax forms** — the **standard metaLine** on its own line (`#~` / `#~N` / `#~~~`); the
**close-marker** `#]` (§4/§9); and the **inline `#~`** at the end of a content line (§9). Plus one **modifier**:
the **inert `#~!`**, which makes a standard metaLine's content *not be processed* (§9).

> ⚠ **Parsing gotcha:** inside a single-hash `# ` *content* line, **any `#~` token (any form — `#~`, `#~N`,
> `#~!`, `#~~~`, or an inline `#~`) and `#]`** are parsed as **live inline syntax** (§9), not prose. To write
> GoMeta tokens in commentary, **QUOTE-GLUE the metaStatement — the escape convention: write `"#~ hide"`
> with the quote hugging the marker.** A quote-glued mention is inert (zero evaluations, byte-identical
> render): a token is only recognized after whitespace or at line start, so the glued quote blocks dispatch
> entirely. The one discipline: NO space between the opening quote and the marker — `" #~ hide"` (spaced)
> fires the inline scanner and refuses loudly. (Double-hash `## ` comments alone are NOT unconditionally
> inert: a whitespace-preceded `#~` inside one still fires the inline scanner.)

**String literals are NOT parsed.** GoMeta reads a file as LINES; it never lexes the host
language's string syntax. Inside a MULTI-LINE string a whitespace-preceded marker
MID-LINE is LIVE — a trailing `#~ hide` comment-marks and `#~ discard` silently DELETES
that line of string content from the share render. (A line BEGINNING with a marker is
held by the string fence and stays inert; on a single-line string the closing quote
poisons the body and the file refuses loudly.) **The escape is the token-delimiter law
itself: glue ANY non-whitespace character to the front of the `#`** — `"#~ hide"`,
`'#~ hide'`, a backtick, a period — a front-glued marker is never a token.

*(Flavor-scoped bound — the `:latex` flavor (ships at `0.3.0`): LaTeX `verbatim`
environments are NOT fences — a `%~` metaLine inside `\begin{verbatim}…\end{verbatim}` is
LIVE (it mints, and a hide covers the following lines, the `\end{verbatim}` line included).
The front-glue escape applies unchanged.)*

**THE TOKEN-DELIMITER LAW.** Every marker token — the `#~` family, the `##` comment, the `#]` close, the
`# ` text lead — requires **whitespace or a line boundary on BOTH sides of its head**. The delimiter class
is **Unicode horizontal whitespace** (ASCII space and tab, the no-break space, the CJK full-width space,
and the rest of the `\h` class); line-break characters delimit as line boundaries, and zero-width format
characters (U+200B and friends) are NOT whitespace and never delimit — though note that some characters
IN the delimiter class (the no-break space foremost) render indistinguishably from an ordinary space
while activating a token: only zero-width characters are guaranteed inert. A shape that fails the after-side —
`something##glued`, `#~someWord`, `#]x`, `###banner`, a bare `#x` — is **plain content of its
neighbourhood**: not meta, not a comment, never refused, and it never splits the block it sits in. This is
deliberate: `someCharacters##someMoreCharacters` is a valid thing to write in a file PRECISELY BECAUSE
tokens demand their delimiters. The law gates token *recognition* only — a delimited token with a
malformed body still refuses loudly (`##` is a comment exactly when BOTH sides delimit — whitespace or a
line boundary before it, whitespace or end-of-line after it;
`###`-runs are content).

**One carve-out from the plain-content rule:** the four RESERVED structural-directive comment
forms — `#-`, `#+`, `#[`, `#>`-initial, which fire on their prefix (so ordinary `#----` dividers
and `#->` arrows are in the family) — are NOT plain content. They are parse-level structure
hints held as reserved future GoMeta syntax: a directive-form line can start a new block, and,
since `0.2.3`, a directive form DIRECTLY adjacent to metadata meets a stable, early refusal
instead of the earlier crash (both grains — with one measured corner: inside an OPEN
multi-line string, `#+`/`#>` interior lines remain string content even directly after inline
metadata, while the `#-`/`#[` twins refuse; the escapes and the full behavior catalogue live
in [Public API + error modes](public-api.md) §3.4). Away from metadata — at file start,
between code lines, after an interposed content line — they behave as render-inert comments.

---

## 2. Depth

**IS** — every meta-block sits at a **depth** (1, 2, 3, …), analogous to heading levels (section, subsection).
**DOES** — depth is set by the **number of tildes**, and an explicit **digit overrides** the count
(the multi-tilde-plus-digit form, e.g. `#~~3`, is outside the v0 corpus; the corpus is the
reference — §13):

| Written | Depth | Verified by |
|---|---|---|
| `#~`   | 1 | `Extended L7/L8/L19`, `Proposal L1/L3` |
| `#~2`  | 2 | `Extended L18/L51`, `Proposal L9` |
| `#~3`  | 3 | `Extended L34`, `Proposal L22` |
| `#~~~` | 3 | `feature_triple_tilde.jl` — engine-verified structure: its `#~~~` block nests inside the depth-2 chapter (the tree golden pins the NESTING; the depth integer is the documented reading of the tilde count) |

(`#~2` itself shows the digit setting the depth — one tilde, digit 2, ⇒ depth 2. A *multi*-tilde-plus-differing-
digit form, e.g. `#~~3`, is not exercised here — see §13.)

**The authorable depth WINDOW at v0 is 1–8.** In the **digit** depth form, `#~9` and beyond is
out-of-window and is a documented guarded edge (the E-06 row of `docs/public-api.md` §3.1: a stable
refusal, not a crash) — do not author beyond depth 8.

**REASONING** — depth drives the open/close (scope) rules in §4 and §8, exactly like nesting headings.
**PURPOSE** — lets one file express nested metadata regions.

---

## 3. Blocks — the unit of scope

- **Contiguous metaLines are ONE metaBlock** — the engine-verified structure shows no block break in
  either depth direction. A later **deeper** digit is recorded only at the line level: the block's scope
  depth stays **frozen** at its **first** line's depth. Verified: `feature_contiguous_metablock.jl`
  (`#~ hide{ :label1 }` + `#~2 :label1` render as one depth-1 block — engine-verified structure). A later
  **shallower** digit also stays in the SAME structural block; the corpus narrates it as the run's end
  marker ("This comment ends this meta `Block` at level 2", `Extended L19`), and it cancels nothing:
  `Extended L18`'s labels reach both the attached code block (input L23) and a later text block
  (input L37), and `L19`'s own `hide{:label1}` reaches later content too (input L45). Implicit
  close/supersede happens BETWEEN metaBlocks, not inside a contiguous run (§4).
- A `## ` comment line **between** metaLines does **not** break the block. Cite: `Extended L7–L10` are one meta
  block even though `L9` is a `## ` comment ("The following meta `Line` within this `Block`…").
- A block **ends** at: a blank line, a content line (type change), a `#]` close-marker, or a `#~!`.
- **A blank line after a meta line starts a new block** (only Code and Text blocks may contain interior blank
  lines). Verified end-to-end by `feature_contiguous_metablock_blankline.jl`: inserting one blank line splits a
  contiguous meta-block into two and changes the render (§8).

---

## 4. The two axes — CLOSE (scope) and ATTACH (inheritance) are orthogonal

These are independent; keep them separate.

**CLOSE — which meta-blocks are *open*** (a stack by depth):
- `#]` closes the **innermost** open meta-block; outer blocks stay open.
- An implicit close happens when a following `#~P` has **`P ≤ N`** (the open block's depth) — it
  **closes/supersedes** (the `P = N` "sibling" case included); if **`P > N`** it **nests** inside (and
  inherits). Also closed by a blank line, a `#~!`, or end-of-file.
- Verified: `feature_explicit_close.jl` — after `#]`, the level-5 block still inherits the level-2 chapter
  (`D` hidden), proving the chapter stayed open (only the innermost level-4 closed). Implicit supersede:
  `Extended L51` (`#~2`) supersedes the earlier `#~3`/`#~2`. (A CONTIGUOUS shallower line is a
  different case — it stays inside the same metaBlock and closes nothing; §3.)

**Close vs rule lifetime** — closing a metaBlock (blank line, `#]`, `#~!`, end-of-file) ends its
ATTACHMENT scope for following plain content in some forms, but does **not retire** alterant rules
already absorbed: a standing conditional rule (`hide{ :label1 }`) is still evaluated against later
matching content, and a later **deeper** metaBlock re-enters the hierarchy so earlier standing rules
reach it — `feature_contiguous_metablock_blankline.jl` pins both (its blank line closes that block,
yet line A, attached to the (now separate) `:label1` block, renders hidden). The eviction side is
the sibling rule: an implicit close by a following `#~P` with `P ≤ N` retires the superseded
block's labels AND its standing rules for everything under the new block — a standing rule reaches
later content only through DEEPER re-entry, never across a supersession (verified by a
section-swap fixture in the development fork, outside this document's §11 proof set). `#~!` does not detach
following content as `#]` does (§9). Unpinned shapes: the corpus is the reference (§13).

**ATTACH — what a content block *inherits***:
- A content block is **attached** (inherits the open metaLines' alterants) **iff there is no blank line** between
  the last metaLine and the block's first line.
- A **blank line detaches** the next block (it inherits nothing). Cite: `Extended L12–L16` is a text block that
  the blank `L11` detached, so it does **not** inherit the `L7` meta-block.
- `#]` additionally **detaches the single line immediately after it**. Verified: `feature_explicit_close.jl`
  line `C` (right after `#]`) is **shown** (inherits nothing) while the later level-5 block is hidden.

The proof these are orthogonal: in `feature_explicit_close.jl`, `C` is shown (attach severed) **yet** `D` is
hidden (scope resumed) — one `#]`, two independent effects.

---

## 5. Labels

- **IS** — labels are accumulative tags a metaLine applies to the content in its scope. **Label
  names are validated in BOTH roles** against the engine's closed whitelist — the
  corpus-documented set `:label1` … `:label5` plus, since `0.3.0`, a fixed pictograph
  vocabulary (byte-exact names like `:💡`, `:🔥`; the refusal message lists the full accepted
  set): applying a label from outside the whitelist AND
  querying one in a condition each refuse with a stable message naming the accepted set (a
  condition-side label after an already-winning true atom in a `,`/`||` chain is not queried —
  short-circuit — and in a region that carries no labels at all, the query is never consulted
  and simply evaluates false).
- **Conditional application** — `:labelN{ condition }` applies the label **only** to components satisfying the
  condition. Cite: `Extended L8` `#~ :label1{ isText && containsMeta }` — `:label1` reaches only text that
  contains meta; `Proposal L3` `#~ :label1{ (isText && containsMeta), isMeta }`.
- **Worked contrast — conditional *label* vs conditional *action*** (two different uses of "condition"):
  `:label1{ isText && containsMeta }` is a conditional **label** — it decides *which* components receive
  `:label1`. `discard{ :label1 }` is a conditional **action** — it decides *when* the discard fires on a
  `:label1`-bearing component. In short: a label-condition asks *where to apply the label*; an action-condition
  (§6) asks *when to fire the action*.
- Labels are how conditions (§6) and Visib actions (§7) select what they act on.

---

## 6. Conditions / predicates

Conditions guard **alterant actions** (`discard{…}`/`hide{…}`/`show{…}`) and **conditional labels**
(`:labelN{…}`).

> **SECURITY — conditions run in GoMeta's own closed interpreter.** The `{…}` body is parsed
> and evaluated by the engine itself (a bounded grammar over label and state queries) — it never
> reaches Julia's `eval` in a default-configured run, so a condition cannot execute code or have
> effects. The explicitly opt-in `:full_eval_v1` extension mode is the one documented exception
> (host evaluation — only process trusted input with it loaded). Full posture: the README's
> SECURITY section and `docs/public-api.md` §3.2.

The operators (all verified against the corpus):

| Operator | Meaning | Verified by |
|---|---|---|
| `,`  | **OR**  | `Extended L7` `discard{ :label2 , isCode}` — discard if `:label2` **or** `isCode` |
| `&&` | **AND** | `Extended L8` `:label1{ isText && containsMeta }` |
| `!`  | **NOT** | `Extended L18` `show{ !:label5}` — show only if `:label5` is **not** present |
| `()` | **group** | `Proposal L3` `:label1{ (isText && containsMeta), isMeta }` |

> Precedence of *un-parenthesized* mixed operators (e.g. `a && b, c`) is engine-defined and **not exercised by
> this corpus** — **do not rely on it; always use explicit `()`** to make intent unambiguous, as `Proposal L3`
> does. (See §13.) Tokenization note: keep a space after a grouping `)` before the next atom or
> operator, as the corpus does (`Proposal L3`) — a `)` glued directly to a following atom
> tokenizes engine-defined at v0. (Outside `{}`, on the metaLine itself, a token glued to a
> closing `)`/`}` refuses — `docs/public-api.md` §3.4.)

**State-refs** read the BLS component's type/content: `isCode`, `isText`, `isMeta`, `containsMeta`. Verified:
- `isCode` — the **Code** block (`Extended L20–L32`) is discarded by `discard{ :label2 , isCode}` (`L7`)
  specifically because it `isCode` (it does **not** itself carry `:label2`; it carries `:label3`/`:label5` from
  `L18`).
- `isText && containsMeta` — the text block (`Extended L35–L49`) receives `:label1` from
  `:label1{ isText && containsMeta }` (`L8`).
- `isMeta` — `Proposal L3` `:label1{ (isText && containsMeta), isMeta }`.

(`containsText` exists as a BLS attribute but is **not** used as a condition predicate anywhere in this corpus —
see §13.)

---

## 7. The Visib alterant and its actions

- **IS** — `Visib` is the alterant that decides rendering. Its actions are mutually exclusive: **show**,
  **hide**, **discard**. **The default is `show`.**
- **Render outcomes** (verified across the whole corpus):
  - `show` → the line is kept **verbatim**.
  - `hide` → the line is kept but **prefixed with `## `** (commented out). Cite: `Extended L14` `#~ hide`
    → `→ Out L14` `## # This Line…`.
  - `discard` → the line is **omitted entirely**. Cite: `Extended L15` `#~ discard` → absent from output
    ("Input line 15 will be missing").
- **A metaLine is itself subject to Visib** — a metaLine that carries a hidden/discarded label is itself
  hidden/discarded (e.g. `Extended L51` `#~2 :label2` is discarded along with its markdown).
- **When a block is hidden, every NON-EMPTY line in it carries the `## ` marker** — a single-hash `# `
  content line becomes `## #`; a double-hash `## ` comment ALREADY heads with the marker and renders
  AS-IS (ensure-token — no `## ##` doubling; *dated true-up 2026-08-12 for `0.3.0`, superseding the
  `0.2.3` doubling behavior*); an EMPTY line inside the hidden block stays
  a bare empty line (the marker applies to non-empty lines only). Cite: in the hidden text block of `Extended`,
  the `# ` content lines (`L35–L38`) → `## #`, the `## ` narration (`L46–L49`) stays `## `, and the blank `L40`
  stays blank. (A `## ` comment is still subject to *Visib* — narration meant to stay visible must live in a
  block that is not itself hidden. **Metadata is ALIVE in the render — a stated design property:** hide is a
  VISIBILITY operation, so a hidden metaLine's rendered form `## #~ …` re-parses on re-ingestion (at segment
  grain — same liveness, shifted scope) and re-processing a share render re-yields verdicts; DISCARDED
  metadata is absent from the render and therefore gone. One carve-out: a hidden metaLine that re-ingests
  as a `## ` comment INSIDE a live meta block reads as block commentary — inert by the same rule that makes
  `## ` comments inert between metaLines. Choose `discard` when metadata must not survive the
  share.)

---

## 8. The semantic model — four rules (each verified by render + structure)

1. **Contiguous metaLines = one structural block.** A later **deeper** digit is line-level only (scope
   depth = the first line's; `feature_contiguous_metablock.jl`); a later **shallower** digit marks the
   run's end and cancels nothing — `L18`'s labels still reach the attached and later blocks, and `L19`'s
   own hide action does too (`Extended L18–L19`; input L23/L37/L45).
2. **Between metaBlocks, `P ≤ N` closes/supersedes; `P > N` nests + inherits.** (`feature_explicit_close.jl`; `Extended L51`.)
   This is the CLOSE/scope axis; whether a following content block's *content* inherits is the separate ATTACH
   axis of §4 — a blank line detaches it regardless of depth.
3. **A block inherits the open shallower-depth scopes** (their labels and standing conditions). (`Extended`:
   the code block and the markdown both inherit the file-level `L7` rule; the text block inherits `L8`'s
   `:label1` and `L19`'s `hide{:label1}`.)
4. **Order-of-application — left-to-right within a metaLine; a standing condition reaches later blocks.** Tokens
   on a metaLine are processed left-to-right; a condition issued **before** its label is evaluated with that
   label **not yet applied**, so it does **not** fire on the content attached to *that same block* — but the
   condition **stands**, and **does** fire on later blocks that come to carry the label. Verified two ways:
   - `feature_order_of_application.jl` — `discard{:label1} :label1` leaves the block **shown** (condition before
     label); swapping to `:label1 discard{:label1}` discards it.
   - `Extended L34` `#~3 discard{:label4} :label4` — the block `L35–L49` is **not** discarded (label4 not yet
     applied when the condition was issued); but `L39`, whose trailing inline `#~` re-applies `:label4`, **is**
     discarded — the standing `discard{:label4}` fires there.

A vivid consequence, verified by a *pair* of committed examples: in `feature_contiguous_metablock.jl` the same
`hide{ :label1 }` leaves line A **shown** (A is attached to the same block where the rule preceded the label) yet
hides a later block B that inherits `:label1`. In `feature_contiguous_metablock_blankline.jl` — the sibling
fixture whose byte-identical metaLine pair has **one blank line** inserted between the two metaLines (its
narration text differs) — **both** flip (A hidden, B shown), because the blank line splits one block into two and
drops `:label1` from depth 1 to depth 2. One blank line, two flips, two reasons.

---

## 9. Special metaLines

- **`#~!` (inert)** — the metaLine's content is **not processed**; it also ends the metaBlock (the next content
  attaches per §4, unless a blank line detaches it). Cite: `Extended L10` `#~! discard{ isMeta }` — the
  `discard{isMeta}` is **not** applied (the surrounding meta lines are not discarded), purely because of the `!`.
- **`#]` (close-marker)** — see §4 (the two axes). Demonstrated end-to-end in `feature_explicit_close.jl`.
- **inline `#~`** — a `#~` at the **end of a content line** applies meta to *that line*. The corpus exercises
  three inline forms (other inline forms, e.g. inline labels or depth markers, are not exercised — see §13):
  - `#~ hide` / `#~ discard` hide/discard the line (`Extended L14`/`L15`, `Proposal L7`, markdown `Proposal L34`).
  - `#~ show` **overrides an inherited hide** so the line stays visible (`Proposal L30` — a line inside an
    otherwise-hidden block that renders shown).
  - a bare trailing `#~` re-applies the meta context to the line, which can make a standing condition fire on it
    (`Extended L39`, discarded as shown in §8 rule 4).

---

## 10. Alterant actions and their arguments (v0 forms)

**IS** — an alterant ACTION token may carry a parenthesized, comma-split argument list —
`action(arg1, arg2)` — parsed with the metaLine and handed to the action when it fires.
**DOES** — the v0 forms, each engine-verified:

- **Labels (the `:` action) — documented, both forms:** repeated one-word labels
  (`#~ :label1 :label2`) AND the parenthesized list (`#~ :(label1, label2)`) are equivalent; each
  label is checked against the closed whitelist, in both the label-setting and the condition-query
  roles (an unknown label refuses with a stable message where the query is consulted —
  `docs/public-api.md` §3.4).
- **Id actions (`cell` / `parent` / `file`) — EXPERIMENTAL at this release:** one integer value
  argument (`#~ cell(7)`), Int16 domain. The Id alterant is a v0 placeholder implementation; this
  syntax may change — do not build durable content on it at v0.
- **Visib actions (`show` / `hide` / `discard`) take NO arguments;** an empty list (`hide()`) is
  accepted as the bare form.
- **Malformed arguments** (wrong arity; non-parsable or overflowing values) refuse with the stable
  message `GoMeta apply: invalid arguments …` — never a raw stack trace.
- **Condition-side atoms** (`{ cell(7) }`-class queries inside `{}`) route through the closed
  condition intake instead: non-label arguments meet the typed argument-domain refusal there, and
  the BARE unqueryable atom is the E-07 pending-mint edge (`docs/public-api.md` §3.2/§3.4).

---

## 11. Worked examples (the proof set)

| Example | Proves |
|---|---|
| `file_for_Example_Extended.jl` | depth 1/2/3; `,`/`&&`/`!` conditions; `#~!`; inline `#~ hide`/`#~ discard`/`#~`; blank-line detach; inheritance (file-level rule → code + markdown); order-of-application; implicit close; `hide`=`## ` / `discard`=omit / default=show |
| `file_for_Example_Proposal_JuliaCon.jl` | `()` grouping; `hide{…,isCode}`; `show{!:label5}`; conditional `:label1{…}`; inline `#~ show` overriding inherited hide; depth 2/3; markdown `hide` |
| `feature_explicit_close.jl` | `#]` — the two axes (close-innermost scope + detach-next line), independent |
| `feature_order_of_application.jl` | token order on a metaLine decides whether a condition sees a label |
| `feature_contiguous_metablock.jl` | contiguous metaLines = one block (depth = the first line's); cross-block order-of-application |
| `feature_contiguous_metablock_blankline.jl` | the contiguous-metablock metaLine pair with one blank line inserted between them — flips both content lines (proves blank-line block-splitting; the metaLines are byte-identical across the two fixtures, the surrounding narration is not) |
| `feature_triple_tilde.jl` | `#~~~` = depth 3 (tilde-count), with a depth-3 block nesting in a depth-2 chapter |

---

## 12. Verify it / extend it

Run, from the repository root (after `Pkg.instantiate()`):

```
julia --startup-file=no --project=. run_examples.jl
```

It processes every input in `examples/InFileFolder/`, writes each rendered output to a scratch
folder (printed; pass `--out <dir>` to keep them somewhere specific), and verifies every render
**byte-for-byte** against the committed `examples/OutFileFolder/` reference. To test a hypothesis,
copy or edit an input, rerun, and READ the resulting render (an edited input reports as differing
from the committed reference — that difference *is* the observed effect). Every rule above cites
its committed example.

---

## 13. Out of scope / not exercised by this corpus

To keep the verified claims honest, these are **known but not established here** — do not assume their behaviour:

- **Alterant actions beyond Visib + labels.** The engine's action whitelist also contains `head` (the
  Heading action) and `cell`, `file`, `parent` (the Id actions). The Id actions' v0 *argument forms*
  are documented in §10 (EXPERIMENTAL); their *rendering behaviour* is not exercised by this corpus
  and is not documented here.
- **Section-title metaLines** (`#~2 "Title"` — a first-token quoted string lowering to the `head`
  action, recorded as evaluated `head_<level>` entries with no render effect): documented with
  their refusal family in `docs/public-api.md` §2/§3.4; not exercised by this corpus.
- **`containsText`** is a BLS component attribute but is not used as a *condition predicate* in any example
  (only `containsMeta` is) — treat it as unverified-as-a-predicate.
- **Operator precedence** for un-parenthesized mixed conditions (§6) — use explicit `()`.
- **Digit-vs-tilde-count conflict.** A multi-tilde form carrying a *differing* digit (e.g. `#~~3`) is not
  exercised; `#~2`/`#~3` (one tilde + digit) are.
- **`## ` and inline `#~` in the same `# ` content line** — their parsing interaction is not exercised.
- **Multi-line detachment after `#]`** — `#]` is verified to detach the *immediately-following* line; whether it
  detaches multiple consecutive plain lines is not exercised.
- **Multiple Visib actions in one metaStatement** (e.g. `discard{…} show`) — resolved by THE FIRST
  APPLICABLE VALUE IN SOURCE ORDER: the first value whose condition holds (no condition = holds) wins
  and the remaining values are skipped without evaluating their conditions. `discard{ isCode } show`
  therefore discards code and shows everything else. (The corpus itself does not exercise a
  same-statement pair whose second value would apply; the first-wins rule above is the contract.)
- **Engine limits** — metaLines live in comments (`#`/`##`), not as executable code. The label
  whitelist is closed: the corpus-documented `:label1`..`:label5` plus (since `0.3.0`) the fixed
  pictograph vocabulary — byte-exact names, no normalization —
  and **label names are validated against it in BOTH roles** — applying a label and querying one
  in a condition each refuse with the stable `GoMeta apply: unknown label …` message, which names
  the accepted set (a condition-side label after an already-winning true atom in a `,`/`||` chain
  is not queried — short-circuit — and in a region that carries no labels at all, the query is
  never consulted and simply evaluates false). At most 7 actions accumulate per meta-hierarchy slot
  (exceeding it refuses with a stable message — see `docs/public-api.md` §3.4). The
  authorable depth window is 1–8 in the digit form (§2). Custom label names in either role (where
  the query is consulted — `docs/public-api.md` §3.4), and
  predicates outside the state-ref/action whitelists, are refused.

> Status: this is the verified working reference for the v0 subset of the GoMeta language. The
> language grows by design; the v0 subset forecloses none of it.
