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
    time!(ocp, 0, tf) 
    
# initial and final conditions
    constraint!(ocp, :initial, [a , 0.0 , 0.0])    
    constraint!(ocp, :final, Index(1) , b)    
    constraint!(ocp, :final, Index(3) , L)      

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