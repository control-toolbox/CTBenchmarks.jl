"""
    Particle Steering Problem:
        We want to find the optimal trajectory of a particle.
        The objective is to minimize the time taken to achieve a given altitude and terminal velocity.
        The problem is formulated as an OptimalControl model.
"""
function steering_OC()
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
    time!(ocp, t0=0, indf=1) 
    constraint!(ocp, :variable, rg=1, lb=0.0, ub=Inf)
    
# initial and final conditions
    constraint!(ocp, :initial, lb=xs, ub=xs)       
    constraint!(ocp, :final, lb=xf, ub=xf)       

# control constraints
    constraint!(ocp, :control, lb=u_min, ub=u_max)
    
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