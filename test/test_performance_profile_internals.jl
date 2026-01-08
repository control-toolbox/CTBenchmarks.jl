using Test
using DataFrames
using Statistics
using CTBenchmarks

function test_performance_profile_internals()
    @testset "Performance Profile Internals" begin
        # Mock data
        data = Dict(
            "results" => [
                Dict("problem" => "p1", "grid_size" => 10, "model" => "exa", "solver" => "ipopt", "time" => 1.0, "success" => true),
                Dict("problem" => "p1", "grid_size" => 10, "model" => "exa", "solver" => "ab", "time" => 2.0, "success" => true),
                Dict("problem" => "p1", "grid_size" => 10, "model" => "exb", "solver" => "ipopt", "time" => 0.5, "success" => true),
                Dict("problem" => "p1", "grid_size" => 20, "model" => "exa", "solver" => "ipopt", "time" => 10.0, "success" => true),
                Dict("problem" => "p1", "grid_size" => 20, "model" => "exa", "solver" => "ab", "time" => NaN, "success" => false),
                # Duplicate run for aggregation test
                Dict("problem" => "p2", "grid_size" => 10, "model" => "exa", "solver" => "ipopt", "time" => 1.0, "success" => true),
                Dict("problem" => "p2", "grid_size" => 10, "model" => "exa", "solver" => "ipopt", "time" => 1.2, "success" => true),
            ]
        )
        df = DataFrame(data["results"])

        # Config
        cpu_criterion = CTBenchmarks.ProfileCriterion{Float64}(
            "CPU time (s)",
            row -> get(row, "time", NaN),
            (a, b) -> a <= b
        )
        config = CTBenchmarks.PerformanceProfileConfig{Float64}(
            [:problem, :grid_size],
            [:model, :solver],
            cpu_criterion,
            row -> row.success == true,
            row -> true,
            xs -> Statistics.mean(skipmissing(xs))
        )

        @testset "_filter_benchmark_data" begin
            # Test basic filtering
            filtered = CTBenchmarks._filter_benchmark_data(df, config, nothing)
            @test nrow(filtered) == 6 # One failure removed

            # Test allowed combos
            allowed = [("exa", "ipopt")]
            filtered_restricted = CTBenchmarks._filter_benchmark_data(df, config, allowed)
            @test nrow(filtered_restricted) == 4 # Only (exa, ipopt) rows
            @test all(r -> (r.model == "exa" && r.solver == "ipopt"), eachrow(filtered_restricted))
        end

        @testset "_extract_benchmark_metrics" begin
            filtered = CTBenchmarks._filter_benchmark_data(df, config, nothing)
            with_metrics = CTBenchmarks._extract_benchmark_metrics(filtered, config)
            @test "metric" in names(with_metrics)
            @test with_metrics[1, :metric] == 1.0
        end

        @testset "_aggregate_metrics" begin
            # Filter and extract first
            filtered = CTBenchmarks._filter_benchmark_data(df, config, nothing)
            with_metrics = CTBenchmarks._extract_benchmark_metrics(filtered, config)

            aggregated = CTBenchmarks._aggregate_metrics(with_metrics, config)

            # Check aggregation for p2 (1.0 and 1.2 -> mean 1.1)
            p2_row = filter(r -> r.problem == "p2" && r.grid_size == 10, aggregated)
            @test nrow(p2_row) == 1
            @test p2_row[1, :metric] ≈ 1.1

            # Check non-duplicated rows exist
            p1_row = filter(r -> r.problem == "p1" && r.grid_size == 10 && r.solver == "ipopt" && r.model == "exa", aggregated)
            @test nrow(p1_row) == 1
            @test p1_row[1, :metric] == 1.0
        end

        @testset "_compute_dolan_more_ratios" begin
            # Prep data
            filtered = CTBenchmarks._filter_benchmark_data(df, config, nothing)
            metrics = CTBenchmarks._extract_benchmark_metrics(filtered, config)
            agg = CTBenchmarks._aggregate_metrics(metrics, config)

            ratios = CTBenchmarks._compute_dolan_more_ratios(agg, config)

            # p1, 10: exa/ipopt=1.0, exa/ab=2.0, exb/ipopt=0.5 -> best is 0.5
            # Ratios should be: 1.0/0.5=2.0, 2.0/0.5=4.0, 0.5/0.5=1.0

            sub = filter(r -> r.problem == "p1" && r.grid_size == 10, ratios)

            sol1 = filter(r -> r.model == "exb", sub)[1, :]
            @test sol1.ratio == 1.0
            @test sol1.best_metric == 0.5

            sol2 = filter(r -> r.model == "exa" && r.solver == "ipopt", sub)[1, :]
            @test sol2.ratio == 2.0

            sol3 = filter(r -> r.model == "exa" && r.solver == "ab", sub)[1, :]
            @test sol3.ratio == 4.0
        end

        @testset "_compute_profile_metadata" begin
            filtered = CTBenchmarks._filter_benchmark_data(df, config, nothing)
            metrics = CTBenchmarks._extract_benchmark_metrics(filtered, config)
            agg = CTBenchmarks._aggregate_metrics(metrics, config)
            ratios = CTBenchmarks._compute_dolan_more_ratios(agg, config)

            combos, min_r, max_r = CTBenchmarks._compute_profile_metadata(ratios, config)

            @test length(combos) == 3 # (exa, ipopt), (exa, ab), (exb, ipopt)
            @test "(exb, ipopt)" in combos
            @test min_r == 1.0
            @test max_r == 4.0
        end
        @testset "_compute_curve_points" begin
            # N=2 problems
            total_matches = 2

            # Case 1: ratios = [1.0, 2.0]
            # y(1.0) = count(<=1.0)/2 = 0.5
            # y(2.0) = count(<=2.0)/2 = 1.0
            x, y = CTBenchmarks._compute_curve_points([1.0, 2.0], total_matches)
            @test x == [1.0, 2.0]
            @test y == [0.5, 1.0]

            # Case 2: ratios = [1.0, 1.0, 2.0] (multiple solvers fastest on same pb)
            # y(1.0) = 2/2 = 1.0
            # y(2.0) = 3/2 = 1.5
            x2, y2 = CTBenchmarks._compute_curve_points([1.0, 1.0, 2.0], total_matches)
            @test x2 == [1.0, 1.0, 2.0]
            @test y2 == [1.0, 1.0, 1.5]
        end
    end
end
