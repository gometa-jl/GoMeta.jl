# `feature_order_of_application.jl`

**Proves:** token order on a metaLine decides whether a condition sees a label

*(The "proves" line is this example's row in the [syntax reference](../SYNTAX-AND-SEMANTICS.md)
§11 proof-set table; every rule there cites a runnable committed example.)*

Committed pair: `examples/InFileFolder/feature_order_of_application.jl` → `examples/OutFileFolder/feature_order_of_application.jl` — the same
bytes the golden test layer pins. Verify locally from the repository root:
`julia --startup-file=no --project=. run_examples.jl`.

## Input

```julia
## ============================================================================================
## FEATURE: order-of-application — a condition sees only the labels applied to its LEFT (earlier).
## Labels are limited to :label1..:label5; the Visib actions are show / hide / discard.
## ============================================================================================
## Within a meta-line, tokens are processed LEFT-TO-RIGHT. A conditional alterant such as
## discard{ :label1 } is evaluated AT ITS POSITION, so it "sees" a label only if that label was applied
## earlier (to its left) on the same line.
##
## On the meta-line below, discard{ :label1 } comes BEFORE :label1. When discard{ :label1 } is evaluated,
## :label1 has not been applied yet, so the condition is false: the block is NOT discarded. (The block
## still receives :label1, applied afterwards, but renders SHOWN.)
##
## EXPECTED RENDER — see OutFileFolder/: the block below is SHOWN.
##
## TRY IT (verified): on the meta-line below, move :label1 to the LEFT of discard{ :label1 } (label first,
##   condition second) and rerun. Now :label1 is applied before discard{ :label1 } is evaluated, the
##   condition is true, and the block is DISCARDED (it disappears from the output). The only change is the
##   token order — that is the whole point of this example.
## ============================================================================================
#~ discard{ :label1 } :label1
# This block carries :label1, but the discard condition was evaluated before the label, so it is SHOWN.
# A second line of the same block; also shown.
```

## Rendered output

```julia
## ============================================================================================
## FEATURE: order-of-application — a condition sees only the labels applied to its LEFT (earlier).
## Labels are limited to :label1..:label5; the Visib actions are show / hide / discard.
## ============================================================================================
## Within a meta-line, tokens are processed LEFT-TO-RIGHT. A conditional alterant such as
## discard{ :label1 } is evaluated AT ITS POSITION, so it "sees" a label only if that label was applied
## earlier (to its left) on the same line.
##
## On the meta-line below, discard{ :label1 } comes BEFORE :label1. When discard{ :label1 } is evaluated,
## :label1 has not been applied yet, so the condition is false: the block is NOT discarded. (The block
## still receives :label1, applied afterwards, but renders SHOWN.)
##
## EXPECTED RENDER — see OutFileFolder/: the block below is SHOWN.
##
## TRY IT (verified): on the meta-line below, move :label1 to the LEFT of discard{ :label1 } (label first,
##   condition second) and rerun. Now :label1 is applied before discard{ :label1 } is evaluated, the
##   condition is true, and the block is DISCARDED (it disappears from the output). The only change is the
##   token order — that is the whole point of this example.
## ============================================================================================
#~ discard{ :label1 } :label1
# This block carries :label1, but the discard condition was evaluated before the label, so it is SHOWN.
# A second line of the same block; also shown.
```
