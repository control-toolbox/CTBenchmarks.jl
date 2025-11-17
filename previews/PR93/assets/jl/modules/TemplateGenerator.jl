# ═══════════════════════════════════════════════════════════════════════════════
# Template Generator Module
# ═══════════════════════════════════════════════════════════════════════════════
#
# This module provides functions to automatically generate Markdown template files
# for benchmark problem documentation pages. It creates structured documentation
# that includes:
# - Performance plots (time vs grid size)
# - Solution visualizations (PNG/PDF figures)
# - Benchmark logs and configuration details
#
# The generated templates are processed by TemplateProcessor to create the
# final documentation pages.
#
# ═══════════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════════════════════

"""
    draft_meta(draft)

Generate Documenter.jl draft metadata block.

Controls whether @example blocks in the documentation are executed during the build.
Useful for speeding up documentation builds during development.

# Arguments
- `draft::Union{Bool,Nothing}`: Draft mode flag
  - `nothing`: No metadata block (default behavior)
  - `true`: Add `Draft = true` (skip @example execution)
  - `false`: Add `Draft = false` (force @example execution)

# Returns
- `String`: Markdown metadata block or empty string
"""
function draft_meta(draft::Union{Bool,Nothing})
    if isnothing(draft)
        return ""
    elseif draft
        return """```@meta\nDraft = true\n```"""
    else
        return """```@meta\nDraft = false\n```"""
    end
end

# ═══════════════════════════════════════════════════════════════════════════════
# Core Template Generation Functions
# ═══════════════════════════════════════════════════════════════════════════════

