using CTBenchmarks
using JSON
using DataFrames
using Markdown
using Dates
using Printf
using Plots
using Plots.PlotMeasures
using Statistics

"""
    _get_bench_data(bench_id::AbstractString)

Retrieve benchmark data from a JSON file based on the benchmark ID.

# Arguments
- `bench_id::AbstractString`: Identifier for the benchmark (e.g., "core-ubuntu-latest")

# Returns
- `Dict` or `nothing`: Parsed benchmark data dictionary if file exists, `nothing` otherwise

# Details
Constructs the path to the benchmark JSON file using the benchmark ID and reads it.
The file is expected to be located at `benchmarks/<bench_id>/<bench_id>.json`.
"""
function _get_bench_data(bench_id::AbstractString)
    json_filename = string(bench_id, ".json")
    path = joinpath(@__DIR__, "..", "benchmarks", bench_id, json_filename)
    return _read_benchmark_json(path)
end

"""
    _read_benchmark_json(path::AbstractString)

Read and parse a benchmark JSON file.

# Arguments
- `path::AbstractString`: Full path to the JSON file

# Returns
- `Dict` or `nothing`: Parsed JSON content if file exists, `nothing` if file not found

# Details
Safely reads a JSON file and returns its parsed content. Returns `nothing` if the file
does not exist, allowing graceful handling of missing benchmark data.
"""
function _read_benchmark_json(path::AbstractString)
    if !isfile(path)
        return nothing
    end
    open(path, "r") do io
        return JSON.parse(io)
    end
end

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

    solvers_str = isempty(solvers) ? "n/a" : join(sort(collect(solvers)), ", ")
    models_str = isempty(models) ? "n/a" : join(sort(collect(models)), ", ")
    problems_str = isempty(problems) ? "n/a" : join(string.(problems), ", ")
    grid_sizes_str = isempty(grid_sizes) ? "n/a" : join(string.(grid_sizes), ", ")
    disc_methods_str = isempty(disc_methods) ? "n/a" : join(string.(disc_methods), ", ")

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

"""
    _print_benchmark_log(bench_id; problems=nothing)

Display benchmark results as a formatted log table.

# Arguments
- `bench_id`: Benchmark identifier string
- `problems::Union{Nothing, Vector}`: Optional filter to display only specific problems

# Details
Prints benchmark results in a hierarchical tree format with:
- Problem names (grouped by problem)
- Solver and discretization method combinations
- Grid sizes
- Model types with timing and convergence statistics

Results are displayed line-by-line with colored formatting for easy readability.
If `problems` is specified, only results for those problems are shown.
"""
function _print_benchmark_log(bench_id; problems=nothing)
    bench_data = _get_bench_data(bench_id)
    if bench_data === nothing
        println("⚠️  No results to display because the benchmark file is missing.")
    else
        rows = get(bench_data, "results", Any[])
        if isempty(rows)
            println("⚠️  No results recorded in the benchmark file.")
        else
            println("Benchmarks results:")

            # Convert to DataFrame for easier manipulation
            df = DataFrame(rows)

            # Filter by problems if specified
            if problems !== nothing
                df = filter(row -> row.problem in problems, df)
            end

            # Group by problem for structured display
            problems_list = unique(df.problem)

            for problem in problems_list
                # H2 level: Problem name in deep blue
                print("\n┌─ ")
                printstyled("Problem: $problem"; color=:blue, bold=true)
                println()
                println("│")

                # Get all rows for this problem
                prob_df = filter(row -> row.problem == problem, df)

                # Group by solver and disc_method
                solver_disc_combos = unique([
                    (row.solver, row.disc_method) for row in eachrow(prob_df)
                ])

                for (idx, (solver, disc_method)) in enumerate(solver_disc_combos)
                    is_last = (idx == length(solver_disc_combos))

                    # H3 level: Solver in cyan, disc_method in yellow
                    print("├──┬ ")
                    printstyled("Solver: $solver"; color=:cyan, bold=true)
                    print(", ")
                    printstyled("Discretization: $disc_method"; color=:yellow, bold=true)
                    println()
                    println("│  │")

                    # Filter for this solver/disc_method combination
                    combo_df = filter(
                        row -> row.solver == solver && row.disc_method == disc_method,
                        prob_df,
                    )

                    # Group by grid size
                    grid_sizes = unique(combo_df.grid_size)

                    for (grid_idx, N) in enumerate(grid_sizes)
                        # H4 level: Grid size in yellow
                        print("│  │  ")
                        printstyled("N = $N"; color=:yellow, bold=true)
                        println()

                        # Filter for this grid size
                        grid_df = filter(row -> row.grid_size == N, combo_df)

                        # Display each model with library formatting
                        for row in eachrow(grid_df)
                            # Create a NamedTuple with benchmark data for formatting
                            stats = (
                                benchmark=row.benchmark,
                                objective=row.objective,
                                iterations=row.iterations,
                                status=row.status,
                                success=row.success,
                                criterion=hasproperty(row, :criterion) ? row.criterion : missing,
                            )
                            print("│  │")
                            CTBenchmarks.print_benchmark_line(Symbol(row.model), stats)
                        end

                        # Add spacing between grid sizes
                        if grid_idx < length(grid_sizes)
                            println("│  │ ")
                        end
                    end

                    println("│  └─")

                    # Add spacing between solver blocks
                    if !is_last
                        println("│")
                    end
                end

                println("└─")
            end
        end
    end
    return nothing
