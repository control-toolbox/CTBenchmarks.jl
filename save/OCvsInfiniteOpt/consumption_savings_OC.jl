function consumption_savings_OC(; nh=1000)
    B0 = 100.0 # endowment
    ocp = @def begin
        # Constants
        ρ = 0.025  # discount rate
        k = 100.0  # utility bliss point
        T = 10.0   # life horizon
        r = 0.05   # interest rate
        B0 = 100.0 # endowment

        t ∈ [0, T], time
        x ∈ R, state
        u ∈ R, control

        # constraints
        x(0) == B0
        x(T) == 0

        # Dynamics
        ẋ(t) == [r*x(t) - u(t)]

        # Objective
        ∫(exp(-ρ*t) * (-(u(t) - k)^2)) → max
    end

    # Initial guess
    init = (state=B0, control=B0)

    # NLPModel + DOCP
    res = direct_transcription(ocp; init=init, grid_size=nh)

    return res
end
