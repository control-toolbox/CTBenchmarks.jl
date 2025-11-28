"""
    $(TYPEDSIGNATURES)

Return a consistent color for a given (model, solver) pair.

This function ensures visual consistency across plots by assigning fixed colors to known
(model, solver) combinations. For unknown combinations, it cycles through a default palette
based on the provided index.

# Fixed Mappings
- `(adnlp, ipopt)` → `:blue`
- `(exa, ipopt)` → `:red`
- `(adnlp, madnlp)` → `:green`
- `(exa, madnlp)` → `:orange`
- `(jump, ipopt)` → `:purple`
- `(jump, madnlp)` → `:brown`
- `(exa_gpu, madnlp)` → `:cyan`

# Arguments
- `model::Union{Symbol,String}`: Model name (case-insensitive)
- `solver::Union{Symbol,String}`: Solver name (case-insensitive)
- `idx::Int`: Index for palette fallback (used if pair not in fixed mappings)

# Returns
- `Symbol`: Color symbol suitable for Plots.jl (e.g., `:blue`, `:red`)

# Example
```julia-repl
julia> using CTBenchmarks

julia> CTBenchmarks.get_color(:adnlp, :ipopt, 1)
:blue

julia> CTBenchmarks.get_color(:unknown, :solver, 2)
:red
```
"""
function get_color(model::T, solver::T, disc_method::T, idx::Int) where {T<:Union{String,Symbol}}
    model = lowercase(string(model))
    solver = lowercase(string(solver))
    disc = lowercase(string(disc_method))
    
    # Palette de secours
    palette = [:blue,:red,:green,:orange,:purple,:brown,:pink,:gray,:cyan,:magenta,:teal,:olive,:gold,:navy,:darkred]

    fixed = Dict(
        ("adnlp",   "ipopt",  "trapeze") => :blue,
        ("adnlp",   "madnlp", "trapeze") => :green,
        ("jump",    "ipopt",  "trapeze") => :purple,
        ("jump",    "madnlp", "trapeze") => :brown,
        ("exa_gpu", "madnlp", "trapeze") => :cyan,
        ("exa", "ipopt",  "trapeze") => :red,
        ("exa", "madnlp", "trapeze") => :orange,
        ("exa", "ipopt",  "midpoint") => :royalblue, 
        ("exa", "madnlp", "midpoint") => :teal,
    )
    return get(fixed, (model, solver, disc), palette[mod1(idx, length(palette))])
end

# -----------------------------------
# Helper: left margin for plots
# -----------------------------------
"""
    $(TYPEDSIGNATURES)

Get the left margin for plots based on the problem.

Different problems may require different margins to accommodate axis labels and titles.
The beam problem uses a smaller margin (5mm) while other problems use 20mm.

# Arguments
- `problem::Symbol`: Problem name (e.g., `:beam`, `:shuttle`)

# Returns
- `Plots.Measure`: Left margin in millimeters (5mm or 20mm)

# Example
```julia-repl
julia> using CTBenchmarks

julia> CTBenchmarks.get_left_margin(:beam)
5 mm

julia> CTBenchmarks.get_left_margin(:shuttle)
20 mm
```
"""
function get_left_margin(problem::Symbol)
    margins = Dict(:beam => 5mm)
    return get(margins, problem, 20mm)
end

# -----------------------------------
# Helper: costate sign based on criterion
# -----------------------------------
"""
    $(TYPEDSIGNATURES)

Determine the sign used to plot costates based on the optimization criterion.

For maximisation problems, costates are plotted with a positive sign. For
minimisation problems (the default), costates are plotted with a negative sign
so that their visual behaviour matches the usual optimal control conventions.

# Arguments
- `criterion`: Optimization criterion (`:min`, `:max`, or `missing`).

# Returns
- `Int`: `+1` if the problem is a maximisation, `-1` otherwise.

# Example
```julia-repl
julia> using CTBenchmarks

julia> CTBenchmarks.costate_multiplier(:min)
-1

julia> CTBenchmarks.costate_multiplier(:max)
1
```
"""
function costate_multiplier(criterion)
    lowercase(string(ismissing(criterion) ? "min" : criterion)) == "max" ? 1 : -1
end

