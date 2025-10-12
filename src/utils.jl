# ------------------------------
# Internal helper functions
# ------------------------------

"""
    solve_and_extract_data(problem, solver, model, grid_size, disc_method, 
                          tol, mu_strategy, print_level, max_iter, max_wall_time) -> NamedTuple

Solve an optimal control problem and extract performance and solver statistics.

This internal helper function handles the solve process and data extraction for
different model types (JuMP, adnlp, exa, exa_gpu).

# Arguments
- `problem::Symbol`: problem name (e.g., :beam, :chain)
- `solver::Symbol`: solver to use (:ipopt or :madnlp)
- `model::Symbol`: model type (:JuMP, :adnlp, :exa, or :exa_gpu)
- `grid_size::Int`: number of grid points
- `disc_method::Symbol`: discretization method
- `tol::Float64`: solver tolerance
- `mu_strategy::Union{String, Missing}`: mu strategy for Ipopt (missing for MadNLP)
- `print_level::Union{Int, MadNLP.LogLevels, Missing}`: print level for solver (Int for Ipopt, MadNLP.LogLevels for MadNLP)
- `max_iter::Int`: maximum number of iterations
- `max_wall_time::Float64`: maximum wall time in seconds

# Returns
A NamedTuple with fields:
- `benchmark`: full benchmark object from @btimed (CPU) or CUDA.@timed (GPU)
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
    # Assertion: exa_gpu requires madnlp
    @assert (model != :exa_gpu || solver == :madnlp) "exa_gpu model requires madnlp solver"
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
                benchmark = bt,
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
            # Create a dummy benchmark object for error case
            dummy_bench = (time = NaN, alloc = 0, bytes = 0, gctime = NaN)
            return (
                benchmark = dummy_bench,
                objective = missing,
                iterations = missing,
                status = "ERROR: $e",
                success = false
            )
        end
    elseif model == :exa_gpu
        # ===== GPU Model (exa with CUDA backend) =====
        try
            pb = Symbol(problem, :_s)  # exa models need the suffix _s
            docp = eval(pb)(OptimalControlBackend(), :exa, solver; grid_size=grid_size, disc_method=disc_method)
            nlp_model_oc = nlp_model(docp)
            
            # Build solver options (only madnlp for GPU)
            if !ismissing(print_level)
                opt = (tol=tol, print_level=print_level, max_iter=max_iter, max_wall_time=max_wall_time, exa_backend=CUDABackend())
            else
                opt = (tol=tol, max_iter=max_iter, max_wall_time=max_wall_time, exa_backend=CUDABackend())
            end
            
            # Use CUDA.@timed for GPU benchmarking
            bt = CUDA.@timed madnlp(nlp_model_oc; opt...)
            nlp_sol = bt.value
            
            # Build OCP solution to extract statistics
            ocp_sol = build_ocp_solution(docp, nlp_sol)
            obj = objective(ocp_sol)
            iters = iterations(ocp_sol)
            status = nlp_sol.status
            
            # Check if solve succeeded
            success = (status == MadNLP.SOLVE_SUCCEEDED)
            
            return (
                benchmark = bt,
                objective = obj,
                iterations = iters,
                status = status,
                success = success
            )
        catch e
            println("ERROR in GPU solve: ", e)
            println("Stack trace: ")
            Base.show_backtrace(stdout, catch_backtrace())
            println()
            # Create a dummy benchmark object for error case
            dummy_bench = (time = NaN, cpu_bytes = 0, gpu_bytes = 0, cpu_gctime = NaN, gpu_memtime = NaN, 
                          cpu_gcstats = Base.GC_Diff(Base.gc_num(), Base.gc_num()),
                          gpu_memstats = (alloc_count = 0, alloc_bytes = 0, total_time = NaN))
            return (
                benchmark = dummy_bench,
                objective = missing,
                iterations = missing,
                status = "ERROR: $e",
                success = false
            )
        end
    else
        # ===== OptimalControl Models (adnlp or exa) =====
        try
            pb = (model == :exa) ? Symbol(problem, :_s) : problem # for exa, we need the suffix _s
            docp = eval(pb)(OptimalControlBackend(), model, solver; grid_size=grid_size, disc_method=disc_method)
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
                benchmark = bt,
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
            # Create a dummy benchmark object for error case
            dummy_bench = (time = NaN, alloc = 0, bytes = 0, gctime = NaN)
            return (
                benchmark = dummy_bench,
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
        solver_models,
        grid_sizes,
        disc_methods,
        tol,
        ipopt_mu_strategy,
        ipopt_print_level,
        madnlp_print_level,
        max_iter,
        max_wall_time,
        grid_size_max_cpu
    ) -> DataFrame

Run benchmarks on optimal control problems and return results as a DataFrame.

For each combination of problem, solver, model, and grid size, this function:
1. Sets up and solves the optimization problem
2. Captures timing and memory statistics using `@btimed` or `CUDA.@timed`
3. Extracts solver statistics (objective value, iterations)
4. Stores all data in a DataFrame row

# Arguments
- `problems`: Vector of problem names (Symbols)
- `solver_models`: Vector of Pairs mapping solver => models (e.g., [:ipopt => [:JuMP, :adnlp], :madnlp => [:exa, :exa_gpu]])
- `grid_sizes`: Vector of grid sizes (Int)
- `disc_methods`: Vector of discretization methods (Symbols)
- `tol`: Solver tolerance (Float64)
- `ipopt_mu_strategy`: Mu strategy for Ipopt (String)
- `ipopt_print_level`: Print level for Ipopt (Int)
- `madnlp_print_level`: Print level for MadNLP (MadNLP.LogLevels)
- `max_iter`: Maximum number of iterations (Int)
- `max_wall_time`: Maximum wall time in seconds (Float64)
- `grid_size_max_cpu`: Maximum grid size for CPU models (Int)

# Returns
A DataFrame with columns:
- `problem`: Symbol - problem name
- `solver`: Symbol - solver used (:ipopt or :madnlp)
- `model`: Symbol - model type (:JuMP, :adnlp, :exa, or :exa_gpu)
- `disc_method`: Symbol - discretization method
- `grid_size`: Int - number of grid points
- `tol`: Float64 - solver tolerance
- `mu_strategy`: Union{String, Missing} - mu strategy for Ipopt (missing for MadNLP)
- `print_level`: Any - print level for solver (Int for Ipopt, MadNLP.LogLevels for MadNLP)
- `max_iter`: Int - maximum number of iterations
- `max_wall_time`: Float64 - maximum wall time in seconds
- `benchmark`: NamedTuple - full benchmark object from @btimed or CUDA.@timed
- `objective`: Union{Float64, Missing} - objective function value (missing if failed)
- `iterations`: Union{Int, Missing} - number of solver iterations (missing if failed)
- `status`: Any - termination status (type depends on solver/model)
- `success`: Bool - whether the solve succeeded
"""
function benchmark_data(;
    problems,
    solver_models,
    grid_sizes,
    disc_methods,
    tol,
    ipopt_mu_strategy,
    ipopt_print_level,
    madnlp_print_level,
    max_iter,
    max_wall_time,
    grid_size_max_cpu
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
        benchmark = Any[],  # Full benchmark object from @btimed or CUDA.@timed
        objective = Union{Float64, Missing}[],
        iterations = Union{Int, Missing}[],
        status = Any[],  # Type depends on solver/model
        success = Bool[]
    )

    # Main loop over all combinations
    # Loop order: problems -> solver_models -> disc_methods -> grid_sizes -> models
    for (prob_idx, problem) in enumerate(problems)
        # Print problem header
        println("┌─ problem: $problem")
        println("│")
        
        # Create all combinations of (solver, models) and disc_method for this problem
        solver_disc_combos = [(solver, models, d) for (solver, models) in solver_models for d in disc_methods]
        
        for (combo_idx, (solver, models, disc_method)) in enumerate(solver_disc_combos)
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
            
            # Determine if this is the last solver+disc combo
            is_last_combo = (combo_idx == length(solver_disc_combos))
            
            # Print solver/disc_method header
            println("├──┬ solver: $solver, disc_method: $disc_method")
            println("│  │")
            
            for (grid_idx, N) in enumerate(grid_sizes)
                # Filter models based on grid_size_max_cpu
                # CPU models are those that don't end with "_gpu"
                models_to_run = filter(models) do model
                    is_gpu_model = endswith(string(model), "_gpu")
                    is_gpu_model || N <= grid_size_max_cpu
                end
                
                # Skip this grid size if no models to run
                if isempty(models_to_run)
                    continue
                end
                
                # Print grid size
                println("│  │  N       : $N")
                
                for model in models_to_run
                    # Solve and extract data using helper function
                    stats = solve_and_extract_data(
                        problem, solver, model, N, disc_method,
                        tol, mu_strategy, print_level, max_iter, max_wall_time
                    )
                    
                    # Format and print the benchmark line
                    println("│  │", format_benchmark_line(model, stats))
                    
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
                        benchmark = stats.benchmark,
                        objective = stats.objective,
                        iterations = stats.iterations,
                        status = stats.status,
                        success = stats.success
                    ))
                end
                
                # Add spacing between grid sizes (except after the last one)
                # Only add spacing if there are more grid sizes with models to run
                remaining_grids = grid_sizes[(grid_idx+1):end]
                has_more_grids = any(remaining_grids) do next_N
                    any(models) do model
                        is_gpu_model = endswith(string(model), "_gpu")
                        is_gpu_model || next_N <= grid_size_max_cpu
                    end
                end
                if has_more_grids
                    println("│  │ ")
                end
            end
            
            # Close solver block
            println("│  └─")
            
            # Add spacing between solver blocks (except after the last one)
            if !is_last_combo
                println("│")
            end
        end
        
        # Close problem block
        println("└─")
        println()
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
- `pkg_status` - output of Pkg.status() with ANSI colors
- `versioninfo` - output of versioninfo() with ANSI colors
- `pkg_manifest` - output of Pkg.status(mode=PKGMODE_MANIFEST) with ANSI colors
"""
function generate_metadata()
    # Capture Pkg.status() with colors
    pkg_status_output = sprint() do buffer
        io = IOContext(buffer, :color => true)
        Pkg.status(; io=io)
    end
    
    # Capture versioninfo() with colors
    versioninfo_output = sprint() do buffer
        io = IOContext(buffer, :color => true)
        versioninfo(io)
    end
    
    # Capture Pkg.status(mode=PKGMODE_MANIFEST) with colors
    pkg_manifest_output = sprint() do buffer
        io = IOContext(buffer, :color => true)
        Pkg.status(; mode = Pkg.PKGMODE_MANIFEST, io=io)
    end
    
    Dict(
        "timestamp" => Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-dd HH:MM:SS") * " UTC",
        "julia_version" => string(VERSION),
        "os" => string(Sys.KERNEL),
        "machine" => gethostname(),
        "pkg_status" => pkg_status_output,
        "versioninfo" => versioninfo_output,
        "pkg_manifest" => pkg_manifest_output,
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

function copy_project_files(outpath::AbstractString)
    root_dir = normpath(joinpath(@__DIR__, ".."))
    mkpath(outpath)
    for filename in ("Project.toml", "Manifest.toml")
        src = normpath(joinpath(root_dir, filename))
        dest = joinpath(outpath, filename)
        cp(src, dest; force=true)
    end
    return nothing
end

# ------------------------------
# Public API
# ------------------------------

"""
    benchmark(;
        outpath,
        problems,
        solver_models,
        grid_sizes,
        disc_methods,
        tol,
        ipopt_mu_strategy,
        ipopt_print_level,
        madnlp_print_level,
        max_iter,
        max_wall_time,
        grid_size_max_cpu
    ) -> String