"""
    generate_template_problem(problem_name, bench_id, bench_title, bench_desc, env_name, src_dir)

Generate a Markdown template section for a single benchmark configuration.

Creates a documentation section containing performance plots, solution figures,
and benchmark logs for a specific problem-benchmark combination.

# Arguments
- `problem_name::String`: Name of the optimal control problem (e.g., "beam", "robot")
- `bench_id::String`: Benchmark identifier (e.g., "core-ubuntu-latest")
- `bench_title::String`: Human-readable benchmark title (e.g., "Ubuntu Latest CPU")
- `bench_desc::String`: Brief description of the benchmark configuration
- `env_name::String`: Documenter @example environment name (typically "BENCH")
- `src_dir::String`: Path to the docs/src directory

# Returns
- `String`: Markdown template section ready to be written to a .md.template file

# Details
The generated section includes:
1. Section title (## level)
2. Optional description
3. INCLUDE_ENVIRONMENT block for configuration/environment info
4. Performance plots (time vs grid size)
5. Solution figures (automatically detected from figures/ directory)
6. Benchmark log table
"""
function generate_template_problem(
    problem_name::String,
    bench_id::String, 
    bench_title::String,
    bench_desc::String,
    env_name::String,
    src_dir::String,
    )

    # ───────────────────────────────────────────────────────────────────────────
    # Build section title
    # ───────────────────────────────────────────────────────────────────────────
    TITLE = "## " * bench_title * "\n"

    # ───────────────────────────────────────────────────────────────────────────
    # Add optional description
    # ───────────────────────────────────────────────────────────────────────────
    DESC = isempty(bench_desc) ? "" : bench_desc * "\n"
    
    # ───────────────────────────────────────────────────────────────────────────
    # Generate INCLUDE_ENVIRONMENT block
    # This will be replaced by template_processor.jl with actual environment info
    # ───────────────────────────────────────────────────────────────────────────
    ENV = """
    <!-- INCLUDE_ENVIRONMENT:
    BENCH_ID = "$bench_id"
    ENV_NAME = $env_name
    -->
    """

    # ───────────────────────────────────────────────────────────────────────────
    # Generate performance plots section via INCLUDE_FIGURE blocks
    # ───────────────────────────────────────────────────────────────────────────
    RESULTS = """
    ### Time vs Grid Size ($bench_title)

    <!-- INCLUDE_FIGURE:
    FUNCTION = _plot_time_vs_grid_size
    ARGS = $problem_name, $bench_id
    -->

    <!-- INCLUDE_FIGURE:
    FUNCTION = _plot_time_vs_grid_size_bar
    ARGS = $problem_name, $bench_id
    -->
    """

    # ───────────────────────────────────────────────────────────────────────────
    # Auto-detect and generate solution figure blocks
    # ───────────────────────────────────────────────────────────────────────────
    # Scan the figures directory for solution plots (PDF + SVG pairs)
    # and generate clickable image blocks for each grid size N
    figures_dir = joinpath(src_dir, "assets", "benchmarks", bench_id, "figures")
    figure_blocks = String[]

    if isdir(figures_dir)
        files = readdir(figures_dir)
        # Pattern matches files like "beam_N200.pdf"
        pattern = Regex("^" * problem_name * "_N(\\d+)\\.pdf")

        # Store figure blocks indexed by N for sorted output
        blocks_by_N = Dict{Int,String}()
        
        for filename in files
            # Check if filename matches the pattern
            m = match(pattern, filename)
            m === nothing && continue

            # Extract grid size N from filename
            N_str = m.captures[1]
            N = try
                parse(Int, N_str)
            catch
                continue  # Skip if N is not a valid integer
            end

            # Verify that corresponding SVG exists
            base, _ = splitext(filename)  # e.g., "beam_N200"
            svg_name = base * ".svg"
            svg_name in files || continue  # Skip if SVG missing

            # Generate Markdown block with clickable PDF link and SVG preview
            md_block = """
            ### Solution: N = $N ($bench_title)

            ```@raw html
            <a href="../../assets/benchmarks/$bench_id/figures/$base.pdf">
              <img 
                class="centering" 
                width="100%" 
                style="max-width:1400px" 
                src="../../assets/benchmarks/$bench_id/figures/$base.svg"
              />
            </a>
            ```
            """

            blocks_by_N[N] = md_block
        end

        # Sort figure blocks by grid size N (ascending)
        for N in sort(collect(keys(blocks_by_N)))
            push!(figure_blocks, blocks_by_N[N])
        end
    end

    FIGURES = isempty(figure_blocks) ? "" : join(figure_blocks, "\n")

    # ───────────────────────────────────────────────────────────────────────────
    # Generate benchmark log section
    # ───────────────────────────────────────────────────────────────────────────
    LOG = """
    ### Log ($bench_title)

    ```@example $env_name
    _print_benchmark_log("$bench_id"; problems=["$problem_name"]) # hide
    ```"""

    TABLE = """
    <!-- INCLUDE_ANALYSIS:
    FUNCTION = _print_benchmark_table_results
    ARGS = $bench_id, $problem_name
    -->
    """

    # ───────────────────────────────────────────────────────────────────────────
    # Assemble all sections in order
    # ───────────────────────────────────────────────────────────────────────────
    blocks = String[]
    push!(blocks, TITLE)
    isempty(DESC) || push!(blocks, DESC)
    push!(blocks, ENV)
    push!(blocks, RESULTS)
    isempty(FIGURES) || push!(blocks, FIGURES)
    push!(blocks, TABLE)
    push!(blocks, LOG)

    return join(map(x -> x * "\n", blocks), "")
end

# ═══════════════════════════════════════════════════════════════════════════════
# Benchmark Data Query Functions
# ═══════════════════════════════════════════════════════════════════════════════

"""
    is_problem_in_benchmark(bench_id, problem_name, src_dir)

Check if a problem has benchmark results in a given benchmark configuration.

Reads the benchmark JSON file and verifies that the problem has at least one
successful benchmark result.

# Arguments
- `bench_id::String`: Benchmark identifier (e.g., "core-ubuntu-latest")
- `problem_name::String`: Problem name (e.g., "beam", "robot")
- `src_dir::String`: Path to the docs/src directory

# Returns
- `Bool`: `true` if problem has results in this benchmark, `false` otherwise
"""
function is_problem_in_benchmark(bench_id::String, problem_name::String, src_dir::String)
    # Load benchmark data from JSON file
    raw = _get_bench_data(bench_id, src_dir)
    if raw === nothing
        return false
    end

    # Extract results array
    rows = get(raw, "results", Any[])
    if isempty(rows)
        return false
    end

    # Check if problem exists with valid benchmark data
    df = DataFrame(rows)
    df_successful = filter(row -> row.benchmark !== nothing && row.problem == problem_name, df)
    return !isempty(df_successful)
end

