# `feature_explicit_close.jl`

**Proves:** `#]` — the two axes (close-innermost scope + detach-next line), independent

*(The "proves" line is this example's row in the [syntax reference](../SYNTAX-AND-SEMANTICS.md)
§11 proof-set table; every rule there cites a runnable committed example.)*

Committed pair: `examples/InFileFolder/feature_explicit_close.jl` → `examples/OutFileFolder/feature_explicit_close.jl` — the same
bytes the golden test layer pins. Verify locally from the repository root:
`julia --startup-file=no --project=. run_examples.jl`.

## Input

```julia
## ============================================================================================
## FEATURE: the explicit close-marker line (a line that is only the close bracket).
## Labels are limited to :label1..:label5; the Visib actions are show / hide / discard.
## ============================================================================================
## The close-marker has TWO distinct effects, on two different axes — both demonstrated here at once:
##
##   (1) SCOPE — it closes only the INNERMOST currently-open meta-block. An OUTER block (a "chapter")
##       stays open, so a later, deeper meta-block still nests inside it and inherits its metadata.
##
##   (2) ATTACHMENT — it detaches the line IMMEDIATELY following it: that one line inherits no metadata.
##
## Setup (the lines below): a level-2 chapter applies :label1 and hides anything carrying :label1; a
## level-4 block nests inside it; then the close-marker; then a plain line; then a level-5 block.
##
## EXPECTED RENDER — see OutFileFolder/:
##   - the level-2 chapter line, line A, the level-4 block line, and line B  ->  HIDDEN (## -prefixed):
##       each carries :label1 (A directly; the level-4 block + B by inheritance), so hide{:label1} applies.
##   - line C, immediately after the close-marker                            ->  SHOWN: the close-marker
##       DETACHED it (axis 2), so it carries no :label1.
##   - the level-5 block line and line D                                     ->  HIDDEN: the close-marker
##       closed ONLY the level-4 block; the level-2 chapter is STILL OPEN, so the level-5 block nests in it
##       and inherits :label1 (axis 1).
##
##   The proof is "C shown but D hidden": the chapter resumed (axis 1) while the single line right after the
##   close-marker detached (axis 2). The two effects are independent.
##
## TRY IT: delete the close-marker line below and rerun — line C is then attached + nested, so it too is
##   hidden; this shows the close-marker is what detaches C.
## ============================================================================================
#~2 :label1 hide{ :label1 }
# A line adjacent to the level-2 chapter.
#~4 :label2
# B line adjacent to the level-4 block nested in the chapter.
#]
# C line immediately after the close-marker.
#~5 :label3
# D line adjacent to a level-5 block.
```

## Rendered output

```julia
## ============================================================================================
## FEATURE: the explicit close-marker line (a line that is only the close bracket).
## Labels are limited to :label1..:label5; the Visib actions are show / hide / discard.
## ============================================================================================
## The close-marker has TWO distinct effects, on two different axes — both demonstrated here at once:
##
##   (1) SCOPE — it closes only the INNERMOST currently-open meta-block. An OUTER block (a "chapter")
##       stays open, so a later, deeper meta-block still nests inside it and inherits its metadata.
##
##   (2) ATTACHMENT — it detaches the line IMMEDIATELY following it: that one line inherits no metadata.
##
## Setup (the lines below): a level-2 chapter applies :label1 and hides anything carrying :label1; a
## level-4 block nests inside it; then the close-marker; then a plain line; then a level-5 block.
##
## EXPECTED RENDER — see OutFileFolder/:
##   - the level-2 chapter line, line A, the level-4 block line, and line B  ->  HIDDEN (## -prefixed):
##       each carries :label1 (A directly; the level-4 block + B by inheritance), so hide{:label1} applies.
##   - line C, immediately after the close-marker                            ->  SHOWN: the close-marker
##       DETACHED it (axis 2), so it carries no :label1.
##   - the level-5 block line and line D                                     ->  HIDDEN: the close-marker
##       closed ONLY the level-4 block; the level-2 chapter is STILL OPEN, so the level-5 block nests in it
##       and inherits :label1 (axis 1).
##
##   The proof is "C shown but D hidden": the chapter resumed (axis 1) while the single line right after the
##   close-marker detached (axis 2). The two effects are independent.
##
## TRY IT: delete the close-marker line below and rerun — line C is then attached + nested, so it too is
##   hidden; this shows the close-marker is what detaches C.
## ============================================================================================
## #~2 :label1 hide{ :label1 }
## # A line adjacent to the level-2 chapter.
## #~4 :label2
## # B line adjacent to the level-4 block nested in the chapter.
## #]
# C line immediately after the close-marker.
## #~5 :label3
## # D line adjacent to a level-5 block.
```
