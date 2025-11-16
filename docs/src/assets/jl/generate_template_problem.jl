using JSON
using DataFrames

include(joinpath(@__DIR__, "common.jl"))

# Generate template problem
# 
# the function `generate_template_problem`
# returns a Markdown string that can be saved to a file
# 
function generate_template_problem(
    problem_name::String,
    bench_id::String, 
    bench_title::String,
    bench_desc::String,
    env_name::String,
    )

    TITLE = "## " * bench_title * "\n"

    DESC = isempty(bench_desc) ? "" : bench_desc * "\n"
    
    ENV = """
    <!-- INCLUDE_ENVIRONMENT:
    bench_id = "$bench_id"
    env_name = $env_name
    -->
    """

    RESULTS = """
    ### Time vs Grid Size ($bench_title)

    ```@example $env_name
    _plot_time_vs_grid_size("$problem_name", "$bench_id") # hide
    ```

    ```@example $env_name
    _plot_time_vs_grid_size_bar("$problem_name", "$bench_id") # hide
    ```
    """

    # Build figure blocks for each available N where both PDF and PNG exist
    # Figures are stored under docs/src/assets/benchmarks/<bench_id>/figures/
    figures_dir = joinpath(@__DIR__, "..", "benchmarks", bench_id, "figures")
    figure_blocks = String[]

    if isdir(figures_dir)
        files = readdir(figures_dir)
        # Match files like "beam_N200.pdf" for the given problem_name
        pattern = Regex("^" * problem_name * "_N(\\d+)\\.pdf")

        # Collect valid (N, block) pairs
        blocks_by_N = Dict{Int,String}()
        for filename in files
            m = match(pattern, filename)
            m === nothing && continue

            N_str = m.captures[1]
            N = try
                parse(Int, N_str)
            catch
                continue
            end

            base, _ = splitext(filename)  # e.g., "beam_N200"
            png_name = base * ".png"
            png_name in files || continue

            md_block = """
            ### Solution: N = $N ($bench_title)

            ```@raw html
            <a href="../../assets/benchmarks/$bench_id/figures/$base.pdf">
              <img 
                class="centering" 
                width="100%" 
                style="max-width:1400px" 
                src="../../assets/benchmarks/$bench_id/figures/$base.png"
              />
            </a>
            ```
            """

            blocks_by_N[N] = md_block
        end

        for N in sort(collect(keys(blocks_by_N)))
            push!(figure_blocks, blocks_by_N[N])
        end
    end

    FIGURES = isempty(figure_blocks) ? "" : join(figure_blocks, "\n")

    LOG = """
    ### Log ($bench_title)

    ```@example $env_name
    _print_benchmark_log("$bench_id"; problems=["$problem_name"]) # hide
    ```"""

    blocks = String[]
    push!(blocks, TITLE)
    isempty(DESC) || push!(blocks, DESC)
    push!(blocks, ENV)
    push!(blocks, RESULTS)
    isempty(FIGURES) || push!(blocks, FIGURES)
    push!(blocks, LOG)

    return join(map(x -> x * "\n", blocks), "")
end

# function to check if a problem is part of a benchmark or not
# inputs: 
# - bench_id: the id of the benchmark
# - problem_name: the name of the problem
# outputs: 
# - true if the problem is part of the benchmark, false otherwise
function is_problem_in_benchmark(bench_id::String, problem_name::String)

    raw = _get_bench_data(bench_id)
    if raw === nothing
        return false
    end

    rows = get(raw, "results", Any[])
    if isempty(rows)
        return false
    end

    df = DataFrame(rows)
    df_successful = filter(row -> row.benchmark !== nothing && row.problem == problem_name, df)
    return !isempty(df_successful)

end

# function to generate the template for a given problem from a list of benchmarks
# the elements of list of the benchmarks contains the triplet (bench_id, bench_title, bench_desc)
function generate_template_problem_from_list(
    problem_name::String,
    benchmarks::Vector{Tuple{String, String, String}},
    title::String,
    desc::String,
    )

    #
    env_name = "BENCH"
    blocks = String[]

    # title
    push!(blocks, "## " * title * "\n")

    # description
    !isempty(desc) && push!(blocks, desc * "\n")

    # setup
    SETUP = """
    ```@setup $env_name
    include(normpath(joinpath(@__DIR__, "..", "..", "assets", "jl", "utils.jl")))
    ```
    """
    push!(blocks, SETUP)

    #
    for (bench_id, bench_title, bench_desc) in benchmarks
        if is_problem_in_benchmark(bench_id, problem_name)
            println("Generating template for $problem_name in $bench_id")
            md = generate_template_problem(problem_name, bench_id, bench_title, bench_desc, env_name)
            push!(blocks, md)
        end 
    end
    
    return join(blocks, "\n")
end

# function to get all the problems available in a benchmark
function get_problems_in_benchmark(bench_id::String)
    raw = _get_bench_data(bench_id)
    if raw === nothing
        return []
    end
    rows = get(raw, "results", Any[])
    if isempty(rows)
        return []
    end
    df = DataFrame(rows)
    return unique(df.problem)
end

# function to get all the problems available in at least of the benchmark in the list
function get_problems_in_benchmarks(benchmarks::Vector{Tuple{String, String, String}})
    problems = String[]
    for (bench_id, _, _) in benchmarks
        append!(problems, get_problems_in_benchmark(bench_id))
    end
    return unique(problems)
end

# function to write core benchmark templates for a list of problems
function write_core_benchmark_templates()
    benchmarks = [
        ("core-ubuntu-latest", "Ubuntu Latest CPU", "This benchmark suite evaluates optimal control problems on a standard CPU platform using GitHub Actions runners."),
        ("core-moonshot-cpu", "Moonshot CPU", "Results on self-hosted CPU hardware."),
        ("core-moonshot-gpu", "Moonshot GPU", "Results on self-hosted GPU hardware."),
    ]
    problems = get_problems_in_benchmarks(benchmarks)
    files_generated = String[]
    for problem_name in problems
        title = "Core $problem_name Benchmark"
        desc = """
        This page presents benchmark results for the **$problem_name** problem across different platforms and configurations.

        !!! note
            The linear solver is MUMPS for all experiments."""
        str = generate_template_problem_from_list(problem_name, benchmarks, title, desc)
        println("Generating template for $problem_name")
        filepath = normpath(joinpath(@__DIR__, "..", "..", "core", "problems", "$(problem_name).md.template"))
        write(filepath, str)
        push!(files_generated, filepath)
    end
    return files_generated
end

# function with_processed_template_problems: that will process the template problems
function with_processed_template_problems(f::Function)
    files_generated = write_core_benchmark_templates()
    try
        return f()
    finally
        for filepath in files_generated
            rm(filepath)
        end
    end
end