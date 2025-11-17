# [Performance Profiles](@id performance-profiles)

Performance profiles are a powerful visualization tool for comparing the performance of multiple algorithms (or solver-model combinations) across a set of test problems. They were introduced by Dolan and Moré in 2002[^1] and have become a standard method for benchmarking optimization software.

This page explains:

- The general concept of performance profiles
- How they are adapted in CTBenchmarks.jl
- How to interpret the resulting plots

---

## The General Concept

### Motivation

Traditional benchmarking efforts often involve extensive tables displaying solver performance on various metrics. However, these tables face inherent challenges:

- The sheer volume of data becomes overwhelming, especially for large test sets
- Interpretation of results frequently leads to disagreements
- A small subset of problems can dominate the conclusions

Performance profiles address these issues by using **performance ratios** rather than raw metrics, offering insights into the percent improvement of a solver's metric compared to the best solver.

### Mathematical Definition

Consider:

- A set of **solvers** $S$ (or solver-model combinations)
- A set of **problems** $P$
- A **performance metric** $t_{p,s}$ for each solver $s \in S$ on problem $p \in P$

The metric must be a positive value where **smaller is better** (e.g., CPU time, number of iterations).

#### Performance Ratio

The **performance ratio** $r_{p,s}$ of solver $s$ on problem $p$ is defined as:

```math
r_{p,s} := \frac{t_{p,s}}{\min_{s' \in S} t_{p,s'}}
```

where $t_{p,s}$ is the value of the chosen metric for solver $s$ on problem $p$.

Key properties:

- We have $r_{p,s} \geq 1$ by definition
- Having $r_{p,s} = 1$ means that solver $s$ achieved the best performance on problem $p$
- When a solver **fails** to solve a problem (e.g., reaches maximum time or iteration limit), we assign $r_{p,s} = +\infty$

#### Performance Profile Function

The **performance profile** is the cumulative distribution function for the performance ratio:

```math
\rho_s(\tau) := \frac{1}{n_p} \sum_{p \in P} \mathbb{1}_{r_{p,s} \leq \tau}
```

where:

- the parameter $n_p$ is the total number of problems
- the indicator function $\mathbb{1}_X$ is defined as $\mathbb{1}_X = 1$ if condition $X$ is true, and $\mathbb{1}_X = 0$ otherwise

In words, $\rho_s(\tau)$ represents **the proportion of problems for which solver $s$ has a performance ratio within a factor $\tau$ of the best solver**.

### Key Properties

By definition, $\rho_s(\tau)$ has several important properties:

1. **Range**: $0 \leq \rho_s(\tau) \leq 1$ for all $\tau$
2. **At $\tau = 1$**: The value $\rho_s(1)$ gives the **percentage of problems where solver $s$ achieved the best performance**
   - Note: The sum across all solvers may exceed 100% in case of ties
3. **Monotonicity**: $\tau \mapsto \rho_s(\tau)$ is a **non-decreasing function**
4. **Plateau**: For $\tau$ sufficiently large, all solvers should reach a plateau representing **the percentage of problems solved**
   - If $\rho_s(\tau) < 1$ for all $\tau$, solver $s$ failed on some problems

---

## Performance Profiles in CTBenchmarks.jl

### Adaptation to Our Context

In CTBenchmarks.jl, we adapt the classical Dolan–Moré definition to our specific benchmark structure:

#### Instances

An **instance** is a pair $(problem, grid\_size)$ appearing in the benchmark results, regardless of whether it was successfully solved by any solver.

For example:

- `(beam, 100)`
- `(beam, 500)`
- `(crane, 200)`

are three distinct instances.

#### Solver-Model Combinations

A **solver-model combination** $s$ is identified by the pair `(model, solver)`.

For example:

- `(JuMP, Ipopt)`
- `(ADNLPModels, Ipopt)`
- `(ExaModels, MadNLP)`

are three distinct solver-model combinations.

### Performance Metric

For each instance $p = (problem, grid\_size)$ and solver-model $s$:

1. If the run $(p, s)$ has `success == true` and a valid benchmark object, we extract the **CPU wall time**:

   ```math
   t_{p,s} = \text{benchmark["time"]}
   ```

