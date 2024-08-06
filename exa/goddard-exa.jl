using OptimalControl
import ExaModels
using NLPModelsIpopt
using MadNLP
using KernelAbstractions
using BenchmarkTools

# OptimalControl model

const Cd = 310 # Drag (1/2)
const β = 500 # Drag (2/2)
const Tmax = 3.5 # Max thrust
const b = 2 # Fuel consumption

r0 = 1 # Initial altitude
v0 = 0 # Initial speed
m0 = 1 # Initial mass
vmax = 0.1 # Maximal authorized speed
mf = 0.6 # Final mass to target

@def ocp begin

    tf ∈ R, variable
    t ∈ [0, tf], time
    x = (r, v, m) ∈ R³, state
    u ∈ R, control

    tf ≥ 0
    x(0) == [r0, v0, m0]
    m(tf) == mf
    0 ≤ u(t) ≤ 1
    r(t) ≥ r0
    0 ≤ v(t) ≤ vmax

    dr = v(t)
    dv = -Cd * v(t)^2 * exp(-β * (r(t) - 1)) / m(t) - 1 / r(t)^2 + u(t) * Tmax / m(t)
    dm = -b * Tmax * u(t)
    ẋ(t) == [dr, dv, dm]

    r(tf) → max
end

# Define a common initial guess

N = 5
i_print_level = 0
m_print_level = MadNLP.WARN
sol = solve(ocp; grid_size=N, print_level=0)

N = 100
print_level = 0
n = 3
m = 1
tfs = sol.times[end]
t = tfs * (0:N) / N
xs = sol.state.(t)
xs = [ xs[j][i] for (i, j) ∈ Base.product(1:n, 1:N+1) ] 
us = sol.control.(t)
us = [ us[j][i] for (i, j) ∈ Base.product(1:m, 1:N+1) ] 

# NLP

_, nlp_m = direct_transcription(ocp; grid_size=N)

# ExaModel

function docp_exa(N=100; backend=nothing, tfs=0.1, xs=0.1, us=0.1)

    c = ExaModels.ExaCore(; backend=backend)

    tf = ExaModels.variable(c, 1; start=tfs)
    x = ExaModels.variable(c, n, 1:N+1; start=xs)
    u = ExaModels.variable(c, m, 1:N+1; start=us)

    dt = tf[1] / N
    ExaModels.constraint(c, tf[1]; lcon=0, ucon=Inf)
    __it1 = [(i, [r0, v0, m0][i]) for i ∈ 1:n] 
    ExaModels.constraint(c, x[i, 1] - __v for (i, __v) ∈ __it1)
    ExaModels.constraint(c, x[3, N+1] - mf)
    ExaModels.constraint(c, u[1, j] for j ∈ 1:N+1; lcon=0, ucon=1)
    ExaModels.constraint(c, x[1, j] for j ∈ 1:N+1; lcon=r0, ucon=Inf)
    ExaModels.constraint(c, x[2, j] for j ∈ 1:N+1; lcon=0, ucon=vmax)
    
    dr(r, v, m, u) = v
    dv(r, v, m, u) = -Cd * v^2 * exp(-β * (r - 1)) / m - 1 / r^2 + u * Tmax / m
    dm(r, v, m, u) = -b * Tmax * u
    rk2(x1, x2, rhs1, rhs2, dt) = x2 - x1 - dt / 2 * (rhs1 + rhs2)

    ExaModels.constraint(c, rk2(x[1, j], x[1, j+1], dr(x[1, j], x[2, j], x[3, j], u[1, j]), dr(x[1, j+1], x[2, j+1], x[3, j+1], u[1, j+1]), dt) for j ∈ 1:N) # To be optimised using additional vars
    ExaModels.constraint(c, rk2(x[2, j], x[2, j+1], dv(x[1, j], x[2, j], x[3, j], u[1, j]), dv(x[1, j+1], x[2, j+1], x[3, j+1], u[1, j+1]), dt) for j ∈ 1:N)
    ExaModels.constraint(c, rk2(x[3, j], x[3, j+1], dm(x[1, j], x[2, j], x[3, j], u[1, j]), dm(x[1, j+1], x[2, j+1], x[3, j+1], u[1, j+1]), dt) for j ∈ 1:N)

    ExaModels.objective(c, -x[1, N+1])

    return ExaModels.ExaModel(c)

end

#exa_m = docp_exa(N; tfs=tfs, xs=xs, us=us, backend=CPU()) 
exa_m = docp_exa(N; tfs=tfs, xs=xs, us=us) 

# Solve

print("NLP + Ipopt :")
nlp_i_output = @btime ipopt(nlp_m; print_level=i_print_level)
print("NLP + MadNLP:")
nlp_m_output = @btime madnlp(nlp_m; print_level=m_print_level)
print("Exa + Ipopt :")
exa_i_output = @btime ipopt(exa_m; print_level=i_print_level)
print("Exa + MadNLP:")
exa_m_output = @btime madnlp(exa_m; print_level=m_print_level)

println()
println("NLP + Ipopt : ", nlp_i_output)
println("NLP + MadNLP: ", nlp_m_output)
println("Exa + Ipopt : ", exa_i_output)
println("Exa + MadNLP: ", exa_m_output)