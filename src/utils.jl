# ------------------------------
# Internal helper functions
# ------------------------------

"""
    solve_and_extract_data(problem, solver, model, grid_size, disc_method, 
                          tol, mu_strategy, print_level, max_iter, max_wall_time) -> NamedTuple

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
- `max_iter::Int`: maximum number of iterations
- `max_wall_time::Float64`: maximum wall time in seconds

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
    print_level::Union{Int, MadNLP.LogLevels, Missing},
    max_iter::Int,
    max_wall_time::Float64
)
    if model == :JuMP
        # ===== JuMP Model =====
        try
            nlp = eval(problem)(JuMPBackend(); grid_size=grid_size)
            
            if solver == :ipopt
                JuMP.set_optimizer(nlp, Ipopt.Optimizer)
                JuMP.set_optimizer_attribute(nlp, "sb", "yes")
                JuMP.set_optimizer_attribute(nlp, "tol", tol)
                JuMP.set_optimizer_attribute(nlp, "max_iter", max_iter)
                JuMP.set_optimizer_attribute(nlp, "max_wall_time", max_wall_time)
                if !ismissing(mu_strategy)
                    JuMP.set_optimizer_attribute(nlp, "mu_strategy", mu_strategy)
                end
                if !ismissing(print_level)
                    JuMP.set_optimizer_attribute(nlp, "print_level", print_level)
                end
            elseif solver == :madnlp
                JuMP.set_optimizer(nlp, MadNLP.Optimizer)
                JuMP.set_optimizer_attribute(nlp, "tol", tol)
                JuMP.set_optimizer_attribute(nlp, "max_iter", max_iter)
                JuMP.set_optimizer_attribute(nlp, "max_wall_time", max_wall_time)
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
                    opt = (tol=tol, mu_strategy=mu_strategy, print_level=print_level, sb="yes", max_iter=max_iter, max_wall_time=max_wall_time)
                elseif !ismissing(print_level)
                    opt = (tol=tol, print_level=print_level, sb="yes", max_iter=max_iter, max_wall_time=max_wall_time)
                else
                    opt = (tol=tol, sb="yes", max_iter=max_iter, max_wall_time=max_wall_time)
                end
                bt = @btimed NLPModelsIpopt.ipopt($nlp_model_oc; $opt...)
                nlp_sol = bt.value
            elseif solver == :madnlp
                if !ismissing(print_level)
                    opt = (tol=tol, print_level=print_level, max_iter=max_iter, max_wall_time=max_wall_time)
                else
                    opt = (tol=tol, max_iter=max_iter, max_wall_time=max_wall_time)
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
    benchmark_data(;
        problems,
        solvers,
        models,
        grid_sizes,
        disc_methods,
        tol,
        ipopt_mu_strategy,
        ipopt_print_level,
        madnlp_print_level,
        max_iter,
        max_wall_time
    ) -> DataFrame

Run benchmarks on optimal control problems and return results as a DataFrame.

For each combination of problem, solver, model, and grid size, this function:
1. Sets up and solves the optimization problem
2. Captures timing and memory statistics using `@btimed`
3. Extracts solver statistics (objective value, iterations)
4. Stores all data in a DataFrame row

# Arguments
- `problems`: Vector of problem names (Symbols)
- `solvers`: Vector of solver names (:ipopt or :madnlp)
- `models`: Vector of model types (:JuMP, :adnlp, or :exa)
- `grid_sizes`: Vector of grid sizes (Int)
- `disc_methods`: Vector of discretization methods (Symbols)
- `tol`: Solver tolerance (Float64)
- `ipopt_mu_strategy`: Mu strategy for Ipopt (String)
- `ipopt_print_level`: Print level for Ipopt (Int)
- `madnlp_print_level`: Print level for MadNLP (MadNLP.LogLevels)
- `max_iter`: Maximum number of iterations (Int)
- `max_wall_time`: Maximum wall time in seconds (Float64)

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
- `max_iter`: Int - maximum number of iterations
- `max_wall_time`: Float64 - maximum wall time in seconds
- `time`: Float64 - execution time in seconds (NaN if failed)
- `allocs`: Int - number of allocations (0 if failed)
- `memory`: Int - memory allocated in bytes (0 if failed)
- `gctime`: Float64 - garbage collection time in seconds (NaN if failed)
- `objective`: Union{Float64, Missing} - objective function value (missing if failed)
- `iterations`: Union{Int, Missing} - number of solver iterations (missing if failed)
- `status`: Any - termination status (type depends on solver/model)
- `success`: Bool - whether the solve succeeded
"""
function benchmark_data(;
    problems,
    solvers,
    models,
    grid_sizes,
    disc_methods,
    tol,
    ipopt_mu_strategy,
    ipopt_print_level,
    madnlp_print_level,
    max_iter,
    max_wall_time
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
        max_iter = Int[],
        max_wall_time = Float64[],
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
                        tol, mu_strategy, print_level, max_iter, max_wall_time
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
                        max_iter = max_iter,
                        max_wall_time = max_wall_time,
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

"""
    generate_metadata() -> Dict{String, String}

Return metadata about the current environment:
- `timestamp` (UTC, ISO8601)
- `julia_version`
- `os`
- `machine` hostname
"""
function generate_metadata()
    Dict(
        "timestamp" => Dates.format(Dates.now(), dateformat"yyyy-mm-ddTHH:MM:SSZ"),
        "julia_version" => string(VERSION),
        "os" => Sys.KERNEL,
        "machine" => gethostname(),
    )
end

"""
    build_payload(results::DataFrame, meta::Dict) -> Dict

Combine benchmark results DataFrame and metadata into a JSON-friendly dictionary.
The DataFrame is converted to a vector of dictionaries (one per row) for easy JSON serialization
and reconstruction.
"""
function build_payload(results::DataFrame, meta::Dict)
    # Convert DataFrame to vector of dictionaries using Tables.jl interface
    # This preserves all column names and types automatically
    results_vec = [Dict(pairs(row)) for row in Tables.rows(results)]
    
    Dict(
        "metadata" => meta,
        "results" => results_vec
    )
end

"""
    save_json(payload::Dict, outpath::AbstractString)

Save a JSON payload to a file. Creates the parent directory if needed.
Uses pretty printing for readability.
"""
function save_json(payload::Dict, outpath::AbstractString)
    mkpath(dirname(outpath))
    open(outpath, "w") do io
        JSON.print(io, payload)    # pretty printed, multi-line
        write(io, '\n')            # add trailing newline
    end
end

# ------------------------------
# Public API
# ------------------------------

"""
    benchmark(;
        outpath,
        problems,
        solvers,
        models,
        grid_sizes,
        disc_methods,
        tol,
        ipopt_mu_strategy,
        ipopt_print_level,
        madnlp_print_level,
        max_iter,
        max_wall_time
    ) -> String

Run benchmarks on optimal control problems and save results to a JSON file.

This function performs the following steps:
1. Runs benchmarks using `benchmark_data()` to generate a DataFrame of results
2. Collects environment metadata (Julia version, OS, machine, timestamp)
3. Builds a JSON-friendly payload combining results and metadata
4. Saves the payload to `outpath` as pretty-printed JSON

The JSON file can be easily loaded and converted back to a DataFrame using:
```julia
using JSON, DataFrames
data = JSON.parsefile("path/to/data.json")
df = DataFrame(data["results"])
```

# Arguments
- `outpath`: Path to save the JSON file
- `problems`: Vector of problem names (Symbols)
- `solvers`: Vector of solver names (:ipopt or :madnlp)
- `models`: Vector of model types (:JuMP, :adnlp, or :exa)
- `grid_sizes`: Vector of grid sizes (Int)
- `disc_methods`: Vector of discretization methods (Symbols)
- `tol`: Solver tolerance (Float64)
- `ipopt_mu_strategy`: Mu strategy for Ipopt (String)
- `ipopt_print_level`: Print level for Ipopt (Int)
- `madnlp_print_level`: Print level for MadNLP (MadNLP.LogLevels)
- `max_iter`: Maximum number of iterations (Int)
- `max_wall_time`: Maximum wall time in seconds (Float64)

# Returns
- The `outpath` of the saved JSON file.
"""
function benchmark(;
    outpath,
    problems,
    solvers,
    models,
    grid_sizes,
    disc_methods,
    tol,
    ipopt_mu_strategy,
    ipopt_print_level,
    madnlp_print_level,
    max_iter,
    max_wall_time
)
    # Run benchmarks and get DataFrame
    results = benchmark_data(;
        problems=problems,
        solvers=solvers,
        models=models,
        grid_sizes=grid_sizes,
        disc_methods=disc_methods,
        tol=tol,
        ipopt_mu_strategy=ipopt_mu_strategy,
        ipopt_print_level=ipopt_print_level,
        madnlp_print_level=madnlp_print_level,
        max_iter=max_iter,
        max_wall_time=max_wall_time
    )
    
    # Generate metadata
    meta = generate_metadata()
    
    # Build payload
    payload = build_payload(results, meta)
    
    # Save to JSON
    save_json(payload, outpath)
    
    return outpath
end