Run benchmarks on optimal control problems and save results to a JSON file.

This function performs the following steps:
1. Detects CUDA availability and filters out :exa_gpu if CUDA is not functional
2. Runs benchmarks using `benchmark_data()` to generate a DataFrame of results
3. Collects environment metadata (Julia version, OS, machine, timestamp)
4. Builds a JSON-friendly payload combining results and metadata
5. Saves the payload to `outpath` as pretty-printed JSON

The JSON file can be easily loaded and converted back to a DataFrame using:
```julia
using JSON, DataFrames
data = JSON.parsefile("path/to/data.json")
df = DataFrame(data["results"])
```

# Arguments
- `outpath`: Path to save the JSON file
- `problems`: Vector of problem names (Symbols)
- `solver_models`: Vector of Pairs mapping solver => models (e.g., [:ipopt => [:JuMP, :adnlp], :madnlp => [:exa, :exa_gpu]])
- `grid_sizes`: Vector of grid sizes (Int)
- `disc_methods`: Vector of discretization methods (Symbols)
- `tol`: Solver tolerance (Float64)
- `ipopt_mu_strategy`: Mu strategy for Ipopt (String)
- `ipopt_print_level`: Print level for Ipopt (Int)
- `madnlp_print_level`: Print level for MadNLP (MadNLP.LogLevels)
- `max_iter`: Maximum number of iterations (Int)
- `max_wall_time`: Maximum wall time in seconds (Float64)
- `grid_size_max_cpu`: Maximum grid size for CPU models (Int)

