"""
    The Truck Trailer Problem:
        We want to find the optimal trajectory of a truck with two trailers that starts horizontally aligned.
        The objective is to minimize the time taken to park the truck and the trailers aligned vertically at a given target location.
        The problem is formulated as an OptimalControl model.
"""
               #L   M   W
default_data = [0.4 0.1 0.2; #truck
                1.1 0.2 0.2; #trailer1
                0.8 0.1 0.2] #trailer2
function truck_OC(;data::Array{Float64,2}=default_data)
# parameters
    if size(data) != (3, 3)
        error("The input matrix must be 3x3.")
    end
    L0 = data[1, 1]
    M0 = data[1, 2]
    W0 = data[1, 3]
    L1 = data[2, 1]
    M1 = data[2, 2]
    W1 = data[2, 3]
    L2 = data[3, 1]
    M2 = data[3, 2]
    W2 = data[3, 3]
    speedf = 1
    x2_t0 = 0.0
    y2_t0 = 0.0
    theta2_t0 = 0.0
    theta1_t0 = 0.0
    theta0_t0 = 0.0
    x2_tf = 0.0
    y2_tf = -2.0
    theta2_tf = 2*pi/4
    theta1_tf = 2*pi/4
    theta0_tf = 2*pi/4

    @def ocp begin
    # parameters
        L0 = data[1, 1]
        M0 = data[1, 2]
        W0 = data[1, 3]
        L1 = data[2, 1]
        M1 = data[2, 2]
        W1 = data[2, 3]
        L2 = data[3, 1]
        M2 = data[3, 2]
        W2 = data[3, 3]
        speedf = 1
        x2_t0 = 0.0
        y2_t0 = 0.0
        theta2_t0 = 0.0
        theta1_t0 = 0.0
        theta0_t0 = 0.0
        x2_tf = 0.0
        y2_tf = -2.0
        theta2_tf = 2*pi/4
        theta1_tf = 2*pi/4
        theta0_tf = 2*pi/4

    ## define the problem
        tf ∈ R, variable
        t ∈ [0.0, tf], time
        x ∈ R⁷, state
        u ∈ R², control

    ## state variables
        x2 = x₁
        y2 = x₂
        theta0 = x₃
        theta1 = x₄
        theta2 = x₅
        v0 = x₆
        delta0 = x₇
    ## control variables
        d_v0 = u₁
        d_delta0 = u₂
    ## auxiliary variables
        beta01 = theta0 - theta1
        beta12 = theta1 - theta2
        x1     = x2 + L2*cos(theta2) + M1*cos(theta1)
        y1     = x2 + L2*cos(theta2) + M1*cos(theta1)
        x0     = x1 + L1*cos(theta1) + M0*cos(theta0)
        y0     = y1 + L1*sin(theta1) + M0*sin(theta0)

    ## constraints
        # state constraints
        -pi/2 ≤ theta0(t) ≤ pi/2,                  (theta0_con)
        -pi/2 ≤ theta1(t) ≤ pi/2,                  (theta1_con)
        # control constraints
        -0.2 * speedf ≤ v0(t) ≤ 0.2 * speedf,                       (v0_con)
        -pi/6 ≤ delta0(t) ≤ pi/6,                                   (delta0_con)
        -1 ≤ d_v0(t) ≤ 1,                   (v0_dot_con)
        -pi/10 ≤ d_delta0(t) ≤ pi/10,       (delta0_dot_con)
        -pi/2 ≤ beta01(t) ≤ pi/2,                     (beta01_con)
        -pi/2 ≤ beta12(t) ≤ pi/2,                     (beta12_con)
        # initial conditions
        x2(0) == x2_t0,                       (x2_t0_con)
        y2(0) == y2_t0,                       (y2_t0_con)
        theta0(0) == theta0_t0,               (theta0_t0_con)
        theta1(0) == theta1_t0,               (theta1_t0_con)
        theta2(0) == theta2_t0,               (theta2_t0_con)
        # final conditions
        x2(tf) == x2_tf,                       (x2_tf_con)
        y2(tf) == y2_tf,                       (y2_tf_con)
        theta2(tf) == theta2_tf,               (theta2_tf_con)
        beta01(tf) == theta0_tf - theta1_tf,    (beta01_tf_con)
        beta12(tf) == theta1_tf - theta2_tf,    (beta12_tf_con)

    ## dynamics
        ẋ(t) == dynamics(x(t), u(t))

    ## objective
        tf + ∫((beta01(t)^2)+(beta12(t)^2)) → min
    end

    function dynamics(x, u)
        x2, y2, theta0, theta1, theta2, v0, delta0 = x
       d_v0, d_delta0 = u

        beta01 = theta0 - theta1
        beta12 = theta1 - theta2

        dtheta0 = v0/L0*tan(delta0)
        dtheta1 = v0/L1*sin(beta01) - M0/L1*cos(beta01)*dtheta0
        v1 = v0*cos(beta01) + M0*sin(beta01)*dtheta0

        dtheta2 = v1/L2*sin(beta12) - M1/L2*cos(beta12)*dtheta1
        v2 = v1*cos(beta12) + M1*sin(beta12)*dtheta1

        dx2 = v2*cos(theta2)
        dy2 = v2*sin(theta2)
        
        return [ dx2, dy2, dtheta0, dtheta1, dtheta2,d_v0, d_delta0 ]
    end

    return ocp

end


function truck_init(;nh)
    init = (state=[0, 0, 0.1, 0.0, 0.0, -0.2, 0],)
    return init
end