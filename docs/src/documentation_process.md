# Documentation Generation Process {#documentation-process}

This page explains how the CTBenchmarks.jl documentation is generated and how
benchmark results are turned into rich documentation pages with figures,
tables, and environment information.

It is mainly intended for developers who want to:

- **Understand** the `docs/make.jl` pipeline.
- **Add documentation** for a new benchmark.
- **Extend** the existing template/figure system.

If you only want to add a benchmark to the CI pipeline, see
`Add a new benchmark` first. For documentation-specific details, come back to
this page.

---

## High-Level Overview

The documentation build has three main stages:

1. **Prepare the environment and utilities**
   - Copy `Project.toml` and `Manifest.toml` under `docs/src/assets/toml/`.
   - Load documentation utilities from `docs/src/assets/jl/utils.jl`.

2. **Generate and process templates**
   - Automatically generate `.md.template` files for per-problem pages
     (core benchmark problems).
   - Process template files (including manual templates) to produce temporary
     `.md` files that Documenter can read.
   - While processing templates, replace special blocks such as
     `INCLUDE_ENVIRONMENT` and `INCLUDE_FIGURE`.

3. **Build and deploy documentation**
   - Call `makedocs` with the processed `.md` files.
   - Clean up all generated templates and figures.
   - Deploy the documentation to GitHub Pages via `deploydocs`.

All of this is orchestrated by `docs/make.jl`.

```text
docs/make.jl
   ├─ copy Project/Manifest → docs/src/assets/toml
   ├─ include docs/src/assets/jl/utils.jl
   ├─ with_processed_template_problems("docs/src") do core_problems
   │    └─ with_processed_templates([core/cpu.md, core/gpu.md, core/problems], ... ) do
   │         └─ makedocs(...)
   └─ deploydocs(...)
```

---

## `docs/make.jl`: Orchestrating the Build

The main steps in `docs/make.jl` are:

- **Configuration**
  - `draft = false` controls execution of `@example` blocks.
  - `exclude_problems_from_draft` can force specific problem pages to execute
    their examples even in draft mode.

- **Environment files**
  - `Project.toml` and `Manifest.toml` are copied into
    `docs/src/assets/toml/` so that the exact environment used for the
    documentation is preserved.

- **Documentation utilities**
  - `include("src/assets/jl/utils.jl")` loads all helper modules:
    template generation, template processing, figure generation, plotting, and
    log/environment printers.

- **Template generation for problems**
  - `with_processed_template_problems(joinpath(@__DIR__, "src"); ...) do core_problems`:
    - Calls into `TemplateGenerator.write_core_benchmark_templates` to create
      `.md.template` files for all **core benchmark problems**.
    - Returns a list of generated template paths and the list of problem names
      `core_problems`.
    - Ensures that all generated `.md.template` files are deleted afterwards.

  Flow (problems):

  ```text
  with_processed_template_problems(src) do core_problems
      ├─ write_core_benchmark_templates(src, draft, exclude)
      │    ├─ read core benchmark JSONs
      │    ├─ collect all problems
      │    └─ write core/problems/<problem>.md.template
      ├─ core_problems = list of problem names
      └─ f(core_problems)  # calls into template processing + makedocs
      # finally: remove generated .md.template files
  end
  ```

- **Template processing**
  - Inside the `do core_problems` block, we call:

    ```julia
    with_processed_templates(
        [
            joinpath("core", "cpu.md"),
            joinpath("core", "gpu.md"),
            joinpath("core", "problems"),
        ],
        joinpath(@__DIR__, "src"),
        joinpath(@__DIR__, "src", "assets", "md"),
    ) do
        makedocs(; ...)
    end
    ```

    - `with_processed_templates` (from `TemplateProcessor.jl`) takes a list of
      template files/directories and:
      1. Resolves them to concrete template paths
         (e.g., `core/cpu.md.template`, `core/problems/*.md.template`).
      2. Processes each template, replacing `INCLUDE_ENVIRONMENT` and
         `INCLUDE_FIGURE` blocks and writing the resulting `.md` files.
      3. Collects all figure paths generated during processing.
      4. Runs `makedocs`.
      5. Cleans up all generated `.md` files and figures in a `finally` block.

  Flow (templates):

  ```text
  with_processed_templates(files, src, assets_md) do
      ├─ construct_template_files(files, src)
      │    └─ expand directories → list of *.md.template
      ├─ process_templates(...)
      │    ├─ for each template:
      │    │    ├─ replace_environment_blocks
      │    │    └─ replace_figure_blocks → generate figures (SVG + PDF)
      │    └─ write processed .md files
      ├─ makedocs(...)
      └─ finally
           ├─ remove generated .md files
           └─ remove generated figures (if any)
  end
  ```

