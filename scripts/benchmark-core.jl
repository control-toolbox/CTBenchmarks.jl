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

function main(; runner::String="local", grid_sizes::Vector{Int} = [200], grid_size_max_cpu::Int = typemax(Int))
    outpath=joinpath(project_dir, "docs", "src", "assets", "benchmark-core" * (runner == "local" ? "" : "-" * runner))
    CTBenchmarks.benchmark(;
        outpath=outpath,
        problems = [
            :beam,
            # :chain,
            # :double_oscillator,
            # :ducted_fan,
            # :electric_vehicle,
            # :glider,
            # :insurance,
            # :jackson,
            # :robbins,
            # :robot,
            # :rocket,
            # :space_shuttle,
            # :steering,
            # :vanderpol,
        ],
        solver_models = [
            :ipopt => [:JuMP, :adnlp, :exa],
            :madnlp => [:JuMP, :adnlp, :exa, :exa_gpu]
        ],
        grid_sizes = grid_sizes,
        disc_methods = [:trapeze],
        tol = 1e-8,
        ipopt_mu_strategy = "adaptive",
        ipopt_print_level = 0,
        madnlp_print_level = MadNLP.ERROR,
        max_iter = 1000,
        max_wall_time = 500.0,
        grid_size_max_cpu = grid_size_max_cpu  # CPU models won't run for grid_size > grid_size_max_cpu
    )
    println("✅ Benchmark completed successfully!")
    return outpath
end