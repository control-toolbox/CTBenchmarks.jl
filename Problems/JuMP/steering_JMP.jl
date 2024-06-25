"""
    Particle Steering Problem:
        We want to find the optimal trajectory of a particle.
        The objective is to minimize the time taken to achieve a given altitude and terminal velocity.
        The problem is formulated as a JuMP model.
    Ref: https://github.com/MadNLP/COPSBenchmark.jl/blob/main/src/steering.jl
"""
function steering_JMP(;nh::Int64 = 100)
    a = 100.0 
    u_min, u_max = -pi/2.0, pi/2.0
    xs = zeros(4)
    xf = [NaN, 5.0, 45.0, 0.0]

    function gen_x0(k, i)
        if i == 1 || i == 4
            return 0.0
        elseif i == 2
            return 5*k/nh
        elseif i == 3
            return 45.0*k/nh
        end
    end

    model = JuMP.Model()

    @variable(model, u_min <= u[i=1:nh+1] <= u_max, start=0.0)   # control
    @variable(model, x[i=1:nh+1, j=1:4], start=gen_x0(i, j))     # state
    @variable(model, tf, start=1.0)                              # final time

    @expression(model, h, tf / nh) # step size
    @objective(model, Min, tf)

    @constraint(model, tf >= 0.0)
    # Dynamics
    @constraints(
        model, begin
            con_x1[i=1:nh], x[i+1,1] == x[i,1] + 0.5*h*(x[i,3] + x[i+1,3])
            con_x2[i=1:nh], x[i+1,2] == x[i,2] + 0.5*h*(x[i,4] + x[i+1,4])
            con_x3[i=1:nh], x[i+1,3] == x[i,3] + 0.5*h*(a*cos(u[i]) + a*cos(u[i+1]))
            con_x4[i=1:nh], x[i+1,4] == x[i,4] + 0.5*h*(a*sin(u[i]) + a*sin(u[i+1]))
        end
    )
    # Boundary conditions
    @constraint(model , [j=1:4], x[1, j] == xs[j])
    @constraint(model , [j=2:4], x[nh+1, j] == xf[j])

    return model
end

