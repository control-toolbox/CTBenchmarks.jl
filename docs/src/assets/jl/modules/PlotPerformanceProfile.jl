# ═══════════════════════════════════════════════════════════════════════════════
# Plot Performance Profile Module
# ═══════════════════════════════════════════════════════════════════════════════

# ───────────────────────────────────────────────────────────────────────────────
# Data Structure
# ───────────────────────────────────────────────────────────────────────────────

"""
    PerformanceProfile

Immutable structure containing all data needed to plot and analyze a performance profile.

# Fields
- `bench_id::String`: Benchmark identifier
- `df_instances::DataFrame`: All (problem, grid_size) instances attempted
- `df_successful::DataFrame`: Successful runs with timing and ratios
- `combos::Vector{String}`: List of "(model, solver)" combinations
- `total_problems::Int`: Total number of instances (N in Dolan–Moré)
- `min_ratio::Float64`: Minimum performance ratio across all combos
- `max_ratio::Float64`: Maximum performance ratio across all combos
"""
struct PerformanceProfile
    bench_id::String
    df_instances::DataFrame
    df_successful::DataFrame
    combos::Vector{String}
    total_problems::Int
    min_ratio::Float64
    max_ratio::Float64
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

# Arguments
- `bench_id`: Benchmark identifier
- `src_dir`: Path to docs/src directory

# Returns
- `PerformanceProfile` if data is available and valid
- `nothing` if no data or no successful runs

# Details
This function:
1. Loads benchmark data from JSON
2. Identifies all (problem, grid_size) instances
3. Filters successful runs with valid timing
4. Computes performance ratios r_{p,s} = t_{p,s} / t_p^*
5. Aggregates all data into a PerformanceProfile struct

Follows the classical Dolan–Moré performance profile definition:
- Each *instance* is a pair `(problem, grid_size)`
- Each *solver-model combination* is identified by `(model, solver)`
- Performance ratio: r_{p,s} = t_{p,s} / min_s t_{p,s}
- Profile function: ρ_s(τ) = (1/N) * #{instances p : r_{p,s} ≤ τ}
"""
function compute_performance_profile(bench_id::AbstractString, src_dir::AbstractString)
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

    # All problem × grid_size instances that were attempted (for any solver/model)
    df_instances = unique(select(df, [:problem, :grid_size]))
    if isempty(df_instances)
        @warn "No problem-grid instances found in benchmark results."
        return nothing
    end

    # Keep only successful runs with a recorded benchmark for ratio computation
    df_successful = filter(row -> row.success == true && row.benchmark !== nothing, df)
    if isempty(df_successful)
        @warn "No successful benchmark entry to analyze."
        return nothing
    end

    # Extract timing and compute ratios
    df_successful.time = [row.benchmark["time"] for row in eachrow(df_successful)]
    select!(df_successful, [:problem, :model, :solver, :grid_size, :time])
    df_successful = dropmissing(df_successful, :time)
    sort!(df_successful, [:problem, :grid_size, :model, :solver])

    df_min = combine(groupby(df_successful, [:problem, :grid_size]), :time => minimum => :min_time)
    df_successful = leftjoin(df_successful, df_min, on = [:problem, :grid_size])
    df_successful.ratio = df_successful.time ./ df_successful.min_time

    df_successful.combo = string.("(", df_successful.model, ", ", df_successful.solver, ")")
    combos = unique(df_successful.combo)

    # Compute ratio bounds
    min_ratio = Inf
    max_ratio = 1.0
    for c in combos
        sub = filter(row -> row.combo == c, df_successful)
        ratios = collect(skipmissing(sub.ratio))
        if !isempty(ratios)
            max_ratio = max(max_ratio, maximum(ratios))
            min_ratio = min(min_ratio, minimum(ratios))
        end
    end

    total_problems = nrow(df_instances)

    return PerformanceProfile(
        bench_id,
        df_instances,
        df_successful,
        combos,
        total_problems,
        min_ratio,
        max_ratio
    )
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
    _plot_performance_profiles(bench_id)

Generate and display performance profile plots for benchmark results.

# Arguments
- `bench_id`: Benchmark identifier string

# Returns
- `Plots.Plot`: Performance profile plot, or empty plot if no data available

# Details
Creates a performance profile plot showing the proportion of solved instances
for each solver-model combination relative to the best solver for each problem.

The plot uses:
- Log scale (base 2) on the x-axis for performance ratio (τ)
- Proportion of solved instances on the y-axis
- One curve per (model, solver) combination

Only successful benchmarks with valid timing data are included.
Returns an empty plot if no benchmark data or successful runs are found.

## Definition of the performance profile

We follow the classical performance profile definition à la Dolan–Moré, adapted to
this benchmark structure:

- Each *instance* is a pair `(problem, grid_size)` appearing in the benchmark
  results, regardless of whether it was successfully solved by any solver.
- Each *solver-model combination* `s` is identified by `(model, solver)`.

For each instance `p = (problem, grid_size)` and solver-model `s`:

1. If the run `(p, s)` has `success == true` and a valid benchmark object,
   we extract the CPU wall time

   - `t_{p,s} = row.benchmark["time"]`.

2. Among all solver-models `s` that succeeded on the same instance `p`, we
   compute the best (minimal) time

   - `t_p^* = min_s t_{p,s}`.

3. For every successful run `(p, s)` we define the performance ratio

   - `r_{p,s} = t_{p,s} / t_p^* ≥ 1`.

   Instances where `s` failed (or has no valid timing) are treated conceptually
   as having `r_{p,s} = +∞`: they never contribute to the counts of
   `r_{p,s} ≤ τ` for any finite `τ`.

We then define the performance profile of each solver-model combination `s` as a
piecewise-constant, non-decreasing function

```text
ρ_s(τ) = (1 / N) * # { instances p : r_{p,s} ≤ τ },
```

where `N` is the **total** number of distinct `(problem, grid_size)` instances
present in the JSON file (including those where all solvers failed).

- The x-axis samples `τ` over the sorted finite ratios `r_{p,s}` for each `s`.
- The y-axis value at each `τ` is the fraction of all instances on which
  solver-model `s` has a performance ratio at most `τ`.

## Treatment of failures and unsolved problems

- Only instances with `success == true` and a valid timing contribute ratios
  `r_{p,s}` and hence can increase `ρ_s(τ)`.
- Instances where a given solver-model fails are counted in `N` but never in the
  numerator `# { r_{p,s} ≤ τ }` for that solver-model.
- Instances where **all** solver-models fail are still included in `N` but do
  not contribute any `r_{p,s}` for any solver-model.

As a consequence, if there exist problem-grid instances that are not solved by a
given solver-model combination, its curve `ρ_s(τ)` will plateau strictly below
`1` (100%). If some instances are unsolved by *all* solver-models, then **no**
curve can reach `1`, clearly indicating that there are problems for which none
of the tested approaches succeeded.
"""
function _plot_performance_profiles(bench_id::AbstractString, src_dir::AbstractString)
    pp = compute_performance_profile(bench_id, src_dir)
    if pp === nothing
        println("⚠️ No result (missing or invalid file) for bench_id: $bench_id")
        return plot()  # Empty plot on error
    end
    
    plt = plot_performance_profile(pp)
    @info "  ✅ Global performance profile generated."
    return plt
end