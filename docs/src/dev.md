# Development Guidelines

This guide explains how to add a new benchmark to the CTBenchmarks.jl pipeline.

## Overview

Adding a new benchmark involves creating several interconnected components:

1. **Benchmark script** - Julia script that runs the benchmark
2. **GitHub Actions workflow** - Workflow that executes the script on a specific runner
3. **GitHub label** - Label to trigger the benchmark on pull requests
4. **Orchestrator integration** - Update the orchestrator to manage the new workflow
5. **Documentation page** (optional) - Display benchmark results in the documentation

## Step-by-Step Guide

### 1. Create the Benchmark Script

Create a new Julia script in `scripts/benchmark-<name>.jl`:

```julia
using Pkg
const project_dir = normpath(@__DIR__, "..")
ENV["PROJECT"] = project_dir

Pkg.activate(project_dir)
Pkg.instantiate()

using CTBenchmarks

function main()
    outpath = joinpath(project_dir, "docs", "src", "assets", "benchmark-<name>")
    CTBenchmarks.benchmark(;
        outpath = outpath,
        problems = [:problem1, :problem2, ...],
        solver_models = [:solver => [:model1, :model2]],
        grid_sizes = [100, 500, 1000],
        disc_methods = [:trapeze],
        tol = 1e-6,
        ipopt_mu_strategy = "adaptive",
        print_trace = false,
        max_iter = 1000,
        max_wall_time = 500.0
    )
    return outpath
end

main()
```

**Key points:**

- **All parameters are required** - the `benchmark` function has no optional arguments
- **The `main()` function is crucial** - it must:
  - Take no arguments
  - Return the output path where files are saved
- The `benchmark` function generates JSON and TOML files in the specified `outpath`
- Print statements (like `println("📦 Activating...")`) are optional but helpful for debugging
- The output directory follows the pattern `docs/src/assets/benchmark-<name>`
- **Available problems:** The list of problems you can choose is available in the [OptimalControlProblems.jl documentation](https://control-toolbox.org/OptimalControlProblems.jl/stable/problems_browser.html)

### 2. Create the GitHub Actions Workflow

Create `.github/workflows/benchmark-<name>.yml`:

```yaml
name: Benchmark <Name>

on:
  workflow_call:

permissions:
  contents: write
  pull-requests: write

jobs:
  bench:
    uses: ./.github/workflows/benchmark-reusable.yml
    with:
      script_path: scripts/benchmark-<name>.jl
      julia_version: '1.11'
      julia_arch: x64
      runs_on: '<runner-specification>'
      runner: '<runner-type>'  # Only for self-hosted runners
```

**Runner configuration:**

For **standard GitHub runners** (e.g., ubuntu-latest):

```yaml
runs_on: '"ubuntu-latest"'
# Do NOT include the 'runner' parameter
```

For **self-hosted runners** (e.g., GPU machines):

```yaml
runs_on: '["self-hosted", "Linux", "gpu", "cuda", "cuda12"]'
runner: 'self-hosted'
```

**All inputs are required except `runner`:**

- `script_path`: Path to your benchmark script
- `julia_version`: Julia version to use (e.g., '1.11')
- `julia_arch`: Architecture (typically 'x64')
- `runs_on`: Runner specification (string or JSON array)
- `runner`: **Optional** - Only set to `'self-hosted'` for self-hosted runners

### Understanding Cache Management

The `runner` parameter controls the caching strategy:

**Standard runners** (omit `runner` parameter):

- Uses `julia-actions/cache@v2`
- Caches Julia artifacts, packages, AND registries
- Cache stored on GitHub servers and restored on each run
- Optimal for ephemeral runners that start fresh each time

**Self-hosted runners** (`runner: 'self-hosted'`):

- Uses `actions/cache@v4` for artifacts only (`~/.julia/artifacts`)
- Packages and registries persist naturally on the machine between runs
- Avoids unnecessary upload/download to GitHub servers
- More efficient since dependencies are already local

**Why this matters:** Self-hosted runners maintain their filesystem between runs. Using `julia-actions/cache` would wastefully upload/download gigabytes of data to/from GitHub when the files are already on the machine. We only cache artifacts to avoid re-downloading external dependencies.

### 3. Create the GitHub Label

On GitHub, create a new label for your benchmark:

1. Go to your repository → **Issues** → **Labels**
2. Click **New label**
3. Name: `run bench <name>` (e.g., `run bench core moonshot`)
4. Choose a color and description
5. Click **Create label**

### 4. Update the Orchestrator

Edit `.github/workflows/benchmarks-orchestrator.yml` to integrate your new benchmark:

**a) Add output in the guard job:**

