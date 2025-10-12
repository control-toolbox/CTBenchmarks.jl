using CUDA

function test_utils()
    
    # ===== Test 1: solve_and_extract_data with different models =====
    println("\n=== Testing solve_and_extract_data ===")
    
    # Test JuMP model
    println("Testing JuMP model...")
    stats_jump = CTBenchmarks.solve_and_extract_data(
        :beam, :ipopt, :JuMP, 50, :trapeze, 1e-8, "adaptive", 0, 1000, 500.0
    )
    @test stats_jump isa NamedTuple
    @test haskey(stats_jump, :benchmark)
    @test haskey(stats_jump, :objective)
    @test haskey(stats_jump, :iterations)
    @test haskey(stats_jump, :status)
    @test haskey(stats_jump, :success)
    # Check that solve actually worked (not just error handling)
    @test haskey(stats_jump.benchmark, :time)
    @test haskey(stats_jump.benchmark, :alloc)
    @test haskey(stats_jump.benchmark, :bytes)
    @test !isnan(stats_jump.benchmark.time)
    @test stats_jump.benchmark.alloc > 0
    @test stats_jump.benchmark.bytes > 0
    @test !ismissing(stats_jump.objective)
    @test !ismissing(stats_jump.iterations)

    # ===== Test 2: generate_metadata =====
    println("\n=== Testing generate_metadata ===")
    meta = CTBenchmarks.generate_metadata()
    @test meta isa Dict
    for key in ("timestamp", "julia_version", "os", "machine", "pkg_status", "versioninfo", "pkg_manifest")
        @test haskey(meta, key)
        value = meta[key]
        @test value isa AbstractString
        @test !isempty(strip(value))
    end

    # Test adnlp model
    println("Testing adnlp model...")
    stats_adnlp = CTBenchmarks.solve_and_extract_data(
        :beam, :ipopt, :adnlp, 50, :trapeze, 1e-8, "adaptive", 0, 1000, 500.0
    )
    @test stats_adnlp isa NamedTuple
    @test haskey(stats_adnlp, :status)
    @test haskey(stats_adnlp, :success)
    @test !isnan(stats_adnlp.benchmark.time)
    @test stats_adnlp.benchmark.alloc > 0
    @test !ismissing(stats_adnlp.objective)
    
    # Test exa model
    println("Testing exa model...")
    stats_exa = CTBenchmarks.solve_and_extract_data(
        :beam, :ipopt, :exa, 50, :trapeze, 1e-8, "adaptive", 0, 1000, 500.0
    )
    @test stats_exa isa NamedTuple
    @test haskey(stats_exa, :status)
    @test haskey(stats_exa, :success)
    @test !isnan(stats_exa.benchmark.time)
    @test stats_exa.benchmark.alloc > 0
    @test !ismissing(stats_exa.objective)
    
    # Test with MadNLP (missing mu_strategy)
    println("Testing with MadNLP...")
    stats_madnlp = CTBenchmarks.solve_and_extract_data(
        :beam, :madnlp, :JuMP, 50, :trapeze, 1e-8, missing, MadNLP.ERROR, 1000, 500.0
    )
    @test stats_madnlp isa NamedTuple
    @test haskey(stats_madnlp, :status)
    @test haskey(stats_madnlp, :success)
    @test !isnan(stats_madnlp.benchmark.time)
    @test stats_madnlp.benchmark.alloc > 0
    @test !ismissing(stats_madnlp.objective)
    
    # Test assertion: exa_gpu requires madnlp
    println("Testing exa_gpu assertion...")
    @test_throws AssertionError CTBenchmarks.solve_and_extract_data(
        :beam, :ipopt, :exa_gpu, 50, :trapeze, 1e-8, "adaptive", 0, 1000, 500.0
    )

    if CUDA.functional()
        println("Testing exa_gpu model with CUDA...")
        stats_exa_gpu = CTBenchmarks.solve_and_extract_data(
            :beam, :madnlp, :exa_gpu, 20, :trapeze, 1e-8, missing, MadNLP.ERROR, 200, 120.0
        )

        @test stats_exa_gpu isa NamedTuple
        @test haskey(stats_exa_gpu, :benchmark)
        @test haskey(stats_exa_gpu, :status)
        @test haskey(stats_exa_gpu, :success)

        bench_gpu = stats_exa_gpu.benchmark

        getval(obj, key::Symbol) = isa(obj, Dict) ? get(obj, key, get(obj, string(key), nothing)) : getproperty(obj, key)
        hasval(obj, key::Symbol) = isa(obj, Dict) ? (haskey(obj, key) || haskey(obj, string(key))) : Base.hasproperty(obj, key)

        @test hasval(bench_gpu, :time)
        @test hasval(bench_gpu, :cpu_bytes)
        @test hasval(bench_gpu, :gpu_bytes)

        @test !isnan(getval(bench_gpu, :time))
        @test getval(bench_gpu, :cpu_bytes) >= 0
        @test getval(bench_gpu, :gpu_bytes) >= 0
        @test stats_exa_gpu.success isa Bool
    else
        println("Skipping exa_gpu model test because CUDA is not functional.")
    end
    
    # ===== Test 2: benchmark_data with multiple configurations =====
    println("\n=== Testing benchmark_data ===")
    
    # Test with 2 problems, 2 solvers with their models, 2 grid sizes
    # Expected rows: 2 problems × (3 ipopt models + 3 madnlp models) × 2 grid_sizes = 24
    println("Testing with multiple configurations...")
    df = benchmark_data(
        problems = [:beam, :chain],
        solver_models = [
            :ipopt => [:JuMP, :adnlp, :exa],
            :madnlp => [:JuMP, :adnlp, :exa]
        ],
        grid_sizes = [50, 100],
        disc_methods = [:trapeze],
        tol = 1e-8,
        ipopt_mu_strategy = "adaptive",
        ipopt_print_level = 0,
        madnlp_print_level = MadNLP.ERROR,
        max_iter = 1000,
        max_wall_time = 500.0
    )
    
    # Check DataFrame type
    @test df isa DataFrames.DataFrame
    
    # Check number of rows: 2 problems × 2 solvers × 3 models × 2 grid_sizes = 24
    @test nrow(df) == 24
    
    # Check that all expected columns exist
    expected_columns = [:problem, :solver, :model, :disc_method, :grid_size, 
                       :tol, :mu_strategy, :print_level, :benchmark, 
                       :objective, :iterations, :status, :success]
    @test all(col in names(df) for col in string.(expected_columns))
    
    # Check that all problems are present
    @test Set(df.problem) == Set([:beam, :chain])
    
    # Check that all solvers are present
    @test Set(df.solver) == Set([:ipopt, :madnlp])
    
    # Check that all models are present
    @test Set(df.model) == Set([:JuMP, :adnlp, :exa])
    
    # Check that all grid sizes are present
    @test Set(df.grid_size) == Set([50, 100])
    
    # Check mu_strategy: should be string for ipopt, missing for madnlp
    ipopt_rows = df[df.solver .== :ipopt, :]
    madnlp_rows = df[df.solver .== :madnlp, :]
    @test all(.!ismissing.(ipopt_rows.mu_strategy))
    @test all(ismissing.(madnlp_rows.mu_strategy))
    
    # Check that status and success columns exist and have values
    @test all(.!isnothing.(df.status))
    @test all(isa.(df.success, Bool))
    
    # Check that solves actually worked (not all errors)
    @test all(row -> !isnan(row.benchmark.time), eachrow(df))
    @test all(row -> row.benchmark.alloc > 0, eachrow(df))
    @test all(row -> row.benchmark.bytes > 0, eachrow(df))
    @test all(.!ismissing.(df.objective))
    @test all(.!ismissing.(df.iterations))
    
    # ===== Test 3: benchmark_data with subset of models =====
    println("\n=== Testing with subset of models ===")
    
    # Test with only 1 problem, 1 solver, 2 models, 1 grid size
    # Expected rows: 1 * 1 * 2 * 1 = 2
    df_subset = benchmark_data(
        problems = [:beam],
        solver_models = [
            :ipopt => [:JuMP, :adnlp]
        ],
        grid_sizes = [50],
        disc_methods = [:trapeze],
        tol = 1e-8,
        ipopt_mu_strategy = "adaptive",
        ipopt_print_level = 0,
        madnlp_print_level = MadNLP.ERROR,
        max_iter = 1000,
        max_wall_time = 500.0
    )
    
    @test nrow(df_subset) == 2
    @test Set(df_subset.model) == Set([:JuMP, :adnlp])
    @test all(df_subset.problem .== :beam)
    @test all(df_subset.solver .== :ipopt)
    @test all(df_subset.grid_size .== 50)
    
    println("\n=== All tests passed! ===")

end
