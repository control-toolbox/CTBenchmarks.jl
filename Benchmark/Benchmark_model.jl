"""
    This file contains the functions to benchmark the models using OptimalControl and JuMP
"""

# Function to solve the model with OptimalControl
function benchmark_1model_OC(model, init, nb_discr)
    t =  @timed ( 
        sol = OptimalControl.solve(model, grid_size=nb_discr, init=init, 
            linear_solver="ma57",hsllib=HSL_jll.libhsl_path,
            max_iter=1000, tol=1e-8, constr_viol_tol = 1e-6, 
            display=false, sb = "yes",output_file="outputOC.out",
            print_level=0,
            );
        )
    # Get the results
    outputOC = read("outputOC.out", String)
    tIpopt = parse(Float64,split(split(outputOC, "Total seconds in IPOPT                               =")[2], "\n")[1])
    obj_value = sol.objective
    flag = sol.message
    nb_iter = sol.iterations
    Ipopt_time = tIpopt
    total_time = t.time
    data = DataFrame(:nb_discr => nb_discr,
                        :nb_iter => nb_iter,
                        :obj_value => obj_value,
                        :total_time => total_time,
                        :Ipopt_time => Ipopt_time,
                        :flag => flag)
    return [data]
end


# Function to solve the model with JuMP
function benchmark_1model_JuMP(model, nb_discr)
    # Set up the solver
    set_optimizer(model,Ipopt.Optimizer)
    set_silent(model)
    set_attribute(model, "sb", "yes")
    set_optimizer_attribute(model,"tol",1e-8)
    set_optimizer_attribute(model,"constr_viol_tol",1e-6)
    set_optimizer_attribute(model,"max_iter",1000)
    set_optimizer_attribute(model,"mu_strategy","adaptive")
    set_attribute(model, "hsllib", HSL_jll.libhsl_path)
    set_attribute(model, "linear_solver", "ma57")
    # Solve the model
    t =  @timed (optimize!(model));
    # Get the results
    obj_value = JuMP.objective_value(model)
    flag = solution_summary(model).termination_status
    nb_iter = solution_summary(model).barrier_iterations
    Ipopt_time = solution_summary(model).solve_time
    total_time = t.time
    data = DataFrame(:nb_discr => nb_discr,
                        :nb_iter => nb_iter,
                        :obj_value => obj_value,
                        :total_time => total_time,
                        :Ipopt_time => Ipopt_time,
                        :flag => flag)
    return [data]
end


# Function to benchmark the model
function benchmark_model(model_key, inits , nb_discr_list)
    Results = Dict{Symbol,Any}()
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
            info_OC = benchmark_1model_OC(model, inits[model_key](;nh=nb_discr), nb_discr)
            Results[:OptimalControl] = info_OC
            println("✅")
        end
        if solve_JMP
            print("Benchmarking the model $model_key with JuMP ($nb_discr)... ")
            model = JMPProblems.function_JMP[model_key](;nh=nb_discr)
            info_JuMP = benchmark_1model_JuMP(model, nb_discr)
            Results[:JuMP] = info_JuMP
            println("✅")
        end
    end
    return Results
end