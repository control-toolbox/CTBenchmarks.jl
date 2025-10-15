using Documenter

# Ensure documentation assets exist in the rendered site
mkpath(joinpath(@__DIR__, "src", "assets"))
for filename in ("Manifest.toml", "Project.toml")
    # Copy the documentation environment files for reproducibility
    cp(
        joinpath(@__DIR__, filename),
        joinpath(@__DIR__, "src", "assets", filename);
        force=true,
    )
end

# Process template files before building documentation
include(joinpath(@__DIR__, "src", "assets", "template_processor.jl"))
process_templates(
    ["benchmark-core"],  # List of template files to process
    joinpath(@__DIR__, "src"),
    joinpath(@__DIR__, "src", "assets")
)

repo_url = "github.com/control-toolbox/CTBenchmarks.jl"

# Configure and build the documentation set
makedocs(;
    remotes=nothing,
    warnonly=:cross_references,
    sitename="CTBenchmarks",
    format=Documenter.HTML(;
        repolink="https://" * repo_url,
        prettyurls=false,
        size_threshold_ignore=["index.md"],
        assets=[
            asset("https://control-toolbox.org/assets/css/documentation.css"),
            asset("https://control-toolbox.org/assets/js/documentation.js"),
        ],
    ),
    # Expose the available documentation pages in the navigation sidebar
    pages=["Introduction" => "index.md", "Core benchmark" => "benchmark-core.md"],
)

# Publish documentation previews to GitHub Pages
deploydocs(; repo=repo_url * ".git", devbranch="main", push_preview=true)
