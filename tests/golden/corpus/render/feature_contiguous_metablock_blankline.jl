## ============================================================================================
## FEATURE (variant of feature_contiguous_metablock.jl): the SAME content, but with a BLANK LINE
## inserted between the two meta-lines. That one blank line breaks the single contiguous block into TWO
## separate blocks — and FLIPS both content lines relative to the no-blank version. Compare the two
## committed outputs side by side.
## ============================================================================================
## Why both flip (each for a different reason):
##   - line A becomes HIDDEN: hide{:label1} and :label1 are now in SEPARATE blocks, so the in-block
##     order-of-application protection is gone; the standing hide{:label1} fires on A (which has :label1).
##   - line B becomes SHOWN: :label1 now lives in its OWN depth-2 block, which the following sibling
##     depth-2 :label2 block SUPERSEDES, so B no longer inherits :label1.
##
## EXPECTED RENDER — see OutFileFolder/: line A HIDDEN, line B SHOWN.
## (feature_contiguous_metablock.jl, with NO blank line, renders the opposite: A SHOWN, B HIDDEN.)
## ============================================================================================
#~ hide{ :label1 }

## #~2 :label1
## # A line attached to the (now separate) :label1 block.
#~2 :label2
# B line under the second, sibling block.
