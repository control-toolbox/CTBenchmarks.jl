# Core benchmark

This page attempts to read the core benchmark results from `docs/assets/benchmark-core/data.json` at the root of the repository.
If the file is not present (e.g., benchmarks were not run yet), a message will be displayed.

```@setup bench
using JSON
using DataFrames
using Markdown
using Dates

function _read_benchmark_json(path::AbstractString)
    if !isfile(path)
        return nothing
    end
    open(path, "r") do io
        return JSON.parse(io)
    end
end

const _BENCH_PATH = joinpath(@__DIR__, "assets", "benchmark-core", "data.json")
bench_data = _read_benchmark_json(_BENCH_PATH)
```

## Experiment setup

```@example bench
if bench_data === nothing
    println("No benchmark file found at: $_BENCH_PATH")
else
    meta = get(bench_data, "metadata", Dict())
    println("Timestamp: ", get(meta, "timestamp", "n/a"))
    println("Julia version: ", get(meta, "julia_version", "n/a"))
    println("OS: ", get(meta, "os", "n/a"))
    println("Machine: ", get(meta, "machine", "n/a"))
end
nothing # hide
```

## Results

```@example bench
if bench_data === nothing
    println("No results to display because the benchmark file is missing.")
else
    rows = get(bench_data, "results", Any[])
    if isempty(rows)
        println("No results recorded in the benchmark file.")
    else
        # Transform into a DataFrame
        df = DataFrame(
            problem = String[],
            time = Float64[],
        )
        for r in rows
            push!(df, (get(r, "problem", ""), parse(Float64, string(get(r, "time", NaN)))))
        end
        println(df)
    end
end
nothing # hide
```