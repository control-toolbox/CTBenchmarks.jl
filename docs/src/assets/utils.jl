using CTBenchmarks
using JSON
using DataFrames
using Markdown
using Dates
using Printf
using Plots
using Plots.PlotMeasures
using Statistics

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

function _plot_results(bench_id)
    bench_data = _get_bench_data(bench_id)
    if bench_data === nothing
        println("⚠️  No results to display because the benchmark file is missing.")
        return Plots.Plot[]
    end

    rows = get(bench_data, "results", Any[])
    if isempty(rows)
        println("⚠️  No results recorded in the benchmark file.")
        return Plots.Plot[]
    end

    function pratios(df_sub)
        wide = unstack(df_sub, [:problem, :grid_size], :solver, :time)

        if !("ipopt" in names(wide)) || !("madnlp" in names(wide))
            return nothing
        end

        min_times = min.(wide.ipopt, wide.madnlp)

        wide.r_ipopt  = wide.ipopt  ./ min_times
        wide.r_madnlp = wide.madnlp ./ min_times

        return wide
    end

    function plot_performance_profile(wide, model)
        r_ipopt  = sort(collect(skipmissing(wide.r_ipopt)))
        r_madnlp = sort(collect(skipmissing(wide.r_madnlp)))
        n = length(r_ipopt)

        y = (1:n) ./ n

        plt = plot(
            r_ipopt, y,
            label = "Ipopt", lw = 2,
            xlabel = "τ (Performance ratio)",
            ylabel = "Proportion d'instances résolues ≤ τ",
            title = "Profil de performance — $(model)",
            legend = :bottomright,
            xscale = :log10,
            grid = true
        )

        plot!(
            r_madnlp, y,
            label = "MadNLP", lw = 2
        )

        return plt
    end
    println("Chargement du fichier $input_json_path...")
    brut = JSON.parsefile(input_json_path)
    df = DataFrame(brut["results"])
    nouveaux_temps = []
    for row in eachrow(df)
        if row.benchmark === nothing
            push!(nouveaux_temps, missing)
        else
            valeur_time = row.benchmark["time"]
            push!(nouveaux_temps, valeur_time)
        end
    end
    df.time = nouveaux_temps

    select!(df, [:problem, :model, :solver, :grid_size, :time])
    sort!(df, [:model, :problem, :grid_size, :solver])
    models = unique(df.model)
    mkpath(output_dir_path)

    println("\nGénération des profils de performance par modèle :\n")

    for m in models
        df_sub = filter(row -> row.model == m, df)
        wide = pratios(df_sub) 
        
        if wide === nothing
            println("Skipped modèle $(m) (un des solveurs manquant)")
            continue
        end
        plt = plot_performance_profile(wide, m)

        filepath = joinpath(output_dir_path, "$(m)_profile.png")
        savefig(plt, filepath)

        println("✅ Saved → $(filepath)")
    end

    println("\nTerminé : les graphiques sont dans → $(output_dir_path)\n")
    
    return nothing
end