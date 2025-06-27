module Benchmark

import Pkg
path = dirname(@__FILE__)
Pkg.activate(path*"/../");

using MKL
using BenchmarkTools
using OptimalControlProblems
using JuMP, OptimalControl
using Ipopt, NLPModelsIpopt
using ADNLPModels, NLPModelsKnitro, KNITRO
import HSL_jll
import HSL
using NLPModels, NLPModelsJuMP
using PrettyTables, Colors
using DataFrames

all_names = names(OptimalControlProblems, all=true)
all_list = filter(x -> isdefined(OptimalControlProblems, x) && 
    isa(getfield(OptimalControlProblems, x), Function) && 
    !occursin(r"#", string(x)) &&
    x != :eval &&
    x != :include, 
    all_names)

functions_list = Dict{Symbol, Function}()
for f in all_list
    key = Symbol(f)
    functions_list[key] = OptimalControlProblems.eval(f)
end

include(path*"./Benchmark_OC.jl")
include(path*"./Benchmark_JuMP.jl")
include(path*"./Benchmark_model.jl")
include(path*"./Benchmark_Callbacks.jl")
include(path*"./Benchmark_Knitro.jl")
include(path*"./display_functions.jl")

nb_discr_list = [100; 500]
excluded_models = [:space_shuttle; :quadrotor; :truck_trailer; :moonlander; :jackson; :vanderpol; :glider; :bioreactor]

# JIT warm-up for the first run
# Redirect stdout and stderr to /dev/null
original_stdout = stdout
original_stderr = stderr
null_device = get(ENV, "OS", "") == "Windows_NT" ? "NUL" : "/dev/null"
redirect_stdout(open(null_device, "w"))
redirect_stderr(open(null_device, "w"))

try
    # dummy run for OC and JuMP
    benchmark_model([:rocket], [2])
finally
    # Restore original stdout and stderr
    redirect_stdout(original_stdout)
    redirect_stderr(original_stderr)
end


function Benchmark_OC(nb_discr_list=nb_discr_list, excluded_models=excluded_models;max_iter=1000, tol=1e-8, constr_viol_tol = 1e-6,solver="ma57",display=false)
    Results = benchmark_all_models_OC(functions_list,nb_discr_list, excluded_models;max_iter=max_iter, tol=tol, constr_viol_tol = constr_viol_tol,solver=solver,display=display)
    title = "Benchmark OptimalControl Results"
    file_name = "OptimalControl_Benchmark_file.tex"
    parameter_value = "max iter = $max_iter, tol = $tol, constr viol tol = $constr_viol_tol, solver = $solver"
    display_Benchmark(Results, title, file_name,parameter_value)
end

function Benchmark_JuMP(nb_discr_list=nb_discr_list, excluded_models=excluded_models;max_iter=1000, tol=1e-8, constr_viol_tol = 1e-6,solver="ma57",display=false)
    Results = benchmark_all_models_JuMP(functions_list, nb_discr_list, excluded_models;max_iter=max_iter, tol=tol, constr_viol_tol = constr_viol_tol,solver=solver,display=display)
    title = "Benchmark JuMP Results"
    file_name = "JuMP_Benchmark_file.tex"
    parameter_value = "max iter = $max_iter, tol = $tol, constr viol tol = $constr_viol_tol, solver = $solver"
    display_Benchmark(Results, title, file_name,parameter_value)
end

function Benchmark_model(model_key_list, nb_discr_list=nb_discr_list;max_iter=1000, tol=1e-8, constr_viol_tol = 1e-6,solver="ma57",display=false)
    Results = benchmark_model(model_key_list,nb_discr_list;max_iter=max_iter, tol=tol, constr_viol_tol = constr_viol_tol,solver=solver,display=display)
    title = "Benchmark models with JuMP and OptimalControl"
    file_name = "Model_Benchmark_file.tex"
    parameter_value = "max iter = $max_iter, tol = $tol, constr viol tol = $constr_viol_tol, solver = $solver"
    display_Benchmark_model(Results, title, file_name,parameter_value)
end

function Benchmark_model_TTonly(model_key_list, nb_discr_list=nb_discr_list;max_iter=1000, tol=1e-8, constr_viol_tol = 1e-6,solver="ma57",display=false)    
    Results = benchmark_model_TTonly(model_key_list, nb_discr_list;max_iter=max_iter, tol=tol, constr_viol_tol = constr_viol_tol,solver=solver,display=display)
    title = "Benchmark models with JuMP and OptimalControl"
    file_name = "Model_Benchmark_TTonly_file.tex"
    parameter_value = "max iter = $max_iter, tol = $tol, constr viol tol = $constr_viol_tol, solver = $solver"
    display_Benchmark_model_TTonly(Results, title, file_name,parameter_value)
end


function Benchmark_Callbacks(model_key, nb_discr_list=nb_discr_list)
    Results = benchmark_model_callbacks(model_key, nb_discr_list)
    title = "Benchmark Callbacks of $model_key model with JuMP and OptimalControl"
    file_name = "Benchmark_Callbacks_file.tex"
    display_Callbacks(Results, title, file_name)
end


function Benchmark_KNITRO(model_key_list, nb_discr_list;display=false)
    Results = benchmark_knitro(model_key_list, nb_discr_list;display=display)
    title = "Benchmark Knitro Results"
    file_name = "Knitro_Benchmark_file.tex"
    display_Knitro(Results, title, file_name)
end

end