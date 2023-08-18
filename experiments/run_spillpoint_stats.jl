using CPOMCPPlusExperiments
using Infiltrator
using ProgressMeter
using Distributed
using Random
using POMDPs, CPOMDPs
using SpillpointPOMDP
using FileIO

nsims = 10
run = [true]

rbc = false 

max_steps=25 
k_observation = 10. 
alpha_observation = 0.3
max_depth = 10 
c = 30.0
nu = 0.0
asched = 10000.
update_filter_size = Int(1e4) 
pf_filter_size = 10 
init_lam = [1000.]
tree_in_info = true
search_progress_info = true

if run[1] # POMCPOW

    for constraint_budget in [0.0, 0.1, 0.2, 0.3, 0.4]
        cpomdp = SpillpointInjectionCPOMDP(constraint_budget=constraint_budget)
        mc = max_clip(cpomdp)
        default_updater = CPOMCPPlusExperiments.SpillpointPOMDP.SIRParticleFilter(
            model=cpomdp,  
            N=200, 
            state2param=CPOMCPPlusExperiments.SpillpointPOMDP.state2params, 
            param2state=CPOMCPPlusExperiments.SpillpointPOMDP.params2state,
            N_samples_before_resample=100,
            clampfn=CPOMCPPlusExperiments.SpillpointPOMDP.clamp_distribution,
            fraction_prior = .5,
            prior=CPOMCPPlusExperiments.SpillpointPOMDP.param_distribution(
                CPOMCPPlusExperiments.initialstate(cpomdp)),
            elite_frac=0.3,
            bandwidth_scale=.5,
            max_cpu_time=20 #60 FIXME 
        )

        for tree_queries in [1e2, 3e2, 5e3, 7e2, 9e2, 11e2]
            for plf in [true, false]

                kwargs = Dict(
                    :tree_queries=>tree_queries, 
                    :k_observation => k_observation, 
                    :alpha_observation => alpha_observation, 
                    :check_repeat_obs => false,
                    :check_repeat_act => false,
                    :max_depth => max_depth,
                    :criterion=>CPOMCPPlusExperiments.CPOMCPOW.MaxCUCB(c, nu), 
                    :alpha_schedule => CPOMCPPlusExperiments.CPOMCPOW.ConstantAlphaSchedule(asched),
                    :init_λ=>init_lam,
                    :estimate_value=>QMDP_V,
                    :tree_in_info=>tree_in_info,
                    :max_clip => mc
                )
                first_vals = []
                exp1 = ExperimentResults(nsims)
                @showprogress 1  for i = 1:nsims
                    Random.seed!(i)
                    solver = CPOMCPPlusExperiments.CPOMCPOWSolver(;kwargs..., rng = MersenneTwister(i),search_progress_info = search_progress_info, return_best_cost=rbc,plus_flag=plf)
                    updater(planner) = CPOMCPPlusExperiments.CPOMCPOW.CPOMCPOWBudgetUpdateWrapper(default_updater, planner)
                    hist, R, C, RC, first_val = run_cpomdp_simulation(cpomdp, solver, updater, max_steps;track_history=false)
                    exp1[i] = hist, R, C, RC
                    push!(first_vals, first_val)
                end
                Vr = exp1.Rs
                Vc = [reduce(vcat, vec) for vec in exp1.Cs]
                first_actions = [run[1].a for run in first_vals]
                guessedR = [run[1].v_taken_first for run in first_vals]
                guessedC = reduce(vcat, [run[1].cv_taken_first for run in first_vals])
                lambdas = reduce(vcat, [run[1].lambda_first for run in first_vals])

                print_and_save(exp1,"results/spillpoint_pomcpow_$(nsims)sims.jld2")
                file_name = "results/spill/spill_plf$(plf)_sims$(nsims)_tq$(tree_queries)_cb$(constraint_budget).jld2"
                save_data = Dict(
                    "R"=>Vr, "C"=> Vc, "a"=>first_actions, "expR"=>guessedR,
                    "expC"=>guessedC, "lambda"=>lambdas
                )

                FileIO.save(file_name,save_data)
            end
        end
    end
end