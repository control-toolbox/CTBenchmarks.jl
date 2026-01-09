# DocUtils Developer Guide

This guide explains how to work with the CTBenchmarks.jl documentation template system, including how to create new documentation pages and extend the system with custom visualizations and analysis tools.

## Introduction

The DocUtils template system provides a powerful way to generate dynamic documentation pages that include:

- Benchmark results and analysis
- Performance profiles and plots
- Environment configuration details
- Custom visualizations and tables

The system is built around a **registry pattern** where handlers (functions that generate content) are registered and can be called from template files using special comment blocks.

## Architecture

The DocUtils system is organized into two main categories of modules:

### Core Modules

Core modules provide the infrastructure for template processing and content generation:

- **`TextEngine.jl`**: Registry-based text generation system
  - Manages `TEXT_FUNCTIONS` registry
  - Provides `register_text_handler!()` and `call_text_function()`
  - Handlers return Markdown strings

- **`FigureEngine.jl`**: Registry-based figure generation system
  - Manages `FIGURE_FUNCTIONS` registry
  - Provides `register_figure_handler!()` and `call_figure_function()`
  - Handlers return `Plots.Plot` objects
  - Automatically generates SVG/PDF pairs

- **`TemplateEngine.jl`**: Orchestrates template processing
  - Reads `.template` files
  - Replaces template blocks with generated content
  - Manages figure output and cleanup
  - Provides `with_processed_templates()` for documentation builds

- **`ProfileEngine.jl`**: Performance profile wrappers
  - Manages `PROFILE_REGISTRY` for profile configurations
  - Provides `plot_profile_from_registry()` and `analyze_profile_from_registry()`
  - Wraps `CTBenchmarks.jl` performance profile functionality

- **`TemplateGenerator.jl`**: Auto-generates problem documentation pages
  - Creates `.template` files for benchmark problems
  - Provides `with_processed_template_problems()` for automatic page generation

### Handler Modules

Handler modules implement specific visualization and analysis functions:

- **`DefaultProfiles.jl`**: Standard performance profile configurations
  - Defines `default_cpu` and `default_iter` profiles
  - Initializes `PROFILE_REGISTRY` with standard configurations

- **`PlotTimeVsGridSize.jl`**: Time vs grid size visualizations
  - `_plot_time_vs_grid_size()`: Line plot
  - `_plot_time_vs_grid_size_bar()`: Bar chart

- **`PlotIterationsVsCpuTime.jl`**: Iterations vs CPU time scatter plots
  - `_plot_iterations_vs_cpu_time()`: Scatter plot

- **`PrintBenchmarkResults.jl`**: Benchmark result tables
  - `_print_benchmark_table_results()`: Generates Markdown/HTML tables

- **`PrintEnvConfig.jl`**: Environment configuration display
  - `_print_config()`: Configuration summary
  - `_basic_metadata()`, `_version_info()`, etc.: Environment details

- **`PrintLogResults.jl`**: Benchmark log formatting
  - `_print_benchmark_log()`: Hierarchical log display

### Template Processing Flow

```text
┌─────────────────┐
│  .template file │
│  (Markdown with │
│  special blocks)│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ TemplateEngine  │
│ - Parses blocks │
│ - Extracts args │
└────────┬────────┘
         │
         ├─────────────────┬─────────────────┬─────────────────┐
         ▼                 ▼                 ▼                 ▼
┌────────────────┐ ┌────────────────┐ ┌────────────────┐ ┌────────────────┐
│  TextEngine    │ │ FigureEngine   │ │ ProfileEngine  │ │ (Environment)  │
│  - Looks up    │ │ - Looks up     │ │ - Looks up     │ │ - Direct       │
│    handler in  │ │   handler in   │ │   config in    │ │   substitution │
│    registry    │ │   registry     │ │   registry     │ │                │
│  - Calls func  │ │ - Calls func   │ │ - Calls func   │ │                │
└────────┬───────┘ └────────┬───────┘ └────────┬───────┘ └────────┬───────┘
         │                  │                  │                  │
         ▼                  ▼                  ▼                  ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│  Handler        │ │  Handler        │ │  Handler        │ │  Template       │
│  - Generates    │ │  - Generates    │ │  - Generates    │ │  - Variables    │
│    Markdown     │ │    Plot         │ │    Plot/Text    │ │    replaced     │
└────────┬────────┘ └────────┬────────┘ └────────┬────────┘ └────────┬────────┘
         │                  │                  │                  │
         └──────────────────┴──────────────────┴──────────────────┘
                                    │
                                    ▼
                            ┌───────────────┐
                            │  .md file     │
                            │  (Final       │
                            │  Markdown)    │
                            └───────────────┘
```

## Template Block Reference

Template files use special HTML comment blocks that are replaced with generated content during the documentation build.

