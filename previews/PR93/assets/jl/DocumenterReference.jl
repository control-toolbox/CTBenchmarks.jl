#  Copyright 2023, Oscar Dowson and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
#  Modified November 2025 for CTBenchmarks.jl:
#  - Separated public and private API documentation into distinct pages
#  - Added robust handling for missing docstrings (warnings instead of errors)
#  - Included non-exported symbols in API reference
#  - Filtered internal compiler-generated symbols (starting with '#')

module DocumenterReference

import Documenter
import Markdown
import MarkdownAST

@enum(
    DocType,
    DOCTYPE_ABSTRACT_TYPE,
    DOCTYPE_CONSTANT,
    DOCTYPE_FUNCTION,
    DOCTYPE_MACRO,
    DOCTYPE_MODULE,
    DOCTYPE_STRUCT,
)

struct _Config
    current_module::Module
    subdirectory::String
    modules::Dict{Module,<:Vector}
    sort_by::Function
    exclude::Set{Symbol}
end

const CONFIG = _Config[]

abstract type APIBuilder <: Documenter.Builder.DocumentPipeline end

Documenter.Selectors.order(::Type{APIBuilder}) = 0.0

"""
    automatic_reference_documentation(;
        subdirectory::String,
        modules,
        sort_by::Function = identity,
        exclude::Vector{Symbol} = Symbol[],
    )

Automatically creates the API reference documentation for one or more modules and
returns a `Vector` which can be used in the `pages` argument of
`Documenter.makedocs`.

## Arguments

 * `subdirectory`: the directory relative to the documentation root in which to
   write the API files.
 * `modules`: a vector of modules or `module => extras` pairs. Extras are
   currently unused but reserved for future extensions.
 * `sort_by`: a custom sort function applied to symbol lists.
 * `exclude`: vector of symbol names to skip from the generated API (applied to
   both public and private symbols).

## Multiple instances

Each time you call this function, a new object is added to the global variable
`DocumenterReference.CONFIG`.
"""
function automatic_reference_documentation(;
    subdirectory::String,
    modules::Vector,
    sort_by::Function = identity,
    exclude::Vector{Symbol} = Symbol[],
)
    _to_extras(m::Module) = m => Any[]
    _to_extras(m::Pair) = m
    _modules = Dict(_to_extras(m) for m in modules)
    exclude_set = Set(exclude)
    
    # For single-module case, return Public/Private structure directly
    if length(modules) == 1
        current_module = first(_to_extras(modules[1]))
        push!(CONFIG, _Config(current_module, subdirectory, _modules, sort_by, exclude_set))
        return "API Reference" => [
            "Public" => "$subdirectory/public.md",
            "Private" => "$subdirectory/private.md",
        ]
    end
    
    # For multi-module case, keep original structure
    list_of_pages = Any[]
    for m in modules
        current_module = first(_to_extras(m))
        pages = _automatic_reference_documentation(
            current_module;
            subdirectory,
            modules = _modules,
            sort_by,
            exclude = exclude_set,
        )
        push!(list_of_pages, "$current_module" => pages)
    end
    return "API Reference" => list_of_pages
end

function _automatic_reference_documentation(
    current_module::Module;
    subdirectory::String,
    modules::Dict{Module,<:Vector},
    sort_by::Function,
    exclude::Set{Symbol},
)
    push!(CONFIG, _Config(current_module, subdirectory, modules, sort_by, exclude))
    return "$subdirectory/$current_module.md"
end

function _exported_symbols(mod)
    exported = Pair{Symbol,DocType}[]
    private = Pair{Symbol,DocType}[]
    exported_names = Set(names(mod; all=false))  # Only exported symbols
    
    # Use all=true, imported=false to include non-exported (private) symbols
    # defined in this module, but skip names imported from other modules.
    for n in names(mod; all=true, imported=false)
        name_str = String(n)
        # Skip internal compiler-generated symbols like #save_json##... which
        # do not have meaningful bindings for documentation.
        if startswith(name_str, "#")
            continue
        end
        f = getfield(mod, n)
        f_str = string(f)
        
        local doc_type
        if startswith(f_str, "@")
            doc_type = DOCTYPE_MACRO
        elseif startswith(f_str, "Abstract")
            doc_type = DOCTYPE_ABSTRACT_TYPE
        elseif f isa Type
            doc_type = DOCTYPE_STRUCT
        elseif f isa Function
            if islowercase(f_str[1])
                doc_type = DOCTYPE_FUNCTION
            else
                doc_type = DOCTYPE_STRUCT
            end
        elseif f isa Module
            doc_type = DOCTYPE_MODULE
        else
            doc_type = DOCTYPE_CONSTANT
        end
        
        # Separate exported from private
        if n in exported_names
            push!(exported, n => doc_type)
        else
            push!(private, n => doc_type)
        end
    end
    
    order = Dict(
        DOCTYPE_MODULE => 0,
        DOCTYPE_MACRO => 1,
        DOCTYPE_FUNCTION => 2,
        DOCTYPE_ABSTRACT_TYPE => 3,
        DOCTYPE_STRUCT => 4,
        DOCTYPE_CONSTANT => 5,
    )
    sort_fn = x -> (order[x[2]], "$(x[1])")
    return (exported=sort(exported; by=sort_fn), private=sort(private; by=sort_fn))
