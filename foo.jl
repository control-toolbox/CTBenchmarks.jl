using KernelAbstractions
const KA = KernelAbstractions

function jb!(dx, x, u)
  n, N = size(dx)
  backend = KA.get_backend(dx)
  kernel = jb_kernel!(backend)
  kernel(dx, x, u, n, ndrange=N)
  KA.synchronize(backend)
  return dx
end

@kernel function jb_kernel!(dx, @Const(x), @Const(u), @Const(n))
  j = @index(Global, Linear)
  val = cos(x[1,j] * x[2,j])
  dx[1,j] = u[1,j] * val
  dx[2,j] = x[2,j] + x[3,j] * u[2,j]
  dx[3,j] = u[1,j] + val
  nothing
end

n = 3
m = 2
N = 100000
x = rand(n, N)
u = rand(m, N)
dx = zeros(n, N)

@time jb!(dx, x, u)

using AMDGPU

d_x = ROCMatrix(x)
d_u = ROCMatrix(u)
d_dx = ROCMatrix(dx)

AMDGPU.@time jb!(d_dx, d_x, d_u)

using CUDA

d_x = CuMatrix(x)
d_u = CuMatrix(u)
d_dx = CuMatrix(dx)

CUDA.@time jb!(d_dx, d_x, d_u)