# -----------------------------------
# Helper: marker style for better visibility
# -----------------------------------
"""
    $(TYPEDSIGNATURES)

Get marker shape and spacing for a given (model, solver) pair.

This function provides consistent marker styles for known (model, solver) combinations
and automatically calculates appropriate marker spacing based on grid size to avoid
visual clutter while maintaining visibility.

# Fixed Mappings
- `(adnlp, ipopt)` → `:circle`
- `(exa, ipopt)` → `:square`
- `(adnlp, madnlp)` → `:diamond`
- `(exa, madnlp)` → `:utriangle`
- `(jump, ipopt)` → `:dtriangle`
- `(jump, madnlp)` → `:star5`
- `(exa_gpu, madnlp)` → `:hexagon`

# Arguments
- `model::Union{Symbol,String}`: Model name (case-insensitive)
- `solver::Union{Symbol,String}`: Solver name (case-insensitive)
- `idx::Int`: Index for marker fallback (used if pair not in fixed mappings)
- `grid_size::Int`: Number of grid points on the curve

# Returns
- `Tuple{Symbol, Int}`: `(marker_shape, marker_interval)` where:
  - `marker_shape`: Symbol for marker type (e.g., `:circle`, `:square`)
  - `marker_interval`: Spacing between markers (calculated as `max(1, grid_size ÷ 6)`)

# Example
```julia-repl
julia> using CTBenchmarks

julia> CTBenchmarks.get_marker_style(:adnlp, :ipopt, 1, 200)
(:circle, 33)

julia> CTBenchmarks.get_marker_style(:unknown, :solver, 2, 100)
(:square, 16)
```
"""
function get_marker_style(model::T, solver::T, disc_method::T, idx::Int) where {T<:Union{String,Symbol}}
    solver = lowercase(string(solver))
    if solver == "ipopt"
        return :square
    elseif solver == "madnlp"
        return :circle
    else
        markers = [:dtriangle, :utriangle, :diamond, :hexagon, :cross]
        return markers[mod1(idx, length(markers))]
    end
end

function get_marker_style(model::T, solver::T, disc_method::T, idx::Int, grid_size::Int) where {T<:Union{String,Symbol}}
    marker = get_marker_style(model, solver, disc_method, idx)
    M = 6
    marker_interval = max(1, div(grid_size, M))
    return (marker, marker_interval)
end

"""
    $(TYPEDSIGNATURES)

Calculate marker indices with offset to avoid superposition between curves.

When multiple curves are overlaid on the same plot, markers can overlap and obscure the visualization.
This function staggers the marker positions across curves by applying an offset based on the curve index.

# Arguments
- `idx::Int`: Curve index (1-based)
- `card_g::Int`: Total number of curves
- `grid_size::Int`: Number of grid points on the curve
- `marker_interval::Int`: Base spacing between markers

# Returns
- `UnitRange{Int}`: Range of indices for marker placement

# Details
For curve `idx` out of `card_g` curves, the first marker is offset by:
```
offset = (idx - 1) * marker_interval / card_g
```

# Example
```julia-repl
julia> using CTBenchmarks

julia> CTBenchmarks.get_marker_indices(1, 3, 100, 20)
1:20:101

julia> CTBenchmarks.get_marker_indices(2, 3, 100, 20)
8:20:101
```
"""
function get_marker_indices(idx::Int, card_g::Int, grid_size::Int, marker_interval::Int)
    # Calculate offset for this curve
    offset = div((idx - 1) * marker_interval, card_g)
    # Start from 1 + offset and step by marker_interval
    start_idx = 1 + offset
    return start_idx:marker_interval:(grid_size + 1)
end

