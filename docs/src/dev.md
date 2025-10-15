# Development Guidelines

This guide explains how to add a new benchmark to the CTBenchmarks.jl pipeline.

## Overview

Adding a new benchmark involves creating several interconnected components:

1. **Benchmark script** ⭐ *Simple* - Julia script that runs the benchmark
2. **GitHub Actions workflow** ⭐ *Simple* - Workflow that executes the script on a specific runner
3. **GitHub label** ⭐ *Simple* - Label to trigger the benchmark on pull requests (manual step on GitHub)
4. **Orchestrator integration** ⚠️ *Complex* - Update the orchestrator to manage the new workflow (**14 locations to modify**)
5. **Documentation page** ⭐ *Simple* (optional) - Display benchmark results in the documentation

!!! tip "Estimated Time"
    - Steps 1-3: ~10 minutes
    - Step 4 (Orchestrator): ~30-45 minutes (careful verification required)
    - Step 5: ~10 minutes

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

!!! warning "Complex Integration"
    This is the **most complex and error-prone step**. The orchestrator requires modifications in **14 different locations** throughout the file. Missing even one location will cause workflow failures. Take your time and verify each step.

Edit `.github/workflows/benchmarks-orchestrator.yml` to integrate your new benchmark. Follow these steps carefully:

#### Step 4.1: Add output in the guard job

In the `guard` job outputs section (~line 16-20):

```yaml
jobs:
  guard:
    outputs:
      run_ubuntu: ${{ steps.check.outputs.run_ubuntu }}
      run_moonshot: ${{ steps.check.outputs.run_moonshot }}
      run_<name>: ${{ steps.check.outputs.run_<name> }}  # Add this line
      benchmarks_summary: ${{ steps.check.outputs.benchmarks_summary }}
```

#### Step 4.2: Initialize the variable

In the guard job's check step, initialize the variable (~line 30-33):

```bash
# Initialize outputs
RUN_UBUNTU="false"
RUN_MOONSHOT="false"
RUN_<NAME>="false"  # Add this line
BENCHMARKS_LIST=""
```

#### Step 4.3: Update "run all" label detection

When the "run bench core all" label is detected (~line 57-64), add your benchmark:

```bash
if echo "$LABELS" | grep -q "run bench core all"; then
  echo "✅ Found 'run bench core all' label"
  RUN_UBUNTU="true"
  RUN_MOONSHOT="true"
  RUN_<NAME>="true"  # Add this line
  BENCHMARKS_LIST="ubuntu-latest, moonshot, <name>"  # Add <name> here
```

#### Step 4.4: Add specific label detection

After the moonshot label detection block (~line 68-77), add detection for your benchmark:

```bash
if echo "$LABELS" | grep -q "run bench core <name>"; then
  echo "✅ Found 'run bench core <name>' label"
  RUN_<NAME>="true"
  if [ -n "$BENCHMARKS_LIST" ]; then
    BENCHMARKS_LIST="$BENCHMARKS_LIST, <name>"
  else
    BENCHMARKS_LIST="<name>"
  fi
fi
```

#### Step 4.5: Update "no labels" condition

Update the condition that checks if no benchmarks were selected (~line 79-83):

```bash
if [ "$RUN_UBUNTU" == "false" ] && [ "$RUN_MOONSHOT" == "false" ] && [ "$RUN_<NAME>" == "false" ]; then
  echo "❌ No benchmark labels found"
  echo "ℹ️  Expected labels: 'run bench core ubuntu', 'run bench core moonshot', 'run bench core <name>', or 'run bench core all'"
  BENCHMARKS_LIST="none"
fi
```

#### Step 4.6: Set the output

Add the output for your benchmark (~line 88-91):

```bash
# Set outputs
echo "run_ubuntu=$RUN_UBUNTU" >> $GITHUB_OUTPUT
echo "run_moonshot=$RUN_MOONSHOT" >> $GITHUB_OUTPUT
echo "run_<name>=$RUN_<NAME>" >> $GITHUB_OUTPUT  # Add this line
echo "benchmarks_summary=$BENCHMARKS_LIST" >> $GITHUB_OUTPUT
```

