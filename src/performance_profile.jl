# ═══════════════════════════════════════════════════════════════════════════════
# Performance Profile Module
# ═══════════════════════════════════════════════════════════════════════════════
#
# This module provides generic types and functions for building, plotting, and
# analyzing Dolan–Moré performance profiles from benchmark data.
#
# ═══════════════════════════════════════════════════════════════════════════════

import Statistics: mean

# ───────────────────────────────────────────────────────────────────────────────
# Data Structures
# ───────────────────────────────────────────────────────────────────────────────

"""
    ProfileCriterion{M}

Criterion used to extract and compare a scalar metric from benchmark runs.

# Fields
- `name::String`: Human-readable name of the criterion (e.g., "CPU time (s)").
- `value::Function`: Function `row::DataFrameRow -> M` extracting the metric.
- `better::Function`: Function `(a::M, b::M) -> Bool` returning `true` if `a`
  is strictly better than `b` according to the criterion.

# Example
```julia
cpu_criterion = ProfileCriterion{Float64}(
    "CPU time (s)",
    row -> get(row.benchmark, "time", NaN),
    (a, b) -> a <= b
)
```
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

# Example
```julia
config = PerformanceProfileConfig{Float64}(
    [:problem, :grid_size],
    [:model, :solver],
    cpu_criterion,
    row -> row.success == true && row.benchmark !== nothing,
    row -> true,
    xs -> mean(skipmissing(xs))
)
```
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

"""
    ProfileStats

Statistical summary of a performance profile dataset.

# Fields
- `n_problems::Int`: Number of unique problems
- `n_instances::Int`: Total number of instances (problem × grid_size combinations)
- `n_combos::Int`: Number of solver combinations
- `n_successful_runs::Int`: Number of successful runs across all combos
- `n_successful_instances::Int`: Number of instances with at least one successful run
- `unsuccessful_instances::Vector{Tuple}`: List of instances that failed for all combos
- `instance_cols::Vector{Symbol}`: Instance column names
- `solver_cols::Vector{Symbol}`: Solver column names
- `criterion_name::String`: Name of the performance criterion
"""
struct ProfileStats
    n_problems::Int
    n_instances::Int
    n_combos::Int
    n_successful_runs::Int
    n_successful_instances::Int
    unsuccessful_instances::Vector{Tuple}
    instance_cols::Vector{Symbol}
    solver_cols::Vector{Symbol}
    criterion_name::String
end

"""
    ComboPerformance

Performance metrics for a single solver combination.

# Fields
- `combo::String`: Solver combination label (e.g., "(exa, ipopt)")
- `robustness::Float64`: Percentage of instances solved (0-100)
- `efficiency::Float64`: Percentage of instances where this combo was fastest (0-100)
"""
struct ComboPerformance
    combo::String
    robustness::Float64
    efficiency::Float64
end

"""
    ProfileAnalysis

Complete analysis results for a performance profile.

# Fields
- `bench_id::String`: Benchmark identifier
- `stats::ProfileStats`: Statistical summary
- `performances::Vector{ComboPerformance}`: Performance metrics for each combo
- `most_robust::Vector{String}`: Combo(s) with highest robustness
- `most_efficient::Vector{String}`: Combo(s) with highest efficiency
"""
struct ProfileAnalysis
    bench_id::String
    stats::ProfileStats
    performances::Vector{ComboPerformance}
    most_robust::Vector{String}
    most_efficient::Vector{String}
end

# ───────────────────────────────────────────────────────────────────────────────
# Registry
# ───────────────────────────────────────────────────────────────────────────────

"""
    PerformanceProfileRegistry

A container for named performance profile configurations.

# Example
```julia
registry = PerformanceProfileRegistry()
register!(registry, "default_cpu", cpu_config)
config = get_config(registry, "default_cpu")
```
"""
struct PerformanceProfileRegistry
    configs::Dict{String,PerformanceProfileConfig}
    PerformanceProfileRegistry() = new(Dict{String,PerformanceProfileConfig}())
end

"""
    register!(registry::PerformanceProfileRegistry, name::AbstractString, config::PerformanceProfileConfig)