"""
    $(TYPEDSIGNATURES)

Generate PDF plots comparing solutions for each (problem, grid_size) pair.

This is the main entry point for visualizing benchmark results. It creates comprehensive
comparison plots where all solver-model combinations for a given problem and grid size
are overlaid on the same figure, enabling easy visual comparison of solution quality
and convergence behavior.

# Arguments
- `payload::Dict`: Benchmark results dictionary containing:
  - `"results"`: Vector of result dictionaries with fields: `problem`, `grid_size`, `model`, `solver`, etc.
  - `"solutions"`: Vector of solution objects (OptimalControl.Solution or JuMP.Model)
- `output_dir::AbstractString`: Directory where PDF files will be saved (created if not exists)

# Output
Generates one PDF file per (problem, grid_size) combination with filename format:
`<problem>_N<grid_size>.pdf`

Each plot displays:
- State and costate trajectories (2 columns)
- Control trajectories (full width below)
- All solver-model combinations overlaid with consistent colors and markers
- Success/failure indicators (✓/✗) in legend

# Details
- OptimalControl solutions are plotted first (simple overlay)
- JuMP solutions are plotted last (for proper subplot layout)
- Uses consistent color and marker schemes via `get_color` and `get_marker_style`
- Handles missing or failed solutions gracefully

# Example
```julia-repl
julia> using CTBenchmarks

julia> payload = Dict(
           "results" => [...],  # benchmark results
           "solutions" => [...]  # solution objects
       )

julia> CTBenchmarks.plot_solutions(payload, "plots/")
📊 Generating solution plots...
  - Plotting beam with N=100 (4 solutions)
    ✓ Saved: beam_N100.pdf
✅ All solution plots generated in plots/
```
"""
function plot_solutions(payload::Dict, output_dir::AbstractString)
    # Ensure the target directory exists
    mkpath(output_dir)

    # Retrieve the data
    results_vec = payload["results"]
    solutions = payload["solutions"]

    # Rebuild a DataFrame with the solutions
    df = DataFrame(results_vec)
    df.solution = solutions

    # Keep rows with available solutions (successful or not)
    df_with_solution = filter(row -> !ismissing(row.solution), df)

    if isempty(df_with_solution)
        println("⚠️  No solutions available to plot")
        return nothing
    end

    # Group by (problem, grid_size)
    grouped = groupby(df_with_solution, [:problem, :grid_size])

    println("📊 Generating solution plots...")
    for group in grouped
        problem = first(group.problem)
        grid_size = first(group.grid_size)

        println("  - Plotting $problem with N=$grid_size ($(nrow(group)) solutions)")

        try
            # Create the plot
            plt = plot_solution_comparison(group, problem, grid_size)

            # Save as PDF
            pdf_filename = "$(problem)_N$(grid_size).pdf"
            pdf_filepath = joinpath(output_dir, pdf_filename)
            savefig(plt, pdf_filepath)

            # Save as SVG
            svg_filename = "$(problem)_N$(grid_size).svg"
            svg_filepath = joinpath(output_dir, svg_filename)
            savefig(plt, svg_filepath)

            println("    ✓ Saved: $pdf_filename and $svg_filename")
        catch e
            println("    ✗ Error plotting $problem N=$grid_size: $e")
            Base.show_backtrace(stdout, catch_backtrace())
        end
    end

    println("✅ All solution plots generated in $output_dir")
end

"""
    $(TYPEDSIGNATURES)

Create a comprehensive comparison plot for all solutions in a group.

This function orchestrates the plotting of all OptimalControl and JuMP solutions for a given
problem and grid size, arranging them in a multi-panel layout with consistent styling.

# Arguments
- `group::SubDataFrame`: DataFrame subset with rows for the same (problem, grid_size)
- `problem::Symbol`: Problem name (used for plot styling, e.g., left margin)
- `grid_size::Int`: Grid size (used for marker spacing calculations)

# Returns
- `Plots.Plot`: Multi-panel plot with states, costates, and controls

# Layout
- **Top panels**: State trajectories (n columns)
- **Middle panels**: Costate trajectories (n columns)
- **Bottom panels**: Control trajectories (m columns, full width)

# Strategy
1. OptimalControl solutions plotted first (simple overlay with `plot!`)
2. JuMP solutions plotted last (for proper subplot layout)
3. All solutions use consistent colors and markers via `get_color` and `get_marker_style`
4. Success/failure indicators (✓/✗) shown in legend
"""
function plot_solution_comparison(group::SubDataFrame, problem::Symbol, grid_size::Int)
    plt = nothing
    color_idx = 1

    # Determine dimensions n and m
    n, m = get_dimensions(group)

    # Calculate total number of curves for marker offset
    card_g_total = nrow(group)

    # Separate solutions by concrete type and plot them
    # We iterate through the group and handle each type separately

    # 1. Plot OptimalControl solutions first
    ocp_indices = findall(
        row -> !ismissing(row.solution) && row.solution isa OptimalControl.Solution,
        eachrow(group),
    )
    if !isempty(ocp_indices)
        ocp_rows = view(group, ocp_indices, :)
        # Pass card_g_total and starting idx (color_idx)
        plt, color_idx = plot_ocp_group(
            ocp_rows, plt, color_idx, problem, grid_size, n, m, card_g_total
        )
    end

    # 2. Plot JuMP solutions last
    jump_indices = findall(
        row -> !ismissing(row.solution) && row.solution isa JuMP.Model, eachrow(group)
    )
    if !isempty(jump_indices)
        jump_rows = view(group, jump_indices, :)
        # Pass card_g_total and current color_idx
        plt, color_idx = plot_jump_group(
            jump_rows, plt, color_idx, problem, grid_size, n, m, card_g_total
        )
    end

    return plt
end

