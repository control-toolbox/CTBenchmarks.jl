# Development Guidelines

This guide explains how to add a new benchmark to the CTBenchmarks.jl pipeline.

## Overview

Adding a new benchmark involves creating several components:

1. **JSON configuration entry** ⭐ *Simple* - Add benchmark config to JSON file (**1 entry to add**)
2. **Benchmark script** ⭐ *Simple* - Julia script that runs the benchmark
3. **GitHub label** ⭐ *Simple* - Label to trigger the benchmark on pull requests (manual step on GitHub)
4. **Individual workflow** ⭐ *Optional* - Workflow for manual testing (reads from JSON)
5. **Documentation page** ⭐ *Optional* - Display benchmark results in the documentation

!!! tip "Estimated Time"
    - Step 1 (JSON): ~2 minutes
    - Step 2 (Script): ~5-10 minutes
    - Step 3 (Label): ~1 minute
    - Step 4 (Optional workflow): ~5 minutes
    - Step 5 (Optional docs): ~10 minutes

!!! success "Key Improvement"
    The orchestrator now uses a **JSON configuration file** and **matrix strategy**. Adding a benchmark requires modifying only **one JSON entry** instead of multiple workflow files!

## Step-by-Step Guide

### 1. Add Configuration to JSON

Edit `.github/benchmarks-config.json` and add your benchmark configuration:

```json
{
  "benchmarks": [
    {
      "id": "your-benchmark-id",
      "julia_version": "1.11",
      "julia_arch": "x64",
      "runs_on": "ubuntu-latest",
      "runner": "github"
    }
  ]
}
```

**Configuration fields:**

- **`id`** (required): Unique identifier for the benchmark (kebab-case)
  - Convention: `{family}-{runner}` (e.g., `core-ubuntu-latest`, `core-moonshot`)
  - Used as script filename: `benchmarks/{id}.jl`
  - Used in label: `run bench {id}`
  
- **`julia_version`** (required): Julia version to use (e.g., `"1.11"`)

- **`julia_arch`** (required): Architecture (typically `"x64"`)

- **`runs_on`** (required): GitHub runner specification
  - For standard runners: `"ubuntu-latest"`
  - For self-hosted: `"[\"self-hosted\", \"Linux\", \"gpu\", \"cuda\", \"cuda12\"]"`
  
- **`runner`** (required): Runner type for caching strategy
  - `"github"` for standard GitHub runners (uses `julia-actions/cache`)
  - `"self-hosted"` for self-hosted runners (uses `actions/cache` for artifacts only)

**Examples:**

```json
// Standard GitHub runner
{
  "id": "core-ubuntu-latest",
  "julia_version": "1.11",
  "julia_arch": "x64",
  "runs_on": "ubuntu-latest",
  "runner": "github"
}

// Self-hosted GPU runner
{
  "id": "core-moonshot",
  "julia_version": "1.11",
  "julia_arch": "x64",
  "runs_on": "[\"self-hosted\", \"Linux\", \"gpu\", \"cuda\", \"cuda12\"]",
  "runner": "self-hosted"
}
```

### 2. Create the Benchmark Script

Create a new Julia script in the `benchmarks/` directory with the filename `{id}.jl`:

**Important**: The script filename must **exactly match** the `id` in the JSON configuration.

**Example**: For `"id": "core-ubuntu-latest"`, create `benchmarks/core-ubuntu-latest.jl`

