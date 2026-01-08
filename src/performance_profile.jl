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

    if isempty(df_filtered)
        @warn "No successful benchmark entry to analyze."
        return nothing
    end

    # Extract metric
    df_filtered = copy(df_filtered)
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
        for x in xs[2:end]
            best = cfg.criterion.better(x, best) ? x : best
        end
        return best
    end
    df_best = combine(inst_grouped, :metric => _best_metric => :best_metric)
    df_metric = leftjoin(df_metric, df_best; on=cfg.instance_cols)

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

    plt = plot(;
        xlabel="τ (Performance ratio)",
        ylabel="Proportion of solved instances ≤ τ",
        title="\nPerformance profile — " * pp.config.criterion.name,
        legend=:bottomright,
        xscale=:log2,
        grid=true,
        size=(900, 600),
        titlefont=title_font,
        xguidefont=label_font,
        yguidefont=label_font,
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
    )

    for (idx, c) in enumerate(pp.combos)
        sub = filter(row -> row.combo == c, pp.df_successful)
        ratios = sort(collect(skipmissing(sub.ratio)))

        if !isempty(ratios)
            first_row = first(eachrow(sub))
            color = get_color(first_row.model, first_row.solver, idx)

            # Compute ρ_s(τ) = (1/N) * count(r_{p,s} ≤ τ)
            # For each ratio value, count how many ratios are ≤ to it
            y = [count(x -> x <= tau, ratios) / pp.total_problems for tau in ratios]

            marker_indices = _marker_indices_for_curve(ratios)
            x_markers = ratios[marker_indices]
            y_markers = y[marker_indices]
            marker = get_marker_style(first_row.model, first_row.solver, idx)

            # Plot the curve
            plot!(ratios, y; label="", lw=1.5, color=color)

            scatter!(
                x_markers,
                y_markers;
                color=color,
                markershape=marker,
                markersize=4,
                markerstrokewidth=0,
                label="",
            )

            # Add marker on the first point of the curve
            plot!(
                [ratios[1]],
                [y[1]];
                color=color,
                linewidth=1.5,
                markershape=marker,
                markersize=4,
                label=c,
                markerstrokewidth=0,
            )
        end
    end

    # Add reference lines with low z-order (plot them last)
    vline!([1.0]; color=:black, lw=0.5, label="", linestyle=:solid, z_order=1)
    hline!([0.0]; color=:black, lw=0.5, label="", linestyle=:solid, z_order=1)
    hline!([1.0]; color=:black, lw=0.5, label="", linestyle=:solid, z_order=1)

    return plt
end

# ───────────────────────────────────────────────────────────────────────────────
# Performance Profile Analysis
# ───────────────────────────────────────────────────────────────────────────────

