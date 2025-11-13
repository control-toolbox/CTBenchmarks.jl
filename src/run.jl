"""
Run the benchmarks for a specific version.

# Arguments
- `version::Symbol`: version to run (:complete or :minimal)
- `filepath::Union{AbstractString, Nothing}`: optional path to the JSON file where results
  should be saved. When provided, it must end with `.json`.
- `print_trace::Bool`: whether to print the trace of the solver

# Returns
- `Dict` containing benchmark results and metadata
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
                :ipopt => [:JuMP, :adnlp, :exa], :madnlp => [:JuMP, :adnlp, :exa, :exa_gpu]
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
                :ipopt => [:JuMP, :adnlp, :exa], :madnlp => [:JuMP, :adnlp, :exa, :exa_gpu]
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
