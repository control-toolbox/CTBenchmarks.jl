if Base.find_package("Revise") !== nothing
    try
        @eval using Revise
        println("🔁 Revise loaded successfully")
    catch err
        println("⚠️  Revise detected but could not be loaded: $(err)")
    end
else
    println("ℹ️  Revise not installed; continuing without it")
end

using Pkg
const project_dir = normpath(@__DIR__, "..")
ENV["PROJECT"] = project_dir

println("📦 Activating project environment...")
Pkg.activate(project_dir)

println("📥 Installing dependencies...")
Pkg.instantiate()

println("🔄 Loading CTBenchmarks package...")
using CTBenchmarks
using MadNLP

println("⏱️  Ready to run core benchmark...")
function main()
    outpath=joinpath(project_dir, "docs", "src", "assets", "benchmark-core-moonshot")
    CTBenchmarks.benchmark(;
        outpath=outpath,
        problems = [
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
        solver_models = [
            :madnlp => [:exa, :exa_gpu]
        ],
        grid_sizes = [1000],
        disc_methods = [:trapeze],
        tol = 1e-6,
        ipopt_mu_strategy = "adaptive",
        ipopt_print_level = 0,
        madnlp_print_level = MadNLP.ERROR,
        max_iter = 1000,
        max_wall_time = 500.0
    )
    println("✅ Benchmark completed successfully!")
    return outpath
end