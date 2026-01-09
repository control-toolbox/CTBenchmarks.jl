# ═══════════════════════════════════════════════════════════════════════════════
# Text Engine Module
# ═══════════════════════════════════════════════════════════════════════════════

"""
Registry of text-generating functions that can be called from INCLUDE_TEXT blocks.

All registered functions must accept string arguments and return a Markdown
string that will be inlined directly into the generated documentation.
"""

const TEXT_FUNCTIONS = Dict{String,Function}()


"""
    register_text_handler!(name::String, func::Function)

Register a text-generating function in the global text registry.
"""
function register_text_handler!(name::AbstractString, func::Function)
    TEXT_FUNCTIONS[String(name)] = func
    return nothing
end

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
function call_text_function(
    function_name::AbstractString,
    args::Vector{<:AbstractString},
    extra_args::Tuple=()
)
    if !haskey(TEXT_FUNCTIONS, function_name)
        available = join(sort(collect(keys(TEXT_FUNCTIONS))), ", ")
        error(
            "Function '$function_name' not found in TEXT_FUNCTIONS registry. Available: $available",
        )
    end

    func = TEXT_FUNCTIONS[function_name]
    DOC_DEBUG[] && @info "  📝 Calling $function_name($(join(args, ", ")))"

    return func(args..., extra_args...)
end
