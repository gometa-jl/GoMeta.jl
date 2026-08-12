# Examples gallery

The 7 committed corpus pairs: each page quotes one input file and, beneath
it, the rendered output the engine produces for it — exactly as committed under `examples/`
and pinned by the golden test layer (where a committed file ends without a final newline,
its quoted block necessarily shows one; the affected page says so beside the quote). The
[syntax reference](../SYNTAX-AND-SEMANTICS.md) cites these same files rule by rule; its §11
table (quoted per page) states what each example proves.

| Example | Proves |
|---|---|
| [`file_for_Example_Extended.jl`](file_for_Example_Extended.md) | depth 1/2/3; `,`/`&&`/`!` conditions; `#~!`; inline `#~ hide`/`#~ discard`/`#~`; blank-line detach; inheritance (file-level rule → code + markdown); order-of-application; implicit close; `hide`=`## ` / `discard`=omit / default=show |
| [`file_for_Example_Proposal_JuliaCon.jl`](file_for_Example_Proposal_JuliaCon.md) | `()` grouping; `hide{…,isCode}`; `show{!:label5}`; conditional `:label1{…}`; inline `#~ show` overriding inherited hide; depth 2/3; markdown `hide` |
| [`feature_explicit_close.jl`](feature_explicit_close.md) | `#]` — the two axes (close-innermost scope + detach-next line), independent |
| [`feature_order_of_application.jl`](feature_order_of_application.md) | token order on a metaLine decides whether a condition sees a label |
| [`feature_contiguous_metablock.jl`](feature_contiguous_metablock.md) | contiguous metaLines = one block (depth = the first line's); cross-block order-of-application |
| [`feature_contiguous_metablock_blankline.jl`](feature_contiguous_metablock_blankline.md) | the contiguous-metablock metaLine pair with one blank line inserted between them — flips both content lines (proves blank-line block-splitting; the metaLines are byte-identical across the two fixtures, the surrounding narration is not) |
| [`feature_triple_tilde.jl`](feature_triple_tilde.md) | `#~~~` = depth 3 (tilde-count), with a depth-3 block nesting in a depth-2 chapter |

Verify every pair locally from the repository root (after `Pkg.instantiate()`):
`julia --startup-file=no --project=. run_examples.jl` — it renders each input and compares
the result byte-for-byte against the committed reference.
