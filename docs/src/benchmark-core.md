# Core benchmark

```@setup BENCH
include(joinpath(@__DIR__, "assets", "utils.jl"))

# Load both benchmark datasets
const BENCH_DIR_UBUNTU = "benchmark-core-ubuntu-latest"
const BENCH_DIR_MOONSHOT = "benchmark-core-moonshot"
const BENCH_DATA_UBUNTU = _read_benchmark_json(joinpath(@__DIR__, "assets", BENCH_DIR_UBUNTU, "data.json"))
const BENCH_DATA_MOONSHOT = _read_benchmark_json(joinpath(@__DIR__, "assets", BENCH_DIR_MOONSHOT, "data.json"))
```

## Ubuntu Latest

This page displays the core benchmark results from `docs/src/assets/benchmark-core-ubuntu-latest/data.json`.

### 🖥️ Environment

```@example BENCH
_basic_metadata(BENCH_DATA_UBUNTU) # hide
```

```@example BENCH
_downloads_toml(BENCH_DIR_UBUNTU) # hide
```

```@raw html
<details style="margin-bottom: 0.5em; margin-top: 0.5em;"><summary>ℹ️ Version info</summary>
```

```@example BENCH
_bench_data(BENCH_DATA_UBUNTU) # hide
```

```@raw html
</details>
```

```@raw html
<details style="margin-bottom: 0.5em;"><summary>📦 Package status</summary>
```

```@example BENCH
_package_status(BENCH_DATA_UBUNTU) # hide
```

```@raw html
</details>
```

```@raw html
<details style="margin-bottom: 0.5em;"><summary>📚 Complete manifest</summary>
```

```@example BENCH
_complete_manifest(BENCH_DATA_UBUNTU) # hide
```

```@raw html
</details>
```

### 📊 Results

```@example BENCH
_print_results(BENCH_DATA_UBUNTU) # hide
nothing # hide
```

## Moonshot

This page displays the core benchmark results from `docs/src/assets/benchmark-core-moonshot/data.json`.

### 🚀 Environment

```@example BENCH
_basic_metadata(BENCH_DATA_MOONSHOT) # hide
```

```@example BENCH
_downloads_toml(BENCH_DIR_MOONSHOT) # hide
```

```@raw html
<details style="margin-bottom: 0.5em; margin-top: 0.5em;"><summary>ℹ️ Version info</summary>
```

```@example BENCH
_bench_data(BENCH_DATA_MOONSHOT) # hide
```

```@raw html
</details>
```

```@raw html
<details style="margin-bottom: 0.5em;"><summary>📦 Package status</summary>
```

```@example BENCH
_package_status(BENCH_DATA_MOONSHOT) # hide
```

```@raw html
</details>
```

```@raw html
<details style="margin-bottom: 0.5em;"><summary>📚 Complete manifest</summary>
```

```@example BENCH
_complete_manifest(BENCH_DATA_MOONSHOT) # hide
```

```@raw html
</details>
```

### ⚡ Results

```@example BENCH
_print_results(BENCH_DATA_MOONSHOT) # hide
nothing # hide
```
