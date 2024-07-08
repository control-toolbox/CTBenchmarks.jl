"""
    The Cart-Pendulum Problem: 
        we want to find the optimal trajectory of a cart-pendulum system.
        The objective is to swing the pendulum from the downward position to the upright position in the shortest time possible.      
        The problem is formulated as a JuMP model.
    Ref: https://arxiv.org/pdf/2303.16746
"""
function Cart_Pendulum_JMP(;nh::Int64=100)
## parameters
    g = 9.82      # gravitation [m/s^2]
    L = 1.0       # pendulum length [m]
    m = 1.0       # pendulum mass [kg]
    I = m*L^2/12  # pendulum moment of inertia
    m_cart = 0.5  # cart mass [kg]
    max_f = 5.0
    max_x = 1.0
    max_v = 2.0

## define the problem
    model = JuMP.Model()

    @variables(model, begin
        0.0 <= tf 
        ddx

        -max_x <= x[k=0:nh] <= max_x         
        -max_v <= dx[k=0:nh] <= max_v 
        theta[k=0:nh]                                 
        omega[k=0:nh]    

        -max_f <= Fex[k=0:nh] <= max_f       
    end)

    @constraints(model, begin
        x[0] == 0.0
        theta[0] == 0.0
        omega[0] == 0.0
        theta[nh] == pi
        omega[nh] == 0.0
    end)

    @expressions(model, begin
        step,           tf / nh
        COG[i=0:nh],    L/2 * [sin(theta[i])+ x[i], - cos(theta[i])] + [x[i], 0]
        alpha[i=0:nh],  1.0/(I+0.25*m*L^2) * 0.5*L*m * (-ddx*cos(theta[i]) - g*sin(theta[i]))
        ddCOG[i=0:nh],  L * [-sin(theta[i]),cos(theta[i])]*omega[i] + L/2 * [cos(theta[i]),sin(theta[i])]*alpha[i] + [ddx, 0]
        FXFY[i=0:nh],   m*ddCOG[i] + [0, m*g]
        eq[i=0:nh],     -FXFY[i][1] + Fex[i] - m_cart*ddx
        J[i=0:nh],      m_cart
        c[i=0:nh],      eq[i] - J[i]*ddx
        ddx_[i=0:nh],   -1.0/J[i]*c[i]
        alpha_[i=0:nh], 1.0/(I+0.25*m*L^2) * 0.5*L*m * (-ddx_[i]*cos(theta[i]) - g*sin(theta[i]))
    end)

# Dynamics
    @constraints(model,begin
        d_x[k=1:nh],        x[k] == x[k-1] + 0.5 * step * (dx[k] + dx[k-1]) 
        d_dx[k=1:nh],       dx[k] == dx[k-1] + 0.5 * step * (ddx_[k] + ddx_[k-1]) 
        d_theta[k=1:nh],    theta[k] == theta[k-1] + 0.5 * step * (omega[k] + omega[k-1]) 
        d_omega[k=1:nh],    omega[k] == omega[k-1] + 0.5 * step * (alpha_[k] + alpha_[k-1]) 
    end)

    @objective(model, Min, tf)
    
    

    return model
end