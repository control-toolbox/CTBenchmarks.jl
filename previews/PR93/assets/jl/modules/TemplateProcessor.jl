# ═══════════════════════════════════════════════════════════════════════════════
# Template Processor Module
# ═══════════════════════════════════════════════════════════════════════════════
#
# This module provides functions to process template files that include:
# - `<!-- INCLUDE_ENVIRONMENT: ... -->` blocks: replaced with environment info
# - `<!-- INCLUDE_FIGURE: ... -->` blocks: replaced with generated figure HTML
# - `<!-- INCLUDE_TEXT: ... -->` blocks: replaced with generated Markdown text
#
# ═══════════════════════════════════════════════════════════════════════════════

"""
    read_environment_template(templates_dir::String) -> String

Read the environment template file from the assets directory.

# Arguments
- `templates_dir`: Path to the assets directory containing `environment.md.template`

# Returns
- String containing the template content

# Throws
- `SystemError` if the template file doesn't exist
"""
function read_environment_template(templates_dir::String)
    template_path = joinpath(templates_dir, "environment.md.template")
    if !isfile(template_path)
        error("Environment template not found at: $template_path")
    end
    @info "📄 Reading environment template from: $template_path"
    return read(template_path, String)
end

"""
    parse_include_params(param_block::AbstractString) -> Dict{String, String}

Parse the parameters from an INCLUDE_ENVIRONMENT block.

# Arguments
- `param_block`: String containing parameter assignments (e.g., "BENCH_DATA = BENCH_DATA_UBUNTU\\nENV_NAME = BENCH")

# Returns
- Dictionary mapping parameter names to their values

# Example
```julia
params = parse_include_params("BENCH_DATA = BENCH_DATA_UBUNTU\\nENV_NAME = BENCH")
# Returns: Dict("BENCH_DATA" => "BENCH_DATA_UBUNTU", "ENV_NAME" => "BENCH")
```
"""
function parse_include_params(param_block::AbstractString)
    params = Dict{String,String}()

    for line in split(param_block, '\n')
        # Skip empty lines
        stripped_line = strip(line)
        if isempty(stripped_line)
            continue
        end

        # Match pattern: KEY = VALUE, where VALUE can be any non-empty expression
        m = match(r"^\s*(\w+)\s*=\s*(.+?)\s*$", line)
        if m !== nothing
            key, value = m.captures
            value = strip(value)
            params[key] = value
            @info "  ✓ Parsed parameter: $key = $value"
        else
            @warn "  ⚠ Skipping malformed parameter line: '$line'"
        end
    end

    return params
end

"""
    substitute_variables(template::String, params::Dict{String, String}) -> String

Replace all occurrences of parameter names with their values in the template.

# Arguments
- `template`: Template string containing variable names to replace
- `params`: Dictionary mapping variable names to their replacement values

# Returns
- String with all variables substituted

# Example
```julia
template = "Hello ENV_NAME"
params = Dict("ENV_NAME" => "BENCH")
result = substitute_variables(template, params)
# Returns: "Hello BENCH"
```
"""
function substitute_variables(template::String, params::Dict{String,String})
    result = template

    # Replace each parameter in the template
    for (key, value) in params
        result = replace(result, key => value)
    end

    return result
end

