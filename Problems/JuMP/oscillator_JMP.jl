"""
    Double Oscillator Problem:
        Implement the optimal control of a double oscillator toy model.
        The problem is formulated as a JuMP model.
    Ref: [CLP2018] Coudurier, C., Lepreux, O., & Petit, N. (2018). Optimal bang-bang control of a mechanical double oscillator using averaging methods. IFAC-PapersOnLine, 51(2), 49-54.
"""
function double_oscillator_JMP(;N::Int=100)
    m1 = 100.0 # [kg]
    m2 = 2.0   # [kg]
    c = 0.5    # [Ns/m]
    k1 = 100.0 # [N/m]
    k2 = 3.0   # [N/m]
    tf = 2π
    step = tf / N

    F(t) = sin(t * 2π/tf)

    model = Model()

    @variables(model, begin
        x1[0:N]
        x2[0:N]
        x3[0:N]
        x4[0:N]
        -1.0 <= u[0:N] <= 1.0
    end)

    # Objective
    @objective(model, Min, 0.5 * sum(x1[t]^2 + x2[t]^2 + u[t]^2 for t in 0:N))

    # Dynamics
    @expressions(model, begin
        dx1[t=0:N], x3[t]
        dx2[t=0:N], x4[t]
        dx3[t=0:N], -(k1 + k2)/m1 * x1[t] + k2/m1 * x2[t] + 1/m1 * F(t * step)
        dx4[t=0:N], k2 / m2 * x1[t] - k2/m2 * x2[t] - c*(1 - u[t])/m2 * x4[t]
    end)
    # Collocation
    @constraints(model, begin
        con_x1[t=1:N], x1[t] == x1[t-1] + 0.5 * step * (dx1[t] + dx1[t-1])
        con_x2[t=1:N], x2[t] == x2[t-1] + 0.5 * step * (dx2[t] + dx2[t-1])
        con_x3[t=1:N], x3[t] == x3[t-1] + 0.5 * step * (dx3[t] + dx3[t-1])
        con_x4[t=1:N], x4[t] == x4[t-1] + 0.5 * step * (dx4[t] + dx4[t-1])
    end)
    # Boundary
    @constraints(model, begin
        x1[0] == 0.0
        x2[0] == 0.0
    end)

    return model
end

