"""
    Quadrotor Problem:
        We want to find the optimal trajectory of a quadrotor to reach a target position.
        The objective is to minimize the final time of the quadrotor while avoiding obstacles.
        The problem is formulated as an OptimalControl model.
    Ref: https://arxiv.org/pdf/2303.16746
"""
function quadrotor_JMP(;nh::Int64=100)
    # parameters
    g = -9.81
    atmin = 0
    atmax = 9.18*5
    tiltmax = 1.1 / 2
    dtiltmax = 6.0 / 2
    p0 = [0.0, 0.0, 2.5]
    v0 = [0, 0, 0]
    u0 = [9.81, 0, 0, 0]
    pf = [0.01, 5.0, 2.5]
    vf = [0.0, 0.0, 0.0]
    ϕf = 0.0

    model = JuMP.Model()

    @variables(model, begin
        0.0 <= tf
        p1[0:nh]
        p2[0:nh]
        p3[0:nh]
        v1[0:nh]
        v2[0:nh]
        v3[0:nh]
        atmin <= at[0:nh] <= atmax,  (start=10.0)
        - pi/2 <= ϕ[0:nh] <= pi/2
        - pi/2 <= θ[0:nh] <= pi/2
        ψ[0:nh]
    end)

    @expressions(model, begin
        step, tf / nh
        ϕ_dot[j=1:nh], (ϕ[j] - ϕ[j-1]) / step
        θ_dot[j=1:nh], (θ[j] - θ[j-1]) / step
    end)

    @constraints(model,begin
        cond_tiltmax[j=0:nh], cos(θ[j])*cos(ϕ[j]) >= cos(tiltmax)
        cond_dtiltmax1[j=1:nh], -dtiltmax <= ϕ_dot[j] <= dtiltmax
        cond_dtiltmax2[j=1:nh], -dtiltmax <= θ_dot[j] <= dtiltmax
    end)

    # initial and final conditions
    @constraints(model,begin
        p1_i, p1[0] == p0[1]
        p2_i, p2[0] == p0[2]
        p3_i, p3[0] == p0[3]
        v1_i, v1[0] == v0[1]
        v2_i, v2[0] == v0[2]
        v3_i, v3[0] == v0[3]
        #at_i, at[0] == u0[1]
        #ϕ_i, ϕ[0] == u0[2]
        #θ_i, θ[0] == u0[3]
        #ψ_i, ψ[0] == u0[4]
        p1_f, p1[nh] == pf[1]
        p2_f, p2[nh] == pf[2]
        p3_f, p3[nh] == pf[3]
        v1_f, v1[nh] == vf[1]
        v2_f, v2[nh] == vf[2]
        v3_f, v3[nh] == vf[3]
        #ϕ_f, ϕ[nh] == ϕf
    end)

    # dynamics
    @expressions(model, begin
        cr[j=0:nh],     cos(ϕ[j])
        sr[j=0:nh],     sin(ϕ[j])
        cp[j=0:nh],     cos(θ[j])
        sp[j=0:nh],     sin(θ[j])
        cy[j=0:nh],     cos(ψ[j])
        sy[j=0:nh],     sin(ψ[j])
        R[j=0:nh],      [(cy[j]*cp[j]) (sy[j]*cp[j]) (-sp[j]);
                        (cy[j]*sp[j]*sr[j]-sy[j]*cr[j]) (sy[j]*sp[j]*sr[j] + cy[j]*cr[j]) (cp[j]*sr[j]);
                        (cy[j]*sp[j]*cr[j] + sy[j]*sr[j]) (sy[j]*sp[j]*cr[j]-cy[j]*sr[j]) (cp[j]*cr[j]) ]
        at_[j=0:nh],    R[j] * [0 ; 0 ; at[j]]
        g_,             [0 ; 0 ; g]
        a[j=0:nh],      at_[j] + g_
    end)
    @constraints(model,begin
        d_p1[j=1:nh], p1[j] == p1[j-1] + 0.5 * step * (v1[j] + v1[j-1])
        d_p2[j=1:nh], p2[j] == p2[j-1] + 0.5 * step * (v2[j] + v2[j-1])
        d_p3[j=1:nh], p3[j] == p3[j-1] + 0.5 * step * (v3[j] + v3[j-1])
        d_v1[j=1:nh], v1[j] == v1[j-1] + 0.5 * step * (a[j][1] + a[j-1][1])
        d_v2[j=1:nh], v2[j] == v2[j-1] + 0.5 * step * (a[j][2] + a[j-1][2])
        d_v3[j=1:nh], v3[j] == v3[j-1] + 0.5 * step * (a[j][3] + a[j-1][3]) 
    end)

    @objective(model, Min, tf + 
            sum(1e-8 * (at[j] + ϕ[j] + θ[j] + ψ[j]) for j in 0:nh) +
            sum(1e2*(ψ[j]- u0[3])^2 for j in 0:nh) 
            )
    return model


end