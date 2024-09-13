# Control-toolbox benchmark

## Description

This project is a tool to compare the performance of two optimal control solvers : `JuMP` and `OptimalControl`. The comparison is done on different problems. The goal is to evaluate the performance of OptimalControl in terms of speed and accuracy. It also aims to identify the limitations of OptimalControl and to propose some improvements.

## Getting Started

For this project, you need to have the following packages installed:
1. Models
    - [JuMP](https://jump.dev/JuMP.jl/stable/) 
    - [OptimalControl](https://control-toolbox.org/OptimalControl.jl/stable/)
    - [CTDirect](https://control-toolbox.org/docs/ctdirect/stable/)
    - [CTBase](https://control-toolbox.org/docs/ctbase/stable/)
    - [ExaModels](https://exanauts.github.io/ExaModels.jl/stable/)
    - [NLPModelsIpopt](https://jso.dev/NLPModelsIpopt.jl/stable/)
2. Solvers
    - [IPOPT](https://github.com/jump-dev/Ipopt.jl)
    - [KNITRO](https://www.artelys.com/app/docs/knitro/1_introduction.html): To use KNITRO, you need a license from [Artelys KNITRO](https://www.artelys.com/products/knitro/). For installation instructions, you can check the [installation guide](https://www.artelys.com/app/docs/knitro/1_introduction/installation.html).
    - [HSL_jll](https://licences.stfc.ac.uk/product/libhsl): After obtaining the license, to use the HSL solvers in Julia, you can check the following [link](https://discourse.julialang.org/t/how-to-get-hsl-up-and-running-with-ipopt/114138/3) for installation instructions.
    - [MadNLP](https://madnlp.github.io/MadNLP.jl/stable/)
    - [MadNLPHSL](https://github.com/MadNLP/MadNLP.jl/tree/master/lib/MadNLPHSL)
3. Tools
    - [Plots](http://docs.juliaplots.org/latest/)
    - [BenchmarkTools](https://github.com/JuliaCI/BenchmarkTools.jl)
    - [DataFrames](https://dataframes.juliadata.org/stable/)
    - [Interpolations](http://juliamath.github.io/Interpolations.jl/latest/)
    - [MathOptInterface](https://jump.dev/MathOptInterface.jl/stable/)
    - [MathOptSymbolicAD](https://juliapackages.com/p/mathoptsymbolicad)

## Organization

The project is composed of three main directories : 

### 1. Problems
This directory contains the different problems that we want to solve. Each problem is defined in the JuMP format ( in `/Problems/JuMP` ) and in the OptimalControl format ( in `/Problems/OptimalControl` ).
We have the following problems <span  style="font-size:0.8em;">(Let XX be JMP or OC)</span>:
- ***"The Hanging Chain Problem"*** (`chain_XX`) : This problem consists of a chain hanging from two points. The goal is to find the shape of the chain that minimizes the potential energy.
- ***"The Hang Glider Problem"*** (`glider_XX`): This problem consists of a hang glider that has to reach a target point. The goal is to find the trajectory that maximize the final horizontal position of the glider while in the presence of a thermal updraft.
- ***"The Robot Arm Problem"*** (`robot_XX`): This problem consists of a robot arm that has to reach a target point. The goal is to find the trajectory that minimize the time taken for the robot arm to travel between the two points.
- ***"The Goddard Rocket Problem"*** (`rocket_XX`): This problem consists of maximizing the final altitude of a rocket using the thrust as a control and given the initial mass, the fuel mass, and the drag characteristics of the rocket.      
- ***"The Particle Steering Problem"*** (`steering_XX`) : This problem consists of a particle that has to reach a target point. The goal is to find the trajectory that minimize the time taken for the particle to travel between the two points.
- ***"The Space Shuttle Reentry Problem"*** (`space_Shuttle_XX`) : This problem consists of finding the optimal trajectory of a space shuttle reentry. The objective is to minimize the angle of attack at the terminal point.
- ***"The Cart Pendulum Problem"*** (`cart_pendulum_XX`) : This problem consists of a cart pendulum system. The goal is to find the trajectory that minimize the time taken for the cart pendulum to travel from a downward position to an upward position.
- ***"The Moonlander Problem"*** (`moonlander_XX`): This problem consists of finding the optimal trajectory of a spacecraft to land on the moon. The objective is to minimize the time taken to land.
- ***"The Truck Trailer Problem"*** (`truck_trailer_XX`): This problem consists of a truck trailer system. The goal is to find the trajectory that minimize the time taken for the truck and the two trailers to travel between a horizontal position and a vertical target position.
- ***The Electrical Vehicle Problem"*** (`electrical_vehicle_XX`): This problem consists of an electrical vehicle system.
- ***"The Quadrotor Point to Point Problem:"*** (`quadrotorP2P_XX`): This problem consists of a quadrotor system. The goal is to find the trajectory that minimize the time taken for the quadrotor to travel between two points.
- ***"The Quadrotor one Obstacle Problem:"*** (`quadrotor1Obs_XX`): This problem consists of a quadrotor system. The goal is to find the trajectory that minimize the time taken for the quadrotor to travel between two points while avoiding an obstacle.
- ***"The Dielectrophoretic Particle Problem:"*** (`particle_XX`): This problem consists of a dielectrophoretic particle system. The goal is to find the trajectory that minimize the time taken for the particle to travel between two points.
- ***"The Ducted Fan Problem:"*** (`ducted_fan_XX`): This problem consists of a planar ducted fan system. 
- ***"Double Oscillator Problem:"*** (`oscillator_XX`): This problem consists of a double oscillator system. 

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
| `The Quadrotor P2P` | ✅ | ✅| ❌ not same solution found|
| `The Quadrotor 1Obstacle` | ❌ | ❌| ❌ |
| `The Dielectrophoretic Particle` | ✅ | ✅| 🆗 |
| `The Ducted Fan` | ✅ | ✅| 🆗 |
| `The Double Oscillator` | ✅ | ✅| solution 🆗 + costate differences |
| `The Electrical Vehicle` | ✅ | ✅| solution 🆗 + costate differences |




### 2. TestProblems

This directory contains the execution of the different problems stated above. The goal is to compare the performance of JuMP and OptimalControl in terms of accuracy:
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
- ***"TestQuadrotorP2P"*** : This file contains the execution of the quadrotor point to point problem.
- ***"TestQuadrotor1Obs"*** : This file contains the execution of the quadrotor one obstacle problem.
- ***"TestSpaceShuttleOC"*** : This file contains the execution of the space shuttle problem with OptimalControl.
- ***"TestSpaceShuttleJMP"*** : This file contains the execution of the space shuttle problem with JuMP. It compares the results using the rectangular and the trapezoidal integration methods.
- ***"TestSpaceShuttleSolvers"*** : This file contains the execution of the space shuttle problem with JuMP. It compares the results using different linear and nonlinear solvers.



### 3. Benchmark
This directory contains the benchmark of the Goddard Rocket Problem. 
The main two files are :
- ***"GoddardModels"*** : This file contains the benchmark of the Goddard Rocket Problem using different linear solvers (MUMPS, HSL_MA57 and HSL_MA27) with both JuMP and OptimalControl. We compare the results on terms of speed and accuracy.
- ***"GoddardJuMPs"*** : This file contains the benchmark of the Goddard Rocket Problem using JuMP. We compare the results of different linear solvers, backends, and nonlinear solvers. The goal is to find the best combination that gives the best results.
For this matter, we use the following functions that varyate the different parameters:
    - *"backend_variant"* : This function compares the results of different backends (ExaModels, JuMPDefault and SymbolicAD) with JuMP.
    - *"linear_solver_variant"* : This function compares the results of different linear solvers (MUMPS, HSL_MA57 and HSL_MA27) with JuMP.
    - *"solver_variant"* : This function compares the results of different nonlinear solvers (IPOPT, MadNLP and KNITRO) with JuMP.
- ***"Benchmark"*** : This file contains the benchmark module that solves the different models with different solvers and compares the results in terms of speed and accuracy.
  It contains 3 main functions:
    - *"Benchmark_model(model_key,nb_discr_list)"* : This function compares the results of different solvers (JuMP and OptimalControl) on a specific problem (model_key) with different discretization values (nb_discr_list).
    - *"Benchmark_JuMP(nb_discr_list,excluded_models)"* : This function compares the results of solving with JuMP on the different problems with different discretization values (nb_discr_list). It excludes the problems in the excluded_models list.
    - *"Benchmark_OC(nb_discr_list,excluded_models)"* : This function compares the results of solving with OptimalControl on the different problems with different discretization values (nb_discr_list). It excludes the problems in the excluded_models list.
      
    To run the benchmark, you can use the following command:
```julia
    include("./path/to/Benchmark.jl")
    Benchmark.Benchmark_OC()
    Benchmark.Benchmark_JuMP()
    Benchmark.Benchmark_model(:glider)
```

The results of the benchmark are generated in the `Benchmark/outputs` directory. They are saved in Latex files that contains the following columns:

- *Model* : The name of the problem.
- *Discretization* : The number of discretization points.
- *Iterations* : The number of iterations.
- *Total Time* : The total time taken to solve the problem.
- *Ipopt Time* : The time taken by Ipopt to solve the problem.
- *Objective Value* : The value of the objective function.
- *Flag* : The status of the solution.

## License

## Acknowledgments
