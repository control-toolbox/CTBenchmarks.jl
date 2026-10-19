# Modeler: adnlp

function run()
    results = CTBenchmarks.benchmark(;
        solver_models=[:madnlp => [:adnlp], :ipopt => [:adnlp]],
        disc_methods=[:midpoint],
        grid_sizes=[250, 500, 1000, 2000],
        tol=1e-8,
        ipopt_mu_strategy="adaptive",
        print_trace=false,
        max_iter=2000,
        max_wall_time=600.0,
    )
    println("✅ Benchmark ipopt vs madnlp completed successfully!")
    return results
end