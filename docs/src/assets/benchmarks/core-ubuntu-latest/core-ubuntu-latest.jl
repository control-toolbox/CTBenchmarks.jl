# Benchmark script for core-ubuntu-latest
# Setup (Pkg.activate, instantiate, update, using CTBenchmarks) is handled by the workflow

function run()
    results = CTBenchmarks.benchmark(;
        problems=[
            :bryson_denham,
            :robertson,
            
        ],
        solver_models=[:ipopt => [:jump, :adnlp, :exa], :madnlp => [:jump, :adnlp, :exa]],
        grid_sizes=[200, 500, 1000, 2000],
        disc_methods=[:trapeze],
        tol=1e-8,
        ipopt_mu_strategy="adaptive",
        print_trace=false,
        max_iter=1000,
        max_wall_time=500.0,
    )
    println("✅ Benchmark completed successfully!")
    return results
end
