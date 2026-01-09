# Issue #124 - [120] Cleanup obsolete files and add documentation

**Date**: 2026-01-09 | **State**: Open | **Repo**: control-toolbox/CTBenchmarks.jl  
**PR**: #128 on branch `120-us4-cleanup`

---
## 📋 Summary
This issue is the final phase (US-4) of the major code refactoring (#120). It focuses on removing legacy modules that have been replaced by the new registry-based architecture and providing clear documentation for developers on how to add custom performance profiles.

**Created**: 2026-01-08 | **Updated**: 2026-01-09 | **Labels**: documentation, enhancement

---

## 💬 Discussion
The refactoring process progressed through:
1. **US-2**: Implementation of the `PerformanceProfileRegistry` in core `src/`.
2. **US-3**: Transition to declarative `PROFILE_PLOT` and `PROFILE_ANALYSIS` template syntax.
3. **US-4** (Current): Cleanup of the documentation utilities and final documentation polish.

**Key Decisions**:
- Consolidate all performance profile logic into `src/performance_profile.jl`.
- Remove bridge/adapter modules in `docs/src/docutils/modules/` that are no longer needed.

---

## ✅ Completed
- ✓ [Cleanup] - Removed obsolete files:
    - `docs/src/docutils/modules/PerformanceProfileCore.jl`
    - `docs/src/docutils/modules/PlotPerformanceProfile.jl`
    - `docs/src/docutils/modules/AnalyzePerformanceProfile.jl`
- ✓ [Integrity] - Updated `docs/src/docutils/CTBenchmarksDocUtils.jl` to remove imports and initializations related to the deleted modules.

---

## 📝 Pending Actions

### 🔴 Critical
**Create `docs/src/add_performance_profile.md`**
- Why: Guidance for adding new performance metrics is currently missing from the new architecture.
- Actions: Explain `ProfileCriterion`, `PerformanceProfileConfig`, and the registration process.
- Complexity: Moderate

**Update Page Navigation**
- Why: The new documentation page must be registered in the build script.
- Actions: Add `add_performance_profile.md` to the `Developers Guidelines` section in `docs/make.jl`.
- Complexity: Simple

### 🟡 High
**Verification Build**
- Why: Confirm the documentation build still works after the file deletions and additions.
- Complexity: Simple

### 🟢 Medium
**Broken Link Check**
- Why: Ensure the move to the new documentation structure didn't break existing cross-references.
- Complexity: Simple

---

## 🔧 Technical Analysis

**Code Findings**:
- Legacy files were successfully removed during the merge of `120-dev-refactoring`.
- `CTBenchmarksDocUtils.jl` now correctly includes `ProfileRegistry.jl` and initializes it via `init_default_profiles!()`.

**Julia Standards**:
- ✅ Code organization: Consolidating logic into `src/` follows standard package structure.
- ✅ Documentation: Transitioning to specialized template blocks improves maintainability.

---

## 🚧 Blockers
- None.

---

## 💡 Recommendations

**Immediate**:
1. Draft the guide for custom profiles, specifically showing how to use the `PROFILE_REGISTRY`.

**Long-term**:
- Consider adding a "Gallery" or "Summary" page that lists all available profiles in the registry.

---

**Status**: On track | **Effort**: Small
