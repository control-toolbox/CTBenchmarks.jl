"""
    This file contains the functions to benchmark the models using OptimalControl and JuMP
"""

# Function to solve the model with OptimalControl
function benchmark_1model_OC(model, init, nb_discr;max_iter=1000, tol=1e-8, constr_viol_tol = 1e-6,solver="ma57",display=false)
    nh = nb_discr - 1 > 1 ? nb_discr - 1 : 2 
    if solver == "ma57"
        t =  @timed ( 
            sol = OptimalControl.solve(model, grid_size=nh, init=init, 
                linear_solver="ma57",hsllib=HSL_jll.libhsl_path,
                max_iter=max_iter, tol=tol, constr_viol_tol = constr_viol_tol, 
                display=display, sb = "yes",output_file="./outputs/outputOC.out",
                print_level=0,
                );
            )
    elseif solver == "ma27"
        t =  @timed ( 
            sol = OptimalControl.solve(model, grid_size=nh, init=init, 
                linear_solver="ma27",hsllib=HSL_jll.libhsl_path,
                max_iter=max_iter, tol=tol, constr_viol_tol = constr_viol_tol, 
                display=display, sb = "yes",output_file="./outputs/outputOC.out",
                print_level=0,
                );
            )
    elseif solver == "mumps"
        t =  @timed ( 
            sol = OptimalControl.solve(model, grid_size=nh, init=init, 
                max_iter=max_iter, tol=tol, constr_viol_tol = constr_viol_tol, 
                display=display, sb = "yes",output_file="./outputs/outputOC.out",
                print_level=0,
                );
            )
    else
        error("The solver $solver is not supported")
    end
    # Get the results
    outputOC = read("./outputs/outputOC.out", String)
    tIpopt = parse(Float64,split(split(outputOC, "Total seconds in IPOPT                               =")[2], "\n")[1])
    obj_value = sol.objective
    flag = sol.message
    nb_iter = sol.iterations
    Ipopt_time = tIpopt
    total_time = t.time
    nlp = get_nlp(direct_transcription(model; grid_size=nb_discr))
    nvar = nlp.meta.nvar
    ncon = nlp.meta.ncon
    data = DataFrame(:nb_discr => nb_discr,
                        :nvar => nvar,
                        :ncon => ncon,
                        :nb_iter => nb_iter,
                        :obj_value => obj_value,
                        :total_time => total_time,
                        :Ipopt_time => Ipopt_time,
                        :flag => flag)
    return data
end


# Function to solve the model with JuMP
function benchmark_1model_JuMP(model, nb_discr;max_iter=1000, tol=1e-8, constr_viol_tol = 1e-6,solver="ma57",display=false)
    # Set up the solver
    set_optimizer(model,Ipopt.Optimizer)
    if !display
        set_silent(model)
    end
    set_attribute(model, "sb", "yes")
    set_optimizer_attribute(model,"tol",tol)
    set_optimizer_attribute(model,"constr_viol_tol",constr_viol_tol)
    set_optimizer_attribute(model,"max_iter",max_iter)
    set_optimizer_attribute(model,"mu_strategy","adaptive")
    if solver == "ma57"
        set_attribute(model, "hsllib", HSL_jll.libhsl_path)
        set_attribute(model, "linear_solver", "ma57")
    elseif solver == "ma27"
        set_attribute(model, "hsllib", HSL_jll.libhsl_path)
        set_attribute(model, "linear_solver", "ma27")
    elseif solver == "mumps"
        set_attribute(model, "linear_solver", "mumps")
    else
        error("The solver $solver is not supported")
    end
    # Solve the model
    t =  @timed (optimize!(model));
    # Get the results
    obj_value = JuMP.objective_value(model)
    flag = solution_summary(model).termination_status
    nb_iter = solution_summary(model).barrier_iterations
    Ipopt_time = solution_summary(model).solve_time
    total_time = t.time
    nvar = MOI.get(model, MOI.NumberOfVariables());
    ncon = length(all_constraints(model; include_variable_in_set_constraints = false))
    data = DataFrame(:nb_discr => nb_discr,
                        :nvar => nvar,
                        :ncon => ncon,
                        :nb_iter => nb_iter,
                        :obj_value => obj_value,
                        :total_time => total_time,
                        :Ipopt_time => Ipopt_time,
                        :flag => flag)
    return data
end


# Function to benchmark the model
function benchmark_model(model_key_list, inits , nb_discr_list;max_iter=1000, tol=1e-8, constr_viol_tol = 1e-6,solver="ma57",display=false)
    Results = Dict{Symbol,Any}()
    for model_key in model_key_list
        R = Dict{Symbol,Any}()
        R_OC = []
        R_JuMP = [] 
        solve_OC = true
        solve_JMP = true
        if ! (model_key in keys(OCProblems.function_OC))
            println("The model $model_key is not available in the OptimalControl benchmark list. ❌")
            solve_OC = false
        end
        if ! (model_key in keys(JMPProblems.function_JMP))
            println("The model $model_key is not available in the JuMP benchmark list. ❌")
            solve_JMP = false
        end
        for nb_discr in nb_discr_list
            if solve_OC
                print("Benchmarking the model $model_key with OptimalControl ($nb_discr)... ")
                model = OCProblems.function_OC[model_key]()
                info_OC = benchmark_1model_OC(model, inits[model_key](;nh=nb_discr-1), nb_discr;max_iter=max_iter, tol=tol, constr_viol_tol = constr_viol_tol,solver=solver,display=display)
                push!(R_OC, info_OC)
                println("✅")
            end
            if solve_JMP
                print("Benchmarking the model $model_key with JuMP ($nb_discr)... ")
                model = JMPProblems.function_JMP[model_key](;nh=nb_discr)
                info_JuMP = benchmark_1model_JuMP(model, nb_discr;max_iter=max_iter, tol=tol, constr_viol_tol = constr_viol_tol,solver=solver,display=display)
                push!(R_JuMP, info_JuMP)
                println("✅")
            end
        end
        R[:JuMP] = R_JuMP
        R[:OptimalControl] = R_OC
        Results[model_key] = R
    end
    return Results
end