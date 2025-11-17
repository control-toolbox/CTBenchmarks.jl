# ═══════════════════════════════════════════════════════════════════════════════
# Plot Performance Profile Module
# ═══════════════════════════════════════════════════════════════════════════════

# ───────────────────────────────────────────────────────────────────────────────
# Data Structure
# ───────────────────────────────────────────────────────────────────────────────

"""
    ProfileCriterion{M}

Criterion used to extract and compare a scalar metric from benchmark runs.

# Fields
- `name::String`: Human-readable name of the criterion (e.g., "CPU time (s)").
- `value::Function`: Function `row::DataFrameRow -> M` extracting the metric.
- `better::Function`: Function `(a::M, b::M) -> Bool` returning `true` if `a`
  is strictly better than `b` according to the criterion.
"""
struct ProfileCriterion{M}
    name::String
    value::Function
    better::Function
end

"""
    PerformanceProfileConfig{M}

Configuration describing how to build a performance profile from a benchmark
results table.

# Fields
- `instance_cols::Vector{Symbol}`: Columns defining an instance (e.g., `[:problem, :grid_size]`).
- `solver_cols::Vector{Symbol}`: Columns defining a solver/model (e.g., `[:model, :solver]`).
- `criterion::ProfileCriterion{M}`: Metric extraction and comparison rule.
- `is_success::Function`: `row::DataFrameRow -> Bool`, selects successful runs.
- `row_filter::Function`: `row::DataFrameRow -> Bool`, additional filtering.
- `aggregate::Function`: Aggregation `xs::AbstractVector{M} -> M` when multiple
  runs exist for the same instance/solver.
"""
struct PerformanceProfileConfig{M}
    instance_cols::Vector{Symbol}
    solver_cols::Vector{Symbol}
    criterion::ProfileCriterion{M}
    is_success::Function
    row_filter::Function
    aggregate::Function
end

"""
    PerformanceProfile{M}

Immutable structure containing all data needed to plot and analyze a performance
profile, together with the configuration that was used to build it.

# Type parameter
- `M`: Metric type used in the underlying profile (e.g., `Float64` for CPU time).

# Fields
- `bench_id::String`: Benchmark identifier
- `df_instances::DataFrame`: All (problem, grid_size) instances attempted
- `df_successful::DataFrame`: Successful runs with aggregated metric and ratios
- `combos::Vector{String}`: List of solver labels (typically "(model, solver)")
- `total_problems::Int`: Total number of instances (N in Dolan–Moré)
- `min_ratio::Float64`: Minimum performance ratio across all combos
- `max_ratio::Float64`: Maximum performance ratio across all combos
- `config::PerformanceProfileConfig{M}`: Configuration used to construct this profile
"""
struct PerformanceProfile{M}
    bench_id::String
    df_instances::DataFrame
    df_successful::DataFrame
    combos::Vector{String}
    total_problems::Int
    min_ratio::Float64
    max_ratio::Float64
    config::PerformanceProfileConfig{M}
end

# ───────────────────────────────────────────────────────────────────────────────
# Helper Functions
# ───────────────────────────────────────────────────────────────────────────────

"""
    _nearest_index(xs, x)

Find the index of the element in `xs` closest to `x`.
"""
function _nearest_index(xs, x)
    best_idx = 1
    best_dist = abs(xs[1] - x)
    for i in eachindex(xs)[2:end]
        d = abs(xs[i] - x)
        if d < best_dist
            best_dist = d
            best_idx = i
        end
    end
    return best_idx
end

"""
    _marker_indices_for_curve(ratios; M = 6)

Compute marker positions for a performance profile curve.

Places M markers uniformly in log2 space between the first and last ratio,
then snaps to the nearest available grid points.
"""
function _marker_indices_for_curve(ratios; M = 6)
    n = length(ratios)
    if n == 0
        return Int[]
    elseif n == 1
        return [1]
    end

    a = log2(ratios[1])
    b = log2(ratios[end])
    if !isfinite(a) || !isfinite(b) || a == b
        return [1]
    end

    # Place M markers uniformly in the log2 domain between a and b, then
    # project back to τ-space and snap to the nearest available grid
    # points on this curve only.
    indices = Int[]
    if M <= 1
        push!(indices, 1)
    else
        for k in 0:(M-1)
            t = k / (M - 1)
            p = a + t * (b - a)
            x_target = 2.0 ^ p
            idx = _nearest_index(ratios, x_target)
            if !(idx in indices)
                push!(indices, idx)
            end
        end
    end

    if isempty(indices)
        push!(indices, 1)
    end

    sort!(indices)
    return indices
end

