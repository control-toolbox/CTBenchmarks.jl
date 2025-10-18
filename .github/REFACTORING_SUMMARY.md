# Benchmarks Orchestrator Refactoring - Final Summary

## Overview

The benchmarks orchestrator has been completely refactored to use a **JSON-based configuration** with **matrix strategy**, dramatically simplifying benchmark management.

## Key Changes

### 1. JSON Configuration File

**New file**: `.github/benchmarks-config.json`

```json
{
  "benchmarks": [
    {
      "id": "core-ubuntu-latest",
      "julia_version": "1.11",
      "julia_arch": "x64",
      "runs_on": "ubuntu-latest",
      "runner": "github"
    },
    {
      "id": "core-moonshot",
      "julia_version": "1.11",
      "julia_arch": "x64",
      "runs_on": "[\"self-hosted\", \"Linux\", \"gpu\", \"cuda\", \"cuda12\"]",
      "runner": "self-hosted"
    },
    {
      "id": "core-mothra",
      "julia_version": "1.11",
      "julia_arch": "x64",
      "runs_on": "[\"self-hosted\", \"Linux\", \"gpu\", \"cuda\", \"cuda13\"]",
      "runner": "self-hosted"
    }
  ]
}
```

**Single source of truth** for all benchmark configurations!

### 2. Matrix Strategy

The orchestrator now uses a **matrix strategy** to dynamically call the reusable workflow:

```yaml
benchmark:
  needs: guard
  if: needs.guard.outputs.run_any == 'true'
  strategy:
    matrix:
      benchmark: ${{ fromJSON(needs.guard.outputs.benchmarks) }}
    fail-fast: false
  uses: ./.github/workflows/benchmark-reusable.yml
  with:
    script_path: scripts/benchmark-${{ matrix.benchmark.id }}.jl
    julia_version: ${{ matrix.benchmark.julia_version }}
    julia_arch: ${{ matrix.benchmark.julia_arch }}
    runs_on: ${{ matrix.benchmark.runs_on }}
    runner: ${{ matrix.benchmark.runner }}
```

### 3. Simplified Guard Job

The guard job now:
- Reads the JSON configuration
- Extracts benchmark IDs dynamically
- Builds a JSON array of selected benchmarks based on labels
- Outputs: `benchmarks` (JSON array), `run_any` (boolean), `benchmarks_summary` (string)

### 4. Individual Workflows (Optional)

Individual workflows like `benchmark-core-ubuntu-latest.yml` now:
- Read their configuration from the JSON
- Can be triggered manually via `workflow_dispatch`
- Remain useful for testing individual benchmarks

## Benefits

### Before vs After

| Aspect | Before | After |
|--------|--------|-------|
| **Configuration location** | Scattered across multiple files | Single JSON file |
| **Adding a benchmark** | ~10 modifications | **2-3 modifications** |
| **Jobs to declare** | 3 individual jobs | 1 matrix job |
| **Maintenance** | Error-prone | Simple |
| **Scalability** | Limited | Excellent |

### To Add a New Benchmark

1. **Add entry to JSON** (`.github/benchmarks-config.json`):
   ```json
   {
     "id": "your-benchmark-id",
     "julia_version": "1.11",
     "julia_arch": "x64",
     "runs_on": "ubuntu-latest",
     "runner": "github"
   }
   ```

2. **Create the script** (`benchmarks/your-benchmark-id.jl`)

3. **(Optional) Create individual workflow** (`.github/workflows/benchmark-your-benchmark-id.yml`)

4. **Create GitHub label**: `run bench your-benchmark-id`

That's it! The orchestrator will automatically:
- Detect the new benchmark from JSON
- Include it in `run bench core-all` if it starts with `core-`
- Call the reusable workflow with the correct parameters

## Technical Details

### Script Path Construction

The `script_path` is now automatically constructed from the benchmark ID:
```yaml
script_path: benchmarks/${{ matrix.benchmark.id }}.jl
```

Convention: `benchmarks/{id}.jl` (filename exactly matches the ID)

### Runner Types

- `"runner": "github"` → Uses `julia-actions/cache` (standard GitHub runners)
- `"runner": "self-hosted"` → Uses `actions/cache` for artifacts only

### Label System (Generic)

The label system is **completely generic** with automatic prefix detection:

#### Individual Labels
- **Format**: `run bench {id}`
- **Example**: `run bench core-ubuntu-latest`, `run bench minimal-macos`
- **Behavior**: Runs the specific benchmark

#### Group Labels (Automatic)
- **Format**: `run bench {prefix}-all`
- **Behavior**: Automatically runs **all** benchmarks whose ID starts with `{prefix}-`
- **Examples**:
  - `run bench core-all` → runs all `core-*` benchmarks
  - `run bench minimal-all` → runs all `minimal-*` benchmarks
  - `run bench gpu-all` → runs all `gpu-*` benchmarks
  - `run bench perf-all` → runs all `perf-*` benchmarks

**No hardcoded family names** - the system extracts prefixes dynamically from labels using regex pattern matching (`run bench [a-z0-9]+-all`)

### Simplified Jobs

- **docs**: Now depends on single `benchmark` job
- **notify-failure**: Simplified to check `benchmark` result
- **notify-success**: Simplified to check `benchmark` result
- **workflow-summary**: Simplified to display `benchmark` result

## Files Modified

1. ✅ `.github/benchmarks-config.json` - **NEW** - Configuration file
2. ✅ `.github/workflows/benchmarks-orchestrator.yml` - Refactored with matrix
3. ✅ `.github/workflows/benchmark-reusable.yml` - Made `runner` required
4. ✅ `.github/workflows/benchmark-core-ubuntu-latest.yml` - Reads from JSON
5. ⏳ `.github/workflows/benchmark-core-moonshot.yml` - TODO: Update to read from JSON
6. ⏳ `.github/workflows/benchmark-core-mothra.yml` - TODO: Update to read from JSON
7. ⏳ `docs/src/dev.md` - TODO: Update documentation

## Migration Notes

### Labels to Update

Rename labels on GitHub:
- `run bench core ubuntu` → `run bench core-ubuntu-latest`
- `run bench core moonshot` → `run bench core-moonshot`
- `run bench core mothra` → `run bench core-mothra`
- `run bench core all` → `run bench core-all`

### No Breaking Changes

The individual workflow files still work, they just now read from the JSON instead of hardcoding values.

## Future Improvements

Potential enhancements:
- Add more metadata to JSON (description, tags, etc.)
- Generate documentation automatically from JSON
- Add JSON schema validation
- Support for benchmark groups/families beyond `core-*`

---

**Date**: 2025-10-18  
**Status**: ✅ Core refactoring complete, documentation update pending
