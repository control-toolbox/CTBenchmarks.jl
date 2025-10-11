using OptimalControlProblems
using OptimalControl
import JuMP
import Ipopt
import NLPModelsIpopt 
using MadNLPMumps
using BenchmarkTools
using DataFrames

"""
    solve_and_extract_data(problem, solver, model, grid_size, disc_method, 
                          tol, mu_strategy, print_level) -> NamedTuple

Solve an optimal control problem and extract performance and solver statistics.

This internal helper function handles the solve process and data extraction for
different model types (JuMP, adnlp, exa).

# Arguments
- `problem::Symbol`: problem name (e.g., :beam, :chain)
- `solver::Symbol`: solver to use (:ipopt or :madnlp)
- `model::Symbol`: model type (:JuMP, :adnlp, or :exa)
- `grid_size::Int`: number of grid points
- `disc_method::Symbol`: discretization method
- `tol::Float64`: solver tolerance
- `mu_strategy::Union{String, Missing}`: mu strategy for Ipopt (missing for MadNLP)
- `print_level::Union{Int, MadNLP.LogLevels, Missing}`: print level for solver (Int for Ipopt, MadNLP.LogLevels for MadNLP)

# Returns
A NamedTuple with fields:
- `time::Float64`: execution time in seconds (or NaN if failed)
- `allocs::Int`: number of allocations (or 0 if failed)
- `memory::Int`: memory allocated in bytes (or 0 if failed)
- `gctime::Float64`: garbage collection time in seconds (or NaN if failed)
- `objective::Union{Float64, Missing}`: objective function value (missing if failed)
- `iterations::Union{Int, Missing}`: number of solver iterations (missing if failed)
- `status::Any`: termination status (type depends on solver/model)
- `success::Bool`: whether the solve succeeded
"""
function solve_and_extract_data(
    problem::Symbol,
    solver::Symbol,
    model::Symbol,
    grid_size::Int,
    disc_method::Symbol,
    tol::Float64,
    mu_strategy::Union{String, Missing},
    print_level::Union{Int, MadNLP.LogLevels, Missing}
)
    if model == :JuMP
        # ===== JuMP Model =====
        try
            nlp = eval(problem)(JuMPBackend(); grid_size=grid_size)
            
            if solver == :ipopt
                JuMP.set_optimizer(nlp, Ipopt.Optimizer)
                JuMP.set_optimizer_attribute(nlp, "sb", "yes")
                JuMP.set_optimizer_attribute(nlp, "tol", tol)
                if !ismissing(mu_strategy)
                    JuMP.set_optimizer_attribute(nlp, "mu_strategy", mu_strategy)
                end
                if !ismissing(print_level)
                    JuMP.set_optimizer_attribute(nlp, "print_level", print_level)
                end
            elseif solver == :madnlp
                JuMP.set_optimizer(nlp, MadNLP.Optimizer)
                JuMP.set_optimizer_attribute(nlp, "tol", tol)
                if !ismissing(print_level)
                    JuMP.set_optimizer_attribute(nlp, "print_level", print_level)
                end
            else
                error("undefined solver: $solver")
            end
            
            bt = @btimed JuMP.optimize!($nlp)
            
            # Extract statistics from JuMP model
            status = JuMP.termination_status(nlp)
            obj = objective(nlp)
            iters = iterations(nlp)
            
            # Check if solve succeeded (MOI.LOCALLY_SOLVED or MOI.OPTIMAL)
            success = (status == JuMP.MOI.LOCALLY_SOLVED || status == JuMP.MOI.OPTIMAL)
            
            return (
                time = bt.time,
                allocs = bt.alloc,
                memory = bt.bytes,
                gctime = bt.gctime,
                objective = obj,
                iterations = iters,
                status = status,
                success = success
            )
        catch e
            println("ERROR in JuMP solve: ", e)
            println("Stack trace: ")
            Base.show_backtrace(stdout, catch_backtrace())
            println()
            return (
                time = NaN,
                allocs = 0,
                memory = 0,
                gctime = NaN,
                objective = missing,
                iterations = missing,
                status = "ERROR: $e",
                success = false
            )
        end
    else
        # ===== OptimalControl Models (adnlp or exa) =====
        try
            docp = eval(Symbol(problem, :_s))(OptimalControlBackend(), model, solver; 
                                              grid_size=grid_size, disc_method=disc_method)
            nlp_model_oc = nlp_model(docp)
            
            # Build solver options and solve
            if solver == :ipopt
                if !ismissing(mu_strategy) && !ismissing(print_level)
                    opt = (tol=tol, mu_strategy=mu_strategy, print_level=print_level, sb="yes")
                elseif !ismissing(print_level)
                    opt = (tol=tol, print_level=print_level, sb="yes")
                else
                    opt = (tol=tol, sb="yes")
                end
                bt = @btimed NLPModelsIpopt.ipopt($nlp_model_oc; $opt...)
                nlp_sol = bt.value
            elseif solver == :madnlp
                if !ismissing(print_level)
                    opt = (tol=tol, print_level=print_level)
                else
                    opt = (tol=tol,)
                end
                bt = @btimed madnlp($nlp_model_oc; $opt...)
                nlp_sol = bt.value
            else
                error("undefined solver: $solver")
            end
            
            # Build OCP solution to extract statistics
            ocp_sol = build_ocp_solution(docp, nlp_sol)
            obj = objective(ocp_sol)
            iters = iterations(ocp_sol)
            status = nlp_sol.status
            
            # Check if solve succeeded
            # For Ipopt: :first_order or :acceptable
            # For MadNLP: MadNLP.SOLVE_SUCCEEDED
            if solver == :ipopt
                success = (status == :first_order || status == :acceptable)
            elseif solver == :madnlp
                success = (status == MadNLP.SOLVE_SUCCEEDED)
            else
                success = false
            end
            
            return (
                time = bt.time,
                allocs = bt.alloc,
                memory = bt.bytes,
                gctime = bt.gctime,
                objective = obj,
                iterations = iters,
                status = status,
                success = success
            )
        catch e
            println("ERROR in OptimalControl solve: ", e)
            println("Stack trace: ")
            Base.show_backtrace(stdout, catch_backtrace())
            println()
            return (
                time = NaN,
                allocs = 0,
                memory = 0,
                gctime = NaN,
                objective = missing,
                iterations = missing,
                status = "ERROR: $e",
                success = false
            )
        end
    end
