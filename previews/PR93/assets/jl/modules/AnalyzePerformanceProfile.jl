# ═══════════════════════════════════════════════════════════════════════════════
# Analyze Performance Profile Module
# ═══════════════════════════════════════════════════════════════════════════════

"""
    analyze_performance_profile(pp::PerformanceProfile) -> String

Generate a detailed textual analysis of a performance profile.

# Arguments
- `pp::PerformanceProfile`: Pre-computed performance profile data

# Returns
- Markdown string with analysis insights including:
  - Dataset overview (problems, instances, solver-model combinations)
  - Robustness metrics (% of instances solved per combination)
  - Efficiency metrics (% of instances where each combination was fastest)

# Details
This function extracts key metrics from the performance profile:
- **Robustness**: Proportion of instances successfully solved by each solver-model
- **Efficiency**: Proportion of instances where each solver-model achieved the best time (ratio = 1.0)
"""
function analyze_performance_profile(pp::PerformanceProfile)
    buf = IOBuffer()
    
    print(buf, "!!! info \"Performance Profile Analysis\"\n")
    print(buf, "    **Dataset overview for `$(pp.bench_id)`:**\n")
    print(buf, "    - **Problems**: ", length(unique(pp.df_instances.problem)), " unique optimal control problems\n")
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
    # Total runs = total_problems × number of combos (each combo attempts each instance)
    total_runs = pp.total_problems * length(pp.combos)
    n_successful_runs = nrow(pp.df_successful)
    success_percentage = round(100 * n_successful_runs / total_runs, digits=1)
    print(buf, "    - **Successful runs**: ", n_successful_runs, "/", total_runs, " (", success_percentage, "%)\n")

    # Compute successful instances: instances with at least one successful combo
    solved_instances = unique(select(pp.df_successful, [:problem, :grid_size]))
    n_successful_instances = nrow(solved_instances)
    success_instances_percentage = round(100 * n_successful_instances / pp.total_problems, digits=1)
    print(buf, "    - **Successful instances**: ", n_successful_instances, "/", pp.total_problems, " (", success_instances_percentage, "%)\n")
    
    # Identify instances with no successful run for any solver-model combination
    solved_set = Set((row.problem, row.grid_size) for row in eachrow(solved_instances))
    unsuccessful_instances = [(row.problem, row.grid_size) for row in eachrow(pp.df_instances)
                              if !((row.problem, row.grid_size) in solved_set)]

    if isempty(unsuccessful_instances)
        print(buf, "    - **Unsuccessful instances**: none (every instance had at least one successful run)\n")
    else
        print(buf, "    - **Unsuccessful instances** (no solver converged):\n")
        # Sort by problem, then grid_size for a stable display
        sort!(unsuccessful_instances, by = x -> (x[1], x[2]))
        for (p, N) in unsuccessful_instances
            print(buf, "      - `", p, "` (N = ", N, ")\n")
        end
    end
    print(buf, "\n")
    
    # Compute robustness: % of instances solved by each combo
    print(buf, "    **Robustness (% of instances solved):**\n")
    robustness_data = []
    for c in pp.combos
        sub = filter(row -> row.combo == c, pp.df_successful)
        n_solved = nrow(unique(select(sub, [:problem, :grid_size])))
        success_rate = round(100 * n_solved / pp.total_problems, digits=1)
        push!(robustness_data, (combo=c, rate=success_rate))
        print(buf, "    - `$c`: $success_rate%\n")
    end
    
    # Compute efficiency: % of instances where fastest (ratio = 1.0)
    print(buf, "    **Efficiency (% of instances where fastest):**\n")
    efficiency_data = []
    for c in pp.combos
        sub = filter(row -> row.combo == c, pp.df_successful)
        n_best = count(row -> row.ratio == 1.0, eachrow(sub))
        best_rate = round(100 * n_best / pp.total_problems, digits=1)
        push!(efficiency_data, (combo=c, rate=best_rate))
        print(buf, "    - `$c`: $best_rate%\n")
    end
    
    # Find best overall performer (highest robustness)
    if !isempty(robustness_data)
        best_robust = maximum(r -> r.rate, robustness_data)
        best_robust_combos = [r.combo for r in robustness_data if r.rate == best_robust]
        if length(best_robust_combos) == 1
            print(buf, "    **Most robust**: `$(best_robust_combos[1])` solved $best_robust% of instances.\n")
        else
            print(buf, "    **Most robust**: $(length(best_robust_combos)) combinations tied at $best_robust%.\n")
        end
    end
    print(buf, "\n")
    
    # Find most efficient performer (highest efficiency)
    if !isempty(efficiency_data)
        best_efficient = maximum(e -> e.rate, efficiency_data)
        best_efficient_combos = [e.combo for e in efficiency_data if e.rate == best_efficient]
        if length(best_efficient_combos) == 1
            print(buf, "    **Most efficient**: `$(best_efficient_combos[1])` was fastest on $best_efficient% of instances.\n")
        else
            print(buf, "    **Most efficient**: $(length(best_efficient_combos)) combinations tied at $best_efficient%.\n")
        end
    end
    print(buf, "\n")
    
    print(buf, "    *For detailed interpretation, see the [Performance Profiles](@ref performance-profiles) page.*\n")
    
    return String(take!(buf))
end

"""
    _analyze_profile_default_cpu(bench_id::AbstractString, src_dir::AbstractString) -> String

Compute a detailed textual analysis of a benchmark's default CPU-time
performance profile.

This is a convenience wrapper that:
1. Computes the performance profile data using `compute_profile_default_cpu`
2. Generates the analysis using `analyze_performance_profile`

# Arguments
- `bench_id`: Benchmark identifier
- `src_dir`: Path to docs/src directory

# Returns
- Markdown string with analysis, or a warning if no data is available
"""
function _analyze_profile_default_cpu(bench_id::AbstractString, src_dir::AbstractString)
    pp = compute_profile_default_cpu(bench_id, src_dir)
    if pp === nothing
        return "!!! warning\n    No benchmark data available for analysis for `$bench_id`.\n"
    end
    return analyze_performance_profile(pp)
end

"""
    _analyze_profile_default_iter(bench_id::AbstractString, src_dir::AbstractString) -> String

Compute a detailed textual analysis of a benchmark's default iterations
performance profile.

This is a convenience wrapper that:
1. Computes the performance profile data using `compute_profile_default_iter`
2. Generates the analysis using `analyze_performance_profile`

# Arguments
- `bench_id`: Benchmark identifier
- `src_dir`: Path to docs/src directory

# Returns
- Markdown string with analysis, or a warning if no data is available
"""
function _analyze_profile_default_iter(bench_id::AbstractString, src_dir::AbstractString)
    pp = compute_profile_default_iter(bench_id, src_dir)
    if pp === nothing
        return "!!! warning\n    No benchmark data available for analysis for `$bench_id`.\n"
    end
    return analyze_performance_profile(pp)
end
