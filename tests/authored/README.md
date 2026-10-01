# tests/authored — the owner's stated expectations (the specification, not a regression pin)

*Owner ruling R-V04B-15 (c), 2026-08-28: "These test will have to be gradually expanded and have to capture any possible scenario." Every CONFIRMED value here is stated or confirmed by the owner; a value in a file whose `status` is `draft` is a session's proposal and has no specification authority until the owner confirms it. The suite checks the Engine against the confirmed statements; a pinned golden elsewhere only checks that nothing changed since it was pinned — this layer checks that the Engine does what the owner means.*

## The law

1. **One scenario = one input file + one expectation file**, same stem: `NNN_<name>.jl` (or `.c`, `.tex`) and `NNN_<name>.toml`.
2. **The expectation file names Components by position** (a Line by its 1-based line number, `line@N`; a Block by its FIRST line, `block@N` — for a metaBlock that is the line its `#~` metaLine stands on, for a Code or Text Block the first line of its run; the File as `file`; a Segment by its Line and its 1-based index, `segment@N.k`) and states, per Alterant, the value the owner expects to apply to that Component — including Components that carry no meta of their own. **The owner's principle (2026-09-10) — his bytes are the build record's `OWNER-WORDS_standing-laws.md` §8 item 5; the wording here is the session's:** *if altValue X_i of Alterant X applies to Block B_p, then it applies INDIRECTLY to B_p's children* — the children are not explicitly issued X_i and did not explicitly inherit it (his Id and Visib examples, §8 item 3); this holds for every Alterant alike, Id and Heading included (§8 items 3 and 5); Visib is only the example. *The session's reading of the grains, not his words:* a metaLine (a whole-line `#~` statement) is the metaStatement of the metaBlock it forms, `block@N`; the Line it stands on, `line@N`, falls under that Block's value indirectly, as its child; only an inline metaSegment is a Line's own metaStatement, and a Line with one is decided by it — for Visib, his words: *"the closest metaStatement wins"* (§7 item 1, Line 3 of draft 001). A statement for a child Component therefore records the value that applies to it, directly or indirectly, and `decided_by` names the Component whose metaStatement decided that value — one position for a single value, a list for an accumulating one; the per-field form of a compound value (Id, set-mode `:mutExclusivePerField`, where fields may be decided by different Components) is NOT yet defined and is open with the interface's design. Whether the Engine's delivery carries an entry for such a child is open too (the interface is a first crude draft, OWNER-WORDS §7 item 2 — his lean, given with a question back) and is not what the statement asserts. **Typed forms:** a SINGLE value (Visib — set-mode `:mutExclusive`; Heading — `:localOnly`, applying once where it stands) is a string and its `decided_by` one position (or `"default"`); an ACCUMULATING value (Labels — the labels that apply) is a list of strings and its `decided_by` a list of positions — *PROVISIONAL: this is the builder's proposed form for the shape the owner may choose at question 4b (i); the shapes (ii) per-value mapping and (iii) contribution rows would define their own form*; an ABSENT value (no value applies at this Component) is written `present = false` with no `value` and no `decided_by`; a value that APPLIES but for which the Engine gives no per-Component answer (only under a design answer where a checker derives a plain Line's value from its Block) is written with its `value` and `decided_by` plus `own_answer = false` — *PROVISIONAL, pending question 1b-DESIGN*; a `note` may carry implementation observations as provenance, always with the observed commit and date (never "today").
3. **Owner-confirmed only.** A scenario drafted by a session carries `status = "draft"` and is NOT run as a test until the owner sets `status = "confirmed"` (the file records who confirmed and when). Drafts exist so the owner confirms rather than writes from scratch.
4. **Append-only, never re-minted silently.** A confirmed expectation changes only by an owner ruling recorded in the file's `history`.
5. **Every new feature, ruling or cure adds its scenario** (a standing obligation on every session; the catalogue `SCENARIOS.md` is the checklist of what is covered and what is not yet).

## The expectation file format

```toml
schema = 1
stem = "001_block_hide_inherits"
status = "draft"            # draft | confirmed
drafted_by = "session S3B, 2026-08-28"
confirmed_by = ""           # "owner, 2026-08-29"
scenario = "block@1: hide; block@2, attached to that meta, inherits hide; a plain Line inside falls under it indirectly, as its child; a Line with an inline #~ show is show — the closest metaStatement wins"

[[expect]]
component = "block@1"       # the metaBlock whose #~ line is line 1
alterant = "Visib"
value = "hide"
decided_by = "block@1"      # the Component whose metaStatement decided it (its own | the metaBlock its Block is attached to | an enclosing Block)

[[expect]]
component = "block@2"       # the Code Block (first line 2), attached to block@1's meta
alterant = "Visib"
value = "hide"
decided_by = "block@1"      # inherits hide (the owner's word for an attached Block)

[[expect]]
component = "line@2"        # a plain Line inside block@2
alterant = "Visib"
value = "hide"
decided_by = "block@1"      # applies indirectly to line@2 as a child of block@2, which is attached to block@1's meta; no per-Line row at 85576bf (observed 2026-08-28)

[[expect]]
component = "line@3"        # the Line with the inline "#~ show"
alterant = "Visib"
value = "show"
decided_by = "line@3"       # its own

[[expect]]                  # an accumulating value: a list, and a list of contributors
component = "block@4"
alterant = "Labels"
value = ["label1", "label2"]
decided_by = ["block@1", "block@3"]

[[expect]]                  # a typed absence: no value applies at this Component
component = "line@2"
alterant = "Heading"
present = false
```

*Corrected 2026-09-04 (session S4, after the CrossReview set `s4drafts`; the scaffold is S3B's of 2026-08-28): the Block selector now names Code Blocks too (by first line — the drafts already used that reading); "every value" → every CONFIRMED value; the format example showed a hide on the Line that says show; the typed forms for accumulating values, absence and provenance notes were undefined.*

*Corrected 2026-09-10 (session S4, on the owner's words of the same day, OWNER-WORDS §7–§8, and after a three-seat read-only check of the wording against those words): rule 2 no longer says that a plain Line "inherits" a value or that the Engine "records" it — a value applies to the Component it was evaluated for and INDIRECTLY to that Component's children, for every Alterant alike; the grains sentence (a metaLine is its metaBlock's statement; an inline metaSegment is a Line's own) is labelled the session's reading; the typed forms: "exclusive" renamed SINGLE with each Alterant's set-mode named, Id's per-field form declared open; the example's scenario string, the `decided_by` gloss and the line@2 comment reworded the same way and a block@2 row added; the provisional `own_answer` form is unused and stays provisional until the interface's design is settled.*

The runner (`tests/authored/authored_tests.jl` — landed 2026-09-11 under R-V04B-24 (R), the third layer of `tests/runtests.jl`) reads every `*.toml` with `status = "confirmed"`, runs the input, maps the positions to the Engine's occurrence handles, and asserts each expectation against `altValues_evals` (and, after D-1, the resolved rows). *How it reaches a child Component today (its header states it):* a Component's own rows if it has any, else — for a Line — its Block's rows (the owner's indirect-application principle, rule 2), else the documented default for Visib (`show`, docs/SYNTAX-AND-SEMANTICS.md §7) / absence for the others; it never re-evaluates a metaStatement. `decided_by` is ASSERTED since stage 2's commit 4a of the v0.4 build (the Engine's provenance since its commit 2, R-V04B-35 (d)): the deciding statements' Components of the rows that gave the applied value, named by position — a Segment's statement by its Line (`line@N`, the vocabulary of the confirmed files; the session's reading, put to the owner), the fed profile as `user`, no statement as `default` — must equal the expectation's set. A confirmed statement the Engine is KNOWN not to meet yet is listed in the runner's `EXPECTED_FAILURES` with its ruling and runs as `@test_broken` (none since stage 2's commit 1 — the heading re-key, R-V04B-50).
