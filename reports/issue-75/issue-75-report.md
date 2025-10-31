# 📊 Status Report: Issue #75 - [General] Benchmark workflow

**Date**: 2025-10-26 | **State**: Open | **Repo**: control-toolbox/CTBenchmarks.jl  
**PR**: None

---

## 📋 Summary

This issue proposes refactoring the benchmark workflow to move common setup code and file copying operations from individual benchmark scripts and Julia functions into the reusable GitHub workflow. The goal is to simplify benchmark scripts, reduce code duplication, and centralize workflow logic.

**Created**: 2025-10-26T10:51:43Z | **Updated**: 2025-10-26T10:51:43Z | **Labels**: None

---

## 💬 Discussion

The issue identifies two main areas for improvement:

1. **Common Setup Code**: All three benchmark scripts (`core-moonshot.jl`, `core-mothra.jl`, `core-ubuntu-latest.jl`) contain identical setup code (lines 1-15) that activates the project environment, installs dependencies, updates packages, and loads CTBenchmarks. This should be moved to the reusable workflow.

2. **TOML File Copying**: The `copy_project_files()` function in `src/utils.jl` (lines 636-645) copies `Project.toml` and `Manifest.toml` to the output directory. This copying should be handled by the GitHub workflow instead, consistent with how the benchmark script itself is copied (lines 133-154 of `benchmark-reusable.yml`).

**Key Decisions**:

- Centralize environment setup in GitHub workflow
- Move file copying from Julia code to workflow
- Maintain backward compatibility during transition

**References**:


