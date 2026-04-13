# ═══════════════════════════════════════════════════════════════════════════════
# Profile Engine Module
# ═══════════════════════════════════════════════════════════════════════════════
#
# This module provides the infrastructure for registering and using performance
# profile configurations.
#
# ═══════════════════════════════════════════════════════════════════════════════

"""
    PROFILE_REGISTRY

Global registry for performance profile configurations used in the documentation.
"""
const PROFILE_REGISTRY = CTBenchmarks.PerformanceProfileRegistry()

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
