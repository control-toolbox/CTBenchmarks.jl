try
    using Revise
catch
    @warn "Revise not available, continuing without it"
end

using Pkg
const project_dir = normpath(joinpath(@__DIR__, "..", ".."))

println("📦 Activating project environment...")
Pkg.activate(project_dir)

# This file is used to test the plot_solutions function
# Tests individual plot functions with no side effects on existing plots.
# We use beam and space_shuttle problems with small grid sizes for quick testing.

# ============================================================================
# Step 1: Solve problems to get solutions
# ============================================================================

using OptimalControlProblems
using OptimalControl
using CTBenchmarks
using Plots

println("\n🔧 Solving test problems...")

# Beam problem with JuMP model (ipopt)
println("  • Solving beam with JuMP + ipopt...")
beam_jump_ipopt_result = CTBenchmarks.solve_and_extract_data(
    :beam, :ipopt, :jump, 200, :trapeze, 1e-8, "adaptive", false, 1000, 120.0
)

# Beam problem with JuMP model (madnlp)
println("  • Solving beam with JuMP + madnlp...")
beam_jump_madnlp_result = CTBenchmarks.solve_and_extract_data(
    :beam, :madnlp, :jump, 200, :trapeze, 1e-8, missing, false, 1000, 120.0
)

# Beam problem with OptimalControl model (adnlp + ipopt)
println("  • Solving beam with adnlp + ipopt...")
beam_ocp_ipopt_result = CTBenchmarks.solve_and_extract_data(
    :beam, :ipopt, :adnlp, 200, :trapeze, 1e-8, "adaptive", false, 1000, 120.0
)

# Beam problem with OptimalControl model (adnlp + madnlp)
println("  • Solving beam with adnlp + madnlp...")
beam_ocp_madnlp_result = CTBenchmarks.solve_and_extract_data(
    :beam, :madnlp, :adnlp, 200, :trapeze, 1e-8, missing, false, 1000, 120.0
)

# Space shuttle problem with JuMP model (ipopt)
println("  • Solving space_shuttle with JuMP + ipopt...")
shuttle_jump_ipopt_result = CTBenchmarks.solve_and_extract_data(
    :space_shuttle, :ipopt, :jump, 500, :trapeze, 1e-8, "adaptive", false, 1000, 120.0
)

# Space shuttle problem with JuMP model (madnlp)
println("  • Solving space_shuttle with JuMP + madnlp...")
shuttle_jump_madnlp_result = CTBenchmarks.solve_and_extract_data(
    :space_shuttle, :madnlp, :jump, 500, :trapeze, 1e-8, missing, false, 1000, 120.0
)

# Space shuttle problem with OptimalControl model (adnlp + ipopt)
println("  • Solving space_shuttle with adnlp + ipopt...")
shuttle_ocp_ipopt_result = CTBenchmarks.solve_and_extract_data(
    :space_shuttle, :ipopt, :adnlp, 500, :trapeze, 1e-8, "adaptive", false, 1000, 120.0
)

# Space shuttle problem with OptimalControl model (adnlp + madnlp)
println("  • Solving space_shuttle with adnlp + madnlp...")
shuttle_ocp_madnlp_result = CTBenchmarks.solve_and_extract_data(
    :space_shuttle, :madnlp, :adnlp, 500, :trapeze, 1e-8, missing, false, 1000, 120.0
)

# ============================================================================
# Step 2: Test individual plot functions (no side effects)
# ============================================================================

println("\n📊 Testing individual plot functions...\n")

# Test 1: plot_ocp_solution (create new plot for OCP solution)
println("Test 1: plot_ocp_solution (beam with adnlp)")
if beam_ocp_ipopt_result.success
    n_beam, m_beam = CTBenchmarks.get_solution_dimensions(beam_ocp_ipopt_result.solution)
    grid_size_beam = 200
    marker, marker_interval = CTBenchmarks.get_marker_style(:adnlp, :ipopt, 1, grid_size_beam)
    plt1 = CTBenchmarks.plot_ocp_solution(
        beam_ocp_ipopt_result.solution,
        :adnlp,
        :ipopt,
        beam_ocp_ipopt_result.success,
        :blue,
        :beam,
        grid_size_beam,
        n_beam,
        m_beam,
        marker,
        marker_interval
    )
    println("  ✓ Created OCP plot for beam (n=$n_beam, m=$m_beam)")
    display(plt1)
