using JuMP, NLPModelsJuMP, NLPModels, OptimalControl, SparseArrays

include("./particle_JMP.jl")
nh=3

jump_model = dielectrophoretic_particle_JMP(; nh=nh)
nlp_model = MathOptNLPModel(jump_model)
println(get_x0(nlp_model))
rows, cols = hess_structure(nlp_model)
nnz_nlp = length(rows)
vals = ones(Int64, nnz_nlp)
nvar = MOI.get(jump_model, MOI.NumberOfVariables());
H = sparse(rows, cols, vals, nvar, nvar)
display(H)

include("./particle_OC.jl")

opt_model = dielectrophoretic_particle_OC()
init = dielectrophoretic_particle_init(; nh=nh)
nlp = get_nlp(direct_transcription(opt_model; grid_size=nh, init=init))
println(get_x0(nlp))
rows, cols = hess_structure(nlp)
nnz_nlp = length(rows)
vals = ones(Int64, nnz_nlp)
nvar = nlp.meta.nvar
H = sparse(rows, cols, vals, nvar, nvar)
display(H)
