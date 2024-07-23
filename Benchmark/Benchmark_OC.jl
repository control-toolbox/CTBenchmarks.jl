"""
    This file contains the functions to benchmark the models using OptimalControl
"""

# Function to solve the model
function solving_model_OC(model,nb_discr,init)
    # Solve the problem
    t =  @timed ( 
        sol = OptimalControl.solve(model, grid_size=nb_discr, init=init, 
            linear_solver="ma57",hsllib=HSL_jll.libhsl_path,
            max_iter=1000, tol=1e-8, constr_viol_tol = 1e-6, 
            display=false, sb = "yes",output_file="./outputs/outputOC.out",
            print_level=0,
            );
        )
    # Get the results
    outputOC = read("./outputs/outputOC.out", String)
    tIpopt = parse(Float64,split(split(outputOC, "Total seconds in IPOPT                               =")[2], "\n")[1])
    obj_value = sol.objective
    flag = sol.message
    nb_iter = sol.iterations
    Ipopt_time = tIpopt
    total_time = t.time
    return nb_iter, total_time, Ipopt_time, obj_value, flag
end


# Function to benchmark the model
function benchmark_model_OC(model_function,model_init, nb_discr_list)
    DataModel = []
    # Loop over the list of number of discretization
    for nb_discr in nb_discr_list
        model = model_function()
        # Solve the model
        nb_iter, total_time, Ipopt_time, obj_value, flag = solving_model_OC(model,nb_discr,model_init(;nh=nb_discr))
        # Save the data
        data = DataFrame(:nb_discr => nb_discr,
                        :nb_iter => nb_iter,
                        :obj_value => obj_value,
                        :total_time => total_time,
                        :Ipopt_time => Ipopt_time,
                        :flag => flag)
        push!(DataModel,data)
    end
    return DataModel
end


# Function to benchmark all the models
function benchmark_all_models_OC(models, inits , nb_discr_list, excluded_models)
    Results = Dict{Symbol,Any}()
    for (k,v) in models
        print("Benchmarking the model ",k, " ... ")
        if k in excluded_models
            Results[k] = []
            println("❌")
            continue
        end
        info = benchmark_model_OC(v,inits[k], nb_discr_list)
        Results[k] = info
        println("✅")
    end
    return Results
end