"""
    $(TYPEDSIGNATURES)

Plot all OptimalControl solutions in a group with consistent styling.

This function creates the base plot if `plt` is nothing, then adds all OptimalControl solutions
from the group with consistent colors and markers. It manages color indexing across multiple
groups to ensure visual consistency.

# Arguments
- `ocp_rows::SubDataFrame`: Rows containing OptimalControl solutions
- `plt`: Existing plot (or `nothing` to create new)
- `color_idx::Int`: Current color index for consistent styling
- `problem::Symbol`: Problem name
- `grid_size::Int`: Grid size
- `n::Int`: Number of states
- `m::Int`: Number of controls
- `card_g_override::Union{Int,Nothing}`: Override for total number of curves (for marker offset)

# Returns
- `Tuple{Plots.Plot, Int}`: Updated plot and next color index
"""
function plot_ocp_group(
    ocp_rows::SubDataFrame,
    plt,
    color_idx::Int,
    problem::Symbol,
    grid_size::Int,
    n::Int,
    m::Int,
    card_g_override::Union{Int,Nothing}=nothing,
)
    card_g = isnothing(card_g_override) ? nrow(ocp_rows) : card_g_override

    get_disc(row) = hasproperty(row, :disc_method) ? row.disc_method : "trapeze"

    first_row = ocp_rows[1, :]
    disc = get_disc(first_row) 

    marker, marker_interval = get_marker_style(
        first_row.model, first_row.solver, disc, color_idx, grid_size 
    )
    base_color = get_color(first_row.model, first_row.solver, disc, color_idx) 
    
    
    plt = plot_ocp_solution(
        first_row.solution,
        first_row.model,
        first_row.solver,
        disc,
        first_row.success,
        base_color,
        problem,
        grid_size,
        n,
        m,
        marker,
        marker_interval,
        color_idx,
        card_g,
    )
    color_idx += 1

    # Add the remaining OCP solutions
    for row in eachrow(ocp_rows)[2:end]
        disc = get_disc(row) 

        marker, marker_interval = get_marker_style(
            row.model, row.solver, disc, color_idx, grid_size 
        )
        color = get_color(row.model, row.solver, disc, color_idx) 
        
        plt = plot_ocp_solution!(
            plt,
            row.solution,
            row.model,
            row.solver,
            disc, 
            row.success,
            color,
            n,
            m,
            marker,
            marker_interval,
            color_idx, 
            card_g,
        )
        color_idx += 1
    end

    return plt, color_idx
end

"""
    $(TYPEDSIGNATURES)

Create a new multi-panel plot for a single OptimalControl solution.

Generates a comprehensive visualization with state, costate, and control trajectories,
with spaced markers for improved visibility and a legend entry indicating success status.

# Arguments
- `solution`: OptimalControl.Solution object
- `model::Symbol`: Model name (for legend)
- `solver::Symbol`: Solver name (for legend)
- `success::Bool`: Whether the solution converged successfully
- `color`: Color symbol (from `get_color`)
- `problem::Symbol`: Problem name (for plot styling)
- `grid_size::Int`: Grid size
- `n::Int`: Number of states
- `m::Int`: Number of controls
- `marker`: Marker shape symbol (from `get_marker_style`)
- `marker_interval::Int`: Spacing between markers
- `idx::Int`: Curve index for marker offset (default: 1)
- `card_g::Int`: Total number of curves for marker offset (default: 1)

# Returns
- `Plots.Plot`: Multi-panel plot with (n + n + m) subplots
"""
function plot_ocp_solution(solution, model::Symbol, solver::Symbol, disc_method, success::Bool, color,
                           problem::Symbol, grid_size::Int, n::Int, m::Int, marker, marker_interval,
                           idx::Int=1, card_g::Int=1)
    # Create the plot without markers (just lines)
    plt = plot(
        solution,
        :state, :costate, :control;
        color=color,
        label=:none,
        size=(816, 240*(n+m)),
        leftmargin=get_left_margin(problem),
        linewidth=1.5,
        dpi=300,
    )
    
    # Get time grid and marker positions with offset
    t = OptimalControl.time_grid(solution)
    marker_indices = get_marker_indices(idx, card_g, grid_size, marker_interval)
    t_markers = t[marker_indices]
    
    # Get state, costate, control values
    x_vals = OptimalControl.state(solution)
    p_vals = OptimalControl.costate(solution)
    u_vals = OptimalControl.control(solution)
    
    label_str = format_solution_label(model, solver, disc_method, success)

    # Add an invisible point with line+marker for the legend (only on first state plot)
    plot!(plt[1], [t[1]], [x_vals(t[1])[1]];
          color=color, linewidth=1.5, markershape=marker, markersize=3,
          label=label_str, markerstrokewidth=0)
    
    # Add spaced markers to states (plt[1:n])
    for i in 1:n
        scatter!(plt[i], t_markers, [x_vals(t_val)[i] for t_val in t_markers];
                 color=color, markershape=marker, markersize=3, label=:none, markerstrokewidth=0)
    end
    
    # Add spaced markers to costates (plt[n+1:2n])
    for i in 1:n
        scatter!(plt[n+i], t_markers, [p_vals(t_val)[i] for t_val in t_markers];
                 color=color, markershape=marker, markersize=3, label=:none, markerstrokewidth=0)
    end
    
    # Add spaced markers to controls (plt[2n+1:2n+m])
    for i in 1:m
        scatter!(plt[2n+i], t_markers, [u_vals(t_val)[i] for t_val in t_markers];
                 color=color, markershape=marker, markersize=3, label=:none, markerstrokewidth=0)
    end
    
    for i in 2:(2n+m)
        plot!(plt[i]; legend=:none)
    end
    return plt
