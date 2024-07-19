"""
    electrical_vehicle_OC

Implement optimal control of an electrical vehicle, following [PS2011].

- nx: 2
- nu: 1
- time: fixed

# Reference

[PS2011] Nicolas Petit and Antonio Sciarretta. "Optimal drive of electric vehicles using an inversion-based trajectory generation approach." IFAC Proceedings Volumes 44, no. 1 (2011): 14519-14526.
"""
function electrical_vehicle_OC()
# parameters
    D = 10.0
    tf = 1.0
    b1 = 1e3
    b2 = 1e3
    h0 = 0.1
    h1 = 1.0
    h2 = 1e-3
    p0, p1, p2, p3 = (3.0, 0.4, -1.0, 0.1)

    @def ocp begin
    ## parameters
        D = 10.0
        tf = 1.0
        b1 = 1e3
        b2 = 1e3
        h0 = 0.1
        h1 = 1.0
        h2 = 1e-3
    ## define the problem
        t ∈ [ 0.0, tf ], time
        x ∈ R², state
        u ∈ R, control

    ## state variables
        pos = x₁
        v = x₂

    ## constraints
        # initial constraints
        pos(0) == 0.0,                                   (pos_i)
        v(0) == 0.0,                                     (v_i)
        # final constraints
        pos(tf) == D,                                    (pos_f)
        v(tf) == 0.0,                                    (v_f)
        
    ## dynamics
        ẋ(t) == dynamics(x(t), u(t))

    ## objective
        ∫(b1 *u(t) * v(t) + b2 * u(t)^2) → min

    end

    function road(x)
        return p0 + p1*x + p2*x^2 + p3*x^3
    end

    function dynamics(x, u)
        pos, v = x
        a = h1 * u - h2 * v^2 - h0 - road(pos)
        return [v, a]
    end

    return ocp

end


function electrical_vehicle_init(;nh)
    return ()
end