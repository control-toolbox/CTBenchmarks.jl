using JuMP, Ipopt, Plots
using BenchmarkTools
using DataFrames
import HSL_jll
include("./utils.jl")


function linear_solver_variant(JuMPModel)
    sl_results = DataFrame( :method => String[], 
                    :diff_auto_time => Float64[] , 
                    :total_time => String[],
                    :objective_value => Float64[],
                    :tf => Float64[]);
 
    println("Using Ipopt Solver :");
    set_optimizer(JuMPModel,Ipopt.Optimizer)
    """"""
    print("Solving With MUMPS...")
    set_optimizer_attribute(JuMPModel,"linear_solver", "mumps")
    b = @benchmark optimize!(JuMPModel);
    tt = prettytime(median(b.times));
    tf = median(b.times);
    diff_auto_time = solve_time(JuMPModel);
    push!(sl_results,["MUMPS",diff_auto_time,tt,objective_value(JuMPModel),tf]);
    println("✅")
    println()

    """"""
    print("Solving With HSLMA57...")
    set_attribute(JuMPModel, "hsllib", HSL_jll.libhsl_path)
    set_attribute(JuMPModel, "linear_solver", "ma57")
    b = @benchmark optimize!(JuMPModel);
    tt = prettytime(median(b.times));
    tf = median(b.times);
    diff_auto_time = solve_time(JuMPModel);
    push!(sl_results,["HSLMA57",diff_auto_time,tt,objective_value(JuMPModel),tf]);
    println("✅")
    println()

    """"""
    print("Solving With HSLMA27...")
    set_attribute(JuMPModel, "hsllib", HSL_jll.libhsl_path)
    set_attribute(JuMPModel, "linear_solver", "ma27")
    b = @benchmark optimize!(JuMPModel);
    tt = prettytime(median(b.times));
    tf = median(b.times);
    diff_auto_time = solve_time(JuMPModel);
    push!(sl_results,["HSLMA27",diff_auto_time,tt,objective_value(JuMPModel),tf]);
    println("✅")
    println()

    """"""
    sort!(sl_results, [:tf])
    printstyled("-------------------------Results of Linear Solvers-------------------------",color = :blue)
    println()
    sl_results = select(sl_results, Not(:tf));
    println(sl_results)
    best_linear_solver = Vector(first(sl_results))[1]

    return sl_results, best_linear_solver
end
