# ═══════════════════════════════════════════════════════════════════════════════
# Common Utilities Module
# ═══════════════════════════════════════════════════════════════════════════════

"""
    _plot_font_settings()

Return font settings for plot titles and axis labels.

# Returns
- `Tuple{Plots.Font, Plots.Font}`: tuple `(title_font, label_font)` where the
  title font uses size 14 pt and the label font uses size 10 pt, both with the
  default plot font family.
"""
function _plot_font_settings()
    return font(14, Plots.default(:fontfamily)), font(10, Plots.default(:fontfamily))
end

"""
    _get_bench_data(bench_id::AbstractString, src_dir::AbstractString)

Retrieve benchmark data from a JSON file based on the benchmark ID.

# Arguments
- `bench_id::AbstractString`: identifier for the benchmark (for example
  `"core-ubuntu-latest"`).
- `src_dir::AbstractString`: path to the `docs/src` directory.

# Returns
- `Dict` or `Nothing`: parsed benchmark data dictionary if the JSON file
  exists, `nothing` otherwise.

# Details
Constructs the path to the benchmark JSON file using the benchmark identifier
and reads it. The file is expected to be located at
`src/assets/benchmarks/<bench_id>/<bench_id>.json` relative to the
documentation root.
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
- `path::AbstractString`: full path to the JSON file on disk.

# Returns
- `Dict` or `Nothing`: parsed JSON content if the file exists, `nothing` if the
  file is not found.

# Details
Safely reads a JSON file and returns its parsed content. Returning `nothing`
when the file does not exist allows graceful handling of missing benchmark
data in higher-level utilities.
"""
function _read_benchmark_json(path::AbstractString)
    if !isfile(path)
        return nothing
    end
    open(path, "r") do io
        return JSON.parse(io)
    end
end
