"""
    CTBenchmarksDocUtils

Main module for CTBenchmarks documentation utilities.

This module provides all the functions needed for generating and processing
benchmark documentation, including:
- Template generation and processing with specialized block syntax
- Figure generation (SVG/PDF)
- Performance profile plotting and analysis
- Environment configuration display
- Benchmark log printing

# Template Block Syntax

The template system supports several specialized block types:

## INCLUDE_ENVIRONMENT
Inserts environment configuration information (Julia version, packages, etc.)

## PROFILE_PLOT
Generates performance profile plots using the profile registry.
Parameters: NAME (profile name), BENCH_ID (benchmark ID), COMBOS (optional solver combinations)

## PROFILE_ANALYSIS
Generates textual analysis of performance profiles using the profile registry.
Parameters: NAME (profile name), BENCH_ID (benchmark ID), COMBOS (optional solver combinations)

## INCLUDE_FIGURE
Generic figure generation for custom plotting functions.
Parameters: FUNCTION (function name), ARGS (comma-separated arguments)

## INCLUDE_TEXT
Generic text generation for custom analysis functions.
Parameters: FUNCTION (function name), ARGS (comma-separated arguments)

# Exported Functions

## Template System
- `with_processed_templates`: Process template files with specialized block syntax
- `with_processed_template_problems`: Generate and process problem-specific templates

## Plotting Functions (for use in @example blocks)
- `_plot_time_vs_grid_size`: Plot solve time vs grid size
- `_plot_time_vs_grid_size_bar`: Bar plot of solve time vs grid size
- `_plot_iterations_vs_cpu_time`: Plot iterations vs CPU time

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

# Shared Constants
# Path to docs/src directory (used by all wrapper functions)
const SRC_DIR = normpath(joinpath(@__DIR__, ".."))
const DOC_DEBUG = Ref(false)

function set_doc_debug!(flag::Bool)
    DOC_DEBUG[] = flag
    return nothing
end

# ═══════════════════════════════════════════════════════════════════════════════
# Include submodules
# ═══════════════════════════════════════════════════════════════════════════════

include(joinpath(@__DIR__, "modules", "Common.jl"))
include(joinpath(@__DIR__, "ProfileRegistry.jl"))

# Initialize registry with standard documentation profiles
init_default_profiles!()

include(joinpath(@__DIR__, "modules", "PrintEnvConfig.jl"))
include(joinpath(@__DIR__, "modules", "PrintLogResults.jl"))
include(joinpath(@__DIR__, "modules", "PlotTimeVsGridSize.jl"))
include(joinpath(@__DIR__, "modules", "PlotIterationsVsCpuTime.jl"))
include(joinpath(@__DIR__, "modules", "FigureGeneration.jl"))
include(joinpath(@__DIR__, "modules", "PrintBenchmarkResults.jl"))
include(joinpath(@__DIR__, "modules", "TextGeneration.jl"))
include(joinpath(@__DIR__, "modules", "TemplateProcessor.jl"))
include(joinpath(@__DIR__, "modules", "TemplateGenerator.jl"))
include(joinpath(@__DIR__, "modules", "DocumenterReference.jl"))

# Make DocumenterReference submodule available
using .DocumenterReference

# ═══════════════════════════════════════════════════════════════════════════════
# Wrapper Functions (no src_dir parameter needed in templates)
# ═══════════════════════════════════════════════════════════════════════════════

# Analysis functions
function _print_benchmark_table_results(
    bench_id::AbstractString; problems::Union{Nothing,Vector{<:AbstractString}}=nothing
)
    return _print_benchmark_table_results(bench_id, SRC_DIR; problems=problems)
end

# Plotting functions

function _plot_time_vs_grid_size(problem::AbstractString, bench_id::AbstractString)
    return _plot_time_vs_grid_size(problem, bench_id, SRC_DIR)
end

function _plot_time_vs_grid_size_bar(problem::AbstractString, bench_id::AbstractString)
    return _plot_time_vs_grid_size_bar(problem, bench_id, SRC_DIR)
end

function _plot_iterations_vs_cpu_time(problem::AbstractString, bench_id::AbstractString)
    return _plot_iterations_vs_cpu_time(problem, bench_id, SRC_DIR)
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
export _plot_time_vs_grid_size
export _plot_time_vs_grid_size_bar
export _plot_iterations_vs_cpu_time

# Text/analysis functions (used by INCLUDE_TEXT blocks)
export _print_benchmark_table_results

# Registry-based functions
export PROFILE_REGISTRY
export plot_profile_from_registry
export analyze_profile_from_registry

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