```julia
using Pkg
const project_dir = normpath(@__DIR__, "..")
ENV["PROJECT"] = project_dir

Pkg.activate(project_dir)
Pkg.instantiate()

using CTBenchmarks

function main()
    outpath = joinpath(project_dir, "docs", "src", "assets", "benchmarks", "<id>")
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
- The output directory follows the pattern `docs/src/assets/benchmarks/{id}`
- **Available problems:** The list of problems you can choose is available in the [OptimalControlProblems.jl documentation](https://control-toolbox.org/OptimalControlProblems.jl/stable/problems_browser.html)

### 2. Automatic Workflow Execution

**Good news!** You don't need to create a workflow file manually. The orchestrator automatically runs your benchmark based on the JSON configuration using a matrix strategy.

When you add a label to a PR (e.g., `run bench your-benchmark-id`), the orchestrator:

1. Reads `.github/benchmarks-config.json`
2. Finds your benchmark configuration
3. Calls the reusable workflow with the correct parameters
4. Constructs the script path as `benchmarks/{id}.jl`

**Everything is automatic!** ✨

### 3. Create the GitHub Label

On GitHub, create a new label for your benchmark:

1. Go to your repository → **Issues** → **Labels**
2. Click **New label**
3. Name: `run bench {id}` where `{id}` matches your JSON configuration
   - Example: `run bench core-ubuntu-latest`
   - Example: `run bench core-moonshot`
   - **Important**: Use the exact benchmark ID from JSON
4. Choose a color and description
5. Click **Create label**

**Label types:**

1. **Individual labels** - Trigger a specific benchmark:
   - Format: `run bench {id}`
   - Example: `run bench core-moonshot`
   - Example: `run bench minimal-ubuntu-latest`

2. **Group labels** - Trigger all benchmarks with a common prefix:
   - Format: `run bench {prefix}-all`
   - Example: `run bench core-all` → runs all `core-*` benchmarks
   - Example: `run bench minimal-all` → runs all `minimal-*` benchmarks
   - Example: `run bench gpu-all` → runs all `gpu-*` benchmarks

**Naming convention for benchmark families:**

To use group labels effectively, follow this naming convention:

- `{family}-{runner}` format (e.g., `core-ubuntu-latest`, `core-moonshot`)
- All benchmarks in the same family share the same prefix
- Group label `run bench {family}-all` will run all benchmarks in that family

**Examples:**

- `core-ubuntu-latest`, `core-moonshot`, `core-mothra` → `run bench core-all`
- `minimal-ubuntu-latest`, `minimal-macos` → `run bench minimal-all`
- `gpu-cuda12`, `gpu-cuda13` → `run bench gpu-all`

### 4. (Optional) Create Individual Workflow

!!! info "Optional Step"
    Individual workflows are **optional**. The orchestrator will automatically run your benchmark based on the JSON configuration. Individual workflows are useful for:
    - Manual testing via `workflow_dispatch`
    - Running a specific benchmark without the orchestrator
    - Debugging

Create `.github/workflows/benchmark-{id}.yml`:

```yaml
name: Benchmark {Name}

on:
  workflow_call:
  workflow_dispatch:

permissions:
  contents: write
  pull-requests: write

jobs:
  load-config:
    runs-on: ubuntu-latest
    outputs:
      config: ${{ steps.get-config.outputs.config }}
    steps:
      - uses: actions/checkout@v5
      - name: Get benchmark config
        id: get-config
        run: |
          CONFIG=$(jq -c '.benchmarks[] | select(.id == "{id}")' .github/benchmarks-config.json)
          echo "config=$CONFIG" >> $GITHUB_OUTPUT
  
  bench:
    needs: load-config
    uses: ./.github/workflows/benchmark-reusable.yml
    with:
      script_path: benchmarks/${{ fromJSON(needs.load-config.outputs.config).id }}.jl
      julia_version: ${{ fromJSON(needs.load-config.outputs.config).julia_version }}
      julia_arch: ${{ fromJSON(needs.load-config.outputs.config).julia_arch }}
      runs_on: ${{ fromJSON(needs.load-config.outputs.config).runs_on }}
      runner: ${{ fromJSON(needs.load-config.outputs.config).runner }}