# ───────────────────────────────────────────────────────────────────────────────
# Performance Profile Computation
# ───────────────────────────────────────────────────────────────────────────────

"""
    compute_performance_profile(bench_id::AbstractString, src_dir::AbstractString) -> Union{PerformanceProfile, Nothing}

Compute performance profile data from benchmark results.

Currently this uses the default CPU time criterion; see `compute_profile_default_cpu`.
"""

function build_profile_from_df(df::DataFrame,
                               bench_id::AbstractString,
                               cfg::PerformanceProfileConfig{M}) where {M}
    # All instances attempted (for any solver/model)
    df_instances = unique(select(df, cfg.instance_cols...))
    if isempty(df_instances)
        @warn "No instances found in benchmark results."
        return nothing
    end

    # Filter runs according to configuration
    df_filtered = filter(row -> cfg.row_filter(row) && cfg.is_success(row), df)
    if isempty(df_filtered)
        @warn "No successful benchmark entry to analyze."
        return nothing
    end

    # Extract metric
    df_filtered.metric = [cfg.criterion.value(row) for row in eachrow(df_filtered)]
    df_filtered = dropmissing(df_filtered, :metric)
    if isempty(df_filtered)
        @warn "No valid metric values available for performance profile."
        return nothing
    end

    # Aggregate per (instance, solver)
    group_cols = vcat(cfg.instance_cols, cfg.solver_cols)
    grouped = groupby(df_filtered, group_cols)
    df_metric = combine(grouped, :metric => (xs -> cfg.aggregate(xs)) => :metric)

    # Best metric per instance according to the criterion
    inst_grouped = groupby(df_metric, cfg.instance_cols)
    function _best_metric(xs)
        best = xs[1]
        for i in 2:length(xs)
            best = cfg.criterion.better(xs[i], best) ? xs[i] : best
        end
        return best
    end
    df_best = combine(inst_grouped, :metric => _best_metric => :best_metric)
    df_metric = leftjoin(df_metric, df_best, on = cfg.instance_cols)

    # Dolan–Moré ratio (assumes smaller is better for the chosen metric)
    df_metric.ratio = df_metric.metric ./ df_metric.best_metric

    # Solver/model combination labels
    combos = String[]
    for row in eachrow(df_metric)
        parts = [string(row[c]) for c in cfg.solver_cols]
        push!(combos, "(" * join(parts, ", ") * ")")
    end
    df_metric.combo = combos
    unique_combos = unique(df_metric.combo)

    # Ratio bounds across all combinations
    min_ratio = Inf
    max_ratio = 1.0
    for c in unique_combos
        sub = filter(row -> row.combo == c, df_metric)
        ratios = collect(skipmissing(sub.ratio))
        if !isempty(ratios)
            max_ratio = max(max_ratio, maximum(ratios))
            min_ratio = min(min_ratio, minimum(ratios))
        end
    end

    total_instances = nrow(df_instances)

    return PerformanceProfile(
        String(bench_id),
        df_instances,
        df_metric,
        unique_combos,
        total_instances,
        min_ratio,
        max_ratio,
        cfg,
    )
end

function compute_profile_generic(bench_id::AbstractString,
                                 src_dir::AbstractString,
                                 cfg::PerformanceProfileConfig{M}) where {M}
    raw = _get_bench_data(bench_id, src_dir)
    if raw === nothing
        @warn "No result (missing or invalid file) for bench_id: $bench_id"
        return nothing
    end

    rows = get(raw, "results", Any[])
    if isempty(rows)
        @warn "No ('results') recorded in the benchmark file."
        return nothing
    end

    df = DataFrame(rows)
    return build_profile_from_df(df, bench_id, cfg)
end

function compute_profile_default_cpu(bench_id::AbstractString,
                                     src_dir::AbstractString)
    cpu_criterion = ProfileCriterion{Float64}(
        "CPU time (s)",
        row -> begin
            bench = row.benchmark
            if bench === nothing || ismissing(bench)
                return NaN
            end
            time_raw = get(bench, "time", nothing)
            time_raw === nothing && return NaN
            return Float64(time_raw)
        end,
        (a, b) -> a <= b,
    )

    cfg = PerformanceProfileConfig{Float64}(
        [:problem, :grid_size],
        [:model, :solver],
        cpu_criterion,
        row -> row.success == true && row.benchmark !== nothing,
        row -> true,
        xs -> mean(skipmissing(xs)),
    )

    return compute_profile_generic(bench_id, src_dir, cfg)
end

function compute_performance_profile(bench_id::AbstractString, src_dir::AbstractString)
    return compute_profile_default_cpu(bench_id, src_dir)
