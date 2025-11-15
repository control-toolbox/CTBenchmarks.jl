module CTBenchmarks

# Core utilities
using DocStringExtensions       # Docstring extensions
using Dates                     # Date and time functionality
using JSON                      # JSON serialization/deserialization
using InteractiveUtils          # Interactive utilities (e.g., versioninfo)
using CTBase                    # Common exceptions and shared utilities
using Pkg: Pkg                  # Package manager utilities
using Sockets                   # Network socket support
using Printf                    # String formatting

# Benchmarking and optimization
using OptimalControlProblems    # Standard optimal control problems
using OptimalControl            # Optimal control problem definition and solving
using BenchmarkTools            # Performance benchmarking tools
using DataFrames                # Tabular data structures
using Tables                    # Tables interface for data manipulation

# Optimization backends
using JuMP: JuMP                        # Julia Mathematical Programming
using Ipopt: Ipopt                      # Interior Point OPTimizer
using NLPModelsIpopt: NLPModelsIpopt    # NLPModels interface to Ipopt
using MadNLPMumps                       # MadNLP with MUMPS linear solver
using MadNLPGPU                         # MadNLP with GPU support
using CUDA                              # CUDA GPU support

# Plots
using Plots
using Plots.PlotMeasures

const ITERATION = Ref{Int}(0)

include("utils.jl")
include("print.jl")
include("run.jl")
include("plot_solutions.jl")

end # module