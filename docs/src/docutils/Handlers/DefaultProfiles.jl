# ═══════════════════════════════════════════════════════════════════════════════
# Default Profiles (Specific Handlers)
# ═══════════════════════════════════════════════════════════════════════════════
#
# This file defines the default performance profiles used in the documentation.
#
# ═══════════════════════════════════════════════════════════════════════════════

# ───────────────────────────────────────────────────────────────────────────────
# Profile Criteria (Reusable)
# ───────────────────────────────────────────────────────────────────────────────

"""
    CPU_TIME_CRITERION

Criterion based on `row.benchmark["time"]` (CPU time).
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
    ITERATIONS_CRITERION

Criterion based on `row.iterations`.
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

Both use `(problem, grid_size)` as instances and `(model, solver)` as combos.
"""
function init_default_profiles!()
    # 1. Default CPU Profile
    cpu_config = CTBenchmarks.PerformanceProfileConfig{Float64}(
        [:problem, :grid_size],
        [:model, :solver],
        CPU_TIME_CRITERION,
        row -> row.success == true && get(row, :benchmark, nothing) !== nothing,
        row -> true,
        xs -> Statistics.mean(skipmissing(xs))
    )
    CTBenchmarks.register!(PROFILE_REGISTRY, "default_cpu", cpu_config)

    # 2. Default Iterations Profile
    iter_config = CTBenchmarks.PerformanceProfileConfig{Float64}(
        [:problem, :grid_size],
        [:model, :solver],
        ITERATIONS_CRITERION,
        row -> row.success == true && hasproperty(row, :iterations) && !ismissing(row.iterations),
        row -> true,
        xs -> Statistics.mean(skipmissing(xs))
    )
    CTBenchmarks.register!(PROFILE_REGISTRY, "default_iter", iter_config)

    return nothing
end
