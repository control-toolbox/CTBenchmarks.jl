function prettytime(t)
    if t < 1e3
        value, units = t, "ns"
    elseif t < 1e6
        value, units = t / 1e3, "μs"
    elseif t < 1e9
        value, units = t / 1e6, "ms"
    else
        value, units = t / 1e9, "s"
    end
    return string(value , " " , units)
end

function jac_hess_nnz_JMP(model)
    nlp = MOI.Nonlinear.Model()
    for (F, S) in list_of_constraint_types(model)
        if F <: VariableRef
            continue
        end
        for ci in all_constraints(model, F, S)
            object = constraint_object(ci)
            MOI.Nonlinear.add_constraint(nlp, object.func, object.set)
        end
    end
    MOI.Nonlinear.set_objective(nlp, objective_function(model))
    evaluator = MOI.Nonlinear.Evaluator(
        nlp,
        MOI.Nonlinear.SparseReverseMode(),
        index.(all_variables(model)),
    )
    MOI.initialize(evaluator, MOI.features_available(evaluator))
    nnz_hess = length(MOI.hessian_lagrangian_structure(evaluator))
    nnz_jac = length(MOI.jacobian_structure(evaluator))
    return nnz_jac , nnz_hess
end