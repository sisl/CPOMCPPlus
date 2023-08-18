using Revise
using CPOMCPPlusExperiments
using Infiltrator
using ProgressMeter
using FileIO
using Statistics
using Distributed
using RockSample
using Random
using DataFrames

nsims = 3
run = [true, true, false]

cpomdp = RockSampleCPOMDP(bad_rock_budget=2.)

# global parameters
rsize = cpomdp.pomdp.map_size
max_steps= 100
tree_queries = Int(1500) 
pft_tree_queries = Int(300)
k_observation = 10.
alpha_observation = 0.3
tree_in_info = true
search_progress_info = false
max_depth = 100
c = 30.0
nu = 0.0
asched = 4.
update_filter_size = Int(1e4)
pf_filter_size = 10
init_lam = [1000.]
plf = false

println("Plus Flag set to $plf")
if run[1] # POMCPOW
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
        :estimate_value=>QMDP_V,
    )
    first_vals = []
    exp1 = LightExperimentResults(nsims)
    @showprogress 1 for i = 1:nsims
        Random.seed!(i)
        solver = CPOMCPPlusExperiments.CPOMCPOWSolver(;kwargs..., rng = MersenneTwister(i))
        default_updater = CPOMCPPlusExperiments.ParticleFilters.BootstrapFilter(cpomdp, update_filter_size, solver.rng)
        updater(planner) = CPOMCPPlusExperiments.CPOMCPOW.CPOMCPOWBudgetUpdateWrapper(default_updater, planner)
        hist, R, C, RC, f_v = run_cpomdp_simulation(cpomdp, solver, updater, max_steps;track_history=true)
        exp1[i] = hist, R, C, RC
        push!(first_vals, f_v)
    end
    print_and_save(exp1,"results/rocksample_pomcpow_$(nsims)sims.jld2")
end

if run[2] # POMCP
    kwargs = Dict(
        :tree_queries=>pft_tree_queries,
        :max_depth => max_depth,
        :c=>c,
        :nu=>nu, 
        :alpha_schedule => CPOMCPPlusExperiments.CPOMCP.ConstantAlphaSchedule(asched),
        :estimate_value=>QMDP_V,
        :plus_flag=>plf,
    )
    exp2 = LightExperimentResults(nsims)
    first_vals = []
    @showprogress 1 for i = 1:nsims
        Random.seed!(i)
        solver = CPOMCPPlusExperiments.CPOMCPSolver(;kwargs..., rng = MersenneTwister(i))
        updater(planner) = CPOMCPPlusExperiments.CPOMCP.CPOMCPBudgetUpdateWrapper(
            CPOMCPPlusExperiments.ParticleFilters.BootstrapFilter(cpomdp, update_filter_size, solver.rng), 
            planner)
        hist, R, C, RC, f_v = run_cpomdp_simulation(cpomdp, solver, updater, max_steps;track_history=true)
        exp2[i] = hist, R, C, RC
        push!(first_vals, f_v)
    end
    
    println("CPOMCP")
    print_and_save(exp2,"results/rocksample_pomcp_$(nsims)sims.jld2")
end