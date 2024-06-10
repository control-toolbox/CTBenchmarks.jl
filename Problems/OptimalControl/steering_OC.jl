function steering_OC()
    # should return an OptimalControlProblem with a message, a model and a solution

    # ------------------------------------------------------------------------------------------
# parameters
    a = 100.0 
    u_min, u_max = -pi/2.0, pi/2.0
    xs = zeros(4)
    xf = [NaN, 5.0, 45.0, 0.0]

    ocp = OptimalControl.Model(variable=true)
    
# dimensions
    state!(ocp, 4)                                  
    control!(ocp, 1) 
    variable!(ocp, 1, "tf")
    
# time interval
    time!(ocp, 0, Index(1)) 
    constraint!(ocp, :variable, Index(1), 0.0, Inf)
    
# initial and final conditions
    constraint!(ocp, :initial, xs)       
    constraint!(ocp, :final, xf)        

# state constraints

# control constraints
    constraint!(ocp, :control, u_min, u_max)
# dynamics
    dynamics!(ocp, (x, u, tf) -> [ 
        x[3] , 
        x[4],
        a * cos(u),
        a * sin(u)
    ] ) 

# objective     
    objective!(ocp, :mayer, (x0, xf, tf) -> tf, :min) 

    return ocp

end