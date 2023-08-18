using Statistics
using Infiltrator
using FileIO
using Plots
pgfplotsx()

function load_that_data(file_name::String)
    load_data = load(file_name)
    R, C = (load_data["R"], load_data["C"])
    expR, expC = (load_data["expR"], load_data["expC"])
    a, lambda, n = (load_data["a_indx"], load_data["lambda"], load_data["n"])
    return R, C, a, expR, expC, lambda, n
end

struct SolverTypeCombo
    flag::Bool
    Rs::Vector{Any}
    Cs::Vector{Any}
    as::Vector{Any}
    expRs::Vector{Any}
    expCs::Vector{Any}
    lambdas::Vector{Any}
    ns::Vector{Any}
    function SolverTypeCombo(flag::Bool=false)
        new(flag, Vector{Any}(), Vector{Any}(), Vector{Any}(), Vector{Any}(), Vector{Any}(), Vector{Any}(), Vector{Any}())
    end
end

function lightDark()
    nsims = 100
    tree_queries = [10, 100000.0, 150000.0, 200000.0, 250000.0, 300000.0, 350000.0, 400000.0, 450000.0, 550000.0, 600000.0] 
    plus_flag = [true, false]

    Plus = SolverTypeCombo(true)
    Minus = SolverTypeCombo(false)
    Solvers = [Plus, Minus]

    for solver in Solvers
        for tq in tree_queries
            file_name = "results/additional_data/ldnew_plf$(solver.flag)_$(nsims)_sims_tq$(tq)_additional.jld2"
            R, C, a, expR, expC, lambda, n = load_that_data(file_name)
            push!(solver.Rs, R)
            push!(solver.Cs, C)
            push!(solver.as, a)
            push!(solver.expRs, expR)
            push!(solver.expCs, expC)
            push!(solver.lambdas, lambda)
            push!(solver.ns, n)
        end
    end

    α = 1.4
    Plots.scalefontsizes(α)
    ###Performance Metrics###
    xtick_values = [3e5, 6e5]
    p_SE = plot(ylabel = "discounted R", xlabel = "simulations", xticks=xtick_values)
    c_SE = plot(ylabel = "discounted C", xlabel = "simulations", legend=:outertop, legend_columns=-1, xticks=xtick_values)
    for solver in Solvers
        #Average Discounted Cumulative Reward vs Iteration
        means = [Statistics.mean(iters) for iters in solver.Rs]
        stds = [Statistics.std(iters) for iters in solver.Rs]
        SEs = stds / sqrt(nsims)
        if solver.flag == true
            color = :blue
            solver_label = ""
        else
            color = :red
            solver_label = ""
        end
        plot!(p_SE, tree_queries, means, linecolor=color, label="")
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

    hline!(c_SE, [0.1], line=:dash, label="", linecolor=:green)
    infiltrate
    x = plot(c_SE, p_SE,  layout=grid(2, 1), size=(500,500))
    return p_SE,c_SE
end
