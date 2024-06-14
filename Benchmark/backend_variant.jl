using JuMP, Ipopt, ExaModels, NLPModelsIpopt
import MathOptInterface as MOI
import MathOptSymbolicAD

function backend_variant(JuMPModel)
    be_results = DataFrame( :method => String[], 
                    :diff_auto_time => Float64[] , 
                    :total_time => Float64[],
                    :objective_value => Float64[]);

    m1 = JuMPModel
    set_attribute(JuMPModel,
            MOI.AutomaticDifferentiationBackend(),
            MOI.Nonlinear.SparseReverseMode(),)
    """"""
    println("Solving With : JuMPDefault ($(MOI.get(JuMPModel , MOI.AutomaticDifferentiationBackend())))")
    tick();
    optimize!(JuMPModel);
    tt = tok();
    diff_auto_time = solve_time(JuMPModel);
    push!(be_results,["JuMPDefault",diff_auto_time,tt,objective_value(JuMPModel)]);
    println()
    sleep(2)

    """"""
    set_attribute(JuMPModel,
            MOI.AutomaticDifferentiationBackend(),
            MathOptSymbolicAD.DefaultBackend(),)
    println("Solving With : SymbolicAD ($(MOI.get(JuMPModel , MOI.AutomaticDifferentiationBackend())))")
    tick();
    optimize!(JuMPModel);
    tt = tok();
    diff_auto_time = solve_time(JuMPModel);
    push!(be_results,["SymbolicAD",diff_auto_time,tt,objective_value(JuMPModel)]);
    println()
    sleep(2)

    JuMPModel = m1
    """"""
    EXAModel = ExaModels.ExaModel(JuMPModel)
    println("Solving With : ExaModels")
    tick();
    stats = ipopt(EXAModel, print_level = 0);
    tt = tok();
    diff_auto_time = stats.elapsed_time;
    push!(be_results,["ExaModels",diff_auto_time,tt,stats.objective]);
    println()

    """"""
    sort!(be_results, [:total_time])
    println("Results of Backends :")
    println(be_results)
    best_backend = Vector(first(be_results))[1]

    return be_results, best_backend



end