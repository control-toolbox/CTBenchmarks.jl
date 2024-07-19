"""
    this file contains the functions to benchmark the models using JuMP
"""

# Function to solve the model
function solving_model_JuMP(model)
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
    return nb_iter, total_time, Ipopt_time, obj_value, flag
end

# Function to benchmark the model
function benchmark_model_JuMP(model_function, nb_discr_list)
    DataModel = []
    # Loop over the list of number of discretization
    for nb_discr in nb_discr_list
        model = model_function(;nh=nb_discr)
        # Solve the model
        nb_iter, total_time, Ipopt_time, obj_value, flag = solving_model_JuMP(model)
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
function benchmark_all_models_JuMP(models, nb_discr_list, excluded_models)
    Results = Dict{Symbol,Any}()
    for (k,v) in models
        print("Benchmarking the model ",k, " ... ")
        if k in excluded_models
            Results[k] = []
            println("❌")
            continue
        end
        info = benchmark_model_JuMP(v, nb_discr_list)
        Results[k] = info
        println("✅")
    end
    return Results
end

"""
function Benchmarking_JuMP(nb_discr_list, excluded_models)
    # Benchmark all the models
    Results = benchmark_all_models_JuMP(JMPProblems.function_JMP, nb_discr_list, excluded_models)

    # print the results
    println("---------- Results : ")
    table = DataFrame(:Model => Symbol[], :nb_discr => Int[], :nb_iter => Int[], :total_time => Float64[], :Ipopt_time => Float64[], :obj_value => Float64[], :flag => Any[])
    for (k,v) in Results
        for i in v
            push!(table, [k; i.nb_discr[1]; i.nb_iter[1]; i.total_time[1]; i.Ipopt_time[1]; i.obj_value[1]; i.flag[1]])
        end
    end
    # Define the custom display
    header = ["Model","Discretization" ,"Iterations" ,"Total Time", "Ipopt Time" ,"Objective Value", "Flag"];
    hl_flags = Highlighter( (results, i, j) -> (j == 7) && (results[i, j] != MOI.LOCALLY_SOLVED && results[i, j] != MOI.OPTIMAL),
                            crayon"red"
                        );
    pretty_table(
        table;
        header        = header,
        title = "Benchmark results",
        header_crayon = crayon"yellow bold",
        highlighters  = (hl_flags),
        tf            = tf_unicode_rounded
    )
end"""