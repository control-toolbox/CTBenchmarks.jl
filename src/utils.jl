"""
    $(TYPEDSIGNATURES)

Remove the `value` field from benchmark outputs (NamedTuple or Dict) to
ensure JSON-serializable data while preserving all other statistics.

The `value` field typically contains the actual return value from the benchmarked
code, which may not be JSON-serializable. This function strips it out while keeping
timing, memory allocation, and other benchmark statistics intact.

# Arguments
- `bench`: Benchmark output (NamedTuple, Dict, or other type)

# Returns
- Same type as input, with `value` field removed (if present)

# Details
Three methods are provided:
- **Default**: Returns input unchanged (for types without a `value` field)
- **NamedTuple**: Reconstructs NamedTuple without the `:value` key
- **Dict**: Creates new Dict excluding both `:value` and `"value"` keys

# Example
```julia-repl
julia> using CTBenchmarks

julia> bench_nt = (time=0.001, alloc=1024, value=42)
(time = 0.001, alloc = 1024, value = 42)

julia> CTBenchmarks.strip_benchmark_value(bench_nt)
(time = 0.001, alloc = 1024)

julia> bench_dict = Dict("time" => 0.001, "value" => 42)
Dict{String, Float64} with 2 entries:
  "time"  => 0.001
  "value" => 42

julia> CTBenchmarks.strip_benchmark_value(bench_dict)
Dict{String, Float64} with 1 entry:
  "time" => 0.001
```
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
    $(TYPEDSIGNATURES)

Solve an optimal control problem and extract performance and solver statistics.

This internal helper function orchestrates the solve process for different model types
(JuMP, adnlp, exa, exa_gpu) and captures timing, memory, and solver statistics. It
handles error cases gracefully by returning missing values instead of propagating exceptions.

# Arguments
- `problem::Symbol`: problem name (e.g., `:beam`, `:chain`)
- `solver::Symbol`: solver to use (`:ipopt` or `:madnlp`)
- `model::Symbol`: model type (`:jump`, `:adnlp`, `:exa`, or `:exa_gpu`)
- `grid_size::Int`: number of grid points
- `disc_method::Symbol`: discretization method (`:trapeze` or `:midpoint`)
- `tol::Float64`: solver tolerance
- `mu_strategy::Union{String, Missing}`: mu strategy for Ipopt (missing for MadNLP)
- `print_trace::Bool`: whether to emit detailed solver output
- `max_iter::Int`: maximum number of iterations
- `max_wall_time::Float64`: maximum wall time in seconds

# Returns
A NamedTuple with fields:
- `benchmark`: full benchmark object from `@btimed` (CPU) or `CUDA.@timed` (GPU)
- `objective::Union{Float64, Missing}`: objective function value (missing if failed)
- `iterations::Union{Int, Missing}`: number of solver iterations (missing if failed)
- `status::Any`: termination status (type depends on solver/model)
- `success::Bool`: whether the solve succeeded
- `criterion::Union{String, Missing}`: optimization sense (`"min"` or `"max"`, missing if failed)
- `solution::Union{Any, Missing}`: the solution object (JuMP model or OCP solution, missing if failed)

# Details

**Model-specific logic**:
- **JuMP** (`:jump`): Uses `@btimed` for CPU benchmarking, requires `:trapeze` discretization
- **GPU** (`:exa_gpu`): Uses `CUDA.@timed` for GPU benchmarking, requires MadNLP solver and functional CUDA
- **OptimalControl** (`:adnlp`, `:exa`): Uses `@btimed` for CPU benchmarking with OptimalControl backend

**Solver configuration**:
- **Ipopt**: Configured with MUMPS linear solver, mu strategy, and second-order barrier
- **MadNLP**: Configured with MUMPS linear solver

**Print level adjustment**: The solver print level is reduced after the first iteration to avoid
excessive output during benchmarking (controlled by the `ITERATION` counter).

**Error handling**: If any solve fails, returns a NamedTuple with `success=false` and missing
values for objective, iterations, and solution, allowing batch processing to continue.

# Throws
- `AssertionError`: If GPU model is used without MadNLP, without functional CUDA, if JuMP model
  uses non-trapeze discretization, or if Ipopt is used without mu_strategy.
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
            )
        end
    end
end

"""
    $(TYPEDSIGNATURES)