"""
    replace_environment_blocks(content::String, env_template::String) -> String

Replace all INCLUDE_ENVIRONMENT blocks in the content with the environment template,
substituting the specified variables.

# Arguments
- `content`: Document content containing INCLUDE_ENVIRONMENT blocks
- `env_template`: Environment template content

# Returns
- String with all INCLUDE_ENVIRONMENT blocks replaced

# Details
The function searches for blocks matching the pattern:
```
<!-- INCLUDE_ENVIRONMENT:
PARAM1 = VALUE1
PARAM2 = VALUE2
-->
```

And replaces them with the environment template where PARAM1, PARAM2, etc. are
substituted with their corresponding values.
"""
function replace_environment_blocks(content::String, env_template::String)
    # Regex to match INCLUDE_ENVIRONMENT blocks
    # The 's' flag allows '.' to match newlines
    pattern = r"<!-- INCLUDE_ENVIRONMENT:\s*\n(.*?)-->"s

    block_count = 0

    # Replace each match
    result = replace(
        content,
        pattern => function (match_str)
            block_count += 1
            @info "🔄 Processing INCLUDE_ENVIRONMENT block #$block_count"

            # Extract the parameter block (group 1)
            m = match(pattern, match_str)
            if m === nothing
                @warn "  ✗ Failed to parse INCLUDE_ENVIRONMENT block"
                return match_str  # Return original if parsing fails
            end

            param_block = m.captures[1]

            # Parse parameters
            params = parse_include_params(param_block)

            if isempty(params)
                @warn "  ✗ No valid parameters found in INCLUDE_ENVIRONMENT block"
                return match_str  # Return original if no params
            end

            # Substitute variables in the template
            substituted = substitute_variables(env_template, params)
            @info "  ✓ Successfully replaced block #$block_count with $(length(params)) parameter(s)"

            return substituted
        end,
    )

    @info "📝 Replaced $block_count INCLUDE_ENVIRONMENT block(s)"
    return result
end

"""
    replace_figure_blocks(
        content::String,
        template_filename::String,
        figures_output_dir::String,
        relative_path::String
    ) -> (String, Vector{String})

Replace all INCLUDE_FIGURE blocks in the content with generated HTML that embeds SVG previews
and links to PDF files.

This function scans the input content for blocks of the form:

```html
<!-- INCLUDE_FIGURE:
FUNCTION = "_plot_time_vs_grid_size"
ARGS     = "arg1, arg2"
-->
```

For each block, it calls the corresponding function from the utilities module to generate
a pair of figure files (SVG for preview, PDF for download) and replaces the block with
an HTML snippet that embeds the SVG and links to the PDF.

# Arguments
- `content::String`: Input markdown content
- `template_filename::String`: Name of the template file (for basename generation)
- `figures_output_dir::String`: Absolute path where figures will be saved
- `relative_path::String`: Relative path from the .md file to the figures directory

# Returns
- `(String, Vector{String})`: Tuple containing the content with INCLUDE_FIGURE blocks replaced by
  HTML, and a list of absolute paths to the generated figure files (SVG and PDF)

# Example
```julia
content, figure_paths = replace_figure_blocks(
    template_content,
    "cpu.md.template",
    "/path/to/docs/src/assets/plots",
    "../assets/plots"
)
```
"""
function replace_figure_blocks(
    content::String,
    template_filename::String,
    figures_output_dir::String,
    relative_path::String
)
    # Regex to match INCLUDE_FIGURE blocks
    pattern = r"<!-- INCLUDE_FIGURE:\s*\n(.*?)-->"s
    block_count = 0
    figure_paths = String[]
    
    result = replace(content, pattern => function(match_str)
        block_count += 1
        @info "🖼️  Processing INCLUDE_FIGURE block #$block_count"
        
        # Extract the parameter block
        m = match(pattern, match_str)
        if m === nothing
            @warn "  ✗ Failed to parse INCLUDE_FIGURE block"
            return match_str
        end
        
        param_block = m.captures[1]
        params = parse_include_params(param_block)
        
        # Extract required parameters
        function_name = get(params, "FUNCTION", nothing)
        args_str = get(params, "ARGS", "")
        
        if function_name === nothing
            @warn "  ✗ Missing FUNCTION parameter in INCLUDE_FIGURE block"
            return match_str
        end
        
        # Parse arguments (comma-separated, strip quotes and whitespace)
        args = if isempty(args_str)
            String[]
        else
            [strip(strip(arg), ['"', '\'']) for arg in split(args_str, ',')]
        end
        
        # Generate figures (SVG for preview, PDF for download)
        try
            svg_file, pdf_file = generate_figure_files(
                template_filename,
                function_name,
                args,
                figures_output_dir
            )

            # Record absolute paths for later cleanup
            push!(figure_paths, joinpath(figures_output_dir, svg_file))
            push!(figure_paths, joinpath(figures_output_dir, pdf_file))
            
            # Generate HTML with clickable SVG→PDF
            html = """```@raw html
<a href="$relative_path/$pdf_file">
  <img 
    class="centering" 
    width="100%" 
    style="max-width:1400px" 
    src="$relative_path/$svg_file"
  />
</a>
```"""
            
            @info "  ✓ Replaced block #$block_count with figure: $svg_file"
            return html
            
        catch e
            @error "  ✗ Failed to generate figure" exception = (e, catch_backtrace())
            return match_str  # Return original block on error
        end
    end)
    
    @info "🖼️  Replaced $block_count INCLUDE_FIGURE block(s)"
    return result, figure_paths
