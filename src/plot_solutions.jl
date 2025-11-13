using Plots
using Plots.PlotMeasures
using OptimalControl
using OptimalControlProblems
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
    # Créer le répertoire figures
    figures_dir = joinpath(output_dir, "figures")
    mkpath(figures_dir)
    
    # Récupérer les données
    results_vec = payload["results"]
    solutions = payload["solutions"]
    solution_types = payload["solution_types"]
    
    # Reconstruire un DataFrame avec les solutions
    df = DataFrame(results_vec)
    df.solution = solutions
    df.solution_type = solution_types
    
    # Filtrer les solutions réussies avec solution non-missing
    df_success = filter(row -> row.success && !ismissing(row.solution), df)
    
    if isempty(df_success)
        println("⚠️  No successful solutions to plot")
        return
    end
    
    # Grouper par (problem, grid_size)
    grouped = groupby(df_success, [:problem, :grid_size])
    
    println("📊 Generating solution plots...")
    for group in grouped
        problem = first(group.problem)
        grid_size = first(group.grid_size)
        
        println("  - Plotting $problem with N=$grid_size ($(nrow(group)) solutions)")
        
        try
            # Créer le plot
            plt = plot_solution_comparison(group, problem, grid_size)
            
            # Sauvegarder en PDF
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
    # Séparer les solutions par type
    ocp_rows = filter(row -> row.solution_type == :ocp, group)
    jump_rows = filter(row -> row.solution_type == :jump, group)
    
    plt = nothing
    colors = [:blue, :red, :green, :orange, :purple, :brown, :pink, :gray]
    color_idx = 1
    
    # Déterminer les dimensions n et m
    n, m = get_dimensions(group)
    
    # 1. Tracer les solutions OptimalControl d'abord
    if !isempty(ocp_rows)
        # Première solution OCP: créer le plot de base
        first_row = ocp_rows[1, :]
        plt = plot(
            first_row.solution,
            :state, :costate, :control;
            color=colors[color_idx],
            label="$(first_row.model)-$(first_row.solver)",
            size=(816, 600),
            leftmargin=5mm,
            title="$problem - N=$grid_size"
        )
        color_idx += 1
        
        # Ajouter les autres solutions OCP
        for row in eachrow(ocp_rows)[2:end]
            plot!(
                plt,
                row.solution,
                :state, :costate, :control;
                color=colors[mod1(color_idx, length(colors))],
                label="$(row.model)-$(row.solver)",
                linestyle=:dash
            )
            color_idx += 1
        end
    end
    
    # 2. Tracer les solutions JuMP en dernier
    if !isempty(jump_rows)
        for row in eachrow(jump_rows)
            nlp_jp = row.solution
            
            # Si pas encore de plot, créer avec layout 2 colonnes
            if plt === nothing
                plt = create_jump_layout(n, m, problem, grid_size)
            end
            
            # Extraire les données JuMP
            t = OptimalControl.time_grid(nlp_jp)
            x = OptimalControl.state(nlp_jp)
            u = OptimalControl.control(nlp_jp)
            p = OptimalControl.costate(nlp_jp)
            
            label_base = "$(row.model)-$(row.solver)"
            current_color = colors[mod1(color_idx, length(colors))]
            
            # Plot states (colonne 1)
            for i in 1:n
                subplot_idx = 2*(i-1) + 1
                plot!(
                    plt[subplot_idx],
                    t,
                    t -> x(t)[i];
                    color=current_color,
                    linestyle=:dot,
                    label=(i == 1 ? label_base : :none)
                )
            end
            
            # Plot costates (colonne 2)
            for i in 1:n
                subplot_idx = 2*i
                plot!(
                    plt[subplot_idx],
                    t,
                    t -> -p(t)[i];
                    color=current_color,
                    linestyle=:dot,
                    label=:none
                )
            end
            
            # Plot controls (en dessous, pleine largeur)
            for i in 1:m
                subplot_idx = 2*n + i
                plot!(
                    plt[subplot_idx],
                    t,
                    t -> u(t)[i];
                    color=current_color,
                    linestyle=:dot,
                    label=:none
                )
            end
            
            color_idx += 1
        end
    end
    
    return plt
end

"""
    get_dimensions(group::SubDataFrame) -> (Int, Int)

Get state and control dimensions from the first successful solution in group.
"""
function get_dimensions(group::SubDataFrame)
    for row in eachrow(group)
        if row.solution_type == :ocp
            n = OptimalControl.state_dimension(row.solution)
            m = OptimalControl.control_dimension(row.solution)
            return (n, m)
        elseif row.solution_type == :jump
            n = OptimalControlProblems.state_dimension(row.solution)
            m = OptimalControlProblems.control_dimension(row.solution)
            return (n, m)
        end
    end
    error("No valid solution found to determine dimensions")
end

"""
    create_jump_layout(n::Int, m::Int, problem::Symbol, grid_size::Int)

Create a plot layout for JuMP solutions with 2 columns (state/costate) and controls below.

Layout structure:
- Top: n rows × 2 columns (states left, costates right)
- Bottom: m rows × 2 columns (controls spanning full width)
"""
function create_jump_layout(n::Int, m::Int, problem::Symbol, grid_size::Int)
    # Layout: 2 colonnes pour states/costates, puis controls en dessous
    # Total subplots: 2*n (states + costates) + m (controls)
    total_plots = 2*n + m
    
    # Créer le layout avec grid
    # n lignes pour states/costates (2 colonnes)
    # m lignes pour controls (2 colonnes mais on utilisera @layout pour fusionner)
    
    # Hauteur: 150px par ligne de state/costate, 200px par ligne de control
    height = 150*n + 200*m
    
    plt = plot(
        layout=(n + m, 2),
        size=(816, height),
        leftmargin=5mm,
        plot_title="$problem - N=$grid_size"
    )
    
    # Configurer les subplots pour les states (colonne 1)
    for i in 1:n
        subplot_idx = 2*(i-1) + 1
        plot!(plt[subplot_idx]; ylabel="x$i", legend=(i==1 ? :best : :none))
    end
    
    # Configurer les subplots pour les costates (colonne 2)
    for i in 1:n
        subplot_idx = 2*i
        plot!(plt[subplot_idx]; ylabel="p$i", legend=:none)
    end
    
    # Configurer les subplots pour les controls (fusionnés sur 2 colonnes)
    for i in 1:m
        # Les controls occupent les indices 2*n+1 à 2*n+m
        # On les met sur 2 colonnes pour avoir la pleine largeur
        subplot_idx_left = 2*n + 2*(i-1) + 1
        subplot_idx_right = 2*n + 2*i
        
        if subplot_idx_left <= total_plots
            plot!(plt[subplot_idx_left]; ylabel="u$i", legend=:none)
        end
        if subplot_idx_right <= total_plots
            # Masquer le subplot de droite ou le fusionner
            plot!(plt[subplot_idx_right]; ylabel="", legend=:none, axis=:off)
        end
    end
    
    return plt
end
