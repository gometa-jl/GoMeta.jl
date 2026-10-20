# tests/authored — the creator's stated expectations (the specification, not a regression pin)

*The creator's rule (2026-08-28): the tests are to be "gradually expanded" and "capture any possible scenario". Every CONFIRMED value here is stated or confirmed by the creator; a value in a file whose `status` is `draft` is a proposal and has no specification authority until the creator confirms it. The suite checks the Engine against the confirmed statements; a pinned golden elsewhere only checks that nothing changed since it was pinned — this layer checks that the Engine does what the creator means.*

## The law

1. **One scenario = one input file + one expectation file**, same stem: `NNN_<name>.jl` (or `.c`, `.tex`) and `NNN_<name>.toml`.
2. **The expectation file names Components by position** (a Line by its 1-based line number, `line@N`; a Block by its FIRST line, `block@N` — for a metaBlock that is the line its `#~` metaLine stands on, for a Code or Text Block the first line of its run; the File as `file`; a Segment by its Line and its 1-based index, `segment@N.k`) and states, per Alterant, the value the creator expects to apply to that Component — including Components that carry no meta of their own. **The creator's principle (2026-09-10), in this page's wording:** *if altValue X_i of Alterant X applies to Block B_p, then it applies INDIRECTLY to B_p's children* — the children are not explicitly issued X_i and did not explicitly inherit it (his Id and Visib examples); this holds for every Alterant alike, Id and Heading included; Visib is only the example. *The reading of the grains that follows is this page's, not the creator's words:* a metaLine (a whole-line `#~` statement) is the metaStatement of the metaBlock it forms, `block@N`; the Line it stands on, `line@N`, falls under that Block's value indirectly, as its child; only an inline metaSegment is a Line's own metaStatement, and a Line with one is decided by it — for Visib, his words: *"the closest metaStatement wins"*. A statement for a child Component therefore records the value that applies to it, directly or indirectly, and `decided_by` names the Component whose metaStatement decided that value — one position for a single value, a list for an accumulating one; the per-field form of a compound value (Id, set-mode `:mutExclusivePerField`, where fields may be decided by different Components) is NOT yet defined and is open with the interface's design. Whether the Engine's delivery carries an entry for such a child is open too (the interface is a first crude draft — the creator's lean, given with a question back) and is not what the statement asserts. **Typed forms:** a SINGLE value (Visib — set-mode `:mutExclusive`; Heading — `:localOnly`, applying once where it stands) is a string and its `decided_by` one position (or `"default"`); an ACCUMULATING value (Labels — the labels that apply) is a list of strings and its `decided_by` a list of positions — *PROVISIONAL: the proposed form for the shape the creator may choose; the alternative shapes — a per-value mapping, contribution rows — would define their own form*; an ABSENT value (no value applies at this Component) is written `present = false` with no `value` and no `decided_by`; a value that APPLIES but for which the Engine gives no per-Component answer (only under a design answer where a checker derives a plain Line's value from its Block) is written with its `value` and `decided_by` plus `own_answer = false` — *PROVISIONAL and so far unused: no file states it and the runner does not read it; pending the interface's design*; a `note` may carry implementation observations as provenance, always with the observed commit and date (never "today").
3. **Creator-confirmed only.** A drafted scenario carries `status = "draft"` and is NOT run as a test until the creator sets `status = "confirmed"` (the file records who confirmed and when). Drafts exist so the creator confirms rather than writes from scratch.
4. **Append-only, never re-minted silently.** A confirmed expectation changes only by the creator's decision, recorded in the file's `history`.
5. **Every new feature, decision or cure adds its scenario** (a standing obligation; the catalogue `SCENARIOS.md` is the checklist of what is covered and what is not yet).

## The expectation file format

```toml
schema = 1
stem = "001_block_hide_inherits"
status = "draft"            # draft | confirmed
drafted_by = "a draft of 2026-08-28"
confirmed_by = ""           # "the creator, 2026-08-29"
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
decided_by = "block@1"      # inherits hide (the creator's word for an attached Block)

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


The runner (`tests/authored/authored_tests.jl`, the third layer of `tests/runtests.jl`) reads every `*.toml` with `status = "confirmed"`, runs the input, maps the positions to the Engine's occurrence handles, and asserts each expectation against the Engine's answer for the Component — `GoMeta.evaluatedAltValue(delivery, component, alterant)`, the rows read through the public `altValues_evals`. *How a child Component is reached (its header states it):* the Engine's answer is the Component's own rows if it has any, else its parent's up the tree (the creator's indirect-application principle, rule 2), else the Alterant's declared default (Visib `show`, docs/SYNTAX-AND-SEMANTICS.md §7) or absence; the runner derives nothing of its own and never re-evaluates a metaStatement. `decided_by` is ASSERTED since 0.4.0: the deciding statements' Components of the rows that gave the applied value, named by position — a Segment's statement by its Line (`line@N`, the vocabulary of the confirmed files), the fed profile as `user`, no statement as `default` — must equal the expectation's set. A confirmed statement the Engine is KNOWN not to meet yet is listed in the runner's `EXPECTED_FAILURES` with its reason and runs as `@test_broken` (none since 0.4.0).
