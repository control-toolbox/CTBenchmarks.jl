using CTBenchmarks
using JSON
using DataFrames
using Markdown
using Dates
using Printf
using Plots

# Get benchmark data from benchmark ID
function _get_bench_data(bench_id::AbstractString)
    path = joinpath(@__DIR__, "benchmarks", bench_id, "data.json")
    return _read_benchmark_json(path)
end

# Read benchmark JSON file
function _read_benchmark_json(path::AbstractString)
    if !isfile(path)
        return nothing
    end
    open(path, "r") do io
        return JSON.parse(io)
    end
end

# Download links for the benchmark environment
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

# Factorized helper functions that take bench_id as argument
function _basic_metadata(bench_id) # hide
    bench_data = _get_bench_data(bench_id) # hide
    if bench_data !== nothing # hide
        meta = get(bench_data, "metadata", Dict()) # hide
        for (label, key) in ( # hide
            ("📅 Timestamp", "timestamp"), # hide
            ("🔧 Julia version", "julia_version"), # hide
            ("💻 OS", "os"), # hide
            ("🖥️ Machine", "machine"), # hide
        ) # hide
            value = string(get(meta, key, "n/a")) # hide
            println(rpad(label, key=="machine" ? 16 : 17), ": ", value) # hide
        end # hide
    else # hide
        println("⚠️  No benchmark data available") # hide
    end # hide
end # hide

function _bench_data(bench_id) # hide
    bench_data = _get_bench_data(bench_id) # hide
    if bench_data !== nothing # hide
        meta = get(bench_data, "metadata", Dict()) # hide
        versioninfo_text = get(meta, "versioninfo", "No version info available") # hide
        println(versioninfo_text) # hide
    else # hide
        println("⚠️  No benchmark data available") # hide
    end # hide
end # hide

function _package_status(bench_id) # hide
    bench_data = _get_bench_data(bench_id) # hide
    if bench_data !== nothing # hide
        meta = get(bench_data, "metadata", Dict()) # hide
        pkg_status = get(meta, "pkg_status", "No package status available") # hide
        println(pkg_status) # hide
    else # hide
        println("⚠️  No benchmark data available") # hide
    end # hide
end # hide

function _complete_manifest(bench_id) # hide
    bench_data = _get_bench_data(bench_id) # hide
    if bench_data !== nothing # hide
        meta = get(bench_data, "metadata", Dict()) # hide
        pkg_manifest = get(meta, "pkg_manifest", "No manifest available") # hide
        println(pkg_manifest) # hide
    else # hide
        println("⚠️  No benchmark data available") # hide
    end # hide
end # hide

function _print_results(bench_id)
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

            # Group by problem for structured display
            problems = unique(df.problem)

            for problem in problems
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
end

function _plot_results(file)
    raw = JSON.read(open(file, "r"), Dict)
    results = raw["results"]
    df = DataFrame(
        problem = [r["problem"] for r in results],
        solver  = [r["solver"] for r in results],
        model   = [r["model"] for r in results],
        metric  = [r["benchmark"][string(time)] for r in results],
        success = [r["success"] for r in results],
    )
    filter!(r -> r.success == true, df)
    df.ratio = similar(df.metric)
    for prob in unique(df.problem)
        subset = df[df.problem .== prob, :]
        tmin = minimum(subset.metric)
        df.ratio[df.problem .== prob] .= subset.metric ./ tmin
    end
    taus = range(1, stop=10, length=200)
    solvers = unique(df.solver)
    profiles = Dict{String, Vector{Float64}}()
    for s in solvers
        ratios = df.ratio[df.solver .== s]
        probs = df.problem[df.solver .== s]
        unique_probs = unique(probs)
        ρ = Float64[]
        for τ in taus
            count = sum(ratios .<= τ)
            push!(ρ, count / length(unique_probs))
        end
        profiles[s] = ρ
    end
    plt = plot(
        xlabel="Facteur de performance (τ)",
        ylabel="Proportion de problèmes résolus (ρ)",
        legend=:bottomright,
        title="Performance Profile — $(metric)",
        xlim=(1, maximum(taus)),
        ylim=(0, 1.05),
        lw=2,
    )
    for (solver, ρ) in profiles
        plot!(plt, taus, ρ, label=solver)
    end
    display(plt)
    return plt
end