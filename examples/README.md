# examples/ — the GoMeta corpus (ground truth)

- **`InFileFolder/`** — the canonical inputs (the single source of truth). Each file's `##` header
  states the expected behaviour AND the reason why — the files are the spec.
- **`OutFileFolder/`** — the committed reference renders: byte-for-byte what the basic renderer — a development tool since 0.4.0 (`devtools/basic_renderer.jl`) — produces from the Engine's run.
  Verify locally with `julia --startup-file=no --project=. devtools/run_examples.jl` from the repository
  root; the golden test layer pins the same bytes. Structural claims in the example headers
  (which line sits at which depth, what inherits what) are engine-verified by the tree-half
  goldens under `tests/golden/`.