end

"""
    replace_text_blocks(content::String) -> String

Replace all INCLUDE_TEXT (and legacy INCLUDE_ANALYSIS) blocks in the content
with Markdown generated by registered text functions.

This function scans the input content for blocks of the form:

```html
<!-- INCLUDE_TEXT:
FUNCTION = "_analyze_profile_default_cpu"
ARGS     = "core-ubuntu-latest"
-->
```

and replaces each block with the Markdown string returned by the corresponding
text function.
"""
function replace_text_blocks(content::String)
    pattern = r"<!-- INCLUDE_(?:TEXT|ANALYSIS):\s*\n(.*?)-->"s
    block_count = 0

    result = replace(content, pattern => function(match_str)
        block_count += 1
        @info "🧮 Processing INCLUDE_TEXT block #$block_count"

        m = match(pattern, match_str)
        if m === nothing
            @warn "  ✗ Failed to parse INCLUDE_TEXT block"
            return match_str
        end

        param_block = m.captures[1]
        params = parse_include_params(param_block)

        function_name = get(params, "FUNCTION", nothing)
        args_str = get(params, "ARGS", "")

        if function_name === nothing
            @warn "  ✗ Missing FUNCTION parameter in INCLUDE_TEXT block"
            return match_str
        end

        args = if isempty(args_str)
            String[]
        else
            [strip(strip(arg), ['"', '\'']) for arg in split(args_str, ',')]
        end

        try
            text_md = call_text_function(function_name, args)
            @info "  ✓ Replaced INCLUDE_TEXT block #$block_count with generated Markdown"
            return text_md
        catch e
            @error "  ✗ Failed to generate analysis" exception=(e, catch_backtrace())
            return match_str
        end
    end)

    @info "🧮 Replaced $block_count INCLUDE_TEXT block(s)"
    return result
end

"""
    process_single_template(
        input_path::String,
        output_path::String,
        env_template::String,
        figures_output_dir::String,
        figures_relative_path::String
    ) -> Vector{String}

Process a single template file, replacing INCLUDE_ENVIRONMENT and INCLUDE_FIGURE blocks.

# Arguments
- `input_path::String`: Path to the input .template file
- `output_path::String`: Path to the output .md file
- `env_template::String`: Environment template content
- `figures_output_dir::String`: Absolute path where figures will be saved
- `figures_relative_path::String`: Relative path from .md file to figures directory

# Returns
- `Vector{String}`: Absolute paths to all figure files (SVG and PDF) generated while
  processing this template

# Throws
- `SystemError` if the input file doesn't exist or output cannot be written
"""
function process_single_template(
    input_path::String,
    output_path::String,
    env_template::String,
    figures_output_dir::String,
    figures_relative_path::String
)
    # Read the template file
    if !isfile(input_path)
        error("Template file not found: $input_path")
    end

    @info "📖 Reading template file: $input_path"
    content = read(input_path, String)
    
    # Extract template filename for figure generation
    template_filename = basename(input_path)

    # Replace all INCLUDE_ENVIRONMENT blocks
    processed_content = replace_environment_blocks(content, env_template)
    
    # Replace all INCLUDE_FIGURE blocks and collect generated figure paths
    processed_content, figure_paths = replace_figure_blocks(
        processed_content,
        template_filename,
        figures_output_dir,
        figures_relative_path
    )

    # Replace all INCLUDE_TEXT blocks
    processed_content = replace_text_blocks(processed_content)

    # Write the output file
    @info "💾 Writing processed file: $output_path"
    write(output_path, processed_content)

    @info "✅ Successfully processed: $(basename(input_path)) -> $(basename(output_path))"
    return figure_paths
end

