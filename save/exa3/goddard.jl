# goddard.jl

using OptimalControl
using MadNLP
import MadNCL: MadNCL, madncl
using MadNLPGPU
using CUDA
using BenchmarkTools
using Interpolations

const r0 = 1.0
const v0 = 0.0
const m0 = 1.0
const vmax = 0.1
const mf = 0.6
const Cd = 310.0
const Tmax = 3.5
const β = 500.0
const b = 2.0

parsing_backend!(:exa)

o = @def begin
    tf ∈ R, variable
    t ∈ [0, tf], time
    x = (r, v, m) ∈ R³, state
    u ∈ R, control

    x(0) == [r0, v0, m0]
    m(tf) == mf
    0 ≤ u(t) ≤ 1
    r(t) ≥ r0
    0 ≤ v(t) ≤ vmax

    ∂(r)(t) == v(t)
    ∂(v)(t) == -Cd * v(t)^2 * exp(-β * (r(t) - 1)) / m(t) - 1 / r(t)^2 + u(t) * Tmax / m(t)
    ∂(m)(t) == -b * Tmax * u(t)

    r(tf) → max
end

tfs = 0.18761155665063417
xs0 = [
    1.0 1.00105 1.00398 1.00751 1.01009 1.01124
    -1.83989e-40 0.056163 0.1 0.0880311 0.0492518 0.0123601
    1.0 0.811509 0.650867 0.6 0.6 0.6
]
us0 = [0.599377 0.835887 0.387328 -5.87733e-9 -9.03538e-9 -8.62101e-9]
N0 = length(us0) - 1
_t = (tfs * 0):N0
_xs = linear_interpolation(_t, [xs0[:, j] for j in 1:(N0 + 1)]; extrapolation_bc=Line())
_us = linear_interpolation(_t, [us0[:, j] for j in 1:(N0 + 1)]; extrapolation_bc=Line())

tol = 1e-7
print_level = MadNLP.WARN
ncl_options = MadNCL.NCLOptions(; verbose=false)
mads = :madnlp
#mads = :madncl

function solver(m, s)
    sol = begin
        if s == :madnlp
            madnlp(m; print_level=print_level, tol=tol)
        elseif s == :madncl
            madncl(m; print_level=print_level, ncl_options=ncl_options, tol=tol)
        else
            throw("unknown solver")
        end
    end
    return sol
end

for N in (100, 500, 1000, 2000, 5000, 7500, 10000, 20000, 50000)
    t = (tfs * 0):N
    xs = _xs.(t);
    xs = stack(xs[:])
    us = _us.(t);
    us = stack(us[:])
    m_cpu = o(; grid_size=N, init=(tfs, xs, us))
    m_gpu = o(; grid_size=N, init=(tfs, xs, us), backend=CUDABackend())
    printstyled("\nsolver = ", mads, ", N = ", N, "\n"; bold=true)
    print("CPU:")
    try
        sol = @btime $solver($m_cpu, mads)
        println("      converged: ", sol.status == MadNLP.Status(1), ", iter: ", sol.iter)
    catch ex
        println("\n      error: ", ex)
    end
    CUDA.functional() || throw("CUDA not available")
    print("GPU:")
    try
        solver(m_gpu, mads);
        sol = CUDA.@time solver(m_gpu, mads)
        println("      converged: ", sol.status == MadNLP.Status(1), ", iter: ", sol.iter)
    catch ex
        println("\n      error: ", ex)
    end
end