### `INCLUDE_ENVIRONMENT`

Includes environment configuration information for a benchmark.

**Syntax**:

```markdown
<!-- INCLUDE_ENVIRONMENT:
BENCH_ID = "core-ubuntu-latest"
ENV_NAME = BENCH
-->
```

**Parameters**:

- `BENCH_ID`: Benchmark identifier (e.g., `"core-ubuntu-latest"`)
- `ENV_NAME`: Documenter `@example` environment name (typically `BENCH`)

**Output**: Markdown block with environment details, configuration, and download links.

---

### `INCLUDE_FIGURE`

Generates a figure using a registered figure handler.

**Syntax**:

```markdown
<!-- INCLUDE_FIGURE:
NAME = plot_time_vs_grid_size
ARGS = beam, core-ubuntu-latest
-->
```

**Parameters**:

- `NAME`: Name of the registered figure handler (without leading underscore)
- `ARGS`: Comma-separated arguments to pass to the handler

**Output**: HTML block with SVG preview and PDF download link.

**Example handlers**:

- `plot_time_vs_grid_size`: Line plot of solve time vs grid size
- `plot_time_vs_grid_size_bar`: Bar chart of solve time vs grid size
- `plot_iterations_vs_cpu_time`: Scatter plot of iterations vs CPU time

---

### `INCLUDE_TEXT`

Generates text content using a registered text handler.

**Syntax**:

```markdown
<!-- INCLUDE_TEXT:
NAME = print_benchmark_table_results
ARGS = core-ubuntu-latest, beam
-->
```

**Parameters**:

- `NAME`: Name of the registered text handler (without leading underscore)
- `ARGS`: Comma-separated arguments to pass to the handler

**Output**: Markdown text (tables, lists, formatted output).

**Example handlers**:

- `print_benchmark_table_results`: Benchmark results table
- `print_benchmark_log`: Formatted benchmark log

---

### `PROFILE_PLOT`

Generates a performance profile plot using a registered profile configuration.

**Syntax**:

```markdown
<!-- PROFILE_PLOT:
NAME = default_cpu
BENCH_ID = core-ubuntu-latest
COMBOS = exa:madnlp, exa:ipopt
-->
```

**Parameters**:

- `NAME`: Name of the registered profile configuration (e.g., `default_cpu`, `default_iter`)
- `BENCH_ID`: Benchmark identifier
- `COMBOS` (optional): Comma-separated `model:solver` pairs to include

**Output**: HTML block with SVG preview and PDF download link.

---

### `PROFILE_ANALYSIS`

Generates textual analysis of a performance profile.

**Syntax**:

```markdown
<!-- PROFILE_ANALYSIS:
NAME = default_cpu
BENCH_ID = core-ubuntu-latest
COMBOS = exa:madnlp, exa:ipopt
-->
```

**Parameters**: Same as `PROFILE_PLOT`

**Output**: Markdown text with profile analysis (winner, statistics, etc.).

---

## Extension Tutorial

This tutorial shows how to add a new visualization or analysis tool to the DocUtils system.

### Creating a Figure Handler

Figure handlers generate plots that can be embedded in documentation.

**Step 1: Create the handler file**

Create a new file in `docs/src/docutils/Handlers/`, e.g., `PlotObjectiveConvergence.jl`:

```julia
# ═══════════════════════════════════════════════════════════════════════════════
# Plot Objective Convergence Module
# ═══════════════════════════════════════════════════════════════════════════════

"""
    _plot_objective_convergence(problem, bench_id, src_dir=SRC_DIR)

Plot objective value convergence for a given problem and benchmark.

# Arguments
- `problem::AbstractString`: Problem name
- `bench_id::AbstractString`: Benchmark identifier
- `src_dir::AbstractString`: Path to docs/src directory (default: SRC_DIR)

# Returns
- `Plots.Plot`: Convergence plot or empty plot if no data
"""
function _plot_objective_convergence(
    problem::AbstractString,
    bench_id::AbstractString,
    src_dir::AbstractString=SRC_DIR
)
    # Load benchmark data
    raw = _get_bench_data(bench_id, src_dir)
    if raw === nothing
        println("⚠️ No data for bench_id: $bench_id")
        return plot()
    end

    # Extract and process data
    rows = get(raw, "results", Any[])
    if isempty(rows)
        println("⚠️ No results in benchmark file")
        return plot()
    end

    df = DataFrame(rows)
    df_problem = filter(row -> row.problem == problem && row.success == true, df)
    
    if isempty(df_problem)
        println("⚠️ No successful runs for problem: $problem")
        return plot()
    end

    # Create plot
    title_font, label_font = _plot_font_settings()
    
    plt = plot(;
        xlabel="Iteration",
        ylabel="Objective Value",
        title="\\nObjective Convergence — $problem",
        legend=:best,
        grid=true,
        size=(900, 600),
        titlefont=title_font,
        xguidefont=label_font,
        yguidefont=label_font,
    )

    # Add data series (example - adapt to your data structure)
    for row in eachrow(df_problem)
        # Extract convergence data from row.benchmark
        # This is problem-specific
        # plot!(iterations, objectives; label=row.solver)
    end

    return plt
end

# ───────────────────────────────────────────────────────────────────────────────
# Registration
# ───────────────────────────────────────────────────────────────────────────────

register_figure_handler!("plot_objective_convergence", _plot_objective_convergence)
```

