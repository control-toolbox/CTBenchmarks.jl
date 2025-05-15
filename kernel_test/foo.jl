# foo.jl
# testing Julia kernel 
# todo: try some basic linear algebra (linear / bilnear)

using KernelAbstractions
const KA = KernelAbstractions
using AMDGPU
using CUDA
import CTParser: subs2
using MLStyle

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
N = Int(1e6)

# CPU kernel

x = rand(n, N)
u = rand(m, N)
dx = zeros(n, N)
dynamics_k!(dx, x, u);
@time dynamics_k!(dx, x, u)

# CUDA kernel

d_x = CuMatrix(x)
d_u = CuMatrix(u)
d_dx = CuMatrix(dx)
dynamics_k!(d_dx, d_x, d_u);
CUDA.@time dynamics_k!(d_dx, d_x, d_u)

# AMD kernel

#d_x = ROCMatrix(x)
#d_u = ROCMatrix(u)
#d_dx = ROCMatrix(dx)
#dynamics_k!(d_dx, d_x, d_u);
#AMDGPU.@time dynamics_k!(d_dx, d_x, d_u)