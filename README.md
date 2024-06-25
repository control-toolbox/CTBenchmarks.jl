# COTS : Control Optimal Test Set

## Description

This project is a tool to compare the performance of two optimal control solvers : `JuMP` and `OptimalControl`. The comparison is done on different problems. The goal is to evaluate the performance of `OptimalControl` in terms of speed and accuracy. It aims also to identify the limitations of `OptimalControl` and to propose some improvements.

## Getting Started
For this project, you need to have the following packages installed :
- [JuMP](https://jump.dev/JuMP.jl/stable/) 
- [OptimalControl](https://control-toolbox.org/OptimalControl.jl/stable/)
- [Plots](http://docs.juliaplots.org/latest/)
- [BenchmarkTools](https://github.com/JuliaCI/BenchmarkTools.jl)
- [MathOptSymbolicAD](https://juliapackages.com/p/mathoptsymbolicad
- [ExaModels](https://exanauts.github.io/ExaModels.jl/stable/)
- [NLPModelsIpopt](https://jso.dev/NLPModelsIpopt.jl/stable/)
- [IPOPT](https://github.com/jump-dev/Ipopt.jl)
- [MathOptInterface](https://jump.dev/MathOptInterface.jl/stable/)
- [DataFrames]()



## Organization

The project is composed of three main directories : 

### Problems
This directory contains the different problems that we want to solve. Each problem is defined in the JuMP format (`/Problems/JuMP`) and in the OptimalControl format (`/Problems/OptimalControl`).
We have the following problems `Let XX be JMP or OC`:
- *"The Hanging Chain Problem"* (`chain_XX`) : This problem consists of a chain hanging from two points. The goal is to find the shape of the chain that minimizes the potential energy.
- *"The Hang Glider Problem"* (`glider_XX`): This problem consists of a hang glider that has to reach a target point. The goal is to find the trajectory that maximize the final horizontal position of the glider while in the presence of a thermal updraft.
- *"The Robot Arm Problem"* (`robot_XX`): This problem consists of a robot arm that has to reach a target point. The goal is to find the trajectory that minimize the time taken for the robot arm to travel between the two points.
- *"The Rocket Problem"* (`rocket_XX`): This problem consists of maximizing the final altitude of a rocket using the thrust as a control and given the initial mass, the fuel mass, and the drag characteristics of the rocket.      
- *"The Particle Steering Problem"* (`steering_XX`) : This problem consists of a particle that has to reach a target point. The goal is to find the trajectory that minimize the time taken for the particle to travel between the two points.
- *"The Space Shuttle Reentry Problem"* (`space_Shuttle_XX`) : This problem consists of finding the optimal trajectory of a space shuttle reentry. The objective is to minimize the angle of attack at the terminal point.

### TestProblems
This directory contains the execution of the different problems stated above. The goal is to compare the performance of JuMP and OptimalControl in terms of accuracy.
- *"TestChain"* : This file contains the execution of the chain problem.
- *"TestGlider"* : This file contains the execution of the glider problem.
- *"TestRobot"* : This file contains the execution of the robot problem.
- *"TestRocket"* : This file contains the execution of the rocket problem.
- *"TestSteering"* : This file contains the execution of the steering problem.
- *"TestSpaceShuttleOC"* : This file contains the execution of the space shuttle problem with OptimalControl.
- *"TestSpaceShuttleJMP"* : This file contains the execution of the space shuttle problem with JuMP. It compares the results using the rectangular and the trapezoidal integration methods.
- *"TestSpaceShuttleSolvers"* : This file contains the execution of the space shuttle problem with JuMP. It compares the results using different linear and nonlinear solvers.

### Benchmark
This directory contains the benchmark of the Goddard Rocket Problem. 
The main two files are :
- *"GoddardJuMPs"* : This file contains the benchmark of the Goddard Rocket Problem using JuMP. We compare the results of different linear solvers, backends, and nonlinear solvers. The goal is to find the best combination that gives the best results.
- *"GoddardModels"* : This file contains the benchmark of the Goddard Rocket Problem using different linear solvers (MUMPS, HSL_MA57 and HSL_MA27) with both JuMP and OptimalControl. We compare the results on terms of speed and accuracy.
For this matter, we use the following functions that varyate the different parameters.
- *"backend_variant"* : This function compares the results of different backends (ExaModels, JuMPDefault and SymbolicAD) with JuMP.
- *"linear_solver_variant"* : This function compares the results of different linear solvers (MUMPS, HSL_MA57 and HSL_MA27) with JuMP.
- *"solver_variant"* : This function compares the results of different nonlinear solvers (IPOPT, MadNLP and KNITRO) with JuMP.

## Issues

## License

## Acknowledgments

Inspiration, code snippets, etc.
* [link](link)