end

"""
    $(TYPEDSIGNATURES)

Add an OptimalControl solution to an existing multi-panel plot.

Appends state, costate, and control trajectories to existing subplots with spaced markers
and consistent styling. Updates the legend with success status.

# Arguments
- `plt`: Existing Plots.Plot to modify
- `solution`: OptimalControl.Solution object
- `model::Symbol`: Model name (for legend)
- `solver::Symbol`: Solver name (for legend)
- `success::Bool`: Whether the solution converged successfully
- `color`: Color symbol (from `get_color`)
- `n::Int`: Number of states
- `m::Int`: Number of controls
- `marker`: Marker shape symbol (from `get_marker_style`)
- `marker_interval::Int`: Spacing between markers
- `idx::Int`: Curve index for marker offset (default: 1)
- `card_g::Int`: Total number of curves for marker offset (default: 1)

# Returns
- `Plots.Plot`: Modified plot with new solution added
"""
function plot_ocp_solution!(plt, solution, model::Symbol, solver::Symbol, disc_method, success::Bool, color, n::Int, m::Int, marker, marker_interval,
                            idx::Int=1, card_g::Int=1)
    # Add line without markers
    plot!(
        plt,
        solution,
        :state, :costate, :control;
        color=color,
        label=:none,
        linewidth=1.5,
    )
    
    # Get time grid and marker positions with offset
    t = OptimalControl.time_grid(solution)
    grid_size = length(t) - 1
    marker_indices = get_marker_indices(idx, card_g, grid_size, marker_interval)
    t_markers = t[marker_indices]
    
    # Get state, costate, control values
    x_vals = OptimalControl.state(solution)
    p_vals = OptimalControl.costate(solution)
    u_vals = OptimalControl.control(solution)
    
    label_str = format_solution_label(model, solver, disc_method, success)

    # Add an invisible point with line+marker for the legend (only on first state plot)
    plot!(plt[1], [t[1]], [x_vals(t[1])[1]];
          color=color, linewidth=1.5, markershape=marker, markersize=3,
          label=label_str, markerstrokewidth=0)
    
    # Add spaced markers to states (plt[1:n])
    for i in 1:n
        scatter!(plt[i], t_markers, [x_vals(t_val)[i] for t_val in t_markers];
                 color=color, markershape=marker, markersize=3, label=:none, markerstrokewidth=0)
    end
    
    # Add spaced markers to costates (plt[n+1:2n])
    for i in 1:n
        scatter!(plt[n+i], t_markers, [p_vals(t_val)[i] for t_val in t_markers];
                 color=color, markershape=marker, markersize=3, label=:none, markerstrokewidth=0)
    end
    
    # Add spaced markers to controls (plt[2n+1:2n+m])
    for i in 1:m
        scatter!(plt[2n+i], t_markers, [u_vals(t_val)[i] for t_val in t_markers];
                 color=color, markershape=marker, markersize=3, label=:none, markerstrokewidth=0)
    end
    
    for i in 2:(2n+m)
        plot!(plt[i]; legend=:none)
    end
    return plt
end

"""
    $(TYPEDSIGNATURES)

Plot all JuMP solutions in a group with consistent styling.

This function creates the plot layout if `plt` is nothing, then adds all JuMP solutions
from the group. JuMP solutions require special layout handling compared to OptimalControl solutions.

# Arguments
- `jump_rows::SubDataFrame`: Rows containing JuMP solutions
- `plt`: Existing plot (or `nothing` to create new)
- `color_idx::Int`: Current color index for consistent styling
- `problem::Symbol`: Problem name
- `grid_size::Int`: Grid size
- `n::Int`: Number of states
- `m::Int`: Number of controls
- `card_g_override::Union{Int,Nothing}`: Override for total number of curves (for marker offset)

# Returns
- `Tuple{Plots.Plot, Int}`: Updated plot and next color index
"""
function plot_jump_group(
    jump_rows::SubDataFrame,
    plt,
    color_idx::Int,
    problem::Symbol,
    grid_size::Int,
    n::Int,
    m::Int,
    card_g_override::Union{Int,Nothing}=nothing,
)
    # Use override if provided, otherwise calculate from local group
    card_g = isnothing(card_g_override) ? nrow(jump_rows) : card_g_override

    for row in eachrow(jump_rows)
        current_color = get_color(row.model, row.solver, color_idx)
        marker, marker_interval = get_marker_style(
            row.model, row.solver, color_idx, grid_size
        )

        if plt === nothing
            # Create layout without plotting first
            state_labels = try
                [string(c) for c in OptimalControlProblems.state_components(row.solution)]
            catch
                String[]
            end
            control_labels = try
                [string(c) for c in OptimalControlProblems.control_components(row.solution)]
            catch
                String[]
            end
            plt = create_jump_layout(n, m, problem, grid_size, state_labels, control_labels)
        end

        # Always use plot_jump_solution! to add the solution with markers
        plt = plot_jump_solution!(
            plt,
            row.solution,
            row.model,
            row.solver,
            row.success,
            current_color,
            n,
            m,
            row.criterion,
            marker,
            marker_interval,
            color_idx,  # Use color_idx as global idx
            card_g,
        )

        color_idx += 1
    end

    return plt, color_idx
