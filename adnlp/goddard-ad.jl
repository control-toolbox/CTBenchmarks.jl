# Solve Goddard problem using ADNLPModels.jl

using OptimalControl
using ADNLPModels
using NLPModelsIpopt
using LinearAlgebra
using JET

# Parameters

const n = 3 # State dim
const m = 1 # Control dim
const Cd = 310. # Drag (1/2)
const β = 500. # Drag (2/2)
const Tmax = 3.5 # Max thrust
const b = 2. # Fuel consumption

const r0 = 1. # Initial altitude
const v0 = 0. # Initial speed
const m0 = 1. # Initial const mass
const vmax = 0.1 # Maximal authorized speed
const mf = 0.6 # Final mass to target

# ADNLPModel
# z = [tf, x[:], u[:]], tf : 1, x : n x (N + 1), u : m x (N + 1)

@inline function _get(z, i, j, d; offset=0)
    k = offset + i + (j - 1) * d # j is assumed to start from 1 
    return z[k]
end

@inline function _get(z, j, d; offset=0)
    k = offset + 1 + (j - 1) * d
    return @view z[k:k + d - 1]
end

macro tf() esc( :( z[1] ) ) end # assumes z, n, m, N are used
macro x(i, j) esc( :( _get(z, $i, $j, n; offset=1) ) ) end
macro x(j) esc( :( _get(z, $j, n; offset=1) ) ) end
macro u(i, j) esc( :( _get(z, $i, $j, m; offset=1 + (N + 1) * n) ) ) end
macro u(j) esc( :( _get(z, $j, m; offset=1 + (N + 1) * n) ) ) end
macro con(l, v, u)
    code = quote # assumes c, lcon, ucon, dim are used
        dim = length($l) # not local to avoid reallocating
        if set_bounds
            append!(lcon, $l)
            append!(ucon, $u)
        else
            c[k:k + dim - 1] .= $v
            k = k + dim
        end
    end
    return esc(code)
end

## objective: -r[N + 1]

f(z, N) = -@x(1, N + 1)

## constraints

dr(r, v, m, u) = v
dv(r, v, m, u) = -Cd * v^2 * exp(-β * (r - 1)) / m - 1 / r^2 + u * Tmax / m
dm(r, v, m, u) = -b * Tmax * u
rk2(x1, x2, rhs1, rhs2, dt) = x2 - x1 - dt / 2 * (rhs1 + rhs2)

#function build(c, z, N :: Int; set_bounds=false)
function build(c, z, N; set_bounds=false)
    k = 1
    lcon = Float64[]
    ucon = Float64[]
    dt = (@tf) / N

    # 0 ≤ tf
    @con 0 (@tf) Inf

    # x[:, 1] - [r0, v0, m0] == 0
    @con [0, 0, 0] @x(1) - [r0, v0, m0] [0, 0, 0] 

    # x[3, N + 1] == mf
    @con 0 @x(3, N + 1) - mf 0

    # 0 ≤ u[1, :] ≤ 1 
    for j ∈ 1:N + 1
        @con 0 @u(1, j) 1
    end

    # r0 ≤ x[1, :]
    for j ∈ 1:N + 1
        @con r0 @x(1, j) Inf
    end

    # 0 ≤ x[2, :] ≤ vmax
    for j ∈ 1:N + 1
        @con 0 @x(2, j) vmax
    end

    # rk2 on r
    dj = dr(@x(1, 1), @x(2, 1), @x(3, 1), @u(1, 1)) 
    for j ∈ 1:N
        dj1 = dr(@x(1, j + 1), @x(2, j + 1), @x(3, j + 1), @u(1, j + 1)) 
        @con 0 rk2(@x(1, j), @x(1, j + 1), dj, dj1, dt) 0
        dj = dj1
    end

    # rk2 on v
    dj = dv(@x(1, 1), @x(2, 1), @x(3, 1), @u(1, 1)) 
    for j ∈ 1:N
        dj1 = dv(@x(1, j + 1), @x(2, j + 1), @x(3, j + 1), @u(1, j + 1)) 
        @con 0 rk2(@x(2, j), @x(2, j + 1), dj, dj1, dt) 0
        dj = dj1
    end

    # rk2 on m
    dj = dm(@x(1, 1), @x(2, 1), @x(3, 1), @u(1, 1)) 
    for j ∈ 1:N
        dj1 = dm(@x(1, j + 1), @x(2, j + 1), @x(3, j + 1), @u(1, j + 1)) 
        @con 0 rk2(@x(3, j), @x(3, j + 1), dj, dj1, dt) 0
        dj = dj1
    end

    return lcon, ucon

end

N = 100
z_dim = 1 + n * (N + 1) + m * (N + 1)
z = ones(z_dim)

f(z) = f(z, N)
lcon, ucon = build([], z, N; set_bounds=true); c_dim = length(lcon)
con!(c, z) = (build(c, z, N :: Int); nothing) # usefull to add nothing?
@assert(length(lcon) == length(lcon) == 1 + n + 1 + 3(N + 1) + n * N)

c = -1.1ones(c_dim)
#@code_warntype con!(c, z)
#@report_opt con!(c, z)

error("debug")

# check

ocp = @def begin

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

    dr = dr(r(t), v(t), m(t), u(t))
    dv = dv(r(t), v(t), m(t), u(t))
    dm = dm(r(t), v(t), m(t), u(t))
    ẋ(t) == [dr, dv, dm]

    r(tf) → max

end

sol = solve(ocp; grid_size=N)

(@tf) = time_grid(sol)[end]
x = state(sol)
u = control(sol)
t = range(0, @(tf); length=N + 1)

for j ∈ 1:N + 1
    @x(j) .= x(t[j])
    @u(j) .= u(t[j])
end

con!(c, z)
println("lcon    : ", lcon ≤ c)
println("ucon    : ", c ≤ ucon)
println("dynamics: ", norm(@view c[end - 3N + 1:end]))

#lvar = -Inf * ones(z_dim)
#uvar =  Inf * ones(z_dim)
#nlp = ADNLPModel!(f, z, lvar, uvar, con!, lcon, ucon)
#sol2 = ipopt(nlp)