function test_run()
    @testset "run saves JSON outputs" begin
        build_dir = joinpath(@__DIR__, "build")
        mkpath(build_dir)

        minimal_path = joinpath(build_dir, "run-minimal.json")
        complete_path = joinpath(build_dir, "run-complete.json")

        for path in (minimal_path, complete_path)
            isfile(path) && rm(path; force=true)
        end

        try
            CTBenchmarks.run(:minimal; filepath=minimal_path)
            @test isfile(minimal_path)

            # CTBenchmarks.run(:complete; filepath=complete_path)
            # @test isfile(complete_path)
        finally
            for path in (minimal_path, complete_path)
                isfile(path) && rm(path; force=true)
            end
        end
    end
end
