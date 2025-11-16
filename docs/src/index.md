# CTBenchmarks

**CTBenchmarks.jl** is a comprehensive benchmarking suite for optimal control problems, designed to evaluate and compare the performance of different solvers and modelling approaches within the [control-toolbox ecosystem](https://github.com/control-toolbox).

This package provides:

- 🚀 Pre-configured benchmark suites for quick performance evaluation
- 📊 Automated result collection and analysis
- 🔧 Flexible API for creating custom benchmarks
- 📈 Detailed performance metrics including timing, memory usage, and solver statistics

## Installation

CTBenchmarks.jl is registered in the Julia General Registry. Install it using the package manager:

```julia
using Pkg
Pkg.add("CTBenchmarks")
```

Or in the Julia REPL package mode (press `]`):

```julia-repl
pkg> add CTBenchmarks
```

Once installed, load the package:

```julia
using CTBenchmarks
```

## Quick Start

### Running Pre-configured Benchmarks

CTBenchmarks provides two pre-configured benchmark suites:

#### Minimal Benchmark (Fast)

Run a quick benchmark on a single problem to test your setup:

```julia
CTBenchmarks.run(:minimal)
```

This runs the `:beam` problem with:

- Grid size: 100
- Discretization: trapeze
- Solvers: Ipopt and MadNLP
- Models: JuMP, adnlp, exa, exa_gpu

#### Complete Benchmark (Comprehensive)

Run the full benchmark suite across all problems:

```julia
CTBenchmarks.run(:complete)
```

This runs 14 optimal control problems with:

- Grid sizes: 100, 200, 500
- Discretizations: trapeze, midpoint
- Solvers: Ipopt and MadNLP
- Models: JuMP, adnlp, exa, exa_gpu

!!! tip "Solver Output"
    By default, solver output is suppressed. To see detailed solver traces, use:
    ```julia
    CTBenchmarks.run(:minimal; print_trace=true)
    ```

### Saving Results

To save benchmark results to a directory:

```julia
results = CTBenchmarks.run(:minimal; filepath="my_results/minimal.json")
```

This returns the benchmark payload as a `Dict` and saves it to `my_results/minimal.json` (the
directory is created automatically if needed). The `filepath` argument is optional but, when
provided, it must end with `.json`.

- `my_results/minimal.json` – Benchmark results in JSON format

## Creating Custom Benchmarks

For more control over your benchmarks, use the `CTBenchmarks.benchmark` function directly:

```julia
results = CTBenchmarks.benchmark(;
    problems = [:beam, :chain, :robot],
    solver_models = [
        :ipopt => [:jump, :adnlp, :exa],
        :madnlp => [:exa, :exa_gpu]
    ],
    grid_sizes = [200, 500, 1000],
    disc_methods = [:trapeze],
    tol = 1e-6,
    ipopt_mu_strategy = "adaptive",
    print_trace = false,
    max_iter = 1000,
    max_wall_time = 500.0
)

CTBenchmarks.save_json(results, "path/to/custom_benchmark.json")
```

### Available Problems

CTBenchmarks includes 14 optimal control problems from [OptimalControlProblems.jl](https://control-toolbox.org/OptimalControlProblems.jl):

- `:beam` - Beam control problem
- `:chain` - Chain of masses
- `:double_oscillator` - Double oscillator
- `:ducted_fan` - Ducted fan control
- `:electric_vehicle` - Electric vehicle optimization
- `:glider` - Glider trajectory
- `:insurance` - Insurance problem
- `:jackson` - Jackson problem
- `:robbins` - Robbins problem
- `:robot` - Robot arm control
- `:rocket` - Rocket trajectory
- `:space_shuttle` - Space shuttle re-entry
- `:steering` - Steering control
- `:vanderpol` - Van der Pol oscillator

### Solver and Model Combinations

**Supported Solvers:**

- `:ipopt` - Interior Point Optimizer
- `:madnlp` - Matrix-free Augmented Lagrangian NLP solver

**Supported Models:**

- `:jump` - JuMP modelling framework
- `:adnlp` - Automatic differentiation NLP models
- `:exa` - ExaModels (CPU)
- `:exa_gpu` - ExaModels (GPU acceleration)

### Benchmark Parameters

- `grid_sizes`: Number of discretization points (e.g., `[100, 200, 500]`)
- `disc_methods`: Discretization schemes (`:trapeze`, `:midpoint`)
- `tol`: Solver tolerance (e.g., `1e-6`)
- `max_iter`: Maximum solver iterations (e.g., `1000`)
- `max_wall_time`: Maximum wall time in seconds (e.g., `500.0`)

## Benchmark Results in This Documentation

This documentation includes pre-computed benchmark results from continuous integration runs on different platforms:

- **Ubuntu Latest** - Standard CPU benchmarks on GitHub Actions runners
- **Moonshot** - GPU-accelerated benchmarks on dedicated hardware

These results provide reference performance data and demonstrate the capabilities of different solver and model combinations. You can explore them in the [Core Benchmark CPU](core/cpu.md) page.

Each benchmark result page includes:

- 📊 Performance metrics (time, memory, iterations)
- 🖥️ Environment information (Julia version, OS, hardware)
- 📜 Reproducible benchmark scripts
- 📦 Complete dependency information

## Understanding Benchmark Output

When you run a benchmark, you'll see output similar to:

```text
Benchmarks results:

┌─ problem: beam
│
├──┬ solver: ipopt, disc_method: trapeze
│  │
│  │  N : 100
│  │  ✓ | JuMP    | time:    1.234 s | iters: 42    | obj: 1.234567e+00 (min) | CPU:    2.5 MiB
│  │  ✓ | adnlp   | time:    0.987 s | iters: 42    | obj: 1.234567e+00 (min) | CPU:    2.1 MiB
│  │  ✓ | exa     | time:    0.765 s | iters: 42    | obj: 1.234567e+00 (min) | CPU:    1.8 MiB
│  └─
└─
```

**Legend:**

- ✓ / ✗ - Success or failure indicator
- **Model** - Modelling framework (JuMP, ADNLPModels, ExaModels)
- **time** - Total solve time
- **iters** - Number of solver iterations
- **obj** - Objective function value and criterion (min or max problem)
- **Memory** - CPU memory usage (GPU memory shown separately for GPU models)

## Documentation build environment

```@setup main
using Pkg
using InteractiveUtils
using Markdown

# Download links for the benchmark environment
function _downloads_toml()
    link_manifest = joinpath("assets", "toml", "Manifest.toml")
    link_project = joinpath("assets", "toml", "Project.toml")
    return Markdown.parse("""
    You can download the exact environment used to build this documentation:
    - 📦 [Project.toml]($link_project) - Package dependencies
    - 📋 [Manifest.toml]($link_manifest) - Complete dependency tree with versions
    """)
end
```

```@example main
_downloads_toml() # hide
```

```@raw html
<details class="ct-collapse" style="margin-bottom: 0.5em; margin-top: 1em;"><summary>ℹ️ Version info</summary>
```

```@example main
versioninfo() # hide
```

```@raw html
</details>
```

```@raw html
<details class="ct-collapse" style="margin-bottom: 0.5em;"><summary>📦 Package status</summary>
```

```@example main
Pkg.status() # hide
```

```@raw html
</details>
```

```@raw html
<details class="ct-collapse" style="margin-bottom: 0.5em;"><summary>📚 Complete manifest</summary>
```

```@example main
Pkg.status(; mode = PKGMODE_MANIFEST) # hide
```

```@raw html
</details>
```
