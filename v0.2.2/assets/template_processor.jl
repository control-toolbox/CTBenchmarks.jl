"""
Template processor for benchmark documentation.

This module provides functions to process template files that include environment
information blocks. It replaces `<!-- INCLUDE_ENVIRONMENT: ... -->` blocks with
the content from `environment.md.template`, substituting the specified variables.
"""

"""
    read_environment_template(assets_dir::String) -> String

Read the environment template file from the assets directory.

# Arguments
- `assets_dir`: Path to the assets directory containing `environment.md.template`

# Returns
- String containing the template content

# Throws
- `SystemError` if the template file doesn't exist
"""
function read_environment_template(assets_dir::String)
    template_path = joinpath(assets_dir, "environment.md.template")
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
    params = Dict{String, String}()
    
    for line in split(param_block, '\n')
        # Skip empty lines
        stripped_line = strip(line)
        if isempty(stripped_line)
            continue
        end
        
        # Match pattern: KEY = VALUE
        m = match(r"^\s*(\w+)\s*=\s*(\w+)\s*$", line)
        if m !== nothing
            key, value = m.captures
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
function substitute_variables(template::String, params::Dict{String, String})
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
    result = replace(content, pattern => function(match_str)
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
    end)
    
    @info "📝 Replaced $block_count INCLUDE_ENVIRONMENT block(s)"
    return result
end

"""
    process_single_template(input_path::String, output_path::String, env_template::String)

Process a single template file, replacing INCLUDE_ENVIRONMENT blocks and writing the result.

# Arguments
- `input_path`: Path to the input .template file
- `output_path`: Path to the output .md file
- `env_template`: Environment template content

# Throws
- `SystemError` if the input file doesn't exist or output cannot be written
"""
function process_single_template(input_path::String, output_path::String, env_template::String)
    # Read the template file
    if !isfile(input_path)
        error("Template file not found: $input_path")
    end
    
    @info "📖 Reading template file: $input_path"
    content = read(input_path, String)
    
    # Replace all INCLUDE_ENVIRONMENT blocks
    processed_content = replace_environment_blocks(content, env_template)
    
    # Write the output file
    @info "💾 Writing processed file: $output_path"
    write(output_path, processed_content)
    
    @info "✅ Successfully processed: $(basename(input_path)) -> $(basename(output_path))"
end

"""
    process_templates(template_files::Vector{String}, src_dir::String, assets_dir::String)

Process multiple template files, replacing INCLUDE_ENVIRONMENT blocks with the environment template.

# Arguments
- `template_files`: List of template file names (e.g., ["benchmark-core.md"]) to process
- `src_dir`: Source directory containing the template files
- `assets_dir`: Assets directory containing `environment.md.template`

# Details
For each file in `template_files`:
1. Reads `<src_dir>/<filename>.template` (e.g., `benchmark-core.md.template`)
2. Replaces all `<!-- INCLUDE_ENVIRONMENT: ... -->` blocks
3. Writes the result to `<src_dir>/<filename>` (e.g., `benchmark-core.md`)

# Example
```julia
process_templates(
    ["benchmark-core", "benchmark-minimal"],
    "docs/src",
    "docs/src/assets"
)
```
"""
function process_templates(template_files::Vector{String}, src_dir::String, assets_dir::String)
    @info "" # Empty line for readability
    @info "═"^70
    @info "🚀 Starting template processing"
    @info "═"^70
    @info "📂 Source directory: $src_dir"
    @info "📂 Assets directory: $assets_dir"
    @info "📋 Templates to process: $(length(template_files))"
    
    # Read the environment template once
    env_template = read_environment_template(assets_dir)
    
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
        env_template = join(env_template_lines[comment_end+1:end], '\n')
        @info "  ✓ Removed $comment_end line(s) from template header"
    end
    
    @info "" # Empty line for readability
    
    # Process each template file
    for (idx, filename) in enumerate(template_files)
        @info "─"^70
        @info "📄 Processing template $idx/$(length(template_files)): $filename"
        @info "─"^70
        
        input_path = joinpath(src_dir, filename * ".template")
        output_path = joinpath(src_dir, filename)
        
        try
            process_single_template(input_path, output_path, env_template)
        catch e
            @error "❌ Failed to process template: $filename" exception=(e, catch_backtrace())
            rethrow(e)
        end
        
        @info "" # Empty line for readability
    end
    
    @info "═"^70
    @info "✅ Successfully processed $(length(template_files)) template file(s)"
    @info "═"^70
    @info "" # Empty line for readability
end

"""
    with_processed_templates(f::Function, template_files::Vector{String}, src_dir::String, assets_dir::String)

Process template files, execute the provided function, and clean up generated files.

This function ensures that generated .md files are always removed after use, even if an error occurs
during the execution of `f`. This is useful for documentation generation where temporary files
should not persist.

# Arguments
- `f`: Function to execute after templates are processed (typically `makedocs`)
- `template_files`: List of template file names (e.g., ["benchmark-core.md"]) to process
- `src_dir`: Source directory containing the template files
- `assets_dir`: Assets directory containing `environment.md.template`

# Returns
- The return value of `f()`

# Example
```julia
with_processed_templates(
    ["benchmark-core.md"],
    joinpath(@__DIR__, "src"),
    joinpath(@__DIR__, "src", "assets")
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
3. Clean up all generated `.md` files in a `finally` block (guaranteed cleanup)

This pattern is inspired by `with_problems_browser` from OptimalControlProblems.jl.
"""
function with_processed_templates(f::Function, template_files::Vector{String}, src_dir::String, assets_dir::String)
    # Process templates to generate .md files
    process_templates(template_files, src_dir, assets_dir)
    
    try
        # Execute the user function (typically makedocs)
        return f()
    finally
        # Clean up generated .md files (guaranteed to run even on error)
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
        
        @info "✅ Cleanup completed"
        @info "" # Empty line for readability
    end
end
