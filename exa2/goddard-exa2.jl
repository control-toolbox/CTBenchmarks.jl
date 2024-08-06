using ExaModels
using NLPModelsIpopt
using MadNLP
using MadNLPGPU
using CUDA
using KernelAbstractions
using BenchmarkTools

# ExaModel

const Cd = 310 # Drag (1/2)
const β = 500 # Drag (2/2)
const Tmax = 3.5 # Max thrust
const b = 2 # Fuel consumption

r0 = 1 # Initial altitude
v0 = 0 # Initial speed
m0 = 1 # Initial mass
vmax = 0.1 # Maximal authorized speed
mf = 0.6 # Final mass to target

# save (N = 5)
# julia> tfs
# 0.18761155665063417
# 
# julia> xs
# 3×6 Matrix{Float64}:
#   1.0          1.00105   1.00398   1.00751    1.01009    1.01124
#  -1.83989e-40  0.056163  0.1       0.0880311  0.0492518  0.0123601
#   1.0          0.811509  0.650867  0.6        0.6        0.6
# 
# julia> us
# 1×6 Matrix{Float64}:
#  0.599377  0.835887  0.387328  -5.87733e-9  -9.03538e-9  -8.62101e-9
 
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

exa0 = docp_exa(N; tfs=tfs, xs=xs, us=us) 
exa1 = docp_exa(N; tfs=tfs, xs=xs, us=us, backend=CPU()) 
exa2 = docp_exa(N; tfs=tfs, xs=xs, us=us, backend=CUDABackend()) 

# Solve

print("exa0:")
output0 = @btime madnlp(exa0; print_level=m_print_level)
print("exa1:")
output1 = @btime madnlp(exa1; print_level=m_print_level)
print("exa2:")
output2 = @btime madnlp(exa2; print_level=m_print_level)

println()
print("exa0: ", output0)
print("exa1: ", output1)
print("exa2: ", output2)