# ═══════════════════════════════════════════════════════════════════════════════
# Plot Iterations vs CPU Time Module
# ═══════════════════════════════════════════════════════════════════════════════

"""
    _plot_iterations_vs_cpu_time(problem, bench_id, src_dir)

Plot the relationship between iteration count and CPU time for a given problem
and benchmark.

Uses benchmark JSON data to collect individual runs for the specified `problem`
across all `(model, solver)` combinations, and displays them as a scatter plot
in the `(iterations, CPU time)` plane.

# Arguments
- `problem::AbstractString`: Name of the problem to filter.
- `bench_id`: Benchmark identifier used to locate the benchmark JSON file.
- `src_dir`: Path to `docs/src` directory.

# Returns
- `Plots.Plot`: Scatter plot of iteration count vs CPU time. Returns an empty
  plot if no data is available.
"""
function _plot_iterations_vs_cpu_time(
    problem::AbstractString, bench_id::AbstractString, src_dir::AbstractString
)
    raw = _get_bench_data(bench_id, src_dir)
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
    df_successful = filter(
        row -> row.success == true && row.benchmark !== nothing && row.problem == problem,
        df,
    )
    if isempty(df_successful)
        println("⚠️ No successful benchmark entry to analyze for problem: $problem")
        return plot()
    end

    # Extract CPU time and iterations from benchmark payload
    times = Float64[]
    iters = Int[]
    models = String[]
    solvers = String[]

    for row in eachrow(df_successful)
        bench = row.benchmark
        time_raw = get(bench, "time", nothing)
        iter_raw = hasproperty(row, :iterations) ? row.iterations : nothing

        if time_raw === nothing ||
            ismissing(time_raw) ||
            iter_raw === nothing ||
            ismissing(iter_raw)
            continue
        end

        push!(times, Float64(time_raw))
        push!(iters, Int(iter_raw))
        push!(models, String(row.model))
        push!(solvers, String(row.solver))
    end

    if isempty(times)
        println("⚠️ No valid (time, iterations) pairs available for problem: $problem")
        return plot()
    end

    # Build a small DataFrame for plotting convenience
    df_plot = DataFrame(; time=times, iterations=iters, model=models, solver=solvers)

    # Derive combination labels
    df_plot.combo = string.("(", df_plot.model, ", ", df_plot.solver, ")")
    combos = unique(df_plot.combo)

    title_font, label_font = _plot_font_settings()

    plt = plot(;
        xlabel="Iterations",
        ylabel="CPU time (s)",
        title="\nIterations vs CPU time — $problem",
        legend=:topleft,
        grid=true,
        size=(900, 600),
        left_margin=5mm,
        bottom_margin=5mm,
        top_margin=5mm,
        titlefont=title_font,
        xguidefont=label_font,
        yguidefont=label_font,
    )

    for (idx, c) in enumerate(combos)
        sub = filter(row -> row.combo == c, df_plot)
        if isempty(sub)
            continue
        end

        first_row = first(eachrow(sub))
        color = CTBenchmarks.get_color(first_row.model, first_row.solver, idx)
        marker = CTBenchmarks.get_marker_style(first_row.model, first_row.solver, idx)

        scatter!(
            sub.iterations,
            sub.time;
            label=c,
            color=color,
            markershape=marker,
            markersize=6,
            markerstrokewidth=0,
        )
    end

    DOC_DEBUG[] &&
        @info "  ✅ Iterations vs CPU time plot generated for problem: $problem and bench_id: $bench_id"
    return plt
end
