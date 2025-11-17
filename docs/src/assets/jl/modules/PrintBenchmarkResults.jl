"""
    _print_benchmark_table_results(bench_id::AbstractString, src_dir::AbstractString; problems::Union{Nothing, Vector{<:AbstractString}}=nothing) -> String

Generate a Markdown table-style summary of benchmark results for `bench_id`.

The table is organized by problem, then grid size `N`, then model and solver,
and includes columns for:
- Success (whether the run converged)
- N (grid size)
- Model
- Solver
- Time in milliseconds
- Iteration count
- Objective value
- Criterion (e.g. min/max)
- Best (marks the fastest successful run for each N)
"""
function _print_benchmark_table_results(bench_id::AbstractString, src_dir::AbstractString;
    problems::Union{Nothing, Vector{<:AbstractString}}=nothing)
    bench_data = _get_bench_data(bench_id, src_dir)
    if bench_data === nothing
        return "!!! warning\n    No benchmark data available for `$bench_id`.\n"
    end

    rows = get(bench_data, "results", Any[])
    if isempty(rows)
        return "!!! warning\n    Benchmark file for `$bench_id` contains no `results`.\n"
    end

    df = DataFrame(rows)

    # Optionally filter by a subset of problems, mirroring _print_benchmark_log
    if problems !== nothing
        df = filter(row -> row.problem in problems, df)
    end

    buf = IOBuffer()

    # Helper to read from Dict or NamedTuple
    function getval(obj, key::Symbol)
        if isa(obj, Dict)
            return get(obj, string(key), get(obj, key, nothing))
        else
            return getproperty(obj, key)
        end
    end

    problems = unique(df.problem)
    first_problem = true

    for problem in problems
        prob_df = filter(row -> row.problem == problem, df)
        if isempty(prob_df)
            continue
        end

        sort!(prob_df, [:grid_size, :model, :solver])

        # Compute best (minimal) time per N for this problem
        best_time_by_N = Dict{Any, Float64}()
        for sub in groupby(prob_df, :grid_size)
            sub_success = filter(row -> row.success == true && row.benchmark !== nothing, sub)
            if isempty(sub_success)
                continue
            end

            times = Float64[]
            for row in eachrow(sub_success)
                bench = row.benchmark
                time_val = getval(bench, :time)
                if time_val !== nothing && !ismissing(time_val)
                    push!(times, Float64(time_val))
                end
            end

            if !isempty(times)
                N = first(sub.grid_size)
                best_time_by_N[N] = minimum(times)
            end
        end

        if !first_problem
            print(buf, "\n\n")
        end
        first_problem = false

        print(buf, "#### Problem: `", problem, "`\n\n")

        Ns = sort(unique(prob_df.grid_size))
        for (idxN, Nval) in enumerate(Ns)
            if idxN > 1
                print(buf, "\n\n")
            end

            print(buf, "| Success | N | Model | Solver | Time (ms) | Iters | Objective | Criterion | Best |\n")
            print(buf, "|:------:|---:|:------|:-------|----------:|------:|----------:|:---------:|:----:|\n")

            subN_df = filter(row -> row.grid_size == Nval, prob_df)

            for row in eachrow(subN_df)
                success = hasproperty(row, :success) && row.success == true
                success_mark = success ? "✓" : "✗"

                N = row.grid_size
                model = string(row.model)
                solver = string(row.solver)

                bench = row.benchmark
                time_val = nothing
                time_ms_str = "N/A"

                if !(ismissing(bench) || bench === nothing)
                    time_raw = getval(bench, :time)
                    if time_raw !== nothing && !ismissing(time_raw)
                        time_val = Float64(time_raw)
                        time_ms_str = @sprintf("%.3f", time_val * 1000)
                    end

                end

                obj_str = if ismissing(row.objective) || row.objective === nothing
                    "N/A"
                else
                    @sprintf("%.6f", row.objective)
                end

                iter_str = (ismissing(row.iterations) || row.iterations === nothing) ? "N/A" : string(row.iterations)

                criterion_str = if hasproperty(row, :criterion) && !(ismissing(row.criterion) || row.criterion === nothing)
                    string(row.criterion)
                else
                    "N/A"
                end

                is_best = false
                if success && haskey(best_time_by_N, N) && time_val !== nothing
                    best_time = best_time_by_N[N]
                    is_best = abs(time_val - best_time) <= (eps(Float64) * max(1.0, abs(best_time)))
                end
                best_mark = is_best ? "✓" : ""

                print(buf, "| ", success_mark, " | ", N, " | `", model, "` | `", solver, "` | ",
                      time_ms_str, " | ", iter_str, " | ", obj_str, " | ", criterion_str,
                      " | ", best_mark, " |\n")
            end
        end
    end

    return String(take!(buf))
end
