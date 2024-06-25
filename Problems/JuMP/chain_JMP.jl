"""
    The Hanging Chain Problem:
        We want to find the shape of a chain hanging between two points a and b, with a length L.
        The objective is to minimize the potential energy of the chain.
        The problem is formulated as a JuMP model.
    Ref: https://github.com/MadNLP/COPSBenchmark.jl/blob/main/src/chain.jl
"""
function chain_JMP(;nh::Int64 = 200)
    L = 4.0
    a = 1.0
    b = 3.0
    tf = 1.0
    h = tf / nh
    tmin = b > a ? 1 / 4 : 3 / 4

    model = JuMP.Model()
    
    @variables(model, begin
        u[k=1:(nh + 1)],          (start=4 * abs(b - a) * (k / nh - tmin))
        x1[k=1:(nh + 1)],         (start=4 * abs(b - a) * k / nh * (1 / 2 * k / nh - tmin) + a)
        x2[k=1:(nh + 1)],         (start=(4 * abs(b - a) * k / nh * (1 / 2 * k / nh - tmin) + a) * (4 * abs(b - a) * (k / nh - tmin)))
        x3[k=1:(nh + 1)],         (start=4 * abs(b - a) * (k / nh - tmin))
    end)

    @constraints(model, begin
        x1[1] == a
        x1[nh+1] == b
        x2[1] == 0
        x3[1] == 0
        x3[nh+1] == L
    end)

    @objective(model, Min, x2[nh + 1])

    @constraints(model, begin
        con_x2[j = 1:nh], x2[j + 1] - x2[j] - (1 / 2) * h * (x1[j] * sqrt(1 + u[j]^2) + x1[j + 1] * sqrt(1 + u[j + 1]^2)) == 0
        con_x3[j = 1:nh], x3[j + 1] - x3[j] - (1 / 2) * h * (sqrt(1 + u[j]^2) + sqrt(1 + u[j + 1]^2)) == 0
        con_x1[j = 1:nh], x1[j + 1] - x1[j] - (1 / 2) * h * (u[j] + u[j + 1]) == 0
    end)

    return model
end
