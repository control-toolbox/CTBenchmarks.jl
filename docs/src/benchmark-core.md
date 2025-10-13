# Core benchmark

This page displays the core benchmark results from `docs/src/assets/benchmark-core-ubuntu-cpu/data.json`.

```@setup bench
using CTBenchmarks
using JSON
using DataFrames
using Markdown
using Dates
using TOML
using Printf

function _read_benchmark_json(path::AbstractString)
    if !isfile(path)
        return nothing
    end
    open(path, "r") do io
        return JSON.parse(io)
    end
end

# Benchmark directory name (reusable for paths and links)
const BENCH_DIR = "benchmark-core-ubuntu-cpu"
const _BENCH_PATH = joinpath(@__DIR__, "assets", BENCH_DIR, "data.json")
bench_data = _read_benchmark_json(_BENCH_PATH)
```

## Benchmark environment

```@example bench
function _basic_metadata() # hide
    if bench_data !== nothing # hide
        meta = get(bench_data, "metadata", Dict()) # hide
        for (label, key) in ( # hide
            ("📅 Timestamp", "timestamp"), # hide
            ("🔧 Julia version", "julia_version"), # hide
            ("💻 OS", "os"), # hide
            ("🖥️ Machine", "machine"), # hide
        ) # hide
            value = string(get(meta, key, "n/a")) # hide
            println(rpad(label, key=="machine" ? 16 : 17), ": ", value) # hide
        end # hide
    else # hide
        println("⚠️  No benchmark data available") # hide
    end # hide
end # hide
nothing # hide
```

```@example bench
_basic_metadata() # hide
```

```@eval
using TOML
using Markdown

# Benchmark directory name
BENCH_DIR = "benchmark-core"

# Read package metadata
version = TOML.parse(read("../../Project.toml", String))["version"]
name = TOML.parse(read("../../Project.toml", String))["name"]

# Build download links using joinpath for correct path construction
base_url = "https://github.com/control-toolbox/" * name * ".jl/tree/gh-pages/v" * version
link_manifest = joinpath(base_url, "assets", BENCH_DIR, "Manifest.toml")
link_project = joinpath(base_url, "assets", BENCH_DIR, "Project.toml")

Markdown.parse("""
You can download the exact environment used for this benchmark:
- 📦 [Project.toml]($link_project) - Package dependencies
- 📋 [Manifest.toml]($link_manifest) - Complete dependency tree with versions

These files allow you to reproduce the benchmark environment exactly.
More infos below.
""")
```

```@raw html
<details style="margin-bottom: 0.5em;"><summary>ℹ️ Version info</summary>
```

```@example bench
function _bench_data() # hide
    if bench_data !== nothing # hide
        meta = get(bench_data, "metadata", Dict()) # hide
        versioninfo_text = get(meta, "versioninfo", "No version info available") # hide
        println(versioninfo_text) # hide
    else # hide
        println("⚠️  No benchmark data available") # hide
    end # hide
end # hide
_bench_data() # hide
```

```@raw html
</details>
```

```@raw html
<details style="margin-bottom: 0.5em;"><summary>📦 Package status</summary>
```

```@example bench
function _package_status() # hide
    if bench_data !== nothing # hide
        meta = get(bench_data, "metadata", Dict()) # hide
        pkg_status = get(meta, "pkg_status", "No package status available") # hide
        println(pkg_status) # hide
    else # hide
        println("⚠️  No benchmark data available") # hide
    end # hide
end # hide
_package_status() # hide
```

```@raw html
</details>
```

```@raw html
<details style="margin-bottom: 0.5em;"><summary>📚 Complete manifest</summary>
```

```@example bench
function _complete_manifest() # hide
    if bench_data !== nothing # hide
        meta = get(bench_data, "metadata", Dict()) # hide
        pkg_manifest = get(meta, "pkg_manifest", "No manifest available") # hide
        println(pkg_manifest) # hide
    else # hide
        println("⚠️  No benchmark data available") # hide
    end # hide
end # hide
_complete_manifest() # hide
```

```@raw html
</details>
```

## Results

```@raw html
<details><summary>Click to unfold the results rendering code.</summary>
```

```@example bench
function _print_results(bench_data)
    if bench_data === nothing
        println("⚠️  No results to display because the benchmark file is missing.")
    else
        rows = get(bench_data, "results", Any[])
        if isempty(rows)
            println("⚠️  No results recorded in the benchmark file.")
        else
            println("Benchmarks results:")

            # Convert to DataFrame for easier manipulation
            df = DataFrame(rows)
            
            # Group by problem for structured display
            problems = unique(df.problem)
            
            for problem in problems
                println("\n┌─ problem: $problem")
                println("│")
                
                # Get all rows for this problem
                prob_df = filter(row -> row.problem == problem, df)
                
                # Group by solver and disc_method
                solver_disc_combos = unique([(row.solver, row.disc_method) for row in eachrow(prob_df)])
                
                for (idx, (solver, disc_method)) in enumerate(solver_disc_combos)
                    is_last = (idx == length(solver_disc_combos))
                    
                    println("├──┬ solver: $solver, disc_method: $disc_method")
                    println("│  │")
                    
                    # Filter for this solver/disc_method combination
                    combo_df = filter(row -> row.solver == solver && row.disc_method == disc_method, prob_df)
                    
                    # Group by grid size
                    grid_sizes = unique(combo_df.grid_size)
                    
                    for (grid_idx, N) in enumerate(grid_sizes)
                        println("│  │  N       : $N")
                        
                        # Filter for this grid size
                        grid_df = filter(row -> row.grid_size == N, combo_df)
                        
                        # Display each model with library formatting
                        for row in eachrow(grid_df)
                            # Create a NamedTuple with benchmark data for formatting
                            stats = (benchmark = row.benchmark,)
                            println("│  │", CTBenchmarks.format_benchmark_line(Symbol(row.model), stats))
                        end
                        
                        # Add spacing between grid sizes
                        if grid_idx < length(grid_sizes)
                            println("│  │ ")
                        end
                    end
                    
                    println("│  └─")
                    
                    # Add spacing between solver blocks
                    if !is_last
                        println("│")
                    end
                end
                
                println("└─")
            end
        end
    end
end
nothing # hide
```

```@raw html
</details></br>
```

```@example bench
_print_results(bench_data) # hide
nothing # hide
```
