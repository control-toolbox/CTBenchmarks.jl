# prettypercent(p) = string(@sprintf("%.2f", p * 100), "%")

# function prettydiff(p)
#     diff = p - 1.0
#     return string(diff >= 0.0 ? "+" : "", @sprintf("%.2f", diff * 100), "%")
# end

"""
    prettytime(t::Real) -> String

Format a duration `t` expressed in nanoseconds into a human-readable string with
three decimal places and adaptive units (ns, μs, ms, s).
"""
function prettytime(t)
    if t < 1e3
        value, units = t, "ns"
    elseif t < 1e6
        value, units = t / 1e3, "μs"
    elseif t < 1e9
        value, units = t / 1e6, "ms"
    else
        value, units = t / 1e9, "s"
    end
    return string(@sprintf("%.3f", value), " ", units)
end

"""
    prettymemory(bytes::Integer) -> String

Format a memory footprint `bytes` into a human-readable string using binary
prefixes (bytes, KiB, MiB, GiB) with two decimal places.
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
    format_benchmark_line(model::Symbol, stats::NamedTuple) -> String

Build a formatted line summarizing benchmark statistics for `model`.
Handles both CPU benchmarks (from @btimed) and GPU benchmarks (from CUDA.@timed).

For CPU: displays time, allocations count, and memory
For GPU: displays time, CPU allocations/memory, and GPU allocations/memory
"""
function format_benchmark_line(model::Symbol, stats::NamedTuple)
    model_str = rpad(string(model), 8)
    bench = stats.benchmark
    
    # Check if this is a CUDA.@timed result (has cpu_bytes and gpu_bytes)
    if haskey(bench, :cpu_bytes) && haskey(bench, :gpu_bytes)
        # GPU benchmark format
        time_str = @sprintf("%.6f", bench.time)
        cpu_allocs = Base.gc_alloc_count(bench.cpu_gcstats)
        cpu_mem_str = prettymemory(bench.cpu_bytes)
        gpu_allocs = bench.gpu_memstats.alloc_count
        gpu_mem_str = prettymemory(bench.gpu_bytes)
        return "  $model_str: $time_str seconds ($cpu_allocs CPU allocations: $cpu_mem_str) ($gpu_allocs GPU allocation$(gpu_allocs == 1 ? "" : "s"): $gpu_mem_str)"
    else
        # CPU benchmark format (BenchmarkTools @btimed)
        time_str = prettytime(bench.time)
        memory_str = prettymemory(bench.bytes)
        return "  $model_str: $time_str ($(bench.alloc) allocations: $memory_str)"
    end
end