Register a performance profile configuration under a given name.

# Arguments
- `registry`: The registry to add the configuration to.
- `name`: Name to associate with the configuration.
- `config`: The performance profile configuration.
"""
function register!(
    registry::PerformanceProfileRegistry,
    name::AbstractString,
    config::PerformanceProfileConfig,
)
    registry.configs[String(name)] = config
    return nothing
end

"""
    get_config(registry::PerformanceProfileRegistry, name::AbstractString) -> PerformanceProfileConfig

Retrieve a registered performance profile configuration by name.

# Arguments
- `registry`: The registry to search.
- `name`: Name of the configuration.

# Throws
- `KeyError` if the name is not found in the registry.
"""
function get_config(registry::PerformanceProfileRegistry, name::AbstractString)
    key = String(name)
    haskey(registry.configs, key) || throw(KeyError("Profile '$key' not found in registry"))
    return registry.configs[key]
end

"""
    list_profiles(registry::PerformanceProfileRegistry) -> Vector{String}

Return a list of all registered profile names.
"""
function list_profiles(registry::PerformanceProfileRegistry)
    return collect(keys(registry.configs))
end

# ───────────────────────────────────────────────────────────────────────────────
# Data Loading
# ───────────────────────────────────────────────────────────────────────────────

"""
    load_benchmark_df(source::AbstractString) -> DataFrame

Load benchmark data from a JSON file path.

# Arguments
- `source`: Path to a JSON file containing benchmark results.

# Returns
- `DataFrame` with the "results" array from the JSON, or an empty DataFrame if not found.
"""
function load_benchmark_df(source::AbstractString)
    if !isfile(source)
        @warn "Benchmark file not found: $source"
        return DataFrame()
    end
    data = open(source, "r") do io
        JSON.parse(io)
    end
    results = get(data, "results", Any[])
    return DataFrame(results)
end

"""
    load_benchmark_df(source::Dict) -> DataFrame

Load benchmark data from a parsed JSON dictionary.

# Arguments
- `source`: Dictionary containing benchmark data with a "results" key.

# Returns
- `DataFrame` with the "results" array, or an empty DataFrame if not found.
"""
function load_benchmark_df(source::Dict)
    results = get(source, "results", Any[])
    return DataFrame(results)
end

"""
    load_benchmark_df(source::DataFrame) -> DataFrame

Pass-through for already-loaded DataFrame.
"""
function load_benchmark_df(source::DataFrame)
    return source
end

# ───────────────────────────────────────────────────────────────────────────────
# Performance Profile Construction
# ───────────────────────────────────────────────────────────────────────────────


"""
    _filter_benchmark_data(df, cfg, allowed_combos) -> DataFrame

Filter benchmark rows based on configuration criteria and allowed combinations.
"""
function _filter_benchmark_data(df, cfg, allowed_combos)
    # Filter runs according to configuration
    df_filtered = filter(row -> cfg.row_filter(row) && cfg.is_success(row), df)

    # Optionally restrict to a subset of solver/model combinations
    if allowed_combos !== nothing && !isempty(allowed_combos)
        if cfg.solver_cols == [:model, :solver]
            allowed_set = Set(allowed_combos)
            df_filtered = filter(
                row -> begin
                    hasproperty(row, :model) &&
                        hasproperty(row, :solver) &&
                        (String(row.model), String(row.solver)) in allowed_set
                end,
                df_filtered,
            )
        else
            @warn "allowed_combos is only supported when solver_cols == [:model, :solver]; ignoring filter."
        end
    end

    return df_filtered
end

"""
    _extract_benchmark_metrics(df, cfg) -> DataFrame