2. Among all solver-models that succeeded on instance $p$, we compute the **best (minimal) time**:

   ```math
   t_p^* = \min_{s' \in S} t_{p,s'}
   ```

3. For every successful run $(p, s)$, we define the **performance ratio**:

   ```math
   r_{p,s} = \frac{t_{p,s}}{t_p^*} \geq 1
   ```

4. Instances where solver-model $s$ **failed** (or has no valid timing) are treated as having $r_{p,s} = +\infty$

### Performance Profile Definition

The performance profile of each solver-model combination $s$ is:

```math
\rho_s(\tau) = \frac{1}{N} \cdot \#\{ \text{instances } p : r_{p,s} \leq \tau \}
```

where $N$ is the **total number of distinct $(problem, grid\_size)$ instances** present in the JSON file, **including those where all solvers failed**.

### Treatment of Failures

This definition has important consequences:

- Only instances with `success == true` and valid timing contribute ratios $r_{p,s}$ and can increase $\rho_s(\tau)$

- Instances where a given solver-model **fails** are counted in $N$ but never in the numerator for that solver-model

- Instances where **all** solver-models fail are still included in $N$ but do not contribute any $r_{p,s}$ for any solver-model

**Consequence**: If there exist problem-grid instances that are not solved by a given solver-model combination, its curve $\rho_s(\tau)$ will **plateau strictly below 1** (100%). If some instances are unsolved by *all* solver-models, then **no curve can reach 1**, clearly indicating that there are problems for which none of the tested approaches succeeded.

---

## Optimal Control Problems and Discretization

### What are Optimal Control Problems?