end

# ───────────────────────────────────────────────────────────────────────────────
# Performance Profile Plotting
# ───────────────────────────────────────────────────────────────────────────────

"""
    plot_performance_profile(pp::PerformanceProfile) -> Plots.Plot

Generate a Dolan–Moré performance profile plot from a PerformanceProfile struct.

# Arguments
- `pp::PerformanceProfile`: Pre-computed performance profile data

# Returns
- `Plots.Plot`: Performance profile visualization

# Details
Creates a performance profile plot showing the proportion of solved instances
for each solver-model combination relative to the best solver for each problem.

The plot uses:
- Log scale (base 2) on the x-axis for performance ratio (τ)
- Proportion of solved instances on the y-axis
- One curve per (model, solver) combination
"""
function plot_performance_profile(pp::PerformanceProfile)
    title_font, label_font = _plot_font_settings()
    
    gap = log2(pp.max_ratio) - log2(pp.min_ratio)
    factor = 0.02
    xlim_max = pp.max_ratio * (1 + factor * gap)
    xlim_min = 1.0 * (1 - factor * gap)
    
    plt = plot(
        xlabel = "τ (Performance ratio)",
        ylabel = "Proportion of solved instances ≤ τ",
        title = "\nPerformance profile — models × solvers",
        legend = :bottomright,
        xscale = :log2,
        grid = true,
        size = (900, 600),
        titlefont = title_font,
        xguidefont = label_font,
        yguidefont = label_font,
        xticks = ([1, 2, 4, 10, 50, 100], ["1", "2", "4", "10", "50", "100"]),
        xlims = (xlim_min, xlim_max),
        ylims = (-0.05, 1.05),
        yticks = ([0.0, 0.10, 0.20, 0.30, 0.40, 0.50, 0.60, 0.70, 0.80, 0.90, 1.0], 
                  ["0", "10%", "20%", "30%", "40%", "50%", "60%", "70%", "80%", "90%", "100%"]),
        left_margin = 5mm,
        bottom_margin = 5mm,
        top_margin = 5mm,
    )

    n_curves = length(pp.combos)

    for (idx, c) in enumerate(pp.combos)
        sub = filter(row -> row.combo == c, pp.df_successful)
        ratios = sort(collect(skipmissing(sub.ratio)))
        
        if !isempty(ratios)
            first_row = first(eachrow(sub))
            color = CTBenchmarks.get_color(first_row.model, first_row.solver, idx)
            
            # Compute ρ_s(τ) = (1/N) * count(r_{p,s} ≤ τ)
            # For each ratio value, count how many ratios are ≤ to it
            y = [count(x -> x <= tau, ratios) / pp.total_problems for tau in ratios]

            marker_indices = _marker_indices_for_curve(ratios)
            x_markers = ratios[marker_indices]
            y_markers = y[marker_indices]
            marker = CTBenchmarks.get_marker_style(first_row.model, first_row.solver, idx)
            
            # Plot the curve
            plot!(ratios, y, label = "", lw = 1.5, color = color)
            
            scatter!(x_markers, y_markers;
                     color = color, markershape = marker,
                     markersize = 4, markerstrokewidth = 0, label = "")
            
            # Add marker on the first point of the curve
            plot!([ratios[1]], [y[1]];
                  color = color, linewidth = 1.5,
                  markershape = marker, markersize = 4,
                  label = c, markerstrokewidth = 0)
        end
    end
    
    # Add reference lines with low z-order (plot them last)
    vline!([1.0], color = :black, lw = 0.5, label = "", linestyle = :solid, z_order = 1)
    hline!([0.0], color = :black, lw = 0.5, label = "", linestyle = :solid, z_order = 1)
    hline!([1.0], color = :black, lw = 0.5, label = "", linestyle = :solid, z_order = 1)

    return plt
end

# ───────────────────────────────────────────────────────────────────────────────
# Public API (Wrapper)
# ───────────────────────────────────────────────────────────────────────────────

"""
    _plot_profile_default_cpu(bench_id, src_dir)

Generate and display the default CPU-time performance profile plot for a
benchmark.

This is a convenience wrapper around `compute_profile_default_cpu` and
`plot_performance_profile`.
"""
function _plot_profile_default_cpu(bench_id::AbstractString, src_dir::AbstractString)
    pp = compute_profile_default_cpu(bench_id, src_dir)
    if pp === nothing
        println("⚠️ No result (missing or invalid file) for bench_id: $bench_id")
        return plot()  # Empty plot on error
    end

    plt = plot_performance_profile(pp)
    @info "  ✅ Default CPU performance profile generated."
    return plt
end