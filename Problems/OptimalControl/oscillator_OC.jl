"""
    Double Oscillator Problem:
        Implement the optimal control of a double oscillator toy model.
        The problem is formulated as an OptimalControl model.
    Ref: [CLP2018] Coudurier, C., Lepreux, O., & Petit, N. (2018). Optimal bang-bang control of a mechanical double oscillator using averaging methods. IFAC-PapersOnLine, 51(2), 49-54.
"""
function double_oscillator_OC()
# parameters
    m1 = 100.0 # [kg]
    m2 = 2.0   # [kg]
    c = 0.5    # [Ns/m]
    k1 = 100.0 # [N/m]
    k2 = 3.0   # [N/m]
    tf = 2π

    @def ocp begin
        ## parameters
            m1 = 100.0 # [kg]
            m2 = 2.0   # [kg]
            c = 0.5    # [Ns/m]
            k1 = 100.0 # [N/m]
            k2 = 3.0   # [N/m]
            tf = 2π

        ## define the problem
            t ∈ [ 0.0, tf ], time
            x ∈ R⁴, state
            u ∈ R¹, control

        ## constraints
            # control constraints
            -1.0 ≤ u(t) ≤ 1.0,                          (u_con)
            # initial constraints
            x₁(0.0) == 0.0,                                (x1_con)
            x₂(0.0) == 0.0,                                (x2_con)
        
        ## dynamics
            ẋ(t) == dynamics(x(t), u(t),F(t))
        
        ## objective
            0.5 * ∫(x₁(t)^2 + x₂(t)^2 + u(t)^2) → min

    end

    function F(t)
        return sin(t * 2π/tf)
    end

    function dynamics(x,u,F)
        x1, x2, x3, x4 = x

        dx1 = x3
        dx2 = x4
        dx3 = -(k1 + k2)/m1 * x1 + k2/m1 * x2 + 1/m1 * F
        dx4 = k2 / m2 * x1 - k2/m2 * x2 - c*(1 - u)/m2 * x4

        return [dx1, dx2, dx3, dx4]
    end

    return ocp

end


function double_oscillator_init(;nh)
    return ()
end