using Revise

using Pkg
const project_dir = normpath(@__DIR__, "..")
ENV["PROJECT"] = project_dir

println("📦 Activating project environment...")
Pkg.activate(project_dir)

println("📥 Installing dependencies...")
Pkg.instantiate()

println("🔄 Loading CTBenchmarks package...")
using CTBenchmarks

println("⏱️ Ready to run core benchmark...")
CTBenchmarks.run(:minimal; print_trace=false)
#CTBenchmarks.run(:complete; print_trace=false)
