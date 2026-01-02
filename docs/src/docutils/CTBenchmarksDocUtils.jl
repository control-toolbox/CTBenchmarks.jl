"""
    CTBenchmarksDocUtils

Main module for CTBenchmarks documentation utilities.

This module provides all the functions needed for generating and processing
benchmark documentation, including:
- Template generation and processing
- Figure generation (PNG/PDF)
- Performance profile plotting
- Environment configuration display
- Benchmark log printing

# Exported Functions

## Template System
- `with_processed_templates`: Process template files with INCLUDE_ENVIRONMENT/INCLUDE_FIGURE blocks
- `with_processed_template_problems`: Generate and process problem-specific templates

## Plotting Functions (for use in @example blocks)
- `_plot_profile_default_cpu`: Plot default CPU-time performance profiles for a benchmark
- `_plot_profile_default_iter`: Plot default iterations performance profiles for a benchmark
- `_plot_time_vs_grid_size`: Plot solve time vs grid size
- `_plot_time_vs_grid_size_bar`: Bar plot of solve time vs grid size

## Environment Display Functions (for use in @example blocks)
- `_print_config`: Print benchmark configuration
- `_basic_metadata`: Display basic metadata (timestamp, Julia version, OS)
- `_downloads_toml`: Generate download links for environment files
- `_version_info`: Display benchmark data (Julia version, packages)
- `_package_status`: Display package status table
- `_complete_manifest`: Display complete manifest

## Log Display Functions (for use in @example blocks)
- `_print_benchmark_log`: Print benchmark execution log

## Debug and Logging
- `set_doc_debug!`: Enable or disable debug logging for documentation
  utilities. When debug mode is on, additional per-block messages and full
  stacktraces are printed during template and figure generation.

## Submodules
- `DocumenterReference`: Module for automatic API reference generation
  - Use `DocumenterReference.automatic_reference_documentation(...)` to generate API docs
"""
module CTBenchmarksDocUtils

# ═══════════════════════════════════════════════════════════════════════════════
# Dependencies
# ═══════════════════════════════════════════════════════════════════════════════

using CTBenchmarks
using JSON
using DataFrames
using Markdown
using Dates
using Printf
using Plots
using Plots.PlotMeasures
using Statistics
using SHA
using Documenter

# ═══════════════════════════════════════════════════════════════════════════════
# Include submodules
# ═══════════════════════════════════════════════════════════════════════════════

include(joinpath(@__DIR__, "modules", "Common.jl"))
include(joinpath(@__DIR__, "modules", "PrintEnvConfig.jl"))
include(joinpath(@__DIR__, "modules", "PrintLogResults.jl"))
include(joinpath(@__DIR__, "modules", "PerformanceProfileCore.jl"))
include(joinpath(@__DIR__, "modules", "PlotPerformanceProfile.jl"))
include(joinpath(@__DIR__, "modules", "PlotTimeVsGridSize.jl"))
include(joinpath(@__DIR__, "modules", "PlotIterationsVsCpuTime.jl"))
include(joinpath(@__DIR__, "modules", "FigureGeneration.jl"))
include(joinpath(@__DIR__, "modules", "PrintBenchmarkResults.jl"))
include(joinpath(@__DIR__, "modules", "AnalyzePerformanceProfile.jl"))
include(joinpath(@__DIR__, "modules", "TextGeneration.jl"))
include(joinpath(@__DIR__, "modules", "TemplateProcessor.jl"))
include(joinpath(@__DIR__, "modules", "TemplateGenerator.jl"))
include(joinpath(@__DIR__, "modules", "DocumenterReference.jl"))

# Make DocumenterReference submodule available
using .DocumenterReference

# ═══════════════════════════════════════════════════════════════════════════════
# Shared Constants
# ═══════════════════════════════════════════════════════════════════════════════

# Path to docs/src directory (used by all wrapper functions)
const SRC_DIR = normpath(joinpath(@__DIR__, ".."))
const DOC_DEBUG = Ref(false)

function set_doc_debug!(flag::Bool)
    DOC_DEBUG[] = flag
    return nothing
end

# ═══════════════════════════════════════════════════════════════════════════════
# Wrapper Functions (no src_dir parameter needed in templates)
# ═══════════════════════════════════════════════════════════════════════════════

