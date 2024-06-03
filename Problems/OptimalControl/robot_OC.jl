EXAMPLE=(:robot, :classical, :time, :x_dim_3, :u_dim_3, ...)


@eval function OCPDef{EXAMPLE}()


    title = "Robot problem - minimize time"
    # ------------------------------------------------------------------------------------------
    # parameters 

    # total length of arm
    L = 5.0
    # Upper bounds on the controls
    max_u_rho = 1.0
    max_u_the = 1.0
    max_u_phi = 1.0
    # Initial positions of the length and the angles for the robot arm
    rho0 = 4.5
    phi0 = pi /4

    # the model    
    @def ocp begin
        L = 5.0
        max_u_rho = 1.0
        max_u_the = 1.0
        max_u_phi = 1.0
        rho0 = 4.5
        phi0 = pi /4

        # variables
        tf ∈ R, variable
        t ∈ [ t0, tf ], time
        x ∈ R³, state
        u ∈ R, control
        r = x₁
        v = x₂
        m = x₃
    end

end

