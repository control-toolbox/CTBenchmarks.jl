using Plots
using Plots.PlotMeasures
using OptimalControl
using OptimalControlProblems
using JuMP
using DataFrames

"""
    plot_solutions(payload::Dict, output_dir::AbstractString)

Generate PDF plots comparing solutions for each (problem, grid_size) pair.

# Arguments
- `payload::Dict`: Benchmark results with solutions
- `output_dir::AbstractString`: Directory where to save PDF files

# Details
Creates one PDF per (problem, grid_size) combination in `output_dir/figures/`.
Each plot overlays all solver-model combinations for comparison.
Filename format: `<problem>_N<grid_size>.pdf`

Solutions are plotted in order: OptimalControl solutions first (easy overlay),
then JuMP solutions last (for proper layout).
"""
function plot_solutions(payload::Dict, output_dir::AbstractString)
    # Create the figures directory
    figures_dir = joinpath(output_dir, "figures")
    mkpath(figures_dir)
    
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
            filepath = joinpath(figures_dir, filename)
            savefig(plt, filepath)
            
            println("    ✓ Saved: $filename")
        catch e
            println("    ✗ Error plotting $problem N=$grid_size: $e")
            Base.show_backtrace(stdout, catch_backtrace())
        end
    end
    
    println("✅ All solution plots generated in $figures_dir")
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
    # Separate solutions by concrete type
    ocp_rows = filter(row -> !ismissing(row.solution) && row.solution isa OptimalControl.Solution, group)
    jump_rows = filter(row -> !ismissing(row.solution) && row.solution isa JuMP.Model, group)
    
    plt = nothing
    colors = [:blue, :red, :green, :orange, :purple, :brown, :pink, :gray]
    color_idx = 1
    
    # Determine dimensions n and m
    n, m = get_dimensions(group)
    
    # 1. Plot OptimalControl solutions first
    if !isempty(ocp_rows)
        plt, color_idx = plot_ocp_group(ocp_rows, plt, colors, color_idx, problem, grid_size, n, m)
    end
    
    # 2. Plot JuMP solutions last
    if !isempty(jump_rows)
        plt, color_idx = plot_jump_group(jump_rows, plt, colors, color_idx, problem, grid_size, n, m)
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
                        problem::Symbol, grid_size::Int, n::Int, m::Int)
    # For the first OCP solution: create the base plot
    first_row = ocp_rows[1, :]
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
    )
    color_idx += 1
    
    # Add the remaining OCP solutions
    for row in eachrow(ocp_rows)[2:end]
        plt = plot_ocp_solution!(
            plt,
            row.solution,
            row.model,
            row.solver,
            row.success,
            colors[mod1(color_idx, length(colors))],
        )
        color_idx += 1
    end
    
    return plt, color_idx
end

"""
    plot_ocp_solution(solution, model::Symbol, solver::Symbol, color, 
                      problem::Symbol, grid_size::Int, n::Int, m::Int)

Create a new plot for a single OptimalControl solution.

Returns: plt
"""
function plot_ocp_solution(solution, model::Symbol, solver::Symbol, success::Bool, color,
                           problem::Symbol, grid_size::Int, n::Int, m::Int)
    plt = plot(
        solution,
        :state, :costate, :control;
        color=color,
        label=format_solution_label(model, solver, success),
        size=(816, 240*(n+m)),
        leftmargin=5mm,
        title="$problem - N=$grid_size"
    )
    return plt
end

"""
    plot_ocp_solution!(plt, solution, model::Symbol, solver::Symbol, success::Bool, color)

Add an OptimalControl solution to an existing plot.

Returns: plt
"""
function plot_ocp_solution!(plt, solution, model::Symbol, solver::Symbol, success::Bool, color)
    plot!(
        plt,
        solution,
        :state, :costate, :control;
        color=color,
        label=format_solution_label(model, solver, success),
        linestyle=:dash
    )
    return plt
end

"""
    plot_jump_group(jump_rows::SubDataFrame, plt, colors::Vector, color_idx::Int,
                    problem::Symbol, grid_size::Int, n::Int, m::Int)

Plot all JuMP solutions in a group. Creates the layout if plt is nothing.

Returns: (plt, updated_color_idx)
"""
function plot_jump_group(jump_rows::SubDataFrame, plt, colors::Vector, color_idx::Int,
                         problem::Symbol, grid_size::Int, n::Int, m::Int)
    for row in eachrow(jump_rows)
        # If no plot yet, create one with a two-column layout
        if plt === nothing
            plt = create_jump_layout(n, m, problem, grid_size)
        end
        
        plt = plot_jump_solution!(
            plt,
            row.solution,
            row.model,
            row.solver,
            row.success,
            colors[mod1(color_idx, length(colors))],
            n,
            m,
        )
        color_idx += 1
    end

    return plt, color_idx
