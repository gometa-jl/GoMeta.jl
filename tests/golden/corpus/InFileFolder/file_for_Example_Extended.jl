## Test File
## NOTE: I've addes some markers to this file such as: "## @: Input line 2"
##      They have nothing to do with `GoMeta` [yet].
##      They are simply meant to assist orientation when
##      comparing the input file to the output file.

#~ discard{ :label2 , isCode} ## This is a comment within a meta `Block`.
#~ :label1{ isText && containsMeta }
## The following meta `Line` within this `Block` will be ignored due to the `!`.
#~! discard{ isMeta } ## This `Line` of meta ends this `Block` of meta.

# With this `Line` of text starts a new `Block` of text. ## @: Input line 12.
# This `Block` is NOT attached to metadata - it does NOT inherit metadata.
# This `Line` should still be "hidden" / commented out. #~ hide
# ... and this `Line` should still be "discarded" / removed #~ discard
# NOTE: Input line 15 will be missing from the output file! ## @: Input line 16.

#~2 :label3 :label5 show{ !:label5} ## @: Input line 18.
#~ hide{:label1} ## This comment ends this meta `Block` at level 2 [`#~2`].
using Plots ## This `Segment` is a comment within a `Block` of code. ## @: Input line 20.
## This `Block` of code starts with `using Plots` above on line 20.
## This `Block` is ATTACHED to metadata - it inherits metadata from above.
## Therefore, this code `Block` receives label3 and label5 from input line 18.
## `show` [input line 18] does NOT get applied
##      as this can only happen if label5 has NOT been applied: `{!:label5}`

## Instead, this code `Block` inherits `discard` from input line 7 above
##      since it is code i.e.: `isCode`. ## @: Input line 28.

println("!!! NOTE !!! Only Code and Text `Block`s may contain empty lines.")
println("\t Whereas an empty line after a meta `Line` starts a new `Block`.")
## @: Input line 32. It marks the end of this `Block` of code.

#~3 discard{:label4} :label4 ## This comment ends this meta `Block` at level 3.
# Here starts a new `Block` of text ## @: Input line 35.
#       which receives label4 from line 34
#       and label3 and label5 from line 18
#       and receives label1 from line 8
#       since it is a `Block` of text containing this meta here: #~

# This `Block` does NOT get "discarded" since label4 has
#       NOT been applied yet when `discard{:label4}` [line 34] is issued.
# Instead this `Block` gets "hidden" due to circumstance that it is
#       text and contains meta, therefore receiving label1
#       and consequently inheriting the `hide` from line 19.
## NOTE: Line 39, however, will get "discarded"
##      since this `Line` inherits label4 due to the "#~" at its end
##      and consequently `discard{:label4}` [line 34] gets applied here.
## @: Input line 49. It is at the end of this `Block` of text.

#~2 :label2 ## This is a comment within this one-`Line` meta `Block`.
md"""
This is a `Block` of markdown text.

It is ATTACHED to the one-`Line` meta `Block` on line 51.
It therefore inherits label2.

This meta `Block`, however, neither inherits from the meta `Block`
starting with "#~3" nor that further above starting with "#~2".

It DOES inherit from the first meta `Block` starting on input line 7.
Which is why it gets "discarded" - due to `discard{:label2}`.
"""
