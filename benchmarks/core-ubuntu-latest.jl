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
        grid_sizes=[100, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 1100, 1200, 1300, 1400, 1500, 1600, 1700, 1800, 1900, 2000, 2100, 2200, 2300, 2400, 2500, 2600, 2700, 2800, 2900, 3000, 3100, 3200, 3300, 3400, 3500, 3600, 3700, 3800, 3900, 4000, 4100, 4200, 4300, 4400, 4500, 4600, 4700, 4800, 4900, 5000],
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
