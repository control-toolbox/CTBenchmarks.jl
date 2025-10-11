# todo: check solver return status, number of iterations, objective value

using OptimalControlProblems
using OptimalControl
import JuMP
import Ipopt
import NLPModelsIpopt 
using MadNLPMumps
using CUDA
using MadNLPGPU
using BenchmarkTools

cuda_on = CUDA.functional()

# Options 

disc_method = :trapeze # fixed method for JuMP
tol = 1e-8

#solver = :ipopt
solver = :madnlp

if solver == :ipopt
    mu_strategy = "adaptive"
    print_level = 0 # 5
elseif solver == :madnlp
    print_level = MadNLP.ERROR # MadNLP.INFO
else
    error("undefined solver: $solver")  
end

# Main loop

for problem ∈ [:beam,
               #:chain,
               #:double_oscillator,
               #:ducted_fan,
               #:electric_vehicle,
               #:glider,
               #:insurance,
               #:glider,
               #:jackson,
               #:robbins,
               #:robot,
               #:rocket,
               #:space_shuttle,
               #:steering,
               #:vanderpol,
               ]

    println("\nproblem: $problem, solver: $solver, disc_method: $disc_method")
    
    #for N ∈ [100, 200, 500]
    for N ∈ [100]
    
        println("\nN      :   $N")
    
        # JuMP
        print("JuMP   : ")
        nlp = eval(problem)(JuMPBackend(); grid_size=N)
        if solver == :ipopt
            JuMP.set_optimizer(nlp, Ipopt.Optimizer)
            JuMP.set_optimizer_attribute(nlp, "tol", tol)
            JuMP.set_optimizer_attribute(nlp, "mu_strategy", mu_strategy)
            JuMP.set_optimizer_attribute(nlp, "print_level", print_level)
        elseif solver == :madnlp
            JuMP.set_optimizer(nlp, MadNLP.Optimizer)
            JuMP.set_optimizer_attribute(nlp, "tol", tol)
            JuMP.set_optimizer_attribute(nlp, "print_level", print_level)
        else
            error("undefined solver: $solver")
        end
        @btime JuMP.optimize!($nlp)
        
        # adnlp
        print("adnlp  : ")
        docp = eval(Symbol(problem, :_s))(OptimalControlBackend(), :adnlp, solver; grid_size=N, disc_method=disc_method)
        nlp = nlp_model(docp)
        if solver == :ipopt
            opt = (tol=tol, mu_strategy=mu_strategy, print_level=print_level)
        elseif solver == :madnlp
            opt = (tol=tol, print_level=print_level)
        else
            error("undefined solver: $solver")
        end
        @btime eval(solver)($nlp; $opt...)

        # exa
        print("exa    : ")
        docp = eval(Symbol(problem, :_s))(OptimalControlBackend(), :exa, solver; grid_size=N, disc_method=disc_method)
        nlp = nlp_model(docp)
        @btime eval(solver)($nlp; $opt...)

        # exa  GPU
        if cuda_on
            print("exa GPU: ")
            docp = eval(Symbol(problem, :_s))(OptimalControlBackend(), :exa, solver; grid_size=N, disc_method=disc_method)
            nlp = nlp_model(docp)
            eval(solver)(nlp; opt..., exa_backend=CUDABackend());
            CUDA.@time eval(solver)(nlp; opt..., exa_backend=CUDABackend())
        end
        
    end

end