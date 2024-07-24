"""
    This file contains the functions to Benchmark the time spent in evaluating the model callbacks
"""


function callbacks_nlp(nlp, nb_discr)
    n, m = get_nvar(nlp), get_ncon(nlp);
    x0 = get_x0(nlp);
    y0 = get_y0(nlp);
    t_obj = @timed NLPModels.obj(nlp, x0);

    g = zeros(n);
    t_grad = @timed NLPModels.grad!(nlp, x0, g);

    cons = zeros(m);
    t_cons = @timed NLPModels.cons!(nlp, x0, cons);

    nnzj = get_nnzj(nlp);
    jac = zeros(nnzj);
    t_jac = @timed NLPModels.jac_coord!(nlp, x0, jac) ;

    nnzh = get_nnzh(nlp);
    hess = zeros(nnzh);
    t_hess = @timed NLPModels.hess_coord!(nlp, x0, y0, hess) ;
    data = DataFrame(
            :nb_discr => nb_discr,
            :nnzh => nnzh,
            :nnzj => nnzj,
            :t_obj => t_obj.time,
            :t_grad => t_grad.time,
            :t_cons => t_cons.time,
            :t_jac => t_jac.time,
            :t_hess => t_hess.time
            )
    return data
end



# Function to solve the model with OptimalControl
function callbacks_1model_OC(model, init, nb_discr)
    nlp = get_nlp(direct_transcription(model,grid_size=nb_discr, init=init))
    data = callbacks_nlp(nlp, nb_discr)
    return data
end


# Function to solve the model with JuMP
function callbacks_1model_JuMP(model, nb_discr)
    # Set up the solver
    set_optimizer(model,Ipopt.Optimizer)
    nlp = MathOptNLPModel(model)
    data = callbacks_nlp(nlp, nb_discr)
    return data
end

function benchmark_model_callbacks(model_key, inits ,nb_discr_list)
    Results = Dict{Symbol,Any}()
    solve_OC = true
    solve_JMP = true
    R_OC = []
    R_JuMP = []
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
            info_OC = callbacks_1model_OC(model, inits[model_key](;nh=nb_discr-1), nb_discr)
            push!(R_OC, info_OC)
            println("✅")
        end
        if solve_JMP
            print("Benchmarking the model $model_key with JuMP ($nb_discr)... ")
            model = JMPProblems.function_JMP[model_key](;nh=nb_discr)
            info_JuMP = callbacks_1model_JuMP(model, nb_discr)
            push!(R_JuMP, info_JuMP)
            println("✅")
        end
    end
    Results[:JuMP] = R_JuMP
    Results[:OptimalControl] = R_OC
    return Results


end