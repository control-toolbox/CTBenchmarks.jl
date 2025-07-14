function quadrotor_OC(; nh=100)
    n = 9
    p = 4
    ocp = @def begin
        # Data
        n = 9
        p = 4
        nd = 9
        T = 60

        t ∈ [0, T], time
        x ∈ R^n, state
        u ∈ R^p, control

        d1 = t -> sin(2 * pi * t/T)
        d3 = t->2 * sin(4 * pi * t/T)
        d5 = t->2 * (t/T)

        # constraints
        x(0) == [0, 0, 0, 0, 0, 0, 0, 0, 0]

        # Dynamics
        ẋ(t) == [
            x[2](t),
            u[1](t) * cos(x[7](t)) * sin(x[8](t)) * cos(x[9](t)) +
            u[1](t) * sin(x[7](t)) * sin(x[9](t)),
            x[4](t),
            u[1](t) * cos(x[7](t)) * sin(x[8](t)) * sin(x[9](t)) -
            u[1](t) * sin(x[7](t)) * cos(x[9](t)),
            x[6](t),
            u[1](t) * cos(x[7](t)) * cos(x[8](t)) - 9.8,
            u[2](t) * cos(x[7](t)) / cos(x[8](t)) + u[3](t) * sin(x[7](t)) / cos(x[8](t)),
            -u[2](t) * sin(x[7](t)) + u[3](t) * cos(x[7](t)),
            u[2](t) * cos(x[7](t)) * tan(x[8](t)) +
            u[3](t) * sin(x[7](t)) * tan(x[8](t)) +
            u[4](t),
        ]

        # Objective
        ∫(
            (x[1](t) - d1(t))^2 +
            (x[3](t) - d3(t))^2 +
            (x[5](t) - d5(t))^2 +
            x[7](t)^2 +
            x[8](t)^2 +
            x[9](t)^2 +
            0.1 * (u[1](t)^2 + u[2](t)^2 + u[3](t)^2 + u[4](t)^2),
        ) → min
    end

    # Initial guess
    init = (state=[0, 0, 0, 0, 0, 0, 0, 0, 0], control=[0, 0, 0, 0])

    # NLPModel + DOCP
    res = direct_transcription(ocp; init=init, grid_size=nh)

    return res
end