else
    println("  ✗ Failed to solve beam with adnlp")
end

# Test 2: plot_ocp_solution (space_shuttle with adnlp)
println("\nTest 2: plot_ocp_solution (space_shuttle with adnlp)")
if shuttle_ocp_ipopt_result.success
    n_shuttle, m_shuttle = CTBenchmarks.get_solution_dimensions(shuttle_ocp_ipopt_result.solution)
    grid_size_shuttle = 500
    marker, marker_interval = CTBenchmarks.get_marker_style(:adnlp, :ipopt, 2, grid_size_shuttle)
    plt2 = CTBenchmarks.plot_ocp_solution(
        shuttle_ocp_ipopt_result.solution,
        :adnlp,
        :ipopt,
        shuttle_ocp_ipopt_result.success,
        :red,
        :space_shuttle,
        grid_size_shuttle,
        n_shuttle,
        m_shuttle,
        marker,
        marker_interval
    )
    println("  ✓ Plotted space_shuttle with adnlp on fresh figure (n=$n_shuttle, m=$m_shuttle)")
    display(plt2)
else
    println("  ✗ Failed to solve space_shuttle with adnlp")
end

# Test 3: plot_jump_solution (beam with JuMP)
println("\nTest 3: plot_jump_solution (beam with JuMP)")
if beam_jump_ipopt_result.success
    n_beam_jump, m_beam_jump = CTBenchmarks.get_solution_dimensions(beam_jump_ipopt_result.solution)
    grid_size_beam_jump = 200
    marker, marker_interval = CTBenchmarks.get_marker_style(:jump, :ipopt, 3, grid_size_beam_jump)
    plt3 = CTBenchmarks.plot_jump_solution(
        beam_jump_ipopt_result.solution,
        :jump,
        :ipopt,
        beam_jump_ipopt_result.success,
        :green,
        :beam,
        grid_size_beam_jump,
        n_beam_jump,
        m_beam_jump,
        beam_jump_ipopt_result.criterion,
        marker,
        marker_interval
    )
    println("  ✓ Plotted beam with JuMP (n=$n_beam_jump, m=$m_beam_jump)")
    display(plt3)
else
    println("  ✗ Failed to solve beam with JuMP")
end

# Test 4: plot_jump_solution (space_shuttle with JuMP)
println("\nTest 4: plot_jump_solution (space_shuttle with JuMP)")
if shuttle_jump_ipopt_result.success
    n_shuttle_jump, m_shuttle_jump = CTBenchmarks.get_solution_dimensions(shuttle_jump_ipopt_result.solution)
    grid_size_shuttle_jump = 500
    marker, marker_interval = CTBenchmarks.get_marker_style(:jump, :ipopt, 4, grid_size_shuttle_jump)
    plt4 = CTBenchmarks.plot_jump_solution(
        shuttle_jump_ipopt_result.solution,
        :jump,
        :ipopt,
        shuttle_jump_ipopt_result.success,
        :orange,
        :space_shuttle,
        grid_size_shuttle_jump,
        n_shuttle_jump,
        m_shuttle_jump,
        shuttle_jump_ipopt_result.criterion,
        marker,
        marker_interval
    )
    println("  ✓ Plotted space_shuttle with JuMP (n=$n_shuttle_jump, m=$m_shuttle_jump)")
    display(plt4)
else
    println("  ✗ Failed to solve space_shuttle with JuMP")
end

println("\n✅ All individual plot function tests completed!")

# ============================================================================
# Step 3: Test adding plots to existing figure
# ============================================================================
println("\n🎯 Testing plot overlays on existing figures...\n")

