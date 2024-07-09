"""
    The Moonlander Problem:
        We want to find the optimal trajectory for a moonlander to land on the moon.
        The objective is to minimize the time taken to land on the moon.
        The problem is formulated as a JuMP model.
    Ref: https://arxiv.org/pdf/2303.16746
"""
target = [5.0, 5.0]
function moonlander_JMP(;target::Array{Float64}=target,nh::Int64=500)
## parameters
    if size(target) != (2,)
        error("The input matrix must be 3x3.")
    end
    m = 1.0
    g = 9.81
    I = 0.1
    D = 1.0
    max_thrust = 2*g 

    ## define the problem
    model = JuMP.Model()

    @variables(model, begin
        0.0 <= tf
        # state variables
        p1[k=0:nh]
        p2[k=0:nh]
        dp1[k=0:nh]
        dp2[k=0:nh]
        theta[k=0:nh]
        dtheta[k=0:nh]

        # control variables
        0 <= F1[k=0:nh] <= max_thrust,     (start = 5.0)
        0 <= F2[k=0:nh] <= max_thrust,     (start = 5.0)
    end)

    # Initial and final conditions
    @constraints(model, begin
        p1[0] == 0.0
        p2[0] == 0.0
        dp1[0] == 0.0
        dp2[0] == 0.0
        theta[0] == 0.0
        dtheta[0] == 0.0
        p1[nh] == target[1]
        p2[nh] == target[2]
        dp1[nh] == 0.0
        dp2[nh] == 0.0
    end)
    
    #dynamics
    @expressions(model, begin
        F_r[k=0:nh], [cos(theta[k]) -sin(theta[k]) p1[k];
                      sin(theta[k]) cos(theta[k]) p2[k];
                      0.0 0.0 1.0]
    end)
    @expressions(model, begin
        F_tot[k=0:nh], (F_r[k] * [0; F1[k] + F2[k]; 0])[1:2]
    end)
    @expressions(model, begin
        ddp1[k=0:nh], (1/m) * F_tot[k][1]
        ddp2[k=0:nh], (1/m) * F_tot[k][2] - g
        ddtheta[k=0:nh], (1/I) * (D/2) * (F2[k] - F1[k])
    end)    
    @expressions(model, begin
        step,           tf / nh
    end)

    @constraints(model, begin
    d_p1[k=1:nh], p1[k] == p1[k-1] + 0.5 * step * (dp1[k] + dp1[k-1])
    d_p2[k=1:nh], p2[k] == p2[k-1] + 0.5 * step * (dp2[k] + dp2[k-1])
    d_dp1[k=1:nh], dp1[k] == dp1[k-1] + 0.5 * step * (ddp1[k] + ddp1[k-1])
    d_dp2[k=1:nh], dp2[k] == dp2[k-1] + 0.5 * step * (ddp2[k] + ddp2[k-1])
    d_theta[k=1:nh], theta[k] == theta[k-1] + 0.5 * step * (dtheta[k] + dtheta[k-1])
    d_dtheta[k=1:nh], dtheta[k] == dtheta[k-1] + 0.5 * step * (ddtheta[k] + ddtheta[k-1])
    end)

    @objective(model, Min, tf)

    return model
end