```yaml
jobs:
  guard:
    outputs:
      run_ubuntu: ${{ steps.check.outputs.run_ubuntu }}
      run_moonshot: ${{ steps.check.outputs.run_moonshot }}
      run_<name>: ${{ steps.check.outputs.run_<name> }}  # Add this line
```

**b) Add label detection logic:**

```bash
# In the guard job's check step
if echo "$LABELS" | grep -q "run bench <name>"; then
  echo "✅ Found 'run bench <name>' label"
  RUN_<NAME>="true"
  # Update BENCHMARKS_LIST accordingly
fi
```

**c) Set the output:**

```bash
echo "run_<name>=$RUN_<NAME>" >> $GITHUB_OUTPUT
```

**d) Add the benchmark job:**

```yaml
benchmark-<name>:
  needs: guard
  if: needs.guard.outputs.run_<name> == 'true'
  uses: ./.github/workflows/benchmark-<name>.yml
```

**e) Update dependent jobs:**

Add your benchmark to the `needs` list of downstream jobs (e.g., `docs`, `notify-failure`, `notify-success`).

### 5. Create Documentation Page (Optional)

If you want to display results in the documentation, create `docs/src/benchmark-<name>.md.template`:

````markdown
# <Name> Benchmark

```@setup BENCH_<NAME>
include(joinpath(@__DIR__, "assets", "utils.jl"))

const BENCH_DIR = "benchmark-<name>"
const BENCH_DATA = _read_benchmark_json(joinpath(@__DIR__, "assets", BENCH_DIR, "data.json"))
```

## Description

Brief description of your benchmark configuration.

**Benchmark Configuration:**

- **Solvers:** List of solvers
- **Models:** List of models
- **Grid sizes:** Discretisation points
- **Tolerance:** 1e-6
- **Limits:** Max iterations and wall time

### 🖥️ Environment

<!-- INCLUDE_ENVIRONMENT:
BENCH_DATA = BENCH_DATA
BENCH_DIR = BENCH_DIR
ENV_NAME = BENCH_<NAME>
-->

### 📊 Results

```@example BENCH_<NAME>
_print_results(BENCH_DATA) # hide
nothing # hide
```
````

Then add it to `docs/make.jl`:

```julia
pages = [
    "Introduction" => "index.md",
    "Core benchmark" => "benchmark-core.md",
    "<Name> Benchmark" => "benchmark-<name>.md",
    "API" => "api.md",
    "Development Guidelines" => "dev.md",
]
```

## Testing Your Benchmark

1. **Local testing:** Run your script locally to verify it works
2. **Push changes:** Commit and push all files
3. **Create PR:** Open a pull request
4. **Add label:** Add the `run bench <name>` label to trigger the workflow
5. **Monitor:** Check the Actions tab to monitor execution

## Troubleshooting

**Cache issues on self-hosted runners:**

- Ensure `runner: 'self-hosted'` is set in your workflow
- The reusable workflow uses `actions/cache` for artifacts only on self-hosted runners
- If you see slow cache operations on self-hosted runners, verify the `runner` parameter is set correctly
- Standard runners should NOT have the `runner` parameter (let it default to use `julia-actions/cache`)

**Workflow not triggering:**

- Verify the label name matches exactly in the orchestrator
- Check that the orchestrator's guard job includes your benchmark in outputs

**Benchmark script fails:**

- Check Julia version compatibility
- Verify all dependencies are available on the target runner
- Review the benchmark function parameters

## Example: Core Moonshot Benchmark

For a complete example, see:

- Script: `scripts/benchmark-core-moonshot.jl`
- Workflow: `.github/workflows/benchmark-core-moonshot.yml`
- Label: `run bench core moonshot`
- Documentation: `docs/src/benchmark-core.md.template`