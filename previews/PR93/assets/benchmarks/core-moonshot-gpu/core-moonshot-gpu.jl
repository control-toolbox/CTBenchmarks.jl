# Benchmark script for core-moonshot-gpu
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
        solver_models=[:madnlp => [:exa, :exa_gpu]],
        grid_sizes=[1000, 5000, 10000, 20000],
        disc_methods=[:trapeze],
        tol=1e-6,
        ipopt_mu_strategy="adaptive",
        print_trace=false,
        max_iter=1000,
        max_wall_time=1000.0,
    )
    println("✅ Benchmark completed successfully!")
    return results
end