end

"""
    $(TYPEDSIGNATURES)

Create a new multi-panel plot for a single JuMP solution.

Generates a comprehensive visualization with state, costate, and control trajectories
from a JuMP model, with spaced markers and legend entry indicating success status.

# Arguments
- `solution`: JuMP.Model object
- `model::Symbol`: Model name (for legend)
- `solver::Symbol`: Solver name (for legend)
- `success::Bool`: Whether the solution converged successfully
- `color`: Color symbol (from `get_color`)
- `problem::Symbol`: Problem name (for plot styling)
- `grid_size::Int`: Grid size
- `n::Int`: Number of states
- `m::Int`: Number of controls
- `criterion`: Optimization criterion (`:min` or `:max`, affects costate sign)
- `marker`: Marker shape symbol (default: `:circle`)
- `marker_interval::Int`: Spacing between markers (default: 10)
- `idx::Int`: Curve index for marker offset (default: 1)
- `card_g::Int`: Total number of curves for marker offset (default: 1)

# Returns
- `Plots.Plot`: Multi-panel plot with (n + n + m) subplots
"""
function plot_jump_solution(
    solution,
    model::Symbol,
    solver::Symbol,
    success::Bool,
    color,
    problem::Symbol,
    grid_size::Int,
    n::Int,
    m::Int,
    criterion,
    marker=:circle,
    marker_interval=10,
    idx::Int=1,
    card_g::Int=1,
)
    state_labels = try
        [string(c) for c in OptimalControlProblems.state_components(solution)]
    catch
        String[]
    end

    control_labels = try
        [string(c) for c in OptimalControlProblems.control_components(solution)]
    catch
        String[]
    end

    plt = create_jump_layout(n, m, problem, grid_size, state_labels, control_labels)
    return plot_jump_solution!(
        plt,
        solution,
        model,
        solver,
        success,
        color,
        n,
        m,
        criterion,
        marker,
        marker_interval,
        idx,
        card_g,
    )
end

