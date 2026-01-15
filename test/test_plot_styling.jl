# ============================================================================
# UNIT TESTS: Variadic Color and Marker Functions
# ============================================================================

"""
Test suite for variadic get_color and get_marker_style functions.

These tests ensure that the plotting functions can handle any number of
solver parameters (2, 3, or more), preventing regressions when using
different solver column configurations like [:model, :solver] or
[:disc_method, :solver].
"""
function test_plot_styling()
    @testset "get_color variadic versions" begin
        # Test 2-parameter version (original)
        @test CTBenchmarks.get_color(:exa, :ipopt, 1) == :tomato
        @test CTBenchmarks.get_color(:adnlp, :madnlp, 1) == :seagreen
        @test CTBenchmarks.get_color(:trapeze, :ipopt, 1) == :steelblue
        @test CTBenchmarks.get_color(:midpoint, :madnlp, 1) == :darkorange

        # Test variadic version with 2 parameters
        @test CTBenchmarks.get_color([:exa, :ipopt], 1) == :tomato
        @test CTBenchmarks.get_color([:adnlp, :madnlp], 1) == :seagreen
        @test CTBenchmarks.get_color([:trapeze, :ipopt], 1) == :steelblue
        @test CTBenchmarks.get_color([:midpoint, :madnlp], 1) == :darkorange

        # Test variadic version with 3+ parameters (uses first two)
        @test CTBenchmarks.get_color([:exa, :ipopt, :extra], 1) == :tomato
        @test CTBenchmarks.get_color([:model, :solver, :disc_method], 1) isa Symbol

        # Test variadic version with 1 parameter (fallback to palette)
        @test CTBenchmarks.get_color([:single], 1) isa Symbol
        @test CTBenchmarks.get_color([:single], 2) isa Symbol

        # Test error on empty parameters
        @test_throws ErrorException CTBenchmarks.get_color(Symbol[], 1)
    end

    @testset "get_marker_style variadic versions" begin
        # Test 2-parameter version (original)
        @test CTBenchmarks.get_marker_style(:exa, :ipopt, 1) == :square
        @test CTBenchmarks.get_marker_style(:adnlp, :madnlp, 1) == :diamond
        @test CTBenchmarks.get_marker_style(:trapeze, :ipopt, 1) == :circle
        @test CTBenchmarks.get_marker_style(:midpoint, :madnlp, 1) == :utriangle

        # Test variadic version with 2 parameters
        @test CTBenchmarks.get_marker_style([:exa, :ipopt], 1) == :square
        @test CTBenchmarks.get_marker_style([:adnlp, :madnlp], 1) == :diamond
        @test CTBenchmarks.get_marker_style([:trapeze, :ipopt], 1) == :circle
        @test CTBenchmarks.get_marker_style([:midpoint, :madnlp], 1) == :utriangle

        # Test variadic version with 3+ parameters
        @test CTBenchmarks.get_marker_style([:exa, :ipopt, :extra], 1) == :square
        @test CTBenchmarks.get_marker_style([:model, :solver, :disc_method], 1) isa Symbol

        # Test variadic version with 1 parameter
        @test CTBenchmarks.get_marker_style([:single], 1) isa Symbol

        # Test error on empty parameters
        @test_throws ErrorException CTBenchmarks.get_marker_style(Symbol[], 1)
    end

    @testset "get_marker_style with grid_size" begin
        # Test 3-parameter version (original)
        marker, interval = CTBenchmarks.get_marker_style(:exa, :ipopt, 1, 200)
        @test marker == :square
        @test interval == 33  # 200 ÷ 6

        # Test variadic version with grid_size
        marker2, interval2 = CTBenchmarks.get_marker_style([:exa, :ipopt], 1, 200)
        @test marker2 == :square
        @test interval2 == 33

        # Test with different grid sizes
        _, interval_small = CTBenchmarks.get_marker_style([:exa, :ipopt], 1, 10)
        @test interval_small == 1  # max(1, 10 ÷ 6)

        _, interval_large = CTBenchmarks.get_marker_style([:exa, :ipopt], 1, 600)
        @test interval_large == 100  # 600 ÷ 6
    end
end

# ============================================================================
# INTEGRATION TESTS: Performance Profile Plotting with Different Solver Columns
# ============================================================================

