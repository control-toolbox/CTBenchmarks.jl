"""
    Robot arm problem:
        We want to find the shape of a robot arm moving between two points.
        The objective is to minimize the time taken to move between the two points.
        The problem is formulated as an OptimalControl model.
"""
function robot_OC()
# parameters
    L = 5.0
    max_u_rho = 1.0
    max_u_the = 1.0
    max_u_phi = 1.0
    max_u = [max_u_rho, max_u_the, max_u_phi]
    rho0 = 4.5
    phi0 = pi /4
    thef = 2.0 * pi / 3
    t0 = 0.0

    @def ocp begin 
    # parameters
        L = 5.0
        max_u_rho = 1.0
        max_u_the = 1.0
        max_u_phi = 1.0
        max_u = [max_u_rho, max_u_the, max_u_phi]
        rho0 = 4.5
        phi0 = pi /4
        thef = 2.0 * pi / 3
        t0 = 0.0

    ## define the problem
        tf ∈ R,variable
        t ∈ [ t0, tf ], time
        x ∈ R⁶, state
        u ∈ R³, control

    ## state variables
        rho = x₁
        rho_dot = x₂
        the = x₃
        the_dot = x₄
        phi = x₅
        phi_dot = x₆
    ## control variables
        u1 = u₁
        u2 = u₂
        u3 = u₃

    ## constraints
        # state constraints
        0 ≤ rho(t) ≤ L,                        (rho_con)
        -pi ≤ the(t) ≤ pi,                     (the_con)
        0 ≤ phi(t) ≤ pi,                       (phi_con)
        # control constraints
        -max_u_rho ≤ u₁(t) ≤ max_u_rho,        (u_rho_con)
        -max_u_the ≤ u₂(t) ≤ max_u_the,        (u_the_con)
        -max_u_phi ≤ u₃(t) ≤ max_u_phi,        (u_phi_con)
        # initial conditions
        rho(t0) == rho0,                       (rho0_con)
        phi(t0) == phi0,                       (phi0_con)
        the(t0) == 0.0,                        (the0_con)
        the_dot(t0) == 0.0,                    (the_dot0_con)
        phi_dot(t0) == 0.0,                    (phi_dot0_con)
        rho_dot(t0) == 0.0,                    (rho_dot0_con)
        # final conditions
        rho(tf) == rho0,                       (rhof_con)
        the(tf) == thef,                       (thef_con)
        phi(tf) == phi0,                       (phif_con)
        the_dot(tf) == 0.0,                    (the_dotf_con)
        phi_dot(tf) == 0.0,                    (phi_dotf_con)
        rho_dot(tf) == 0.0,                    (rho_dotf_con)

    ## dynamics  
        ẋ(t) == [rho_dot(t),
                    u1(t) / L,
                    the_dot(t),
                    u2(t) * 3 /(((L-rho(t))^3 + rho(t)^3) * sin(phi(t))^2),
                    phi_dot(t),
                    u3(t) * 3 /((L-rho(t))^3 + rho(t)^3)]

    ## objective
        tf → min

    end
    return ocp

end


function robot_init(;nh)
    rho0 = 4.5
    phi0 = pi/4

    xinit = t -> [rho0,
            2*pi/3*(t^2),
            phi0,
            0.0,
            4*pi/3*t,
            0.0]
    uinit = [0.0, 0.0, 0.0]
    init = (state = xinit, control = uinit , variable= 1.0)

    return init
end