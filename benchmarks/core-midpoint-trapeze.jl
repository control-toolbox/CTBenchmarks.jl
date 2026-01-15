# Modeler: :exa

function run()
    results = CTBenchmarks.benchmark(;
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

        # solver × modeler
        solver_models=[:madnlp => [:exa], :ipopt => [:exa]],
        disc_methods=[:trapeze, :midpoint],
        grid_sizes=[200],
        tol=1e-8,
        ipopt_mu_strategy="adaptive",
        print_trace=false,
        max_iter=2000,
        max_wall_time=600.0,
    )
    println("✅ Benchmark midpoint vs trapeze completed successfully!")
    return results
end
