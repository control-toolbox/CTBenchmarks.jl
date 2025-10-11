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
    format_benchmark_line(model::Symbol, time_ns::Real, allocs::Integer, memory_bytes::Integer) -> String

Build a formatted line summarizing benchmark statistics for `model`, combining
the elapsed time `time_ns`, allocation count `allocs`, and allocated memory
`memory_bytes` using `prettytime` and `prettymemory`.
"""
function format_benchmark_line(model::Symbol, time_ns::Float64, allocs::Int, memory_bytes::Int)
    model_str = rpad(string(model), 6)
    time_str = prettytime(time_ns)
    memory_str = prettymemory(memory_bytes)
    return "  $model_str:   $time_str ($allocs allocations: $memory_str)"
end