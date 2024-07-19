"""
    Quadrotor Problem:
        We want to find the optimal trajectory of a quadrotor to reach a target position.
        The objective is to minimize the final time.
        The problem is formulated as an OptimalControl model.
"""
function quadrotorP2P_OC()
# parameters
g = 9.81
atmin = 0
atmax = 9.18*5
tiltmax = 1.1 / 2
dtiltmax = 6.0 / 2
p0 = [0.0, 0.0, 2.5]
v0 = [0, 0, 0]
u0 = [9.81, 0, 0, 0]
pf = [0.01, 5.0, 2.5]
vf = [0.0, 0.0, 0.0]

    @def ocp begin
    ## parameters
        g = 9.81
        atmin = 0
        atmax = 9.18*5
        tiltmax = 1.1 / 2
        dtiltmax = 6.0 / 2
        p0 = [0.0, 0.0, 2.5]
        v0 = [0, 0, 0]
        u0 = [9.81, 0, 0, 0]
        pf = [0.01, 5.0, 2.5]
        vf = [0.0, 0.0, 0.0]

    ## define the problem
        tf ∈ R¹, variable
        t ∈ [ 0.0, tf ], time
        x ∈ R⁸, state
        u ∈ R⁴, control

    ## state variables
        p1 = x₁
        p2 = x₂
        p3 = x₃
        v1 = x₄
        v2 = x₅
        v3 = x₆
        ϕ = x₇
        θ = x₈
    ## control variables
        at = u₁
        ϕ_dot = u₂
        θ_dot = u₃
        ψ = u₄

    ## constraints
        # state constraints
        tf ≥ 0.0,                                       (tf_con)
        # control constraints
        -pi/2 ≤ ϕ(t) ≤ pi/2,                            (ϕ_con) 
        -pi/2 ≤ θ(t) ≤ pi/2,                            (θ_con)
        cos(θ(t))*cos(ϕ(t)) ≥ cos(tiltmax),             (tiltmax_con)
        -dtiltmax ≤ ϕ_dot(t)   ≤ dtiltmax,              (ϕdot_con)
        -dtiltmax ≤ θ_dot(t)  ≤ dtiltmax,               (θdot_con)
        atmin ≤ at(t) ≤ atmax,                          (at_con)
        # initial constraints
        p1(0) == p0[1],      (p1_i)
        p2(0) == p0[2],      (p2_i)
        p3(0) == p0[3],      (p3_i)
        v1(0) == v0[1],      (v1_i)
        v2(0) == v0[2],      (v2_i)
        v3(0) == v0[3],      (v3_i)
        ϕ(0) == u0[2],      (ϕ_i)
        θ(0) == u0[3],      (θ_i)
        # final constraints
        p1(tf) == pf[1],     (p1_f)
        p2(tf) == pf[2],     (p2_f)
        p3(tf) == pf[3],     (p3_f)
        v1(tf) == vf[1],   (v1_f)
        v2(tf) == vf[2],   (v2_f)
        v3(tf) == vf[3],   (v3_f)

    ## dynamics
        ẋ(t) == dynamics(x(t), u(t))

    ## objective  
        tf + ∫(1e-8 * (ϕ(t)^2 + θ(t)^2 +ψ(t)^2 + at(t)^2) + (1e2*(ψ(t)- u0[3])^2)) → min
    end

    function dynamics(x,u)
        p1, p2, p3, v1, v2, v3, ϕ, θ = x
        at , ϕ_dot, θ_dot, ψ = u

        cr = cos(ϕ)
        sr = sin(ϕ)
        cp = cos(θ)
        sp = sin(θ)
        cy = cos(ψ)
        sy = sin(ψ)
        R=  [(cy*cp)    (cy*sp*sr - sy*cr) (cy*sp*cr + sy*sr);
            (sy*cp)     (sy*sp*sr + cy*cr) (sy*sp*cr - cy*sr);
            (-sp)       (cp*sr)            (cp*cr)]
        at_ = R*[0;0;at]
        g_ = [0;0;-g]
        a = g_ + at_

        return [v1, v2, v3, a[1], a[2], a[3], ϕ_dot, θ_dot]
    end

    return ocp
end



function quadrotorP2P_init(;nh)
    init = (control = [10, 0.0, 0.0, 0.0],);
    return init
end