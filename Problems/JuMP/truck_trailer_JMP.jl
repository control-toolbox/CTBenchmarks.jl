"""
    The Truck Trailer Problem:


        The problem is formulated as a JuMP model.
"""
                #L   M   W
default_data = [0.4 0.1 0.2; #truck
                1.1 0.2 0.2; #trailer1
                0.8 0.1 0.2] #trailer2
function truck_JMP(;data::Array{Float64,2}=default_data,nh::Int64=200)
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

    model = JuMP.Model()

    @variables(model, begin 
        # Final time
        0 <= tf
        # State variables
        x2[0:nh]              
        y2[0:nh]   
        -pi/2 <= theta0[0:nh] <= pi/2,   (start=0.1)
        -pi/2 <= theta1[0:nh] <= pi/2,   (start=0.0)
        theta2[0:nh],                    (start=0.0)
        # Control variables
        -0.2 * speedf <= v0[0:nh] <= 0.2 * speedf, (start=-0.2)
        -pi/6 <= delta0[0:nh] <= pi/6
    end)

    # positions
    @expressions(model,begin
        x1[j=0:nh], x2[j] + L2*cos(theta2[j]) + M1*cos(theta1[j])
        y1[j=0:nh], y2[j] + L2*sin(theta2[j]) + M1*sin(theta1[j])
        x0[j=0:nh], x1[j] + L1*cos(theta1[j]) + M0*cos(theta0[j])
        y0[j=0:nh], y1[j] + L1*sin(theta1[j]) + M0*sin(theta0[j])
    end)
    
    # intermediate variables
    @expressions(model, begin
        beta01[j=0:nh], theta0[j] - theta1[j]
        beta12[j=0:nh], theta1[j] - theta2[j]
        step, tf/(nh-1)
    end)
    @constraints(model, begin
        beta01_con[j=0:nh], -pi/2 <= beta01[j] <= pi/2
        beta12_con[j=0:nh], -pi/2 <= beta12[j] <= pi/2
    end)

    # derivatives of the control variables
    @expressions(model, begin
        v0_dot[j=1:nh], (v0[j] - v0[j-1]) / step
        delta0_dot[j=1:nh], (delta0[j] - delta0[j-1]) / step
    end)
    @constraints(model, begin
        delta0_dot_con[j=1:nh], -pi/10 <= delta0_dot[j] <= pi/10
        v0_dot_con[j=1:nh], -1  <= v0_dot[j] <= 1
    end)

    @constraints(model, begin
        # Initial constraints
        x2[0] == x2_t0
        y2[0] == y2_t0
        theta0[0] == theta0_t0
        theta1[0] == theta1_t0
        theta2[0] == theta2_t0
        # Final constraint
        x2[nh] == x2_tf
        y2[nh] == y2_tf
        theta2[nh] == theta2_tf
        beta01[nh] == theta0_tf - theta1_tf
        beta12[nh] == theta1_tf - theta2_tf
    end)

    @expression(model,dtheta0[j=0:nh], v0[j] / L0 * tan(delta0[j]))
    @expression(model,dtheta1[j=0:nh], v0[j] / L1 * sin(beta01[j]) - M0/L1 * cos(beta01[j]) * dtheta0[j])
    @expression(model,v1[j=0:nh], v0[j] * cos(beta01[j]) + M0 * sin(beta01[j]) * dtheta0[j])
    @expression(model,dtheta2[j=0:nh], v1[j] / L2 * sin(beta12[j]) - M1/L2 * cos(beta12[j]) * dtheta1[j])
    @expression(model,v2[j=0:nh], v1[j] * cos(beta12[j]) + M1 * sin(beta12[j]) * dtheta1[j])
    @expression(model,dx2[j=0:nh], v2[j] * cos(theta2[j]))
    @expression(model,dy2[j=0:nh], v2[j] * sin(theta2[j]))
    
    # Dynamics
    @constraints(model,begin
        d_x2[j=1:nh],       x2[j] == x2[j-1] + 0.5 * step * (dx2[j] + dx2[j-1])
        d_y2[j=1:nh],       y2[j] == y2[j-1] + 0.5 * step * (dy2[j] + dy2[j-1])
        d_theta0[j=1:nh],   theta0[j] == theta0[j-1] + 0.5 * step * (dtheta0[j] + dtheta0[j-1])
        d_theta1[j=1:nh],   theta1[j] == theta1[j-1] + 0.5 * step * (dtheta1[j] + dtheta1[j-1])
        d_theta2[j=1:nh],   theta2[j] == theta2[j-1] + 0.5 * step * (dtheta2[j] + dtheta2[j-1])
    end)

    @objective(model, Min, tf + sum((beta01[j]^2+beta12[j]^2) for j in 0:nh))

    return model

    return m
end