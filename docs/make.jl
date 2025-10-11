using Documenter

# For reproducibility
mkpath(joinpath(@__DIR__, "src", "assets"))
for filename in ("Manifest.toml", "Project.toml")
    cp(
        joinpath(@__DIR__, filename),
        joinpath(@__DIR__, "src", "assets", filename);
        force=true,
    )
end

repo_url = "github.com/control-toolbox/CTBenchmarks.jl"

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
    pages=["Introduction" => "index.md", "Core benchmark" => "benchmark-core.md"],
)

deploydocs(; repo=repo_url * ".git", devbranch="main", push_preview=true)
