#~ hide{ :label4 , isCode } ## This is a comment within a `Block` of meta.
## The above `Line` of meta initiated this `Block` of meta.
#~ :label1{ (isText && containsMeta), isMeta } ## This meta `Block` ends here.

# This `Line` of text starts a new `Block` of text.
# This `Block` is NOT attached to metadata - it does NOT INHERIT metadata.

#~2 :label5 show{ !:label5} ## This is line 9. It is a one-line meta `Block`.
## using Plots ## This `Line` starts a new `Block` of code.
## This code `Block` is ATTACHED to metadata - it inherits metadata from above.
## Therefore, this code `Block` receives label5.
## `show` from line 9 above does NOT get applied to this `Block`
##      as this can only happen
##      if label5 has NOT been applied. Note `{!:label5}` following `show`.
## This code `Block` inherits `hide` from line 1 above
##      since this is a code `Block` and due to: `{isCode}` following `hide`.

## println("!!! NOTE !!! Only Code and Text `Block`s may contain empty lines.")
## println("\t Whereas an empty line after a meta `Line` starts a new `Block`.")

## #~3 :label4 discard{:label3} :label3
## # This `Block` of text receives label4
## #       plus label5 from further above
## #       plus label1 since it `isText` AND `containsMeta` [last statement].
## # It is NOT "discarded" since label3 has not been applied yet
## #       when `discard{:label3}` is issued.
## # Only after that it receives label3.
## # Instead, it gets hidden due to label4 and `hide{:label4}` on line 1.
# This `Line`, however, will NOT get hidden. #~ show

#~2 :label5
md"""
## This is a `Block` of markdown text. ## #~ hide
"""