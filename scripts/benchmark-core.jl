using Pkg
println("📦 Activating project environment...")
const project_dir = normpath(@__DIR__, "..")
ENV["PROJECT"] = project_dir
Pkg.activate(project_dir)
println("📥 Installing dependencies...")
Pkg.instantiate()
println("🔄 Loading CTBenchmarks package...")
using CTBenchmarks
using MadNLP
println("⏱️  Running core benchmark...")

function main()
    out = CTBenchmarks.benchmark(;
        outpath=joinpath(
            project_dir, "docs", "src", "assets", "benchmark-core", "data.json"
        ),
        problems = [:beam,
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
                    :vanderpol],
        solvers = [:ipopt, :madnlp],
        models = [:JuMP, :adnlp, :exa],
        grid_sizes = [200],
        disc_methods = [:trapeze],
        tol = 1e-8,
        ipopt_mu_strategy = "adaptive",
        ipopt_print_level = 0,
        madnlp_print_level = MadNLP.ERROR,
        max_iter = 1000,
        max_wall_time = 500.0
    )
    println("✅ Benchmark completed successfully!")
    return out
end