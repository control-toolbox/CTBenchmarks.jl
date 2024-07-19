module OCProblems

using OptimalControl

path = dirname(@__FILE__)

files = filter(x -> x[(end - 2):end] == ".jl", readdir(path))
for file in files
    if file ≠ "OCProblems.jl"
        include(file)
    end
end

function_OC = Dict{Symbol, Function}()
all_names = names(OCProblems, all=true)
functions_list = filter(x -> isdefined(OCProblems, x) && isa(getfield(OCProblems, x), Function) && endswith(string(x), "_OC"), all_names)
for f in functions_list
    key = Symbol(lowercase(replace(string(f), "_OC" => "")))
    function_OC[key] = OCProblems.eval(f)
end

function_init = Dict{Symbol, Function}()
functions_list = filter(x -> isdefined(OCProblems, x) && isa(getfield(OCProblems, x), Function) && endswith(string(x), "_init"), all_names)
for f in functions_list
    key = Symbol(lowercase(replace(string(f), "_init" => "")))
    function_init[key] = OCProblems.eval(f)
end


end