"""
Integration tests for plot_performance_profile with different solver column configurations.

These tests verify that the plotting system works correctly with:
- Standard [:model, :solver] columns
- Alternative [:disc_method, :solver] columns
- Future-proof: 3+ column configurations
"""
function test_plot_performance_profile_solver_columns()
    @testset "plot_performance_profile with [:model, :solver] columns" begin
        # Create test data with standard columns
        df = DataFrame(
            problem=[:prob1, :prob1, :prob2, :prob2],
            grid_size=[100, 100, 100, 100],
            model=[:exa, :adnlp, :exa, :adnlp],
            solver=[:ipopt, :ipopt, :ipopt, :ipopt],
            success=[true, true, true, true],
            benchmark=[(time=0.1,), (time=0.15,), (time=0.2,), (time=0.25,)],
        )

        criterion = CTBenchmarks.ProfileCriterion{Float64}(
            "CPU time (s)", row -> get(row.benchmark, :time, NaN), (a, b) -> a <= b
        )

        config = CTBenchmarks.PerformanceProfileConfig{Float64}(
            [:problem, :grid_size],
            [:model, :solver],  # Standard columns
            criterion,
            row -> row.success == true && !ismissing(row.benchmark),
            row -> true,
            xs -> Statistics.mean(skipmissing(xs)),
        )

        pp = CTBenchmarks.build_profile_from_df(df, "test", config)
        @test pp !== nothing

        # Test that plotting doesn't error
        plt = CTBenchmarks.plot_performance_profile(pp)
        @test plt isa Plots.Plot
    end

    @testset "plot_performance_profile with [:disc_method, :solver] columns" begin
        # Create test data with discretization method columns
        df = DataFrame(
            problem=[:prob1, :prob1, :prob2, :prob2],
            grid_size=[200, 200, 200, 200],
            disc_method=[:trapeze, :midpoint, :trapeze, :midpoint],
            solver=[:ipopt, :ipopt, :madnlp, :madnlp],
            model=[:exa, :exa, :exa, :exa],  # Present but not used in solver_cols
            success=[true, true, true, true],
            benchmark=[(time=0.1,), (time=0.12,), (time=0.15,), (time=0.18,)],
        )

        criterion = CTBenchmarks.ProfileCriterion{Float64}(
            "CPU time (s)", row -> get(row.benchmark, :time, NaN), (a, b) -> a <= b
        )

        config = CTBenchmarks.PerformanceProfileConfig{Float64}(
            [:problem, :grid_size],
            [:disc_method, :solver],  # Alternative columns
            criterion,
            row -> row.success == true && !ismissing(row.benchmark),
            row -> true,
            xs -> Statistics.mean(skipmissing(xs)),
        )

        pp = CTBenchmarks.build_profile_from_df(df, "midpoint-trapeze", config)
        @test pp !== nothing
        @test length(pp.combos) >= 2  # At least trapeze and midpoint combinations

        # Test that plotting doesn't error (this was the bug!)
        plt = CTBenchmarks.plot_performance_profile(pp)
        @test plt isa Plots.Plot
    end

    @testset "Helper functions: _prepare_combo_data and _get_combo_styling" begin
        # Create minimal test profile
        df = DataFrame(
            problem=[:p1, :p1],
            grid_size=[100, 100],
            disc_method=[:trapeze, :midpoint],
            solver=[:ipopt, :ipopt],
            success=[true, true],
            benchmark=[(time=0.1,), (time=0.15,)],
        )

        criterion = CTBenchmarks.ProfileCriterion{Float64}(
            "CPU time (s)", row -> get(row.benchmark, :time, NaN), (a, b) -> a <= b
        )

        config = CTBenchmarks.PerformanceProfileConfig{Float64}(
            [:problem, :grid_size],
            [:disc_method, :solver],
            criterion,
            row -> row.success == true && !ismissing(row.benchmark),
            row -> true,
            xs -> Statistics.mean(skipmissing(xs)),
        )

        pp = CTBenchmarks.build_profile_from_df(df, "test", config)
        @test pp !== nothing

        # Test _prepare_combo_data
        combo = pp.combos[1]
        ratios = CTBenchmarks._prepare_combo_data(pp, combo)
        @test ratios !== nothing
        @test ratios isa Vector{Float64}
        @test length(ratios) > 0

        # Test _get_combo_styling
        color, marker = CTBenchmarks._get_combo_styling(pp, combo, 1)
        @test color isa Symbol
        @test marker isa Symbol
    end
end
