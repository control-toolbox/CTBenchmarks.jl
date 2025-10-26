# 🎯 Action Plan: PR #76 - [General] Benchmark workflow

**Date**: 2025-10-26  
**PR**: #76 by @ocots | **Branch**: `75-general-benchmark-workflow` → `main`  
**State**: OPEN | **Linked Issue**: #75

---

## 📋 Overview

**Issue Summary**: Issue #75 requests refactoring the benchmark workflow to move common setup code (Pkg activation, instantiate, update) from individual benchmark scripts into the reusable GitHub workflow, and to move TOML file copying from the Julia `copy_project_files()` function to the workflow for consistency.

**PR Summary**: This PR currently contains only a cosmetic change - removing a trailing newline from `test/runtests.jl`. It does not implement any of the requirements from issue #75.

**Status**: ⚠️ **INCOMPLETE** - PR does not address issue requirements

---

## 🎯 Gap Analysis

### ✅ Completed Requirements

**None** - The PR only contains a whitespace change to the test file.

### ❌ Missing Requirements (from Issue #75)

All four action items from the issue are missing:

1. **❌ Move common setup code to reusable workflow**
   - Not addressed
   - Required: Extract lines 1-15 from benchmark scripts and add to `.github/workflows/benchmark-reusable.yml`
   - Affects: `benchmarks/core-moonshot.jl`, `benchmarks/core-mothra.jl`, `benchmarks/core-ubuntu-latest.jl`

2. **❌ Move TOML file copying to reusable workflow**
   - Not addressed
   - Required: Add TOML copying step to workflow, remove from Julia code
   - Affects: `.github/workflows/benchmark-reusable.yml`, `src/utils.jl` (line 744)

3. **❌ Update docstrings and documentation**
   - Not addressed
   - Required: Update `src/utils.jl` docstrings and `docs/src/dev.md`

4. **❌ Update tests if needed**
   - Not addressed (though the PR does touch a test file)
   - Required: Assess impact on `test/test_utils.jl`

### ➕ Additional Work Done

- Removed trailing newline from `test/runtests.jl` (cosmetic change)

---

## 🧪 Test Status

**Overall**: ⚠️ Tests not run (PR contains no functional changes)

**Details**:
- Existing tests: Not affected by current changes
- New tests added: No
- Test failures: N/A

**Note**: The only change is removing a trailing newline, which has no functional impact.

---

## 📝 Review Feedback

**Reviews**: No reviews yet

**Unresolved comments**: None

---

## 🔧 Code Quality Assessment

**Current PR Changes**:
- Only whitespace modification
- No functional code changes
- No impact on code quality

