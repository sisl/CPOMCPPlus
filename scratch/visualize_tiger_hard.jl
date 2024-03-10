using CPOMCPPlusExperiments
using D3Trees
using Plots 

using Debugger
using ProgressMeter
using Distributed
using Random
using Infiltrator

# global parameters
tree_queries = Int(1e6)
k_observation = 5.
alpha_observation = 1/15
enable_action_pw = false 
max_depth = 5 
c = 90 
nu = 0.0
asched = 0.5
update_filter_size = Int(1e4)
pf_filter_size = 10

tree_in_info = true
search_progress_info = true

### Find Good Settings
kwargs = Dict(
    :tree_queries=>pft_tree_queries,
    :max_depth => max_depth,
    :c=>c,
    :nu=>nu, 
    :alpha_schedule => CPOMCPPlusExperiments.CPOMCP.ConstantAlphaSchedule(asched),
    :tree_in_info=>tree_in_info,
    :search_progress_info=>search_progress_info,
)

runs = [false, true, false]

plus_flag = false

if runs[2]
    
    cpomdp = CTigerExtended()

    nsims = 1

    @showprogress 1 for i = 1:nsims
        solver = CPOMCPPlusExperiments.CPOMCPSolver(;kwargs..., rng = MersenneTwister(i), plus_flag)

        updater(planner) = CPOMCPPlusExperiments.CPOMCP.CPOMCPBudgetUpdateWrapper(
            CPOMCPPlusExperiments.ParticleFilters.BootstrapFilter(cpomdp, update_filter_size, solver.rng), 
            planner)
    
        hist4, R4, C4, RC4 = run_cpomdp_simulation(cpomdp, solver, updater, 5)
    
        inchrome(D3Tree(hist4[1][:tree]))
    end
end 