Check whether CUDA is available and functional on this machine.

This function is used to decide whether GPU-based models (those whose name ends
with `_gpu`) can be run in the benchmark suite.

# Returns
- `Bool`: `true` if CUDA is functional, `false` otherwise.

# Example
```julia-repl
julia> using CTBenchmarks

julia> CTBenchmarks.is_cuda_on()
false
```
"""
is_cuda_on() = CUDA.functional()

"""
    $(TYPEDSIGNATURES)

Filter solver models depending on backend availability and discretization support.

- GPU models (ending with `_gpu`) are kept only if CUDA is available.
- JuMP models are kept only when `disc_method == :trapeze`.

# Arguments
- `models::Vector{Symbol}`: Candidate model types (e.g. `[:jump, :adnlp, :exa, :exa_gpu]`)
- `disc_method::Symbol`: Discretization method (`:trapeze` or `:midpoint`)

# Returns
- `Vector{Symbol}`: Filtered list of models that are compatible with the current
  backend configuration.

# Example
```julia-repl
julia> using CTBenchmarks

julia> CTBenchmarks.filter_models_for_backend([:jump, :exa, :exa_gpu], :trapeze)
3-element Vector{Symbol}:
 :jump
 :exa
 :exa_gpu
```
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
    $(TYPEDSIGNATURES)

Set print level based on solver and `print_trace` flag.

For Ipopt, this returns an integer verbosity level. For MadNLP, it returns a
`MadNLP.LogLevels` value. The flag `print_trace` is typically propagated from
high-level benchmarking options.

# Arguments
- `solver::Symbol`: Solver name (`:ipopt` or `:madnlp`)
- `print_trace::Bool`: Whether detailed solver output should be printed

# Returns
- `Int` or `MadNLP.LogLevels`: Print level appropriate for the chosen solver

# Example
```julia-repl
julia> using CTBenchmarks

julia> CTBenchmarks.set_print_level(:ipopt, true)
5

julia> CTBenchmarks.set_print_level(:madnlp, false)
MadNLP.ERROR
```
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
    $(TYPEDSIGNATURES)

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
- `max_iter`: Int - maximum number of iterations
- `max_wall_time`: Float64 - maximum wall time in seconds
- `benchmark`: NamedTuple - full benchmark object from @btimed or CUDA.@timed
- `objective`: Union{Float64, Missing} - objective function value (missing if failed)
- `iterations`: Union{Int, Missing} - number of solver iterations (missing if failed)
- `status`: Any - termination status (type depends on solver/model)
- `success`: Bool - whether the solve succeeded
- `criterion`: Union{String, Missing} - optimization sense ("min" or "max", missing if failed)
- `solution`: Any - underlying solution object (JuMP model or OptimalControl solution)
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
                    print_benchmark_line(model, disc_method, stats)

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
    $(TYPEDSIGNATURES)

Collect metadata about the current Julia environment for benchmark reproducibility.

The returned dictionary includes a timestamp, Julia version, OS and machine information,
as well as textual snapshots of the package environment.

# Returns
- `Dict{String,String}`: Dictionary with keys
  - `"timestamp"`: Current time in UTC (ISO8601-like formatting)
  - `"julia_version"`: Julia version string
  - `"os"`: Kernel/OS identifier
  - `"machine"`: Hostname of the current machine
  - `"pkg_status"`: Output of `Pkg.status()` with ANSI colours
  - `"versioninfo"`: Output of `versioninfo()` with ANSI colours
  - `"pkg_manifest"`: Output of `Pkg.status(mode=PKGMODE_MANIFEST)` with ANSI colours

# Example
```julia-repl
julia> using CTBenchmarks

julia> meta = CTBenchmarks.generate_metadata()
Dict{String, String} with 7 entries:
  "timestamp"     => "2025-11-15 18:30:00 UTC"
  "julia_version" => "1.10.0"
  "os"            => "Linux"
  ⋮
```
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
    $(TYPEDSIGNATURES)

Combine benchmark results, metadata, and configuration into a JSON-friendly payload.

