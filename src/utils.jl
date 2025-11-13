# ------------------------------
# Internal helper functions
# ------------------------------

"""
    strip_benchmark_value(bench)

Remove the `value` field from benchmark outputs (NamedTuple or Dict) to
ensure JSON-serializable data while preserving all other statistics.
"""
strip_benchmark_value(bench) = bench

function strip_benchmark_value(bench::NamedTuple)
    pairs_without_value = ((k => getproperty(bench, k)) for k in keys(bench) if k != :value)
    return (; pairs_without_value...)
end

function strip_benchmark_value(bench::Dict)
    filtered = Dict{Any,Any}()
    for (k, v) in bench
        if k != :value && k != "value"
            filtered[k] = v
        end
    end
    return filtered
end

"""
    solve_and_extract_data(problem, solver, model, grid_size, disc_method, 
                          tol, mu_strategy, print_level, max_iter, max_wall_time) -> NamedTuple

Solve an optimal control problem and extract performance and solver statistics.

This internal helper function handles the solve process and data extraction for
different model types (JuMP, adnlp, exa, exa_gpu).

# Arguments
- `problem::Symbol`: problem name (e.g., :beam, :chain)
- `solver::Symbol`: solver to use (:ipopt or :madnlp)
- `model::Symbol`: model type (:jump, :adnlp, :exa, or :exa_gpu)
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
- `criterion::Union{String, Missing}`: optimization sense ("min" or "max", missing if failed)
"""
function solve_and_extract_data(
    problem::Symbol,
    solver::Symbol,
    model::Symbol,
    grid_size::Int,
    disc_method::Symbol,
    tol::Float64,
    mu_strategy::Union{String,Missing},
    print_trace::Bool,
    max_iter::Int,
    max_wall_time::Float64,
)
    # print_level
    print_level = set_print_level(solver, print_trace)

    # Assertions: GPU models require MadNLP and CUDA
    is_gpu_model = endswith(string(model), "_gpu")
    @assert (!is_gpu_model || solver == :madnlp) "gpu model requires madnlp solver"
    @assert (!is_gpu_model || is_cuda_on()) "gpu model requires CUDA"
    @assert (model != :jump || disc_method == :trapeze) "JuMP model requires :trapeze discretization"
    @assert (solver != :ipopt || !ismissing(mu_strategy))

    # solve the problem
    if model == :jump
        # ===== JuMP Model =====
        try
            nlp = eval(problem)(JuMPBackend(); grid_size=grid_size)

            if solver == :ipopt
                JuMP.set_optimizer(nlp, Ipopt.Optimizer)
                JuMP.set_optimizer_attribute(nlp, "sb", "yes")
                JuMP.set_optimizer_attribute(nlp, "mu_strategy", mu_strategy)
                JuMP.set_optimizer_attribute(nlp, "linear_solver", "mumps")
            elseif solver == :madnlp
                JuMP.set_optimizer(nlp, MadNLP.Optimizer)
                JuMP.set_optimizer_attribute(nlp, "linear_solver", MumpsSolver)
            else
                error("undefined solver: $solver")
            end
            JuMP.set_optimizer_attribute(nlp, "tol", tol)
            JuMP.set_optimizer_attribute(nlp, "max_iter", max_iter)
            JuMP.set_optimizer_attribute(nlp, "max_wall_time", max_wall_time)

            # solve the problem always with print_level = set_print_level(solver, false)
            JuMP.set_optimizer_attribute(nlp, "print_level", print_level)
            ITERATION[] = 0
            bt = @btimed begin
                ITERATION[] += 1
                if ITERATION[] == 2
                    JuMP.set_optimizer_attribute(
                        $nlp, "print_level", set_print_level($solver, false)
                    )
                end
                JuMP.optimize!($nlp)
                $nlp
            end

            # Extract statistics from JuMP model
            bt_nlp = bt.value
            status = JuMP.termination_status(bt_nlp)
            obj = objective(bt_nlp)
            iters = iterations(bt_nlp)

            # Extract criterion (min or max)
            sense = JuMP.objective_sense(bt_nlp)
            criterion = (sense == JuMP.MAX_SENSE) ? "max" : "min"

            # Check if solve succeeded (MOI.LOCALLY_SOLVED or MOI.OPTIMAL)
            success = (status == JuMP.MOI.LOCALLY_SOLVED || status == JuMP.MOI.OPTIMAL)

            return (
                benchmark=strip_benchmark_value(bt),
                objective=obj,
                iterations=iters,
                status=status,
                success=success,
                criterion=criterion,
                solution=bt_nlp,
                solution_type=:jump,
            )
        catch e
            println("ERROR in JuMP solve: ", e)
            Base.show_backtrace(stdout, catch_backtrace())
            println()
            # Create a dummy benchmark object for error case
            dummy_bench = (time=NaN, alloc=0, bytes=0, gctime=NaN)
            return (
                benchmark=missing, #dummy_bench,
                objective=missing,
                iterations=missing,
                status="ERROR: $e",
                success=false,
                criterion=missing,
                solution=missing,
                solution_type=missing,
            )
        end
    elseif model == :exa_gpu
        # ===== GPU Model (exa with CUDA backend) =====
        try
            pb = Symbol(string(problem) * "_s")  # exa models need the suffix _s
            docp = eval(pb)(
                OptimalControlBackend(),
                :exa,
                solver;
                exa_backend=CUDABackend(),
                grid_size=grid_size,
                disc_method=disc_method,
            )
            nlp_model_oc = nlp_model(docp)

            # Build solver options (only madnlp for GPU)
            opt = Dict{Symbol,Any}(
                :tol => tol,
                :print_level => print_level,
                :max_iter => max_iter,
                :max_wall_time => max_wall_time,
            )

            # Use CUDA.@timed for GPU benchmarking
            madnlp(nlp_model_oc; opt...) # run for warmup
            ITERATION[] = 0
            bt = CUDA.@timed begin
                ITERATION[] += 1
                if ITERATION[] == 2
                    opt[:print_level] = set_print_level(solver, false)
                end
                madnlp(nlp_model_oc; opt...)
            end
            bt_nlp_sol = bt.value

            # Build OCP solution to extract statistics
            ocp_sol = OptimalControl.build_OCP_solution(docp, bt_nlp_sol)
            obj = objective(ocp_sol)
            iters = iterations(ocp_sol)
            status = bt_nlp_sol.status

            # Extract criterion from OCP model
            ocp_model_oc = ocp_model(docp)
            criterion_sym = OptimalControl.criterion(ocp_model_oc)
            criterion = string(criterion_sym)

            # Check if solve succeeded
            success = (status == MadNLP.SOLVE_SUCCEEDED)

            return (
                benchmark=strip_benchmark_value(bt),
                objective=obj,
                iterations=iters,
                status=status,
                success=success,
                criterion=criterion,
                solution=ocp_sol,
                solution_type=:ocp,
            )
        catch e
            println("ERROR in GPU solve: ", e)
            Base.show_backtrace(stdout, catch_backtrace())
            println()
            # Create a dummy benchmark object for error case
            dummy_bench = (
                time=NaN,
                cpu_bytes=0,
                gpu_bytes=0,
                cpu_gctime=NaN,
                gpu_memtime=NaN,
                cpu_gcstats=Base.GC_Diff(Base.gc_num(), Base.gc_num()),
                gpu_memstats=(alloc_count=0, alloc_bytes=0, total_time=NaN),
            )
            return (
                benchmark=missing, #dummy_bench,
                objective=missing,
                iterations=missing,
                status="ERROR: $e",
                success=false,
                criterion=missing,
                solution=missing,
                solution_type=missing,
            )
        end
    else
        # ===== OptimalControl Models (adnlp or exa) =====
        try
            pb = (model == :exa) ? Symbol(string(problem) * "_s") : problem # for exa, we need the suffix _s
            docp = eval(pb)(
                OptimalControlBackend(),
                model,
                solver;
                grid_size=grid_size,
                disc_method=disc_method,
            )
            nlp_model_oc = nlp_model(docp)

            # Build solver options and solve
            opt = Dict{Symbol,Any}(
                :tol => tol,
                :print_level => print_level,
                :max_iter => max_iter,
                :max_wall_time => max_wall_time,
            )
            if solver == :ipopt
                opt[:mu_strategy] = mu_strategy
                opt[:sb] = "yes"
                opt[:linear_solver] = "mumps"
                ITERATION[] = 0
                bt = @btimed begin
                    ITERATION[] += 1
                    if ITERATION[] == 2
                        $opt[:print_level] = set_print_level($solver, false)
                    end
                    NLPModelsIpopt.ipopt($nlp_model_oc; $opt...)
                end
                bt_nlp_sol = bt.value
            elseif solver == :madnlp
                opt[:linear_solver] = MumpsSolver
                ITERATION[] = 0
                bt = @btimed begin
                    ITERATION[] += 1
                    if ITERATION[] == 2
                        $opt[:print_level] = set_print_level($solver, false)
                    end
                    madnlp($nlp_model_oc; $opt...)
                end
                bt_nlp_sol = bt.value
            else
                error("undefined solver: $solver")
            end

            # Build OCP solution to extract statistics
            ocp_sol = OptimalControl.build_OCP_solution(docp, bt_nlp_sol)
            obj = objective(ocp_sol)
            iters = iterations(ocp_sol)
            status = bt_nlp_sol.status

            # Extract criterion from OCP model
            ocp_model_oc = ocp_model(docp)
            criterion_sym = OptimalControl.criterion(ocp_model_oc)
            criterion = string(criterion_sym)

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
                benchmark=strip_benchmark_value(bt),
                objective=obj,
                iterations=iters,
                status=status,
                success=success,
                criterion=criterion,
                solution=ocp_sol,
                solution_type=:ocp,
            )
        catch e
            println("ERROR in OptimalControl solve: ", e)
            Base.show_backtrace(stdout, catch_backtrace())
            println()
            # Create a dummy benchmark object for error case
            dummy_bench = (time=NaN, alloc=0, bytes=0, gctime=NaN)
            return (
                benchmark=missing, #dummy_bench,
                objective=missing,
                iterations=missing,
                status="ERROR: $e",
                success=false,
                criterion=missing,
                solution=missing,
                solution_type=missing,
            )
        end
    end
