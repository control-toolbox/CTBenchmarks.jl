function chain_OC()
    # should return an OptimalControlProblem with a message, a model and a solution

    # ------------------------------------------------------------------------------------------
# parameters
    L = 4
    a = 1
    b = 3
    tf = 1.0
    ocp = OptimalControl.Model()
    
# dimensions
    state!(ocp, 3)                                  
    control!(ocp, 1) 
    
# time interval
    time!(ocp, 0, tf) 
    
# initial and final conditions
    constraint!(ocp, :initial, [a , 0.0 , 0.0])       
    constraint!(ocp, :final, Index(3) , L)    
    constraint!(ocp, :final, Index(1) , b)     

# state constraints

# control constraints

# dynamics
    dynamics!(ocp, (x, u) -> [ 
        u , 
        x[1] * sqrt(1+u^2),
        sqrt(1+u^2)
    ] ) 

# objective     
    objective!(ocp, :mayer, (x0, xf) -> xf[2], :min)    

    return ocp

end