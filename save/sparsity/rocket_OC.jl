 """
    Goddard Rocket Problem:
        We want to find the optimal trajectory of a Goddard rocket.
        The objective is to maximize the final altitude of the rocket.
        The problem is formulated as an OptimalControl model.
"""
function rocket_OC()
# parameters
    h_0 = 1.0
    v_0 = 0.0
    m_0 = 1.0
    g_0 = 1.0
    T_c = 3.5
    h_c = 500.0
    v_c = 620.0
    m_c = 0.6

    c = 0.5*sqrt(g_0 * h_0)
    m_f = m_c * m_0
    D_c = 0.5 * v_c * (m_0 / g_0)
    T_max = T_c * m_0 * g_0

    ocp = OptimalControl.Model(variable=true)
    
# dimensions
    state!(ocp, 3)                                  
    control!(ocp, 1) 
    variable!(ocp, 1, "tf")
    
# time interval
    time!(ocp, t0=0, indf=1) 
    constraint!(ocp, :variable, lb=0.0, ub=Inf)
    
# initial and final conditions
    constraint!(ocp, :initial, lb=[h_0, v_0 ,m_0],ub=[h_0, v_0 ,m_0]) 
    constraint!(ocp, :final, rg =3 , lb=m_f,ub=m_f)     

# state constraints
    constraint!(ocp, :state , rg=1:3, lb=[h_0, v_0 ,m_f] , ub=[Inf, Inf, m_0]) 

# control constraints
    constraint!(ocp, :control , lb=0, ub=T_max)

# dynamics
    dynamics!(ocp, (x, u, tf) -> [ x[2],
        (u - (D_c*x[2]^2*exp(-h_c*(x[1] - h_0))/h_0) - x[3]*g_0*(h_0 / x[1])^2) / x[3],
        -u/c] ) 

# objective     
    objective!(ocp, :mayer, (x0, xf, tf) -> xf[1], :max)    

    return ocp

end


function rocket_init(;nh)
    m_0 = 1.0
    g_0 = 1.0
    T_c = 3.5
    m_c = 0.6
    m_f = m_c * m_0
    T_max = T_c * m_0 * g_0

    xinit = [[1.0,
                k/nh*(1.0 - k/nh) ,
              (m_f - m_0) * k + m_0] for k=0:nh]

    init = (time= 0:nh, state = xinit , control = T_max/2.0 ,variable= 1);
    return init
end