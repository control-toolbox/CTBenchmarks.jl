using OptimalControl

function robot_OC()
    # should return an OptimalControlProblem with a message, a model and a solution

    # ------------------------------------------------------------------------------------------
# parameters
    nh = 200
    L = 5.0
    max_u_rho = 1.0
    max_u_the = 1.0
    max_u_phi = 1.0
    max_u = [max_u_rho, max_u_the, max_u_phi]
    rho0 = 4.5
    phi0 = pi /4
    thef = 2.0 * pi / 3

    model = OptimalControl.Model(variable=true)

# dimensions
    state!(model, 6)                                  
    control!(model, 3)
    variable!(model, 1, "tf")

# time interval
    time!(model, 0, Index(1)) 
    constraint!(model, :variable, Index(1), 0.0, Inf)

# initial and final conditions
    constraint!(model, :initial, [rho0, 0.0 ,0.0, 0.0 , phi0, 0.0])       
    constraint!(model, :final,   [rho0, 0.0 , thef, 0.0 , phi0, 0.0])  

# state constraints
    
# control constraints
    constraint!(model, :control ,-max_u, max_u)

# dynamics
    dynamics!(model, (x, u, tf) -> [ x[2],
        x[4],
        x[6],
        (u[1] - (L-x[1]) * sin(x[5]) * x[6]^2) / ((L-x[1])^3 + x[1]^3) * sin(x[5]),
        (u[2] - x[3] * x[6]^2 * sin(x[5]) * cos(x[5])) / ((L-x[1])^3 + x[1]^3),
        (u[3] - x[3] * x[6]^2 * cos(x[5])) / ((L-x[1])^3 + x[1]^3) ] )

    
# objective
    objective!(model, :mayer, (x0, xf, tf) -> tf, :min)    

    return model

end