Extract the performance metric from each row using the criterion function.
"""
function _extract_benchmark_metrics(df, cfg)
    df_metric = copy(df)
    df_metric.metric = [cfg.criterion.value(row) for row in eachrow(df_metric)]
    dropmissing!(df_metric, :metric)
    return df_metric
end

"""
    _aggregate_metrics(df, cfg) -> DataFrame

Aggregate metrics when multiple runs exist for the same instance/solver combination.
"""
function _aggregate_metrics(df, cfg)
    group_cols = vcat(cfg.instance_cols, cfg.solver_cols)
    grouped = groupby(df, group_cols)

    # Use aggregation function from config
    return combine(grouped, :metric => (xs -> cfg.aggregate(xs)) => :metric)
end

"""
    _compute_dolan_more_ratios(df, cfg) -> DataFrame

Compute Dolan-Moré performance ratios (metric / best_metric).
"""
function _compute_dolan_more_ratios(df, cfg)
    # Best metric per instance according to the criterion
    inst_grouped = groupby(df, cfg.instance_cols)

    function _best_metric(xs)
        best = xs[1]
        for x in xs[2:end]
            best = cfg.criterion.better(x, best) ? x : best
        end
        return best
    end

    df_best = combine(inst_grouped, :metric => _best_metric => :best_metric)
    df_with_best = leftjoin(df, df_best; on=cfg.instance_cols)

    # Dolan–Moré ratio (assumes smaller is better for the chosen metric)
    df_with_best.ratio = df_with_best.metric ./ df_with_best.best_metric

    return df_with_best
end

"""
    _compute_profile_metadata(df, cfg) -> (Vector{String}, Float64, Float64)

Generate solver combination labels and compute min/max ratio bounds.
"""
function _compute_profile_metadata(df, cfg)
    # Solver/model combination labels
    combos = String[]
    for row in eachrow(df)
        parts = [string(row[c]) for c in cfg.solver_cols]
        push!(combos, "(" * join(parts, ", ") * ")")
    end
    df.combo = combos
    unique_combos = unique(df.combo)

    # Ratio bounds across all combinations
    min_ratio = Inf
    max_ratio = 1.0
    for c in unique_combos
        sub = filter(row -> row.combo == c, df)
        ratios = collect(skipmissing(sub.ratio))
        if !isempty(ratios)
            max_ratio = max(max_ratio, maximum(ratios))
            min_ratio = min(min_ratio, minimum(ratios))
        end
    end

    return unique_combos, min_ratio, max_ratio
end

"""
    build_profile_from_df(
        df::DataFrame,
        bench_id::AbstractString,
        cfg::PerformanceProfileConfig{M};
        allowed_combos::Union{Nothing, Vector{Tuple{String,String}}}=nothing,
    ) where {M}

Build a `PerformanceProfile{M}` from a benchmark results table.

This function takes a `DataFrame` of benchmark rows, applies the
`PerformanceProfileConfig{M}` (instance/solver columns, criterion, filters and
aggregation), and computes Dolan–Moré ratios and solver–model labels.

# Arguments
- `df::DataFrame`: raw benchmark results loaded from JSON.
- `bench_id::AbstractString`: benchmark identifier.
- `cfg::PerformanceProfileConfig{M}`: configuration describing how to extract
  and aggregate the metric.
- `allowed_combos::Union{Nothing, Vector{Tuple{String,String}}}`: optional
  list of `(model, solver)` combinations to keep; `nothing` uses all available
  combinations.

# Returns
- `PerformanceProfile{M}` if at least one valid metric is available;
  `nothing` if no instances or valid metrics are found.
