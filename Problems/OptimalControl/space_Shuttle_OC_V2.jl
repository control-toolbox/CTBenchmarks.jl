import Interpolations
"""
    Space Shuttle Reentry Trajectory Problem:
        We want to find the optimal trajectory of a space shuttle reentry.
        The objective is to minimize the angle of attack at the terminal point.
        The problem is formulated as an OptimalControl model.
"""
function space_Shuttle_OC_V2()
    ## Global variables
    w = 203000.0  # weight (lb)
    g₀ = 32.174    # acceleration (ft/sec^2)
    m = w / g₀    # mass (slug)

    ## Aerodynamic and atmospheric forces on the vehicle
    ρ₀ = 0.002378
    hᵣ = 23800.0
    Rₑ = 20902900.0
    μ = 0.14076539e17
    S = 2690.0
    a₀ = -0.20704
    a₁ = 0.029244
    b₀ = 0.07854
    b₁ = -0.61592e-2
    b₂ = 0.621408e-3
    c₀ = 1.06723181
    c₁ = -0:19213774e-1
    c₂ = 0.21286289e-3
    c₃ = -0:10117249e-5

    ## Initial conditions
    h_s = 2.6          # altitude (ft) / 1e5
    ϕ_s = deg2rad(0)   # longitude (rad)
    θ_s = deg2rad(0)   # latitude (rad)
    v_s = 2.56         # velocity (ft/sec) / 1e4
    γ_s = deg2rad(-1)  # flight path angle (rad)
    ψ_s = deg2rad(90)  # azimuth (rad)
    α_s = deg2rad(0)   # angle of attack (rad)
    β_s = deg2rad(0)   # bank angle (rad)
    t_s = 1.00         # time step (sec)

    ## Final conditions, the so-called Terminal Area Energy Management (TAEM)
    h_t = 0.8          # altitude (ft) / 1e5
    v_t = 0.25         # velocity (ft/sec) / 1e4
    γ_t = deg2rad(-5)  # flight path angle (rad)
    tf = 2009.0 # final time (sec)
    t0 = 0.0 # initial time (sec)
    qᵤ = 70.0

    @def ocp begin 
    ## parameters
        w = 203000.0  # weight (lb)
        g₀ = 32.174    # acceleration (ft/sec^2)
        m = w / g₀    # mass (slug)
        ρ₀ = 0.002378
        hᵣ = 23800.0
        Rₑ = 20902900.0
        μ = 0.14076539e17
        S = 2690.0
        a₀ = -0.20704
        a₁ = 0.029244
        b₀ = 0.07854
        b₁ = -0.61592e-2
        b₂ = 0.621408e-3
        c₀ = 1.06723181
        c₁ = -0.19213774e-1
        c₂ = 0.21286289e-3
        c₃ = -0.10117249e-5
        h_s = 2.6          # altitude (ft) / 1e5
        ϕ_s = deg2rad(0)   # longitude (rad)
        θ_s = deg2rad(0)   # latitude (rad)
        v_s = 2.56         # velocity (ft/sec) / 1e4
        γ_s = deg2rad(-1)  # flight path angle (rad)
        ψ_s = deg2rad(90)  # azimuth (rad)
        α_s = deg2rad(0)   # angle of attack (rad)
        β_s = deg2rad(0)   # bank angle (rad)
        t_s = 1.00 
        h_t = 0.8          # altitude (ft) / 1e5
        v_t = 0.25         # velocity (ft/sec) / 1e4
        γ_t = deg2rad(-5)  # flight path angle (rad)
        tf = 2008.0 # final time (sec)
        t0 = 0.0 # initial time (sec)
        qᵤ = 70.0

    ## define the problem
        t ∈ [ t0, tf ], time
        x ∈ R⁶, state
        u ∈ R², control

    ## state variables
        scaled_h = x₁
        ϕ = x₂
        θ = x₃
        scaled_v = x₄
        γ = x₅
        ψ = x₆

    ## control variables
        α = u₁
        β = u₂
    
    ## Heat 
        # Helper functions
        h = scaled_h * 1e5
        ρ = ρ₀ * exp(-h/hᵣ)
        qₐ = c₀ + c₁ * rad2deg(α) + c₂ * rad2deg(α)^2 + c₃ * rad2deg(α)^3
        qᵣ = 17.7 * sqrt(ρ) * scaled_v^3.07
        q = qₐ * qᵣ

    ## constraints
        # variable constraints
        # state constraints
        scaled_h(t) ≥ 0,                        (scaled_h_con)
        deg2rad(-89) ≤ θ(t) ≤ deg2rad(89),      (θ_con)
        scaled_v(t) ≥ 1e-4,                     (scaled_v_con)
        deg2rad(-89) ≤ γ(t) ≤ deg2rad(89),      (γ_con)
        # control constraints
        deg2rad(-89) ≤ β(t) ≤ deg2rad(1),       (β_con)
        deg2rad(-90) ≤ α(t) ≤ deg2rad(90),      (α_con)
        # initial conditions
        scaled_h(t0) == h_s,                    (scaled_h0_con)
        ϕ(t0) == ϕ_s,                           (ϕ0_con)
        θ(t0) == θ_s,                           (θ0_con)
        scaled_v(t0) == v_s,                    (scaled_v0_con)
        γ(t0) == γ_s,                           (γ0_con)
        ψ(t0) == ψ_s,                           (ψ0_con)
        # final conditions
        scaled_h(tf) == h_t,                    (scaled_hf_con)
        scaled_v(tf) == v_t,                    (scaled_vf_con)
        γ(tf) == γ_t,                           (γf_con)
        # heat constraints
        q(t) ≤ qᵤ,                              (q_con)

    ## dynamics  
        ẋ(t) == dynamics(x(t),u(t))

    ## objective
        θ(tf) → max
    end

    ## dynamics
    function dynamics(x,u)
        scaled_h, ϕ, θ, scaled_v, γ, ψ = x
        α, β = u
        h = scaled_h * 1e5
        v = scaled_v * 1e4
        ## Helper functions
        c_D = b₀ + b₁ * rad2deg(α) + b₂ * (rad2deg(α)^2)
        c_L = a₀ + a₁ * rad2deg(α)
        ρ = ρ₀ * exp(-h/hᵣ)
        D = (1/2) * c_D * S * ρ * (v^2)
        L = (1/2) * c_L * S * ρ * (v^2)
        r = Rₑ + h
        g = μ / (r^2)

        ## dynamics  
        h_dot = v * sin(γ)
        ϕ_dot = (v/r) * cos(γ) * sin(ψ) / cos(θ)
        θ_dot = (v/r) * cos(γ) * cos(ψ)
        v_dot = -(D/m) - g*sin(γ)
        γ_dot = (L/(m*v)) * cos(β) + cos(γ) * ((v/r)-(g/v))
        ψ_dot = (1/(m*v*cos(γ))) * L*sin(β) + (v/(r*cos(θ))) * cos(γ) * sin(ψ) * sin(θ)

        return [ h_dot, ϕ_dot, θ_dot, v_dot, γ_dot, ψ_dot]
    end

    return ocp