"""
    get_problems_in_benchmark(bench_id, src_dir)

Retrieve list of all problems that have results in a given benchmark.

# Arguments
- `bench_id::String`: Benchmark identifier (e.g., "core-ubuntu-latest")
- `src_dir::String`: Path to the docs/src directory

# Returns
- `Vector{String}`: List of unique problem names, or empty vector if no data
"""
function get_problems_in_benchmark(bench_id::String, src_dir::String)
    # Load benchmark data
    raw = _get_bench_data(bench_id, src_dir)
    if raw === nothing
        return []
    end
    
    # Extract results
    rows = get(raw, "results", Any[])
    if isempty(rows)
        return []
    end
    
    # Get unique problem names
    df = DataFrame(rows)
    return unique(df.problem)
end

"""
    get_problems_in_benchmarks(benchmarks, src_dir)

Retrieve all problems that appear in at least one benchmark from a list.

# Arguments
- `benchmarks::Vector{Tuple{String, String, String}}`: List of benchmark configurations
- `src_dir::String`: Path to the docs/src directory

# Returns
- `Vector{String}`: Unique list of problem names across all benchmarks
"""
function get_problems_in_benchmarks(benchmarks::Vector{Tuple{String, String, String}}, src_dir::String)
    problems = String[]
    # Collect problems from each benchmark
    for (bench_id, _, _) in benchmarks
        append!(problems, get_problems_in_benchmark(bench_id, src_dir))
    end
    # Return unique list
    return unique(problems)
end

# ═══════════════════════════════════════════════════════════════════════════════
# Problem-Level Template Generation
# ═══════════════════════════════════════════════════════════════════════════════

"""
    generate_template_problem_from_list(problem_name, benchmarks, title, desc, src_dir; draft)

Generate a complete problem documentation page from multiple benchmark configurations.

Creates a full Markdown template file that includes sections for each benchmark
configuration where the problem has results.

# Arguments
- `problem_name::String`: Problem name (e.g., "beam")
- `benchmarks::Vector{Tuple{String, String, String}}`: List of (bench_id, bench_title, bench_desc) tuples
- `title::String`: Page title (e.g., "Core benchmark: beam")
- `desc::String`: Page description
- `src_dir::String`: Path to the docs/src directory
- `draft::Union{Bool,Nothing}`: Draft mode flag for Documenter

# Returns
- `String`: Complete Markdown template ready to be written to a .md.template file
"""
function generate_template_problem_from_list(
    problem_name::String,
    benchmarks::Vector{Tuple{String, String, String}},
    title::String,
    desc::String,
    src_dir::String;
    draft::Union{Bool,Nothing},
    )

    env_name = "BENCH"
    blocks = String[]

    # Add page title (# level)
    push!(blocks, "# " * title * "\n")

    # Add draft metadata if specified
    DRAFT = draft_meta(draft)
    push!(blocks, DRAFT * "\n")

    # Add page description
    !isempty(desc) && push!(blocks, desc * "\n")

    # Add Documenter @setup block to load utilities and define SRC_DIR
    SETUP = """
    ```@setup $env_name
    # Load utilities
    include(normpath(joinpath(@__DIR__, "..", "..", "assets", "jl", "utils.jl")))
    ```
    """
    push!(blocks, SETUP)

    # Generate sections for each benchmark where the problem has results
    for (bench_id, bench_title, bench_desc) in benchmarks
        if is_problem_in_benchmark(bench_id, problem_name, src_dir)
            @info "  ✓ Generating section for problem '$problem_name' in benchmark '$bench_id'"
            md = generate_template_problem(problem_name, bench_id, bench_title, bench_desc, env_name, src_dir)
            push!(blocks, md)
        end 
    end
    
    return join(blocks, "\n")
end

# ═══════════════════════════════════════════════════════════════════════════════
# High-Level Template Generation
# ═══════════════════════════════════════════════════════════════════════════════

