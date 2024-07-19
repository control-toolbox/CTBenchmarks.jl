module JMPProblems

using JuMP

path = dirname(@__FILE__)

files = filter(x -> x[(end - 2):end] == ".jl", readdir(path))
for file in files
    if file ≠ "JMPProblems.jl"
        include(file)
    end
end

function_JMP = Dict{Symbol, Function}()
all_names = names(JMPProblems, all=true)
functions_list = filter(x -> isdefined(JMPProblems, x) && isa(getfield(JMPProblems, x), Function) && endswith(string(x), "_JMP"), all_names)
for f in functions_list
    key = Symbol(lowercase(replace(string(f), "_JMP" => "")))
    function_JMP[key] = JMPProblems.eval(f)
end

end