"""
    Quadrotor Problem:
        We want to find the optimal trajectory of a quadrotor to reach a target position.
        The objective is to minimize the final time of the quadrotor while avoiding obstacles.
        The problem is formulated as an OptimalControl model.
"""
function quadrotor_OC()
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

    @def ocp begin
    ## parameters
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

    ## define the problem
        tf ∈ R¹, variable
        t ∈ [ 0.0, tf ], time
        x ∈ R⁶, state
        u ∈ R⁴, control

    ## state variables
        p1 = x₁
        p2 = x₂
        p3 = x₃
        v1 = x₄
        v2 = x₅
        v3 = x₆
    ## control variables
        at = u₁
        ϕ = u₂
        θ = u₃
        ψ = u₄

    ## constraints
        # state constraints
        tf ≥ 0.0,                                             (tf_con)
        # control constraints
        -pi/2 ≤ ϕ(t) ≤ pi/2,                                   (ϕ_con) 
        -pi/2 ≤ θ(t) ≤ pi/2,                                   (θ_con)
        cos(θ(t))*cos(ϕ(t)) ≥ cos(tiltmax),                       (tiltmax_con)
        #-dtiltmax ≤ (ϕ(t+1e-9) - ϕ(t)) / 1e-10   ≤ dtiltmax    , (ϕdot_con)
        #-dtiltmax ≤ (θ(t+1e-9) - θ(t)) / 1e-9  ≤ dtiltmax,  (θdot_con)
        atmin ≤ at(t) ≤ atmax,                                 (at_con)
        # initial constraints
        p1(0) == p0[1],      (p1_i)
        p2(0) == p0[2],      (p2_i)
        p3(0) == p0[3],      (p3_i)
        v1(0) == v0[1],      (v1_i)
        v2(0) == v0[2],      (v2_i)
        v3(0) == v0[3],      (v3_i)
        #at(0) == u0[1],      (at_i)
        #ϕ(0) == u0[2],      (ϕ_i)
        #θ(0) == u0[3],      (θ_i)
        #ψ(0) == u0[4],      (ψ_i)
        # final constraints
        p1(tf) == pf[1],     (p1_f)
        p2(tf) == pf[2],     (p2_f)
        p3(tf) == pf[3],     (p3_f)
        v1(tf) == vf[1],   (v1_f)
        v2(tf) == vf[2],   (v2_f)
        v3(tf) == vf[3],   (v3_f)
        #ϕ(tf) == ϕf,       (ϕ_f)

    ## dynamics
        ẋ(t) == dynamics(x(t), u(t))

    ## objective  
        tf + ∫(1e-8 * (ϕ(t) + θ(t) +ψ(t) + at(t)) + (1e2*(ψ(t)- u0[3])^2)) → min
    end

    function dynamics(x,u)
        p1, p2, p3, v1, v2, v3 = x
        at, ϕ, θ, ψ = u

        cr = cos(ϕ)
        sr = sin(ϕ)
        cp = cos(θ)
        sp = sin(θ)
        cy = cos(ψ)
        sy = sin(ψ)

        R = [(cy*cp) (sy*cp)   (-sp);
            (cy*sp*sr-sy*cr )(sy*sp*sr + cy*cr)  (cp*sr );
            (cy*sp*cr + sy*sr)  (cp*sr)  (cp*cr);
            ]

        at_ = R*[0;0;at]
        g_ = [0;0;g]
        a = g_ + at_

        return [
            v1
            v2
            v3
            a[1]
            a[2]
            a[3]
        ]

    end
    return ocp
end