"""
function build_profile_from_df(
    df::DataFrame,
    bench_id::AbstractString,
    cfg::PerformanceProfileConfig{M};
    allowed_combos::Union{Nothing,Vector{Tuple{String,String}}}=nothing,
) where {M}
    # All instances attempted (for any solver/model)
    df_instances = unique(select(df, cfg.instance_cols...))
    if isempty(df_instances)
        @warn "No instances found in benchmark results."
        return nothing
    end

    # 1. Filter runs
    df_filtered = _filter_benchmark_data(df, cfg, allowed_combos)
    if isempty(df_filtered)
        @warn "No successful benchmark entry to analyze."
        return nothing
    end

    # 2. Extract metrics
    df_metrics = _extract_benchmark_metrics(df_filtered, cfg)
    if isempty(df_metrics)
        @warn "No valid metric values available for performance profile."
        return nothing
    end

    # 3. Aggregate multiple runs
    df_agg = _aggregate_metrics(df_metrics, cfg)

    # 4. Compute ratios against best
    df_ratios = _compute_dolan_more_ratios(df_agg, cfg)

    # 5. Compute metadata (combos, bounds)
    unique_combos, min_ratio, max_ratio = _compute_profile_metadata(df_ratios, cfg)

    total_instances = nrow(df_instances)

    return PerformanceProfile(
        String(bench_id),
        df_instances,
        df_ratios,
        unique_combos,
        total_instances,
        min_ratio,
        max_ratio,
        cfg,
    )
end

# ───────────────────────────────────────────────────────────────────────────────
# Plotting Helpers
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
function _marker_indices_for_curve(ratios; M=6)
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
            x_target = 2.0^p
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

"""
    _plot_font_settings()

Return font settings for plot titles and axis labels.

# Returns
- `Tuple{Plots.Font, Plots.Font}`: tuple `(title_font, label_font)`.
"""
function _plot_font_settings()
    return font(14, Plots.default(:fontfamily)), font(10, Plots.default(:fontfamily))
end

# ───────────────────────────────────────────────────────────────────────────────
# Performance Profile Plotting
# ───────────────────────────────────────────────────────────────────────────────

"""
    PerformanceProfilePlotConfig

Configuration for performance profile plot styling.

# Fields
- `size::Tuple{Int,Int}`: Plot size (width, height)
- `xlabel::String`: X-axis label
- `ylabel::String`: Y-axis label
- `title_font::Plots.Font`: Font settings for the title
- `label_font::Plots.Font`: Font settings for labels
- `linewidth::Float64`: Width of the profile lines
- `markersize::Int`: Size of the markers
- `framestyle::Symbol`: Plot frame style
- `legend_position::Symbol`: Legend position
"""
struct PerformanceProfilePlotConfig
    size::Tuple{Int,Int}
    xlabel::String
    ylabel::String
    title_font::Plots.Font
    label_font::Plots.Font
    linewidth::Float64
    markersize::Int
    framestyle::Symbol
    legend_position::Symbol
end

"""
    default_plot_config() -> PerformanceProfilePlotConfig

Create a default configuration for performance profile plots.
"""
function default_plot_config()
    title_font, label_font = _plot_font_settings()
    return PerformanceProfilePlotConfig(
        (900, 600),
        "τ (Performance ratio)",
        "Proportion of solved instances ≤ τ",
        title_font,
        label_font,
        1.5,
        4,
        :box,
        :bottomright
    )
end

"""
    _init_profile_plot(pp, cfg) -> Plots.Plot

Initialize the plot canvas with axes configuration.
"""
function _init_profile_plot(pp, cfg::PerformanceProfilePlotConfig)
    gap = log2(pp.max_ratio) - log2(pp.min_ratio)
    factor = 0.02
    xlim_max = pp.max_ratio * (1 + factor * gap)
    xlim_min = 1.0 * (1 - factor * gap)

    return plot(;
        xlabel=cfg.xlabel,
        ylabel=cfg.ylabel,
        title="\nPerformance profile — " * pp.config.criterion.name,
        legend=cfg.legend_position,
        xscale=:log2,
        grid=true,
        size=cfg.size,
        titlefont=cfg.title_font,
        xguidefont=cfg.label_font,
        yguidefont=cfg.label_font,
        xticks=([1, 2, 4, 10, 50, 100], ["1", "2", "4", "10", "50", "100"]),
        xlims=(xlim_min, xlim_max),
        ylims=(-0.05, 1.05),
        yticks=(
            [0.0, 0.10, 0.20, 0.30, 0.40, 0.50, 0.60, 0.70, 0.80, 0.90, 1.0],
            ["0", "10%", "20%", "30%", "40%", "50%", "60%", "70%", "80%", "90%", "100%"],
        ),
        left_margin=5mm,
        bottom_margin=5mm,
        top_margin=5mm,
        framestyle=cfg.framestyle,
    )
end

"""
    _compute_curve_points(ratios, total_problems) -> (Vector{Float64}, Vector{Float64})

