module Benchmark

import Pkg
path = dirname(@__FILE__)
Pkg.activate(path*"/../");
include(path*"/../Problems/JuMP/JMPProblems.jl");
include(path*"/../Problems/OptimalControl/OCProblems.jl");

using MKL
using .JMPProblems
using .OCProblems

include(path*"./Benchmark_OC.jl")
include(path*"./Benchmark_JuMP.jl")
include(path*"./Benchmark_model.jl")

using JuMP , Ipopt
using OptimalControl, NLPModelsIpopt
import HSL_jll

using PrettyTables, Colors
using DataFrames


nb_discr_list = [100; 500]
excluded_models = [:space_shuttle; :quadrotor1obs; :quadrotorp2p; :truck; :moonlander]

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


function display_Benchmark(Results, title, file_name)
    # Print the results
    #println("---------- Results : ")
    table = DataFrame(:Model => Symbol[], :nb_discr => Int[], :nb_iter => Int[], :total_time => Float64[], :Ipopt_time => Float64[], :obj_value => Float64[], :flag => Any[])
    for (k,v) in Results
        for i in v
            push!(table, [k; i.nb_discr[1]; i.nb_iter[1]; i.total_time[1]; i.Ipopt_time[1]; i.obj_value[1]; i.flag[1]])
        end
    end
    # Define the custom display
    header = ["Model","Discretization" ,"Iterations" ,"Total Time", "Ipopt Time" ,"Objective Value", "Flag"];
    hl_flags = LatexHighlighter( (results, i, j) -> ((j == 7) && (results[i, j] != MOI.LOCALLY_SOLVED) && (results[i, j] != MOI.OPTIMAL) && (results[i, j] != "Solve_Succeeded")),
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
        println("\\hline")
        println("\\Large\\textbf{$title}\\\\")
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


function Benchmark_OC(nb_discr_list=nb_discr_list, excluded_models=excluded_models)
    Results = benchmark_all_models_OC(OCProblems.function_OC,OCProblems.function_init ,nb_discr_list, excluded_models)
    title = "Benchmark OptimalControl Results"
    file_name = "OptimalControl_Benchmark_file.tex"
    display_Benchmark(Results, title, file_name)
end

function Benchmark_JuMP(nb_discr_list=nb_discr_list, excluded_models=excluded_models)
    Results = benchmark_all_models_JuMP(JMPProblems.function_JMP, nb_discr_list, excluded_models)
    title = "Benchmark JuMP Results"
    file_name = "JuMP_Benchmark_file.tex"
    display_Benchmark(Results, title, file_name)
end

function Benchmark_model(model_key, nb_discr_list=nb_discr_list)
    Results = benchmark_model(model_key, OCProblems.function_init ,nb_discr_list)
    title = "Benchmark $model_key model with JuMP and OptimalControl"
    file_name = "Model_Benchmark_file.tex"
    display_Benchmark(Results, title, file_name)
end


end