"""
    $(TYPEDSIGNATURES)

Add a JuMP solution to an existing multi-panel plot.

Appends state, costate, and control trajectories from a JuMP model to existing subplots
with spaced markers and consistent styling. Updates the legend with success status.

# Arguments
- `plt`: Existing Plots.Plot to modify
- `solution`: JuMP.Model object
- `model::Symbol`: Model name (for legend)
- `solver::Symbol`: Solver name (for legend)
- `success::Bool`: Whether the solution converged successfully
- `color`: Color symbol (from `get_color`)
- `n::Int`: Number of states
- `m::Int`: Number of controls
- `criterion`: Optimization criterion (`:min` or `:max`, affects costate sign)
- `marker`: Marker shape symbol (default: `:none`)
- `marker_interval::Int`: Spacing between markers (default: 10)
- `idx::Int`: Curve index for marker offset (default: 1)
- `card_g::Int`: Total number of curves for marker offset (default: 1)

# Returns
- `Plots.Plot`: Modified plot with new solution added

# Note
Even with nested layout, subplots are accessed linearly:
- `plt[1:n]` = states
- `plt[n+1:2n]` = costates
- `plt[2n+1:2n+m]` = controls
"""
function plot_jump_solution!(
    plt,
    solution,
    model::Symbol,
    solver::Symbol,
    success::Bool,
    color,
    n::Int,
    m::Int,
    criterion,
    marker=:none,
    marker_interval=10,
    idx::Int=1,
    card_g::Int=1,
)
    # Extract the JuMP data
    t = OptimalControl.time_grid(solution)
    x = OptimalControl.state(solution)
    u = OptimalControl.control(solution)
    p = OptimalControl.costate(solution)

    label_base = format_solution_label(model, solver, success)
    multiplier = costate_multiplier(criterion)

    # Subsample indices for markers with offset (uniform grid)
    grid_size = length(t) - 1
    marker_indices = get_marker_indices(idx, card_g, grid_size, marker_interval)
    t_markers = t[marker_indices]

    # Plot states: plt[1:n]
    for i in 1:n
        # Plot full line without markers
        plot!(plt[i], t, t -> x(t)[i]; color=color, linewidth=1.5, label=:none)
        # Add markers on subsampled points
        scatter!(
            plt[i],
            t_markers,
            [x(t_val)[i] for t_val in t_markers];
            color=color,
            markershape=marker,
            markersize=3,
            markerstrokewidth=0,
            label=:none,
        )
    end

    # Add an invisible point with line+marker for the legend (only on first state plot)
    plot!(
        plt[1],
        [t[1]],
        [x(t[1])[1]];
        color=color,
        linewidth=1.5,
        markershape=marker,
        markersize=3,
        label=label_base,
        markerstrokewidth=0,
    )

    # Plot costates: plt[n+1:2n]
    for i in 1:n
        # Plot full line
        plot!(
            plt[n + i],
            t,
            t -> multiplier * p(t)[i];
            color=color,
            linewidth=1.5,
            label=:none,
        )
        # Add markers on subsampled points
        scatter!(
            plt[n + i],
            t_markers,
            [multiplier * p(t_val)[i] for t_val in t_markers];
            color=color,
            markershape=marker,
            markersize=3,
            markerstrokewidth=0,
            label=:none,
        )
    end

    # Plot controls: plt[2n+1:2n+m]
    for i in 1:m
        # Plot full line
        plot!(plt[2 * n + i], t, t -> u(t)[i]; color=color, linewidth=1.5, label=:none)
        # Add markers on subsampled points
        scatter!(
            plt[2 * n + i],
            t_markers,
            [u(t_val)[i] for t_val in t_markers];
            color=color,
            markershape=marker,
            markersize=3,
            markerstrokewidth=0,
            label=:none,
        )
    end

    return plt
end

"""
    $(TYPEDSIGNATURES)

Format a short label for use in plot legends, combining success status with
the model and solver names.

The label starts with a tick or cross depending on whether the solution was
successful, followed by `model-solver`.

# Arguments
- `model::Symbol`: Model name (e.g. `:jump`, `:adnlp`, `:exa`)
- `solver::Symbol`: Solver name (e.g. `:ipopt`, `:madnlp`)
- `success::Bool`: Whether the solve succeeded (`true`) or failed (`false`)

# Returns
- `String`: A label such as `"✓ jump-ipopt"` or `"✗ exa-madnlp"`

# Example
```julia-repl
julia> using CTBenchmarks

julia> CTBenchmarks.format_solution_label(:jump, :ipopt, true)
"✓ jump-ipopt"

julia> CTBenchmarks.format_solution_label(:exa, :madnlp, false)
"✗ exa-madnlp"
```
"""
function format_solution_label(model::Symbol, solver::Symbol, disc_method::Union{String,Symbol}, success::Bool)
    disc_str = string(disc_method)
    base = string(success ? "✓" : "✗", " ", model, "-", solver)
    
    return "$base ($disc_str)"
end

"""
    $(TYPEDSIGNATURES)

Extract state and control dimensions from an OptimalControl solution.

# Arguments
- `solution::OptimalControl.Solution`: OptimalControl solution object

# Returns
- `Tuple{Int, Int}`: `(n, m)` where n = number of states, m = number of controls
"""
function get_solution_dimensions(solution::OptimalControl.Solution)
    n = OptimalControl.state_dimension(solution)
    m = OptimalControl.control_dimension(solution)
    return (n, m)
end

"""
    $(TYPEDSIGNATURES)

Extract state and control dimensions from a JuMP model solution.

# Arguments
- `solution::JuMP.Model`: JuMP model solution object

# Returns
- `Tuple{Int, Int}`: `(n, m)` where n = number of states, m = number of controls
"""
function get_solution_dimensions(solution::JuMP.Model)
    n = OptimalControlProblems.state_dimension(solution)
    m = OptimalControlProblems.control_dimension(solution)
    return (n, m)
end