Compute the step function (x, y) points for the performance profile.
"""
function _compute_curve_points(ratios, total_problems)
    # Compute ρ_s(τ) = (1/N) * count(r_{p,s} ≤ τ)
    # For each ratio value, count how many ratios are ≤ to it
    y = [count(x -> x <= tau, ratios) / total_problems for tau in ratios]
    return ratios, y
end

"""
    _add_combo_series!(plt, x, y, label, color, marker, cfg)

Add a single solver combination series (line + markers) to the plot.
"""
function _add_combo_series!(plt, x, y, label, color, marker, cfg::PerformanceProfilePlotConfig)
    # Plot the curve
    plot!(plt, x, y; label="", lw=cfg.linewidth, color=color)

    # Add markers at regular intervals
    marker_indices = _marker_indices_for_curve(x)
    x_markers = x[marker_indices]
    y_markers = y[marker_indices]

    scatter!(plt,
        x_markers,
        y_markers;
        color=color,
        markershape=marker,
        markersize=cfg.markersize,
        markerstrokewidth=0,
        label="",
    )

    # Add marker/label entry on the first point of the curve for the legend
    plot!(plt,
        [x[1]],
        [y[1]];
        color=color,
        linewidth=cfg.linewidth,
        markershape=marker,
        markersize=cfg.markersize,
        label=label,
        markerstrokewidth=0,
    )
end

"""
    _add_reference_lines!(plt)

Add reference lines at y=0, y=1 and x=1.
"""
function _add_reference_lines!(plt)
    vline!(plt, [1.0]; color=:black, lw=0.5, label="", linestyle=:solid, z_order=1)
    hline!(plt, [0.0]; color=:black, lw=0.5, label="", linestyle=:solid, z_order=1)
    hline!(plt, [1.0]; color=:black, lw=0.5, label="", linestyle=:solid, z_order=1)
end

"""
    plot_performance_profile(pp::PerformanceProfile; plot_config=nothing) -> Plots.Plot

Generate a Dolan–Moré performance profile plot from a PerformanceProfile struct.

# Arguments
- `pp::PerformanceProfile`: Pre-computed performance profile data
- `plot_config::Union{Nothing, PerformanceProfilePlotConfig}`: Optional styling configuration

# Returns
- `Plots.Plot`: Performance profile visualization
"""
function plot_performance_profile(pp::PerformanceProfile; plot_config=nothing)
    cfg = isnothing(plot_config) ? default_plot_config() : plot_config
    plt = _init_profile_plot(pp, cfg)

    for (idx, c) in enumerate(pp.combos)
        sub = filter(row -> row.combo == c, pp.df_successful)
        ratios = sort(collect(skipmissing(sub.ratio)))

        if !isempty(ratios)
            first_row = first(eachrow(sub))
            color = get_color(first_row.model, first_row.solver, idx)
            marker = get_marker_style(first_row.model, first_row.solver, idx)

            x, y = _compute_curve_points(ratios, pp.total_problems)
            _add_combo_series!(plt, x, y, c, color, marker, cfg)
        end
    end

    _add_reference_lines!(plt)
    return plt
end

# ───────────────────────────────────────────────────────────────────────────────
# Performance Profile Analysis
# ───────────────────────────────────────────────────────────────────────────────

"""
    compute_profile_stats(pp::PerformanceProfile) -> ProfileAnalysis

