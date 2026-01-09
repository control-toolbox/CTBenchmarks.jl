# Development Guidelines

This guide explains how to add a new benchmark to the CTBenchmarks.jl pipeline.

!!! note
    This page focuses on the CI and configuration aspects of benchmarks. For a
    detailed explanation of how documentation pages are generated from
    templates (including `INCLUDE_ENVIRONMENT`, `PROFILE_PLOT`,
    `PROFILE_ANALYSIS`, `INCLUDE_FIGURE`, `INCLUDE_TEXT`, and `@setup BENCH` blocks), see the
    [Documentation Generation Process](@ref documentation-process).

## Overview

Adding a new benchmark involves creating several components:

| Step | Description | Status |
| --- | --- | --- |
| [**Benchmark script**](@ref benchmark-script) | Julia script that runs the benchmark | Required |
| [**JSON configuration**](@ref json-config) | Add benchmark config to JSON file | Required |
| [**GitHub label**](@ref github-label) | Label to trigger the benchmark on pull requests | Required |
| [**Individual workflow**](@ref individual-workflow) | Workflow for manual testing (reads from JSON) | Optional |
| [**Documentation page**](@ref documentation-page) | Display benchmark results in the documentation | Optional |
| [**Performance profile**](@ref performance-profile) | Define custom performance criteria in registry | Optional |

## Step-by-Step Guide

### [1. Create the Benchmark Script](@id benchmark-script)

Create a new Julia script in the `benchmarks/` directory. Choose a descriptive filename that will serve as your benchmark identifier.

**Naming convention**: Use kebab-case (e.g., `core-ubuntu-latest.jl`, `core-moonshot-gpu.jl`)

**Example**: `benchmarks/core-ubuntu-latest.jl`

```julia
# Benchmark script for <id>
# Setup (Pkg.activate, instantiate, update, using CTBenchmarks) is handled by the workflow

function run()
    results = CTBenchmarks.benchmark(;
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
    println("✅ Benchmark completed successfully!")
    return results
end
```

**Key points:**

