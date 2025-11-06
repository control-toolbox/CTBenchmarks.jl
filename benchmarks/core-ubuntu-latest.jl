# Benchmark script for core-ubuntu-latest
# Setup (Pkg.activate, instantiate, update, using CTBenchmarks) is handled by the workflow

function main()
    project_dir = normpath(@__DIR__, "..")
    outpath=joinpath(
        project_dir, "docs", "src", "assets", "benchmarks", "core-ubuntu-latest"
    )
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
        solver_models=[:ipopt => [:JuMP, :adnlp, :exa], :madnlp => [:JuMP, :adnlp, :exa]],
        grid_sizes=[200,500,1000,2000,5000],
        disc_methods=[:trapeze],
        tol=1e-6,
        ipopt_mu_strategy="adaptive",
        print_trace=false,
        max_iter=1000,
        max_wall_time=500.0,
    )
    println("✅ Benchmark completed successfully!")
    return outpath
end