- [core-moonshot.jl](https://github.com/control-toolbox/CTBenchmarks.jl/blob/main/benchmarks/core-moonshot.jl)
- [benchmark-reusable.yml#L117-L128](https://github.com/control-toolbox/CTBenchmarks.jl/blob/0b0920c77f6c8c64be153f1401c3338ffbc74a43/.github/workflows/benchmark-reusable.yml#L117-L128)
- [utils.jl#L636-L645](https://github.com/control-toolbox/CTBenchmarks.jl/blob/0b0920c77f6c8c64be153f1401c3338ffbc74a43/src/utils.jl#L636-L645)
- [utils.jl#L744](https://github.com/control-toolbox/CTBenchmarks.jl/blob/0b0920c77f6c8c64be153f1401c3338ffbc74a43/src/utils.jl#L744)

---

## ✅ Completed

None - This is a new refactoring proposal with no work started yet.

---

## 📝 Pending Actions

### 🔴 Critical

**Action 1: Move common setup code to reusable workflow**
- Why: Eliminates code duplication across all benchmark scripts (currently 15 lines × 3 scripts)
- Where: `.github/workflows/benchmark-reusable.yml` (lines 117-128)
- Complexity: Moderate
- Details:
  - Extract lines 1-15 from benchmark scripts (Pkg setup, activate, instantiate, update, using CTBenchmarks)
  - Add to workflow before `include(ENV["SCRIPT_PATH"])`
  - **Critical consideration**: Must adapt `Pkg.activate(project_dir)` since workflow runs from repo root
  - Likely solution: Use `Pkg.activate(".")` or detect project root dynamically
  - Affects: All 3 benchmark scripts must be updated to remove setup code

**Action 2: Move TOML file copying to reusable workflow**
- Why: Consistency with existing script copying logic, removes Julia-side file I/O responsibility
- Where: `.github/workflows/benchmark-reusable.yml` (add after line 154)
- Complexity: Simple
- Details:
  - Add step to copy `Project.toml` and `Manifest.toml` from repo root to `$OUTPUT_DIR`
  - Pattern already exists for script copying (lines 133-154)
  - Remove call to `copy_project_files(outpath)` from `src/utils.jl` line 744
  - Validation already exists (lines 176-184 check for TOML files)

### 🟡 High

**Action 3: Update docstrings and documentation**
- Why: Changes to `benchmark()` function behavior require documentation updates
- Where: `src/utils.jl` (lines 651-698) and `docs/src/dev.md`
- Complexity: Simple
- Details:
  - Update `benchmark()` docstring to reflect that TOML copying is now workflow responsibility
  - Update `dev.md` to explain new workflow structure
  - Document that benchmark scripts no longer need setup code
  - Update examples in documentation

**Action 4: Decide on `copy_project_files()` function fate**
- Why: Function may become obsolete after workflow changes
- Where: `src/utils.jl` (lines 636-645)
- Complexity: Simple
- Details:
  - Determine if function is used elsewhere (needs code search)
  - If only used in `benchmark()`, consider deprecation or removal
  - If used in local testing scenarios, keep but document workflow handles it in CI

### 🟢 Medium

**Action 5: Update tests if needed**
- Why: Changes to `benchmark()` function may affect test expectations
- Where: `test/test_utils.jl`
- Complexity: Simple to Moderate
- Details:
  - Review tests that call `benchmark()` or `copy_project_files()`
  - Current tests focus on `solve_and_extract_data()` and `benchmark_data()`, not file I/O
  - May not need changes if TOML copying is tested at workflow level
  - Consider adding integration test for workflow behavior

---

## 🔧 Technical Analysis

**Code Findings**:

1. **Common setup pattern** (identical across 3 scripts):
   ```julia
   using Pkg
   const project_dir = normpath(@__DIR__, "..")
   ENV["PROJECT"] = project_dir
   Pkg.activate(project_dir)
   Pkg.instantiate()
   Pkg.update()
   using CTBenchmarks
   ```
   - Found in: `benchmarks/core-moonshot.jl`, `benchmarks/core-mothra.jl`, `benchmarks/core-ubuntu-latest.jl`
   - Lines 1-15 in each file

2. **TOML copying in Julia**:
   ```julia
   copy_project_files(outpath)  # Line 744 in utils.jl
   ```
   - Function definition: lines 636-645
   - Copies `Project.toml` and `Manifest.toml` to output directory
   - Called within `benchmark()` function

3. **Workflow already copies script**:
   - Lines 133-154 in `benchmark-reusable.yml`
   - Establishes pattern for file copying in workflow
   - Validates TOML presence (lines 176-184)

4. **Return value change needed**:
   - Current `benchmark()` returns `nothing` (line 749)
   - Workflow expects `main()` to return `outpath` (line 122)
   - Scripts already return `outpath` from `main()` (e.g., line 48 in core-moonshot.jl)
   - **Issue**: `benchmark()` should return `outpath` to support workflow

**Julia Standards**:
- ✅ Documentation: Comprehensive docstrings present
- ✅ Testing: Good test coverage for core functions
- ⚠️ Type Stability: Not assessed in detail, but function signatures are well-typed
- ✅ Structure: Clean separation of concerns (will improve with this refactoring)

**Performance**: No performance impact expected - this is a workflow/organizational refactoring.

**Architectural Considerations**:
- **Separation of concerns**: Moving setup to workflow improves separation between benchmark logic and environment setup
- **DRY principle**: Eliminates duplication across benchmark scripts
- **Workflow consistency**: Aligns file copying strategy (all in workflow vs. split between workflow and Julia)
- **Local testing**: Need to ensure benchmark scripts can still run locally after removing setup code
  - Solution: Provide a local wrapper script or document manual setup steps
  - Note: `benchmarks/local.jl` exists for local testing

---

## 🚧 Blockers

1. ❓ **Pkg.activate() path adaptation**: How should the workflow activate the project environment?
   - Current scripts use `Pkg.activate(project_dir)` where `project_dir = normpath(@__DIR__, "..")`
   - Workflow runs from repo root, so path logic differs
   - Need to determine correct activation approach in workflow context

2. ❓ **Local testing workflow**: After removing setup code from benchmark scripts, how should developers run benchmarks locally?
   - Option A: Keep `local.jl` as a wrapper that does setup + includes benchmark
   - Option B: Document manual setup steps
   - Option C: Create a helper function for local testing
   - Need user decision on preferred approach

3. ❓ **Backward compatibility**: Should `copy_project_files()` be kept for backward compatibility?
   - Need to search codebase for other uses
   - Consider deprecation strategy if removing

---

## 💡 Recommendations

**Immediate**:

1. **Search for `copy_project_files` usage** before deciding on removal
   ```bash
   grep -r "copy_project_files" --include="*.jl" .
   ```

2. **Prototype workflow changes** in a test branch:
   - Add Pkg setup to workflow
   - Add TOML copying to workflow
   - Test with one benchmark script first

3. **Update `benchmark()` return value** to return `outpath` instead of `nothing` (line 749 in utils.jl)

**Implementation Order**:
1. Action 2 (TOML copying) - Simplest, can be done independently
2. Action 1 (Setup code) - More complex due to path considerations
3. Actions 3-4 (Documentation and cleanup) - After code changes work
4. Action 5 (Tests) - Final validation

**Long-term**:

- **Consider workflow templating**: If more benchmark types are added, consider using workflow templates or matrix strategies
- **Local testing helper**: Create a `run_benchmark_local.jl` helper that wraps any benchmark script with proper setup
- **Validation improvements**: Add workflow validation to ensure TOML files match repo root versions

**Julia Alignment**:
- Follows Julia best practices for package structure
- Improves maintainability through DRY principle
- Maintains clear API boundaries between package code and CI/CD

---

**Status**: Needs attention - Clear requirements but needs decisions on blockers  
**Effort**: Medium (2-4 hours for implementation + testing + documentation)
