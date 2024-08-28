"""
    Hang Glider Problem:
        We want to find the optimal trajectory of a hang glider.
        The objective is to maximize the final horizontal position of the glider while in the presence of a thermal updraft.
        The problem is formulated as an OptimalControl model.
"""
function glider_OC()
# parameters
    x_0 = 0.0
    y_0 = 1000.0
    y_f = 900.0
    vx_0 = 13.23
    vx_f = 13.23
    vy_0 = -1.288
    vy_f = -1.288
    u_c = 2.5
    r_0 = 100.0
    m = 100.0
    g = 9.81
    c0 = 0.034
    c1 = 0.069662
    S = 14.0
    rho = 1.13
    cL_min = 0.0
    cL_max = 1.4
    t0 = 0.0

    @def ocp begin
    ## parameters
        x_0 = 0.0
        y_0 = 1000.0
        y_f = 900.0
        vx_0 = 13.23
        vx_f = 13.23
        vy_0 = -1.288
        vy_f = -1.288
        u_c = 2.5
        r_0 = 100.0
        m = 100.0
        g = 9.81
        c0 = 0.034
        c1 = 0.069662
        S = 14.0
        rho = 1.13
        cL_min = 0.0
        cL_max = 1.4
        t0 = 0.0
    ## define the problem
        tf ∈ R¹, variable
        t ∈ [ t0, tf ], time
        x ∈ R⁴, state
        u ∈ R¹, control
    ## state variables
        y = x₂
        vx = x₃
        vy = x₄
    ## control variables
        cL = u₁

    ## constraints
        # state constraints
        x₁(t) ≥ 0.0,                        (x_con)
        vx(t) ≥ 0.0,                       (vx_con)
        # control constraints
        cL_min ≤ cL(t) ≤ cL_max,         (cL_con)
        # initial conditions
        x₁(t0) == x_0,                    (x0_con)
        y(t0) == y_0,                    (y0_con)
        vx(t0) == vx_0,                  (vx0_con)
        vy(t0) == vy_0,                  (vy0_con)
        # final conditions
        y(tf) == y_f,                    (yf_con)
        vx(tf) == vx_f,                  (vxf_con)
        vy(tf) == vy_f,                  (vyf_con)

    ## dynamics
        ẋ(t) == dynamics(x(t),u(t))

    ## objective
        x₁(tf) → max

    end

    function dynamics(x,u)
        x1, y, vx, vy = x
        cL = u
        ## Helper functions
        r = (x1/r_0 - 2.5)^2
        UpD = u_c*(1 - r)*exp(-r)
        w = vy - UpD
        v = sqrt(vx^2 + w^2)
        D = 0.5*(c0+c1*(cL^2))*rho*S*(v^2)
        L = 0.5*cL*rho*S*(v^2)
        vx_dot = (-L*(w/v) - D*(vx/v))/m
        vy_dot = ((L*(vx/v) - D*(w/v))/m) - g
        return [vx, vy, vx_dot, vy_dot]
    end

    return ocp

end


function glider_init(;nh)
    x_0 = 0.0
    y_0 = 1000.0
    y_f = 900.0
    vx_0 = 13.23
    vy_0 = -1.288
    cL_max = 1.4
    tf = 90.0

    xinit = [[x_0 + vx_0*(k/nh),
            y_0 + (k/nh)*(y_f - y_0),
            vx_0 ,
            vy_0] for k=0:nh]
    uinit = cL_max/2.0
    time_vec = LinRange(0.0,tf,nh+1)
    init = (time=time_vec,state = xinit, control = uinit , variable= 1.0,)
    return init
end