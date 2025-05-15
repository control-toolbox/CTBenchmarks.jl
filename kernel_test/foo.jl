# foo.jl
# testing Julia kernel 
# todo: try some basic linear algebra (linear / bilnear)

using KernelAbstractions
const KA = KernelAbstractions
using AMDGPU
using CUDA
import CTParser: subs2
using MLStyle
import ForwardDiff: jacobian!

function dynamics_k!(dx, x, u)
    N = size(dx, 2)
    backend = KA.get_backend(dx)
    kernel = __dynamics!(backend)
    kernel(dx, x, u, ndrange = N)
    KA.synchronize(backend)
    return
end

@kernel function __dynamics!(dx, @Const(x), @Const(u))
    j = @index(Global, Linear)
    dynamics!(view(dx, :, j), view(x, :, j), view(u, :, j))
    nothing # no return allowed
end

function dynamics!(dx, x, u) # user defined / generated
    cosx12 = cos(x[1] * x[2])
    dx[1] = u[1] * cosx12
    dx[2] = x[2] + x[3] * u[2]
    dx[3] = u[1] + cosx12
    return nothing
end

function f_k!(y, x)
    N = size(x, 2)
    backend = KA.get_backend(x)
    kernel = __f!(backend)
    kernel(y, x, ndrange = N)
    KA.synchronize(backend)
    return
end

@kernel function __f!(y, @Const(x))
    j = @index(Global, Linear)
    f!(view(y, :, j), view(x, :, j))
    nothing # no return allowed
end

function f!(y, x) # user defined / generated
    cosx12 = cos(x[1] * x[2])
    y[1] = cosx12
    y[2] = x[2] + x[3]
    y[3] = x[1] + x[2] * cosx12
    return nothing
end

function df_k!(dy, y, x)
    N = size(x, 2)
    backend = KA.get_backend(x)
    kernel = __df!(backend)
    kernel(dy, y, x, ndrange = N)
    KA.synchronize(backend)
    return
end

@kernel function __df!(dy, y, @Const(x))
    j = @index(Global, Linear)
    df!(view(dy, :, :, j), view(y, :, j), view(x, :, j))
    nothing # no return allowed
end

function df!(dy, y, x)
    jacobian!(dy, f!, y, x)
    return nothing
end

macro kernelise(f, log = false)

    f.head == :function || throw("unknown syntax")
    code = @match f.args[1] begin
            :($fun($dx, $x, $u)) => begin
                    j = Symbol(:j_, gensym())  
                    body = f.args[2]
                    body = subs2(body, dx, dx, j)
                    body = subs2(body,  x,  x, j)
                    body = subs2(body,  u,  u, j)
                    quote
                        @kernel function $fun($dx, @Const($x), @Const($u))
                            $j = @index(Global, Linear)
                            $body
                        end
                    end
            end
            _ => throw("unknow syntax")
    end
    log && println("code: ", code)
    return code

end

@kernelise function foo!(dx, x, u)
    cosx12 = cos(x[1] * x[2])
    dx[1] = u[1] * cosx12
    dx[2] = x[2] + x[3] * u[2]
    dx[3] = u[1] + cosx12
    nothing
end

# Testing

n = 3
m = 2
N = Int(1e7)

# CPU kernel

println("CPU:")
x = rand(n, N)
u = rand(m, N)
dx = zeros(n, N)
dynamics_k!(dx, x, u);
@time dynamics_k!(dx, x, u)

y = zeros(n, N)
dy = zeros(n, n, N)
df_k!(dy, y, x);
@time df_k!(dy, y, x)

# CUDA kernel

println("CUDA:")
d_x = CuArray(x)
d_u = CuArray(u)
d_dx = CuArray(dx)
dynamics_k!(d_dx, d_x, d_u);
CUDA.@time dynamics_k!(d_dx, d_x, d_u)

d_y = CuArray(y)
d_dy = CuArray(dy)
df_k!(dy, y, x);
CUDA.@time df_k!(dy, y, x)

# AMD kernel

#d_x = ROCMatrix(x)
#d_u = ROCMatrix(u)
#d_dx = ROCMatrix(dx)
#dynamics_k!(d_dx, d_x, d_u);
#AMDGPU.@time dynamics_k!(d_dx, d_x, d_u)