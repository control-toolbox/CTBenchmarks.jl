module Problems

include("OptimalControl/OCProblems.jl")
include("JuMP/JMPProblems.jl")

using DataFrames

export JMPProblems, OCProblems

path = dirname(@__FILE__)
files = filter(x -> x[(end - 2):end] == ".jl", readdir(path * "/ProblemsData"))
for file in files
  include("ProblemsData/" * file)
end

number_of_problems = length(files)


"""
The following keys are valid:
  - `name::String`: problem name
  - `minimize::Bool`: true if optimize == minimize  
  - `nature::Symbol`: nature of the problem, in [:mayer, :lagrange, :bolza]
  - `nvar::Int`: number of variables
  - `ncon::Int`: number of constraints
  - `has_equalities_only::Bool`: true if the problem has constraints, and all are equality constraints (doesn't include bounds)
  - `has_inequalities_only::Bool`: true if the problem has constraints, and all are inequality constraints (doesn't include bounds)
  - `has_bounds::Bool`: true if the problem has bound constraints
  - `origin::Symbol`: origin of the problem, in [:academic, :modelling, :real, :unknown]
"""

const names = [
  :name
  :minimize
  :nature
  :nvar
  :ncon
  :has_equalities_only
  :has_inequalities_only
  :has_bounds
  :origin
]

const types = [
  String
  Bool
  Symbol
  Int
  Int
  Bool
  Bool
  Bool
  Symbol
]

const meta = DataFrame(names .=> [Array{T}(undef, number_of_problems) for T in types])

for name in names, i = 1:number_of_problems
  meta[!, name][i] = eval(Meta.parse("$(split(files[i], ".")[1])_data"))[name]
end


end
