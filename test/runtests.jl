using Test
using Aqua
using CTBenchmarks

#
@testset verbose = true showtiming = true "CTBenchmarks tests" begin
    for name in (:aqua, :default)
        @testset "$(name)" begin
            test_name = Symbol(:test_, name)
            include("$(test_name).jl")
            @eval $test_name()
        end
    end
end
