using OptimalControlProblems
using OptimalControl
import JuMP
using Ipopt
using NLPModelsIpopt 
using MadNLPMumps
using BenchmarkTools

solver = :ipopt
disc_method = :trapeze
print_level = 0
problem = :space_shuttle

for N ∈ [100, 500]

    println("\nN    :   $N")

    # JuMP
    print("JuMP : ")
    nlp = eval(problem)(JuMPBackend(); grid_size=N)
    JuMP.set_optimizer(nlp, Ipopt.Optimizer)
    JuMP.set_optimizer_attribute(nlp, "print_level", print_level)
    @btime JuMP.optimize!($nlp)
    
    # adnlp
    print("adnlp: ")
    docp = eval(Symbol(problem, :_s))(OptimalControlBackend(), :adnlp, solver; grid_size=N, disc_method=disc_method)
    nlp = nlp_model(docp)
    @btime eval(solver)($nlp; print_level=$print_level)
    
    # exa
    print("exa  : ")
    docp = eval(Symbol(problem, :_s))(OptimalControlBackend(), :exa, solver; grid_size=N, disc_method=disc_method)
    nlp = nlp_model(docp)
    @btime eval(solver)($nlp; print_level=$print_level)
    
end