using Documenter
using CTBenchmarks

# Ensure documentation assets exist in the rendered site
mkpath(joinpath(@__DIR__, "src", "assets", "toml"))
for filename in ("Manifest.toml", "Project.toml")
    # Copy the documentation environment files for reproducibility
    cp(
        joinpath(@__DIR__, filename),
        joinpath(@__DIR__, "src", "assets", "toml", filename);
        force=true,
    )
end

# Process template files before building documentation
include(joinpath(@__DIR__, "src", "assets", "jl", "template_processor.jl"))

# Automatic API reference generation (adapted from JuMP)
include(joinpath(@__DIR__, "src", "assets", "jl", "DocumenterReference.jl"))

repo_url = "github.com/control-toolbox/CTBenchmarks.jl"

# Process templates, build documentation, and clean up generated files
with_processed_template_problems() do
    with_processed_templates(
        [
            joinpath("core", "cpu.md"),
            joinpath("core", "gpu.md"),
            joinpath("core", "problems"),
        ],  # List of template files to process
        joinpath(@__DIR__, "src"),
        joinpath(@__DIR__, "src", "assets", "md"),
    ) do
        # Configure and build the documentation set
        makedocs(;
            remotes=nothing,
            warnonly=true,
            sitename="CTBenchmarks",
            format=Documenter.HTML(;
                ansicolor=true,
                repolink="https://" * repo_url,
                prettyurls=false,
                size_threshold_ignore=[
                    "index.md", 
                    joinpath("core", "cpu.md"),
                    joinpath("core", "gpu.md"),
                    joinpath("core", "problems", "beam.md"),
                ],
                assets=[
                    asset("https://control-toolbox.org/assets/css/documentation.css"),
                    asset("https://control-toolbox.org/assets/js/documentation.js"),
                    joinpath("assets", "js", "ctbenchmarks-details.js"),
                ],
            ),
            # Expose the available documentation pages in the navigation sidebar
            pages=[
                "Introduction" => "index.md",
                "Core benchmarks" => [
                    "CPU" => joinpath("core", "cpu.md"),
                    "GPU" => joinpath("core", "gpu.md"),
                    "Problems" => [
                        "Beam" => joinpath("core", "problems", "beam.md"),
                    ]
                ],
                DocumenterReference.automatic_reference_documentation(
                    subdirectory="api",
                    modules=[CTBenchmarks],
                    # Exclude internal or confusing bindings from API reference
                    exclude=Symbol[
                        :include,  # module-local include from Base
                        :eval,     # module-local eval from Base
                    ],
                ),
                "Development Guidelines" => "dev.md",
            ],
        )
    end
end

# Publish documentation previews to GitHub Pages
deploydocs(; repo=repo_url * ".git", devbranch="main", push_preview=true)
