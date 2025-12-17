# ═══════════════════════════════════════════════════════════════════════════════
# Plot Performance Profile Module
# ═══════════════════════════════════════════════════════════════════════════════

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
        for k in 0:(M - 1)
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
# Public API (Wrapper)
# ───────────────────────────────────────────────────────────────────────────────

"""
    _plot_profile_default_cpu(bench_id, src_dir; allowed_combos=nothing)

Generate and display the default CPU-time performance profile plot for a
benchmark.

This is a convenience wrapper around `compute_profile_default_cpu` and
`plot_performance_profile`. When `allowed_combos` is provided, only the
specified `(model, solver)` combinations are included in the profile.
"""
function _plot_profile_default_cpu(
    bench_id::AbstractString,
    src_dir::AbstractString;
    allowed_combos::Union{Nothing,Vector{Tuple{String,String}}}=nothing,
)
    pp = compute_profile_default_cpu(bench_id, src_dir; allowed_combos=allowed_combos)
    if pp === nothing
        println("⚠️ No result (missing or invalid file) for bench_id: $bench_id")
        return plot()  # Empty plot on error
    end

    plt = plot_performance_profile(pp)
    DOC_DEBUG[] && @info "  ✅ Default CPU performance profile generated."
    return plt
end

"""
    _plot_profile_default_iter(bench_id, src_dir; allowed_combos=nothing)

Generate and display the default iterations performance profile plot for a
benchmark.

This is a convenience wrapper around `compute_profile_default_iter` and
`plot_performance_profile`. When `allowed_combos` is provided, only the
specified `(model, solver)` combinations are included in the profile.
"""
function _plot_profile_default_iter(
    bench_id::AbstractString,
    src_dir::AbstractString;
    allowed_combos::Union{Nothing,Vector{Tuple{String,String}}}=nothing,
)
    pp = compute_profile_default_iter(bench_id, src_dir; allowed_combos=allowed_combos)
    if pp === nothing
        println("⚠️ No result (missing or invalid file) for bench_id: $bench_id")
        return plot()  # Empty plot on error
    end

    plt = plot_performance_profile(pp)
    DOC_DEBUG[] && @info "  ✅ Default iterations performance profile generated."
    return plt
end

function _plot_profile_midpoint_trapeze_exa(
    bench_id::AbstractString, 
    src_dir::AbstractString; 
    allowed_combos::Union{Nothing,Vector{Tuple{String,String,String}}}=nothing
)
    # 1. On appelle ta fonction de calcul spécifique à 4 courbes
    prof = compute_profile_midpoint_trapeze_exa(bench_id, src_dir; allowed_combos=allowed_combos)
    
    # 2. On vérifie si le profil a pu être construit
    if prof === nothing
        return nothing
    end

    # 3. On appelle la fonction de rendu graphique interne du projet
    return _plot_performance_profile(prof)
end