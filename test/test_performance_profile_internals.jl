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

            # Test generic filtering with different solver_cols
            config_gen = CTBenchmarks.PerformanceProfileConfig{Float64}(
                [:problem],
                [:model],
                config.criterion,
                row -> true,
                row -> true,
                xs -> Statistics.mean(xs)
            )
            allowed_gen = [("exb",)]
            filtered_gen = CTBenchmarks._filter_benchmark_data(df, config_gen, allowed_gen)
            @test nrow(filtered_gen) == 1
            @test filtered_gen[1, :model] == "exb"
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

            # Edge case: 0.0 metric (best = 0.0)
            df0 = DataFrame(
                problem=["p1", "p1"],
                grid_size=[10, 10],
                model=["m1", "m2"],
                solver=["s1", "s2"],
                metric=[1.0, 0.0]
            )
            ratios0 = CTBenchmarks._compute_dolan_more_ratios(df0, config)
            @test ratios0[1, :ratio] == Inf
            @test ratios0[2, :ratio] == 1.0

            # Edge case: All Fail (Inf)
            dfinf = DataFrame(
                problem=["p1", "p1"],
                grid_size=[10, 10],
                model=["m1", "m2"],
                solver=["s1", "s2"],
                metric=[Inf, Inf]
            )
            ratiosinf = CTBenchmarks._compute_dolan_more_ratios(dfinf, config)
            @test all(isnan.(ratiosinf.ratio))
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
        @testset "_validate_benchmark_df" begin
            # Valid case
            @test_nowarn CTBenchmarks._validate_benchmark_df(df, config)

            # Missing instance column
            df_bad = select(df, Not(:problem))
            @test_throws ArgumentError CTBenchmarks._validate_benchmark_df(df_bad, config)

            # Missing solver column
            df_bad2 = select(df, Not(:solver))
            @test_throws ArgumentError CTBenchmarks._validate_benchmark_df(df_bad2, config)
        end

        @testset "compute_profile_stats" begin
            # 1. Ties: multiple solvers are best
            df_ties = DataFrame(
                problem=["p1", "p1", "p1"],
                grid_size=[10, 10, 10],
                model=["m1", "m2", "m3"],
                solver=["s1", "s1", "s1"],
                ratio=[1.0, 1.0, 2.0],
                best_metric=[1.0, 1.0, 1.0],
                combo=["(m1, s1)", "(m2, s1)", "(m3, s1)"]
            )
            pp_ties = CTBenchmarks.PerformanceProfile(
                "ties",
                DataFrame(problem=["p1"], grid_size=[10]),
                df_ties,
                ["(m1, s1)", "(m2, s1)", "(m3, s1)"],
                1, 1.0, 2.0, config
            )
            stats = CTBenchmarks.compute_profile_stats(pp_ties)

            # Efficiency at ratio 1.0 (in %)
            eff = stats.performances
            @test filter(p -> p.combo == "(m1, s1)", eff)[1].efficiency == 100.0
            @test filter(p -> p.combo == "(m2, s1)", eff)[1].efficiency == 100.0
            @test filter(p -> p.combo == "(m3, s1)", eff)[1].efficiency == 0.0

            # 2. Total failure: one instance, no success
            # Note: build_profile_from_df would return nothing, but we test the stats logic
            df_fail_ratios = DataFrame(
                problem=["p1"], grid_size=[10], model=["m1"], solver=["s1"],
                ratio=[NaN], best_metric=[Inf], combo=["(m1, s1)"]
            )
            pp_fail = CTBenchmarks.PerformanceProfile(
                "fail",
                DataFrame(problem=["p1"], grid_size=[10]),
                DataFrame(problem=String[], grid_size=Int[]), # Empty but has columns
                ["(m1, s1)"],
                1, 1.0, 1.0, config
            )

            stats_fail = CTBenchmarks.compute_profile_stats(pp_fail)
            # Success rate 0% for fail test (empty df_successful for that combo)
            @test stats_fail.performances[1].robustness == 0.0
        end
    end
end