#### Step 4.7: Update guard summary logs

In the guard decision summary step (~line 98-117), add logging for your benchmark:

```bash
RUN_UBUNTU="${{ steps.check.outputs.run_ubuntu }}"
RUN_MOONSHOT="${{ steps.check.outputs.run_moonshot }}"
RUN_<NAME>="${{ steps.check.outputs.run_<name> }}"  # Add this line
SUMMARY="${{ steps.check.outputs.benchmarks_summary }}"

if [ "$RUN_UBUNTU" == "true" ]; then
  echo "  ✅ benchmark-core-ubuntu-latest"
fi
if [ "$RUN_MOONSHOT" == "true" ]; then
  echo "  ✅ benchmark-core-moonshot"
fi
if [ "$RUN_<NAME>" == "true" ]; then  # Add this block
  echo "  ✅ benchmark-core-<name>"
fi
if [ "$RUN_UBUNTU" != "true" ] && [ "$RUN_MOONSHOT" != "true" ] && [ "$RUN_<NAME>" != "true" ]; then
  echo "  ⏭️  None (conditions not met)"
  echo ""
  echo "💡 To run benchmarks on PRs, ensure:"
  echo "   • PR targets 'main' branch"
  echo "   • PR has one of: 'run bench core ubuntu', 'run bench core moonshot', 'run bench core <name>', or 'run bench core all'"
```

#### Step 4.8: Add the benchmark job

After the existing benchmark jobs (~line 124-127), add your new job:

```yaml
benchmark-<name>:
  needs: guard
  if: needs.guard.outputs.run_<name> == 'true'
  uses: ./.github/workflows/benchmark-<name>.yml
```

#### Step 4.9: Update docs job dependencies and conditions

Update the `docs` job (~line 129-138):

```yaml
docs:
  needs: [guard, benchmark-ubuntu, benchmark-moonshot, benchmark-<name>]  # Add benchmark-<name>
  if: |
    always() &&
    (needs.guard.result == 'success') &&
    (needs.benchmark-ubuntu.result != 'cancelled') &&
    (needs.benchmark-moonshot.result != 'cancelled') &&
    (needs.benchmark-<name>.result != 'cancelled') &&  # Add this line
    (needs.benchmark-ubuntu.result != 'failure') &&
    (needs.benchmark-moonshot.result != 'failure') &&
    (needs.benchmark-<name>.result != 'failure')  # Add this line
```

#### Step 4.10: Update notify-failure job

Update the `notify-failure` job dependencies (~line 167-168):

```yaml
notify-failure:
  needs: [guard, benchmark-ubuntu, benchmark-moonshot, benchmark-<name>, docs]  # Add benchmark-<name>
```

And add failure detection in the script (~line 182-193):

```javascript
if (needs['benchmark-<name>'] && needs['benchmark-<name>'].result === 'failure') {
  console.log('❌ Benchmark <Name> job failed');
  failedJobs.push('Benchmark <Name>');
}
```

#### Step 4.11: Update notify-success job

Update the `notify-success` job dependencies and conditions (~line 229-238):

```yaml
notify-success:
  needs: [guard, benchmark-ubuntu, benchmark-moonshot, benchmark-<name>, docs]  # Add benchmark-<name>
  if: |
    always() &&
    (needs.guard.result == 'success') &&
    (needs.docs.result == 'success') &&
    (needs.benchmark-ubuntu.result != 'cancelled') &&
    (needs.benchmark-moonshot.result != 'cancelled') &&
    (needs.benchmark-<name>.result != 'cancelled') &&  # Add this line
    (needs.benchmark-ubuntu.result != 'failure') &&
    (needs.benchmark-moonshot.result != 'failure') &&
    (needs.benchmark-<name>.result != 'failure')  # Add this line
```

#### Step 4.12: Update workflow-summary job

