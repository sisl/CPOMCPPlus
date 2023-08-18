using Statistics
using Infiltrator
using FileIO
using Plots
#using PlotlyJS

function load_this_data(file_name::String)
    load_data = load(file_name)
    R, C = (load_data["R"], load_data["C"])
    expR, expC = (load_data["expR"], load_data["expC"])
    a, lambda= (load_data["a"], load_data["lambda"])
    return R, C, a, expR, expC, lambda
end

struct SolverTypeSpill
    flag::Bool
    Rs::Vector{Any}
    Cs::Vector{Any}
    as::Vector{Any}
    expRs::Vector{Any}
    expCs::Vector{Any}
    lambdas::Vector{Any}
    function SolverTypeSpill(flag::Bool=false)
        new(flag, Vector{Any}(), Vector{Any}(), Vector{Any}(), Vector{Any}(), Vector{Any}(), Vector{Any}())
    end
end

nsims = 10
tree_queries = [1e2, 3e2, 5e2, 7e2, 1e3]
plus_flag = [true, false]

Plus = SolverTypeSpill(true)
Minus = SolverTypeSpill(false)
Solvers = [Plus, Minus]

cost_budget = 0.0

for solver in Solvers
    for tq in tree_queries
        file_name = "results/spill/spill_plf$(solver.flag)_sims$(nsims)_tq$(tq)_cb$(cost_budget).jld2"
        R, C, a, expR, expC, lambda = load_this_data(file_name)
        push!(solver.Rs, R)
        push!(solver.Cs, C)
        push!(solver.as, a)
        push!(solver.expRs, expR)
        push!(solver.expCs, expC)
        push!(solver.lambdas, lambda)
    end   

end

###Performance Metrics###
for solver in Solvers
    #Average Discounted Cumulative Reward vs Iteration
    means = [Statistics.mean(iters) for iters in solver.Rs]
    stds = [Statistics.std(iters) for iters in solver.Rs]
    SEs = stds / sqrt(nsims)
    #Average Discounted Cumulative Cost vs Iteration
    meansC = [Statistics.mean(iters) for iters in solver.Cs]
    meansC = reduce(vcat, meansC)
    stdsC = [Statistics.std(iters) for iters in solver.Cs]
    stdsC = reduce(vcat, stdsC)
    SEsC = stdsC / sqrt(nsims)
end