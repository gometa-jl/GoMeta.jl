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
## # This `Line` should still be "hidden" / commented out. ## #~ hide
# NOTE: Input line 15 will be missing from the output file! ## @: Input line 16.

#~2 :label3 :label5 show{ !:label5} ## @: Input line 18.
#~ hide{:label1} ## This comment ends this meta `Block` at level 2 [`#~2`].

#~3 discard{:label4} :label4 ## This comment ends this meta `Block` at level 3.
## # Here starts a new `Block` of text ## @: Input line 35.
## #       which receives label4 from line 34
## #       and label3 and label5 from line 18
## #       and receives label1 from line 8

## # This `Block` does NOT get "discarded" since label4 has
## #       NOT been applied yet when `discard{:label4}` [line 34] is issued.
## # Instead this `Block` gets "hidden" due to circumstance that it is
## #       text and contains meta, therefore receiving label1
## #       and consequently inheriting the `hide` from line 19.
## NOTE: Line 39, however, will get "discarded"
##      since this `Line` inherits label4 due to the "#~" at its end
##      and consequently `discard{:label4}` [line 34] gets applied here.
## @: Input line 49. It is at the end of this `Block` of text.
