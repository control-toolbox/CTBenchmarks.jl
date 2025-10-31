"""
Run the benchmarks for a specific version.

# Arguments
- `version::Symbol`: version to run (:complete or :minimal)
- `outpath::Union{AbstractString, Nothing}`: directory path to save results (nothing for no saving)
- `print_trace::Bool`: whether to print the trace of the solver

# Returns
- `nothing`
"""
function run(
    version::Symbol=:complete;
    outpath::Union{AbstractString,Nothing}=nothing,
    print_trace::Bool=false,
)
    if version == :complete
        CTBenchmarks.benchmark(;
            outpath=outpath,
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
        CTBenchmarks.benchmark(;
            outpath=outpath,
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
    return nothing
end