"""
    $(TYPEDSIGNATURES)

Get state and control dimensions from the first available solution in a group.

Extracts the problem dimensions (number of states and controls) by examining the first
solution in the group. Works with both OptimalControl.Solution and JuMP.Model objects.

# Arguments
- `group::SubDataFrame`: DataFrame subset with solution rows

# Returns
- `Tuple{Int, Int}`: `(n, m)` where n = number of states, m = number of controls

# Example
```julia-repl
julia> using CTBenchmarks

julia> n, m = CTBenchmarks.get_dimensions(group)
(3, 2)
```
"""
function get_dimensions(group::SubDataFrame)
    n = nothing
    m = nothing
    for row in eachrow(group)
        if ismissing(row.solution)
            continue
        end

        if !applicable(get_solution_dimensions, row.solution)
            continue
        end

        n_row, m_row = get_solution_dimensions(row.solution)

        if n === nothing
            n, m = n_row, m_row
        else
            @assert n == n_row && m == m_row "Inconsistent solution dimensions in group: expected (n=$n, m=$m), got (n=$(n_row), m=$(m_row))"
        end
    end

    if n === nothing
        error("No valid solution found to determine dimensions")
    end

    return (n, m)
end

"""
    $(TYPEDSIGNATURES)

Create a nested plot layout for JuMP solutions.

Generates a multi-panel layout with states and costates in two columns, and controls
spanning the full width below. This layout facilitates easy visual comparison of multiple
solutions overlaid on the same plots.

# Arguments
- `n::Int`: Number of states
- `m::Int`: Number of controls
- `problem::Symbol`: Problem name (for plot styling)
- `grid_size::Int`: Grid size (used for sizing calculations)
- `state_labels::Vector{<:AbstractString}`: Labels for state components
- `control_labels::Vector{<:AbstractString}`: Labels for control components

# Returns
- `Plots.Plot`: Nested plot layout with (n + n + m) accessible subplots

# Layout Structure
- **Left column**: State trajectories (n subplots)
- **Right column**: Costate trajectories (n subplots)
- **Bottom**: Control trajectories (m subplots, full width)

# Details
Subplots are accessed linearly:
- `plt[1:n]` = states
- `plt[n+1:2n]` = costates
- `plt[2n+1:2n+m]` = controls

# Example
```julia-repl
julia> using CTBenchmarks

julia> state_labels = ["x₁", "x₂", "x₃"]
julia> control_labels = ["u₁", "u₂"]
julia> plt = CTBenchmarks.create_jump_layout(3, 2, :beam, 100, state_labels, control_labels)
```
"""
function create_jump_layout(
    n::Int,
    m::Int,
    problem::Symbol,
    grid_size::Int,
    state_labels::Vector{<:AbstractString},
    control_labels::Vector{<:AbstractString},
)
    lm = get_left_margin(problem)

    # Font settings
    title_font = font(10, Plots.default(:fontfamily))
    label_font = 10

    # Create individual plots for states
    state_plots = []
    for i in 1:n
        label = i <= length(state_labels) ? state_labels[i] : "x$i"
        p = plot(;
            ylabel=label,
            legend=(i==1 ? :best : :none),
            title=(i==1 ? "state" : ""),
            titlefont=title_font,
            leftmargin=lm,
            xguidefontsize=label_font,
            yguidefontsize=label_font,
            xlabel=i==n ? "time" : "",
        )
        push!(state_plots, p)
    end

    # Create individual plots for costates
    costate_plots = []
    for i in 1:n
        #label = i <= length(state_labels) ? "λ" * state_labels[i] : "λx$i"
        p = plot(;
            legend=:none,
            leftmargin=lm,
            title=(i==1 ? "costate" : ""),
            titlefont=title_font,
            xguidefontsize=label_font,
            yguidefontsize=label_font,
            xlabel=i==n ? "time" : "",
        )
        push!(costate_plots, p)
    end

    # Create individual plots for controls
    control_plots = []
    for i in 1:m
        label = i <= length(control_labels) ? control_labels[i] : "u$i"
        p = plot(;
            ylabel=label,
            title=(i==1 ? "control" : ""),
            titlefont=title_font,
            xguidefontsize=label_font,
            yguidefontsize=label_font,
            xlabel=i==m ? "time" : "",
            leftmargin=lm,
        )
        push!(control_plots, p)
    end

    # Combine states vertically
    p_state = plot(state_plots...; layout=(n, 1))

    # Combine costates vertically
    p_costate = plot(costate_plots...; layout=(n, 1))

    # Combine states and costates horizontally
    p_state_costate = plot(p_state, p_costate; layout=(1, 2))

    # Combine controls vertically
    p_control = plot(control_plots...; layout=(m, 1))

    # Combine state/costate block with control block vertically
    # Height: 240px per subplot (n states + n costates + m controls = 2n+m total)
    height = 240*(n + m)
    # Layout weights: n rows for states/costates, m rows for controls
    p_final = plot(
        p_state_costate,
        p_control;
        layout=grid(2, 1; heights=[n/(n+m), m/(n+m)]),
        size=(816, height),
        #plot_title="$problem - N=$grid_size",
        dpi=300,
    )

    return p_final
end
