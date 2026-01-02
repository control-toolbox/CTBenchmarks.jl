# ═══════════════════════════════════════════════════════════════════════════════
# Figure Generation Module
# ═══════════════════════════════════════════════════════════════════════════════
#
# This module provides the INCLUDE_FIGURE system for generating PNG/PDF figure
# pairs from plotting functions and embedding them in documentation.
#
# ═══════════════════════════════════════════════════════════════════════════════

# ───────────────────────────────────────────────────────────────────────────────
# Function Registry
# ───────────────────────────────────────────────────────────────────────────────

"""
Registry of plotting functions that can be called from INCLUDE_FIGURE blocks.

All registered functions must accept string arguments and return a Plots.Plot object.
"""

"""
    _plot_profile_default_cpu_from_args(args...)

Internal adapter used by INCLUDE_FIGURE to call `_plot_profile_default_cpu`.

Interpretation of arguments:
- First argument: `bench_id`
- Remaining arguments (if any): list of combo specs `"model:solver"` used to
  restrict the `(model, solver)` combinations included in the profile.
"""
function _plot_profile_default_cpu_from_args(args...)
    if isempty(args)
        error("_plot_profile_default_cpu requires at least a bench_id argument")
    end

    bench_id = String(args[1])

    if length(args) == 1
        return _plot_profile_default_cpu(bench_id)
    end

    combos = Tuple{String,String}[]
    for spec in args[2:end]
        parts = split(String(spec), ":")
        if length(parts) != 2
            error(
                "Invalid combo specification '" *
                String(spec) *
                "'. Expected 'model:solver'.",
            )
        end
        push!(combos, (parts[1], parts[2]))
    end

    return _plot_profile_default_cpu(bench_id; combos=combos)
end

"""
    _plot_profile_default_iter_from_args(args...)

Internal adapter used by INCLUDE_FIGURE to call `_plot_profile_default_iter`.

Interpretation of arguments:
- First argument: `bench_id`
- Remaining arguments (if any): list of combo specs `"model:solver"` used to
  restrict the `(model, solver)` combinations included in the profile.
"""
function _plot_profile_default_iter_from_args(args...)
    if isempty(args)
        error("_plot_profile_default_iter requires at least a bench_id argument")
    end

    bench_id = String(args[1])

    if length(args) == 1
        return _plot_profile_default_iter(bench_id)
    end

    combos = Tuple{String,String}[]
    for spec in args[2:end]
        parts = split(String(spec), ":")
        if length(parts) != 2
            error(
                "Invalid combo specification '" *
                String(spec) *
                "'. Expected 'model:solver'.",
            )
        end
        push!(combos, (parts[1], parts[2]))
    end

    return _plot_profile_default_iter(bench_id; combos=combos)
end

function _plot_profile_midpoint_trapeze_exa_from_args(args...)
    if isempty(args)
        error("_plot_profile_default_iter requires at least a bench_id argument")
    end

    bench_id = String(args[1])

    if length(args) == 1
        return _plot_profile_midpoint_trapeze_exa(bench_id)
    end

    combos = Tuple{String,String}[]
    for spec in args[2:end]
        parts = split(String(spec), ":")
        if length(parts) != 2
            error(
                "Invalid combo specification '" *
                String(spec) *
                "'. Expected 'model:solver'.",
            )
        end
        push!(combos, (parts[1], parts[2]))
    end

    return _plot_profile_midpoint_trapeze_exa(bench_id; combos=combos)
end

const FIGURE_FUNCTIONS = Dict{String,Function}(
    "_plot_profile_default_cpu" => _plot_profile_default_cpu_from_args,
    "_plot_profile_default_iter" => _plot_profile_default_iter_from_args,
    "_plot_time_vs_grid_size" => _plot_time_vs_grid_size,
    "_plot_time_vs_grid_size_bar" => _plot_time_vs_grid_size_bar,
    "_plot_iterations_vs_cpu_time" => _plot_iterations_vs_cpu_time,
    "_plot_profile_midpoint_trapeze_exa" => _plot_profile_midpoint_trapeze_exa_from_args,
)