end

"""
    benchmark_minimal_data(;
        problems = [:beam, :chain, :double_oscillator, :ducted_fan, :electric_vehicle, 
                    :glider, :insurance, :jackson, :robbins, :robot, :rocket, 
                    :space_shuttle, :steering, :vanderpol],
        solvers = [:ipopt, :madnlp],
        models = [:JuMP, :adnlp, :exa],
        grid_sizes = [200],
        disc_method = :trapeze,
        tol = 1e-8,
        ipopt_mu_strategy = "adaptive",
        ipopt_print_level = 0,
        madnlp_print_level = MadNLP.ERROR
    ) -> DataFrame

Run benchmarks on optimal control problems and return results as a DataFrame.

For each combination of problem, solver, model, and grid size, this function:
1. Sets up and solves the optimization problem
2. Captures timing and memory statistics using `@btimed`
3. Extracts solver statistics (objective value, iterations)
4. Stores all data in a DataFrame row

# Returns
A DataFrame with columns:
- `problem`: Symbol - problem name
- `solver`: Symbol - solver used (:ipopt or :madnlp)
- `model`: Symbol - model type (:JuMP, :adnlp, or :exa)
- `disc_method`: Symbol - discretization method
- `grid_size`: Int - number of grid points
- `tol`: Float64 - solver tolerance
- `mu_strategy`: Union{String, Missing} - mu strategy for Ipopt (missing for MadNLP)
- `print_level`: Any - print level for solver (Int for Ipopt, MadNLP.LogLevels for MadNLP)
- `time`: Float64 - execution time in seconds (NaN if failed)
- `allocs`: Int - number of allocations (0 if failed)
- `memory`: Int - memory allocated in bytes (0 if failed)
- `gctime`: Float64 - garbage collection time in seconds (NaN if failed)
- `objective`: Union{Float64, Missing} - objective function value (missing if failed)
- `iterations`: Union{Int, Missing} - number of solver iterations (missing if failed)
- `status`: Any - termination status (type depends on solver/model)
- `success`: Bool - whether the solve succeeded
"""
function benchmark_minimal_data(;
    problems = [:beam,
                :chain,
                :double_oscillator,
                :ducted_fan,
                :electric_vehicle,
                :glider,
                :insurance,
                :jackson,
                :robbins,
                :robot,
                :rocket,
                :space_shuttle,
                :steering,
                :vanderpol],
    solvers = [:ipopt, :madnlp],
    models = [:JuMP, :adnlp, :exa],
    grid_sizes = [200],
    disc_methods = [:trapeze],
    tol = 1e-8,
    ipopt_mu_strategy = "adaptive",
    ipopt_print_level = 0,
    madnlp_print_level = MadNLP.ERROR
)
    # Initialize DataFrame
    data = DataFrame(
        problem = Symbol[],
        solver = Symbol[],
        model = Symbol[],
        disc_method = Symbol[],
        grid_size = Int[],
        tol = Float64[],
        mu_strategy = Union{String, Missing}[],
        print_level = Any[],  # Can be Int or MadNLP.LogLevel
        time = Float64[],
        allocs = Int[],
        memory = Int[],
        gctime = Float64[],
        objective = Union{Float64, Missing}[],
        iterations = Union{Int, Missing}[],
        status = Any[],  # Type depends on solver/model
        success = Bool[]
    )

    # Main loop over all combinations
    for solver in solvers
        # Set solver-specific options
        if solver == :ipopt
            mu_strategy = ipopt_mu_strategy
            print_level = ipopt_print_level
        elseif solver == :madnlp
            mu_strategy = missing
            print_level = madnlp_print_level
        else
            error("undefined solver: $solver")
        end

        for problem in problems, disc_method in disc_methods
            println("\nproblem: $problem, solver: $solver, disc_method: $disc_method")
            
            for N in grid_sizes
                println("N: $N")
                
                for model in models
                    print("  $(rpad(string(model), 6)) : ")
                    
                    # Solve and extract data using helper function
                    stats = solve_and_extract_data(
                        problem, solver, model, N, disc_method,
                        tol, mu_strategy, print_level
                    )
                    
                    println("$(stats.time)s, $(stats.allocs) allocs, $(stats.memory) bytes")
                    
                    # Store results in DataFrame
                    push!(data, (
                        problem = problem,
                        solver = solver,
                        model = model,
                        disc_method = disc_method,
                        grid_size = N,
                        tol = tol,
                        mu_strategy = mu_strategy,
                        print_level = print_level,
                        time = stats.time,
                        allocs = stats.allocs,
                        memory = stats.memory,
                        gctime = stats.gctime,
                        objective = stats.objective,
                        iterations = stats.iterations,
                        status = stats.status,
                        success = stats.success
                    ))
                end
            end
        end
    end
    
    return data
end