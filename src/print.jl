# prettypercent(p) = string(@sprintf("%.2f", p * 100), "%")

# function prettydiff(p)
#     diff = p - 1.0
#     return string(diff >= 0.0 ? "+" : "", @sprintf("%.2f", diff * 100), "%")
# end

"""
    prettytime(t::Real) -> String

Format a duration `t` expressed in **seconds** into a human-readable string with
three decimal places and adaptive units (ns, μs, ms, s).
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
        value, units = t, "s"
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
    
    # Helper function to get value from either Dict or NamedTuple
    function getval(obj, key::Symbol)
        if isa(obj, Dict)
            return get(obj, string(key), get(obj, key, nothing))
        else
            return getproperty(obj, key)
        end
    end
    
    # Check if this is a CUDA.@timed result (has cpu_bytes and gpu_bytes)
    has_cpu_bytes = (isa(bench, Dict) && (haskey(bench, "cpu_bytes") || haskey(bench, :cpu_bytes))) || 
                    (!isa(bench, Dict) && haskey(bench, :cpu_bytes))
    has_gpu_bytes = (isa(bench, Dict) && (haskey(bench, "gpu_bytes") || haskey(bench, :gpu_bytes))) || 
                    (!isa(bench, Dict) && haskey(bench, :gpu_bytes))
    
    if has_cpu_bytes && has_gpu_bytes
        # GPU benchmark format
        time_val = getval(bench, :time)
        time_str = prettytime(time_val)
        
        cpu_gcstats = getval(bench, :cpu_gcstats)
        if isa(cpu_gcstats, Dict)
            cpu_allocs = get(cpu_gcstats, "allocd", get(cpu_gcstats, :allocd, 0))
        else
            cpu_allocs = Base.gc_alloc_count(cpu_gcstats)
        end
        
        cpu_bytes = getval(bench, :cpu_bytes)
        cpu_mem_str = Base.format_bytes(cpu_bytes)
        
        gpu_memstats = getval(bench, :gpu_memstats)
        if isa(gpu_memstats, Dict)
            gpu_allocs = get(gpu_memstats, "alloc_count", get(gpu_memstats, :alloc_count, 0))
        else
            gpu_allocs = gpu_memstats.alloc_count
        end
        
        gpu_bytes = getval(bench, :gpu_bytes)
        gpu_mem_str = Base.format_bytes(gpu_bytes)
        
        return "  $model_str: $time_str ($cpu_allocs CPU allocations: $cpu_mem_str) ($gpu_allocs GPU allocation$(gpu_allocs == 1 ? "" : "s"): $gpu_mem_str)"
    else
        # CPU benchmark format (BenchmarkTools @btimed)
        time_val = getval(bench, :time)
        time_str = prettytime(time_val)
        
        bytes_val = getval(bench, :bytes)
        memory_str = prettymemory(bytes_val)
        
        alloc_val = getval(bench, :alloc)
        return "  $model_str: $time_str ($alloc_val allocations: $memory_str)"
    end
end