**Step 2: Include the handler in `CTBenchmarksDocUtils.jl`**

Add to `docs/src/docutils/CTBenchmarksDocUtils.jl`:

```julia
# Include handler modules
include("Handlers/PlotObjectiveConvergence.jl")
```

**Step 3: Use in templates**

In any `.template` file:

```markdown
### Objective Convergence

<!-- INCLUDE_FIGURE:
NAME = plot_objective_convergence
ARGS = beam, core-ubuntu-latest
-->
```

### Creating a Text Handler

Text handlers generate Markdown content (tables, analysis, etc.).

**Step 1: Create the handler file**

Create `docs/src/docutils/Handlers/PrintSolverComparison.jl`:

```julia
# ═══════════════════════════════════════════════════════════════════════════════
# Print Solver Comparison Module
# ═══════════════════════════════════════════════════════════════════════════════

"""
    _print_solver_comparison(bench_id, src_dir=SRC_DIR)

Generate a Markdown table comparing solver performance.

# Arguments
- `bench_id::AbstractString`: Benchmark identifier
- `src_dir::AbstractString`: Path to docs/src directory (default: SRC_DIR)

# Returns
- `String`: Markdown table
"""
function _print_solver_comparison(
    bench_id::AbstractString,
    src_dir::AbstractString=SRC_DIR
)
    bench_data = _get_bench_data(bench_id, src_dir)
    if bench_data === nothing
        return "!!! warning\\n    No benchmark data available.\\n"
    end

    rows = get(bench_data, "results", Any[])
    if isempty(rows)
        return "!!! warning\\n    No results in benchmark file.\\n"
    end

    df = DataFrame(rows)
    
    # Process data and build comparison
    buf = IOBuffer()
    println(buf, "| Solver | Success Rate | Avg Time (s) | Avg Iterations |")
    println(buf, "|:-------|-------------:|-------------:|---------------:|")
    
    for solver in unique(df.solver)
        solver_df = filter(row -> row.solver == solver, df)
        success_rate = count(solver_df.success) / nrow(solver_df) * 100
        
        # Calculate averages (adapt to your data structure)
        avg_time = mean(skipmissing([
            get(row.benchmark, "time", NaN) 
            for row in eachrow(solver_df) if row.success
        ]))
        avg_iters = mean(skipmissing([
            row.iterations 
            for row in eachrow(solver_df) if row.success
        ]))
        
        println(buf, "| `$solver` | $(round(success_rate, digits=1))% | ",
                "$(round(avg_time, digits=3)) | $(round(Int, avg_iters)) |")
    end
    
    return String(take!(buf))
end

# ───────────────────────────────────────────────────────────────────────────────
# Registration
# ───────────────────────────────────────────────────────────────────────────────

register_text_handler!("print_solver_comparison", _print_solver_comparison)
```

**Step 2: Include the handler**

Add to `CTBenchmarksDocUtils.jl`:

```julia
include("Handlers/PrintSolverComparison.jl")
```

**Step 3: Use in templates**

```markdown
### Solver Comparison

<!-- INCLUDE_TEXT:
NAME = print_solver_comparison
ARGS = core-ubuntu-latest
-->
```

### Handler Signature Requirements

**Figure handlers** must:

- Accept string arguments (problem, bench_id, etc.)
- Accept optional `src_dir::AbstractString=SRC_DIR` as last argument
- Return a `Plots.Plot` object
- Return an empty `plot()` if data is unavailable

**Text handlers** must:

- Accept string arguments
- Accept optional `src_dir::AbstractString=SRC_DIR` as last argument
- Return a `String` (Markdown-formatted)
- Return a warning message if data is unavailable

**Important**: The `TemplateEngine` automatically appends `SRC_DIR` as the last argument when calling handlers, so your handler signature should include it with a default value.

### Registration Pattern

All handlers must register themselves using the appropriate registration function:

```julia
# For figure handlers
register_figure_handler!("handler_name", _handler_function)

# For text handlers
register_text_handler!("handler_name", _handler_function)
```

**Convention**:

- Handler function names start with `_` (e.g., `_plot_time_vs_grid_size`)
- Registration uses the name without `_` (e.g., `"plot_time_vs_grid_size"`)
- Both forms are typically registered for backward compatibility

## Debugging

### Enabling Debug Mode

To see detailed logging during template processing, enable debug mode:

```julia
using CTBenchmarksDocUtils

# Enable debug mode
set_doc_debug!(true)

# Process templates with verbose output
with_processed_templates(...) do
    # Documentation build
end

# Disable debug mode
set_doc_debug!(false)
```

**Debug output includes**:

- Template file processing progress
- Block parsing details
- Handler function calls with arguments
- Figure generation status
- File cleanup operations

### Common Issues

**Issue**: `Function 'handler_name' not found in TEXT_FUNCTIONS registry`

**Solution**:

1. Verify the handler is registered: `register_text_handler!("handler_name", _handler_function)`
2. Check that the handler file is included in `CTBenchmarksDocUtils.jl`
3. Ensure the registration code is executed (not inside a conditional)

---

**Issue**: `Template parsing error`

**Solution**:

1. Check block syntax: `<!-- INCLUDE_FIGURE:` (with colon)
2. Ensure closing `-->` is present
3. Verify parameter format: `KEY = value` (one per line)
4. Check for typos in parameter names (`NAME`, `ARGS`, etc.)

---

**Issue**: `Figure generation failed`

**Solution**:

1. Check handler function signature matches template arguments
2. Verify `src_dir` is the last argument with default `SRC_DIR`
3. Test handler function directly in REPL
4. Check for missing data files or incorrect paths
5. Enable debug mode to see detailed error messages

---

**Issue**: `Empty plot generated`

**Solution**:

1. Verify benchmark data exists for the given `bench_id`
2. Check that the problem name matches exactly (case-sensitive)
3. Ensure successful benchmark runs exist in the data
4. Add debug `println()` statements to check data loading

## Best Practices

### Handler Design

1. **Fail gracefully**: Return empty plots or warning messages instead of throwing errors
2. **Validate inputs**: Check for `nothing`, `missing`, and empty data
3. **Use default arguments**: Always include `src_dir::AbstractString=SRC_DIR`
4. **Document thoroughly**: Include docstrings with examples
5. **Test independently**: Handlers should be testable without template processing

### Template Organization

1. **Group related blocks**: Keep environment, figures, and text blocks together
2. **Use descriptive names**: Choose handler names that clearly indicate their purpose
3. **Comment complex templates**: Add HTML comments to explain template structure
4. **Consistent formatting**: Follow existing template conventions

### Performance

1. **Cache expensive computations**: Avoid recomputing the same data multiple times
2. **Minimize file I/O**: Load benchmark data once and reuse
3. **Use efficient data structures**: DataFrames for tabular data, dictionaries for lookups
4. **Profile slow handlers**: Use `@time` or `@benchmark` to identify bottlenecks

## Appendix: Quick Reference

### Template Block Syntax

| Block | Purpose | Required Parameters | Optional Parameters |
|-------|---------|---------------------|---------------------|
| `INCLUDE_ENVIRONMENT` | Environment info | `BENCH_ID`, `ENV_NAME` | - |
| `INCLUDE_FIGURE` | Custom figure | `NAME`, `ARGS` | - |
| `INCLUDE_TEXT` | Custom text | `NAME`, `ARGS` | - |
| `PROFILE_PLOT` | Profile plot | `NAME`, `BENCH_ID` | `COMBOS` |
| `PROFILE_ANALYSIS` | Profile analysis | `NAME`, `BENCH_ID` | `COMBOS` |

### Registration Functions

```julia
# Text handlers
register_text_handler!(name::String, func::Function)

# Figure handlers
register_figure_handler!(name::String, func::Function)

# Profile configurations
CTBenchmarks.register!(PROFILE_REGISTRY, name::String, config::PerformanceProfileConfig)
```

### Utility Functions

```julia
# Get benchmark data
_get_bench_data(bench_id::String, src_dir::String) -> Union{Dict, Nothing}

# Plot font settings
_plot_font_settings() -> (title_font, label_font)

# Debug mode
set_doc_debug!(enabled::Bool)
```

### Example Handler Signatures

```julia
# Figure handler
function _my_plot(problem::AbstractString, bench_id::AbstractString, src_dir::AbstractString=SRC_DIR)
    # ... implementation
    return plt
end

# Text handler
function _my_analysis(bench_id::AbstractString, src_dir::AbstractString=SRC_DIR)
    # ... implementation
    return markdown_string
end

# Text handler with optional argument
function _my_table(bench_id::AbstractString, problem::Union{Nothing,AbstractString}=nothing, src_dir::AbstractString=SRC_DIR)
    # ... implementation
    return markdown_string
end
```