end

"""
    is_cuda_on() -> Bool

Return true if CUDA is functional on this machine.
"""
is_cuda_on() = CUDA.functional()

"""
    filter_models_for_backend(models::Vector{Symbol}, disc_method::Symbol) -> Vector{Symbol}

Filter solver models depending on backend availability and discretization support.

- GPU models (ending with `_gpu`) are kept only if CUDA is available.
- JuMP models are kept only when `disc_method == :trapeze`.
"""
function filter_models_for_backend(models::Vector{Symbol}, disc_method::Symbol)
    cuda_on = is_cuda_on()
    supports_jump = disc_method == :trapeze
    return [
        model for model in models if
        endswith(string(model), "_gpu") ? cuda_on : (model != :jump || supports_jump)
    ]
end

"""
    set_print_level(solver::Symbol, print_trace::Bool) -> Int

Set print level based on solver and print_trace flag.
"""
function set_print_level(solver::Symbol, print_trace::Bool)
    if solver == :ipopt
        return print_trace ? 5 : 0
    elseif solver == :madnlp
        return print_trace ? MadNLP.INFO : MadNLP.ERROR
    else
        error("undefined solver: $solver")
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
        print_trace
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
- `solver_models`: Vector of Pairs mapping solver => models (e.g., [:ipopt => [:jump, :adnlp], :madnlp => [:exa, :exa_gpu]])
- `grid_sizes`: Vector of grid sizes (Int)
- `disc_methods`: Vector of discretization methods (Symbols)
- `tol`: Solver tolerance (Float64)
- `ipopt_mu_strategy`: Mu strategy for Ipopt (String)
- `print_trace`: Boolean - whether to print solver output (for debugging)
- `max_iter`: Maximum number of iterations (Int)
- `max_wall_time`: Maximum wall time in seconds (Float64)

