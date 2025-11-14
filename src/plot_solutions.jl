using Plots
using Plots.PlotMeasures
using OptimalControl
using OptimalControlProblems
using JuMP
using DataFrames

# -----------------------------------
# Helper: left margin for plots
# -----------------------------------
"""
    get_left_margin(problem::Symbol)

Get the left margin for plots based on the problem.
Returns 5mm for :beam, 20mm for all other problems.
"""
function get_left_margin(problem::Symbol)
    margins = Dict(:beam => 5mm)
    return get(margins, problem, 20mm)
end

# -----------------------------------
# Helper: costate sign based on criterion
# -----------------------------------
costate_multiplier(criterion) =
    lowercase(string(ismissing(criterion) ? "min" : criterion)) == "max" ? 1 : -1

# -----------------------------------
# Helper: marker style for better visibility
# -----------------------------------
"""
    get_marker_style(idx::Int, grid_size::Int)

Get marker shape and spacing for the idx-th curve to improve visibility when curves overlap.
Returns (marker_shape, marker_interval) where marker_interval is calculated as grid_size/M with M=10
to have approximately M markers per curve.
"""
function get_marker_style(idx::Int, grid_size::Int)
    markers = [:circle, :square, :diamond, :utriangle, :dtriangle, :star5, :hexagon, :cross]
    marker = markers[mod1(idx, length(markers))]
    # Calculate interval to have approximately 10 markers per curve
    M = 10
    marker_interval = max(1, div(grid_size, M))
    return (marker, marker_interval)
end

"""
    get_marker_indices(idx::Int, card_g::Int, grid_size::Int, marker_interval::Int)

Calculate marker indices with offset to avoid superposition between curves.
For curve idx out of card_g curves, the first marker is offset by:
    offset = (idx - 1) * marker_interval / card_g

Returns the range of indices for markers.
"""
function get_marker_indices(idx::Int, card_g::Int, grid_size::Int, marker_interval::Int)
    # Calculate offset for this curve
    offset = div((idx - 1) * marker_interval, card_g)
    # Start from 1 + offset and step by marker_interval
    start_idx = 1 + offset
    return start_idx:marker_interval:(grid_size+1)
end

"""
    plot_solutions(payload::Dict, output_dir::AbstractString)

Generate PDF plots comparing solutions for each (problem, grid_size) pair.

# Arguments
- `payload::Dict`: Benchmark results with solutions
- `output_dir::AbstractString`: Directory where to save PDF files

# Details
Creates one PDF per (problem, grid_size) combination directly inside `output_dir`.
Each plot overlays all solver-model combinations for comparison.
Filename format: `<problem>_N<grid_size>.pdf`

Solutions are plotted in order: OptimalControl solutions first (easy overlay),
then JuMP solutions last (for proper layout).
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
        return
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
            filename = "$(problem)_N$(grid_size).pdf"
            filepath = joinpath(output_dir, filename)
            savefig(plt, filepath)
            
            println("    ✓ Saved: $filename")
        catch e
            println("    ✗ Error plotting $problem N=$grid_size: $e")
            Base.show_backtrace(stdout, catch_backtrace())
        end
    end
    
    println("✅ All solution plots generated in $output_dir")
end

"""
    plot_solution_comparison(group::SubDataFrame, problem::Symbol, grid_size::Int)

Create a comparison plot for all solutions in a group (same problem, same grid_size).

Strategy:
1. Plot OptimalControl solutions first (easy with plot!)
2. Plot JuMP solutions last (to get proper layout)

