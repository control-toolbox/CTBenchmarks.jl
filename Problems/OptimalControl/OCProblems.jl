module OCProblems

using OptimalControl

path = dirname(@__FILE__)

files = filter(x -> x[(end - 2):end] == ".jl", readdir(path))
for file in files
    if file ≠ "OCProblems.jl"
        include(file)
    end
end

end