The results `DataFrame` is converted to a vector of dictionaries (one per row) for easy
JSON serialisation and reconstruction. Solutions are extracted and kept in memory (not
serialised to JSON) for later plot generation.

# Arguments
- `results::DataFrame`: Benchmark results table produced by `benchmark_data`
- `meta::Dict`: Environment metadata produced by `generate_metadata`
- `config::Dict`: Configuration describing the benchmark run (problems, solvers, grids, etc.)

# Returns
- `Dict`: Payload with three keys:
  - `"metadata"` – merged metadata and configuration
  - `"results"` – vector of row dictionaries obtained from `results`
  - `"solutions"` – vector of solution objects (kept in memory only)

# Example
```julia-repl
julia> using CTBenchmarks

julia> payload = CTBenchmarks.build_payload(results, meta, config)
Dict{String, Any} with 3 entries:
  "metadata"  => Dict{String, Any}(...)
  "results"   => Vector{Dict}(...)
  "solutions" => Any[...]
```
"""
function build_payload(results::DataFrame, meta::Dict, config::Dict)
    # Extract solutions BEFORE conversion to JSON
    solutions = results.solution

    # Create a copy of DataFrame WITHOUT solution column
    results_for_json = select(results, Not(:solution))

    # Convert DataFrame to vector of dictionaries using Tables.jl interface
    # This preserves all column names and types automatically
    results_vec = [Dict(pairs(row)) for row in Tables.rows(results_for_json)]

    # Add configuration to metadata
    meta_with_config = merge(meta, Dict("configuration" => config))

    Dict(
        "metadata" => meta_with_config,
        "results" => results_vec,
        "solutions" => solutions,  # Kept in memory, not in JSON
    )
end

"""
    $(TYPEDSIGNATURES)

Save a JSON payload to a file. Creates the parent directory if needed and uses
pretty printing for readability.

The `payload` is typically produced by `build_payload`. The `"solutions"` entry is
excluded from serialisation so that the JSON contains only metadata and results.

# Arguments
- `payload::Dict`: Benchmark results with metadata
- `filepath::AbstractString`: Full path to the output JSON file (including filename)

# Returns
- `Nothing`: Writes the JSON file as a side effect.

# Example
```julia-repl
julia> using CTBenchmarks

julia> payload = CTBenchmarks.build_payload(results, meta, config)

julia> CTBenchmarks.save_json(payload, "benchmarks.json")
```
"""
function save_json(payload::Dict, filepath::AbstractString)
    mkpath(dirname(filepath))

    # Filter out solutions before JSON serialization
    json_payload = Dict(k => v for (k, v) in payload if k != "solutions")

    open(filepath, "w") do io
        JSON.print(io, json_payload, 4)    # pretty printed with 4-space indent
        write(io, '\n')            # add trailing newline
    end
end

# ------------------------------
# Public API
# ------------------------------

"""
    $(TYPEDSIGNATURES)

Run benchmarks on optimal control problems and build a JSON-ready payload.

This function performs the following steps:
1. Detects CUDA availability and filters out :exa_gpu if CUDA is not functional
2. Runs benchmarks using `benchmark_data()` to generate a DataFrame of results
3. Collects environment metadata (Julia version, OS, machine, timestamp)
4. Builds a JSON-friendly payload combining results and metadata
5. Returns the payload as a `Dict`

The JSON file can be easily loaded and converted back to a DataFrame using:
```julia
using JSON, DataFrames
data = JSON.parsefile("path/to/data.json")
df = DataFrame(data["results"])
```

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
- `Dict`

# Example
```julia-repl
julia> using CTBenchmarks

julia> payload = CTBenchmarks.benchmark(
           problems = [:beam],
           solver_models = [:ipopt => [:jump]],
           grid_sizes = [100],
           disc_methods = [:trapeze],
           tol = 1e-6,
           ipopt_mu_strategy = "adaptive",
           print_trace = false,
           max_iter = 1000,
           max_wall_time = 60.0,
       )
Dict{String, Any} with 3 entries:
  "metadata"  => Dict{String, Any}(...)
  "results"   => Vector{Dict}(...)
  "solutions" => Any[...]
```
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
