# ------------------------------
# Internal helper functions
# ------------------------------

"""
    generate_dummy_results() -> Vector{NamedTuple}

Return a minimal set of placeholder benchmark results.

Each result is a NamedTuple with:
- `problem::Symbol`: name of the toy problem
- `time::Float64`: arbitrary execution time
"""
function generate_dummy_results()
    [
        (; problem = :toy_problem_1, time = 0.123),
        (; problem = :toy_problem_2, time = 0.456),
    ]
end

"""
    generate_metadata() -> Dict{String, String}

Return metadata about the current environment:
- `timestamp` (UTC, ISO8601)
- `julia_version`
- `os`
- `machine` hostname
"""
function generate_metadata()
    Dict(
        "timestamp" => Dates.format(Dates.now(), dateformat"yyyy-mm-ddTHH:MM:SSZ"),
        "julia_version" => string(VERSION),
        "os" => Sys.KERNEL,
        "machine" => gethostname(),
    )
end

"""
    build_payload(results::Vector{NamedTuple}, meta::Dict) -> Dict

Combine benchmark results and metadata into a JSON-friendly dictionary.
"""
function build_payload(results::Vector{<:NamedTuple}, meta::Dict)
    Dict(
        "metadata" => meta,
        "results" => [Dict("problem" => String(r.problem), "time" => r.time) for r in results],
    )
end

"""
    save_json(payload::Dict, outpath::AbstractString)

Save a JSON payload to a file. Creates the parent directory if needed.
Uses pretty printing for readability.
"""
function save_json(payload::Dict, outpath::AbstractString)
    mkpath(dirname(outpath))
    open(outpath, "w") do io
        JSON.print(io, payload)    # pretty printed, multi-line
        write(io, '\n')            # add trailing newline
    end
end

# ------------------------------
# Public API
# ------------------------------

"""
    benchmark_minimal(; outpath::AbstractString = joinpath(normpath(@__DIR__, ".."), "docs", "src", "assets", "benchmark-minimal", "data.json")) -> String

Run a minimal placeholder benchmark and save results to a JSON file.

This function performs the following steps:
1. Generates dummy benchmark results.
2. Collects environment metadata (Julia version, OS, machine, timestamp).
3. Builds a JSON-friendly payload combining results and metadata.
4. Saves the payload to `outpath` as pretty-printed JSON.

# Arguments
- `outpath`: path to save the JSON file (default: `docs/src/assets/benchmark-minimal/data.json` relative to package root)

# Returns
- The `outpath` of the saved JSON file.
"""
function benchmark_minimal(; outpath::AbstractString = joinpath(normpath(@__DIR__, ".."), "docs", "src", "assets", "benchmark-minimal", "data.json"))    
    results = generate_dummy_results()
    meta = generate_metadata()
    payload = build_payload(results, meta)
    save_json(payload, outpath)
    return outpath
end