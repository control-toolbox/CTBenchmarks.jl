"""
    this file contains the functions to benchmark the models using JuMP
"""

# Function to solve the model
function solving_model_JuMP(
    model; max_iter=1000, tol=1e-8, constr_viol_tol=1e-6, solver="ma57", display=false
)
    # Set up the solver
    set_optimizer(model, Ipopt.Optimizer)
    if !display
        set_silent(model)
    end
    set_attribute(model, "sb", "yes")
    set_optimizer_attribute(model, "tol", tol)
    set_optimizer_attribute(model, "constr_viol_tol", constr_viol_tol)
    set_optimizer_attribute(model, "max_iter", max_iter)
    set_optimizer_attribute(model, "mu_strategy", "adaptive")
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
    t = @timed (optimize!(model));
    # Get the results
    obj_value = JuMP.objective_value(model)
    flag = solution_summary(model).termination_status
    nb_iter = solution_summary(model).barrier_iterations
    Ipopt_time = solution_summary(model).solve_time
    total_time = t.time
    nvar = MOI.get(model, MOI.NumberOfVariables());
    ncon = length(all_constraints(model; include_variable_in_set_constraints=false))
    return nb_iter, total_time, Ipopt_time, obj_value, flag, nvar, ncon
end

# Function to benchmark the model
function benchmark_model_JuMP(
    model_function,
    nb_discr_list;
    max_iter=1000,
    tol=1e-8,
    constr_viol_tol=1e-6,
    solver="ma57",
    display=false,
)
    DataModel = []
    # Loop over the list of number of discretization
    for nb_discr in nb_discr_list
        model = model_function(JuMPBackend(); nh=nb_discr)
        # Solve the model
        nb_iter, total_time, Ipopt_time, obj_value, flag, nvar, ncon = solving_model_JuMP(
            model;
            max_iter=max_iter,
            tol=tol,
            constr_viol_tol=constr_viol_tol,
            solver=solver,
            display=display,
        )
        # Save the data
        data = DataFrame(
            :nb_discr => nb_discr,
            :nvar => nvar,
            :ncon => ncon,
            :nb_iter => nb_iter,
            :obj_value => obj_value,
            :total_time => total_time,
            :Ipopt_time => Ipopt_time,
            :flag => flag,
        )
        push!(DataModel, data)
    end
    return DataModel
end

# Function to benchmark all the models
function benchmark_all_models_JuMP(
    models,
    nb_discr_list,
    excluded_models;
    max_iter=1000,
    tol=1e-8,
    constr_viol_tol=1e-6,
    solver="ma57",
    display=false,
)
    Results = Dict{Symbol,Any}()
    for (k, v) in models
        print("Benchmarking the model ", k, " ... ")
        if k in excluded_models
            Results[k] = []
            println("❌")
            continue
        end
        info = benchmark_model_JuMP(
            v,
            nb_discr_list;
            max_iter=max_iter,
            tol=tol,
            constr_viol_tol=constr_viol_tol,
            solver=solver,
            display=display,
        )
        Results[k] = info
        println("✅")
    end
    return Results
end
