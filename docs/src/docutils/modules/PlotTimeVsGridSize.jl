# ═══════════════════════════════════════════════════════════════════════════════
# Plot Time vs Grid Size Module
# ═══════════════════════════════════════════════════════════════════════════════

"""
    _plot_time_vs_grid_size(problem, bench_id, src_dir)

Plot solve time versus grid size for a given problem and benchmark.

Uses benchmark JSON data to aggregate successful runs by `(model, solver)` and
plot the mean solve time per grid size for each combination.

# Arguments
- `problem::AbstractString`: Name of the problem to filter.
- `bench_id`: Benchmark identifier used to locate the benchmark JSON file.
- `src_dir`: Path to docs/src directory

# Returns
- `Plots.Plot`: Line plot of solve time vs grid size. Returns an empty plot if
  no data is available.
"""
function _plot_time_vs_grid_size(
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

    df_successful.time = [row.benchmark["time"] for row in eachrow(df_successful)]
    select!(df_successful, [:model, :solver, :grid_size, :time])
    df_successful = dropmissing(df_successful, :time)
    sort!(df_successful, [:grid_size, :model, :solver])

    df_successful.combo = string.("(", df_successful.model, ", ", df_successful.solver, ")")
    combos = unique(df_successful.combo)
    title_font, label_font = _plot_font_settings()

    min_N = minimum(df_successful.grid_size)
    max_N = maximum(df_successful.grid_size)
    if min_N > 0 && max_N > min_N
        log_min = log10(min_N)
        log_max = log10(max_N)
        span_log = log_max - log_min
        padding_log = 0.05 * span_log
        x_min = 10^(log_min - padding_log)
        x_max = 10^(log_max + padding_log)
    else
        span_N = max_N - min_N
        padding = span_N > 0 ? 0.05 * span_N : 1
        x_min = max(0, min_N - padding)
        x_max = max_N + padding
    end
    Ns = sort(unique(df_successful.grid_size))

    plt = plot(;
        xlabel="Grid size N",
        ylabel="Solve time (s)",
        title="\nSolve time vs grid size — $problem",
        legend=:bottomright,
        grid=true,
        size=(900, 600),
        xticks=(Ns, string.(Ns)),
        xlims=(x_min, x_max),
        left_margin=5mm,
        bottom_margin=5mm,
        top_margin=5mm,
        titlefont=title_font,
        xguidefont=label_font,
        yguidefont=label_font,
        xscale=:log10,
        yscale=:log10,
    )

    for (idx, c) in enumerate(combos)
        sub = filter(row -> row.combo == c, df_successful)
        grouped = combine(groupby(sub, :grid_size), :time => mean => :mean_time)
        sort!(grouped, :grid_size)
        xs = grouped.grid_size
        ys = grouped.mean_time

        first_row = first(eachrow(sub))
        color = CTBenchmarks.get_color(first_row.model, first_row.solver, idx)
        marker = CTBenchmarks.get_marker_style(first_row.model, first_row.solver, idx)

        plot!(
            xs,
            ys;
            label=c,
            lw=1.5,
            color=color,
            marker=marker,
            markersize=4,
            markerstrokewidth=0,
        )
    end

    DOC_DEBUG[] &&
        @info "  ✅ Time vs grid size plot generated for problem: $problem and bench_id: $bench_id"
    return plt
end

"""
    _plot_time_vs_grid_size_bar(problem, bench_id, src_dir; max_bar_width=0.18)

Plot solve time versus grid size as grouped bars for each model–solver
combination.

Computes the mean solve time per grid size for each `(model, solver)` pair and
displays the result as a grouped bar chart.

# Arguments
- `problem::AbstractString`: Name of the problem to filter.
- `bench_id`: Benchmark identifier used to locate the benchmark JSON file.
- `src_dir`: Path to docs/src directory
- `max_bar_width::Real`: Maximum width of each bar in x-axis units.

# Returns
- `Plots.Plot`: Grouped bar plot of solve time vs grid size. Returns an empty
  plot if no data is available.
"""
function _plot_time_vs_grid_size_bar(
    problem::AbstractString,
    bench_id::AbstractString,
    src_dir::AbstractString;
    max_bar_width::Real=0.08,
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

    df_successful.time = [row.benchmark["time"] for row in eachrow(df_successful)]
    select!(df_successful, [:model, :solver, :grid_size, :time])
    df_successful = dropmissing(df_successful, :time)
    sort!(df_successful, [:grid_size, :model, :solver])

    df_successful.combo = string.("(", df_successful.model, ", ", df_successful.solver, ")")
    combos = unique(df_successful.combo)
    title_font, label_font = _plot_font_settings()

    Ns = sort(unique(df_successful.grid_size))
    nN = length(Ns)
    nC = length(combos)

    # Base positions for each grid size (treated as categorical)
    x_base = collect(1:nN)
    xtick_labels = string.(Ns)

    # Width of a group and spacing/width for individual bars
    group_width = 0.7
    center_spacing = group_width / max(nC, 1)
    base_bar_width = 0.6 * center_spacing

    # If bars are capped by max_bar_width, shrink the spacing so that bar
    # centers stay proportional to the actual bar width (tighter grouping).
    if base_bar_width <= max_bar_width
        bar_width = base_bar_width
    else
        bar_width = max_bar_width
        center_spacing = bar_width / 0.6
    end

    offsets = (collect(0:(nC - 1)) .- (nC - 1) / 2) .* center_spacing

    plt = plot(;
        xlabel="Grid size N",
        ylabel="Solve time (s)",
        title="\nSolve time vs grid size (bar) — $problem",
        legend=:topleft,
        grid=true,
        size=(900, 600),
        xticks=(x_base, xtick_labels),
        left_margin=5mm,
        bottom_margin=5mm,
        top_margin=5mm,
        titlefont=title_font,
        xguidefont=label_font,
        yguidefont=label_font,
    )

    for (j, c) in enumerate(combos)
        sub = filter(row -> row.combo == c, df_successful)
        grouped = combine(groupby(sub, :grid_size), :time => mean => :mean_time)

        # Map mean times to each grid size index
        yj = fill(NaN, nN)
        for row in eachrow(grouped)
            i = findfirst(==(row.grid_size), Ns)
            yj[i] = row.mean_time
        end

        xj = x_base .+ offsets[j]
        first_row = first(eachrow(sub))
        color = CTBenchmarks.get_color(first_row.model, first_row.solver, j)

        bar!(
            xj,
            yj;
            bar_width=bar_width,
            label=c,
            color=color,
            linecolor=:transparent,
            linewidth=0,
        )
    end

    # When there are very few categories (<= 2), enlarge x-limits so bars
    # do not visually occupy the entire horizontal range.
    if nN <= 2
        x_min = minimum(x_base) - 1
        x_max = maximum(x_base) + 1
        xlims!(plt, (x_min, x_max))
    end

    DOC_DEBUG[] &&
        @info "  ✅ Time vs grid size bar plot generated for problem: $problem and bench_id: $bench_id"
    return plt
end