Layout: 2 columns for states/costates, then controls below in full width
"""
function plot_solution_comparison(group::SubDataFrame, problem::Symbol, grid_size::Int)
    plt = nothing
    colors = [:blue, :red, :green, :orange, :purple, :brown, :pink, :gray]
    color_idx = 1
    
    # Determine dimensions n and m
    n, m = get_dimensions(group)
    
    # Calculate total number of curves for marker offset
    card_g_total = nrow(group)
    
    # Separate solutions by concrete type and plot them
    # We iterate through the group and handle each type separately
    
    # 1. Plot OptimalControl solutions first
    ocp_indices = findall(row -> !ismissing(row.solution) && row.solution isa OptimalControl.Solution, eachrow(group))
    if !isempty(ocp_indices)
        ocp_rows = view(group, ocp_indices, :)
        # Pass card_g_total and starting idx (color_idx)
        plt, color_idx = plot_ocp_group(ocp_rows, plt, colors, color_idx, problem, grid_size, n, m, card_g_total)
    end
    
    # 2. Plot JuMP solutions last
    jump_indices = findall(row -> !ismissing(row.solution) && row.solution isa JuMP.Model, eachrow(group))
    if !isempty(jump_indices)
        jump_rows = view(group, jump_indices, :)
        # Pass card_g_total and current color_idx
        plt, color_idx = plot_jump_group(jump_rows, plt, colors, color_idx, problem, grid_size, n, m, card_g_total)
    end
    
    return plt
end

"""
    plot_ocp_group(ocp_rows::SubDataFrame, plt, colors::Vector, color_idx::Int, 
                   problem::Symbol, grid_size::Int, n::Int, m::Int)

Plot all OptimalControl solutions in a group. Creates the base plot if plt is nothing.

Returns: (plt, updated_color_idx)
"""
function plot_ocp_group(ocp_rows::SubDataFrame, plt, colors::Vector, color_idx::Int,
                        problem::Symbol, grid_size::Int, n::Int, m::Int, card_g_override::Union{Int,Nothing}=nothing)
    # Use override if provided, otherwise calculate from local group
    card_g = isnothing(card_g_override) ? nrow(ocp_rows) : card_g_override
    
    # For the first OCP solution: create the base plot
    first_row = ocp_rows[1, :]
    marker, marker_interval = get_marker_style(color_idx, grid_size)
    plt = plot_ocp_solution(
        first_row.solution,
        first_row.model,
        first_row.solver,
        first_row.success,
        colors[color_idx],
        problem,
        grid_size,
        n,
        m,
        marker,
        marker_interval,
        color_idx,  # Use color_idx as global idx
        card_g,
    )
    color_idx += 1
    
    # Add the remaining OCP solutions
    for row in eachrow(ocp_rows)[2:end]
        marker, marker_interval = get_marker_style(color_idx, grid_size)
        plt = plot_ocp_solution!(
            plt,
            row.solution,
            row.model,
            row.solver,
            row.success,
            colors[mod1(color_idx, length(colors))],
            n,
            m,
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
    plot_ocp_solution(solution, model::Symbol, solver::Symbol, success::Bool, color, 
                      problem::Symbol, grid_size::Int, n::Int, m::Int, marker, marker_interval)

Create a new plot for a single OptimalControl solution with markers for better visibility.

Returns: plt
"""
function plot_ocp_solution(solution, model::Symbol, solver::Symbol, success::Bool, color,
                           problem::Symbol, grid_size::Int, n::Int, m::Int, marker, marker_interval,
                           idx::Int=1, card_g::Int=1)
    # Create the plot without markers (just lines)
    plt = plot(
        solution,
        :state, :costate, :control;
        color=color,
        label=:none,  # No label yet
        size=(816, 240*(n+m)),
        leftmargin=get_left_margin(problem),
        #plot_title="$problem - N=$grid_size",
        linewidth=1.5,
    )
    
    # Get time grid and marker positions with offset
    t = OptimalControl.time_grid(solution)
    marker_indices = get_marker_indices(idx, card_g, grid_size, marker_interval)
    t_markers = t[marker_indices]
    
    # Get state, costate, control values
    x_vals = OptimalControl.state(solution)
    p_vals = OptimalControl.costate(solution)
    u_vals = OptimalControl.control(solution)
    
    # Add an invisible point with line+marker for the legend (only on first state plot)
    plot!(plt[1], [t[1]], [x_vals(t[1])[1]];
          color=color, linewidth=1.5, markershape=marker, markersize=3,
          label=format_solution_label(model, solver, success), markerstrokewidth=0)
    
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
    plot_ocp_solution!(plt, solution, model::Symbol, solver::Symbol, success::Bool, color, n::Int, m::Int, marker, marker_interval)

