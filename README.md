# Control-toolbox benchmarks

## Description

This project is a tool to compare the performance of [`OptimalControl`](https://github.com/control-toolbox/OptimalControl.jl) and other existing tools such as `JuMP` and `InfiniteOpt` in solving optimal control problems from the package [`OptimalControlProblems.jl`](https://github.com/control-toolbox/OptimalControlProblems.jl).
The goal is to evaluate the performance of `OptimalControl` in terms of speed and accuracy. It also aims to identify the limitations of OptimalControl and to propose some improvements.

## Getting Started

For this project, you need to have the following packages installed:
1. Models
    - [OptimalControlProblems](https://github.com/control-toolbox/OptimalControlProblems.jl)
    - [JuMP](https://jump.dev/JuMP.jl/stable/) 
    - [OptimalControl](https://control-toolbox.org/OptimalControl.jl/stable/)
    - [ExaModels](https://exanauts.github.io/ExaModels.jl/stable/)
    - [NLPModels](https://jso.dev/NLPModels.jl/stable/)
2. Solvers
    - [IPOPT](https://github.com/jump-dev/Ipopt.jl)
    - [KNITRO](https://www.artelys.com/app/docs/knitro/1_introduction.html): To use KNITRO, you need a license from [Artelys KNITRO](https://www.artelys.com/products/knitro/). For installation instructions, you can check the [installation guide](https://www.artelys.com/app/docs/knitro/1_introduction/installation.html).
    - [HSL_jll](https://licences.stfc.ac.uk/product/libhsl): After obtaining the license, to use the HSL solvers in Julia, you can check the following [link](https://discourse.julialang.org/t/how-to-get-hsl-up-and-running-with-ipopt/114138/3) for installation instructions.
    - [MadNLP](https://madnlp.github.io/MadNLP.jl/stable/)
3. Tools
    - [BenchmarkTools](https://github.com/JuliaCI/BenchmarkTools.jl)
    - [DataFrames](https://dataframes.juliadata.org/stable/)
    - [Interpolations](http://juliamath.github.io/Interpolations.jl/latest/)
    - [MathOptSymbolicAD](https://juliapackages.com/p/mathoptsymbolicad)

## Unit tests

The directory `test` contains the execution of the different problems from `OptimalControlProblems`. The goal is to compare the performance of `JuMP` and `OptimalControl` in terms of accuracy:
- ***"TestChain"*** : This file contains the execution of the chain problem.
- ***"TestGlider"*** : This file contains the execution of the glider problem.
- ***"TestRobot"*** : This file contains the execution of the robot problem.
- ***"TestRocket"*** : This file contains the execution of the rocket problem.
- ***"TestSteering"*** : This file contains the execution of the steering problem.
- ***"TestCartPendulum"*** : This file contains the execution of the cart pendulum problem.
- ***"TestMoonLander"*** : This file contains the execution of the moon lander problem.
- ***"TestTruckTrailer"*** : This file contains the execution of the truck trailer problem.
- ***"TestParticle"*** : This file contains the execution of the particle problem.
- ***"TestDuctedFan"*** : This file contains the execution of the ducted fan problem.
- ***"TestOscillator"*** : This file contains the execution of the oscillator problem.
- ***"TestElectricalVehicle"*** : This file contains the execution of the electrical vehicle problem.
- ***"TestQuadrotor"*** : This file contains the execution of the quadrotor point to point problem.
- ***"TestSpaceShuttle"*** : This file contains the execution of the space shuttle problem.
- ***"TestSpaceShuttleSolvers"*** : This file contains the execution of the space shuttle problem with JuMP. It compares the results using different linear and nonlinear solvers.

=> The table below summarizes the status of the each problem with JuMP and OptimalControl:

| Problem | With JuMP | With OptimalControl | Comparaison Remarks |
| --- | --- | --- | --- |
| `The Hanging Chain` |   ✅  |   ✅ | 🆗|
| `The Hang Glider` |  ✅  |  ✅ | 🆗 |
| `The Robot Arm` |  ✅ | ✅| solution 🆗 + costate differences |
| `The Goddard Rocket` |  ✅ | ✅| 🆗 |
| `The Particle Steering` |  ✅ | ✅|🆗  |
| `The Space Shuttle Reentry` |  ✅ |  ❌| ❌ not same solution found |
| `The Cart Pendulum` | ✅ | ✅| 🆗 |
| `The Moonlander` | ✅ | ✅| 🆗 |
| `The Truck Trailer` | ✅ | ❌| ❌ |
| `The Quadrotor` | ✅ | ✅| ❌ not same solution found|
| `The Dielectrophoretic Particle` | ✅ | ✅| 🆗 |
| `The Ducted Fan` | ✅ | ✅| 🆗 |
| `The Double Oscillator` | ✅ | ✅| solution 🆗 + costate differences |
| `The Electrical Vehicle` | ✅ | ✅| solution 🆗 + costate differences |

## Benchmark

The directory `benchmark` contains the benchmark of the different problems from `OptimalControlProblems`.  
The main three files are :
- ***"GoddardModels"*** : This file contains the benchmark of the Goddard Rocket Problem using different linear solvers (MUMPS, HSL_MA57 and HSL_MA27) with both JuMP and OptimalControl. We compare the results on terms of speed and accuracy.
- ***"GoddardJuMPs"*** : This file contains the benchmark of the Goddard Rocket Problem using JuMP. We compare the results of different linear solvers, backends, and nonlinear solvers. The goal is to find the best combination that gives the best results.
For this matter, we use the following functions that varyate the different parameters:
    - *"backend_variant"* : This function compares the results of different backends (ExaModels, JuMPDefault and SymbolicAD) with JuMP.
    - *"linear_solver_variant"* : This function compares the results of different linear solvers (MUMPS, HSL_MA57 and HSL_MA27) with JuMP.
    - *"solver_variant"* : This function compares the results of different nonlinear solvers (IPOPT, MadNLP and KNITRO) with JuMP.
- ***"Benchmark"*** : This file contains the benchmark module that solves the different models with different solvers and compares the results in terms of speed and accuracy.
  It contains 5 main functions:
    - *"Benchmark_model(model_key,nb_discr_list)"* : This function compares the results of different solvers (JuMP and OptimalControl) on a specific problem (model_key) with different discretization values (nb_discr_list).
    - *"Benchmark_JuMP(nb_discr_list,excluded_models)"* : This function compares the results of solving with JuMP on the different problems with different discretization values (nb_discr_list). It excludes the problems in the excluded_models list.
    - *"Benchmark_OC(nb_discr_list,excluded_models)"* : This function compares the results of solving with OptimalControl on the different problems with different discretization values (nb_discr_list). It excludes the problems in the excluded_models list.
    - *"Benchmark_Callbacks(model_key,nb_discr_list)"* : This function compares the results of different callbacks on a specific problem (model_key) with different discretization values (nb_discr_list).
    - *"Benchmark_KNITRO(model_key,nb_discr_list)"* : This function compares the results with KNITRO on a specific problem (model_key) with different discretization values (nb_discr_list).
      
    To run the benchmark, you can use the following command:
```julia
    include("./path/to/Benchmark.jl")
    Benchmark.Benchmark_OC()
    Benchmark.Benchmark_JuMP()
    Benchmark.Benchmark_model(:glider)
```

The results of the benchmark are generated in the `benchmark/outputs` directory. They are saved in Latex files that contains the following columns:

- *Model* : The name of the problem.
- *Discretization* : The number of discretization points.
- *Iterations* : The number of iterations.
- *Total Time* : The total time taken to solve the problem.
- *Ipopt Time* : The time taken by Ipopt to solve the problem.
- *Objective Value* : The value of the objective function.
- *Flag* : The status of the solution.

## Other folders 

- ***"OCvsInfiniteOpt"*** : This directory contains the comparison of OptimalControl and InfiniteOpt on the quadrotor and [consumption savings problem](https://infiniteopt.github.io/InfiniteOpt.jl/stable/examples/Optimal%20Control/consumption_savings/#Consumption-Savings-Problem) from InfiniteOpt. The task is from the issue [#21](https://github.com/control-toolbox/CTBenchmarks.jl/issues/21).

- ***"exa"*** and ***"exa2"*** : This directories contain the comparison of OptimalControl and ExaModels on the Goddard rocket problem. The task is from the issue [#26](https://github.com/control-toolbox/CTBenchmarks.jl/issues/26).

- ***"sparsity"*** : This directory contains the comparison of OptimalControl and JuMP on the Goddard rocket problem and The Dielectrophoretic Particle problem in term of sparsity pattern. The task is from the issue [#24](https://github.com/control-toolbox/CTBenchmarks.jl/issues/24).

## License

## Acknowledgments
