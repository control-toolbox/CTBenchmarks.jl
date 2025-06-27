using Documenter

mkpath("./docs/src/assets")
cp("./docs/Manifest.toml", "./docs/src/assets/Manifest.toml", force = true)
cp("./docs/Project.toml", "./docs/src/assets/Project.toml", force = true)

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
    pages=["Introduction" => "index.md"],
)

deploydocs(; repo=repo_url * ".git", devbranch="main")
