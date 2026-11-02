# Benchmark script for core-kkt-gpu
# Setup (Pkg.activate, instantiate, update, using CTBenchmarks) is handled by the workflow

function run()
    results = CTBenchmarks.benchmark(;
        solver_models=[:madnlp => [:exa, :exa_gpu]],
        grid_sizes=[1000, 5000, 10000, 20000],
        disc_methods=[:midpoint],
        tol=1e-8,
        ipopt_mu_strategy="adaptive",
        print_trace=false,
        max_iter=1000,
        max_wall_time=2000.0, # updated from 1000 to 2000 for large grid_size's
    )
    println("✅ Benchmark completed successfully!")
    return results
end
