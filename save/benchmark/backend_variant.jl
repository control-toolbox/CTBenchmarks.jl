using JuMP, Ipopt, ExaModels, NLPModelsIpopt
import MathOptInterface as MOI
using MathOptSymbolicAD: MathOptSymbolicAD
using BenchmarkTools

function backend_variant(JuMPModel)
    be_results = DataFrame(
        :method => String[],
        :diff_auto_time => Float64[],
        :total_time => String[],
        :objective_value => Float64[],
        :tf => Float64[],
    );

    """"""
    print("Solving With : ExaModels...")
    Exa_Model = ExaModel(JuMPModel);
    b = @benchmark (ipopt($Exa_Model, print_level=0)) evals=1
    stats = ipopt(Exa_Model; print_level=0);
    tt = prettytime(median(b.times));
    tf = median(b.times);
    diff_auto_time = stats.elapsed_time;
    push!(be_results, ["ExaModels", diff_auto_time, tt, stats.objective, tf]);
    println("✅")
    println()

    """"""
    set_attribute(
        JuMPModel, MOI.AutomaticDifferentiationBackend(), MOI.Nonlinear.SparseReverseMode()
    )
    print(
        "Solving With : JuMPDefault ($(MOI.get(JuMPModel , MOI.AutomaticDifferentiationBackend())))...",
    )
    b = @benchmark optimize!(JuMPModel)
    tt = prettytime(median(b.times));
    tf = median(b.times);
    diff_auto_time = solve_time(JuMPModel);
    push!(be_results, ["JuMPDefault", diff_auto_time, tt, objective_value(JuMPModel), tf]);
    println("✅")
    println()

    """"""
    set_attribute(
        JuMPModel, MOI.AutomaticDifferentiationBackend(), MathOptSymbolicAD.DefaultBackend()
    )
    print(
        "Solving With : SymbolicAD ($(MOI.get(JuMPModel , MOI.AutomaticDifferentiationBackend())))...",
    )
    b = @benchmark optimize!(JuMPModel)
    tt = prettytime(median(b.times));
    tf = median(b.times);
    diff_auto_time = solve_time(JuMPModel);
    push!(be_results, ["SymbolicAD", diff_auto_time, tt, objective_value(JuMPModel), tf]);
    println("✅")
    println()

    """"""
    sort!(be_results, [:tf])
    printstyled(
        "-------------------------Results of Backends-------------------------"; color=:blue
    )
    println()
    be_results = select(be_results, Not(:tf));
    println(be_results)
    best_backend = Vector(first(be_results))[1]

    return be_results, best_backend
end