"""
    call_figure_function(function_name::String, args::Vector{String})

Safely call a registered plotting function with string arguments.

# Arguments
- `function_name::String`: Name of the function (must be in FIGURE_FUNCTIONS)
- `args::Vector{String}`: Vector of string arguments to pass to the function

# Returns
- `Plots.Plot`: The generated plot

# Throws
- `ErrorException` if function not found in registry

# Example
```julia
plt = call_figure_function("_plot_profile_default_cpu", ["core-ubuntu-latest"])
```
"""
function call_figure_function(function_name::AbstractString, args::Vector{<:AbstractString})
    if !haskey(FIGURE_FUNCTIONS, function_name)
        available = join(sort(collect(keys(FIGURE_FUNCTIONS))), ", ")
        error(
            "Function '$function_name' not found in FIGURE_FUNCTIONS registry. Available: $available",
        )
    end

    func = FIGURE_FUNCTIONS[function_name]

    DOC_DEBUG[] && @info "  📞 Calling $function_name($(join(args, ", ")))"

    # Call function with string arguments
    return func(args...)
end

# ───────────────────────────────────────────────────────────────────────────────
# Figure Generation
# ───────────────────────────────────────────────────────────────────────────────

"""
    generate_figure_basename(template_name::String, function_name::String, args_str::String)

Generate a unique basename for figure files based on template name, function, and arguments.

# Arguments
- `template_name::String`: Name of the template file (e.g., "cpu.md.template")
- `function_name::String`: Name of the plotting function (e.g., "_plot_profile_default_cpu")
- `args_str::String`: String representation of arguments (e.g., "core-ubuntu-latest")

# Returns
- `String`: Basename for the figure files (without extension)

# Example
```julia
basename = generate_figure_basename("cpu.md.template", "_plot_profile_default_cpu", "core-ubuntu-latest")
# Returns: "cpu_plot_profile_default_cpu_a3f2c1d4"
```
"""
function generate_figure_basename(
    template_name::AbstractString, function_name::AbstractString, args_str::AbstractString
)
    # Extract base name from template (remove .md.template)
    base = replace(template_name, r"\.md\.template$" => "")

    # Clean function name (remove leading underscore)
    func_clean = replace(function_name, r"^_" => "")

    # Generate short hash from function name + arguments for uniqueness
    hash_input = function_name * "_" * args_str
    hash_bytes = sha256(hash_input)
    hash_short = bytes2hex(hash_bytes)[1:8]

    return "$(base)_$(func_clean)_$(hash_short)"
end

"""
    generate_figure_files(
        template_name::String,
        function_name::String,
        args::Vector{String},
        output_dir::String
    ) -> Tuple{String, String}

Generate SVG and PDF files for a figure and return their filenames.

# Arguments
- `template_name::String`: Name of the template file (e.g., "cpu.md.template")
- `function_name::String`: Name of the plotting function
- `args::Vector{String}`: Arguments to pass to the function
- `output_dir::String`: Directory where to save the figures

# Returns
- `Tuple{String, String}`: (svg_filename, pdf_filename) - just the filenames, not full paths

# Example
```julia
svg, pdf = generate_figure_files(
    "cpu.md.template",
    "_plot_profile_default_cpu",
    ["core-ubuntu-latest"],
    "docs/src/assets/plots"
)
# Returns: ("cpu_plot_profile_default_cpu_a3f2c1d4.svg", "cpu_plot_profile_default_cpu_a3f2c1d4.pdf")
```
"""
function generate_figure_files(
    template_name::AbstractString,
    function_name::AbstractString,
    args::Vector{<:AbstractString},
    output_dir::AbstractString,
)
    # Generate unique basename
    args_str = join(args, "_")
    basename = generate_figure_basename(template_name, function_name, args_str)

    # Create output directory if it doesn't exist
    mkpath(output_dir)

    # Call the plotting function
    DOC_DEBUG[] &&
        @info "  🎨 Generating figure: $function_name($(join(["\"$arg\"" for arg in args], ", ")))"
    plt = call_figure_function(function_name, args)

    # Define file names
    svg_file = basename * ".svg"
    pdf_file = basename * ".pdf"
    svg_path = joinpath(output_dir, svg_file)
    pdf_path = joinpath(output_dir, pdf_file)

    # Save both formats
    savefig(plt, svg_path)
    savefig(plt, pdf_path)

    DOC_DEBUG[] && @info "  ✓ Saved: $svg_file and $pdf_file"

    # Return just the filenames (not full paths)
    return (svg_file, pdf_file)
end