# Beam: add JuMP solution on top of existing OCP plot
println("Test 5: overlay JuMP solution on beam OCP plot")
if beam_ocp_ipopt_result.success && beam_jump_ipopt_result.success
    grid_size_beam_jump = 200
    marker, marker_interval = CTBenchmarks.get_marker_style(:jump, :ipopt, 3, grid_size_beam_jump)
    CTBenchmarks.plot_jump_solution!(
        plt1,
        beam_jump_ipopt_result.solution,
        :jump,
        :ipopt,
        beam_jump_ipopt_result.success,
        :green,
        n_beam_jump,
        m_beam_jump,
        beam_jump_ipopt_result.criterion,
        marker,
        marker_interval,
    )
    println("  ✓ Added JuMP solution to beam OCP plot")
    display(plt1)
elseif !beam_ocp_ipopt_result.success
    println("  ✗ Cannot overlay: beam OCP solution unavailable")
else
    println("  ✗ Cannot overlay: beam JuMP solution unavailable")
end

# Space shuttle: add JuMP solution on top of existing OCP plot
println("\nTest 6: overlay JuMP solution on space_shuttle OCP plot")
if shuttle_ocp_ipopt_result.success && shuttle_jump_ipopt_result.success
    grid_size_shuttle_jump = 500
    marker, marker_interval = CTBenchmarks.get_marker_style(:jump, :ipopt, 4, grid_size_shuttle_jump)
    CTBenchmarks.plot_jump_solution!(
        plt2,
        shuttle_jump_ipopt_result.solution,
        :jump,
        :ipopt,
        shuttle_jump_ipopt_result.success,
        :orange,
        n_shuttle_jump,
        m_shuttle_jump,
        shuttle_jump_ipopt_result.criterion,
        marker,
        marker_interval,
    )
    println("  ✓ Added JuMP solution to space_shuttle OCP plot")
    display(plt2)
elseif !shuttle_ocp_ipopt_result.success
    println("  ✗ Cannot overlay: space_shuttle OCP solution unavailable")
else
    println("  ✗ Cannot overlay: space_shuttle JuMP solution unavailable")
end

# ============================================================================
# Step 4: Test of plot_jump_group and plot_ocp_group
# ============================================================================
println("\n📦 Testing group plotting functions...\n")

# Test 7: plot_ocp_group with beam solutions (ipopt + madnlp)
println("Test 7: plot_ocp_group (beam with adnlp, ipopt + madnlp)")
if beam_ocp_ipopt_result.success && beam_ocp_madnlp_result.success
    using DataFrames
    # Create a DataFrame with both beam OCP solutions
    ocp_df = DataFrame(
        solution=[beam_ocp_ipopt_result.solution, beam_ocp_madnlp_result.solution],
        model=[:adnlp, :adnlp],
        solver=[:ipopt, :madnlp],
        success=[beam_ocp_ipopt_result.success, beam_ocp_madnlp_result.success],
        problem=[:beam, :beam],
        grid_size=[200, 200],
    )
    
    # Convert to SubDataFrame using groupby
    grouped = groupby(ocp_df, [:problem, :grid_size])
    ocp_group = grouped[1]  # Get the first (and only) group
    
    colors = [:blue, :red, :green, :orange]
    plt7, _ = CTBenchmarks.plot_ocp_group(
        ocp_group,
        nothing,  # no existing plot
        colors,
        1,  # color_idx
        :beam,
        200,
        n_beam,
        m_beam,
    )
    println("  ✓ Created OCP group plot for beam with 2 solutions")
    display(plt7)
else
    println("  ✗ Failed to solve beam with adnlp (one or both solvers)")
end

