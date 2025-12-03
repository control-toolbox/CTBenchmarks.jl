# Benchmark script for core-midpoint
# Setup (Pkg.activate, instantiate, update, using CTBenchmarks) is handled by the workflow

function run()
    results = CTBenchmarks.benchmark(;
        problems=[
            :beam,
            :chain,
            :double_oscillator,
            # :ducted_fan,
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
        solver_models=[:ipopt => [:adnlp, :exa], :madnlp => [:adnlp, :exa]],
        grid_sizes = [200, 500, 1000, 2000],
        disc_methods = [:midpoint],
        tol = 1e-8,
        ipopt_mu_strategy = "adaptive",
        print_trace = false,
        max_iter = 1000,
        max_wall_time = 500.0
    )
    println("✅ Benchmark completed successfully!")
    return results
end