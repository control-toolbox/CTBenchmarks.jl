function glider_OC()
# parameters
    x_0 = 0.0
    y_0 = 1000.0
    y_f = 900.0
    vx_0 = 13.23
    vx_f = 13.23
    vy_0 = -1.288
    vy_f = -1.288
    u_c = 2.5
    r_0 = 100.0
    m = 100.0
    g = 9.81
    c0 = 0.034
    c1 = 0.069662
    S = 14.0
    rho = 1.13
    cL_min = 0.0
    cL_max = 1.4

    model = OptimalControl.Model(variable=true)

# dimensions
    state!(model, 4)                                  
    control!(model, 1)
    variable!(model, 1, "tf")

# time interval
    time!(model, 0.0 , Index(1)) 
    constraint!(model, :variable, Index(1), 0, Inf)

# initial and final conditions
    constraint!(model, :initial, [x_0, y_0, vx_0, vy_0])   
    constraint!(model, :final, 2:4 , [ y_f, vx_f, vy_f])

# state constraints
    constraint!(model, :state, Index(1), 0.0, Inf)
    constraint!(model, :state, Index(3), 0.0, Inf)

# control constraints
    constraint!(model, :control , cL_min, cL_max)

# dynamics
    function r(x)
        return ((x[1]/r_0) - 2.5)^2
    end
    
    function UpD(x)
        return u_c*(1 - r(x))*exp(-r(x))
    end

    function w(x)
        return x[4] - UpD(x)
    end

    function v(x)
        return sqrt(x[3]^2 + w(x)^2)
    end

    function D(x, u)
        return 0.5*(c0+c1*(u^2))*rho*S*v(x)^2
    end

    function L(x, u)
        return 0.5*u*rho*S*v(x)^2
    end


    dynamics!(model, (x, u, tf) -> [
        x[3],
        x[4],
        (1/m) * (-L(x, u)*(w(x)/v(x)) - D(x, u)*(x[3]/v(x))),
        (1/m) * (L(x, u)*(x[3]/v(x)) - D(x, u)*(w(x)/v(x))) - g
    ] )

# objective
    objective!(model, :mayer, (x0, xf, tf) -> xf[1], :max)    

    return model

end