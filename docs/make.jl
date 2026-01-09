using Documenter
using CTBenchmarks

# ═══════════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════════

# Draft mode: if true, @example blocks in markdown are not executed
draft = false
debug = false

# Problems to exclude from draft mode (will still execute their @example blocks)
exclude_problems_from_draft = Symbol[
# :beam   # example: exclude beam from draft docs
]

# ═══════════════════════════════════════════════════════════════════════════════
# Setup: Copy environment files for reproducibility
# ═══════════════════════════════════════════════════════════════════════════════

mkpath(joinpath(@__DIR__, "src", "assets", "toml"))
for filename in ("Manifest.toml", "Project.toml")
    cp(
        joinpath(@__DIR__, filename),
        joinpath(@__DIR__, "src", "assets", "toml", filename);
        force=true,
    )
end

# ═══════════════════════════════════════════════════════════════════════════════
# Load documentation utilities
# ═══════════════════════════════════════════════════════════════════════════════

# Load all documentation utilities (templates, plotting, figure generation, etc.)
include(joinpath(@__DIR__, "src", "docutils", "utils.jl"))
set_doc_debug!(debug)

# ═══════════════════════════════════════════════════════════════════════════════
# Repository configuration
# ═══════════════════════════════════════════════════════════════════════════════

repo_url = "github.com/control-toolbox/CTBenchmarks.jl"

# ═══════════════════════════════════════════════════════════════════════════════
# Generate and process templates, then build documentation
# ═══════════════════════════════════════════════════════════════════════════════

with_processed_template_problems(
    joinpath(@__DIR__, "src");
    draft=draft,
    exclude_problems_from_draft=exclude_problems_from_draft,
) do core_problems

    # ───────────────────────────────────────────────────────────────────────────
    # Build list of pages to exclude from size threshold checks
    # ───────────────────────────────────────────────────────────────────────────

    size_threshold_ignore = [
        "index.md", joinpath("core", "cpu.md"), joinpath("core", "gpu.md")
    ]
    for problem in core_problems
        push!(size_threshold_ignore, joinpath("core", "problems", "$(problem).md"))
    end

    # ───────────────────────────────────────────────────────────────────────────
    # Build navigation menu for core problems
    # ───────────────────────────────────────────────────────────────────────────

    core_problems_menu = Pair{String,String}[]
    for problem in core_problems
        push!(core_problems_menu, problem => joinpath("core", "problems", "$(problem).md"))
    end

    # ───────────────────────────────────────────────────────────────────────────
    # Process template files and build documentation
    # ───────────────────────────────────────────────────────────────────────────

    with_processed_templates(
        [
            joinpath("core", "cpu.md"),
            joinpath("core", "gpu.md"),
            joinpath("core", "problems"),
        ],
        joinpath(@__DIR__, "src"),
        joinpath(@__DIR__, "src", "assets", "md"),
    ) do
        # Build the documentation with Documenter.jl
        makedocs(;
            draft=draft,
            remotes=nothing,
            warnonly=true,
            sitename="CTBenchmarks",
            format=Documenter.HTML(;
                ansicolor=true,
                repolink="https://" * repo_url,
                prettyurls=false,
                size_threshold_ignore=size_threshold_ignore,
                assets=[
                    asset("https://control-toolbox.org/assets/css/documentation.css"),
                    asset("https://control-toolbox.org/assets/js/documentation.js"),
                    joinpath("assets", "js", "ctbenchmarks-details.js"),
                    joinpath("assets", "css", "ctbenchmarks-details.css"),
                ],
            ),
            pages=[
                "Introduction" => "index.md",
                "Performance Profile" => "performance_profile.md",
                "Core benchmarks" => [
                    "CPU" => joinpath("core", "cpu.md"),
                    "GPU" => joinpath("core", "gpu.md"),
                    "Problems" => core_problems_menu,
                ],
                DocumenterReference.automatic_reference_documentation(;
                    subdirectory="api",
                    modules=[CTBenchmarks],
                    exclude=Symbol[:include, :eval],
                ),
                "Developers Guidelines" => [
                    "Add a New Benchmark" => "add_benchmark.md",
                    "Add a Custom Profile" => "add_performance_profile.md",
                    "Documentation Process" => "documentation_process.md",
                ],
            ],
        )
    end
end

# ═══════════════════════════════════════════════════════════════════════════════
# Deploy documentation to GitHub Pages
# ═══════════════════════════════════════════════════════════════════════════════

deploydocs(; repo=repo_url * ".git", devbranch="main", push_preview=true)
