using CTBenchmarks
using JSON
using DataFrames
using Markdown
using Dates
using Printf
using Plots
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

function _plot_results(chemin_fichier_json::String)
    
    # --- Étape 1 : Chargement et préparation des données ---
    # MODIFICATION : On utilise JSON.parsefile au lieu de JSON3.read
    brut_data = JSON.parsefile(chemin_fichier_json)
    df = DataFrame(brut_data["results"])

    df_successful = filter(row -> row.success == true && row.benchmark !== nothing, df)
    df_successful.time = [row.benchmark["time"] for row in eachrow(df_successful)]

    select!(df_successful, [:problem, :model, :solver, :grid_size, :time])
    sort!(df_successful, [:problem, :model, :solver, :grid_size])

    # --- Étape 2 : Boucle de génération des graphiques ---
    for problem in unique(df_successful.problem)
        df_problem = filter(row -> row.problem == problem, df_successful)
        
        problem_plot = plot(
            title = "Profil de Performance pour: $problem",
            xlabel = "Facteur de performance τ (échelle log)",
            ylabel = "Proportion des problèmes résolus",
            legend = :bottomright,
            xaxis = :log10,
            grid = true,
            framestyle = :box,
            minorticks = true
        )

        df_grouped_by_model = groupby(df_problem, :model)
        
        for (key, sub_df) in pairs(df_grouped_by_model)
            model_name = key.model
            
            # Calcul des ratios
            wide_df = unstack(DataFrame(sub_df), :grid_size, :solver, :time)
            
            required_solvers = ["ipopt", "madnlp"]
            if !all(s -> s in names(wide_df), required_solvers)
                continue
            end

            min_times = min.(wide_df.ipopt, wide_df.madnlp)
            ratios_ipopt = wide_df.ipopt ./ min_times
            ratios_madnlp = wide_df.madnlp ./ min_times

            # Ajout des courbes
            for (solver, ratios) in [("ipopt", ratios_ipopt), ("madnlp", ratios_madnlp)]
                sorted_ratios = sort(ratios)
                n = length(sorted_ratios)
                proportions = (1:n) / n
                
                plot_x = [1; sorted_ratios]
                plot_y = [0; proportions]
                
                plot!(problem_plot, plot_x, plot_y,
                    label = "$(solver) ($(model_name))",
                    seriestype = :steppost,
                    lw = 2.5,
                    markershape = :circle,
                    markersize = 3,
                    markerstrokewidth = 0
                )
            end
        end
        
        # --- Étape 3 : Affichage du graphique ---
        display(problem_plot)
    end
    
    return nothing
end