# Test Performance Profile
# ═══════════════════════════════════════════════════════════════════════════════

using Statistics

function test_performance_profile()

    # ───────────────────────────────────────────────────────────────────────────
    # Struct Tests
    # ───────────────────────────────────────────────────────────────────────────

    @testset "ProfileCriterion" begin
        criterion = CTBenchmarks.ProfileCriterion{Float64}(
            "Test Criterion",
            row -> row.time,
            (a, b) -> a <= b
        )
        @test criterion.name == "Test Criterion"
        @test criterion.value isa Function
        @test criterion.better isa Function
        @test criterion.better(1.0, 2.0) == true
        @test criterion.better(2.0, 1.0) == false
    end

    @testset "PerformanceProfileConfig" begin
        criterion = CTBenchmarks.ProfileCriterion{Float64}(
            "CPU time",
            row -> row.time,
            (a, b) -> a <= b
        )
        config = CTBenchmarks.PerformanceProfileConfig{Float64}(
            [:problem, :grid_size],
            [:model, :solver],
            criterion,
            row -> row.success == true,
            row -> true,
            xs -> mean(xs)
        )
        @test config.instance_cols == [:problem, :grid_size]
        @test config.solver_cols == [:model, :solver]
        @test config.criterion === criterion
    end

    # ───────────────────────────────────────────────────────────────────────────
    # Registry Tests
    # ───────────────────────────────────────────────────────────────────────────

    @testset "PerformanceProfileRegistry" begin
        registry = CTBenchmarks.PerformanceProfileRegistry()
        @test isempty(CTBenchmarks.list_profiles(registry))

        criterion = CTBenchmarks.ProfileCriterion{Float64}(
            "Test",
            row -> row.time,
            (a, b) -> a <= b
        )
        config1 = CTBenchmarks.PerformanceProfileConfig{Float64}(
            [:problem],
            [:solver],
            criterion,
            row -> true,
            row -> true,
            xs -> mean(xs)
        )
        config2 = CTBenchmarks.PerformanceProfileConfig{Float64}(
            [:problem],
            [:model],
            criterion,
            row -> true,
            row -> true,
            xs -> mean(xs)
        )

        # Basic registration
        CTBenchmarks.register!(registry, "profile1", config1)
        @test "profile1" in CTBenchmarks.list_profiles(registry)
        @test length(CTBenchmarks.list_profiles(registry)) == 1
        @test CTBenchmarks.get_config(registry, "profile1") === config1

        # Multiple registration
        CTBenchmarks.register!(registry, "profile2", config2)
        @test "profile1" in CTBenchmarks.list_profiles(registry)
        @test "profile2" in CTBenchmarks.list_profiles(registry)
        @test length(CTBenchmarks.list_profiles(registry)) == 2
        @test CTBenchmarks.get_config(registry, "profile2") === config2

        # Overwrite registration
        CTBenchmarks.register!(registry, "profile1", config2)
        @test CTBenchmarks.get_config(registry, "profile1") === config2
        @test length(CTBenchmarks.list_profiles(registry)) == 2

        # Error cases
        @test_throws KeyError CTBenchmarks.get_config(registry, "nonexistent")
    end

    # ───────────────────────────────────────────────────────────────────────────
    # Data Loading Tests
    # ───────────────────────────────────────────────────────────────────────────

    @testset "load_benchmark_df" begin
        # Test with DataFrame passthrough
        df = DataFrame(a=[1, 2, 3], b=[4, 5, 6])
        result = CTBenchmarks.load_benchmark_df(df)
        @test result === df

        # Test with Dict
        data = Dict("results" => [Dict("a" => 1, "b" => 2), Dict("a" => 3, "b" => 4)])
        result = CTBenchmarks.load_benchmark_df(data)
        @test result isa DataFrame
        @test nrow(result) == 2

        # Test with Dict missing "results" key
        data_empty = Dict("other" => [1, 2, 3])
        @test_nowarn result = CTBenchmarks.load_benchmark_df(data_empty)
        @test result isa DataFrame
        @test nrow(result) == 0

        # Test with malformed data (not a vector of dicts)
        data_bad = Dict("results" => "not_a_vector")
        @test_throws ArgumentError CTBenchmarks.load_benchmark_df(data_bad)
    end

    # ───────────────────────────────────────────────────────────────────────────
    # Build Profile Tests
    # ───────────────────────────────────────────────────────────────────────────

    @testset "build_profile_from_df" begin
        # Create mock benchmark data
        df = DataFrame(
            problem=["prob1", "prob1", "prob1", "prob1", "prob2", "prob2", "prob2", "prob2"],
            grid_size=[100, 100, 100, 100, 100, 100, 100, 100],
            model=["exa", "exa", "jump", "jump", "exa", "exa", "jump", "jump"],
            solver=["ipopt", "madnlp", "ipopt", "madnlp", "ipopt", "madnlp", "ipopt", "madnlp"],
            success=[true, true, true, true, true, true, true, true],
            time=[1.0, 1.5, 2.0, 1.8, 1.2, 1.4, 2.2, 2.0]
        )

        criterion = CTBenchmarks.ProfileCriterion{Float64}(
            "CPU time (s)",
            row -> row.time,
            (a, b) -> a <= b
        )
        config = CTBenchmarks.PerformanceProfileConfig{Float64}(
            [:problem, :grid_size],
            [:model, :solver],
            criterion,
            row -> row.success == true,
            row -> true,
            xs -> mean(xs)
        )

        pp = CTBenchmarks.build_profile_from_df(df, "test_bench", config)

        @test pp !== nothing
        @test pp isa CTBenchmarks.PerformanceProfile{Float64}
        @test pp.bench_id == "test_bench"
        @test pp.total_problems == 2  # prob1 and prob2 at grid_size 100
        @test length(pp.combos) == 4  # 4 solver/model combinations
        @test pp.max_ratio >= pp.min_ratio

        # Test safety contract: Missing columns
        df_bad = select(df, Not(:solver))
        @test_throws ArgumentError CTBenchmarks.build_profile_from_df(df_bad, "bad_bench", config)
    end

    @testset "build_profile_from_df with allowed_combos" begin
        df = DataFrame(
            problem=["prob1", "prob1", "prob1"],
            grid_size=[100, 100, 100],
            model=["exa", "exa", "jump"],
            solver=["ipopt", "madnlp", "ipopt"],
            success=[true, true, true],
            time=[1.0, 1.5, 2.0]
        )

        criterion = CTBenchmarks.ProfileCriterion{Float64}(
            "CPU time",
            row -> row.time,
            (a, b) -> a <= b
        )
        config = CTBenchmarks.PerformanceProfileConfig{Float64}(
            [:problem, :grid_size],
            [:model, :solver],
            criterion,
            row -> row.success == true,
            row -> true,
            xs -> mean(xs)
        )

        # Filter to only exa solvers
        pp = CTBenchmarks.build_profile_from_df(
            df, "test_bench", config;
            allowed_combos=[("exa", "ipopt"), ("exa", "madnlp")]
        )

        @test pp !== nothing
        @test length(pp.combos) == 2
    end

    # ───────────────────────────────────────────────────────────────────────────
    # Analysis Tests
    # ───────────────────────────────────────────────────────────────────────────

    @testset "analyze_performance_profile" begin
        df = DataFrame(
            problem=["prob1", "prob1"],
            grid_size=[100, 100],
            model=["exa", "jump"],
            solver=["ipopt", "ipopt"],
            success=[true, true],
            time=[1.0, 2.0]
        )

        criterion = CTBenchmarks.ProfileCriterion{Float64}(
            "CPU time",
            row -> row.time,
            (a, b) -> a <= b
        )
        config = CTBenchmarks.PerformanceProfileConfig{Float64}(
            [:problem, :grid_size],
            [:model, :solver],
            criterion,
            row -> row.success == true,
            row -> true,
            xs -> mean(xs)
        )

        pp = CTBenchmarks.build_profile_from_df(df, "test_bench", config)
        analysis = CTBenchmarks.analyze_performance_profile(pp)

        @test analysis isa String
        @test occursin("Performance Profile Analysis", analysis)
        @test occursin("test_bench", analysis)
        @test occursin("Robustness", analysis)
        @test occursin("Efficiency", analysis)
    end

    # ───────────────────────────────────────────────────────────────────────────
    # Plot Tests (basic - just check it returns a plot)
    # ───────────────────────────────────────────────────────────────────────────

    @testset "plot_performance_profile" begin
        df = DataFrame(
            problem=["prob1", "prob1"],
            grid_size=[100, 100],
            model=["exa", "jump"],
            solver=["ipopt", "ipopt"],
            success=[true, true],
            time=[1.0, 2.0]
        )

        criterion = CTBenchmarks.ProfileCriterion{Float64}(
            "CPU time",
            row -> row.time,
            (a, b) -> a <= b
        )
        config = CTBenchmarks.PerformanceProfileConfig{Float64}(
            [:problem, :grid_size],
            [:model, :solver],
            criterion,
            row -> row.success == true,
            row -> true,
            xs -> mean(xs)
        )

        pp = CTBenchmarks.build_profile_from_df(df, "test_bench", config)
        plt = CTBenchmarks.plot_performance_profile(pp)

        @test plt isa Plots.Plot
    end

end
