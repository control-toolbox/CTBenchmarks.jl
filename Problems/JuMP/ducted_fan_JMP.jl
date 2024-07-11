
"""
    ducted_fan_JMP

Implement the optimal control of a planar ducted fan.
Instance taken from [GP2009].

- nx: 6
- nu: 2
- time: free


# Reference

Graichen, K., & Petit, N. (2009). Incorporating a class of constraints into the dynamics of optimal control problems. Optimal Control Applications and Methods, 30(6), 537-561.

"""
function ducted_fan_JMP(;N::Int=100)
    r = 0.2         # [m]
    J = 0.05        # [kg.m2]
    m = 2.2         # [kg]
    mg = 4.0        # [N]
    μ = 1000.0

    model = Model()

    @variable(model, x1[0:N])
    @variable(model, v1[0:N])
    @variable(model, x2[0:N])
    @variable(model, v2[0:N])
    @variable(model, -deg2rad(30.0) <= α[0:N] <= deg2rad(30.0)) # radian
    @variable(model, vα[0:N])
    @variable(model, -5.0 <= u1[0:N] <= 5.0) # [N]
    @variable(model, 0.0 <= u2[0:N] <= 17.0) # [N]
    @variable(model, 0 <= tf, start=1.0)

    @objective(model, Min, tf / N * sum(2*u1[t]^2 + u2[t]^2 for t in 0:N) + μ * tf)

    # Dynamics
    @expressions(model, begin
        step,       tf / N
        dx1[t=0:N], v1[t]
        dv1[t=0:N], (u1[t] * cos(α[t]) - u2[t] * sin(α[t])) / m
        dx2[t=0:N], v2[t]
        dv2[t=0:N], (- mg + u1[t] * sin(α[t]) + u2[t] * cos(α[t])) / m
        dα[t=0:N], vα[t]
        dvα[t=0:N], r * u1[t] / J
    end)
    # Collocation
    @constraints(model, begin
        con_x1[t=1:N], x1[t] == x1[t-1] + 0.5 * step * (dx1[t] + dx1[t-1])
        con_v1[t=1:N], v1[t] == v1[t-1] + 0.5 * step * (dv1[t] + dv1[t-1])
        con_x2[t=1:N], x2[t] == x2[t-1] + 0.5 * step * (dx2[t] + dx2[t-1])
        con_v2[t=1:N], v2[t] == v2[t-1] + 0.5 * step * (dv2[t] + dv2[t-1])
        con_α[t=1:N], α[t] == α[t-1] + 0.5 * step * (dα[t] + dα[t-1])
        con_vα[t=1:N], vα[t] == vα[t-1] + 0.5 * step * (dvα[t] + dvα[t-1])
    end)
    # Boundary constraints
    @constraints(model, begin
        x1[0] == 0.0
        x2[0] == 0.0
        α[0] == 0.0
        v1[0] == 0.0
        v2[0] == 0.0
        vα[0] == 0.0
        x1[N] == 1.0
        x2[N] == 0.0
        α[N] == 0.0
        v1[N] == 0.0
        v2[N] == 0.0
        vα[N] == 0.0
    end)

    return model
end

