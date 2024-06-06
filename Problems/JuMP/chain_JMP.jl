using JuMP , Ipopt

function chain_JMP()

    nh = 200
    L = 4.0
    a = 1.0
    b = 3.0
    tf = 1.0
    h = tf / nh

    model = JuMP.Model()
    
    @variables(model, begin
        u[1:(nh + 1)]
        x1[1:(nh + 1)]
        x2[1:(nh + 1)]
        x3[1:(nh + 1)]
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
