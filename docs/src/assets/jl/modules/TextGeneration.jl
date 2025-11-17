# ═══════════════════════════════════════════════════════════════════════════════
# Text Generation Module
# ═══════════════════════════════════════════════════════════════════════════════

"""
Registry of text-generating functions that can be called from INCLUDE_TEXT blocks.

All registered functions must accept string arguments and return a Markdown
string that will be inlined directly into the generated documentation.
"""

"""
    _print_benchmark_table_results_from_args(args...)

Internal adapter used by INCLUDE_TEXT to call `_print_benchmark_table_results`.

Interpretation of arguments:
- First argument: `bench_id`
- Remaining arguments (if any): list of problem names used to filter the table
  via the `problems` keyword argument.
"""
function _print_benchmark_table_results_from_args(args...)
    if isempty(args)
        error("_print_benchmark_table_results requires at least a bench_id argument")
    end

    bench_id = String(args[1])
    problems = if length(args) > 1
        String[arg for arg in args[2:end]]
    else
        nothing
    end

    return _print_benchmark_table_results(bench_id; problems=problems)
end

const TEXT_FUNCTIONS = Dict{String, Function}(
    "_analyze_profile_default_cpu" => _analyze_profile_default_cpu,
    "_analyze_profile_default_iter" => _analyze_profile_default_iter,
    "_print_benchmark_table_results" => _print_benchmark_table_results_from_args,
)

"""
    call_text_function(function_name::String, args::Vector{String})

Safely call a registered text function with string arguments.

# Arguments
- `function_name::String`: Name of the function (must be in `TEXT_FUNCTIONS`)
- `args::Vector{String}`: Vector of string arguments to pass to the function

# Returns
- `String`: Markdown content produced by the text function

# Throws
- `ErrorException` if function not found in registry
"""
function call_text_function(function_name::AbstractString, args::Vector{<:AbstractString})
    if !haskey(TEXT_FUNCTIONS, function_name)
        available = join(sort(collect(keys(TEXT_FUNCTIONS))), ", ")
        error("Function '$function_name' not found in TEXT_FUNCTIONS registry. Available: $available")
    end

    func = TEXT_FUNCTIONS[function_name]
    @info "  📝 Calling $function_name($(join(args, ", ")))"

    return func(args...)
end
