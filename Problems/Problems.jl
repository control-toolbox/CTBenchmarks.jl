module Problems

using JuMP
using OptimalControl
using CTProblems

list_of_problems_JuMP = "JuMP/" .* [
    "goddard_JMP.jl"
]

list_of_problems_OptimalControl = "OptimalControl/" .* [
    "goddard_OC.jl"
]


for (index, filename) in enumerate(list_of_problems_JuMP)
    try
        include("$filename")
    catch e 
        println("$filename : Unable to find the file")
    end
end

for (index, filename) in enumerate(list_of_problems_OptimalControl)
    try
        include("$filename")
    catch e 
        println("$filename : Unable to find the file")
    end
end

end