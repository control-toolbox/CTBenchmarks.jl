# ═══════════════════════════════════════════════════════════════════════════════
# Profile Registry for Documentation
# ═══════════════════════════════════════════════════════════════════════════════

using CTBenchmarks
using Statistics

"""
    PROFILE_REGISTRY

Global registry for performance profile configurations used in the documentation.
"""
const PROFILE_REGISTRY = CTBenchmarks.PerformanceProfileRegistry()

"""
    init_default_profiles!()

Initialize the global `PROFILE_REGISTRY` with standard performance profile
configurations:
- `"default_cpu"`: Based on `row.benchmark["time"]` (CPU time).
- `"default_iter"`: Based on `row.iterations`.

Both use `(problem, grid_size)` as instances and `(model, solver)` as combos.
"""
function init_default_profiles!()
    # 1. Default CPU Profile
    cpu_criterion = CTBenchmarks.ProfileCriterion{Float64}(
        "CPU time",
        row -> begin
            bench = get(row, :benchmark, nothing)
            if bench === nothing || ismissing(bench)
                return NaN
            end
            time_raw = get(bench, "time", nothing)
            time_raw === nothing && return NaN
            return Float64(time_raw)
        end,
        (a, b) -> a <= b
    )

    cpu_config = CTBenchmarks.PerformanceProfileConfig{Float64}(
        [:problem, :grid_size],
        [:model, :solver],
        cpu_criterion,
        row -> row.success == true && get(row, :benchmark, nothing) !== nothing,
        row -> true,
        xs -> Statistics.mean(skipmissing(xs))
    )
    CTBenchmarks.register!(PROFILE_REGISTRY, "default_cpu", cpu_config)

    # 2. Default Iterations Profile
    iter_criterion = CTBenchmarks.ProfileCriterion{Float64}(
        "Iterations",
        row -> begin
            if !hasproperty(row, :iterations) || ismissing(row.iterations)
                return NaN
            end
            return Float64(row.iterations)
        end,
        (a, b) -> a <= b
    )

    iter_config = CTBenchmarks.PerformanceProfileConfig{Float64}(
        [:problem, :grid_size],
        [:model, :solver],
        iter_criterion,
        row -> row.success == true && hasproperty(row, :iterations) && !ismissing(row.iterations),
        row -> true,
        xs -> Statistics.mean(skipmissing(xs))
    )
    CTBenchmarks.register!(PROFILE_REGISTRY, "default_iter", iter_config)

    return nothing
end

# ───────────────────────────────────────────────────────────────────────────────
# Registry-based Wrappers
# ───────────────────────────────────────────────────────────────────────────────

"""
    plot_profile_from_registry(name::String, bench_id::AbstractString, src_dir::AbstractString; combos=nothing)

Generate a performance profile plot for a benchmark using a registered configuration.

# Arguments
- `name`: Name of the profile configuration in the registry.
- `bench_id`: Benchmark identifier.
- `src_dir`: Directory containing the benchmark results.
- `combos`: Optional list of solver combinations to include.
"""
function plot_profile_from_registry(
    name::String,
    bench_id::AbstractString,
    src_dir::AbstractString;
    combos::Union{Nothing,Vector{<:Tuple}}=nothing
)
    config = CTBenchmarks.get_config(PROFILE_REGISTRY, name)
    json_path = joinpath(src_dir, "assets", "benchmarks", bench_id, bench_id * ".json")
    df = CTBenchmarks.load_benchmark_df(json_path)

    if isempty(df)
        return Plots.plot() # Empty plot if no data
    end

    pp = CTBenchmarks.build_profile_from_df(df, bench_id, config; allowed_combos=combos)

    if pp === nothing
        return Plots.plot()
    end

    return CTBenchmarks.plot_performance_profile(pp)
end

"""
    analyze_profile_from_registry(name::String, bench_id::AbstractString, src_dir::AbstractString; combos=nothing)

Generate a textual analysis of a performance profile for a benchmark using a registered configuration.

# Arguments
- `name`: Name of the profile configuration in the registry.
- `bench_id`: Benchmark identifier.
- `src_dir`: Directory containing the benchmark results.
- `combos`: Optional list of solver combinations to include.
"""
function analyze_profile_from_registry(
    name::String,
    bench_id::AbstractString,
    src_dir::AbstractString;
    combos::Union{Nothing,Vector{<:Tuple}}=nothing
)
    config = CTBenchmarks.get_config(PROFILE_REGISTRY, name)
    json_path = joinpath(src_dir, "assets", "benchmarks", bench_id, bench_id * ".json")
    df = CTBenchmarks.load_benchmark_df(json_path)

    if isempty(df)
        return "!!! warning\n    No benchmark data available for analysis for `$bench_id`.\n"
    end

    pp = CTBenchmarks.build_profile_from_df(df, bench_id, config; allowed_combos=combos)

    if pp === nothing
        return "!!! warning\n    No successful runs found to analyze for `$bench_id`.\n"
    end

    return CTBenchmarks.analyze_performance_profile(pp)
end

# ───────────────────────────────────────────────────────────────────────────────
# Generic adapters for Template System (INCLUDE_FIGURE / INCLUDE_TEXT)
# ───────────────────────────────────────────────────────────────────────────────

"""
    _plot_profile_from_registry_from_args(args...)

Adapter for `INCLUDE_FIGURE` to call `plot_profile_from_registry`.
Expected arguments: `name`, `bench_id`, and optional `model:solver` combos.
"""
function _plot_profile_from_registry_from_args(args...)
    if length(args) < 2
        error("plot_profile_from_registry requires at least 2 arguments: name, bench_id")
    end

    name = String(args[1])
    bench_id = String(args[2])

    if length(args) == 2
        return plot_profile_from_registry(name, bench_id, SRC_DIR)
    end

    combos = _parse_combo_specs(args[3:end])
    return plot_profile_from_registry(name, bench_id, SRC_DIR; combos=combos)
end

"""
    _analyze_profile_from_registry_from_args(args...)

Adapter for `INCLUDE_TEXT` to call `analyze_profile_from_registry`.
Expected arguments: `name`, `bench_id`, and optional `model:solver` combos.
"""
function _analyze_profile_from_registry_from_args(args...)
    if length(args) < 2
        error("analyze_profile_from_registry requires at least 2 arguments: name, bench_id")
    end

    name = String(args[1])
    bench_id = String(args[2])

    if length(args) == 2
        return analyze_profile_from_registry(name, bench_id, SRC_DIR)
    end

    combos = _parse_combo_specs(args[3:end])
    return analyze_profile_from_registry(name, bench_id, SRC_DIR; combos=combos)
end

"""
    _parse_combo_specs(specs)

Shared helper to parse "model:solver" strings into Tuple{String, String} vector.
"""
function _parse_combo_specs(specs)
    combos = Tuple{String,String}[]
    for spec in specs
        parts = split(String(spec), ":")
        if length(parts) != 2
            error("Invalid combo specification '$spec'. Expected 'model:solver'.")
        end
        push!(combos, (String(parts[1]), String(parts[2])))
    end
    return combos
end
