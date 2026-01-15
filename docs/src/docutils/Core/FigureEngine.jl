# ═══════════════════════════════════════════════════════════════════════════════
# Figure Engine Module
# ═══════════════════════════════════════════════════════════════════════════════
#
# This module provides the figure generation system for generating PNG/PDF figure
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

const FIGURE_FUNCTIONS = Dict{String,Function}()

"""
    register_figure_handler!(name::String, func::Function)

Register a plotting function in the global figure registry.
"""
function register_figure_handler!(name::AbstractString, func::Function)
    FIGURE_FUNCTIONS[String(name)] = func
    return nothing
end

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
function call_figure_function(
    function_name::AbstractString, args::Vector{<:AbstractString}, extra_args::Tuple=()
)
    if !haskey(FIGURE_FUNCTIONS, function_name)
        available = join(sort(collect(keys(FIGURE_FUNCTIONS))), ", ")
        error(
            "Function '$function_name' not found in FIGURE_FUNCTIONS registry. Available: $available",
        )
    end

    func = FIGURE_FUNCTIONS[function_name]

    DOC_DEBUG[] && @info "  📞 Calling $function_name($(join(args, ", ")))"

    # Pass extra_args first (injected dependencies), then args (template arguments)
    return func(extra_args..., args...)
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
    extra_args::Tuple=(),
)
    # Generate unique basename
    args_str = join(args, "_")
    basename = generate_figure_basename(template_name, function_name, args_str)

    # Create output directory if it doesn't exist
    mkpath(output_dir)

    # Call the plotting function
    DOC_DEBUG[] &&
        @info "  🎨 Generating figure: $function_name($(join(["\"$arg\"" for arg in args], ", ")))"
    plt = call_figure_function(function_name, args, extra_args)

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
