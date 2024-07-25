module Benchmark

import Pkg
path = dirname(@__FILE__)
Pkg.activate(path*"/../");
include(path*"/../Problems/JuMP/JMPProblems.jl");
include(path*"/../Problems/OptimalControl/OCProblems.jl");

using MKL
using BenchmarkTools
using .JMPProblems
using .OCProblems

include(path*"./Benchmark_OC.jl")
include(path*"./Benchmark_JuMP.jl")
include(path*"./Benchmark_model.jl")
include(path*"./Benchmark_Callbacks.jl")

using JuMP , Ipopt
using OptimalControl, NLPModelsIpopt
import HSL_jll
using NLPModels, NLPModelsJuMP

using PrettyTables, Colors
using DataFrames

nb_discr_list = [100;500]
excluded_models = [:space_shuttle; :quadrotor1obs; :quadrotorp2p; :truck; :moonlander; :glider]

# JIT warm-up for the first run
# Redirect stdout and stderr to /dev/null
original_stdout = stdout
original_stderr = stderr
null_device = get(ENV, "OS", "") == "Windows_NT" ? "NUL" : "/dev/null"
redirect_stdout(open(null_device, "w"))
redirect_stderr(open(null_device, "w"))

try
    # dummy run for OC and JuMP
    benchmark_model(:rocket,OCProblems.function_init, [2])
finally
    # Restore original stdout and stderr
    redirect_stdout(original_stdout)
    redirect_stderr(original_stderr)
end

function uniflag(flag)
    if flag == MOI.LOCALLY_SOLVED || flag == "Solve_Succeeded" || flag == MOI.OPTIMAL
        return "Solve Succeeded"
    elseif flag == MOI.ITERATION_LIMIT || flag == "Maximum_Iterations_Exceeded"
        return "Iterations Exceeded"
    elseif flag == MOI.LOCALLY_INFEASIBLE || flag == "Infeasible_Problem_Detected"
        return "Infeasible Problem"
    elseif flag == MOI.INVALID_MODEL || flag == "Invalid Model"
        return "Invalid Model"
    end
    return "UNI ? "*string(flag)
end

function display_Benchmark(Results, title, file_name, parameter_value)
    # Print the results
    #println("---------- Results : ")
    table = DataFrame(:Model => Symbol[], :nb_discr => Any[], :nvar => Any[], :ncon => Any[], :nb_iter => Any[], :total_time => Any[], :Ipopt_time => Any[], :obj_value => Any[], :flag => Any[])
    ex=[]
    for (k,v) in Results
        if length(v) > 0
            for i in v
                push!(table, [k; i.nb_discr[1]; i.nvar; i.ncon; i.nb_iter[1]; round(i.total_time[1],digits=2); round(i.Ipopt_time[1],digits=2); i.obj_value[1]; uniflag(i.flag[1])])
            end
        else
            push!(ex, [k])
        end
    end
    for i in ex
        push!(table, [i; NaN; NaN; NaN; NaN; NaN; NaN; NaN; "NaN"])
    end
    # Define the custom display
    header = ["Model","Discretization", "Variables","Constraints", "Iterations", "Total Time", "Ipopt Time" ,"Objective Value", "Flag"];
    hl_flags = LatexHighlighter( (table, i, j) -> ((j == 9) && (table[i, j] != "Solve Succeeded") && (table[i, j] != "NaN")),
                            ["color{red}"]
                        );
    original_stdout = stdout
    file = open("./outputs/$(file_name)", "w")
    try
        redirect_stdout(file)
        println("\\documentclass{standalone}")
        println("\\usepackage{color}")
        println("\\usepackage{booktabs}")
        println("\\begin{document}")
        println("\\begin{tabular}{c}")
        println("\\Large\\textbf{$title}\\\\")
        println("\\large\\textbf{$parameter_value}\\\\")
        pretty_table(
            table;
            (backend = Val(:latex)),
            header        = header,
            title = title,
            title_alignment = :c,
            alignment = :c,
            highlighters  = (hl_flags,)
        )
        println("\\end{tabular}")
        println("\\end{document}")
    finally
        redirect_stdout(original_stdout)
        close(file)
    end
end 