# Returns
A DataFrame with columns:
- `problem`: Symbol - problem name
- `solver`: Symbol - solver used (:ipopt or :madnlp)
- `model`: Symbol - model type (:jump, :adnlp, :exa, or :exa_gpu)
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
- `criterion`: Union{String, Missing} - optimization sense ("min" or "max", missing if failed)
"""
function benchmark_data(;
    problems,
    solver_models,
    grid_sizes,
    disc_methods,
    tol,
    ipopt_mu_strategy,
    print_trace,
    max_iter,
    max_wall_time,
)
    # Initialize DataFrame
    data = DataFrame(;
        problem=Symbol[],
        solver=Symbol[],
        model=Symbol[],
        disc_method=Symbol[],
        grid_size=Int[],
        tol=Float64[],
        mu_strategy=Union{String,Missing}[],
        max_iter=Int[],
        max_wall_time=Float64[],
        benchmark=Any[],
        objective=Union{Float64,Missing}[],
        iterations=Union{Int,Missing}[],
        status=Any[],
        success=Bool[],
        criterion=Union{String,Missing}[],
        solution=Any[],
        solution_type=Union{Symbol,Missing}[],
    )

    # Main loop over all combinations
    # Loop order: problems -> solver_models -> disc_methods -> grid_sizes -> models
    for (prob_idx, problem) in enumerate(problems)
        # Print problem header with color
        print("┌─ ")
        printstyled("Problem: $problem"; color=:blue, bold=true)
        println()
        println("│")

        # Create all combinations of (solver, models) and disc_method for this problem
        solver_disc_combos = [
            (solver, models, d) for (solver, models) in solver_models for d in disc_methods
        ]

        for (combo_idx, (solver, models, disc_method)) in enumerate(solver_disc_combos)
            # Set solver-specific options
            if solver == :ipopt
                mu_strategy = ipopt_mu_strategy
            elseif solver == :madnlp
                mu_strategy = missing
            else
                error("undefined solver: $solver")
            end

            # Determine if this is the last solver+disc combo
            is_last_combo = (combo_idx == length(solver_disc_combos))

            # Print solver/disc_method header with colors
            print("├──┬ ")
            printstyled("Solver: $solver"; color=:cyan, bold=true)
            print(", ")
            printstyled("Discretization: $disc_method"; color=:yellow, bold=true)
            println()
            println("│  │")

            for (grid_idx, N) in enumerate(grid_sizes)
                # Filter models based on CUDA availability and discretization support
                models_to_run = filter_models_for_backend(models, disc_method)

                # Skip this grid size if no models to run
                if isempty(models_to_run)
                    continue
                end

                # Print grid size with color
                print("│  │  ")
                printstyled("N = $N"; color=:yellow, bold=true)
                println()

                for model in models_to_run
                    # Solve and extract data using helper function
                    stats = solve_and_extract_data(
                        problem,
                        solver,
                        model,
                        N,
                        disc_method,
                        tol,
                        mu_strategy,
                        print_trace,
                        max_iter,
                        max_wall_time,
                    )

                    # Print the benchmark line with colors
                    print("│  │")
                    print_benchmark_line(model, stats)

                    # Store results in DataFrame
                    push!(
                        data,
                        (
                            problem=problem,
                            solver=solver,
                            model=model,
                            disc_method=disc_method,
                            grid_size=N,
                            tol=tol,
                            mu_strategy=mu_strategy,
                            max_iter=max_iter,
                            max_wall_time=max_wall_time,
                            benchmark=stats.benchmark,
                            objective=stats.objective,
                            iterations=stats.iterations,
                            status=stats.status,
                            success=stats.success,
                            criterion=stats.criterion,
                            solution=stats.solution,
                            solution_type=stats.solution_type,
                        ),
                    )
                end

                # Add spacing between grid sizes (except after the last one)
                # Only add spacing if there are more grid sizes with models to run
                remaining_grids = grid_sizes[(grid_idx + 1):end]
                has_more_grids = any(remaining_grids) do next_N
                    !isempty(filter_models_for_backend(models, disc_method))
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
        Pkg.status(; mode=Pkg.PKGMODE_MANIFEST, io=io)
    end

    Dict(
        "timestamp" =>
            Dates.format(Dates.now(Dates.UTC), dateformat"yyyy-mm-dd HH:MM:SS") * " UTC",
        "julia_version" => string(VERSION),
        "os" => string(Sys.KERNEL),
        "machine" => gethostname(),
        "pkg_status" => pkg_status_output,
        "versioninfo" => versioninfo_output,
        "pkg_manifest" => pkg_manifest_output,
    )
end

"""
    build_payload(results::DataFrame, meta::Dict, config::Dict) -> Dict