"""
    process_templates(template_files::Vector{String}, src_dir::String, templates_dir::String)

Process multiple template files, replacing INCLUDE_ENVIRONMENT and INCLUDE_FIGURE blocks.

# Arguments
- `template_files`: List of template file names (e.g., ["benchmark-core.md"]) to process
- `src_dir`: Source directory containing the template files
- `templates_dir`: Assets directory containing `environment.md.template`

# Returns
- `Vector{String}`: Absolute paths to all figure files (SVG and PDF) generated while
  processing all templates

# Details
For each file in `template_files`:
1. Reads `<src_dir>/<filename>.template` (e.g., `benchmark-core.md.template`)
2. Replaces all `<!-- INCLUDE_ENVIRONMENT: ... -->` blocks
3. Replaces all `<!-- INCLUDE_FIGURE: ... -->` blocks (generates SVG/PDF files)
4. Writes the result to `<src_dir>/<filename>` (e.g., `benchmark-core.md`)

# Example
```julia
figure_paths = process_templates(
    ["benchmark-core", "benchmark-minimal"],
    "docs/src",
    "docs/src/assets"
)
```
"""
function process_templates(
    template_files::Vector{String}, src_dir::String, templates_dir::String
)
    @info "" # Empty line for readability
    @info "═"^70
    @info "🚀 Starting template processing"
    @info "═"^70
    @info "📂 Source directory: $src_dir"
    @info "📂 Assets directory: $templates_dir"
    @info "📋 Templates to process: $(length(template_files))"

    # Read the environment template once
    env_template = read_environment_template(templates_dir)

    # Remove the comment block from the environment template
    # (lines 1-6: <!-- INPUTS: ... -->)
    @info "🧹 Cleaning environment template (removing comment block)"
    env_template_lines = split(env_template, '\n')

    # Find the end of the comment block
    comment_end = 0
    for (i, line) in enumerate(env_template_lines)
        if occursin("-->", line)
            comment_end = i
            break
        end
    end

    if comment_end > 0
        # Keep only the content after the comment block
        env_template = join(env_template_lines[(comment_end + 1):end], '\n')
        @info "  ✓ Removed $comment_end line(s) from template header"
    end
    
    # Setup figures directory
    figures_output_dir = joinpath(src_dir, "assets", "plots")
    mkpath(figures_output_dir)
    @info "📁 Figures output directory: $figures_output_dir"

    @info "" # Empty line for readability

    all_figure_paths = String[]

    # Process each template file
    for (idx, filename) in enumerate(template_files)
        @info "─"^70
        @info "📄 Processing template $idx/$(length(template_files)): $filename"
        @info "─"^70

        input_path = joinpath(src_dir, filename * ".template")
        output_path = joinpath(src_dir, filename)
        
        # Determine relative path from output file to figures directory
        # Most files are in src/core/, so relative path is ../assets/plots
        # Adjust if needed based on file location
        output_subdir = dirname(filename)
        if isempty(output_subdir) || output_subdir == "."
            figures_relative_path = joinpath("assets", "plots")
        else
            # Count directory levels to go up
            levels = length(split(output_subdir, '/'))
            figures_relative_path = join(fill("..", levels), "/") * joinpath("/","assets", "plots")
        end

        try
            figure_paths = process_single_template(
                input_path,
                output_path,
                env_template,
                figures_output_dir,
                figures_relative_path
            )
            append!(all_figure_paths, figure_paths)
        catch e
            @error "❌ Failed to process template: $filename" exception=(
                e, catch_backtrace()
            )
            rethrow(e)
        end

        @info "" # Empty line for readability
    end

    @info "═"^70
    @info "✅ Successfully processed $(length(template_files)) template file(s)"
    @info "═"^70
    @info "" # Empty line for readability

    return all_figure_paths, figures_output_dir
end