Compute statistical analysis of a performance profile.

This function extracts and calculates all performance metrics without any
formatting. It returns structured data that can be used for different
presentation formats (Markdown, JSON, etc.).

# Arguments
- `pp::PerformanceProfile`: Pre-computed performance profile data

# Returns
- `ProfileAnalysis`: Structured analysis results
"""
function compute_profile_stats(pp::PerformanceProfile)
    cfg = pp.config

    # Compute basic statistics
    n_problems = length(unique(pp.df_instances.problem))
    n_instances = pp.total_problems
    n_combos = length(pp.combos)
    total_runs = n_instances * n_combos
    n_successful_runs = nrow(pp.df_successful)

    # Compute successful instances
    solved_instances = unique(select(pp.df_successful, cfg.instance_cols))
    n_successful_instances = nrow(solved_instances)

    # Identify unsuccessful instances
    solved_set = Set(
        Tuple(row[c] for c in cfg.instance_cols) for row in eachrow(solved_instances)
    )
    unsuccessful_instances = [
        Tuple(row[c] for c in cfg.instance_cols) for row in eachrow(pp.df_instances) if
        !(Tuple(row[c] for c in cfg.instance_cols) in solved_set)
    ]
    sort!(unsuccessful_instances)

    # Create ProfileStats
    stats = ProfileStats(
        n_problems,
        n_instances,
        n_combos,
        n_successful_runs,
        n_successful_instances,
        unsuccessful_instances,
        cfg.instance_cols,
        cfg.solver_cols,
        cfg.criterion.name,
    )

    # Compute performance metrics for each combo
    performances = ComboPerformance[]
    for c in pp.combos
        sub = filter(row -> row.combo == c, pp.df_successful)

        # Robustness: % of instances solved
        n_solved = nrow(unique(select(sub, cfg.instance_cols)))
        robustness = round(100 * n_solved / n_instances; digits=1)

        # Efficiency: % of instances where fastest
        n_best = count(row -> row.ratio == 1.0, eachrow(sub))
        efficiency = round(100 * n_best / n_instances; digits=1)

        push!(performances, ComboPerformance(c, robustness, efficiency))
    end

    # Find most robust combos
    if !isempty(performances)
        best_robust_rate = maximum(p -> p.robustness, performances)
        most_robust = [p.combo for p in performances if p.robustness == best_robust_rate]
    else
        most_robust = String[]
    end

    # Find most efficient combos
    if !isempty(performances)
        best_efficient_rate = maximum(p -> p.efficiency, performances)
        most_efficient =
            [p.combo for p in performances if p.efficiency == best_efficient_rate]
    else
        most_efficient = String[]
    end

    return ProfileAnalysis(
        pp.bench_id, stats, performances, most_robust, most_efficient
    )
end

"""
    format_analysis_markdown(analysis::ProfileAnalysis) -> String

Format a ProfileAnalysis as a Markdown string.

# Arguments
- `analysis::ProfileAnalysis`: Structured analysis results