# Returns
- The `outpath` of the saved JSON file.
"""
function benchmark(;
    outpath,
    problems,
    solver_models,
    grid_sizes,
    disc_methods,
    tol,
    ipopt_mu_strategy,
    ipopt_print_level,
    madnlp_print_level,
    max_iter,
    max_wall_time,
    grid_size_max_cpu
)
    # Detect CUDA availability and filter exa_gpu if not available
    cuda_on = CUDA.functional()
    if !cuda_on
        println("⚠️  CUDA not functional, filtering out :exa_gpu models")
        solver_models = [
            solver => filter(m -> m != :exa_gpu, models)
            for (solver, models) in solver_models
        ]
    else
        println("✓ CUDA functional, GPU benchmarks enabled")
    end
    
    # Run benchmarks and get DataFrame
    println("Running benchmarks...")
    results = benchmark_data(;
        problems=problems,
        solver_models=solver_models,
        grid_sizes=grid_sizes,
        disc_methods=disc_methods,
        tol=tol,
        ipopt_mu_strategy=ipopt_mu_strategy,
        ipopt_print_level=ipopt_print_level,
        madnlp_print_level=madnlp_print_level,
        max_iter=max_iter,
        max_wall_time=max_wall_time,
        grid_size_max_cpu=grid_size_max_cpu
    )
    
    # Generate metadata
    println("Generating metadata...")
    meta = generate_metadata()
    
    # Build payload
    println("Building payload...")
    payload = build_payload(results, meta)
    
    # Save to JSON
    println("Saving results to $outpath...")
    copy_project_files(outpath)
    JSON_path = joinpath(outpath, "data.json")
    save_json(payload, JSON_path)
    
    return nothing
end