Add an OptimalControl solution to an existing plot with markers for better visibility.

Returns: plt
"""
function plot_ocp_solution!(plt, solution, model::Symbol, solver::Symbol, success::Bool, color, n::Int, m::Int, marker, marker_interval,
                            idx::Int=1, card_g::Int=1)
    # Add line without markers
    plot!(
        plt,
        solution,
        :state, :costate, :control;
        color=color,
        label=:none,  # No label yet
        #linestyle=:dash,
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
    
    # Add an invisible point with line+marker for the legend (only on first state plot)
    plot!(plt[1], [t[1]], [x_vals(t[1])[1]];
          color=color, linewidth=1.5, markershape=marker, markersize=3,
          label=format_solution_label(model, solver, success), markerstrokewidth=0)
    
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
    plot_jump_group(jump_rows::SubDataFrame, plt, colors::Vector, color_idx::Int,
                    problem::Symbol, grid_size::Int, n::Int, m::Int)

Plot all JuMP solutions in a group. Creates the layout if plt is nothing.

Returns: (plt, updated_color_idx)
"""
function plot_jump_group(jump_rows::SubDataFrame, plt, colors::Vector, color_idx::Int,
                         problem::Symbol, grid_size::Int, n::Int, m::Int, card_g_override::Union{Int,Nothing}=nothing)
    # Use override if provided, otherwise calculate from local group
    card_g = isnothing(card_g_override) ? nrow(jump_rows) : card_g_override
    
    for row in eachrow(jump_rows)
        current_color = colors[mod1(color_idx, length(colors))]
        marker, marker_interval = get_marker_style(color_idx, grid_size)

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
    plot_jump_solution(solution, model::Symbol, solver::Symbol, success::Bool, color,
                       problem::Symbol, grid_size::Int, n::Int, m::Int, criterion)

Create a fresh layout and plot a single JuMP solution.

Returns: plt
"""
function plot_jump_solution(solution, model::Symbol, solver::Symbol, success::Bool, color,
                            problem::Symbol, grid_size::Int, n::Int, m::Int, criterion, marker=:circle, marker_interval=10,
                            idx::Int=1, card_g::Int=1)
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
    return plot_jump_solution!(plt, solution, model, solver, success, color, n, m, criterion, marker, marker_interval, idx, card_g)
end

"""
    plot_jump_solution!(plt, solution, model::Symbol, solver::Symbol, success::Bool, color,
                       n::Int, m::Int, criterion)

Add a JuMP solution to an existing nested plot layout.

Even with the nested layout, subplots are accessed linearly:
- plt[1:n] = states
- plt[n+1:2n] = costates
- plt[2n+1:2n+m] = controls

