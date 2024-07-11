
"""
    dielectrophoretic_particle_model

Implement the optimal control of a particle in a
Dielectrophoretic system, from [CPR2006].

- nx: 2
- nu: 2
- time: free


# Reference

[CPR2006] Chang, D. E., Petit, N., & Rouchon, P. (2006). Time-optimal control of a particle in a dielectrophoretic system. IEEE Transactions on Automatic Control, 51(7), 1100-1114.

"""
function dielectrophoretic_particle_model(N)
    x0 = 1.0
    xf = 2.0
    α = -0.75
    c = 1.0

    model = Model()

    @variable(model, x[0:N], start=1.0)
    @variable(model, y[0:N], start=1.0)
    @variable(model, -1.0 <= u[0:N] <= 1.0)
    @variable(model, 0 <= tf, start=1.0)

    # Objective
    @objective(model, Min, tf)

    # Dynamics
    @expressions(model, begin
        step,      tf / N
        dx[t=0:N], y[t]*u[t] + α*u[t]^2
        dy[t=0:N], -c*y[t] + u[t]
    end)
    # Collocation
    @constraints(model, begin
        [t=1:N], x[t] == x[t-1] + 0.5 * step * (dx[t] + dx[t-1])
        [t=1:N], y[t] == y[t-1] + 0.5 * step * (dy[t] + dy[t-1])
    end)
    # Boundary constraints
    @constraints(model, begin
        x[0] == x0
        x[N] == xf
        y[0] == 0.0
    end)

    return model
end

