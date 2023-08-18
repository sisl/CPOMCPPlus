using Statistics
using Infiltrator
using FileIO
using Plots

function load_this_data(file_name::String)
    load_data = load(file_name)
    R, C = (load_data["R"], load_data["C"])
    return R, C
end

struct SolverTypeRock
    flag::Bool
    Rs::Vector{Any}
    Cs::Vector{Any}
    as::Vector{Any}
    expRs::Vector{Any}
    expCs::Vector{Any}
    lambdas::Vector{Any}
    ns::Vector{Any}
    function SolverTypeRock(flag::Bool=false)
        new(flag, Vector{Any}(), Vector{Any}(), Vector{Any}(), Vector{Any}(), Vector{Any}(), Vector{Any}(), Vector{Any}())
    end
end

nsims = 150 
tree_queries = [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000]
plus_flag = [true, false]
plotting_for = "CPOMCPOW"
Plus = SolverTypeRock(true)
Minus = SolverTypeRock(false)
Solvers = [Plus, Minus]

for solver in Solvers
    for tq in tree_queries
        file_name = "results/rock_cbud2/CPOMCPOWrocksample(7, 8)_plf_$(solver.flag)_$(nsims)_sims_tq$(tq)_additional.jld2"
        R, C = load_this_data(file_name)
        push!(solver.Rs, R)
        push!(solver.Cs, C)
    end
end

###Performance Metrics###
p = plot(title = "Average Reward w/ Standard Dev", ylabel = "R", xlabel = "Tree Queries")
c = plot(title = "Average Cost w/ Standard Dev", ylabel = "C", xlabel = "Tree Queries")
p_SE = plot(title = "Average Reward w/ Standard Error", ylabel = "R", xlabel = "Tree Queries")
c_SE = plot(title = "Average Cost w/ Standard Error", ylabel = "C", xlabel = "Tree Queries")
for solver in Solvers
    #Average Discounted Cumulative Reward vs Iteration
    means = [Statistics.mean(iters) for iters in solver.Rs]
    stds = [Statistics.std(iters) for iters in solver.Rs]
    SEs = stds / sqrt(nsims)
    plot!(p, tree_queries, means, yerr = stds, label = "Solver $(solver.flag)")
    plot!(p_SE, tree_queries, means, yerr = SEs, label = "Solver $(solver.flag)")
    #Average Discounted Cumulative Cost vs Iteration
    meansC = [Statistics.mean(iters) for iters in solver.Cs]
    meansC = reduce(vcat, meansC)
    stdsC = [Statistics.std(iters) for iters in solver.Cs]
    stdsC = reduce(vcat, stdsC)
    SEsC = stdsC / sqrt(nsims)
    plot!(c, tree_queries, meansC, yerr = stdsC, label = "Solver $(solver.flag)") 
    plot!(c_SE, tree_queries, meansC, yerr = SEsC, label = "Solver $(solver.flag)") 
end