end

"""
    plot_jump_solution(solution, model::Symbol, solver::Symbol, success::Bool, color,
                       problem::Symbol, grid_size::Int, n::Int, m::Int)

Create a fresh layout and plot a single JuMP solution.

Returns: plt
"""
function plot_jump_solution(solution, model::Symbol, solver::Symbol, success::Bool, color,
                            problem::Symbol, grid_size::Int, n::Int, m::Int)
    plt = create_jump_layout(n, m, problem, grid_size)
    return plot_jump_solution!(plt, solution, model, solver, success, color, n, m)
end

"""
    plot_jump_solution!(plt, solution, model::Symbol, solver::Symbol, success::Bool, color, n::Int, m::Int)

Add a JuMP solution to an existing plot (with two-column layout).

Returns: plt
"""
function plot_jump_solution!(plt, solution, model::Symbol, solver::Symbol, success::Bool, color, n::Int, m::Int)
    # Extract the JuMP data
    t = OptimalControl.time_grid(solution)
    x = OptimalControl.state(solution)
    u = OptimalControl.control(solution)
    p = OptimalControl.costate(solution)
    
    label_base = format_solution_label(model, solver, success)
    
    # Plot states (column 1)
    for i in 1:n
        subplot_idx = 2*(i-1) + 1
        plot!(
            plt[subplot_idx],
            t,
            t -> x(t)[i];
            color=color,
            linestyle=:dot,
            label=(i == 1 ? label_base : :none)
        )
    end
    
    # Plot costates (column 2)
    for i in 1:n
        subplot_idx = 2*i
        plot!(
            plt[subplot_idx],
            t,
            t -> -p(t)[i];
            color=color,
            linestyle=:dot,
            label=:none
        )
    end
    
    # Plot controls (below, full width)
    for i in 1:m
        subplot_idx = 2*n + i
        plot!(
            plt[subplot_idx],
            t,
            t -> u(t)[i];
            color=color,
            linestyle=:dot,
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
    create_jump_layout(n::Int, m::Int, problem::Symbol, grid_size::Int)

Create a plot layout for JuMP solutions with 2 columns (state/costate) and controls below.

Layout structure:
- Top: n rows × 2 columns (states left, costates right)
- Bottom: m rows × 2 columns (controls spanning full width)
"""
function create_jump_layout(n::Int, m::Int, problem::Symbol, grid_size::Int)
    # Layout: 2 columns for states/costates, then controls below
    # Total subplots: 2*n (states + costates) + m (controls)
    total_plots = 2*n + m
    
    # Create the grid layout
    # n rows for states/costates (2 columns)
    # m rows for controls (2 columns but we use @layout to merge them)
    
    # Height: 150px per state/costate row, 200px per control row
    height = 150*n + 200*m
    
    plt = plot(
        layout=(n + m, 2),
        size=(816, height),
        leftmargin=5mm,
        plot_title="$problem - N=$grid_size"
    )
    
    # Configure the subplots for states (column 1)
    for i in 1:n
        subplot_idx = 2*(i-1) + 1
        plot!(plt[subplot_idx]; ylabel="x$i", legend=(i==1 ? :best : :none))
    end
    
    # Configure the subplots for costates (column 2)
    for i in 1:n
        subplot_idx = 2*i
        plot!(plt[subplot_idx]; ylabel="p$i", legend=:none)
    end
    
    # Configure the subplots for controls (merged across 2 columns)
    for i in 1:m
        # Controls occupy indices 2*n+1 to 2*n+m
        # Use two columns to get the full width
        subplot_idx_left = 2*n + 2*(i-1) + 1
        subplot_idx_right = 2*n + 2*i
        
        if subplot_idx_left <= total_plots
            plot!(plt[subplot_idx_left]; ylabel="u$i", legend=:none)
        end
        if subplot_idx_right <= total_plots
            # Hide or merge the right subplot
            plot!(plt[subplot_idx_right]; ylabel="", legend=:none, axis=:off)
        end
    end
    
    return plt
end
