

function goddard_JMP(N::Int)
    title = "Goddard problem with state constraint - maximise altitude"

    Cd = 310
    Tmax = 3.5
    β = 500
    b = 2
    t0 = 0
    r0 = 1
    v0 = 0
    vmax = 0.1
    m0 = 1
    mf = 0.6
    x0 = [ r0, v0, m0 ]

    model = Model()

# Variables
    @variables(model, begin
        0.0 ≤ Δt ≤ Tmax - t0         # time step
        0 ≤ u(t) ≤ 1            # u
        r[1:N+1] ≥ r0           # r
        0 ≤ v[1:N+1] ≤ vmax     # v
        mf ≤ m[1:N+1] ≤ m0      # m
    end)

# objective
    @objective(model, Max, r[N+1])

# constraints
    @constraints(model, begin
        con_r0, r[1] == r0
        con_v0, v[1] == v0
        con_m0, m[1] == m0
        final_con, m[N+1] == mf       
    end)

    for k = 1:N
        @constraint(model, r[k+1] == r[k] + Δt*v[k])
        @constraint(model, v[k+1] == v[k] + Δt*(-Cd*v[k]^2*exp(-β*(r[k] - 1))/(m[k]) - 1/r[k]^2))
        @constraint(model, m[k+1] == m[k] - Δt*u[k])
    end

    # dynamics
    @NLexpression(model, begin

        D[i = 1:N+1], Cd * v[i]^2 * exp(-β * (r[i] - 1.0))

        dr[i = 1:N+1], v[i]
        dv[i = 1:N+1], (Tmax*u[i]-D[i])/m[i] - 1/r[i]^2
        dm[i = 1:N+1], -b*Tmax*u[i]

    end)

    # Crank-Nicolson scheme
    @NLconstraints(sys, begin
        con_dr[i = 1:N], r[i+1] == r[i] + Δt * (dr[i] + dr[i+1])/2.0
        con_dv[i = 1:N], v[i+1] == v[i] + Δt * (dv[i] + dv[i+1])/2.0
        con_dm[i = 1:N], m[i+1] == m[i] + Δt * (dm[i] + dm[i+1])/2.0
    end)

    return model
end