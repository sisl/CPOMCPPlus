using Statistics
using Infiltrator
using FileIO
using Plots

function load_this_data(file_name::String)
    load_data = load(file_name)
    R, C = (load_data["R"], load_data["C"])
    expR, expC = (load_data["expR"], load_data["expC"])
    a, lambda, n = (load_data["a_indx"], load_data["lambda"], load_data["n"])
    return R, C, a, expR, expC, lambda, n
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

nsims = 100
tree_queries = [10, 100000.0, 150000.0, 200000.0, 250000.0, 300000.0, 350000.0, 400000.0, 450000.0, 550000.0, 600000.0] 
plus_flag = [true, false]

Plus = SolverType(true)
Minus = SolverType(false)
Solvers = [Plus, Minus]

for solver in Solvers
    for tq in tree_queries
        file_name = "results/additional_data/LightDark/ldnew_plf$(solver.flag)_$(nsims)_sims_tq$(tq)_additional.jld2"
        R, C, a, expR, expC, lambda, n = load_this_data(file_name)
        push!(solver.Rs, R)
        push!(solver.Cs, C)
        push!(solver.as, a)
        push!(solver.expRs, expR)
        push!(solver.expCs, expC)
        push!(solver.lambdas, lambda)
        push!(solver.ns, n)
    end
end

###Performance Metrics###
p = plot(title = "Average Reward w/ Standard Dev", ylabel = "R", xlabel = "Tree Queries")
c = plot(title = "Average Cost w/ Standard Dev", ylabel = "C", xlabel = "Tree Queries")
p_SE = plot(title = "Average Reward w/ Standard Dev", ylabel = "R", xlabel = "Tree Queries")
c_SE = plot(title = "Average Cost w/ Standard Dev", ylabel = "C", xlabel = "Tree Queries")
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


###Safety Metrics###
#Episodes with Cost Violations (%)
c_budget = 0.1
passed_c = scatter(title = "Episodes with Cost Violations (%)", ylabel = "Percent", xlabel = "Tree Queries")
for solver in Solvers
    pass_Cthresh = [count(C -> C[1] > c_budget, iters) for iters in solver.Cs]
    percent = 100 * pass_Cthresh / nsims
    scatter!(passed_c, tree_queries, percent, label = "Solver $(solver.flag)")
end
    
string_tq = ["$tq" for tq in tree_queries]

#Plus vs Minus
#First step chosen
actiontoind = []
actions = [-10, -5, -1, 0, 1, 5, 10]
for (ind, i) in enumerate(actions)
    push!(actiontoind, ind)
end

fa = bar(title = "Percent Taken First Step", ylabel = "Percent", xlabel = "Action")
string_a = ["$a" for a in actions]
tq_interest = 600000.0

for solver in Solvers
    println(solver.flag)    
    for (idx, tq) in enumerate(solver.as)
        if tree_queries[idx] == tq_interest
            a_cnt = []
            for action in actiontoind
                push!(a_cnt, 100 * count(x -> x == action, tq) / nsims)
            end
            bar!(fa, string_a, a_cnt,  fillalpha = 0.5, label = "Tq $(tree_queries[idx]), Flg $(solver.flag)")
        end
    end
end
savefig(fa, "figs/additional_figs/CPOMCPOW_perc_taken_first_action_tq$(tq_interest)_nsims=$(nsims).png")
Plots.CURRENT_PLOT.nullableplot = nothing

#Number of searches first step all actions (visualized 2 ways)
plot_a = []
for a in actions
    push!(plot_a, a*ones(nsims))
end

n = bar(title = "Percent Search First Step", ylabel = "Percent", xlabel = "Action")
n_s = scatter(title = "Number Searches First Step", ylabel = "Total Searches", xlabel = "Action")
string_a = ["$a" for a in actions]       

tq_interest = tq_interest
for solver in Solvers   
    for (idx, tq) in enumerate(solver.ns)
        if tree_queries[idx] == tq_interest
            matrix = transpose(hcat(reduce(vcat,tq)...))
            mean_n = [100 * Statistics.mean(col) ./ tree_queries[idx] for col in eachcol(matrix)]
            data_a = [col for col in eachcol(matrix)]

            bar!(n, string_a, mean_n,  fillalpha = 0.5, label = "Tq $(tree_queries[idx]), Flg $(solver.flag)")
            scatter!(n_s, reduce(vcat,plot_a), reduce(vcat,data_a), label = "Tq $(tree_queries[idx]), Flg $(solver.flag)")
        end
    end
end