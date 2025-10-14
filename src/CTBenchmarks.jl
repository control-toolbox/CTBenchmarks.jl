module CTBenchmarks

# Core utilities
using Dates                     # Date and time functionality
using JSON                      # JSON serialization/deserialization
using InteractiveUtils          # Interactive utilities (e.g., versioninfo)
import Pkg                     # Package manager utilities
using Sockets                   # Network socket support
using Printf                    # String formatting

# Benchmarking and optimization
using OptimalControlProblems    # Standard optimal control problems
using OptimalControl            # Optimal control problem definition and solving
using BenchmarkTools            # Performance benchmarking tools
using DataFrames                # Tabular data structures
using Tables                    # Tables interface for data manipulation

# Optimization backends
import JuMP                     # Julia Mathematical Programming
import Ipopt                    # Interior Point OPTimizer
import NLPModelsIpopt           # NLPModels interface to Ipopt
using MadNLPMumps               # MadNLP with MUMPS linear solver
using MadNLPGPU                 # MadNLP with GPU support
using CUDA                      # CUDA GPU support

include("utils.jl")
include("print.jl")

export benchmark, benchmark_data

end # module