"""
    write_core_benchmark_templates(src_dir, draft, exclude_from_draft)

Generate .md.template files for all core benchmark problems.

Scans all core benchmarks (ubuntu-latest, moonshot-cpu, moonshot-gpu) for available
problems and creates a documentation template file for each one.

# Arguments
- `src_dir::String`: Path to the docs/src directory
- `draft::Union{Bool,Nothing}`: Draft mode for Documenter
- `exclude_from_draft::Vector{Symbol}`: Problems to exclude from draft mode

# Returns
- `Tuple{Vector{String}, String}`: (list of generated file paths, problems directory path)
"""
function write_core_benchmark_templates(
    src_dir::String,
    draft::Union{Bool,Nothing}, 
    exclude_from_draft::Vector{Symbol}
)
    # Create output directory
    problems_dir = joinpath(src_dir, "core", "problems")
    mkpath(problems_dir)

    # Define core benchmark configurations
    benchmarks = [
        ("core-ubuntu-latest", "Ubuntu Latest CPU", "This benchmark suite evaluates optimal control problems on a standard CPU platform using GitHub Actions runners."),
        ("core-moonshot-cpu", "Moonshot CPU", "Results on self-hosted CPU hardware."),
        ("core-moonshot-gpu", "Moonshot GPU", "Results on self-hosted GPU hardware."),
    ]
    
    # Get all problems from all benchmarks
    problems = get_problems_in_benchmarks(benchmarks, src_dir)

    # problems = String[]

    # Generate template file for each problem
    @info "📝 Generating template files for $(length(problems)) problem(s)"
    files_generated = String[]
    for problem_name in problems
        # Check if problem should be excluded from draft mode
        draft_problem = Symbol(problem_name) ∈ exclude_from_draft ? false : draft
        
        # Set page metadata
        title = "Core benchmark: $problem_name"
        desc = """
        This page presents benchmark results for the **$problem_name** problem across different platforms and configurations.

        !!! note
            The linear solver is MUMPS for all experiments."""
        
        # Generate template content
        str = generate_template_problem_from_list(problem_name, benchmarks, title, desc, src_dir; draft=draft_problem)
        @info "  ✓ Generated template for problem '$problem_name' (draft=$(draft_problem))"
        
        # Write to file
        filepath = normpath(joinpath(problems_dir, "$(problem_name).md.template"))
        write(filepath, str)
        push!(files_generated, filepath)
    end
    
    return files_generated, problems_dir
end

"""
    with_processed_template_problems(f, src_dir; draft, exclude_problems_from_draft)

Generate problem templates, execute a function, then clean up.

This function follows a resource management pattern:
1. Generate .md.template files for all problems
2. Execute the provided function with the list of problem names
3. Clean up generated files (guaranteed via finally block)

Used in docs/make.jl to generate templates before building documentation.

# Arguments
- `f::Function`: Function to execute with problem list (typically builds documentation)
- `src_dir::String`: Path to the docs/src directory
- `draft::Union{Bool,Nothing}`: Draft mode for Documenter
- `exclude_problems_from_draft::Vector{Symbol}`: Problems to exclude from draft mode

# Returns
- Return value of `f(core_problems)`
"""
function with_processed_template_problems(
    f::Function,
    src_dir::String;
    draft::Union{Bool,Nothing}=nothing, 
    exclude_problems_from_draft::Vector{Symbol}=Symbol[]
    )
    @info ""
    @info "═"^70
    @info "🚀 Starting template problem generation"
    @info "═"^70
    @info "📋 Draft mode: $(isnothing(draft) ? "default" : draft)"
    @info "📋 Excluded from draft: $(isempty(exclude_problems_from_draft) ? "none" : join(exclude_problems_from_draft, ", "))"
    
    # Generate all template files
    core_files_generated, core_problems_dir = write_core_benchmark_templates(src_dir, draft, exclude_problems_from_draft)
    
    # Extract problem names from file paths
    core_problems = [split(basename(filepath), ".")[1] for filepath in core_files_generated]
    @info "✅ Generated $(length(core_problems)) template(s): $(join(core_problems, ", "))"
    @info "═"^70
    
    try
        # Execute user function with problem list
        return f(core_problems)
    finally
        # Cleanup: remove generated .md.template files (guaranteed to run)
        @info "🧹 Cleaning up generated .md.template files"
        for filepath in core_files_generated
            if isfile(filepath)
                rm(filepath)
                @info "  ✓ Removed: $(basename(filepath))"
            end
        end
        # Only remove directory if it's empty
        if isdir(core_problems_dir) && isempty(readdir(core_problems_dir))
            rm(core_problems_dir)
            @info "  ✓ Removed empty directory: $(basename(core_problems_dir))"
        end
        @info "✅ Cleanup complete"
    end
end