function display_Callbacks(Results, title, file_name)
    table = DataFrame(:Model => Symbol[], :nb_discr => Any[], :nnzh => Any[], :nnzj => Any[], 
                        :t_obj => Any[], :t_grad => Any[], :t_cons => Any[], :t_jac => Any[], :t_hess => Any[])
    for (k,v) in Results
        for i in v
            push!(table, [k; i.nb_discr[1]; i.nnzh; i.nnzj; round(i.t_obj[1]*1e3,digits=2); round(i.t_grad[1]*1e3,digits=2); round(i.t_cons[1]*1e3,digits=2); round(i.t_jac[1]*1e3,digits=2); round(i.t_hess[1]*1e3,digits=2)])
            #push!(table, [k; i.nb_discr[1]; i.nnzh; i.nnzj; i.t_obj[1]; i.t_grad[1]; i.t_cons[1]; i.t_jac[1]; i.t_hess[1]])
        end
    end
    # Define the custom display
    header = ["Model","Discretization", "nnz Hessian", "nnz Jacobian", "Time Obj(ms)", "Time Grad(ms)", "Time Cons(ms)", "Time Jac(ms)", "Time Hess(ms)"];
    original_stdout = stdout
    file = open("./outputs/$(file_name)", "w")
    try
        redirect_stdout(file)
        println("\\documentclass{standalone}")
        println("\\usepackage{color}")
        println("\\usepackage{booktabs}")
        println("\\begin{document}")
        println("\\begin{tabular}{c}")
        println("\\Large\\textbf{$title}\\\\")
        pretty_table(
            table;
            (backend = Val(:latex)),
            header        = header,
            title = title,
            title_alignment = :c,
            alignment = :c,
        )
        println("\\end{tabular}")
        println("\\end{document}")
    finally
        redirect_stdout(original_stdout)
        close(file)
    end
end


function Benchmark_OC(nb_discr_list=nb_discr_list, excluded_models=excluded_models;max_iter=1000, tol=1e-8, constr_viol_tol = 1e-6,solver="ma57",display=false)
    Results = benchmark_all_models_OC(OCProblems.function_OC,OCProblems.function_init ,nb_discr_list, excluded_models;max_iter=max_iter, tol=tol, constr_viol_tol = constr_viol_tol,solver=solver,display=display)
    title = "Benchmark OptimalControl Results"
    file_name = "OptimalControl_Benchmark_file.tex"
    parameter_value = "max iter = $max_iter, tol = $tol, constr viol tol = $constr_viol_tol, solver = $solver"
    display_Benchmark(Results, title, file_name,parameter_value)
end

function Benchmark_JuMP(nb_discr_list=nb_discr_list, excluded_models=excluded_models;max_iter=1000, tol=1e-8, constr_viol_tol = 1e-6,solver="ma57",display=false)
    Results = benchmark_all_models_JuMP(JMPProblems.function_JMP, nb_discr_list, excluded_models;max_iter=max_iter, tol=tol, constr_viol_tol = constr_viol_tol,solver=solver,display=display)
    title = "Benchmark JuMP Results"
    file_name = "JuMP_Benchmark_file.tex"
    parameter_value = "max iter = $max_iter, tol = $tol, constr viol tol = $constr_viol_tol, solver = $solver"
    display_Benchmark(Results, title, file_name,parameter_value)
end

function Benchmark_model(model_key, nb_discr_list=nb_discr_list;max_iter=1000, tol=1e-8, constr_viol_tol = 1e-6,solver="ma57",display=false)
    Results = benchmark_model(model_key, OCProblems.function_init ,nb_discr_list;max_iter=max_iter, tol=tol, constr_viol_tol = constr_viol_tol,solver=solver,display=display)
    title = "Benchmark $model_key model with JuMP and OptimalControl"
    file_name = "Model_Benchmark_file.tex"
    parameter_value = "max iter = $max_iter, tol = $tol, constr viol tol = $constr_viol_tol, solver = $solver"
    display_Benchmark(Results, title, file_name,parameter_value)
end


function Benchmark_Callbacks(model_key, nb_discr_list=nb_discr_list)
    Results = benchmark_model_callbacks(model_key, OCProblems.function_init ,nb_discr_list)
    title = "Benchmark Callbacks of $model_key model with JuMP and OptimalControl"
    file_name = "Benchmark_Callbacks_file.tex"
    display_Callbacks(Results, title, file_name)
end

end