**Expected Changes** (based on issue #75):

**Julia Best Practices**:
- Will need to update docstrings for `benchmark()` function
- May need to deprecate or remove `copy_project_files()` function
- Should maintain backward compatibility considerations

**Workflow Best Practices**:
- Moving setup to workflow improves DRY principle
- Centralizing file operations improves consistency
- Need to handle `Pkg.activate()` path correctly in workflow context

---

## 📋 Proposed Action Plan

### 🔴 Critical Priority (blocking merge)

**1. Implement Action 2: Move TOML file copying to workflow**
- Why: This is the simplest change and can be done independently
- Where: `.github/workflows/benchmark-reusable.yml` (after line 154)
- Estimated effort: Small (30 minutes)
- Details:
  ```yaml
  - name: 📋 Copy TOML files to output directory
    if: steps.benchmark.outputs.benchmark_success == 'true'
    run: |
      if [ -f "$BENCHMARK_OUTPUT_FILE" ]; then
        OUTPUT_DIR=$(cat "$BENCHMARK_OUTPUT_FILE")
        echo "📋 Copying TOML files to output directory..."
        cp Project.toml "$OUTPUT_DIR/Project.toml"
        cp Manifest.toml "$OUTPUT_DIR/Manifest.toml"
        echo "✅ TOML files copied successfully"
      else
        echo "❌ ERROR: $BENCHMARK_OUTPUT_FILE not found"
        exit 1
      fi
  ```
  - Then remove `copy_project_files(outpath)` call from `src/utils.jl` line 744

**2. Implement Action 1: Move common setup code to workflow**
- Why: Core requirement, eliminates duplication across 3 scripts
- Where: `.github/workflows/benchmark-reusable.yml` (lines 117-128)
- Estimated effort: Medium (1-2 hours)
- Details:
  - Replace current workflow step with:
  ```yaml
  - name: Run benchmark script
    id: benchmark
    env:
      SCRIPT_PATH: ${{ env.SCRIPT_PATH }}
    run: |
      echo "🚀 Starting benchmark execution..."
      
      julia --color=yes -e '
        using Pkg
        
        println("📦 Activating project environment...")
        Pkg.activate(".")
        
        println("📥 Installing dependencies...")
        Pkg.instantiate()
        
        println("🔄 Updating dependencies...")
        Pkg.update()
        
        println("🔄 Loading CTBenchmarks package...")
        using CTBenchmarks
        
        include(ENV["SCRIPT_PATH"])
        out = main()
        println("📄 Output file: ", out)
        open(ENV["BENCHMARK_OUTPUT_FILE"], "w") do f
          write(f, string(out))
        end
        println("💾 Output path saved to ", ENV["BENCHMARK_OUTPUT_FILE"])
      '
  ```
  - Then update all 3 benchmark scripts to remove lines 1-15
  - Keep only the `main()` function and its call

**3. Fix `benchmark()` return value**
- Why: Current function returns `nothing` but workflow expects `outpath`
- Where: `src/utils.jl` line 749
- Estimated effort: Small (5 minutes)
- Details:
  ```julia
  return outpath  # Instead of: return nothing
  ```

### 🟡 High Priority (should do before merge)

**4. Update docstrings**
- Why: Changes to `benchmark()` function behavior require documentation updates
- Where: `src/utils.jl` lines 651-698
- Estimated effort: Small (15 minutes)
- Details:
  - Update docstring to note that TOML copying is now handled by workflow (when run in CI)
  - Update return value documentation to reflect `outpath` return
  - Note that `copy_project_files()` is deprecated or internal-only

**5. Update development documentation**
- Why: Developers need to know about new workflow structure
- Where: `docs/src/dev.md`
- Estimated effort: Medium (30-45 minutes)
- Details:
  - Update Step 2 (Create the Benchmark Script) section
  - Remove setup code from example (lines 94-102)
  - Explain that setup is now handled by workflow
  - Update local testing instructions
  - Document that `main()` should return `outpath`

**6. Decide on `copy_project_files()` function**
- Why: Function may become obsolete
- Where: `src/utils.jl` lines 636-645
- Estimated effort: Small (15 minutes)
- Details:
  - Search codebase for other uses: `grep -r "copy_project_files" --include="*.jl" .`
  - If only used in `benchmark()`, consider:
    - Option A: Remove entirely
    - Option B: Mark as deprecated with `@deprecate`
    - Option C: Keep as internal function for local testing
  - Document decision in code comments

### 🟢 Medium Priority (nice to have before merge)

**7. Update local testing workflow**
- Why: After removing setup from scripts, local testing needs clarification
- Where: `benchmarks/local.jl` or new helper
- Estimated effort: Medium (30 minutes)
- Details:
  - Update `benchmarks/local.jl` to show how to run benchmarks locally
  - Or create a helper function that wraps benchmark scripts with setup
  - Document in `docs/src/dev.md` under "Testing Your Benchmark"

**8. Review and update tests**
- Why: Ensure changes don't break existing tests
- Where: `test/test_utils.jl`
- Estimated effort: Small (20 minutes)
- Details:
  - Current tests don't test file I/O operations extensively
  - May not need changes since tests call `benchmark_data()` directly
  - Consider adding test for `benchmark()` return value
  - Verify tests still pass after changes

**9. Remove cosmetic change**
- Why: The trailing newline removal is unrelated to issue #75
- Where: `test/runtests.jl`
- Estimated effort: Trivial (1 minute)
- Details:
  - Revert the newline change or keep it (doesn't matter functionally)
  - If keeping, add to commit message that it's a style fix

### 🔵 Low Priority (can defer)

**10. Add workflow validation**
- Why: Ensure TOML files copied match repo root versions
- Where: `.github/workflows/benchmark-reusable.yml`
- Estimated effort: Small (15 minutes)
- Details:
  - Add checksum validation after copying TOML files
  - Verify they match the repo root versions

---

## 🚨 Blockers & Questions

### 🛑 Critical Decisions Needed

**1. Path handling for `Pkg.activate()`**
- **Issue**: Benchmark scripts use `Pkg.activate(normpath(@__DIR__, ".."))` to activate project root
- **Workflow context**: Workflow runs from repo root, so `Pkg.activate(".")` should work
- **Question**: Should we test this works correctly before proceeding?
- **Recommendation**: Test in workflow first, verify it activates the correct environment

**2. Local testing strategy**
- **Issue**: After removing setup code from benchmark scripts, how do developers run them locally?
- **Options**:
  - A: Update `benchmarks/local.jl` as a wrapper with setup
  - B: Document manual setup steps in README
  - C: Create a `run_benchmark_local()` helper function
- **Question**: Which approach do you prefer?
- **Recommendation**: Option A (update local.jl) - simplest for developers

**3. Backward compatibility for `copy_project_files()`**
- **Issue**: Unknown if function is used elsewhere
- **Action needed**: Search codebase first
- **Question**: If only used in `benchmark()`, should we remove or deprecate?
- **Recommendation**: Remove if unused elsewhere, keep code simple

---

## 📊 Summary

**Current State**: PR contains only a cosmetic whitespace change and does not implement any requirements from issue #75.

**Work Required**: Significant - all 4 action items from the issue need implementation.

**Estimated Total Effort**: 4-6 hours
- Critical actions: 2-3 hours
- High priority: 1.5 hours
- Medium priority: 1-1.5 hours

**Recommended Approach**:
1. Start with Action 2 (TOML copying) - simplest and independent
2. Implement Action 1 (setup code) - most complex, needs testing
3. Fix return value (Action 3) - quick win
4. Update documentation (Actions 4-5)
5. Clean up and test (Actions 6-9)

**Next Steps**:
1. Confirm approach for blockers (path handling, local testing, backward compatibility)
2. Implement critical actions in order
3. Test with one benchmark script before updating all three
4. Update documentation to match implementation
5. Run full test suite to verify no regressions

---

**Status**: 🔴 **NOT READY TO MERGE** - Requires substantial implementation work  
**Recommendation**: Implement all critical and high priority actions before requesting review
