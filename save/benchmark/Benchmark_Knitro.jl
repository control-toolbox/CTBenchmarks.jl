"""
    This file contains the functions to benchmark the models using OptimalControl and JuMP
"""

# Function to solve the model with OptimalControl
function benchmark_Knitro_OC(model_key, model, nb_discr;display=false)
    if !KNITRO.has_knitro()
        error("KNITRO is not available")
    else
        if display
            t = @timed ( 
                stats = knitro(model)
            )
        else
            t = @timed ( 
                stats = knitro(model, outlev=0)
            )
        end
    end
    # Get the results
    knitro_time = stats.elapsed_time
    obj_value = stats.objective
    flag = stats.solver_specific[:internal_msg]
    nb_iter = stats.iter
    total_time = t.time
    nvar = model.meta.nvar
    ncon = model.meta.ncon
    data = DataFrame(   :model => model_key,
                        :nb_discr => nb_discr,
                        :nvar => nvar,
                        :ncon => ncon,
                        :nb_iter => nb_iter,
                        :obj_value => obj_value,
                        :total_time => total_time,
                        :knitro_time => knitro_time,
                        :flag => flag)
    return data
end


# Function to solve the model with JuMP
function benchmark_Knitro_JuMP(model_key, model, nb_discr;display=false)
    # Set up the solver
    set_optimizer(model,KNITRO.Optimizer)
    if !display
        set_silent(model)
        set_optimizer_attribute(model, "outmode", 1)
    else
        set_optimizer_attribute(model, "outmode", 2)
    end
    # Solve the model
    t =  @timed (optimize!(model));
    # Get the results
    obj_value = JuMP.objective_value(model)
    flag = solution_summary(model).termination_status
    output = read("knitro.log", String)
    nb_iter = parse(Float64,split(split(output, "# of iterations                     =         ")[2], "\n")[1])
    nb_iter = Int(nb_iter)
    knitro_time = solution_summary(model).solve_time
    total_time = t.time
    nvar = MOI.get(model, MOI.NumberOfVariables());
    ncon = length(all_constraints(model; include_variable_in_set_constraints = false))
    data = DataFrame(   :model => model_key,
                        :nb_discr => nb_discr,
                        :nvar => nvar,
                        :ncon => ncon,
                        :nb_iter => nb_iter,
                        :obj_value => obj_value,
                        :total_time => total_time,
                        :knitro_time => knitro_time,
                        :flag => flag)
    return data
end


# Function to benchmark the model
function benchmark_knitro(model_key_list, nb_discr_list;display=false)
    Results = Dict{Symbol,Any}()
    R_OC = []
    R_JuMP = []
    for model_key in model_key_list
        for nb_discr in nb_discr_list
            print("Benchmarking the model $model_key with OptimalControl ($nb_discr)... ")
            _, model = functions_list[model_key](OptimalControlBackend(); nh=nb_discr)
            info_OC = benchmark_Knitro_OC(model_key,model, nb_discr;display=display)
            push!(R_OC, info_OC)
            println("✅")
            
            print("Benchmarking the model $model_key with JuMP ($nb_discr)... ")
            model = functions_list[model_key](JuMPBackend(); nh=nb_discr)
            info_JuMP = benchmark_Knitro_JuMP(model_key,model, nb_discr;display=display)
            push!(R_JuMP, info_JuMP)
            println("✅")
        end
    end
    Results[:JuMP] = R_JuMP
    Results[:OptimalControl] = R_OC
    return Results
end