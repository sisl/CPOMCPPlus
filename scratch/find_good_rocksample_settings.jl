using CPOMCPPlusExperiments
using D3Trees
using Infiltrator
using Plots 

### Find Good Settings
max_steps= 100
tree_queries = Int(1500) 
pft_tree_queries = Int(1e3)
k_observation = 10.
alpha_observation = 0.3
tree_in_info = true
search_progress_info = true
max_depth = 100
c = 30.0
nu = 0.0
asched = 13. #10000.
update_filter_size = Int(1e4)
pf_filter_size = 10
init_lam = [1000.]
plf = false
rbc = false

println("plus flag is $plf")

runs = [true, false, false]

if runs[1] # POMCP
    kwargs =  Dict(
            :tree_queries=>pft_tree_queries,
            :search_progress_info => search_progress_info,
            :tree_in_info => tree_in_info,
            :max_depth => max_depth,
            :c=>c,
            :nu=>nu, 
            :alpha_schedule => CPOMCPPlusExperiments.CPOMCP.ConstantAlphaSchedule(asched),
            :estimate_value=>QMDP_V,
            :plus_flag=>plf,
        )
    cpomdp = RockSampleCPOMDP(bad_rock_budget=2.)
    solver = CPOMCPPlusExperiments.CPOMCPSolver(;kwargs...)
    updater(planner) = CPOMCPPlusExperiments.CPOMCP.CPOMCPBudgetUpdateWrapper(
        CPOMCPPlusExperiments.ParticleFilters.BootstrapFilter(cpomdp, update_filter_size, solver.rng), 
        planner)
    hist4, R4, C4, RC4, f_v = run_cpomdp_simulation(cpomdp, solver, updater, max_steps;track_history=true)

    println(R4)
    println(C4[1])
    println(RC4)
    sp4 = SearchProgress(hist4[1])
    
    plot(sp4.lambda)
    title!("Lambda plot, tree_queries=$(pft_tree_queries), plf=$(plf)")
    savefig("figs/rocksample/CPOMCP_lambdaplot_treq=$(pft_tree_queries)_RBC=$(rbc)_plf=$(plf).png")
    Plots.CURRENT_PLOT.nullableplot = nothing
end 

if runs[2]
    kwargs = Dict(
        :tree_queries=>tree_queries, 
        :k_observation => k_observation, 
        :alpha_observation => alpha_observation, 
        :check_repeat_obs => true,
        :check_repeat_act => true,
        :max_depth => max_depth,
        :criterion=>CPOMCPPlusExperiments.CPOMCPOW.MaxCUCB(c, nu), 
        :alpha_schedule => CPOMCPPlusExperiments.CPOMCPOW.ConstantAlphaSchedule(asched),
        :init_λ=>init_lam,
        :plus_flag=>plf,
        :tree_in_info=>tree_in_info,
        :search_progress_info=>search_progress_info,
        :estimate_value=>QMDP_V,
    )
    cpomdp = RockSampleCPOMDP(bad_rock_budget=1.)
    solver = CPOMCPPlusExperiments.CPOMCPOWSolver(;kwargs..., return_best_cost=rbc, plus_flag=plf)
    updater(planner) = CPOMCPPlusExperiments.CPOMCPOW.CPOMCPOWBudgetUpdateWrapper(
        CPOMCPPlusExperiments.ParticleFilters.BootstrapFilter(cpomdp, Int(1e4), solver.rng), 
        planner)
    hist4, R4, C4, RC4, f_v = run_cpomdp_simulation(cpomdp, solver, updater, max_steps)

    println(R4)
    println(C4[1])
    println(RC4)
    inchrome(D3Tree(hist4[1][:tree], title="CPOMCPOW Tree For rocksample, lambda prop = $plf"))

    sp4 = SearchProgress(hist4[1])

    plot(sp4.lambda)
    title!("Lambda plot, tree_queries=$(tree_queries), plf=$(plf)")
    savefig("figs/rocksample/CPOMCPOW_lambdaplot_treq=$(tree_queries)_RBC=$(rbc)_plf=$(plf).png")
    Plots.CURRENT_PLOT.nullableplot = nothing
end 