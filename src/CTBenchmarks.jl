module CTBenchmarks

using Dates
using JSON
using InteractiveUtils
using Sockets

greet() = print("Hello World!")

export benchmark_minimal

"""
    benchmark_minimal(; outpath::AbstractString = joinpath(normpath(@__DIR__, ".."), "benchmarks", "minimal.json"))

Run a minimal, placeholder benchmark and save results to a JSON file.

This is a stub that records a couple of toy problems with arbitrary times, and
captures metadata about the Julia version and machine.
"""
function benchmark_minimal(; outpath::AbstractString = joinpath(normpath(@__DIR__, ".."), "benchmarks", "minimal.json"))
    # Ensure output directory exists
    mkpath(dirname(outpath))

    # Dummy results (can be extended later)
    results = [
        (; problem = Symbol("toy_problem_1"), time = 0.123),
        (; problem = Symbol("toy_problem_2"), time = 0.456),
    ]

    # Metadata about environment
    meta = Dict(
        "timestamp" => Dates.format(Dates.now(), dateformat"yyyy-mm-ddTHH:MM:SSZ"),
        "julia_version" => string(VERSION),
        "os" => Sys.KERNEL,
        "machine" => gethostname(),
    )

    # JSON friendly structure
    payload = Dict(
        "metadata" => meta,
        "results" => [Dict("problem" => String(r.problem), "time" => r.time) for r in results],
    )

    # Save JSON
    open(outpath, "w") do io
        JSON.print(io, payload; indent = 2)
    end

    return outpath
end

end
