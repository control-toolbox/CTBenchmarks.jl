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

# Beam problem with JuMP model
println("  • Solving beam with JuMP...")
beam_jump_result = CTBenchmarks.solve_and_extract_data(
    :beam, :ipopt, :jump, 200, :trapeze, 1e-8, "adaptive", false, 1000, 120.0
)

# Beam problem with OptimalControl model (adnlp)
println("  • Solving beam with adnlp...")
beam_ocp_result = CTBenchmarks.solve_and_extract_data(
    :beam, :ipopt, :adnlp, 200, :trapeze, 1e-8, "adaptive", false, 1000, 120.0
)

# Space shuttle problem with JuMP model
println("  • Solving space_shuttle with JuMP...")
shuttle_jump_result = CTBenchmarks.solve_and_extract_data(
    :space_shuttle, :ipopt, :jump, 500, :trapeze, 1e-8, "adaptive", false, 1000, 120.0
)

# Space shuttle problem with OptimalControl model (adnlp)
println("  • Solving space_shuttle with adnlp...")
shuttle_ocp_result = CTBenchmarks.solve_and_extract_data(
    :space_shuttle, :ipopt, :adnlp, 500, :trapeze, 1e-8, "adaptive", false, 1000, 120.0
)

# ============================================================================
# Step 2: Test individual plot functions (no side effects)
# ============================================================================

println("\n📊 Testing individual plot functions...\n")

# Test 1: plot_ocp_solution (create new plot for OCP solution)
println("Test 1: plot_ocp_solution (beam with adnlp)")
if beam_ocp_result.success
    n_beam, m_beam = CTBenchmarks.get_solution_dimensions(beam_ocp_result.solution)
    plt1 = CTBenchmarks.plot_ocp_solution(
        beam_ocp_result.solution,
        :adnlp,
        :ipopt,
        beam_ocp_result.success,
        :blue,
        :beam,
        200,
        n_beam,
        m_beam
    )
    println("  ✓ Created OCP plot for beam (n=$n_beam, m=$m_beam)")
    display(plt1)
else
    println("  ✗ Failed to solve beam with adnlp")
end

# Test 2: plot_ocp_solution (space_shuttle with adnlp)
println("\nTest 2: plot_ocp_solution (space_shuttle with adnlp)")
if shuttle_ocp_result.success
    n_shuttle, m_shuttle = CTBenchmarks.get_solution_dimensions(shuttle_ocp_result.solution)
    plt2 = CTBenchmarks.plot_ocp_solution(
        shuttle_ocp_result.solution,
        :adnlp,
        :ipopt,
        shuttle_ocp_result.success,
        :red,
        :space_shuttle,
        500,
        n_shuttle,
        m_shuttle,
    )
    println("  ✓ Plotted space_shuttle with adnlp on fresh figure (n=$n_shuttle, m=$m_shuttle)")
    display(plt2)
else
    println("  ✗ Failed to solve space_shuttle with adnlp")
end

# Test 3: plot_jump_solution (beam with JuMP)
println("\nTest 3: plot_jump_solution (beam with JuMP)")
if beam_jump_result.success
    n_beam_jump, m_beam_jump = CTBenchmarks.get_solution_dimensions(beam_jump_result.solution)
    plt3 = CTBenchmarks.plot_jump_solution(
        beam_jump_result.solution,
        :jump,
        :ipopt,
        beam_jump_result.success,
        :green,
        :beam,
        200,
        n_beam_jump,
        m_beam_jump
    )
    println("  ✓ Plotted beam with JuMP (n=$n_beam_jump, m=$m_beam_jump)")
    display(plt3)
else
    println("  ✗ Failed to solve beam with JuMP")
end

# Test 4: plot_jump_solution (space_shuttle with JuMP)
println("\nTest 4: plot_jump_solution (space_shuttle with JuMP)")
if shuttle_jump_result.success
    n_shuttle_jump, m_shuttle_jump = CTBenchmarks.get_solution_dimensions(shuttle_jump_result.solution)
    plt4 = CTBenchmarks.plot_jump_solution(
        shuttle_jump_result.solution,
        :jump,
        :ipopt,
        shuttle_jump_result.success,
        :orange,
        :space_shuttle,
        500,
        n_shuttle_jump,
        m_shuttle_jump
    )
    println("  ✓ Plotted space_shuttle with JuMP (n=$n_shuttle_jump, m=$m_shuttle_jump)")
    display(plt4)
else
    println("  ✗ Failed to solve space_shuttle with JuMP")
end

println("\n✅ All individual plot function tests completed!")