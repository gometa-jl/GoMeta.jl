# # GoMeta quickstart
#
# One source, two faces: this file runs as a plain script, and the quickstart
# notebook beside it is DERIVED from this same file's `#~` marks by
# `notebooks_from_source.jl` — the onboarding artifact demonstrates the claim
# it teaches. Either face runs from a repository checkout, top to bottom.
#
# Label legend for this file:
#   :label1 = parameters (the setup cell)   :label5 = private
#~ discard{ :label5 }

# ## Process one committed example
# The setup cell finds the repository root from either launch point (the
# checkout root for the script, `notebooks/` for the derived notebook) and
# activates the checkout's project environment for the kernel.

#~2 :label1
root = isdir("examples") ? "." : ".."
import Pkg; Pkg.activate(root; io = devnull); Pkg.instantiate(; io = devnull)
import GoMeta
example = joinpath(root, "examples", "InFileFolder", "file_for_Example_Proposal_JuliaCon.jl")

bytes  = read(example)
result = GoMeta.goMeta(bytes)             # parse -> absorb -> evaluate -> apply -> emit
result.status == GoMeta.PROCESS_OK || error("processing failed")

# ## The render: the share-view of the file
# Hidden lines come back `## `-commented; discarded lines are gone.

out = GoMeta.outputs(result)              # (blsStructure_bytes, render_bytes)
print(String(copy(out.render_bytes)))

# ## The evals: the queryable per-cell surface
# Labels arrive as `:label_label1`..`:label_label5`; the per-cell visibility
# verdict as `:visib`.

evals = GoMeta.altValues_evals(result)
first(evals, 5)

# ## Find it again
# The shipped query demo indexes exactly this surface across the whole
# committed corpus — run it yourself:
# `julia --startup-file=no --project=. find_by_label.jl label5`

count(e -> e[2] === :label_label5 && e[3] === true, evals)

#~2 :label5
# Synthetic PRIVATE sentinel: this note never reaches the derived notebook —
# diff this source against it and see.