"""
    construct_template_files(template_files::Vector{String}, src_dir::String)::Vector{String}

Construct a list of template files by resolving template file paths and discovering templates in directories.

This function processes a list of template file specifications and returns a list of actual template files
to be processed. It handles two cases: direct template files (with `.template` extension) and directories
containing multiple `.md.template` files.

# Arguments

- `template_files::Vector{String}`: List of template file specifications. Each entry can be either:
  - A template file name (e.g., `"benchmark-core.md"` → looks for `"benchmark-core.md.template"`)
  - A directory name (e.g., `"benchmarks"` → discovers all `.md.template` files in that directory)
- `src_dir::String`: Source directory where template files are located

# Returns

- `Vector{String}`: List of resolved template file paths (without `.template` extension), ready for processing

# Example

```julia
# Direct template file
files = construct_template_files(["benchmark-core.md"], "/path/to/docs/src")
# Returns: ["benchmark-core.md"]

# Directory with multiple templates
files = construct_template_files(["benchmarks"], "/path/to/docs/src")
# Returns: ["benchmarks/cpu.md", "benchmarks/gpu.md"] (if those .md.template files exist)
```

# Details

- If a specification matches a file with `.template` extension, it is added to the result
- If a specification matches a directory, all `.md.template` files in that directory are discovered and added
- The returned paths have the `.template` extension removed for use in subsequent processing
"""
function construct_template_files(template_files::Vector{String}, src_dir::String)
    files = String[]
    for file in template_files
        if isfile(joinpath(src_dir, file * ".template"))
            push!(files, file)
        elseif isdir(joinpath(src_dir, file))
            for f in readdir(joinpath(src_dir, file))
                if endswith(f, ".md.template")
                    push!(files, joinpath(file, f[1:end-9]))
                end
            end
        end
    end
    return files
end

"""
    with_processed_templates(f::Function, template_files::Vector{String}, src_dir::String, templates_dir::String)

Process template files, execute the provided function, and clean up generated files.

This function ensures that generated .md files and any figures created during template processing
are always removed after use, even if an error occurs during the execution of `f`. This is useful
for documentation generation where temporary files should not persist.

# Arguments
- `f`: Function to execute after templates are processed (typically `makedocs`)
- `template_files`: List of template file names (e.g., ["benchmark-core.md"]) to process
- `src_dir`: Source directory containing the template files
- `templates_dir`: Assets directory containing `environment.md.template`

# Returns
- The return value of `f()`

# Example
```julia
with_processed_templates(
    ["benchmark-core.md"],
    joinpath(@__DIR__, "src"),
    joinpath(@__DIR__, "src", "assets", "templates")
) do
    makedocs(;
        sitename="MyDocs",
        pages=["Introduction" => "index.md", "Benchmark" => "benchmark-core.md"]
    )
end
```

# Details
The function follows this workflow:
1. Process all template files (`.template` → `.md`)
2. Execute the user function `f`
3. Clean up all generated `.md` files and figure files in a `finally` block (guaranteed cleanup)

This pattern is inspired by `with_problems_browser` from OptimalControlProblems.jl.
"""
function with_processed_templates(
    f::Function, template_files::Vector{String}, src_dir::String, templates_dir::String
)
    # Process templates to generate .md files and collect generated figure paths
    template_files = construct_template_files(template_files, src_dir)
    figure_paths, figures_output_dir = process_templates(template_files, src_dir, templates_dir)
    @info "📊 Collected $(length(figure_paths)) figure path(s) from process_templates"

    try
        # Execute the user function (typically makedocs)
        return f()
    finally
        # Clean up generated .md files and figures (guaranteed to run even on error)
        @info "" # Empty line for readability
        @info "🧹 Cleaning up generated template files..."

        for filename in template_files
            output_file = joinpath(src_dir, filename)
            if isfile(output_file)
                rm(output_file)
                @info "  ✓ Removed: $(basename(output_file))"
            else
                @warn "  ⚠ File not found (already removed?): $(basename(output_file))"
            end
        end

        if !isempty(figure_paths)
            @info "" # Empty line for readability
            @info "🧹 Cleaning up generated figure files..."
            for fig_path in figure_paths
                if isfile(fig_path)
                    rm(fig_path)
                    @info "  ✓ Removed figure: $(basename(fig_path))"
                else
                    @warn "  ⚠ Figure file not found (already removed?): $(basename(fig_path))"
                end
            end
        end

        # Only remove directory if it's empty
        if isdir(figures_output_dir) && isempty(readdir(figures_output_dir))
            rm(figures_output_dir)
            @info "  ✓ Removed empty directory: $(basename(figures_output_dir))"
        end

        @info "✅ Cleanup completed"
        @info "" # Empty line for readability
    end
end