```

**Key features:**

- **Reads configuration from JSON** - Single source of truth
- **Uses ID to construct script path** - `benchmarks/${{ fromJSON(...).id }}.jl` ensures consistency
- **Can be triggered manually** via `workflow_dispatch` for testing
- **Can be called by orchestrator** via `workflow_call`
- **No hardcoded values** - Everything comes from JSON configuration

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

## Examples

### Example 1: Core Moonshot Benchmark (CUDA 12)

A complete GPU benchmark using CUDA 12:

- **Script**: `benchmarks/core-moonshot.jl`
- **Workflow**: `.github/workflows/benchmark-core-moonshot.yml`
- **Label**: `run bench core moonshot`
- **Runner**: `["self-hosted", "Linux", "gpu", "cuda", "cuda12"]`
- **Documentation**: `docs/src/benchmark-core.md.template`

### Example 2: Core Mothra Benchmark (CUDA 13)

A GPU benchmark identical to Moonshot but using CUDA 13 to compare performance:

- **JSON entry**: Added to `.github/benchmarks-config.json`

    ```json
    {
    "id": "core-mothra",
    "julia_version": "1.11",
    "julia_arch": "x64",
    "runs_on": "[\"self-hosted\", \"Linux\", \"gpu\", \"cuda\", \"cuda13\"]",
    "runner": "self-hosted"
    }
    ```

- **Script**: `benchmarks/core-mothra.jl`
  - Only difference: `outpath` points to `docs/src/assets/benchmarks/core-mothra`
- **Label**: `run bench core-mothra`
- **Workflow** (optional): `.github/workflows/benchmark-core-mothra.yml` reads from JSON

This example demonstrates how to create a variant of an existing benchmark to test different hardware configurations.

## How the Orchestrator Works

### Matrix Strategy

The orchestrator uses a **matrix strategy** to dynamically call benchmarks:

1. **Guard job** reads `.github/benchmarks-config.json`
2. Based on PR labels, it builds a JSON array of selected benchmarks
3. **Benchmark job** uses matrix to iterate over selected benchmarks
4. Each matrix iteration calls `benchmark-reusable.yml` with the appropriate parameters

**Benefits:**

- No need to declare individual jobs for each benchmark
- Adding a benchmark requires only JSON modification
- All benchmarks run in parallel (matrix strategy)
- Consistent behavior across all benchmarks

### Label System

The orchestrator supports two types of labels with **automatic prefix detection**:

#### Individual Labels

- **Format**: `run bench {id}`
- **Behavior**: Runs the specific benchmark with that exact ID
- **Examples**:
  - `run bench core-ubuntu-latest` → runs only `core-ubuntu-latest`
  - `run bench minimal-macos` → runs only `minimal-macos`

#### Group Labels (Generic)

- **Format**: `run bench {prefix}-all`
- **Behavior**: Automatically runs **all** benchmarks whose ID starts with `{prefix}-`
- **How it works**:
  1. The orchestrator extracts the prefix from the label (e.g., `core` from `run bench core-all`)
  2. It scans all benchmark IDs in the JSON
  3. It selects all benchmarks matching the pattern `{prefix}-*`
  
- **Examples**:
  - `run bench core-all` → runs `core-ubuntu-latest`, `core-moonshot`, `core-mothra`
  - `run bench minimal-all` → runs `minimal-ubuntu-latest`, `minimal-macos`
  - `run bench gpu-all` → runs `gpu-cuda12`, `gpu-cuda13`

#### Multiple Labels

You can combine multiple labels on a PR:

- `run bench core-all` + `run bench minimal-ubuntu-latest` → runs all `core-*` benchmarks + `minimal-ubuntu-latest`
- `run bench core-moonshot` + `run bench gpu-all` → runs `core-moonshot` + all `gpu-*` benchmarks

#### Automatic Discovery

The system is **completely generic** - no hardcoded family names:

- Add benchmarks with any prefix (e.g., `perf-*`, `stress-*`, `validation-*`)
- Create corresponding group labels (e.g., `run bench perf-all`)
- The orchestrator automatically detects and processes them

### Configuration File

The `.github/benchmarks-config.json` file is the **single source of truth**:

- Orchestrator reads it to discover available benchmarks
- Individual workflows read it to get their configuration
- Easy to maintain and validate
- Can be extended with additional metadata
