# quadrotor.jl

n = 10 
m = 4
const T = 60
const x0 = zeros(n)
const g = 9.8

ocp = @def begin 

    t ∈ [0, T], time
    x ∈ R^n, state
    u ∈ R^m, control

    x(0) == x0

    ∂(x₁)(t) == x₂(t)
    ∂(x₂)(t) == u₁(t) * cos(x₇(t)) * sin(x₈(t)) * cos(x₉(t)) + u₁(t) * sin(x₇(t)) * sin(x₉(t))
    ∂(x₃)(t) == x₄(t)
    ∂(x₄)(t) == u₁(t) * cos(x₇(t)) * sin(x₈(t)) * sin(x₉(t)) - u₁(t) * sin(x₇(t)) * cos(x₉(t))
    ∂(x₅)(t) == x₆(t)
    ∂(x₆)(t) == u₁(t) * cos(x₇(t)) * cos(x₈(t)) - g 
    ∂(x₇)(t) == u₂(t) * cos(x₇(t)) / cos(x₈(t)) + u₃(t) * sin(x₇(t)) / cos(x₈(t))
    ∂(x₈)(t) ==-u₂(t) * sin(x₇(t)) + u₃(t) * cos(x₇(t))
    ∂(x₉)(t) == u₂(t) * cos(x₇(t)) * tan(x₈(t)) + u₃(t) * sin(x₇(t)) * tan(x₈(t)) + u₄(t)

    dt1 = sin(2π * t / T)
    df1 = 0 
    dt3 = 2sin(4π * t / T)
    df3 = 0 
    dt5 = 2(t / T)
    df5 = 2

    ∂(x10)(t) == (x₁(t) - dt1)^2 + (x₃(t) - dt3)^2 + (x₅(t) - dt5)^2 + x₇(t)^2 + x₈(t)^2 + x₉(t)^2 + u₁(t)^2 + u₂(t)^2 + u₃(t)^2 + u₄(t)^2
    (x₁(T) - df1)^2 + (x₃(T) - df3)^2 + (x₅(T) - df5)^2 + x₇(T)^2 + x₈(T)^2 + x₉(T)^2 + x10(T) → min

end

N = 100
m = ocp(; grid_size = N)
sol = madnlp(m)

if false # debug
init = (state = zeros(n), control = zeros(m))

tol = 1e-7
print_level = MadNLP.WARN
ncl_options = MadNCL.NCLOptions(verbose = false)
mads = :madnlp
#mads = :madncl

function solver(m, s)
    sol = begin
        if s == :madnlp
            madnlp(m; print_level = print_level, tol = tol)
        elseif s == :madncl
            madncl(m; print_level = print_level, ncl_options = ncl_options, tol = tol)
        else
            throw("unknown solver")
        end
    end
    return sol
end

for N ∈ (100,) # 500, 1000, 2000, 5000, 7500, 10000, 20000, 50000)

    t = tfs * 0:N
    xs = _xs.(t); xs = stack(xs[:])
    us = _us.(t); us = stack(us[:])
    m_cpu = o(; grid_size = N, init = init)
    m_gpu = o(; grid_size = N, init = init), backend = CUDABackend())
    printstyled("\nsolver = ", mads, ", N = ", N, "\n"; bold = true)
    print("CPU:")
    try sol = @btime $solver($m_cpu, mads)
        println("      converged: ", sol.status == MadNLP.Status(1), ", iter: ", sol.iter)
    catch ex
        println("\n      error: ", ex)
    end
    CUDA.functional() || throw("CUDA not available")
    print("GPU:")
    try solver(m_gpu, mads);
        sol = CUDA.@time solver(m_gpu, mads)
        println("      converged: ", sol.status == MadNLP.Status(1), ", iter: ", sol.iter)
    catch ex
        println("\n      error: ", ex)
    end

end

end # debug