# Analysis functions
function _analyze_profile_default_cpu(
    bench_id::AbstractString; combos::Union{Nothing,Vector{Tuple{String,String}}}=nothing
)
    return _analyze_profile_default_cpu(bench_id, SRC_DIR; allowed_combos=combos)
end

function _analyze_profile_default_iter(
    bench_id::AbstractString; combos::Union{Nothing,Vector{Tuple{String,String}}}=nothing
)
    return _analyze_profile_default_iter(bench_id, SRC_DIR; allowed_combos=combos)
end

function _print_benchmark_table_results(
    bench_id::AbstractString; problems::Union{Nothing,Vector{<:AbstractString}}=nothing
)
    return _print_benchmark_table_results(bench_id, SRC_DIR; problems=problems)
end

# Plotting functions
function _plot_profile_default_cpu(
    bench_id::AbstractString; combos::Union{Nothing,Vector{Tuple{String,String}}}=nothing
)
    return _plot_profile_default_cpu(bench_id, SRC_DIR; allowed_combos=combos)
end

function _plot_profile_default_iter(
    bench_id::AbstractString; combos::Union{Nothing,Vector{Tuple{String,String}}}=nothing
)
    return _plot_profile_default_iter(bench_id, SRC_DIR; allowed_combos=combos)
end

function _plot_time_vs_grid_size(problem::AbstractString, bench_id::AbstractString)
    return _plot_time_vs_grid_size(problem, bench_id, SRC_DIR)
end

function _plot_time_vs_grid_size_bar(problem::AbstractString, bench_id::AbstractString)
    return _plot_time_vs_grid_size_bar(problem, bench_id, SRC_DIR)
end

function _plot_iterations_vs_cpu_time(problem::AbstractString, bench_id::AbstractString)
    return _plot_iterations_vs_cpu_time(problem, bench_id, SRC_DIR)
end

function _plot_profile_midpoint_trapeze_exa(
    bench_id::AbstractString; combos::Union{Nothing,Vector{Tuple{String,String}}}=nothing
)
    return _plot_profile_default_iter(bench_id, SRC_DIR; allowed_combos=combos)
end

# Environment display functions
function _print_config(bench_id::AbstractString)
    return _print_config(bench_id, SRC_DIR)
end

function _basic_metadata(bench_id::AbstractString)
    return _basic_metadata(bench_id, SRC_DIR)
end

function _downloads_toml(bench_id::AbstractString, file_dir::AbstractString)
    return _downloads_toml(bench_id, SRC_DIR, file_dir)
end

function _version_info(bench_id::AbstractString)
    return _version_info(bench_id, SRC_DIR)
end

function _package_status(bench_id::AbstractString)
    return _package_status(bench_id, SRC_DIR)
end

function _complete_manifest(bench_id::AbstractString)
    return _complete_manifest(bench_id, SRC_DIR)
end

# Log display functions
function _print_benchmark_log(
    bench_id::AbstractString; problems::Union{Nothing,Vector{<:AbstractString}}=nothing
)
    return _print_benchmark_log(bench_id, SRC_DIR; problems=problems)
end

# ═══════════════════════════════════════════════════════════════════════════════
# Exports
# ═══════════════════════════════════════════════════════════════════════════════

# Template system
export with_processed_templates
export with_processed_template_problems
export set_doc_debug!

# Plotting functions (used in templates)
export _plot_profile_default_cpu
export _plot_profile_default_iter
export _plot_time_vs_grid_size
export _plot_time_vs_grid_size_bar
export _plot_iterations_vs_cpu_time
export _plot_profile_midpoint_trapeze_exa

# Text/analysis functions (used by INCLUDE_TEXT blocks)
export _analyze_profile_default_cpu
export _analyze_profile_default_iter
export _print_benchmark_table_results

# Environment display functions (used in templates)
export _print_config
export _basic_metadata
export _downloads_toml
export _version_info
export _package_status
export _complete_manifest

# Log display functions (used in templates)
export _print_benchmark_log

# Export DocumenterReference submodule
export DocumenterReference

end # module CTBenchmarksDocUtils
