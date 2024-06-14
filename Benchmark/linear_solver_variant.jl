using JuMP, Ipopt, Plots
using TickTock
using DataFrames
import HSL_jll

function linear_solver_variant(JuMPModel)
    sl_results = DataFrame( :method => String[], 
                    :diff_auto_time => Float64[] , 
                    :total_time => Float64[],
                    :objective_value => Float64[]);
 
    set_optimizer(JuMPModel,Ipopt.Optimizer)
    """"""
    println("Solving With Ipopt : MUMPS Linear Solver")
    set_optimizer_attribute(JuMPModel,"linear_solver", "mumps")
    tick();
    optimize!(JuMPModel);
    tt = tok();
    diff_auto_time = solve_time(JuMPModel);
    push!(sl_results,["Ipopt : MUMPS",diff_auto_time,tt,objective_value(JuMPModel)]);
    println()
    evaluate_res(JuMPModel)
    plot1 = get_plot_res(JuMPModel)

    """"""
    println("Solving With Ipopt : HSLMA57 Linear Solver")
    set_attribute(JuMPModel, "hsllib", HSL_jll.libhsl_path)
    set_attribute(JuMPModel, "linear_solver", "ma57")
    tick();
    optimize!(JuMPModel);
    tt = tok();
    diff_auto_time = solve_time(JuMPModel);
    push!(sl_results,["Ipopt : HSLMA57",diff_auto_time,tt,objective_value(JuMPModel)]);
    println()
    evaluate_res(JuMPModel)
    plot2 = get_plot_res(JuMPModel)

    """"""
    println("Solving With Ipopt : HSLMA27 Linear Solver")
    set_attribute(JuMPModel, "hsllib", HSL_jll.libhsl_path)
    set_attribute(JuMPModel, "linear_solver", "ma27")
    tick();
    optimize!(JuMPModel);
    tt = tok();
    diff_auto_time = solve_time(JuMPModel);
    push!(sl_results,["Ipopt : HSLMA27",diff_auto_time,tt,objective_value(JuMPModel)]);
    println()
    evaluate_res(JuMPModel)
    plot3 = get_plot_res(JuMPModel);

    """"""
    sort!(s_results, [:total_time])
    println("Results of Linear Solvers")
    println(sl_results)
    best_linear_solver = Vector(first(sl_results))[1]
    plot_res = plot(plot1 , label ="MUMPS",line = 2, show = false);
    plot_res = plot!(plot2 , label ="HSLMA57",line = 2);
    plot_res = plot!(plot3 , label ="HSLMA27",line = 2);

    return sl_results, best_linear_solver , plot_res
end


function evaluate_res(JuMPModel)
    if termination_status(JuMPModel) == MOI.OPTIMAL
        println("  Solution is optimal")
    elseif  termination_status(JuMPModel) == MOI.LOCALLY_SOLVED
        println("  (Local) solution found")
    elseif termination_status(JuMPModel) == MOI.TIME_LIMIT && has_values(JuMPModel)
        println("  Solution is suboptimal due to a time limit, but a primal solution is available")
    else
        error("  The model was not solved correctly.")
    end
    println("  objective value = ", objective_value(JuMPModel))
    println()
end


function get_plot_res(JuMPModel)
    N = 100;
    Δt = JuMPModel[:step]; 
    h = JuMPModel[:h];
    v = JuMPModel[:v];
    m = JuMPModel[:m];
    T = JuMPModel[:T];
    con_dh = JuMPModel[:con_dh];
    con_dv = JuMPModel[:con_dv];
    con_dm = JuMPModel[:con_dm];
    h_ic = JuMPModel[:h_ic];
    v_ic = JuMPModel[:v_ic];
    m_ic = JuMPModel[:m_ic];
    m_fc = JuMPModel[:m_fc];

    Δtt = value.(Δt)
    t = Vector((0:N)*Δtt);

    ph0 = dual(h_ic)
    pv0 = dual(v_ic)
    pm0 = dual(m_ic)
    pmf = dual(m_fc)

    if(ph0*dual(con_dh[1])<0); ph0 = -ph0; end
    if(pv0*dual(con_dv[1])<0); pv0 = -pv0; end
    if(pm0*dual(con_dm[1])<0); pm0 = -pm0; end
    if(pmf*dual(con_dm[N])<0); pmf = -pmf; end

    p = [ [ dual(con_dh[1]), dual(con_dv[1]), dual(con_dm[1]) ]];
    p = -1 * [p;[[ dual(con_dh[i]), dual(con_dv[i]), dual(con_dm[i]) ] for i in 1:N]];

    hh = Vector(value.(h)) ;
    vv = Vector(value.(v)) ;
    mm = Vector(value.(m)) ;
    TT = Vector(value.(T)) ;

    x =  [ [ hh[i], vv[i], mm[i] ] for i in 1:N+1 ];
    r_plot = plot(t, [ x[i][1] for i in 1:N+1 ], xlabel = "t", ylabel = "h", legend = false)
    v_plot = plot(t, [ x[i][2] for i in 1:N+1 ], xlabel = "t", ylabel = "v", legend = false)
    m_plot = plot(t, [ x[i][3] for i in 1:N+1 ], xlabel = "t", ylabel = "m", legend = false)
    pr_plot = plot(t, [ p[i][1] for i in 1:N+1 ], xlabel = "t", ylabel = "ph", legend = false)
    pv_plot = plot(t, [ p[i][2] for i in 1:N+1 ], xlabel = "t", ylabel = "pv", legend = false)
    pm_plot = plot(t, [ p[i][3] for i in 1:N+1 ], xlabel = "t", ylabel = "pm", legend = false)
    TT_plot = plot(t, [ TT[i] for i in 1:N+1 ], xlabel = "t", ylabel = "TT", legend = false)
    
    layout = @layout [a b; c d; e f; g]
    
    x_plot = plot(r_plot, pr_plot, v_plot, pv_plot, m_plot, pm_plot, TT_plot, layout = layout, show = false);
    return x_plot
end