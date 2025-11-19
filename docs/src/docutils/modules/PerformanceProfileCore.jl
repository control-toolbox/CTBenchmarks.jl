# ═══════════════════════════════════════════════════════════════════════════════
# Performance Profile Core Module
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
# Performance Profile Computation
# ───────────────────────────────────────────────────────────────────────────────

"""
    build_profile_from_df(
        df::DataFrame,
        bench_id::AbstractString,
        cfg::PerformanceProfileConfig{M};
        allowed_combos::Union{Nothing, Vector{Tuple{String,String}}}=nothing,
    ) where {M}

Build a `PerformanceProfile{M}` from a benchmark results table.

This helper takes a `DataFrame` of benchmark rows, applies the
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

"""
    compute_profile_generic(
        bench_id::AbstractString,
        src_dir::AbstractString,
        cfg::PerformanceProfileConfig{M};
        allowed_combos::Union{Nothing, Vector{Tuple{String,String}}}=nothing,
    ) where {M}

Generic entry point to compute a `PerformanceProfile{M}` from a benchmark
identified by `bench_id` using the provided configuration.

This function loads the benchmark JSON file, converts it to a `DataFrame`, and
delegates to `build_profile_from_df`.
"""
function compute_profile_generic(
    bench_id::AbstractString,
    src_dir::AbstractString,
    cfg::PerformanceProfileConfig{M};
    allowed_combos::Union{Nothing,Vector{Tuple{String,String}}}=nothing,
) where {M}
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
    return build_profile_from_df(df, bench_id, cfg; allowed_combos=allowed_combos)
end

"""
    compute_profile_default_cpu(
        bench_id::AbstractString,
        src_dir::AbstractString;
        allowed_combos::Union{Nothing, Vector{Tuple{String,String}}}=nothing,
    ) -> Union{PerformanceProfile{Float64}, Nothing}

Compute a default CPU-time performance profile for a benchmark.

The underlying metric is the CPU time stored in `row.benchmark["time"]`, and
instances are defined by `(problem, grid_size)` and solver combinations by
`(model, solver)`.
"""
function compute_profile_default_cpu(
    bench_id::AbstractString,
    src_dir::AbstractString;
    allowed_combos::Union{Nothing,Vector{Tuple{String,String}}}=nothing,
)
    cpu_criterion = ProfileCriterion{Float64}(
        "CPU time", row -> begin
            bench = row.benchmark
            if bench === nothing || ismissing(bench)
                return NaN
            end
            time_raw = get(bench, "time", nothing)
            time_raw === nothing && return NaN
            return Float64(time_raw)
        end, (a, b) -> a <= b
    )

    cfg = PerformanceProfileConfig{Float64}(
        [:problem, :grid_size],
        [:model, :solver],
        cpu_criterion,
        row -> row.success == true && row.benchmark !== nothing,
        row -> true,
        xs -> mean(skipmissing(xs)),
    )

    return compute_profile_generic(bench_id, src_dir, cfg; allowed_combos=allowed_combos)
end

"""
    compute_profile_default_iter(
        bench_id::AbstractString,
        src_dir::AbstractString;
        allowed_combos::Union{Nothing, Vector{Tuple{String,String}}}=nothing,
    ) -> Union{PerformanceProfile{Float64}, Nothing}

Compute a default iterations-based performance profile for a benchmark.

The underlying metric is the `iterations` field recorded in the benchmark
results, using the same instance and solver-combination definitions as the
CPU-time profile.
"""
function compute_profile_default_iter(
    bench_id::AbstractString,
    src_dir::AbstractString;
    allowed_combos::Union{Nothing,Vector{Tuple{String,String}}}=nothing,
)
    iter_criterion = ProfileCriterion{Float64}(
        "Iterations",
        row -> begin
            if !hasproperty(row, :iterations) || ismissing(row.iterations)
                return NaN
            end
            return Float64(row.iterations)
        end,
        (a, b) -> a <= b,
    )

    cfg = PerformanceProfileConfig{Float64}(
        [:problem, :grid_size],
        [:model, :solver],
        iter_criterion,
        row ->
            row.success == true &&
            hasproperty(row, :iterations) &&
            !ismissing(row.iterations),
        row -> true,
        xs -> mean(skipmissing(xs)),
    )

    return compute_profile_generic(bench_id, src_dir, cfg; allowed_combos=allowed_combos)
end

"""
    compute_performance_profile(bench_id::AbstractString, src_dir::AbstractString)

Convenience wrapper that calls `compute_profile_default_cpu`.

This function is kept for backward compatibility with older templates that
expect a single default performance profile.
"""
function compute_performance_profile(bench_id::AbstractString, src_dir::AbstractString)
    return compute_profile_default_cpu(bench_id, src_dir)
end
