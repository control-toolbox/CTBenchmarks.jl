# ═══════════════════════════════════════════════════════════════════════════════
# Print Log Results Module
# ═══════════════════════════════════════════════════════════════════════════════

"""
    _print_benchmark_log(bench_id, src_dir; problems=nothing)

Display benchmark results as a formatted log table.

# Arguments
- `bench_id`: Benchmark identifier string
- `src_dir`: Path to docs/src directory
- `problems::Union{Nothing, Vector{<:AbstractString}}`: Optional filter to display only specific problems

# Details
Prints benchmark results in a hierarchical tree format with:
- Problem names (grouped by problem)
- Solver and discretization method combinations
- Grid sizes
- Model types with timing and convergence statistics

Results are displayed line-by-line with colored formatting for easy readability.
If `problems` is specified, only results for those problems are shown.
"""
function _print_benchmark_log(bench_id::AbstractString, src_dir::AbstractString; 
    problems::Union{Nothing, Vector{<:AbstractString}}=nothing)
    bench_data = _get_bench_data(bench_id, src_dir)
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