- **Building and deployment**
  - `makedocs` builds the HTML documentation.
  - `deploydocs` publishes it to GitHub Pages.

The important takeaway: **problem pages and some benchmark pages are not
written by hand**. They are generated and then processed via templates.

---

## Automatic Problem Pages

Problem pages under `docs/src/core/problems/` are generated automatically from
benchmark data using `TemplateGenerator.jl`.

### Core benchmark templates

The function `write_core_benchmark_templates`:

- Reads the list of **core benchmarks** (e.g., `core-ubuntu-latest`,
  `core-moonshot-cpu`, `core-moonshot-gpu`).
- For each benchmark, determines which **problems** appear in its JSON results
  (e.g., `beam`, `crane`, ...).
- Builds a set of all problems across all core benchmarks.
- For each problem, calls `generate_template_problem_from_list` to create a
  `.md.template` file under `core/problems/`.

```text
core-*.json (benchmark results)
   └─ write_core_benchmark_templates
        ├─ get_problems_in_benchmarks → [problem_1, problem_2, ...]
        └─ for each problem
             └─ generate_template_problem_from_list
                  └─ core/problems/<problem>.md.template
```

### Structure of a generated problem page

Inside `generate_template_problem` and
`generate_template_problem_from_list`, a typical problem page contains:

- A title and description for the problem.
- A single `@setup BENCH` block that loads `utils.jl`.
- One **section per benchmark configuration** (e.g., one for
  `core-ubuntu-latest`, one for `core-moonshot-cpu`, etc.). For each section:
  - An `INCLUDE_ENVIRONMENT` block that will display environment and
    configuration information.
  - One or several `INCLUDE_FIGURE` blocks for plots such as:
    - Global performance profiles.
    - Time vs grid size (line and bar plots).
  - A `@example BENCH` block that calls `_print_benchmark_log` with the
    corresponding `bench_id` to print detailed results.

You do **not** edit these pages by hand. They are regenerated from templates
whenever documentation is built.

---

## Template Processing and Special Blocks

Template files (both auto-generated and manual) may contain special blocks of
the form:

- `<!-- INCLUDE_ENVIRONMENT: ... -->`
- `<!-- INCLUDE_FIGURE: ... -->`

These are handled by `TemplateProcessor.jl`.

### `INCLUDE_ENVIRONMENT`

`INCLUDE_ENVIRONMENT` blocks are used to inject environment and configuration
information for a given benchmark. They look like:

```markdown
<!-- INCLUDE_ENVIRONMENT:
BENCH_ID = "core-ubuntu-latest"
ENV_NAME = BENCH
-->
```

During template processing:

- The parameter block is parsed by `parse_include_params`.
- The environment template `environment.md.template` is loaded.
- Variables such as `BENCH_ID` and `ENV_NAME` are substituted.
- The template is rendered using helper functions from
  `PrintEnvConfig.jl`, typically including:
  - Download links for `Project.toml`, `Manifest.toml` and the benchmark script
    via `_downloads_toml`.
  - Basic metadata (timestamp, Julia version, OS, machine) via
    `_basic_metadata`.
  - Optional detailed metadata (`_version_info`, `_complete_manifest`,
    `_print_config`).

The resulting Markdown replaces the original comment block in the generated
`.md` file.

```text
core/...md.template
   └─ <!-- INCLUDE_ENVIRONMENT: BENCH_ID = "core-ubuntu-latest", ... -->
        └─ replace_environment_blocks
             └─ environment.md.template + PrintEnvConfig helpers
                  └─ Markdown block (links + metadata + config)
```

### `INCLUDE_FIGURE`

`INCLUDE_FIGURE` blocks are used to generate and insert plots. For example:

```markdown
<!-- INCLUDE_FIGURE:
FUNCTION = _plot_performance_profiles
ARGS = core-ubuntu-latest
-->
```

During processing:

- The function name and arguments are parsed from the block.
- `FigureGeneration.jl` looks up the function in the `FIGURE_FUNCTIONS`
  registry:
  - `_plot_performance_profiles`
  - `_plot_time_vs_grid_size`
  - `_plot_time_vs_grid_size_bar`
- The plotting function is called in the `BENCH` environment with string
  arguments.
- Two files are generated in the figures directory (SVG + PDF), with a unique
  basename derived from the template name, function name, and arguments.
