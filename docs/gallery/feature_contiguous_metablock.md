# `feature_contiguous_metablock.jl`

**Proves:** contiguous metaLines = one block (depth = the first line's); cross-block order-of-application

*(The "proves" line is this example's row in the [syntax reference](../SYNTAX-AND-SEMANTICS.md)
§11 proof-set table; every rule there cites a runnable committed example.)*

Committed pair: `examples/InFileFolder/feature_contiguous_metablock.jl` → `examples/OutFileFolder/feature_contiguous_metablock.jl` — the same
bytes the golden test layer pins. Verify locally from the repository root:
`julia --startup-file=no --project=. run_examples.jl`.

## Input

```julia
## ============================================================================================
## FEATURE: contiguous metaLines form ONE metaBlock; order-of-application then spans blocks.
## Labels are limited to :label1..:label5; the Visib actions are show / hide / discard.
## ============================================================================================
## Two linked facts are shown together here:
##
## (1) CONTIGUOUS metaLines (no content line between them) are ONE metaBlock. The two meta-lines below
##     -- the file-level hide rule, then the :label1 line -- are a SINGLE block, and the block's depth is
##     that of its FIRST line. (Structurally this parses as one Meta block spanning both
##     lines, tagged depth1; the second line's "2" is recorded only at the line level and is subsumed.)
##
## (2) ORDER-OF-APPLICATION ACROSS BLOCKS: within that one block, hide{:label1} is issued BEFORE :label1
##     is applied, so the block's OWN attached content (line A) is NOT hidden. But the hide{:label1} rule
##     STANDS; a LATER block that comes to carry :label1 (by inheritance) IS hidden by it.
##
## EXPECTED RENDER — see OutFileFolder/:
##   - line A (attached to the contiguous block)  ->  SHOWN: hide{:label1} was evaluated before :label1,
##       so it did not fire on this block's own content.
##   - the second meta-line and line B            ->  HIDDEN: that block is a NEW block that inherits
##       :label1 from the block above, so the standing hide{:label1} now fires.
##
##   The instructive surprise: line A carries :label1 yet is SHOWN, while line B (no :label1 of its own)
##   is HIDDEN -- because :label1 reaches B by inheritance and the hide rule only "sees" it there.
##
## TRY IT (verified): insert an empty line between the two meta-lines below. That single blank line splits
##   them into TWO blocks -- hide{:label1} alone (still depth 1) and :label1 now in its OWN depth-2 block --
##   and FLIPS both content lines, for two different reasons:
##     * line A becomes HIDDEN: hide{:label1} and :label1 are no longer in one block, so the in-block order
##       protection is gone and the standing hide{:label1} now fires on A.
##     * line B becomes SHOWN: :label1 dropped to depth 2, where the sibling depth-2 :label2 block
##       SUPERSEDES it, so B no longer inherits :label1.
## ============================================================================================
#~ hide{ :label1 }
#~2 :label1
# A line attached to the contiguous meta-block above.
#~2 :label2
# B line under a later meta-block that inherits :label1.
```

## Rendered output

```julia
## ============================================================================================
## FEATURE: contiguous metaLines form ONE metaBlock; order-of-application then spans blocks.
## Labels are limited to :label1..:label5; the Visib actions are show / hide / discard.
## ============================================================================================
## Two linked facts are shown together here:
##
## (1) CONTIGUOUS metaLines (no content line between them) are ONE metaBlock. The two meta-lines below
##     -- the file-level hide rule, then the :label1 line -- are a SINGLE block, and the block's depth is
##     that of its FIRST line. (Structurally this parses as one Meta block spanning both
##     lines, tagged depth1; the second line's "2" is recorded only at the line level and is subsumed.)
##
## (2) ORDER-OF-APPLICATION ACROSS BLOCKS: within that one block, hide{:label1} is issued BEFORE :label1
##     is applied, so the block's OWN attached content (line A) is NOT hidden. But the hide{:label1} rule
##     STANDS; a LATER block that comes to carry :label1 (by inheritance) IS hidden by it.
##
## EXPECTED RENDER — see OutFileFolder/:
##   - line A (attached to the contiguous block)  ->  SHOWN: hide{:label1} was evaluated before :label1,
##       so it did not fire on this block's own content.
##   - the second meta-line and line B            ->  HIDDEN: that block is a NEW block that inherits
##       :label1 from the block above, so the standing hide{:label1} now fires.
##
##   The instructive surprise: line A carries :label1 yet is SHOWN, while line B (no :label1 of its own)
##   is HIDDEN -- because :label1 reaches B by inheritance and the hide rule only "sees" it there.
##
## TRY IT (verified): insert an empty line between the two meta-lines below. That single blank line splits
##   them into TWO blocks -- hide{:label1} alone (still depth 1) and :label1 now in its OWN depth-2 block --
##   and FLIPS both content lines, for two different reasons:
##     * line A becomes HIDDEN: hide{:label1} and :label1 are no longer in one block, so the in-block order
##       protection is gone and the standing hide{:label1} now fires on A.
##     * line B becomes SHOWN: :label1 dropped to depth 2, where the sibling depth-2 :label2 block
##       SUPERSEDES it, so B no longer inherits :label1.
## ============================================================================================
#~ hide{ :label1 }
#~2 :label1
# A line attached to the contiguous meta-block above.
## #~2 :label2
## # B line under a later meta-block that inherits :label1.
```
