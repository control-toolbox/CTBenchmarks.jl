using JuMP, Ipopt, MadNLP, KNITRO

function solver_variant(JuMPModel)
    s_results = DataFrame(
        :method => String[],
        :diff_auto_time => Float64[],
        :total_time => String[],
        :objective_value => Float64[],
        :tf => Float64[],
    );

    """"""
    print("Solving With Ipopt...")
    set_optimizer(JuMPModel, Ipopt.Optimizer)
    b = @benchmark optimize!(JuMPModel)
    tt = prettytime(median(b.times));
    tf = median(b.times);
    diff_auto_time = solve_time(JuMPModel);
    push!(s_results, ["Ipopt", diff_auto_time, tt, objective_value(JuMPModel), tf]);
    println("✅")
    println()

    """"""
    print("Solving With MadNLP...")
    set_optimizer(JuMPModel, MadNLP.Optimizer);
    b = @benchmark optimize!(JuMPModel)
    tt = prettytime(median(b.times));
    tf = median(b.times);
    diff_auto_time = solve_time(JuMPModel);
    push!(s_results, ["MadNLP", diff_auto_time, tt, objective_value(JuMPModel), tf]);
    println("✅")
    println()

    """"""
    print("Solving With KNITRO_SQP...")
    set_optimizer(JuMPModel, KNITRO.Optimizer);
    set_attribute(JuMPModel, "algorithm", 4);
    b = @benchmark optimize!(JuMPModel)
    tt = prettytime(median(b.times));
    tf = median(b.times);
    diff_auto_time = solve_time(JuMPModel);
    push!(s_results, ["KNITRO_SQP", diff_auto_time, tt, objective_value(JuMPModel), tf]);
    println("✅")
    println()

    """"""
    print("Solving With KNITRO_IPM...")
    set_optimizer(JuMPModel, KNITRO.Optimizer);
    set_attribute(JuMPModel, "algorithm", 1);
    b = @benchmark optimize!(JuMPModel)
    tt = prettytime(median(b.times));
    tf = median(b.times);
    diff_auto_time = solve_time(JuMPModel);
    push!(s_results, ["KNITRO_IPM", diff_auto_time, tt, objective_value(JuMPModel), tf]);
    println("✅")
    println()

    """"""
    sort!(s_results, [:tf])
    printstyled(
        "-------------------------Results of Solvers-------------------------"; color=:blue
    )
    println()
    s_results = select(s_results, Not(:tf));
    println(s_results)
    best_solver = Vector(first(s_results))[1]

    return s_results, best_solver
end
