# ═══════════════════════════════════════════════════════════════════════════════
# Default Profiles (Specific Handlers)
# ═══════════════════════════════════════════════════════════════════════════════
# Default Performance Profile Handlers
# ═══════════════════════════════════════════════════════════════════════════════

# ───────────────────────────────────────────────────────────────────────────────
# Common Filter and Aggregation Functions
# ───────────────────────────────────────────────────────────────────────────────

"""
Filter function: accepts rows where success is true and benchmark data is available.
"""
const IS_SUCCESS_WITH_BENCHMARK =
    row -> row.success == true && get(row, :benchmark, nothing) !== nothing

"""
Filter function: accepts rows where success is true and iterations data is available.
"""
const IS_SUCCESS_WITH_ITERATIONS =
    row -> row.success == true && hasproperty(row, :iterations) && !ismissing(row.iterations)

"""
Filter function: accepts all rows (no additional filtering).
"""
const NO_ADDITIONAL_FILTER = row -> true

"""
Aggregation function: computes the mean of values, skipping missing entries.
"""
const AGGREGATE_MEAN = xs -> Statistics.mean(skipmissing(xs))

# ───────────────────────────────────────────────────────────────────────────────
# Performance Criteria
# ───────────────────────────────────────────────────────────────────────────────

"""
Performance criterion based on CPU time from benchmark data.

Extracts the `:time` field from the benchmark object and uses "smaller is better"
comparison (a <= b). Returns NaN if benchmark data is missing or malformed.
"""
const CPU_TIME_CRITERION = CTBenchmarks.ProfileCriterion{Float64}(
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

"""
Performance criterion based on solver iteration count.

Extracts the `:iterations` field and converts to Float64 for profile computation.
Uses "smaller is better" comparison (a <= b). Returns NaN if iterations data is missing.
"""
const ITERATIONS_CRITERION = CTBenchmarks.ProfileCriterion{Float64}(
    "Iterations",
    row -> begin
        if !hasproperty(row, :iterations) || ismissing(row.iterations)
            return NaN
        end
        return Float64(row.iterations)
    end,
    (a, b) -> a <= b
)

# ───────────────────────────────────────────────────────────────────────────────
# Profile Configurations
# ───────────────────────────────────────────────────────────────────────────────

"""
    init_default_profiles!()

Initialize the global `PROFILE_REGISTRY` with standard performance profile
configurations:
- `"default_cpu"`: Based on `CPU_TIME_CRITERION`.
- `"default_iter"`: Based on `ITERATIONS_CRITERION`.
- `"midpoint_trapeze_cpu"`: Based on `CPU_TIME_CRITERION` for discretization method comparison.

Default profiles use `(problem, grid_size)` as instances and `(model, solver)` as combos.
The midpoint_trapeze profile uses `(disc_method, solver)` instead to compare discretization methods.
"""
function init_default_profiles!()
    # 1. Default CPU Profile
    cpu_config = CTBenchmarks.PerformanceProfileConfig{Float64}(
        [:problem, :grid_size],
        [:model, :solver],
        CPU_TIME_CRITERION,
        IS_SUCCESS_WITH_BENCHMARK,
        NO_ADDITIONAL_FILTER,
        AGGREGATE_MEAN
    )
    CTBenchmarks.register!(PROFILE_REGISTRY, "default_cpu", cpu_config)

    # 2. Default Iterations Profile
    iter_config = CTBenchmarks.PerformanceProfileConfig{Float64}(
        [:problem, :grid_size],
        [:model, :solver],
        ITERATIONS_CRITERION,
        IS_SUCCESS_WITH_ITERATIONS,
        NO_ADDITIONAL_FILTER,
        AGGREGATE_MEAN
    )
    CTBenchmarks.register!(PROFILE_REGISTRY, "default_iter", iter_config)

    # 3. Midpoint vs Trapeze CPU Profile
    # Uses disc_method instead of model to compare discretization methods
    midpoint_trapeze_config = CTBenchmarks.PerformanceProfileConfig{Float64}(
        [:problem, :grid_size],
        [:disc_method, :solver],  # Key difference: disc_method instead of model
        CPU_TIME_CRITERION,
        IS_SUCCESS_WITH_BENCHMARK,
        NO_ADDITIONAL_FILTER,
        AGGREGATE_MEAN
    )
    CTBenchmarks.register!(PROFILE_REGISTRY, "midpoint_trapeze_cpu", midpoint_trapeze_config)

    return nothing
end
