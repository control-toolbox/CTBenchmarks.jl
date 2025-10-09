# todo: check solver return status, number of iterations...

using OptimalControlProblems
using OptimalControl
import JuMP
using Ipopt
using NLPModelsIpopt 
using MadNLPMumps
using BenchmarkTools

solver = :ipopt
print_level = 0 # solver dependent
disc_method = :trapeze # only available method for JuMP
problem = :space_shuttle # should loop on problems

println("problem: $problem, solver: $solver, disc_method: $disc_method")

for N ∈ [100, 200, 500]

    println("\nN      :   $N")

    # JuMP
    print("JuMP   : ")
    nlp = eval(problem)(JuMPBackend(); grid_size=N)
    JuMP.set_optimizer(nlp, Ipopt.Optimizer) # update for MadNLP
    JuMP.set_optimizer_attribute(nlp, "print_level", print_level)
    @btime JuMP.optimize!($nlp)
    
    # adnlp
    print("adnlp  : ")
    docp = eval(Symbol(problem, :_s))(OptimalControlBackend(), :adnlp, solver; grid_size=N, disc_method=disc_method)
    nlp = nlp_model(docp)
    @btime eval(solver)($nlp; print_level=$print_level)
    
    # exa
    print("exa    : ")
    docp = eval(Symbol(problem, :_s))(OptimalControlBackend(), :exa, solver; grid_size=N, disc_method=disc_method)
    nlp = nlp_model(docp)
    @btime eval(solver)($nlp; print_level=$print_level)
    
end