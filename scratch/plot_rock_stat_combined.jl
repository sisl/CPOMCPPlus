using Statistics
using Infiltrator
using FileIO
using Plots
pgfplotsx()
include("plot_ld_stat_combined.jl")

function load_this_data(file_name::String)
    load_data = load(file_name)
    R, C = (load_data["R"], load_data["C"])
    return R, C 
end

struct SolverTypeRockCombo
    flag::Bool
    Rs::Vector{Any}
    Cs::Vector{Any}
    as::Vector{Any}
    expRs::Vector{Any}
    expCs::Vector{Any}
    lambdas::Vector{Any}
    ns::Vector{Any}
    function SolverTypeRockCombo(flag::Bool=false)
        new(flag, Vector{Any}(), Vector{Any}(), Vector{Any}(), Vector{Any}(), Vector{Any}(), Vector{Any}(), Vector{Any}())
    end
end

nsims = 150 
tree_queries = [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000]
plus_flag = [true, false]
plotting_for = "CPOMCPOW"
Plus = SolverTypeRockCombo(true)
Minus = SolverTypeRockCombo(false)
Solvers = [Plus, Minus]

for solver in Solvers
    for tq in tree_queries
        file_name = "results/rock_cbud2/CPOMCPOWrocksample(7, 8)_plf_$(solver.flag)_$(nsims)_sims_tq$(tq)_additional.jld2"
        R, C = load_this_data(file_name)
        push!(solver.Rs, R)
        push!(solver.Cs, C)
    end
end

l_R, l_C = lightDark()
###Performance Metrics###
p_SE = plot(ylabel = "discounted R", xlabel = "simulations")#, xticks=xtick_values) #title = "Average Reward w/ Standard Dev", 
c_SE = plot(ylabel = "discounted C", xlabel = "simulations", legend=:topright, legend_background_color=:transparent, fg_legend = :transparent, legendfontsize=13)#, title = "Constrained RockSample", titlefontsize = 13) #legend_columns=-1, , xguidefontsize=13, yguidefontsize=13)#, xticks=xtick_values, ) #title = "Average Cost w/ Standard Dev", 

for solver in Solvers
    if solver.flag == true
        color = :blue
        solver_label = "CPOMCPOW+"
    else
        color = :red
        solver_label = "CPOMCPOW"
    end
    #Average Discounted Cumulative Reward vs Iteration
    means = [Statistics.mean(iters) for iters in solver.Rs]
    stds = [Statistics.std(iters) for iters in solver.Rs]
    SEs = stds / sqrt(nsims)
    plot!(p_SE, tree_queries, means, linecolor=color, label="") #label = "Solver $(solver.flag)",
    plot!(p_SE, tree_queries, means-SEs, fillrange=means+SEs, fillalpha=0.3, label="", linecolor=nothing, fillcolor=color)
    #Average Discounted Cumulative Cost vs Iteration
    meansC = [Statistics.mean(iters) for iters in solver.Cs]
    meansC = reduce(vcat, meansC)
    stdsC = [Statistics.std(iters) for iters in solver.Cs]
    stdsC = reduce(vcat, stdsC)
    SEsC = stdsC / sqrt(nsims)
    plot!(c_SE, tree_queries, meansC, linecolor=color, label = solver_label)
    plot!(c_SE, tree_queries, meansC-SEsC, fillrange=meansC+SEsC, fillalpha=0.3, label="", linecolor=nothing, fillcolor=color)
end
hline!(c_SE, [2.0], line=:dash, label="constraint budget", linecolor=:green)
rock = plot(c_SE, p_SE, layout=grid(1,2))
ld = plot(l_C, l_R , layout=grid(1,2))
sqr = plot(rock, ld, layout=grid(2,1), size=(700,500))

@infiltrate