Returns: plt
"""
function plot_jump_solution!(plt, solution, model::Symbol, solver::Symbol, success::Bool, color, n::Int, m::Int, criterion, marker=:none, marker_interval=10,
                             idx::Int=1, card_g::Int=1)
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
        plot!(
            plt[i],
            t,
            t -> x(t)[i];
            color=color,
            linewidth=1.5,
            label=:none
        )
        # Add markers on subsampled points
        scatter!(
            plt[i],
            t_markers,
            [x(t_val)[i] for t_val in t_markers];
            color=color,
            markershape=marker,
            markersize=3,
            markerstrokewidth=0,
            label=:none
        )
    end
    
    # Add an invisible point with line+marker for the legend (only on first state plot)
    plot!(plt[1], [t[1]], [x(t[1])[1]];
          color=color, linewidth=1.5, markershape=marker, markersize=3,
          label=label_base, markerstrokewidth=0)
    
    # Plot costates: plt[n+1:2n]
    for i in 1:n
        # Plot full line
        plot!(
            plt[n+i],
            t,
            t -> multiplier * p(t)[i];
            color=color,
            linewidth=1.5,
            label=:none
        )
        # Add markers on subsampled points
        scatter!(
            plt[n+i],
            t_markers,
            [multiplier * p(t_val)[i] for t_val in t_markers];
            color=color,
            markershape=marker,
            markersize=3,
            markerstrokewidth=0,
            label=:none
        )
    end
    
    # Plot controls: plt[2n+1:2n+m]
    for i in 1:m
        # Plot full line
        plot!(
            plt[2*n+i],
            t,
            t -> u(t)[i];
            color=color,
            linewidth=1.5,
            label=:none
        )
        # Add markers on subsampled points
        scatter!(
            plt[2*n+i],
            t_markers,
            [u(t_val)[i] for t_val in t_markers];
            color=color,
            markershape=marker,
            markersize=3,
            markerstrokewidth=0,
            label=:none
        )
    end
    
    return plt
end

format_solution_label(model::Symbol, solver::Symbol, success::Bool) =
    string(success ? "✓" : "✗", " ", model, "-", solver)

function get_solution_dimensions(solution::OptimalControl.Solution)
    n = OptimalControl.state_dimension(solution)
    m = OptimalControl.control_dimension(solution)
    return (n, m)
end

function get_solution_dimensions(solution::JuMP.Model)
    n = OptimalControlProblems.state_dimension(solution)
    m = OptimalControlProblems.control_dimension(solution)
    return (n, m)
end

"""
    get_dimensions(group::SubDataFrame) -> (Int, Int)

Get state and control dimensions from the first successful solution in group.
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
    create_jump_layout(n::Int, m::Int, problem::Symbol, grid_size::Int,
                       state_labels::Vector{<:AbstractString},
                       control_labels::Vector{<:AbstractString})

Create a nested plot layout for JuMP solutions with states and costates in two columns,
and controls below spanning the full width.

Layout structure:
- Individual plots for each state (with labels), combined vertically into p_state
- Individual plots for each costate (mirroring state labels), combined vertically into p_costate
- p_state and p_costate combined horizontally into p_state_costate
- Individual plots for each control, combined vertically into p_control
- p_state_costate and p_control combined vertically into p_final
"""
function create_jump_layout(n::Int, m::Int, problem::Symbol, grid_size::Int,
                            state_labels::Vector{<:AbstractString},
                            control_labels::Vector{<:AbstractString})
    lm = get_left_margin(problem)
    
    # Font settings
    title_font = font(10, Plots.default(:fontfamily))
    label_font_size = 10

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
            xguidefontsize=label_font_size,
            yguidefontsize=label_font_size,
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
            xguidefontsize=label_font_size,
            yguidefontsize=label_font_size,
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
            xguidefontsize=label_font_size,
            yguidefontsize=label_font_size,
            xlabel=i==m ? "time" : "",
            leftmargin=lm,
            )
        push!(control_plots, p)
    end
    
    # Combine states vertically
    p_state = plot(state_plots..., layout=(n, 1))
    
    # Combine costates vertically
    p_costate = plot(costate_plots..., layout=(n, 1))
    
    # Combine states and costates horizontally
    p_state_costate = plot(p_state, p_costate, layout=(1, 2))
    
    # Combine controls vertically
    p_control = plot(control_plots..., layout=(m, 1))
    
    # Combine state/costate block with control block vertically
    # Height: 240px per subplot (n states + n costates + m controls = 2n+m total)
    height = 240*(n + m)
    # Layout weights: n rows for states/costates, m rows for controls
    p_final = plot(
        p_state_costate, 
        p_control, 
        layout=grid(2, 1, heights=[n/(n+m), m/(n+m)]),
        size=(816, height),
        #plot_title="$problem - N=$grid_size"
    )
    
    return p_final
end