# Test 8: plot_jump_group with beam solutions (ipopt + madnlp)
println("\nTest 8: plot_jump_group (beam with JuMP, ipopt + madnlp)")
if beam_jump_ipopt_result.success && beam_jump_madnlp_result.success
    # Create a DataFrame with both beam JuMP solutions
    jump_df = DataFrame(
        solution=[beam_jump_ipopt_result.solution, beam_jump_madnlp_result.solution],
        model=[:jump, :jump],
        solver=[:ipopt, :madnlp],
        success=[beam_jump_ipopt_result.success, beam_jump_madnlp_result.success],
        criterion=[beam_jump_ipopt_result.criterion, beam_jump_madnlp_result.criterion],
        problem=[:beam, :beam],
        grid_size=[200, 200],
    )
    
    # Convert to SubDataFrame using groupby
    grouped = groupby(jump_df, [:problem, :grid_size])
    jump_group = grouped[1]  # Get the first (and only) group
    
    colors = [:blue, :red, :green, :orange]
    plt8, _ = CTBenchmarks.plot_jump_group(
        jump_group,
        nothing,  # no existing plot
        colors,
        1,  # color_idx
        :beam,
        200,
        n_beam_jump,
        m_beam_jump,
    )
    println("  ✓ Created JuMP group plot for beam with 2 solutions")
    display(plt8)
else
    println("  ✗ Failed to solve beam with JuMP (one or both solvers)")
end

println("\n✅ Group plotting function tests completed!")

# ============================================================================
# Step 5: Test of plot_solution_comparison
# ============================================================================
println("\n🔀 Testing plot_solution_comparison...\n")

# Test 9: plot_solution_comparison with beam (all 4 solutions: 2 OCP + 2 JuMP)
println("Test 9: plot_solution_comparison (beam with all solutions)")
if beam_ocp_ipopt_result.success && beam_ocp_madnlp_result.success && 
   beam_jump_ipopt_result.success && beam_jump_madnlp_result.success
    # Create a DataFrame with all 4 beam solutions
    all_beam_df = DataFrame(
        solution=[
            beam_ocp_ipopt_result.solution,
            beam_ocp_madnlp_result.solution,
            beam_jump_ipopt_result.solution,
            beam_jump_madnlp_result.solution
        ],
        model=[:adnlp, :adnlp, :jump, :jump],
        solver=[:ipopt, :madnlp, :ipopt, :madnlp],
        success=[
            beam_ocp_ipopt_result.success,
            beam_ocp_madnlp_result.success,
            beam_jump_ipopt_result.success,
            beam_jump_madnlp_result.success
        ],
        criterion=[
            beam_ocp_ipopt_result.criterion,
            beam_ocp_madnlp_result.criterion,
            beam_jump_ipopt_result.criterion,
            beam_jump_madnlp_result.criterion
        ],
        problem=[:beam, :beam, :beam, :beam],
        grid_size=[200, 200, 200, 200],
    )
    
    # Convert to SubDataFrame using groupby
    grouped = groupby(all_beam_df, [:problem, :grid_size])
    comparison_group = grouped[1]
    
    plt9 = CTBenchmarks.plot_solution_comparison(
        comparison_group,
        :beam,
        200
    )
    println("  ✓ Created comparison plot for beam with 4 solutions (2 OCP + 2 JuMP)")
    display(plt9)
else
    println("  ✗ Failed to solve all beam solutions")
end

println("\n✅ plot_solution_comparison test completed!")

# ============================================================================
# Step 6: Test of plot_solutions (full pipeline)
# ============================================================================
println("\n📈 Testing plot_solutions (full benchmark pipeline)...\n")

println("Running small benchmark...")
results = CTBenchmarks.benchmark(;
    problems=[
        :beam,
        :space_shuttle,
    ],
    solver_models=[
        :ipopt => [:jump, :adnlp],
        :madnlp => [:jump, :adnlp],
    ],
    grid_sizes=[200, 500],
    disc_methods=[:trapeze],
    tol=1e-8,
    ipopt_mu_strategy="adaptive",
    print_trace=false,
    max_iter=1000,
    max_wall_time=120.0,
)

println("\n📊 Generating plots from benchmark results...")
output_dir = joinpath(@__DIR__)
figures_dir = joinpath(output_dir, "figures")
CTBenchmarks.plot_solutions(results, figures_dir)

println("\n✅ plot_solutions test completed!")
println("   Figures saved in: $figures_dir")

# ============================================================================