# Returns
- `String`: Markdown-formatted analysis report
"""
function format_analysis_markdown(analysis::ProfileAnalysis)
    buf = IOBuffer()
    stats = analysis.stats

    # Header
    print(buf, "!!! info \"Performance Profile Analysis\"\n")
    print(buf, "    **Dataset overview for `$(analysis.bench_id)`:**\n")
    print(buf, "    - **Problems**: ", stats.n_problems, " unique optimal control problems\n")
    print(buf, "    - **Instances**: ", stats.n_instances, "\n")
    print(buf, "    - **Solver combos**: ", stats.n_combos, "\n")

    # Configuration
    instance_cols = join(string.(stats.instance_cols), ", ")
    solver_cols = join(string.(stats.solver_cols), ", ")
    print(buf, "\n")
    print(buf, "    **Profile configuration:**\n")
    print(buf, "    - **Instance definition**: (", instance_cols, ")\n")
    print(buf, "    - **Solver combos definition**: (", solver_cols, ")\n")
    print(buf, "    - **Criterion**: ", stats.criterion_name, "\n")

    # Success statistics
    total_runs = stats.n_instances * stats.n_combos
    success_percentage = round(100 * stats.n_successful_runs / total_runs; digits=1)
    print(
        buf,
        "    - **Successful runs**: ",
        stats.n_successful_runs,
        "/",
        total_runs,
        " (",
        success_percentage,
        "%)\n",
    )

    success_instances_percentage = round(
        100 * stats.n_successful_instances / stats.n_instances; digits=1
    )
    print(
        buf,
        "    - **Successful instances**: ",
        stats.n_successful_instances,
        "/",
        stats.n_instances,
        " (",
        success_instances_percentage,
        "%)\n",
    )

    # Unsuccessful instances
    if isempty(stats.unsuccessful_instances)
        print(
            buf,
            "    - **Unsuccessful instances**: none (every instance had at least one successful run)\n",
        )
    else
        print(buf, "    - **Unsuccessful instances** (no solver converged):\n")
        for inst in stats.unsuccessful_instances
            print(buf, "      - `", join(string.(inst), ", "), "`\n")
        end
    end
    print(buf, "\n")

    # Robustness
    print(buf, "    **Robustness (% of instances solved):**\n")
    for perf in analysis.performances
        print(buf, "    - `", perf.combo, "`: ", perf.robustness, "%\n")
    end

    # Efficiency
    print(buf, "    **Efficiency (% of instances where fastest):**\n")
    for perf in analysis.performances
        print(buf, "    - `", perf.combo, "`: ", perf.efficiency, "%\n")
    end

    # Best performers
    if !isempty(analysis.most_robust)
        if length(analysis.most_robust) == 1
            best_rate = analysis.performances[findfirst(
                p -> p.combo == analysis.most_robust[1], analysis.performances
            )].robustness
            print(
                buf,
                "    **Most robust**: `",
                analysis.most_robust[1],
                "` solved ",
                best_rate,
                "% of instances.\n",
            )
        else
            best_rate = analysis.performances[findfirst(
                p -> p.combo == analysis.most_robust[1], analysis.performances
            )].robustness
            print(
                buf,
                "    **Most robust**: ",
                length(analysis.most_robust),
                " combinations tied at ",
                best_rate,
                "%.\n",
            )
        end
    end
    print(buf, "\n")

    if !isempty(analysis.most_efficient)
        if length(analysis.most_efficient) == 1
            best_rate = analysis.performances[findfirst(
                p -> p.combo == analysis.most_efficient[1], analysis.performances
            )].efficiency
            print(
                buf,
                "    **Most efficient**: `",
                analysis.most_efficient[1],
                "` was fastest on ",
                best_rate,
                "% of instances.\n",
            )
        else
            best_rate = analysis.performances[findfirst(
                p -> p.combo == analysis.most_efficient[1], analysis.performances
            )].efficiency
            print(
                buf,
                "    **Most efficient**: ",
                length(analysis.most_efficient),
                " combinations tied at ",
                best_rate,
                "%.\n",
            )
        end
    end
    print(buf, "\n")

    return String(take!(buf))
end

"""
    analyze_performance_profile(pp::PerformanceProfile) -> String

Generate a detailed textual analysis of a performance profile.

This is a convenience function that combines `compute_profile_stats` and
`format_analysis_markdown`. For programmatic access to analysis data,
use `compute_profile_stats` directly.

# Arguments
- `pp::PerformanceProfile`: Pre-computed performance profile data

# Returns
- `String`: Markdown-formatted analysis report

# Details
This function extracts key metrics from the performance profile:
- **Robustness**: proportion of instances successfully solved by each combo
- **Efficiency**: proportion of instances where each combo was fastest
"""
function analyze_performance_profile(pp::PerformanceProfile)
    analysis = compute_profile_stats(pp)
    return format_analysis_markdown(analysis)
end
