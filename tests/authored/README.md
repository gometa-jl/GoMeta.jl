# tests/authored — the owner's stated expectations (the specification, not a regression pin)

*Owner ruling R-V04B-15 (c), 2026-08-28: "These test will have to be gradually expanded and have to capture any possible scenario." Every value here is stated or confirmed by the owner. The suite checks the Engine against these statements; a pinned golden elsewhere only checks that nothing changed since it was pinned — this layer checks that the Engine does what the owner means.*

## The law

1. **One scenario = one input file + one expectation file**, same stem: `NNN_<name>.jl` (or `.c`, `.tex`) and `NNN_<name>.toml`.
2. **The expectation file names Components by position** (a Line by its 1-based line number; a Block by the line its `#~` metaLine stands on; the File as `file`; a Segment by its Line and its 1-based index) and states, per Alterant, the value the owner expects the Engine to evaluate to for that Component — including Components that carry no meta of their own (the inherited values), once the Engine records them (D-1).
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
scenario = "one Block hides; a plain Line inside inherits; a Line with inline #~ show overrides"

[[expect]]
component = "block@1"       # the Block whose #~ line is line 1
alterant = "Visib"
value = "hide"
decided_by = "block@1"      # the Component whose meta decided it (own | an enclosing Block)

[[expect]]
component = "line@3"
alterant = "Visib"
value = "hide"
decided_by = "block@1"      # inherited — not recorded by the Engine at 85576bf (the boundary finding); the test expects it once D-1 lands
```

The runner (`tests/authored/authored_tests.jl`, to be written as the next code step) reads every `*.toml` with `status = "confirmed"`, runs the input, maps the positions to the Engine's occurrence handles, and asserts each expectation against `altValues_evals` (and, after D-1, the resolved rows). Until the runner exists this directory is documentation and drafts.