- The template processor emits Markdown that:
  - Embeds the SVG figure in the page.
  - Wraps the SVG in a link pointing to the PDF.

As a result, **figures in the documentation are clickable** and open a PDF
version suitable for high-quality printing.

```text
core/...md.template
   └─ <!-- INCLUDE_FIGURE: FUNCTION = _plot_performance_profiles, ARGS = core-ubuntu-latest -->
        └─ replace_figure_blocks
             ├─ call_figure_function(FUNCTION, ARGS)
             ├─ generate_figure_files → SVG + PDF in assets/plots
             └─ emit @raw html block (img SVG, link PDF)
```

---

## Figure Types and Helper Functions

Several helper modules provide the concrete plots and textual outputs:

- **Performance profiles** — `PlotPerformanceProfile.jl`
  - `_plot_performance_profiles(bench_id)`
  - Plots Dolan–Moré-style performance profiles over (problem, grid_size)
    instances and (model, solver) combinations.

- **Time vs grid size** — `PlotTimeVsGridSize.jl`
  - `_plot_time_vs_grid_size(problem, bench_id, src_dir)`
  - `_plot_time_vs_grid_size_bar(problem, bench_id, src_dir)`
  - Line and bar plots showing mean solve time as a function of grid size.

- **Benchmark logs** — `PrintLogResults.jl`
  - `_print_benchmark_log(bench_id, src_dir; problems=nothing)`
  - Prints a tree-structured log by problem, solver, discretization, grid size,
    and model, with colored formatting.

- **Environment and configuration** — `PrintEnvConfig.jl`
  - `_downloads_toml(bench_id, src_dir)`
  - `_basic_metadata(bench_id, src_dir)`
  - `_version_info(bench_id, src_dir)`
  - `_complete_manifest(bench_id, src_dir)`
  - `_print_config(bench_id, src_dir)`

These functions are all made available by `utils.jl` and are typically used
indirectly via `INCLUDE_ENVIRONMENT`, `INCLUDE_FIGURE`, or `@example BENCH`
blocks.

---

## Adding Documentation for a Benchmark

There are two complementary ways benchmark results appear in the documentation.

### 1. Automatic per-problem pages (core benchmarks)

For **core benchmarks**, once the benchmark JSON files are present under
`docs/src/assets/benchmarks/<id>/<id>.json`, the corresponding problem pages
are generated automatically by `write_core_benchmark_templates`.

You do not need to create these pages manually. The system inspects the JSON
results, discovers which problems were benchmarked, and creates one section per
benchmark configuration in the appropriate problem page.

### 2. Manual benchmark pages

You can also write dedicated pages for specific benchmarks, such as
`docs/src/core/cpu.md.template` or `docs/src/benchmark-<name>.md.template`.

The general pattern for such a page is:

1. Add a single `@setup BENCH` block at the top of the page:

   ````julia
   ```@setup BENCH
   # Load utilities
   include(normpath(joinpath(@__DIR__, "..", "assets", "jl", "utils.jl")))
   ```
   ````

2. For each benchmark you want to show, add:

   - An `INCLUDE_ENVIRONMENT` block with a literal `BENCH_ID`:

     ```markdown
     <!-- INCLUDE_ENVIRONMENT:
     BENCH_ID = "core-ubuntu-latest"
     ENV_NAME = BENCH
     -->
     ```

   - One or more `INCLUDE_FIGURE` blocks:

     ```markdown
     <!-- INCLUDE_FIGURE:
     FUNCTION = _plot_performance_profiles
     ARGS = core-ubuntu-latest
     -->
     ```

   - A `@example BENCH` block to print the benchmark log:

     ````julia
     ```@example BENCH
     _print_benchmark_log("core-ubuntu-latest") # hide
     ```
     ````

3. Add your page to `docs/make.jl` in the `pages` list so that Documenter
   knows about it.

For a minimal template example, see the "Documentation page" step in
`Add a new benchmark`. That section is intentionally concise and defers to this
page for full details of the template processing pipeline.

---

## Summary

- `docs/make.jl` drives the whole documentation build: copying environment
  files, generating templates, processing them, and calling `makedocs`.
- Problem pages for core benchmarks are generated automatically from benchmark
  results.
- Template processing replaces `INCLUDE_ENVIRONMENT` and `INCLUDE_FIGURE`
  blocks with rich content and clickable figures.
- Helper modules provide plotting, logging, and environment/configuration
  utilities.
- To document a new benchmark, you can rely on the automatic problem pages and
  optionally add a manual page following the template pattern above.