- **Setup code is handled by the workflow** - No need to include `using Pkg`, `Pkg.activate()`, `Pkg.instantiate()`, `Pkg.update()`, or `using CTBenchmarks` in your script. The GitHub Actions workflow handles all environment setup automatically.
- **All parameters are required** - the `benchmark` function has no optional arguments
- **Define a `run()` function** - it must take no arguments, return the `Dict` payload from `CTBenchmarks.benchmark`, and should not perform any file I/O
- The workflow calls `run()`, saves the returned payload as `{id}.json`, and stores it under `docs/src/assets/benchmarks/{id}/`
- **TOML files are copied by the workflow** - `Project.toml` and `Manifest.toml` are automatically copied to the output directory by the GitHub Actions workflow to ensure reproducibility
- **Available problems:** The list of problems you can choose is available in the [OptimalControlProblems.jl documentation](https://control-toolbox.org/OptimalControlProblems.jl/stable/problems_browser.html)
- **For local testing:** See `benchmarks/local.jl` for an example that includes the setup code needed to run benchmarks locally

### [2. Add Configuration to JSON](@id json-config)

Edit `benchmarks/benchmarks-config.json` and add your benchmark configuration:

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
  - **Must exactly match your script filename** (without the `.jl` extension)
  - Convention: `{family}-{runner}` (e.g., `core-ubuntu-latest`, `core-moonshot`)
  - Example: if your script is `benchmarks/core-ubuntu-latest.jl`, use `"id": "core-ubuntu-latest"`
  - Used in label: `run bench {id}`
  
- **`julia_version`** (required): Julia version to use (e.g., `"1.11"`)

- **`julia_arch`** (required): Architecture (typically `"x64"`)

- **`runs_on`** (required): GitHub runner specification
  - For standard runners: `"ubuntu-latest"`
  - For self-hosted runners with custom labels: `"[\"moonshot\"]"` or `"[\"mothra\"]"` (use the runner label configured in your self-hosted runner)`
  
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

// Self-hosted runner with custom label
{
  "id": "core-moonshot",
  "julia_version": "1.11",
  "julia_arch": "x64",
  "runs_on": "[\"moonshot\"]",
  "runner": "self-hosted"
}
```

Conceptually, each JSON entry is mapped directly to the inputs of the
reusable workflow:

```text
benchmarks-config.json
   └─ for each {id, julia_version, julia_arch, runs_on, runner}
        └─ orchestrator matrix entry
             └─ benchmark-reusable.yml inputs:
                  script_path  = benchmarks/{id}.jl
                  julia_version
                  julia_arch
                  runs_on
                  runner
```

**Good news!** You don't need to create a workflow file manually. The orchestrator automatically runs your benchmark based on the JSON configuration using a matrix strategy.

When you add a label to a PR (e.g., `run bench your-benchmark-id`), the orchestrator:

1. Reads `benchmarks/benchmarks-config.json`
2. Finds your benchmark configuration by matching the label with the `id` field
3. Calls the reusable workflow with the parameters from the JSON (Julia version, architecture, runner, etc.)
4. The reusable workflow loads and executes your script at `benchmarks/{id}.jl`
5. Results are saved to `docs/src/assets/benchmarks/{id}/{id}.json`

**Everything is automatic!** ✨

The full CI/data flow is:

```text
GitHub label on PR: "run bench {id}" or "run bench {prefix}-all"
   └─ Orchestrator workflow (benchmarks-orchestrator.yml)
        ├─ Guard job:
        │    ├─ read benchmarks/benchmarks-config.json
        │    └─ build JSON matrix of selected benchmarks
        ├─ Benchmark job (matrix over selected benchmarks)
        │    └─ calls benchmark-reusable.yml with
        │         script_path = benchmarks/{id}.jl
        │         julia_version, julia_arch, runs_on, runner
        │         └─ run Julia script → run() → results Dict
        │              └─ save {id}.json + TOML + script under docs/src/assets/benchmarks/{id}/
        └─ Docs job
             └─ include("docs/make.jl")
                  └─ build & deploy docs using latest JSON results
```

### [3. Create the GitHub Label](@id github-label)

On GitHub, create a new label for your benchmark:

1. Go to your repository → **Issues** → **Labels**
2. Click **New label**
3. Name: `run bench {id}` where `{id}` matches your JSON configuration
   - Example: `run bench core-ubuntu-latest`
   - Example: `run bench core-moonshot-gpu`
   - **Important**: Use the exact benchmark ID from JSON
4. Choose a color and description
5. Click **Create label**

**Label types:**

1. **Individual labels** - Trigger a specific benchmark:
   - Format: `run bench {id}`
   - Example: `run bench core-moonshot-gpu`
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

- `core-ubuntu-latest`, `core-moonshot-gpu`, `core-mothra-gpu` → `run bench core-all`
- `minimal-ubuntu-latest`, `minimal-moonshot-gpu`, `minimal-mothra-gpu` → `run bench minimal-all`
- `gpu-cuda12`, `gpu-cuda13` → `run bench gpu-all`

### [4. (Optional) Create Individual Workflow](@id individual-workflow)

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
          CONFIG=$(jq -c '.benchmarks[] | select(.id == "{id}")' benchmarks/benchmarks-config.json)
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

### [5. (Optional) Create Documentation Page](@id documentation-page)

If you want to display results in the documentation, you can create a
template file (for example `docs/src/core/cpu.md.template` for a family of
benchmarks, or `docs/src/benchmark-<name>.md.template` for a single
benchmark) and let the documentation pipeline generate the final `.md` page.

At a high level, a benchmark documentation page:

- Defines a single `@setup BENCH` block that includes `utils.jl`.
- Uses `INCLUDE_ENVIRONMENT` blocks to display environment and configuration
  information based on the benchmark ID.
- Uses `PROFILE_PLOT` blocks to generate performance profiles (clickable SVG + PDF).
- Uses `PROFILE_ANALYSIS` blocks to insert performance-profile textual summaries.
- Uses `INCLUDE_FIGURE` blocks for other generic figures.
- Uses `INCLUDE_TEXT` blocks for other generic analysis or tables.
- Uses `@example BENCH` blocks with `_print_benchmark_log("<id>")` to show
  detailed results.

For a concrete template example and a full description of how these blocks are
processed, see the [Documentation Generation Process](@ref documentation-process).

### [6. (Optional) Add a Performance Profile](@id performance-profile)

Performance profiles are used to compare the relative efficiency of different solver–model combinations. While the default profiles (CPU time and Iterations) are automatically available, you can register custom profiles in the `PROFILE_REGISTRY`.

A profile is defined by a `PerformanceProfileConfig` which specifies:

- **Instance columns**: Columns identifying a problem instance (e.g., `[:problem, :grid_size]`).
- **Success criteria**: A function that determines if a run was successful.
- **Metric criterion**: What value to compare (e.g., CPU time, cost error) and how to compare them (usually "smaller is better").
- **Aggregation**: How to handle multiple runs of the same instance (e.g., taking the mean).

#### Registering a Custom Profile

To add a new profile, you can register it in `docs/src/docutils/ProfileRegistry.jl` or directly in a `@setup` block in your template.

**Example**: Registering a profile based on objective value error.

```julia
using CTBenchmarks
using Statistics

# Define the criterion (Objective error)
obj_criterion = PerformanceProfileCriterion{Float64}(
    "Objective Error",
    row -> abs(row.objective - row.reference_objective),
    (a, b) -> a <= b
)

# Create the configuration
obj_config = PerformanceProfileConfig{Float64}(
    [:problem, :grid_size],
    [:model, :solver],
    obj_criterion,
    row -> row.success == true,
    xs -> Statistics.mean(skipmissing(xs))
)

# Register it
CTBenchmarks.register!(PROFILE_REGISTRY, "objective_error", obj_config)
```

#### Using the Custom Profile in Templates

Once registered, you can use the specialized `PROFILE_PLOT` and `PROFILE_ANALYSIS` blocks in your documentation templates. This is the **preferred syntax** as it is more declarative and simplifies the workflow:

```markdown
<!-- PROFILE_PLOT:
NAME = objective_error
BENCH_ID = core-ubuntu-latest
-->

<!-- PROFILE_ANALYSIS:
NAME = objective_error
BENCH_ID = core-ubuntu-latest
-->
```

You can also restrict the analysis to a specific subset of solver–model combinations using the `COMBOS` parameter:

```markdown
<!-- PROFILE_PLOT:
NAME = objective_error
BENCH_ID = core-ubuntu-latest
COMBOS = exa:madnlp, exa:ipopt
-->
```

## Testing Your Benchmark

1. **Local testing:** Run your script locally to verify it works
2. **Push changes:** Commit and push all files
3. **Create PR:** Open a pull request
4. **Add label:** Add the `run bench <name>` label to trigger the workflow
5. **Monitor:** Check the Actions tab to monitor execution

## Troubleshooting

**Cache issues on self-hosted runners:**

- Ensure `"runner": "self-hosted"` is set in your JSON configuration
- The reusable workflow uses `actions/cache` for artifacts only on self-hosted runners
- Standard GitHub runners should use `"runner": "github"` to enable full package caching

**Workflow not triggering:**

- Verify the label name matches exactly: `run bench {id}` where `{id}` is from your JSON
- Check that your benchmark ID exists in `benchmarks/benchmarks-config.json`
- Ensure the benchmark script file exists at `benchmarks/{id}.jl`

**Benchmark script fails:**

- Check Julia version compatibility
- Verify all dependencies are available on the target runner
- Review the benchmark function parameters

## Examples

### Example 1: Standard GitHub Runner

A CPU benchmark running on GitHub Actions:

**JSON configuration:**

```json
{
  "id": "core-ubuntu-latest",
  "julia_version": "1.11",
  "julia_arch": "x64",
  "runs_on": "\"ubuntu-latest\"",
  "runner": "github"
}
```

**Files:**

- **Script**: `benchmarks/core-ubuntu-latest.jl`
- **Label**: `run bench core-ubuntu-latest`
- **Documentation**: `docs/src/benchmark-core.md.template`

### Example 2: Self-Hosted Runner (Moonshot)

A GPU benchmark on a self-hosted runner with custom label:

**JSON configuration:**

```json
{
  "id": "core-moonshot-gpu",
  "julia_version": "1.11",
  "julia_arch": "x64",
  "runs_on": "[\"moonshot\"]",
  "runner": "self-hosted"
}
```

**Files:**

- **Script**: `benchmarks/core-moonshot-gpu.jl`
- **Label**: `run bench core-moonshot-gpu`

**Key points:**

- Uses simplified runner label `["moonshot"]` instead of full system labels
- The `runner: "self-hosted"` field tells the workflow to use artifact-only caching

### Example 3: Multiple Runners, Same Hardware

You can create CPU and GPU variants for the same hardware:

**CPU variant:**

```json
{
  "id": "core-moonshot-cpu",
  "julia_version": "1.11",
  "julia_arch": "x64",
  "runs_on": "[\"moonshot\"]",
  "runner": "self-hosted"
}
```

**GPU variant:**

```json
{
  "id": "core-moonshot-gpu",
  "julia_version": "1.11",
  "julia_arch": "x64",
  "runs_on": "[\"moonshot\"]",
  "runner": "self-hosted"
}
```

Both use the same runner label but different benchmark scripts with different solver configurations.

## How the Orchestrator Works

### Matrix Strategy

The orchestrator uses a **matrix strategy** to dynamically call benchmarks:

1. **Guard job** reads `benchmarks/benchmarks-config.json`
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
  - `run bench core-all` → runs `core-ubuntu-latest`, `core-moonshot-cpu`, `core-moonshot-gpu`, `core-mothra-gpu`
  - `run bench minimal-all` → runs all benchmarks starting with `minimal-`

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

The `benchmarks/benchmarks-config.json` file is the **single source of truth**:

- Orchestrator reads it to discover available benchmarks
- Individual workflows read it to get their configuration
- Easy to maintain and validate
- Can be extended with additional metadata
