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
        value, units = t, "s "
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
    print_benchmark_line(model::Symbol, stats::NamedTuple)

Print a formatted line summarizing benchmark statistics for `model` with colors.
Handles both CPU benchmarks (from @btimed) and GPU benchmarks (from CUDA.@timed).

Displays: time, allocations/memory, objective, iterations, and success status
"""
function print_benchmark_line(model::Symbol, stats::NamedTuple)
    bench = stats.benchmark
    
    # Handle error cases where benchmark is missing or nothing
    if ismissing(bench) || isnothing(bench)
        error_msg = haskey(stats, :status) ? stats.status : "ERROR"
        # Print with colored model name
        printstyled("  ✗ | ", color=:red, bold=true)
        printstyled(rpad(string(model), 8), color=:magenta, bold=true)
        println(": $error_msg")
        return
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
    has_cpu_bytes = (isa(bench, Dict) && (haskey(bench, "cpu_bytes") || haskey(bench, :cpu_bytes))) || 
                    (!isa(bench, Dict) && haskey(bench, :cpu_bytes))
    has_gpu_bytes = (isa(bench, Dict) && (haskey(bench, "gpu_bytes") || haskey(bench, :gpu_bytes))) || 
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
    obj_str = ismissing(stats.objective) ? rpad("N/A", 13) : rpad(@sprintf("%.6e", stats.objective), 13)
    iter_str = ismissing(stats.iterations) ? rpad("N/A", 6) : rpad(string(stats.iterations), 6)
    
    # Print with colored elements
    if stats.success
        printstyled("  ✓", color=:green, bold=true)
    else
        printstyled("  ✗", color=:red, bold=true)
    end
    
    print(" | ")
    printstyled(rpad(string(model), 8), color=:magenta, bold=true)
    println(": $time_str | obj: $obj_str | iters: $iter_str | $memory_display")
end
