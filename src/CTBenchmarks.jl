module CTBenchmarks

# Core utilities
using Dates                     # Date and time functionality
using JSON                      # JSON serialization/deserialization
using InteractiveUtils          # Interactive utilities (e.g., versioninfo)
using Sockets                   # Network socket support

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

include("benchmark-minimal.jl")

export benchmark_minimal, benchmark_minimal_data

end # module