# ═══════════════════════════════════════════════════════════════════════════════
# Common Utilities Module
# ═══════════════════════════════════════════════════════════════════════════════

"""
    _plot_font_settings()

Return font settings for plot titles and axis labels.

# Returns
- `Tuple{Plots.Font, Plots.Font}`: A tuple of (title_font, label_font) where title_font is 14pt and label_font is 10pt
"""
function _plot_font_settings()
    return font(14, Plots.default(:fontfamily)), font(10, Plots.default(:fontfamily))
end

"""
    _get_bench_data(bench_id::AbstractString, src_dir::AbstractString)

Retrieve benchmark data from a JSON file based on the benchmark ID.

# Arguments
- `bench_id::AbstractString`: Identifier for the benchmark (e.g., "core-ubuntu-latest")
- `src_dir::AbstractString`: Path to docs/src directory

# Returns
- `Dict` or `nothing`: Parsed benchmark data dictionary if file exists, `nothing` otherwise

# Details
Constructs the path to the benchmark JSON file using the benchmark ID and reads it.
The file is expected to be located at `src/assets/benchmarks/<bench_id>/<bench_id>.json`.
"""
function _get_bench_data(bench_id::AbstractString, src_dir::AbstractString)
    json_filename = string(bench_id, ".json")
    path = joinpath(src_dir, "assets", "benchmarks", bench_id, json_filename)
    return _read_benchmark_json(path)
end

"""
    _read_benchmark_json(path::AbstractString)

Read and parse a benchmark JSON file.

# Arguments
- `path::AbstractString`: Full path to the JSON file

# Returns
- `Dict` or `nothing`: Parsed JSON content if file exists, `nothing` if file not found

# Details
Safely reads a JSON file and returns its parsed content. Returns `nothing` if the file
does not exist, allowing graceful handling of missing benchmark data.
"""
function _read_benchmark_json(path::AbstractString)
    if !isfile(path)
        return nothing
    end
    open(path, "r") do io
        return JSON.parse(io)
    end
end
