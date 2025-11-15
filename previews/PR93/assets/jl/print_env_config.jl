"""
    _downloads_toml(BENCH_ID)

Generate Markdown links for downloading benchmark environment files.

# Arguments
- `BENCH_ID`: Benchmark identifier string

# Returns
- `Markdown.MD`: Parsed Markdown content with download links for:
  - Project.toml (package dependencies)
  - Manifest.toml (complete dependency tree with versions)
  - Benchmark script (Julia script to run the benchmark)

# Details
Creates a formatted Markdown block with links to the benchmark environment files,
allowing users to reproduce the exact environment and results.
"""
function _downloads_toml(BENCH_ID)
    link_manifest = joinpath(@__DIR__, "benchmarks", BENCH_ID, "Manifest.toml")
    link_project = joinpath(@__DIR__, "benchmarks", BENCH_ID, "Project.toml")
    link_script = joinpath(@__DIR__, "benchmarks", BENCH_ID, "$BENCH_ID.jl")
    return Markdown.parse("""
    You can download the exact environment used for this benchmark:
    - 📦 [Project.toml]($link_project) - Package dependencies
    - 📋 [Manifest.toml]($link_manifest) - Complete dependency tree with versions
    - 📜 [Benchmark script]($link_script) - Julia script to run the benchmark

    These files allow you to reproduce the benchmark environment and results exactly.
    """)
end

"""
    _basic_metadata(bench_id)

Display basic benchmark metadata (timestamp, Julia version, OS, machine).

# Arguments
- `bench_id`: Benchmark identifier string

# Details
Prints formatted metadata including:
- 📅 Timestamp (UTC, ISO8601)
- 🔧 Julia version
- 💻 Operating system
- 🖥️ Machine hostname

Returns nothing if benchmark data is unavailable.
"""
function _basic_metadata(bench_id)
    bench_data = _get_bench_data(bench_id)
    if bench_data !== nothing
        meta = get(bench_data, "metadata", Dict())
        for (label, key) in (
            ("📅 Timestamp", "timestamp"),
            ("🔧 Julia version", "julia_version"),
            ("💻 OS", "os"),
            ("🖥️ Machine", "machine"),
        )
            value = string(get(meta, key, "n/a"))
            println(rpad(label, key=="machine" ? 16 : 17), ": ", value)
        end
    else
        println("⚠️  No benchmark data available")
    end
    return nothing
end

"""
    _bench_data(bench_id)

Display detailed Julia version information from benchmark metadata.

# Arguments
- `bench_id`: Benchmark identifier string

# Details
Prints the complete `versioninfo()` output that was captured during the benchmark run.
This includes Julia version, platform, and build information.
"""
function _bench_data(bench_id)
    bench_data = _get_bench_data(bench_id)
    if bench_data !== nothing
        meta = get(bench_data, "metadata", Dict())
        versioninfo_text = get(meta, "versioninfo", "No version info available")
        println(versioninfo_text)
    else
        println("⚠️  No benchmark data available")
    end
    return nothing
end

"""
    _package_status(bench_id)

Display package status from benchmark metadata.

# Arguments
- `bench_id`: Benchmark identifier string

# Details
Prints the `Pkg.status()` output that was captured during the benchmark run.
Shows the list of active project dependencies and their versions.
"""
function _package_status(bench_id)
    bench_data = _get_bench_data(bench_id)
    if bench_data !== nothing
        meta = get(bench_data, "metadata", Dict())
        pkg_status = get(meta, "pkg_status", "No package status available")
        println(pkg_status)
    else
        println("⚠️  No benchmark data available")
    end
    return nothing
end

"""
    _complete_manifest(bench_id)

Display complete package manifest from benchmark metadata.

# Arguments
- `bench_id`: Benchmark identifier string

# Details
Prints the complete `Pkg.status(mode=PKGMODE_MANIFEST)` output that was captured
during the benchmark run. Shows all dependencies including transitive dependencies
with their exact versions.
"""
function _complete_manifest(bench_id)
    bench_data = _get_bench_data(bench_id)
    if bench_data !== nothing
        meta = get(bench_data, "metadata", Dict())
        pkg_manifest = get(meta, "pkg_manifest", "No manifest available")
        println(pkg_manifest)
    else
        println("⚠️  No benchmark data available")
    end
    return nothing
end

"""
    _print_config(bench_id)

Render benchmark configuration parameters as Markdown.

# Arguments
- `bench_id`: Benchmark identifier string

# Returns
- `Markdown.MD`: Formatted configuration block
"""
function _print_config(bench_id)
    bench_data = _get_bench_data(bench_id)
    if bench_data === nothing
        return Markdown.parse("⚠️  No configuration available because the benchmark file is missing.")
    end

    meta = get(bench_data, "metadata", Dict())
    config = get(meta, "configuration", nothing)

    if config === nothing
        return Markdown.parse("⚠️  No configuration recorded in the benchmark file.")
    end

    problems = get(config, "problems", [])
    solver_models = get(config, "solver_models", [])
    grid_sizes = get(config, "grid_sizes", [])
    disc_methods = get(config, "disc_methods", [])
    tol = get(config, "tol", "n/a")
    ipopt_mu_strategy = get(config, "ipopt_mu_strategy", "n/a")
    max_iter = get(config, "max_iter", "n/a")
    max_wall_time = get(config, "max_wall_time", "n/a")

    solvers = Set{String}()
    models = Set{String}()
    for pair in solver_models
        if isa(pair, Dict)
            solver = get(pair, "first", "")
            push!(solvers, string(solver))
            for model in get(pair, "second", [])
                push!(models, string(model))
            end
        elseif isa(pair, Pair)
            push!(solvers, string(pair.first))
            for model in pair.second
                push!(models, string(model))
            end
        end
    end

    solvers_str = isempty(solvers) ? "n/a" : join(replace.(sort(collect(solvers)), "_" => "\\_"), ", ")
    models_str = isempty(models) ? "n/a" : join(replace.(sort(collect(models)), "_" => "\\_"), ", ")
    problems_str = isempty(problems) ? "n/a" : join(replace.(string.(problems), "_" => "\\_"), ", ")
    grid_sizes_str = isempty(grid_sizes) ? "n/a" : join(string.(grid_sizes), ", ")
    disc_methods_str = isempty(disc_methods) ? "n/a" : join(replace.(string.(disc_methods), "_" => "\\_"), ", ")

    lines = String[
        "- **Problems:** $problems_str",
        "- **Solvers:** $solvers_str",
        "- **Models:** $models_str",
        "- **Grid sizes:** $grid_sizes_str discretization points",
        "- **Discretization:** $disc_methods_str method",
        "- **Tolerance:** $(string(tol))",
        "- **Ipopt strategy:** $(string(ipopt_mu_strategy)) barrier parameter",
        "- **Limits:** $(string(max_iter)) iterations max, $(string(max_wall_time))s wall time",
    ]

    return Markdown.parse(join(lines, "\n"))
end