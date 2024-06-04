function OCPDef{EXAMPLE}()
  
    title = "Catalyst Mixing"

    # ------------------------------------------------------------------------------------------
    # parameters 
    tf = 1.0
    t0 = 0.0
    bc = [1.0, 0.0]  # Boundary conditions for x
    x0 = [1,0]
    
    # the model    
    @def ocp begin
        # parameters
        tf = 1.0
        t0 = 0.0
        bc = [1.0, 0.0]
        x0 = [1,0]
        # variables
        t ∈ [ t0, tf ]  , time
        x ∈ R²          , state
        u ∈ R           , control

        # constraints
        0 ≤ u(t) ≤ 1,           (u_con)
        x(t0) == x0,         (initial_con)

        # dynamics
        ẋ(t) == F0(x(t)) + u(t)*F1(x(t))

        # objective
        -1.0 + x₁(tf) + x₂(tf) → min
    end
    function F0(x)
        x1, x2 = x
        return [ 0, -x2 ]
    end
    function F1(x)
        x1, x2 = x
        return [10*x2 - x1  , x1 - 9*x2]
    end
    
    return OptimalControlProblem(title, ocp, sol)


end
