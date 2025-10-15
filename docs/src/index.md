# CTBenchmarks

**CTBenchmarks.jl** is a comprehensive benchmarking suite for optimal control problems, designed to evaluate and compare the performance of different solvers and modelling approaches within the [control-toolbox ecosystem](https://github.com/control-toolbox).

This package provides:

- 🚀 Pre-configured benchmark suites for quick performance evaluation
- 📊 Automated result collection and analysis
- 🔧 Flexible API for creating custom benchmarks
- 📈 Detailed performance metrics including timing, memory usage, and solver statistics

## Installation

!!! warning "Development Package"
    CTBenchmarks.jl is not yet registered in the Julia General Registry. You must clone the repository to use it.

To install CTBenchmarks.jl, clone the repository and activate the project:

```julia
using Pkg

# Clone the repository
Pkg.develop(url="https://github.com/control-toolbox/CTBenchmarks.jl")

# Or clone manually and activate
# git clone https://github.com/control-toolbox/CTBenchmarks.jl.git
# cd CTBenchmarks.jl
# julia --project=.
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
- Discretisation: trapeze
- Solvers: Ipopt and MadNLP
- Models: JuMP, adnlp, exa, exa_gpu

#### Complete Benchmark (Comprehensive)

Run the full benchmark suite across all problems:

```julia
CTBenchmarks.run(:complete)
```

This runs 14 optimal control problems with:

- Grid sizes: 100, 200, 500
- Discretisations: trapeze, midpoint
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
CTBenchmarks.run(:minimal; outpath="my_results")
```

This creates a directory containing:

- `data.json` - Benchmark results in JSON format
- `Project.toml` - Package dependencies
- `Manifest.toml` - Complete dependency tree

## Creating Custom Benchmarks

For more control over your benchmarks, use the `CTBenchmarks.benchmark` function directly:

```julia
CTBenchmarks.benchmark(;
    outpath = "custom_benchmark",
    problems = [:beam, :chain, :robot],
    solver_models = [
        :ipopt => [:JuMP, :adnlp, :exa],
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
```

### Available Problems

CTBenchmarks includes 14 optimal control problems from [OptimalControlProblems.jl](https://control-toolbox.org/OptimalControlProblems.jl):

- `:beam` - Beam control problem
- `:chain` - Chain of masses
- `:double_oscillator` - Double oscillator
- `:ducted_fan` - Ducted fan control
- `:electric_vehicle` - Electric vehicle optimisation
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

- `:JuMP` - JuMP modelling framework
- `:adnlp` - Automatic differentiation NLP models
- `:exa` - ExaModels (CPU)
- `:exa_gpu` - ExaModels (GPU acceleration)

### Benchmark Parameters

- `grid_sizes`: Number of discretisation points (e.g., `[100, 200, 500]`)
- `disc_methods`: Discretisation schemes (`:trapeze`, `:midpoint`)
- `tol`: Solver tolerance (default: `1e-6`)
- `max_iter`: Maximum solver iterations (default: `1000`)
- `max_wall_time`: Maximum wall time in seconds (default: `500.0`)

## Benchmark Results in This Documentation

This documentation includes pre-computed benchmark results from continuous integration runs on different platforms:

- **Ubuntu Latest** - Standard CPU benchmarks on GitHub Actions runners
- **Moonshot** - GPU-accelerated benchmarks on dedicated hardware

These results provide reference performance data and demonstrate the capabilities of different solver and model combinations. You can explore them in the [Core Benchmark](benchmark-core.md) section.

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
│  │  ✓ | JuMP    :    1.234 s | obj: 1.234567e+00 | iters: 42    | CPU:    2.5 MiB
│  │  ✓ | adnlp   :    0.987 s | obj: 1.234567e+00 | iters: 42    | CPU:    2.1 MiB
│  │  ✓ | exa     :    0.765 s | obj: 1.234567e+00 | iters: 42    | CPU:    1.8 MiB
│  └─
└─
```

**Legend:**

- ✓ / ✗ - Success or failure indicator
- **Time** - Total solve time (right-aligned for easy comparison)
- **obj** - Objective function value
- **iters** - Number of solver iterations
- **Memory** - CPU memory usage (GPU memory shown separately for GPU models)

## Documentation build environment

```@setup main
using Pkg
using InteractiveUtils
using Markdown

# Download links for the benchmark environment
function _downloads_toml(DIR)
    link_manifest = joinpath("assets", DIR, "Manifest.toml")
    link_project = joinpath("assets", DIR, "Project.toml")
    return Markdown.parse("""
    You can download the exact environment used to build this documentation:
    - 📦 [Project.toml]($link_project) - Package dependencies
    - 📋 [Manifest.toml]($link_manifest) - Complete dependency tree with versions
    """)
end
```

```@example main
_downloads_toml(".") # hide
```

```@raw html
<details style="margin-bottom: 0.5em; margin-top: 1em;"><summary>ℹ️ Version info</summary>
```

```@example main
versioninfo() # hide
```

```@raw html
</details>
```

```@raw html
<details style="margin-bottom: 0.5em;"><summary>📦 Package status</summary>
```

```@example main
Pkg.status() # hide
```

```@raw html
</details>
```

```@raw html
<details style="margin-bottom: 0.5em;"><summary>📚 Complete manifest</summary>
```

```@example main
Pkg.status(; mode = PKGMODE_MANIFEST) # hide
```

```@raw html
</details>
```
