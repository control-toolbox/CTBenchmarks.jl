"""
    The Cart-Pendulum Problem:
        we want to find the optimal trajectory of a cart-pendulum system.
        The objective is to swing the pendulum from the downward position to the upright position in the shortest time possible.
        The problem is formulated as an OptimalControl model.
"""
function cart_pendulum_OC()
# parameters
    # Physical constants
    g = 9.82      # gravitation [m/s^2]
    L = 1.0       # pendulum length [m]
    m = 1.0       # pendulum mass [kg]
    I = m*L^2/12  # pendulum moment of inertia
    m_cart = 0.5  # cart mass [kg]
    max_f = 5.0
    max_x = 1.0
    max_v = 2.0

    @def ocp begin
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
        var ∈ R² , variable
            tf = var₁
            ddx = var₂
        t ∈ [ 0.0, tf ], time
        x ∈ R⁴, state
        u ∈ R¹, control

    ## state variables
        x1 = x₁
        dx = x₂
        theta = x₃
        omega = x₄
    ## control variables
        Fex = u
    
    ## constraints
        # state constraints
        -max_x ≤ x1(t) ≤ max_x,         (x1_con)
        -max_v ≤ dx(t) ≤ max_v,        (dx_con)
        # control constraints
        -max_f ≤ Fex(t) ≤ max_f,       (Fex_con)
        # variables constraints
        tf ≥ 0.0,                      (tf_con)
        # initial conditions
        x1(0.0) == 0.0,                    (x1_ic)
        theta(0.0) == 0.0,                  (theta_ic)
        omega(0.0) == 0.0,                  (omega_ic)
        # final conditions
        theta(tf) == pi,                 (theta_fc)
        omega(tf) == 0,                 (omega_fc)


    ## dynamics
        ẋ(t) == dynamics(x(t), u(t),ddx)
    
    ## objective
        tf → min
    end
    
# dynamics
    function dynamics(x, u,ddx)
        x1, dx, theta, omega = x
        Fex = u
        COG(theta) = L/2 * [sin(theta), -  cos(theta)] + [x1, 0]
        alpha(ddx) = 1.0/(I+0.25*m*L^2) * 0.5*L*m * (-ddx*cos(theta) - g*sin(theta))
        ddCOG =  L * omega * [-sin(theta),cos(theta)] + L/2 * [cos(theta), sin(theta)]* alpha(ddx) + [ddx, 0]
        FXFY = m*ddCOG + [0, m*g]
        eq(ddx) = -FXFY[1] + Fex - m_cart*ddx
        J = m_cart
        c = eq(ddx)-J*ddx
        ddx_ = -1.0/J*c
        alpha_ = alpha(ddx_)
        return [dx , ddx_ , omega, alpha_]
    end

    return ocp
end


function cart_pendulum_init(;nh)
    return ()
end