using JuMP, Ipopt, MadNLP, KNITRO

function solver_variant(JuMPModel)
    s_results = DataFrame( :method => String[], 
                    :diff_auto_time => Float64[] , 
                    :total_time => Float64[],
                    :objective_value => Float64[]);

    """"""
    println("Solving With Ipopt")
    set_optimizer(JuMPModel,Ipopt.Optimizer)
    tick();
    optimize!(JuMPModel);
    tt = tok();
    diff_auto_time = solve_time(JuMPModel);
    push!(s_results,["Ipopt",diff_auto_time,tt,objective_value(JuMPModel)]);
    println()
    sleep(2)

    """"""
    println("Solving With MadNLP")
    set_optimizer(JuMPModel,MadNLP.Optimizer);
    tick();
    optimize!(JuMPModel);
    tt = tok();
    diff_auto_time = solve_time(JuMPModel);
    push!(s_results,["MadNLP",diff_auto_time,tt,objective_value(JuMPModel)]);
    println()
    sleep(2)

    """"""
    println("Solving With KNITRO_SQP ")
    set_optimizer(JuMPModel,KNITRO.Optimizer);
    set_attribute(JuMPModel, "algorithm", 4);
    tick();
    optimize!(JuMPModel);
    tt = tok();
    diff_auto_time = solve_time(JuMPModel);
    push!(s_results,["KNITRO_SQP",diff_auto_time,tt,objective_value(JuMPModel)]);
    println()
    sleep(2)

    """"""
    println("Solving With KNITRO_IPM ")
    set_optimizer(JuMPModel,KNITRO.Optimizer);
    set_attribute(JuMPModel, "algorithm", 1);
    tick();
    optimize!(JuMPModel);
    tt = tok();
    diff_auto_time = solve_time(JuMPModel);
    push!(s_results,["KNITRO_IPM",diff_auto_time,tt,objective_value(JuMPModel)]);
    println()
    sleep(2)


    """"""
    sort!(s_results, [:total_time])
    println("Results of Solvers :")
    println(s_results)
    best_solver = Vector(first(s_results))[1]

    return s_results, best_solver

end