end


function space_Shuttle_init(;nh)
    n = nh
    ## Initial conditions
    h_s = 2.6          # altitude (ft) / 1e5
    ϕ_s = deg2rad(0)   # longitude (rad)
    θ_s = deg2rad(0)   # latitude (rad)
    v_s = 2.56         # velocity (ft/sec) / 1e4
    γ_s = deg2rad(-1)  # flight path angle (rad)
    ψ_s = deg2rad(90)  # azimuth (rad)
    α_s = deg2rad(0)   # angle of attack (rad)
    β_s = deg2rad(0)   # bank angle (rad)
    t_s = 1.00         # time step (sec)
    ## Final conditions
    h_t = 0.8          # altitude (ft) / 1e5
    v_t = 0.25         # velocity (ft/sec) / 1e4
    γ_t = deg2rad(-5)  # flight path angle (rad)
    tf = 2008.0 # final time (sec)

    x_s = [h_s, ϕ_s, θ_s, v_s, γ_s, ψ_s, α_s, β_s,t_s*n*4]
    x_t = [h_t, ϕ_s, θ_s, v_t, γ_t, ψ_s, α_s, β_s,t_s*n*4]
    interp_linear = Interpolations.LinearInterpolation([1, n], [x_s, x_t])
    initial_guess = mapreduce(transpose, vcat, interp_linear.(1:n))

    x_init = [initial_guess[i,1:6] for i in 1:n];
    u_init = [initial_guess[i,7:8] for i in 1:n];
    #t_init =  2012.0
    time_vec = LinRange(0.0,tf,n)
    #init = (time= time_vec, state= x_init, control= u_init,variable= t_init)
    init = (time= time_vec, state= x_init, control= u_init)
    return init
end