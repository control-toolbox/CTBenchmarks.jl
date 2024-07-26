"""
    Dielectrophoretic particle problem:
        This problem consists of a dielectrophoretic particle system.
        The goal is to find the trajectory that minimize the time taken for the particle to travel between two points.
        The problem is formulated as an OptimalControl model.
    Ref: [CPR2006] Chang, D. E., Petit, N., & Rouchon, P. (2006). Time-optimal control of a particle in a dielectrophoretic system. IEEE Transactions on Automatic Control, 51(7), 1100-1114.
"""
function dielectrophoretic_particle_OC()
# parameters
x0 = 1.0
xf = 2.0
α = -0.75
c = 1.0

    @def ocp begin
    ## parameters
    x0 = 1.0
    xf = 2.0
    α = -0.75
    c = 1.0

    ## define the problem
        tf ∈ R¹, variable
        t ∈ [ 0.0, tf ], time
        x ∈ R², state
        u ∈ R¹, control

    ## state variables
        pos_x = x₁
        pos_y = x₂

    ## constraints
        # state constraints
        tf ≥ 0.0,                                       (tf_con)
        # control constraints
        -1.0 ≤ u(t) ≤ 1.0,                             (u_con)
        # initial constraints
        pos_x(0) == x0,                                 (pos_x0_con)
        pos_y(0) == 0.0,                                (pos_y0_con)
        # final constraints
        pos_x(tf) == xf,                                (pos_xf_con)

    ## dynamics
        ẋ(t) == dynamics(x(t), u(t))

    ## objective  
        tf → min
    end

    function dynamics(x,u)
        pos_x , pos_y = x

        dx = pos_y*u + α*u^2
        dy = -c*pos_y + u

        return [dx, dy]
    end

    return ocp
end


function dielectrophoretic_particle_init(;nh)
    init = (state = [1.0,1.0],control = 0.0,variable = 1.0);
    return init
end