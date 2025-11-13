using Documenter
using CTBenchmarks

# Ensure documentation assets exist in the rendered site
mkpath(joinpath(@__DIR__, "src", "assets", "toml"))
for filename in ("Manifest.toml", "Project.toml")
    # Copy the documentation environment files for reproducibility
    cp(
        joinpath(@__DIR__, filename),
        joinpath(@__DIR__, "src", "assets", filename);
        force=true,
    )
end

# Process template files before building documentation
include(joinpath(@__DIR__, "src", "assets", "jl", "template_processor.jl"))

repo_url = "github.com/control-toolbox/CTBenchmarks.jl"

# Process templates, build documentation, and clean up generated files
with_processed_templates(
    [
        "benchmark-core-cpu.md",
        "benchmark-core-gpu.md",
        "benchmark-core-beam.md",
    ],  # List of template files to process
    joinpath(@__DIR__, "src"),
    joinpath(@__DIR__, "src", "assets", "templates"),
) do
    # Configure and build the documentation set
    makedocs(;
        remotes=nothing,
        warnonly=:cross_references,
        sitename="CTBenchmarks",
        format=Documenter.HTML(;
            ansicolor=true,
            repolink="https://" * repo_url,
            prettyurls=false,
            size_threshold_ignore=[
                "index.md", 
                "benchmark-core-cpu.md",
                "benchmark-core-gpu.md",
                "benchmark-core-beam.md",
            ],
            assets=[
                asset("https://control-toolbox.org/assets/css/documentation.css"),
                asset("https://control-toolbox.org/assets/js/documentation.js"),
            ],
        ),
        # Expose the available documentation pages in the navigation sidebar
        pages=[
            "Introduction" => "index.md",
            "Core benchmarks" => [
                "CPU" => "benchmark-core-cpu.md",
                "GPU" => "benchmark-core-gpu.md",
                "By Problems" => [
                    "Beam" => "benchmark-core-beam.md",
                ]
            ],
            "API" => "api.md",
            "Development Guidelines" => "dev.md",
        ],
    )
end

# Publish documentation previews to GitHub Pages
deploydocs(; repo=repo_url * ".git", devbranch="main", push_preview=true)