end

"""
    _plot_performance_profiles(bench_id)

Generate and display performance profile plots for benchmark results.

# Arguments
- `bench_id`: Benchmark identifier string

# Returns
- `Plots.Plot`: Performance profile plot, or empty plot if no data available

# Details
Creates a performance profile plot showing the proportion of solved instances
for each solver-model combination relative to the best solver for each problem.

The plot uses:
- Log scale (base 2) on the x-axis for performance ratio (τ)
- Proportion of solved instances on the y-axis
- One curve per (model, solver) combination

Only successful benchmarks with valid timing data are included.
Returns an empty plot if no benchmark data or successful runs are found.
"""
function _plot_performance_profiles(bench_id)
    raw = _get_bench_data(bench_id)
    if raw === nothing
        println("⚠️ No result (missing or invalid file) for bench_id: $bench_id")
        return plot()
    end

    rows = get(raw, "results", Any[])
    if isempty(rows)
        println("⚠️ No ('results') recorded in the benchmark file.")
        return plot()
    end

    df = DataFrame(rows)
    df_successful = filter(row -> row.success == true && row.benchmark !== nothing, df)
    if isempty(df_successful)
        println("⚠️ No successful benchmark entry to analyze.")
        return plot()
    end

    df_successful.time = [row.benchmark["time"] for row in eachrow(df_successful)]
    select!(df_successful, [:problem, :model, :solver, :grid_size, :time])
    df_successful = dropmissing(df_successful, :time)
    sort!(df_successful, [:problem, :grid_size, :model, :solver])

    df_min = combine(groupby(df_successful, [:problem, :grid_size]), :time => minimum => :min_time)
    df_successful = leftjoin(df_successful, df_min, on = [:problem, :grid_size])
    df_successful.ratio = df_successful.time ./ df_successful.min_time

    df_successful.combo = string.("(", df_successful.model, ", ", df_successful.solver, ")")

    function performance_profile(df)
        combos = unique(df.combo)
        colors = [
            :blue, :red, :green, :orange, :purple, :brown, :pink, :gray,
            :cyan, :magenta, :teal, :olive, :gold, :navy, :darkred
        ]
        
        # Total number of unique problems (problem × grid_size combinations)
        total_problems = nrow(combine(groupby(df, [:problem, :grid_size]), nrow => :count))
        
        # Compute max ratio across all curves for xlim
        min_ratio = Inf
        max_ratio = 1.0
        for c in combos
            sub = filter(row -> row.combo == c, df)
            ratios = collect(skipmissing(sub.ratio))
            if !isempty(ratios)
                max_ratio = max(max_ratio, maximum(ratios))
                min_ratio = min(min_ratio, minimum(ratios))
            end
        end
        gap = log2(max_ratio) - log2(min_ratio)
        factor = 0.02
        xlim_max = max_ratio * (1+factor*gap)
        xlim_min = 1.0 * (1-factor*gap)
        
        plt = plot(
            xlabel = "τ (Performance ratio)",
            ylabel = "Proportion of solved instances ≤ τ",
            title = "Performance profile — Global models × solvers",
            legend = :bottomright,
            xscale = :log2,
            grid = true,
            size = (900, 600),
            xticks = ([1, 2, 4, 10, 50, 100], ["1", "2", "4", "10", "50", "100"]),
            xlims = (xlim_min, xlim_max),
            ylims = (-0.05, 1.05),
            yticks = ([0.0, 0.10, 0.20, 0.30, 0.40, 0.50, 0.60, 0.70, 0.80, 0.90, 1.0], ["0", "10%", "20%", "30%", "40%", "50%", "60%", "70%", "80%", "90%", "100%"]),
            left_margin = 5mm,
            bottom_margin = 5mm
        )

        for (idx, c) in enumerate(combos)
            color = colors[mod1(idx, length(colors))]
            sub = filter(row -> row.combo == c, df)
            ratios = sort(collect(skipmissing(sub.ratio)))
            
            if !isempty(ratios)
                # Compute ρ_s(τ) = (1/n_p) * count(r_{p,s} ≤ τ)
                # For each ratio value, count how many ratios are ≤ to it
                y = [count(x -> x <= tau, ratios) / total_problems for tau in ratios]
                
                # Plot the curve
                plot!(ratios, y, label = c, lw = 1.5, color = color)
                
                # Add marker on the first point of the curve
                plot!([ratios[1]], [y[1]], seriestype = :scatter, label = "",
                      markersize = 4, markerstrokewidth = 0, color = color)
            end
        end
        
        # Add reference lines with low z-order (plot them last)
        vline!([1.0], color = :black, lw = 0.5, label = "", linestyle = :solid, z_order = 1)
        hline!([0.0], color = :black, lw = 0.5, label = "", linestyle = :solid, z_order = 1)
        hline!([1.0], color = :black, lw = 0.5, label = "", linestyle = :solid, z_order = 1)

        return plt
    end

    plt = performance_profile(df_successful)
    println("✅ Global performance profile generated.")
    return plt
end
