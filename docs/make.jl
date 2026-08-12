# docs/make.jl — builds the GoMeta documentation site with Documenter.jl.
#
# The page sources are the committed files under docs/ (index.md, the three references,
# and the two derived-manual pages — all browsable directly in the repository), plus the
# generated gallery pages under docs/gallery/. Documenter builds from docs/src/, so this
# script stages a copy of each page there first; docs/src/ and docs/build/ are generated
# directories and are never committed (see .gitignore).
#
# Local build, from the repository root:
#   julia --startup-file=no --project=docs -e 'using Pkg; Pkg.instantiate()'   # once
#   julia --startup-file=no --project=docs docs/make.jl
# The built site is browsable at docs/build/index.html. Site deployment is a
# repository-level step and is not part of this script.

using Documenter

const DOCS  = @__DIR__
const PAGES = ["index.md", "SYNTAX-AND-SEMANTICS.md", "public-api.md", "CANONICAL-OUTPUT.md",
               "montecarlo-full.md", "montecarlo-reader.md"]

# docs/src/ is wholly generated: clear it first so a page later removed or renamed in
# PAGES cannot leave a stale staged copy behind (Documenter renders unlisted files too).
rm(joinpath(DOCS, "src"); force = true, recursive = true)
mkpath(joinpath(DOCS, "src"))
for page in PAGES
    cp(joinpath(DOCS, page), joinpath(DOCS, "src", page); force = true)
end
# the logo + favicon assets (docs/assets/): Documenter auto-detects assets/logo.svg,
# assets/logo-dark.svg and assets/favicon.ico by name once they sit in src/assets/
mkpath(joinpath(DOCS, "src", "assets"))
for a in filter(f -> !startswith(f, "."), readdir(joinpath(DOCS, "assets")))
    cp(joinpath(DOCS, "assets", a), joinpath(DOCS, "src", "assets", a); force = true)
end
# the examples gallery (docs/gallery/*.md): staged the same way, one directory down
mkpath(joinpath(DOCS, "src", "gallery"))
for page in filter(f -> endswith(f, ".md"), readdir(joinpath(DOCS, "gallery")))
    cp(joinpath(DOCS, "gallery", page), joinpath(DOCS, "src", "gallery", page); force = true)
end

makedocs(
    sitename = "GoMeta",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
        canonical  = "https://gometa.dev",
        repolink   = "https://github.com/gometa-jl/GoMeta.jl",
        edit_link  = nothing,
    ),
    remotes = nothing,
    pages = [
        "Overview" => "index.md",
        "Syntax & semantics" => "SYNTAX-AND-SEMANTICS.md",
        "Examples gallery" => [
            "gallery/index.md",
            "gallery/file_for_Example_Extended.md",
            "gallery/file_for_Example_Proposal_JuliaCon.md",
            "gallery/feature_explicit_close.md",
            "gallery/feature_order_of_application.md",
            "gallery/feature_contiguous_metablock.md",
            "gallery/feature_contiguous_metablock_blankline.md",
            "gallery/feature_triple_tilde.md",
        ],
        "Derived manual" => ["montecarlo-full.md", "montecarlo-reader.md"],
        "Public API + error modes" => "public-api.md",
        "Canonical output" => "CANONICAL-OUTPUT.md",
    ],
)
