"""
    The Hanging Chain Problem:
        We want to find the shape of a chain hanging between two points a and b, with a length L.
        The objective is to minimize the potential energy of the chain.
        The problem is formulated as an OptimalControl model.
"""


function chain_OC()
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
    time!(ocp, t0 = 0, tf = tf) 
    
# initial and final conditions
    constraint!(ocp, :initial, lb=[a , 0.0 , 0.0],ub=[a , 0.0 , 0.0])    
    constraint!(ocp, :final, rg=1 , lb=b, ub=b)    
    constraint!(ocp, :final, rg=3 , lb=L, ub=L)      

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