The benchmarks in CTBenchmarks.jl are based on **optimal control problems (OCPs)** from the [OptimalControlProblems.jl](https://control-toolbox.org/OptimalControlProblems.jl/stable/) package. An optimal control problem with fixed initial and final times consists of minimizing a cost functional (in Bolza form):

```math
J(x, u) = g(x(t_0), x(t_f)) + \int_{t_0}^{t_f} f^{0}(t, x(t), u(t))~\mathrm{d}t
```

where:

- the variable $x(t)$ is the **state** trajectory (e.g., position, velocity)
- the variable $u(t)$ is the **control** input (e.g., force, torque)
- the function $g$ is the **Mayer cost** (terminal cost)
- the function $f^0$ is the **Lagrange cost** (running cost)
- the variable $t \in [t_0, t_f]$ is the time interval

The state and control must satisfy the **dynamics constraint**:

```math
\dot{x}(t) = f(t, x(t), u(t))
```

and possibly other constraints:

```math
\begin{array}{llcll}
x_{\mathrm{lower}} & \le & x(t) & \le & x_{\mathrm{upper}}, & \text{(state box constraints)} \\
u_{\mathrm{lower}} & \le & u(t) & \le & u_{\mathrm{upper}}, & \text{(control box constraints)} \\
c_{\mathrm{lower}} & \le & c(t, x(t), u(t)) & \le & c_{\mathrm{upper}}, & \text{(path constraints)} \\
b_{\mathrm{lower}} & \le & b(x(t_0), x(t_f)) & \le & b_{\mathrm{upper}}. & \text{(boundary constraints)}
\end{array}
```

**Cost types**:

- **Mayer**: Only terminal cost ($f^0 = 0$)
- **Lagrange**: Only integral cost ($g = 0$)
- **Bolza**: Both terminal and integral costs

### The Direct Method: From OCP to NLP

The **direct method** transforms the infinite-dimensional optimal control problem into a finite-dimensional **nonlinear programming problem (NLP)** by discretizing time. This approach is:

- **More robust** with respect to initialization than indirect methods (Pontryagin's Maximum Principle)
- **Easier to apply**, which explains its widespread use in industrial applications
- **Less precise** than indirect methods, but sufficient for many practical purposes

#### Discretization Scheme

In OptimalControlProblems.jl, every OCP is discretized using the **trapezoidal rule** on a uniform grid with $N$ steps:

```math
\begin{array}{lclr}
t \in [t_0,t_f] & \to & t_0 < t_1 < \dots < t_N=t_f, \text{ with } t_{i}-t_{i-1} = \frac{t_f-t_0}{N}, & i = 1:N \\[0.5em]
x(\cdot),\, u(\cdot) & \to & X=\{x_0, \ldots, x_N, u_0, \ldots, u_N\} & \\[1em]
\hline \\
\text{step} & \to & \displaystyle h = \frac{t_f-t_0}{N} & \\[0.5em]
\text{criterion} & \to & \displaystyle g(x_0, x_N) + \frac{h}{2} \sum_{i=1}^{N} \left( f^0(t_i, x_i, u_i) + f^0(t_{i-1}, x_{i-1}, u_{i-1}) \right) & \\[1em]
\text{dynamics} & \to & \displaystyle x_{i} = x_{i-1} + \frac{h}{2} \left( f(t_i, x_i, u_i) + f(t_{i-1}, x_{i-1}, u_{i-1}) \right), & i = 1:N \\[1em]
\text{state constraints} & \to & x_{\mathrm{lower}} \le x_i \le x_{\mathrm{upper}}, & i = 0:N \\[1em]
\text{control constraints} & \to & u_{\mathrm{lower}} \le u_i \le u_{\mathrm{upper}}, & i = 0:N \\[1em]
\text{path constraints} & \to & c_{\mathrm{lower}} \le c(t_i, x_i, u_i) \le c_{\mathrm{upper}}, & i = 0:N \\[1em]
\text{boundary constraints} & \to & b_{\mathrm{lower}} \le b(x_0, x_N) \le b_{\mathrm{upper}} &
\end{array}
```

This yields a standard NLP of the form:

```math
\text{(NLP)} \quad \left\{ \begin{array}{lr}
\min \  F(X) \\[1em]
X_{\mathrm{lower}} \le X \le X_{\mathrm{upper}}\\[0.5em]
C_{\mathrm{lower}} \le C(X) \le C_{\mathrm{upper}}
\end{array} \right.
```

where $X$ contains all discretized state and control variables, and $C(X)$ represents the discretized dynamics and constraints.

### Grid Size and Problem Instances

The **grid size** $N$ (number of discretization steps) is a crucial parameter:

- **Smaller $N$**: Faster to solve, but less accurate approximation of the continuous problem
- **Larger $N$**: More accurate, but computationally more expensive

In CTBenchmarks.jl, we benchmark each optimal control problem at **multiple grid sizes** to assess:

- **Scalability**: How does solver performance degrade as $N$ increases?
- **Accuracy vs. speed trade-offs**: Which solver-model combinations are efficient for coarse/fine grids?

This is why an **instance** is defined as a pair $(problem, grid\_size)$: the same optimal control problem discretized with different $N$ values represents different computational challenges.

### Available Optimal Control Problems

The [OptimalControlProblems.jl](https://control-toolbox.org/OptimalControlProblems.jl/stable/) package provides a curated collection of optimal control problems from the literature. Each problem is modeled in two ways:

1. **JuMP models**: Direct NLP formulation using [JuMP.jl](https://jump.dev/)
2. **OptimalControl models**: High-level OCP description using [OptimalControl.jl](https://control-toolbox.org/OptimalControl.jl/stable/), with automatic discretization via [CTDirect.jl](https://control-toolbox.org/CTDirect.jl/stable/)

**Examples of problems** (see the [problems browser](https://control-toolbox.org/OptimalControlProblems.jl/stable/problems_browser.html) for the complete list):

- **Beam**: Minimize vibrations in a flexible beam
- **Chain**: Hanging chain with control forces
- **Double oscillator**: Coupled oscillators with control
- **Goddard**: Rocket ascent problem (maximize altitude)
- **Robot**: Robot arm trajectory optimization
- **Steering**: Vehicle steering with obstacle avoidance
- **Vanderpol**: Van der Pol oscillator control

Each problem has specific characteristics:

- **State dimension**: Number of state variables (e.g., position, velocity)
- **Control dimension**: Number of control inputs
- **Cost type**: Mayer, Lagrange, or Bolza
- **Constraints**: Which types of constraints are present (state, control, path, boundary)

You can explore all problems interactively in the [problems browser](https://control-toolbox.org/OptimalControlProblems.jl/stable/problems_browser.html), which allows filtering by:

- Number of state/control variables
- Cost type (Mayer, Lagrange, Bolza)
- Constraint types (state, control, path, boundary)
- Final time (fixed or free)

### Models and Solvers

In CTBenchmarks.jl, a **model** refers to the Julia package used to formulate the NLP:

- **JuMP**: [JuMP.jl](https://jump.dev/) with automatic differentiation
- **ADNLPModels**: [ADNLPModels.jl](https://github.com/JuliaSmoothOptimizers/ADNLPModels.jl) with automatic differentiation
- **ExaModels**: [ExaModels.jl](https://github.com/exanauts/ExaModels.jl) for GPU-accelerated modeling
- **OptimalControl**: [OptimalControl.jl](https://control-toolbox.org/OptimalControl.jl/stable/) with [CTDirect.jl](https://control-toolbox.org/CTDirect.jl/stable/) for direct transcription

A **solver** is the optimization algorithm used to solve the NLP:

- **Ipopt**: [Ipopt.jl](https://github.com/jump-dev/Ipopt.jl) (interior-point method)
- **MadNLP**: [MadNLP.jl](https://github.com/MadNLP/MadNLP.jl) (interior-point method, GPU-capable)

Different **model-solver combinations** can have vastly different performance characteristics:

- **Modeling overhead**: Time to build the NLP (automatic differentiation, sparsity detection)
- **Solver efficiency**: Time to solve the NLP (linear algebra, convergence rate)
- **Memory usage**: RAM and GPU memory requirements
- **Scalability**: Performance on large-scale problems (large $N$)

---

## Example: Performance Profile Plot

The following figure shows a typical performance profile from CTBenchmarks.jl, comparing 6 solver-model combinations on a set of optimal control problems with varying grid sizes.

![Performance Profile Example](assets/figs/performance_profile_example.svg)

### Reading This Example

In this plot:

- **6 solver-model combinations** are compared:
  - `(ADNLPModels, Ipopt)` (blue circles)
  - `(ADNLPModels, MadNLP)` (green diamonds)
  - `(ExaModels, Ipopt)` (red squares)
  - `(ExaModels, MadNLP)` (orange triangles)
  - `(JuMP, Ipopt)` (purple inverted triangles)
  - `(JuMP, MadNLP)` (brown stars)

- **Multiple problem instances**: Each curve represents performance across all $(problem, grid\_size)$ pairs tested

**Key observations**:

1. **At $\tau = 1$** (leftmost):
   - `(ExaModels, Ipopt)` (red) is the fastest on ~25% of instances
   - `(ExaModels, MadNLP)` (orange) is the fastest on ~20% of instances
   - No single combination dominates all instances

2. **At $\tau = 2$**:
   - `(ExaModels, Ipopt)` (red) solves ~60% of instances within 2× the best time
   - `(ExaModels, MadNLP)` (orange) solves ~70% of instances within 2× the best time

3. **Plateaus** (rightmost):
   - `(ExaModels, MadNLP)` (orange) reaches ~75%, indicating it solved 75% of all instances
   - `(ADNLPModels, Ipopt)` (blue) reaches ~80%
   - `(ADNLPModels, MadNLP)` (green) reaches ~75%
   - `(JuMP, Ipopt)` (purple) reaches ~70%
   - Some combinations fail on 20-30% of instances

4. **Trade-offs**:
   - **ExaModels combinations** are often fastest when they succeed, but have lower robustness
   - **ADNLPModels + Ipopt** is more robust (80% success) but rarely the fastest
   - **JuMP combinations** show intermediate performance

**Interpretation**: There is no clear winner. The choice of solver-model combination depends on your priorities:

- For **maximum robustness**: Choose `(ADNLPModels, Ipopt)`
- For **speed on easy problems**: Choose `(ExaModels, Ipopt)` or `(ExaModels, MadNLP)`
- For **balanced performance**: Consider `(ADNLPModels, MadNLP)` or `(JuMP, Ipopt)`

This example illustrates why performance profiles are valuable: they reveal the **full spectrum of performance** (efficiency, robustness, scalability) in a single plot, enabling informed decisions based on your specific requirements.

---

## Interpreting Performance Profiles

### Visual Elements

A typical performance profile plot shows:

- **X-axis**: Performance ratio $\tau$ (log scale, base 2)
  - Values like 1, 2, 4, 10, 50, 100
  - Factor by which a solver is slower than the best

- **Y-axis**: Proportion of solved instances $\rho_s(\tau)$ (linear scale, 0 to 1)
  - Displayed as percentages: 0%, 10%, ..., 100%

- **Curves**: One curve per solver-model combination
  - Each curve is piecewise constant and non-decreasing
  - Markers help distinguish curves

### Reading the Plot

#### At $\tau = 1$ (leftmost point)

The height of a curve at $\tau = 1$ indicates **the proportion of instances where that solver-model was the fastest**.

Example:

- If `(JuMP, Ipopt)` has $\rho(\tau=1) = 0.6$, it means JuMP+Ipopt was the fastest on 60% of instances

#### At intermediate $\tau$

The height at $\tau = 2$ indicates **the proportion of instances where that solver-model was within a factor 2 of the best**.

Example:

- If `(ADNLPModels, Ipopt)` has $\rho(\tau=2) = 0.8$, it means ADNLPModels+Ipopt solved 80% of instances within twice the time of the best solver

#### Plateau (rightmost part)

The plateau represents **the proportion of instances successfully solved** by that solver-model, regardless of performance.

Example:

- If `(ExaModels, MadNLP)` plateaus at 0.95, it means ExaModels+MadNLP solved 95% of all instances (but failed on 5%)

### Common Patterns

#### Pattern 1: Clear Winner

```text
Solver A: ρ(1) = 1.0, plateau at 1.0
Solver B: ρ(1) = 0.0, plateau at 1.0
```

Solver A was faster on all problems, and both solved all problems. **Solver A is clearly preferable.**

#### Pattern 2: Fast but Not Robust

```text
Solver A: ρ(1) = 0.7, plateau at 0.75
Solver B: ρ(1) = 0.3, plateau at 1.0
```

Solver A is faster on most problems but fails on 25% of them. Solver B is slower but solves everything. **Trade-off between speed and robustness.**

#### Pattern 3: Very Small Factors

If all curves are very close and differences occur only at $\tau \approx 1.0001$, the solvers are essentially equivalent for practical purposes.

#### Pattern 4: Multiple Solvers (>2)

With more than two solvers, performance profiles do not directly establish a complete ranking. A solver may dominate when compared to the full set but not when compared pairwise to another solver[^2].

### What to Look For

When analyzing performance profiles in CTBenchmarks.jl:

1. **Robustness**: Does the curve reach 100%? If not, which problems failed?

2. **Efficiency**: How high is the curve at small $\tau$ (e.g., $\tau = 1, 2, 4$)?

3. **Consistency**: Is the curve smooth or does it have large jumps?

4. **Comparison**: Which solver-model combination dominates for your use case?
   - If you need to solve 90% of problems efficiently, look at small $\tau$
   - If you need to solve all problems, look at the plateau

---

## References

[^1]: Dolan, E. D., & Moré, J. J. (2002). Benchmarking optimization software with performance profiles. *Mathematical Programming*, 91, 201-213. [DOI: 10.1007/s101070100263](https://link.springer.com/article/10.1007/s101070100263)

[^2]: Gould, N., & Scott, J. (2016). A note on performance profiles for benchmarking software. *ACM Transactions on Mathematical Software (TOMS)*, 43(2), 1-5. [DOI: 10.1145/2950048](https://dl.acm.org/doi/abs/10.1145/2950048)

See also:

- [Performance Profile Benchmarking Tool](https://tmigot.github.io/posts/2024/06/teaching) by Tangi Migot
- Moré, J. J., & Wild, S. M. (2009). Benchmarking derivative-free optimization algorithms. *SIAM Journal on Optimization*, 20(1), 172-191. [DOI: 10.1137/080724083](https://epubs.siam.org/doi/abs/10.1137/080724083)