end

function _iterate_over_symbols(f, config, symbol_list)
    current_module = config.current_module
    for (key, type) in sort!(symbol_list; by = config.sort_by)
        if key isa Symbol
            if key in config.exclude
                continue
            end
            doc = Base.Docs.doc(Base.Docs.Binding(current_module, key))
            missing_doc = doc === nothing || occursin("No documentation found.", string(doc))
            if missing_doc
                if type == DOCTYPE_MODULE
                    mod = getfield(current_module, key)
                    if mod == current_module || !haskey(config.modules, mod)
                        @warn "No documentation found for module $key in $(current_module). Skipping from API reference."
                        continue
                    end
                else
                    @warn "No documentation found for $key in $(current_module). Skipping from API reference."
                    continue
                end
            end
        end
        f(key, type)
    end
    return
end

function _to_string(x::DocType)
    if x == DOCTYPE_ABSTRACT_TYPE
        return "abstract type"
    elseif x == DOCTYPE_CONSTANT
        return "constant"
    elseif x == DOCTYPE_FUNCTION
        return "function"
    elseif x == DOCTYPE_MACRO
        return "macro"
    elseif x == DOCTYPE_MODULE
        return "module"
    elseif x == DOCTYPE_STRUCT
        return "struct"
    end
end

function _build_api_page(document::Documenter.Document, config::_Config)
    subdir = config.subdirectory
    current_module = config.current_module
    symbols = _exported_symbols(current_module)
    
    # Build Public API page
    public_overview = """
    # Public API

    This page lists the **exported** symbols of `$(current_module)`.

    Load all public symbols into the current scope with:
    ```julia
    using $(current_module)
    ```
    Alternatively, load only the module with:
    ```julia
    import $(current_module)
    ```
    and then prefix all calls with `$(current_module).` to create
    `$(current_module).<NAME>`.
    """
    public_docstrings = String[]
    _iterate_over_symbols(config, symbols.exported) do key, type
        if type == DOCTYPE_MODULE
            return
        end
        push!(
            public_docstrings,
            "## `$key`\n\n```@docs\n$(current_module).$key\n```\n\n",
        )
        return
    end
    public_md = Markdown.parse(public_overview * join(public_docstrings, "\n"))
    public_filename = "$subdir/public.md"
    document.blueprint.pages[public_filename] = Documenter.Page(
        joinpath(document.user.source, public_filename),
        joinpath(document.user.build, public_filename),
        document.user.build,
        public_md.content,
        Documenter.Globals(),
        convert(MarkdownAST.Node, public_md),
    )
    
    # Build Private API page
    private_overview = """
    ```@meta
    EditURL = nothing
    ```

    # Private API

    This page lists the **non-exported** (internal) symbols of `$(current_module)`.

    Access these symbols with:
    ```julia
    import $(current_module)
    $(current_module).<NAME>
    ```
    """
    private_docstrings = String[]
    _iterate_over_symbols(config, symbols.private) do key, type
        if type == DOCTYPE_MODULE
            return
        end
        push!(
            private_docstrings,
            "## `$key`\n\n```@docs\n$(current_module).$key\n```\n\n",
        )
        return
    end
    private_md = Markdown.parse(private_overview * join(private_docstrings, "\n"))
    private_filename = "$subdir/private.md"
    document.blueprint.pages[private_filename] = Documenter.Page(
        joinpath(document.user.source, private_filename),
        joinpath(document.user.build, private_filename),
        document.user.build,
        private_md.content,
        Documenter.Globals(),
        convert(MarkdownAST.Node, private_md),
    )
    
    return
end

function Documenter.Selectors.runner(
    ::Type{APIBuilder},
    document::Documenter.Document,
)
    @info "APIBuilder: creating API reference"
    for config in CONFIG
        _build_api_page(document, config)
    end
    return
end

end  # module