Update the `workflow-summary` job dependencies (~line 317-318):

```yaml
workflow-summary:
  needs: [guard, benchmark-ubuntu, benchmark-moonshot, benchmark-<name>, docs]  # Add benchmark-<name>
```

And add summary logging (~line 340-346):

```bash
if [ "${{ needs.benchmark-<name>.result }}" == "success" ]; then
  echo "📊 Benchmark <Name>: ✅ SUCCESS"
elif [ "${{ needs.benchmark-<name>.result }}" == "failure" ]; then
  echo "📊 Benchmark <Name>: ❌ FAILED"
elif [ "${{ needs.benchmark-<name>.result }}" == "skipped" ]; then
  echo "📊 Benchmark <Name>: ⏭️  SKIPPED"
fi
```

#### Step 4.13: Update overall status check

Update the overall status condition (~line 362-365):

```bash
overall_status="✅ SUCCESS"
if [ "${{ needs.benchmark-ubuntu.result }}" == "failure" ] || 
   [ "${{ needs.benchmark-moonshot.result }}" == "failure" ] || 
   [ "${{ needs.benchmark-<name>.result }}" == "failure" ] ||  # Add this line
   [ "${{ needs.docs.result }}" == "failure" ]; then
  overall_status="❌ FAILED"
fi
```

#### Verification Checklist

Before committing your changes, verify that you have updated **all 14 locations**:

- [ ] **Step 4.1**: Guard job outputs (add `run_<name>`)
- [ ] **Step 4.2**: Variable initialization (add `RUN_<NAME>="false"`)
- [ ] **Step 4.3**: "Run all" label detection (add `RUN_<NAME>="true"` and update `BENCHMARKS_LIST`)
- [ ] **Step 4.4**: Specific label detection (add new `if` block for your label)
- [ ] **Step 4.5**: No labels condition (add `RUN_<NAME>` check and update message)
- [ ] **Step 4.6**: Set outputs (add `echo "run_<name>=$RUN_<NAME>"`)
- [ ] **Step 4.7**: Guard summary logs (add `RUN_<NAME>` variable and logging block)
- [ ] **Step 4.8**: New benchmark job (add complete job definition)
- [ ] **Step 4.9**: Docs job (add to `needs` list and two condition lines)
- [ ] **Step 4.10**: Notify-failure job (add to `needs` list and failure detection)
- [ ] **Step 4.11**: Notify-success job (add to `needs` list and two condition lines)
- [ ] **Step 4.12**: Workflow-summary job (add to `needs` list and logging block)
- [ ] **Step 4.13**: Overall status check (add to failure condition)

**Tip:** Use `grep -n "<name>" .github/workflows/benchmarks-orchestrator.yml` to verify all occurrences of your benchmark name are present.

**Important:** All these modifications must be done consistently. Missing even one location can cause the workflow to fail or behave unexpectedly.

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

- **Script**: `scripts/benchmark-core-moonshot.jl`
- **Workflow**: `.github/workflows/benchmark-core-moonshot.yml`
- **Label**: `run bench core moonshot`
- **Runner**: `["self-hosted", "Linux", "gpu", "cuda", "cuda12"]`
- **Documentation**: `docs/src/benchmark-core.md.template`

### Example 2: Core Mothra Benchmark (CUDA 13)

A GPU benchmark identical to Moonshot but using CUDA 13 to compare performance:

- **Script**: `scripts/benchmark-core-mothra.jl`
  - Only difference: `outpath` points to `benchmark-core-mothra`
- **Workflow**: `.github/workflows/benchmark-core-mothra.yml`
  - Only difference: `runs_on: '["self-hosted", "Linux", "gpu", "cuda", "cuda13"]'`
- **Label**: `run bench core mothra`
- **Runner**: `["self-hosted", "Linux", "gpu", "cuda", "cuda13"]`
- **Orchestrator**: Updated in 14 locations to integrate mothra

This example demonstrates how to create a variant of an existing benchmark to test different hardware configurations.
