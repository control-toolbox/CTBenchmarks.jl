# foo.jl
# testing Julia kernel 

using KernelAbstractions
const KA = KernelAbstractions
using AMDGPU
using CUDA

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
  cosx12 = cos(x[1,j] * x[2,j])
  dx[1,j] = u[1,j] * cosx12
  dx[2,j] = x[2,j] + x[3,j] * u[2,j]
  dx[3,j] = u[1,j] + cosx12
  nothing # no return allowed
end

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