"""
    analyze_performance_profile(pp::PerformanceProfile) -> String

Generate a detailed textual analysis of a performance profile.

# Arguments
- `pp::PerformanceProfile`: pre-computed performance profile data used to
  build Dolan–Moré performance profiles over `(problem, grid_size)` instances
  and `(model, solver)` combinations.

# Returns
- `String`: Markdown string with analysis insights including:
  - dataset overview (problems, instances, solver–model combinations),
  - robustness metrics (percentage of instances solved per combination),
  - efficiency metrics (percentage of instances where each combination was
    the fastest).

# Details
This function extracts key metrics from the performance profile:
- **Robustness**: proportion of instances successfully solved by each
  solver–model combination;
- **Efficiency**: proportion of instances where each solver–model achieved the
  best time (ratio `r_{p,s} = 1.0`).
"""
function analyze_performance_profile(pp::PerformanceProfile)
    buf = IOBuffer()

    print(buf, "!!! info \"Performance Profile Analysis\"\n")
    print(buf, "    **Dataset overview for `$(pp.bench_id)`:**\n")
    print(
        buf,
        "    - **Problems**: ",
        length(unique(pp.df_instances.problem)),
        " unique optimal control problems\n",
    )
    print(buf, "    - **Instances**: ", pp.total_problems, "\n")
    print(buf, "    - **Solver combos**: ", length(pp.combos), "\n")

    # Profile configuration (instances, combos, criterion)
    cfg = pp.config
    instance_cols = join(string.(cfg.instance_cols), ", ")
    solver_cols = join(string.(cfg.solver_cols), ", ")

    print(buf, "\n")
    print(buf, "    **Profile configuration:**\n")
    print(buf, "    - **Instance definition**: (", instance_cols, ")\n")
    print(buf, "    - **Solver combos definition**: (", solver_cols, ")\n")
    print(buf, "    - **Criterion**: ", cfg.criterion.name, "\n")

    # Compute total successful runs across all solver-model combinations
    total_runs = pp.total_problems * length(pp.combos)
    n_successful_runs = nrow(pp.df_successful)
    success_percentage = round(100 * n_successful_runs / total_runs; digits=1)
    print(
        buf,
        "    - **Successful runs**: ",
        n_successful_runs,
        "/",
        total_runs,
        " (",
        success_percentage,
        "%)\n",
    )

    # Compute successful instances: instances with at least one successful combo
    solved_instances = unique(select(pp.df_successful, cfg.instance_cols))
    n_successful_instances = nrow(solved_instances)
    success_instances_percentage = round(
        100 * n_successful_instances / pp.total_problems; digits=1
    )
    print(
        buf,
        "    - **Successful instances**: ",
        n_successful_instances,
        "/",
        pp.total_problems,
        " (",
        success_instances_percentage,
        "%)\n",
    )

    # Identify instances with no successful run for any solver-model combination
    solved_set = Set(Tuple(row[c] for c in cfg.instance_cols) for row in eachrow(solved_instances))
    unsuccessful_instances = [
        Tuple(row[c] for c in cfg.instance_cols) for
        row in eachrow(pp.df_instances) if !(Tuple(row[c] for c in cfg.instance_cols) in solved_set)
    ]

    if isempty(unsuccessful_instances)
        print(
            buf,
            "    - **Unsuccessful instances**: none (every instance had at least one successful run)\n",
        )
    else
        print(buf, "    - **Unsuccessful instances** (no solver converged):\n")
        sort!(unsuccessful_instances)
        for inst in unsuccessful_instances
            print(buf, "      - `", join(string.(inst), ", "), "`\n")
        end
    end
    print(buf, "\n")

    # Compute robustness: % of instances solved by each combo
    print(buf, "    **Robustness (% of instances solved):**\n")
    robustness_data = []
    for c in pp.combos
        sub = filter(row -> row.combo == c, pp.df_successful)
        n_solved = nrow(unique(select(sub, cfg.instance_cols)))
        success_rate = round(100 * n_solved / pp.total_problems; digits=1)
        push!(robustness_data, (combo=c, rate=success_rate))
        print(buf, "    - `$c`: $success_rate%\n")
    end

    # Compute efficiency: % of instances where fastest (ratio = 1.0)
    print(buf, "    **Efficiency (% of instances where fastest):**\n")
    efficiency_data = []
    for c in pp.combos
        sub = filter(row -> row.combo == c, pp.df_successful)
        n_best = count(row -> row.ratio == 1.0, eachrow(sub))
        best_rate = round(100 * n_best / pp.total_problems; digits=1)
        push!(efficiency_data, (combo=c, rate=best_rate))
        print(buf, "    - `$c`: $best_rate%\n")
    end

    # Find best overall performer (highest robustness)
    if !isempty(robustness_data)
        best_robust = maximum(r -> r.rate, robustness_data)
        best_robust_combos = [r.combo for r in robustness_data if r.rate == best_robust]
        if length(best_robust_combos) == 1
            print(
                buf,
                "    **Most robust**: `$(best_robust_combos[1])` solved $best_robust% of instances.\n",
            )
        else
            print(
                buf,
                "    **Most robust**: $(length(best_robust_combos)) combinations tied at $best_robust%.\n",
            )
        end
    end
    print(buf, "\n")

    # Find most efficient performer (highest efficiency)
    if !isempty(efficiency_data)
        best_efficient = maximum(e -> e.rate, efficiency_data)
        best_efficient_combos = [
            e.combo for e in efficiency_data if e.rate == best_efficient
        ]
        if length(best_efficient_combos) == 1
            print(
                buf,
                "    **Most efficient**: `$(best_efficient_combos[1])` was fastest on $best_efficient% of instances.\n",
            )
        else
            print(
                buf,
                "    **Most efficient**: $(length(best_efficient_combos)) combinations tied at $best_efficient%.\n",
            )
        end
    end
    print(buf, "\n")

    return String(take!(buf))
end
