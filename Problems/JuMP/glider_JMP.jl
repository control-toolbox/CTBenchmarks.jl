"""
    Hang Glider Problem:
        We want to find the optimal trajectory of a hang glider.
        The objective is to maximize the final horizontal position of the glider while in the presence of a thermal updraft.
        The problem is formulated as a JuMP model.
    Ref: https://github.com/MadNLP/COPSBenchmark.jl/blob/main/src/glider.jl

"""

function glider_JMP(;nh::Int64=200)
    # Design parameters
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

    model = JuMP.Model()

    @variables(model, begin
        0 <= t_f,                       (start=1.0)
        0.0 <= x[k=0:nh],               (start=x_0 + vx_0*(k/nh))
        y[k=0:nh],                      (start=y_0 + (k/nh)*(y_f - y_0))
        0.0 <= vx[k=0:nh],              (start=vx_0)
        vy[k=0:nh],                     (start=vy_0)
        cL_min <= cL[k=0:nh] <= cL_max, (start=cL_max/2.0)
    end)

    @objective(model, Max, x[nh])

    @expressions(model, begin
        step,           t_f / nh
        r[i=0:nh],      (x[i]/r_0 - 2.5)^2
        u[i=0:nh],      u_c*(1 - r[i])*exp(-r[i])
        w[i=0:nh],      vy[i] - u[i]
        v[i=0:nh],      sqrt(vx[i]^2 + w[i]^2)
        D[i=0:nh],      0.5*(c0+c1*cL[i]^2)*rho*S*v[i]^2
        L[i=0:nh],      0.5*cL[i]*rho*S*v[i]^2
        vx_dot[i=0:nh], (-L[i]*(w[i]/v[i]) - D[i]*(vx[i]/v[i]))/m
        vy_dot[i=0:nh], (L[i]*(vx[i]/v[i]) - D[i]*(w[i]/v[i]))/m - g
    end)

    # Dynamics
    @constraints(model, begin
        x_eqn[j=1:nh],  x[j] == x[j-1] + 0.5 * step * (vx[j] + vx[j-1])
        y_eqn[j=1:nh],  y[j] == y[j-1] + 0.5 * step * (vy[j] + vy[j-1])
        vx_eqn[j=1:nh], vx[j] == vx[j-1] + 0.5 * step * (vx_dot[j] + vx_dot[j-1])
        vy_eqn[j=1:nh], vy[j] == vy[j-1] + 0.5 * step * (vy_dot[j] + vy_dot[j-1])
    end)
    # Boundary constraints
    @constraints(model, begin
        x[0] == x_0
        y[0] == y_0
        y[nh] == y_f
        vx[0] == vx_0
        vx[nh] == vx_f
        vy[0] == vy_0
        vy[nh] == vy_f
    end)

    return model
end

