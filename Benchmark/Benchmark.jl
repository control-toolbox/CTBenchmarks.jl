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

using JuMP , Ipopt
using OptimalControl, NLPModelsIpopt
import HSL_jll

using PrettyTables, Colors
using DataFrames


nb_discr_list = [10]
excluded_models = [:space_shuttle; :quadrotor1obs; :quadrotorp2p; :truck]


function display_Benchmark(Results, title)
    # print the results
    println("---------- Results : ")
    table = DataFrame(:Model => Symbol[], :nb_discr => Int[], :nb_iter => Int[], :total_time => Float64[], :Ipopt_time => Float64[], :obj_value => Float64[], :flag => Any[])
    for (k,v) in Results
        for i in v
            push!(table, [k; i.nb_discr[1]; i.nb_iter[1]; i.total_time[1]; i.Ipopt_time[1]; i.obj_value[1]; i.flag[1]])
        end
    end
    # Define the custom display
    header = ["Model","Discretization" ,"Iterations" ,"Total Time", "Ipopt Time" ,"Objective Value", "Flag"];
    hl_flags = Highlighter( (results, i, j) -> (j == 7) && (results[i, j] != MOI.LOCALLY_SOLVED && results[i, j] != MOI.OPTIMAL),
                            crayon"red"
                        );
    pretty_table(
        table;
        header        = header,
        title = title,
        alignment = :c,
        header_crayon = crayon"yellow bold",
        highlighters  = (hl_flags),
        tf            = tf_unicode_rounded
    )
end

function Benchmark_OC(nb_discr_list=nb_discr_list, excluded_models=excluded_models)
    Results = benchmark_all_models_OC(OCProblems.function_OC,OCProblems.function_init ,nb_discr_list, excluded_models)
    title = "Benchmark OptimalControl results"
    display_Benchmark(Results, title)
end

function Benchmark_JuMP(nb_discr_list=nb_discr_list, excluded_models=excluded_models)
    Results = benchmark_all_models_JuMP(JMPProblems.function_JMP, nb_discr_list, excluded_models)
    title = "Benchmark JuMP results"
    display_Benchmark(Results, title)
end

function Benchmark_model(model_key)
    #Results = benchmark_model()
    #title = "Benchmark model $model_key"
    #display_Benchmark(Results, title)
end


end