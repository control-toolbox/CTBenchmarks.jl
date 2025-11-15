"""
    run(version::Symbol=:complete; filepath=nothing, print_trace=false)

Run comprehensive benchmarks on optimal control problems with various solvers and discretization methods.

This function executes a predefined benchmark suite that evaluates the performance of different 
optimal control solvers (Ipopt, MadNLP) across multiple models (JuMP, ADNLP, Exa, Exa-GPU) and 
problems. Results are collected in a structured dictionary and optionally saved to JSON.

# Arguments
- `version::Symbol`: Benchmark suite version to run (default: `:complete`)
  - `:complete`: Full suite with 14 problems, multiple grid sizes (100, 200, 500), and two discretization methods
  - `:minimal`: Quick suite with only the beam problem and grid size 100 (useful for testing)
- `filepath::Union{AbstractString, Nothing}`: Optional path to save results as JSON file (must end with `.json`). 
  If `nothing`, results are only returned in memory.
- `print_trace::Bool`: Whether to print solver trace information during execution (default: `false`)

# Returns
- `Dict`: Benchmark results containing timing data, solver statistics, and metadata for each problem-solver-model combination

# Throws
- `CTBase.IncorrectArgument`: If `filepath` is provided but does not end with `.json`
- `ErrorException`: If `version` is neither `:complete` nor `:minimal`

# Example
```julia-repl
julia> using CTBenchmarks

julia> # Run minimal benchmark and save results
julia> results = run(:minimal; filepath="results.json")

julia> # Run complete benchmark without saving
julia> results = run(:complete)

julia> # Run with solver trace output
julia> results = run(:minimal; print_trace=true)
```

# See Also
- [`benchmark`](@ref): Core benchmarking function with full customization
"""
function run(
    version::Symbol=:complete;
    filepath::Union{AbstractString,Nothing}=nothing,
    print_trace::Bool=false,
)
    if filepath !== nothing && !endswith(lowercase(filepath), ".json")
        throw(CTBase.IncorrectArgument(
            "The file path provided to run() must end with .json (got: $filepath)",
        ))
    end

    results = if version == :complete
        benchmark(;
            problems=[
                :beam,
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
                :vanderpol,
            ],
            solver_models=[
                :ipopt => [:jump, :adnlp, :exa], :madnlp => [:jump, :adnlp, :exa, :exa_gpu]
            ],
            grid_sizes=[100, 200, 500],
            disc_methods=[:trapeze, :midpoint],
            tol=1e-6,
            ipopt_mu_strategy="adaptive",
            print_trace=print_trace,
            max_iter=1000,
            max_wall_time=500.0,
        )
    elseif version == :minimal
        benchmark(;
            problems=[:beam],
            solver_models=[
                :ipopt => [:jump, :adnlp, :exa], :madnlp => [:jump, :adnlp, :exa, :exa_gpu]
            ],
            grid_sizes=[100],
            disc_methods=[:trapeze],
            tol=1e-6,
            ipopt_mu_strategy="adaptive",
            print_trace=print_trace,
            max_iter=1000,
            max_wall_time=500.0,
        )
    else
        error("undefined version: $version. Please choose :complete or :minimal.")
    end

    if filepath !== nothing
        println("💾 Saving benchmark results to $filepath")
        save_json(results, filepath)
    end

    return results
end
