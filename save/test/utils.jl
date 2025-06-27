using Interpolations

function costateInterpolation(p, t)
    nx = size(p[1])[1]
    n_h = length(t)[1]
    res = [zeros(Float64, nx) for _ in 1:n_h]
    for j in 1:nx
        pj = Interpolations.LinearInterpolation(t[1:end-1], [p[i][j] for i in 1:n_h-1 ], extrapolation_bc=Interpolations.Line())
        f = t -> pj(t)
        for i in 1:n_h
            res[i][j] = f(t[i])
        end
    end
    return res
end

function prettytime(t)
    if t < 1e3
        value, units = t, "ns"
    elseif t < 1e6
        value, units = t / 1e3, "μs"
    elseif t < 1e9
        value, units = t / 1e6, "ms"
    else
        value, units = t / 1e9, "s"
    end
    return string(value , " " , units)
end