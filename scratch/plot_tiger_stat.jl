using Statistics
using Infiltrator
using FileIO
using Plots

function load_this_data(file_name::String)
    load_data = load(file_name)
    R, C = (load_data["R"], load_data["C"])
    expR, expC = (load_data["expR"], load_data["expC"])
    a, lambda, n = (load_data["a"], load_data["lambda"], load_data["n"])

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
tree_queries = [12, 13, 100.0, 1000.0, 2000.0, 4000.0, 6000.0, 8000.0, 10000.0]
plus_flag = [true, false]

Plus = SolverType(true)
Minus = SolverType(false)
Solvers = [Plus, Minus]

Rs = []
Cs = []
as= []
expRs = []
expCs = []
lambdas = []
ns = []

for solver in Solvers
    for tq in tree_queries
        file_name = "results/additional_data/Tiger/tiger_cpomcp_$(solver.flag)pf_$(nsims)sims_$(tq)tq.jld2"
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
    #plot!(c, tree_queries, meansC-stdsC, fillrange=meansC+stdsC, fillalpha=0.5, label="95% CI")
end

###Safety Metrics###
#Episodes with Cost Violations (%)
c_budget = 0.9
passed_c = scatter(title = "Episodes with Cost Violations (%)", ylabel = "Percent", xlabel = "Tree Queries")
for solver in Solvers
    pass_Cthresh = [count(C -> C[1] > c_budget, iters) for iters in solver.Cs]
    percent = 100 * pass_Cthresh / nsims
    scatter!(passed_c, tree_queries, percent, label = "Solver $(solver.flag)")
end

string_tq = ["$tq" for tq in tree_queries]

#Plus vs Minus
#First step chosen

actions = [0 1 2]
actiontoind = [0 1 2]

fa = bar(title = "Percent Taken First Step", ylabel = "Percent", xlabel = "Action")
string_a = []
for a in actions #had to change this to make the type compatible with a_cnt for bar graph
    push!(string_a, "$a")
end

tq_interest = 1000

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

#Number of searches first step all actions (visualized 2 ways)
plot_a = []
for a in actions
    push!(plot_a, a*ones(nsims))
end

n = bar(title = "Percent Search First Step", ylabel = "Percent", xlabel = "Action")
n_s = scatter(title = "Number Searches First Step", ylabel = "Total Searches", xlabel = "Action")   

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


