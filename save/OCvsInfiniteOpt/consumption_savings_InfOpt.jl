function consumption_savings_InfOpt(; nh=1000)
    ρ = 0.025  # discount rate
    k = 100.0  # utility bliss point
    T = 10.0   # life horizon
    r = 0.05   # interest rate
    B0 = 100.0 # endowment
    u(c; k=k) = -(c - k)^2       # utility function
    discount(t; ρ=ρ) = exp(-ρ*t) # discount function
    BC(B, c; r=r) = r*B - c      # budget constraint
    opt = Ipopt.Optimizer   # desired solver
    m = InfiniteModel(opt)
    @infinite_parameter(m, t in [0, T], num_supports = nh)

    @variable(m, B, Infinite(t), start = B0)
    @variable(m, c, Infinite(t), start = B0)
    @objective(m, Max, integral(u(c), t, weight_func=discount))
    @constraint(m, B(0) == B0)
    @constraint(m, B(T) == 0)
    @constraint(m, c1, deriv(B, t) == BC(B, c; r=r))

    return m
end
