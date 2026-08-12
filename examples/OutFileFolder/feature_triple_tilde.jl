## ============================================================================================
## FEATURE: depth is set by the NUMBER OF TILDES. "#~~~" means depth 3 — exactly like "#~3".
## Labels are limited to :label1..:label5; the Visib actions are show / hide / discard.
## ============================================================================================
## A digit after the tildes overrides the count (so "#~3" is also depth 3); this example shows the
## pure tilde-count form. The proof of depth is structural: the engine's parsed tree for this file
## tags the "#~~~" block as depth3.
##
## Setup: a depth-2 chapter hides anything carrying :label1; the "#~~~" block (depth 3) is DEEPER, so it
## nests inside the chapter and inherits :label1.
##
## EXPECTED RENDER (verified): the chapter line + line A are hidden (carry :label1); the "#~~~" line +
## line B are also hidden — the depth-3 block nests in the depth-2 chapter (3 > 2) and inherits :label1.
## ============================================================================================
## #~2 :label1 hide{ :label1 }
## # A line attached to the depth-2 chapter.
## #~~~ :label2
## # B line under the "#~~~" (depth-3) block nested in the chapter.
