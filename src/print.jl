"""
    $(TYPEDSIGNATURES)

Format a duration `t` expressed in **seconds** into a human-readable string with
three decimal places and adaptive units (ns, μs, ms, s).

The function automatically selects the most appropriate unit based on the magnitude
of the input value, ensuring readable output across a wide range of timescales.

# Arguments
- `t::Real`: Duration in seconds (can be positive or negative)

# Returns
- `String`: Formatted time string with three decimal places and unit suffix

# Example
```julia-repl
julia> using CTBenchmarks

julia> CTBenchmarks.prettytime(0.001234)
"1.234 ms"

julia> CTBenchmarks.prettytime(1.5)
"1.500 s "

julia> CTBenchmarks.prettytime(5.6e-7)
"560.000 ns"
```
"""
function prettytime(t)
    t_abs = abs(t)
    if t_abs < 1e-6
        value, units = t * 1e9, "ns"
    elseif t_abs < 1e-3
        value, units = t * 1e6, "μs"
    elseif t_abs < 1
        value, units = t * 1e3, "ms"
    else
        value, units = t, "s "
    end
    return string(@sprintf("%.3f", value), " ", units)
end

"""
    $(TYPEDSIGNATURES)

Format a memory footprint `bytes` into a human-readable string using binary
prefixes (bytes, KiB, MiB, GiB) with two decimal places.

The function uses standard binary units (1024 bytes = 1 KiB) and automatically
selects the most appropriate unit based on the magnitude of the input value.

# Arguments
- `bytes::Integer`: Memory size in bytes (must be non-negative)

# Returns
- `String`: Formatted memory string with two decimal places and unit suffix

# Example
```julia-repl
julia> using CTBenchmarks

julia> CTBenchmarks.prettymemory(512)
"512 bytes"

julia> CTBenchmarks.prettymemory(1048576)
"1.00 MiB"

julia> CTBenchmarks.prettymemory(2147483648)
"2.00 GiB"
```
"""
function prettymemory(b)
    if b < 1024
        return string(b, " bytes")
    elseif b < 1024^2
        value, units = b / 1024, "KiB"
    elseif b < 1024^3
        value, units = b / 1024^2, "MiB"
    else
        value, units = b / 1024^3, "GiB"
    end
    return string(@sprintf("%.2f", value), " ", units)
end

"""
    $(TYPEDSIGNATURES)

Print a formatted line summarizing benchmark statistics for `model` with colors.

This function formats and displays benchmark results in a human-readable table row,
including execution time, memory usage, solver objective value, iteration count,
and success status. It automatically detects and handles both CPU benchmarks
(from `@btimed`) and GPU benchmarks (from `CUDA.@timed`).

# Arguments
- `model::Symbol`: Name of the model being benchmarked (e.g., `:jump`, `:adnlp`)
- `stats::NamedTuple`: Statistics dictionary containing:
  - `benchmark`: Timing and memory data (Dict or NamedTuple) with fields:
    - `:time`: Execution time in seconds
    - `:bytes` or `:cpu_bytes`, `:gpu_bytes`: Memory allocation
  - `objective`: Solver objective value (or `missing`)
  - `iterations`: Number of solver iterations (or `missing`)
  - `success`: Boolean indicating successful completion
  - `criterion`: Optimization criterion (e.g., `:min`, `:max`) or `missing`
  - `status`: Error message (used when benchmark is missing)

# Output
Prints a colored, formatted line to stdout with:
- Success indicator (✓ in green or ✗ in red)
- Model name in magenta
- Formatted execution time
- Iteration count
- Objective value in scientific notation
- Criterion type
- Memory usage (CPU and/or GPU)

# Example
```julia-repl
julia> using CTBenchmarks

julia> stats = (
           benchmark = (time = 0.123, bytes = 1048576),
           objective = 42.5,
           iterations = 100,
           success = true,
           criterion = :min
       )

julia> CTBenchmarks.print_benchmark_line(:jump, stats)
  ✓ | jump     | time:      0.123 s  | iters:   100 | obj: 4.250000e+01 (min) | CPU:       1.00 MiB
```
"""
function print_benchmark_line(model::Symbol, stats::NamedTuple)
    bench = stats.benchmark

    # Handle error cases where benchmark is missing or nothing
    if ismissing(bench) || isnothing(bench)
        error_msg = haskey(stats, :status) ? stats.status : "ERROR"
        # Print with colored model name
        printstyled("  ✗ | "; color=:red, bold=true)
        printstyled(rpad(string(model), 8); color=:magenta, bold=true)
        println(": $error_msg")
        return nothing
    end

    # Helper function to get value from either Dict or NamedTuple
    function getval(obj, key::Symbol)
        if isa(obj, Dict)
            return get(obj, string(key), get(obj, key, nothing))
        else
            return getproperty(obj, key)
        end
    end

    # Check if this is a CUDA.@timed result (has cpu_bytes and gpu_bytes)
    has_cpu_bytes =
        (isa(bench, Dict) && (haskey(bench, "cpu_bytes") || haskey(bench, :cpu_bytes))) ||
        (!isa(bench, Dict) && haskey(bench, :cpu_bytes))
    has_gpu_bytes =
        (isa(bench, Dict) && (haskey(bench, "gpu_bytes") || haskey(bench, :gpu_bytes))) ||
        (!isa(bench, Dict) && haskey(bench, :gpu_bytes))

    # Extract timing and memory info
    time_val = getval(bench, :time)
    time_str = lpad(prettytime(time_val), 10)

    # Build memory string with CPU/GPU labels
    if has_cpu_bytes && has_gpu_bytes
        cpu_bytes = getval(bench, :cpu_bytes)
        cpu_mem_str = lpad(Base.format_bytes(cpu_bytes), 10)

        gpu_bytes = getval(bench, :gpu_bytes)
        gpu_mem_str = lpad(Base.format_bytes(gpu_bytes), 10)

        memory_display = "CPU: $cpu_mem_str | GPU: $gpu_mem_str"
    else
        bytes_val = getval(bench, :bytes)
        memory_str = lpad(prettymemory(bytes_val), 10)

        memory_display = "CPU: $memory_str" * " " ^ 18
    end

    # Format solver statistics with fixed widths
    obj_str = if ismissing(stats.objective)
        rpad("N/A", 13)
    else
        rpad(@sprintf("%.6e", stats.objective), 13)
    end
    iter_str =
        ismissing(stats.iterations) ? rpad("N/A", 5) : rpad(string(stats.iterations), 5)

    # Format criterion (min/max)
    criterion_str = if haskey(stats, :criterion) && !ismissing(stats.criterion)
        rpad(stats.criterion, 3)
    else
        rpad("N/A", 3)
    end

    # Print with colored elements
    if stats.success
        printstyled("  ✓"; color=:green, bold=true)
    else
        printstyled("  ✗"; color=:red, bold=true)
    end

    print(" | ")
    printstyled(rpad(string(model), 8); color=:magenta, bold=true)
    println(
        " | time: $time_str | iters: $iter_str | obj: $obj_str ($criterion_str) | $memory_display",
    )
end
