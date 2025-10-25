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
