# examples/ — the GoMeta corpus (ground truth)

- **`InFileFolder/`** — the canonical inputs (the single source of truth). Each file's `##` header
  states the expected behaviour AND the reason why — the files are the spec.
- **`OutFileFolder/`** — the committed reference renders: byte-for-byte what the engine produces.
  Verify locally with `julia --startup-file=no --project=. run_examples.jl` from the repository
  root; the golden test layer pins the same bytes. Structural claims in the example headers
  (which line sits at which depth, what inherits what) are engine-verified by the tree-half
  goldens under `tests/golden/`.
