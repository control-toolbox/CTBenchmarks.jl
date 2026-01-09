"""
    _print_benchmark_table_results(
        bench_id::AbstractString,
        problem::Union{Nothing, AbstractString}=nothing,
        src_dir::AbstractString=SRC_DIR,
    ) -> String

Generate a Markdown-style summary of benchmark results for `bench_id`, suitable
for inclusion in documentation pages (for example via an `INCLUDE_TEXT` block).

The underlying data are organised by problem, then grid size `N`, then model
and solver, and include columns for:

- Success (whether the run converged)
- N (grid size)
- Model
- Solver
- Time in milliseconds
- Iteration count
- Objective value
- Criterion (for example min/max)
- Best (marks the fastest successful run for each `N`)

# Arguments
- `bench_id::AbstractString`: benchmark identifier whose results should be
  summarised.
- `problem::Union{Nothing, AbstractString}`: optional problem name to filter
  results; `nothing` (the default) shows all problems.
- `src_dir::AbstractString`: path to the `docs/src` directory containing the
  benchmark JSON files.

# Returns
- `String`: Markdown-compatible text. When the benchmark contains a **single
  problem**, the function returns a standard Markdown table. When it contains
  **multiple problems**, it returns a `@raw html` block that embeds:
  - a `<select>` element listing all problems;
  - one HTML table per problem, each wrapped in a `<div>`;
  - a small JavaScript snippet to toggle visibility of the tables and persist
    the last selected problem in `window.localStorage`.

If no data are available, a Documenter-style `!!! warning` block is returned
instead of tables.
"""
function _print_benchmark_table_results(
    bench_id::AbstractString,
    problem::Union{Nothing,AbstractString}=nothing,
    src_dir::AbstractString=SRC_DIR,
)
    bench_data = _get_bench_data(bench_id, src_dir)
    if bench_data === nothing
        return "!!! warning\n    No benchmark data available for `$bench_id`.\n"
    end

    rows = get(bench_data, "results", Any[])
    if isempty(rows)
        return "!!! warning\n    Benchmark file for `$bench_id` contains no `results`.\n"
    end

    df = DataFrame(rows)

    # Optionally filter by a single problem
    if problem !== nothing
        df = filter(row -> row.problem == problem, df)
    end

    # Helper to read from Dict or NamedTuple
    function getval(obj, key::Symbol)
        if isa(obj, Dict)
            return get(obj, string(key), get(obj, key, nothing))
        else
            return getproperty(obj, key)
        end
    end

    # Helper to build safe DOM ids from arbitrary strings
    function sanitize_id(str)
        return replace(String(str), r"[^A-Za-z0-9_-]" => "-")
    end

    # Render all tables for a single problem as Markdown/HTML
    function render_problem_tables(problem, df; heading_mode::Symbol=:markdown)
        prob_df = filter(row -> row.problem == problem, df)
        if isempty(prob_df)
            return ""
        end

        local_buf = IOBuffer()

        sort!(prob_df, [:grid_size, :model, :solver])

        # Compute best (minimal) time per N for this problem
        best_time_by_N = Dict{Any,Float64}()
        for sub in groupby(prob_df, :grid_size)
            sub_success = filter(
                row -> row.success == true && row.benchmark !== nothing, sub
            )
            if isempty(sub_success)
                continue
            end

            times = Float64[]
            for row in eachrow(sub_success)
                bench = row.benchmark
                time_val = getval(bench, :time)
                if time_val !== nothing && !ismissing(time_val)
                    push!(times, Float64(time_val))
                end
            end

            if !isempty(times)
                N = first(sub.grid_size)
                best_time_by_N[N] = minimum(times)
            end
        end

        if heading_mode == :markdown
            print(local_buf, "#### Problem: `", problem, "`\n\n")

            Ns = sort(unique(prob_df.grid_size))
            for (idxN, Nval) in enumerate(Ns)
                if idxN > 1
                    print(local_buf, "\n\n")
                end

                print(
                    local_buf,
                    "| Success | N | Model | Solver | Time (ms) | Iters | Objective | Criterion | Best |\n",
                )
                print(
                    local_buf,
                    "|:------:|---:|:------|:-------|----------:|------:|----------:|:---------:|:----:|\n",
                )

                subN_df = filter(row -> row.grid_size == Nval, prob_df)

                for row in eachrow(subN_df)
                    success = hasproperty(row, :success) && row.success == true
                    success_mark = success ? "✓" : "✗"

                    N = row.grid_size
                    model = string(row.model)
                    solver = string(row.solver)

                    bench = row.benchmark
                    time_val = nothing
                    time_ms_str = "N/A"

                    if !(ismissing(bench) || bench === nothing)
                        time_raw = getval(bench, :time)
                        if time_raw !== nothing && !ismissing(time_raw)
                            time_val = Float64(time_raw)
                            time_ms_str = @sprintf("%.3f", time_val * 1000)
                        end
                    end

                    obj_str = if ismissing(row.objective) || row.objective === nothing
                        "N/A"
                    else
                        @sprintf("%.6f", row.objective)
                    end

                    iter_str = if (ismissing(row.iterations) || row.iterations === nothing)
                        "N/A"
                    else
                        string(row.iterations)
                    end

                    criterion_str =
                        if hasproperty(row, :criterion) &&
                            !(ismissing(row.criterion) || row.criterion === nothing)
                            string(row.criterion)
                        else
                            "N/A"
                        end

                    is_best = false
                    if success && haskey(best_time_by_N, N) && time_val !== nothing
                        best_time = best_time_by_N[N]
                        is_best =
                            abs(time_val - best_time) <=
                            (eps(Float64) * max(1.0, abs(best_time)))
                    end
                    best_mark = is_best ? "✓" : ""

                    print(
                        local_buf,
                        "| ",
                        success_mark,
                        " | ",
                        N,
                        " | `",
                        model,
                        "` | `",
                        solver,
                        "` | ",
                        time_ms_str,
                        " | ",
                        iter_str,
                        " | ",
                        obj_str,
                        " | ",
                        criterion_str,
                        " | ",
                        best_mark,
                        " |\n",
                    )
                end
            end

        elseif heading_mode == :html
            #print(local_buf, "<h4>Problem: ", problem, "</h4>\n\n")

            Ns = sort(unique(prob_df.grid_size))
            for (idxN, Nval) in enumerate(Ns)
                if idxN == 1
                    print(local_buf, "<br/>\n\n")
                end

                print(local_buf, "<table class=\"ct-benchmark-table\">\n")
                print(local_buf, "  <thead>\n")
                print(
                    local_buf,
                    "    <tr><th>Success</th><th>N</th><th>Model</th><th>Solver</th><th>Time (ms)</th><th>Iters</th><th>Objective</th><th>Criterion</th><th>Best</th></tr>\n",
                )
                print(local_buf, "  </thead>\n")
                print(local_buf, "  <tbody>\n")

                subN_df = filter(row -> row.grid_size == Nval, prob_df)

                for row in eachrow(subN_df)
                    success = hasproperty(row, :success) && row.success == true
                    success_mark = success ? "✓" : "✗"

                    N = row.grid_size
                    model = string(row.model)
                    solver = string(row.solver)

                    bench = row.benchmark
                    time_val = nothing
                    time_ms_str = "N/A"

                    if !(ismissing(bench) || bench === nothing)
                        time_raw = getval(bench, :time)
                        if time_raw !== nothing && !ismissing(time_raw)
                            time_val = Float64(time_raw)
                            time_ms_str = @sprintf("%.3f", time_val * 1000)
                        end
                    end

                    obj_str = if ismissing(row.objective) || row.objective === nothing
                        "N/A"
                    else
                        @sprintf("%.6f", row.objective)
                    end

                    iter_str = if (ismissing(row.iterations) || row.iterations === nothing)
                        "N/A"
                    else
                        string(row.iterations)
                    end

                    criterion_str =
                        if hasproperty(row, :criterion) &&
                            !(ismissing(row.criterion) || row.criterion === nothing)
                            string(row.criterion)
                        else
                            "N/A"
                        end

                    is_best = false
                    if success && haskey(best_time_by_N, N) && time_val !== nothing
                        best_time = best_time_by_N[N]
                        is_best =
                            abs(time_val - best_time) <=
                            (eps(Float64) * max(1.0, abs(best_time)))
                    end
                    best_mark = is_best ? "✓" : ""

                    print(local_buf, "    <tr>")
                    print(local_buf, "<td>", success_mark, "</td>")
                    print(local_buf, "<td>", N, "</td>")
                    print(local_buf, "<td><code>", model, "</code></td>")
                    print(local_buf, "<td><code>", solver, "</code></td>")
                    print(local_buf, "<td>", time_ms_str, "</td>")
                    print(local_buf, "<td>", iter_str, "</td>")
                    print(local_buf, "<td>", obj_str, "</td>")
                    print(local_buf, "<td>", criterion_str, "</td>")
                    print(local_buf, "<td>", best_mark, "</td>")
                    print(local_buf, "</tr>\n")
                end

                print(local_buf, "  </tbody>\n")
                print(local_buf, "</table>\n")
            end
        end

        return String(take!(local_buf))
    end

    problems_in_df = sort(unique(df.problem))
    if isempty(problems_in_df)
        return "!!! warning\n    No results to display for `$bench_id` after filtering.\n"
    end

    # Single problem: keep the original long-form rendering
    if length(problems_in_df) == 1
        return render_problem_tables(first(problems_in_df), df; heading_mode=:markdown)
    end

    # Multiple problems: build a selector + one table per problem, wrapped in @raw html
    buf = IOBuffer()

    bench_dom_id = sanitize_id(bench_id)
    select_id = "bench-" * bench_dom_id * "-problem-select"
    container_id = "bench-" * bench_dom_id * "-problem-tables"

    # Start Documenter raw HTML block
    print(buf, "```@raw html\n")

    print(buf, "<div class=\"ct-problem-table-selector\">\n")
    print(buf, "<label for=\"", select_id, "\">Problem:</label>\n")
    print(buf, "<select id=\"", select_id, "\">\n")
    for problem in problems_in_df
        problem_key = sanitize_id(problem)
        print(buf, "  <option value=\"", problem_key, "\">", problem, "</option>\n")
    end
    print(buf, "</select>\n")
    print(buf, "</div>\n\n")

    print(buf, "<div id=\"", container_id, "\">\n")
    for (idx, problem) in enumerate(problems_in_df)
        problem_key = sanitize_id(problem)
        display_style = idx == 1 ? "" : " style=\"display:none;\""
        print(
            buf,
            "<div class=\"ct-problem-table\" data-problem=\"",
            problem_key,
            "\"",
            display_style,
            ">\n\n",
        )

        content = render_problem_tables(problem, df; heading_mode=:html)
        if !isempty(content)
            print(buf, content)
        end

        print(buf, "\n</div>\n")
    end
    print(buf, "</div>\n\n")

    # Attach a small script to switch visible problem table and persist selection
    print(buf, "<script>\n")
    print(buf, "(function(){\n")
    print(buf, "  var select = document.getElementById('", select_id, "');\n")
    print(buf, "  if (!select) return;\n")
    print(buf, "  var container = document.getElementById('", container_id, "');\n")
    print(buf, "  if (!container) return;\n")
    print(buf, "  var storageKey = 'ctbench-problem-", bench_dom_id, "';\n")
    print(buf, "  function showProblem(value){\n")
    print(buf, "    var blocks = container.querySelectorAll('.ct-problem-table');\n")
    print(buf, "    for (var i = 0; i < blocks.length; i++) {\n")
    print(buf, "      var b = blocks[i];\n")
    print(
        buf,
        "      b.style.display = (b.getAttribute('data-problem') === value) ? '' : 'none';\n",
    )
    print(buf, "    }\n")
    print(buf, "  }\n")
    print(buf, "  // Try to restore last selection from localStorage\n")
    print(buf, "  try {\n")
    print(buf, "    if (window.localStorage) {\n")
    print(buf, "      var saved = localStorage.getItem(storageKey);\n")
    print(buf, "      if (saved) {\n")
    print(
        buf, "        var opt = select.querySelector('option[value=\"' + saved + '\"]');\n"
    )
    print(buf, "        if (opt) { select.value = saved; }\n")
    print(buf, "      }\n")
    print(buf, "    }\n")
    print(buf, "  } catch (e) {}\n")
    print(buf, "  // Initial display\n")
    print(buf, "  showProblem(select.value);\n")
    print(buf, "  select.addEventListener('change', function(){\n")
    print(buf, "    var value = this.value;\n")
    print(buf, "    showProblem(value);\n")
    print(buf, "    try {\n")
    print(
        buf, "      if (window.localStorage) { localStorage.setItem(storageKey, value); }\n"
    )
    print(buf, "    } catch (e) {}\n")
    print(buf, "  });\n")
    print(buf, "})();\n")
    print(buf, "</script>\n")

    # End raw HTML block
    print(buf, "```\n")

    return String(take!(buf))
end

# ───────────────────────────────────────────────────────────────────────────────
# Registration
# ───────────────────────────────────────────────────────────────────────────────

register_text_handler!("print_benchmark_table_results", _print_benchmark_table_results)

# Legacy support
register_text_handler!("_print_benchmark_table_results", _print_benchmark_table_results)
