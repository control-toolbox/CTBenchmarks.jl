"""
 CTBenchmarks

 Benchmark and visualise optimal control solvers on a suite of standard problems.

 CTBenchmarks provides high-level utilities to run reproducible benchmark suites over
 multiple models (JuMP, ADNLP, Exa, Exa-GPU) and solvers (Ipopt, MadNLP), collect
 results, and generate plots for solution trajectories and performance summaries.

 # Main functions

 - `run`: Execute a predefined benchmark suite (`:complete` or `:minimal`)
 - `benchmark`: Low-level benchmarking API with full configuration
 - `plot_solutions`: Generate PDF plots comparing solutions for each problem/grid size

 # Example

 ```julia-repl
 julia> using CTBenchmarks

 julia> results = run(:minimal)

 julia> plot_solutions(results, "plots/")
 ```
 """
module CTBenchmarks

# Core utilities
using DocStringExtensions               # Docstring extensions
using Dates                             # Date and time functionality
using JSON                              # JSON serialization/deserialization
using InteractiveUtils                  # Interactive utilities (e.g., versioninfo)
using CTBase                            # Common exceptions and shared utilities
using Pkg: Pkg                          # Package manager utilities
using Sockets                           # Network socket support
using Printf                            # String formatting

# Benchmarking and optimization
using OptimalControlProblems            # Standard optimal control problems
using OptimalControl                    # Optimal control problem definition and solving
using BenchmarkTools                    # Performance benchmarking tools
using DataFrames                        # Tabular data structures
using Tables                            # Tables interface for data manipulation

# Optimization backends
using JuMP: JuMP                        # Julia Mathematical Programming
using Ipopt: Ipopt                      # Interior Point OPTimizer
using NLPModelsIpopt: NLPModelsIpopt    # NLPModels interface to Ipopt
using MadNLPMumps                       # MadNLP with MUMPS linear solver
using MadNLPGPU                         # MadNLP with GPU support
using CUDA                              # CUDA GPU support

# Plots
using Plots                             # Plots.jl for visualization
using Plots.PlotMeasures                # PlotMeasures for Plots.jl

"""
    ITERATION::Base.RefValue{Int}

Internal counter used to track how many times the JuMP solve loop has been executed,
in order to adjust the solver print level after the first iteration.
"""
const ITERATION = Ref{Int}(0)

include("utils.jl")
include("print.jl")
include("run.jl")
include("plot_solutions.jl")

export run, benchmark, plot_solutions

end # module