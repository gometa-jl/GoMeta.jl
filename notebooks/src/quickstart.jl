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
result = GoMeta.goMeta(bytes)             # ONE run: BLS parses the file into the BLS Component tree; the GoMeta Engine evaluates the altValues over it -- ONE object delivered, GoMetaDelivery, carrying both MAIN PRODUCTS
result.status == GoMeta.PROCESS_OK || error("processing failed")

# ## The delivered object — the BLS Component tree
# `blsComponentTree` is the BLS Component tree the run was evaluated over — provided by
# BLS itself; it reaches an Extension as the part `blsComponentTree`, not through any
# function of the GoMeta Engine; an Extension travels it with BLS's own public functions —
# the door (`docs/public-api.md` §1.2): `children` walks down (the File's Blocks, a Block's
# Lines, a Line's Segments), `kind` names a Component's flavor (:Meta / :Code / :Text — a
# metaLine is a Line of flavor Meta), `content` gives the verbatim text of the piece.

tree = result.blsComponentTree
for block in GoMeta.BLS.children(tree), line in GoMeta.BLS.children(tree, block)
    GoMeta.BLS.kind(line) === :Meta || continue
    println(String(GoMeta.BLS.content(tree, line)))   # every metaLine of the example, from the tree and nothing else
end

# ## The delivered object — the evaluated Alterant values
# `altValues_evals` is the part of the delivered object that carries the evaluated
# Alterant values, per piece of the file; the Engine's reader returns it as rows.
# Labels arrive as `:label_label1`..`:label_label5`; the evaluated visibility as `:visib`.

evals = GoMeta.readAltValuesEvals(result.altValues_evals)
first(evals, 5)

# ## The render — a development tool
# The basic renderer is a development tool, not part of the Engine's output (R-V04B-24):
# the share-view of the file, to inspect a run by eye. Hidden lines come back
# `## `-commented; discarded lines are gone.

include(joinpath(pkgdir(GoMeta), "devtools", "load_basic_renderer.jl"))   # loaded through its ONE path, at the top level
out = Main.BasicRenderer.outputs(result)  # (blsStructure_bytes, render_bytes) — the tool's pair
print(String(copy(out.render_bytes)))

# ## Find it again
# The shipped query demo indexes exactly these rows — the part `altValues_evals`, read
# through the reader — across the whole committed corpus; run it yourself:
# `julia --startup-file=no --project=. find_by_label.jl label5`

count(e -> e[2] === :label_label5 && e[3] === true, evals)

#~2 :label5
# Synthetic PRIVATE sentinel: this note never reaches the derived notebook —
# diff this source against it and see.
