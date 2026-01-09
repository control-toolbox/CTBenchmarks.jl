# Custom Performance Profiles

Performance profiles in CTBenchmarks.jl are used to compare the relative efficiency and robustness of different solver-model combinations. While default profiles for CPU time and iterations are provided, you can easily define custom profiles for any metric extracted from the benchmark results (e.g., objective error, constraint violations, etc.).

## The Profile Registry

The documentation system uses a global **Performance Profile Registry** to manage these configurations. Registering a profile once allows you to use it across any documentation template using a simple declarative syntax.

The registry is defined in `docs/src/docutils/ProfileRegistry.jl`.

## Defining a Profile

Adding a custom profile involves two main components: a **Criterion** and a **Configuration**.

### 1. Profile Criterion (`ProfileCriterion`)

The criterion defines what metric is measured and how to compare values.

```julia
criterion = ProfileCriterion{T}(
    name,    # Display name (e.g., "Objective Error")
    value,   # Function (row -> value) to extract the metric
    better   # Function (a, b -> Bool) returning true if a is better than b
)
```

**Example: Objective Error**

```julia
obj_criterion = CTBenchmarks.ProfileCriterion{Float64}(
    "Objective Error",
    row -> abs(row.objective - row.reference_objective),
    (a, b) -> a <= b  # Smaller error is better
)
```

### 2. Profile Configuration (`PerformanceProfileConfig`)

The configuration defines how to group benchmark results into "instances" and "solvers", and how to handle multiple runs.

```julia
config = PerformanceProfileConfig{T}(
    instance_cols, # Cols defining a problem (e.g., [:problem, :grid_size])
    solver_cols,   # Cols defining a solver (e.g., [:model, :solver])
    criterion,     # The ProfileCriterion to use
    is_success,    # Function (row -> Bool) to filter successful runs
    row_filter,    # Function (row -> Bool) for additional filtering
    aggregate      # Function (xs -> value) to aggregate multiple runs
)
```

---

## How to Register a New Profile

To make a profile available globally in the documentation:

1. Open `docs/src/docutils/ProfileRegistry.jl`.
2. Add your registration logic inside the `init_default_profiles!()` function or create a similar initialization step.

**Example Implementation:**

```julia
function init_custom_profiles!()
    # Define the criterion
    error_criterion = CTBenchmarks.ProfileCriterion{Float64}(
        "Constraint Violation",
        row -> get(row, :constraint_violation, NaN),
        (a, b) -> a <= b
    )

    # Define the configuration
    error_config = CTBenchmarks.PerformanceProfileConfig{Float64}(
        [:problem, :grid_size],
        [:model, :solver],
        error_criterion,
        row -> row.success == true,
        row -> true,
        xs -> Statistics.mean(skipmissing(xs))
    )

    # Register it under a unique name
    CTBenchmarks.register!(PROFILE_REGISTRY, "constraint_error", error_config)
end
```

---

## Using Custom Profiles in Templates

Once a profile (e.g., `"constraint_error"`) is registered, you can use it in your `.md.template` files with the specialized block syntax:

### Plotting the Profile

```markdown
<!-- PROFILE_PLOT:
NAME = constraint_error
BENCH_ID = core-ubuntu-latest
-->
```

### Textual Analysis

```markdown
<!-- PROFILE_ANALYSIS:
NAME = constraint_error
BENCH_ID = core-ubuntu-latest
-->
```

### Restricting Solver Combinations

You can use the `COMBOS` parameter to focus on specific solvers:

```markdown
<!-- PROFILE_PLOT:
NAME = constraint_error
BENCH_ID = core-ubuntu-latest
COMBOS = exa:ipopt, exa:madnlp
-->
```