Combine benchmark results DataFrame, metadata, and configuration into a JSON-friendly dictionary.
The DataFrame is converted to a vector of dictionaries (one per row) for easy JSON serialization
and reconstruction.

Solutions are extracted and kept in memory (not serialized to JSON) for later plot generation.
"""
function build_payload(results::DataFrame, meta::Dict, config::Dict)
    # Extract solutions and solution_types BEFORE conversion to JSON
    solutions = results.solution
    solution_types = results.solution_type
    
    # Create a copy of DataFrame WITHOUT solution columns
    results_for_json = select(results, Not([:solution, :solution_type]))
    
    # Convert DataFrame to vector of dictionaries using Tables.jl interface
    # This preserves all column names and types automatically
    results_vec = [Dict(pairs(row)) for row in Tables.rows(results_for_json)]

    # Add configuration to metadata
    meta_with_config = merge(meta, Dict("configuration" => config))

    Dict(
        "metadata" => meta_with_config,
        "results" => results_vec,
        "solutions" => solutions,  # Kept in memory, not in JSON
        "solution_types" => solution_types,  # Kept in memory, not in JSON
    )
end

"""
    save_json(payload::Dict, outpath::AbstractString)

Save a JSON payload to a file. Creates the parent directory if needed.
Uses pretty printing for readability.
Sanitizes NaN and Inf values to null for JSON compatibility.

