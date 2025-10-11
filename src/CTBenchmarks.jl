module CTBenchmarks

using Dates
using JSON
using InteractiveUtils
using Sockets

include("benchmark-minimal.jl")
include("mini.jl")

export benchmark_minimal, benchmark_minimal_data

end # module