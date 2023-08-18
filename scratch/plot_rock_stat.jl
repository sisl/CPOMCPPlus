using Statistics
using Infiltrator
using FileIO
using Plots
# should run after compiling everything.

function load_this_data(file_name::String)
    load_data = load(file_name)
    R, C = (load_data["R"], load_data["C"])
    return R, C
end

struct SolverType
    flag::Bool
    Rs::Vector{Any}
    Cs::Vector{Any}
    as::Vector{Any}
    expRs::Vector{Any}
    expCs::Vector{Any}
    lambdas::Vector{Any}
    ns::Vector{Any}
    function SolverType(flag::Bool=false)
        new(flag, Vector{Any}(), Vector{Any}(), Vector{Any}(), Vector{Any}(), Vector{Any}(), Vector{Any}(), Vector{Any}())
    end
end

cpomdp = RockSampleCPOMDP(bad_rock_budget=2.)
rsize = cpomdp.pomdp.map_size
nsims = 150 
tree_queries = [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000]
plus_flag = [true, false]
plotting_for = "CPOMCPOW"
Plus = SolverType(true)
Minus = SolverType(false)
Solvers = [Plus, Minus]

for solver in Solvers
    for tq in tree_queries
        file_name = "results/additional_data/$(plotting_for)rocksample$(rsize)_plf:$(solver.flag)_$(nsims)_sims_tq$(tq)_additional.jld2"
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
savefig(p, "figs/rocksample_figs$rsize/$(plotting_for)_averageR_nsims=$(nsims).png")
Plots.CURRENT_PLOT.nullableplot = nothing
savefig(c, "figs/rocksample_figs$rsize/$(plotting_for)_averageC_nsims=$(nsims).png")
Plots.CURRENT_PLOT.nullableplot = nothing
savefig(p_SE, "figs/rocksample_figs$rsize/$(plotting_for)_averageR_SE_nsims=$(nsims).png")
Plots.CURRENT_PLOT.nullableplot = nothing
savefig(c_SE, "figs/rocksample_figs$rsize/$(plotting_for)_averageC_SE_nsims=$(nsims).png")
Plots.CURRENT_PLOT.nullableplot = nothing