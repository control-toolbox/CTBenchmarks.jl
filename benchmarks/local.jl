# Local testing script for CTBenchmarks
# This script includes the setup code that is handled by the GitHub workflow in CI
# Use this as a template for running benchmarks locally

try
    using Revise
catch
    @warn "Revise not available, continuing without it"
end

using Pkg
const project_dir = normpath(@__DIR__, "..")
ENV["PROJECT"] = project_dir

println("📦 Activating project environment...")
Pkg.activate(project_dir)

println("📥 Installing dependencies...")
Pkg.instantiate()

println("🔄 Updating dependencies...")
Pkg.update()

println("🔄 Loading CTBenchmarks package...")
using CTBenchmarks

println("⏱️  Ready to run core benchmark...")
CTBenchmarks.run(:minimal; print_trace=false) # or :complete

# To run a specific benchmark script locally, you can also do:
# include("core-moonshot-cpu.jl")
# run()
