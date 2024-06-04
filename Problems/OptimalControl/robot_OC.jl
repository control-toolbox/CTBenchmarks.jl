EXAMPLE=(:robot, :classical, :time, :x_dim_3, :u_dim_3, ...)


@eval function OCPDef{EXAMPLE}()


    title = "Robot problem - minimize time"
    # ------------------------------------------------------------------------------------------
    # parameters 
    N = 100
    Tmax = 1.0

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
        N = 100
        max_u_rho = 1.0
        max_u_the = 1.0
        max_u_phi = 1.0
        rho0 = 4.5
        phi0 = pi /4

        # variables
        tf ∈ R, variable
        t ∈ [ t0, tf ], time
        x ∈ R³, state
        u ∈ R³, control
        rho = x₁
        phi = x₂
        the = x₃
        u_rho = u₁
        u_phi = u₂
        u_the = u₃

        # constraints
        0 ≤ rho(t) ≤ L,                     (rho_con)
        -pi ≤ the(t) ≤ pi,                  (the_con)
        0 ≤ phi(t) ≤ pi,                    (phi_con)  
        -max_u_rho ≤ u_rho(t) ≤ max_u_rho,  (u_rho_con)
        -max_u_the ≤ u_the(t) ≤ max_u_the,  (u_the_con)
        -max_u_phi ≤ u_phi(t) ≤ max_u_phi,  (u_rho_con)
        0.0 ≤ tf ≤ Tmax,                    (tf_con)  
        rho(t0) == rho0,                    (rho0_con)
        phi(t0) == phi0,                    (phi0_con)
        the(t0) == 0.0,                     (the0_con)
        rho(tf) == rho0,
        phi(tf) == phi0,
        the(tf) == 2.0 * pi / 3,
        

        # dynamics
        ẋ(t) ==

        # objective
        tf → min
    end
    # ------------------------------------------------------------------------------------------
    # the solution

end