Solutions and solution_types are excluded from JSON serialization (kept only in memory).
"""
function save_json(payload::Dict, outpath::AbstractString)
    mkpath(dirname(outpath))
    
    # Filter out solutions and solution_types before JSON serialization
    json_payload = Dict(
        k => v for (k, v) in payload if k ∉ ("solutions", "solution_types")
    )
    
    open(outpath, "w") do io
        JSON.print(io, json_payload, 4)    # pretty printed with 4-space indent
        write(io, '\n')            # add trailing newline
    end
end

# ------------------------------
# Public API
# ------------------------------

"""
    benchmark(;
        problems,
        solver_models,
        grid_sizes,
        disc_methods,
        tol,
        ipopt_mu_strategy,
        print_trace,
        max_iter,
        max_wall_time,
        grid_size_max_cpu
    ) -> Nothing

Run benchmarks on optimal control problems and save results to a JSON file.

This function performs the following steps:
1. Detects CUDA availability and filters out :exa_gpu if CUDA is not functional
2. Runs benchmarks using `benchmark_data()` to generate a DataFrame of results
3. Collects environment metadata (Julia version, OS, machine, timestamp)
4. Builds a JSON-friendly payload combining results and metadata
5. Returns the payload as a Dict

The JSON file can be easily loaded and converted back to a DataFrame using:
```julia
using JSON, DataFrames
data = JSON.parsefile("path/to/data.json")
df = DataFrame(data["results"])
```

!!! note "File Management in CI"
    When run in the GitHub Actions workflow, `Project.toml` and `Manifest.toml` are 
    automatically copied to the output directory by the workflow itself. This ensures 
    reproducibility of benchmark results.

!!! note "Return Value"
    This function returns `Dict`.

# Arguments
- `problems`: Vector of problem names (Symbols)
- `solver_models`: Vector of Pairs mapping solver => models (e.g., [:ipopt => [:jump, :adnlp], :madnlp => [:exa, :exa_gpu]])
- `grid_sizes`: Vector of grid sizes (Int)
- `disc_methods`: Vector of discretization methods (Symbols)
- `tol`: Solver tolerance (Float64)
- `ipopt_mu_strategy`: Mu strategy for Ipopt (String)
- `print_trace`: Boolean - whether to print solver output (for debugging)
- `max_iter`: Maximum number of iterations (Int)
- `max_wall_time`: Maximum wall time in seconds (Float64)
- `grid_size_max_cpu`: Maximum grid size for CPU models (Int)

# Returns
- `Dict`
"""
function benchmark(;
    problems::Vector{Symbol},
    solver_models::Vector{Pair{Symbol,Vector{Symbol}}},
    grid_sizes::Vector{Int},
    disc_methods::Vector{Symbol},
    tol::Float64,
    ipopt_mu_strategy::String,
    print_trace::Bool,
    max_iter::Int,
    max_wall_time::Float64,
)

    # Detect CUDA availability (logging only; filtering handled in benchmark_data)
    if is_cuda_on()
        println("✓ CUDA functional, GPU benchmarks enabled")
    else
        println("⚠️  CUDA not functional, GPU models will be skipped")
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
        print_trace=print_trace,
        max_iter=max_iter,
        max_wall_time=max_wall_time,
    )

    # Generate metadata
    println("Generating metadata...")
    meta = generate_metadata()

    # Build configuration dictionary
    config = Dict(
        "problems" => problems,
        "solver_models" => solver_models,
        "grid_sizes" => grid_sizes,
        "disc_methods" => disc_methods,
        "tol" => tol,
        "ipopt_mu_strategy" => ipopt_mu_strategy,
        "print_trace" => print_trace,
        "max_iter" => max_iter,
        "max_wall_time" => max_wall_time,
    )

    # Build payload
    println("Building payload...")
    payload = build_payload(results, meta, config)

    return payload
end
