using CPOMCPPlusExperiments
using Infiltrator
using ProgressMeter
using Distributed
using Statistics
using Random
using FileIO
using Plots
using DataFrames

nsims = 100
run = [true] #(pomcpow)

cpomdp = CLightDarkNew(cost_budget=0.1)

# global parameters
k_observation = 5.
alpha_observation = 1/15
tree_in_info = true
enable_action_pw = false
max_depth = 10
c = 90.0
nu = 0.0
search_progress_info = true
asched = 0.5
update_filter_size = Int(1e4)
pf_filter_size = 10
mc = max_clip(cpomdp)
return_best_cost = false

for plus_flag in [true, false]
    for tree_queries in [10e1, 1e5, 1.5e5, 2e5, 2.5e5, 3e5, 3.5e5, 4e5, 4.5e5, 5.5e5, 6e5]
        if run[1] # POMCPOW

            kwargs = Dict(
                :tree_queries=>Int(tree_queries), 
                :k_observation => k_observation,
                :alpha_observation => alpha_observation, 
                :enable_action_pw => false,
                :check_repeat_obs => false,
                :max_depth => max_depth,
                :criterion=>CPOMCPPlusExperiments.CPOMCPOW.MaxCUCB(c, nu), 
                :alpha_schedule => CPOMCPPlusExperiments.CPOMCPOW.ConstantAlphaSchedule(asched),
                :estimate_value=>zeroV_trueC,
                :max_clip => mc,
                :plus_flag => plus_flag,
                :tree_in_info=>tree_in_info,
                :return_best_cost=>return_best_cost
            )
            first_vals = []
            exp1 = ExperimentResults(nsims)
            @showprogress 1 for i = 1:nsims
                Random.seed!(i)
                solver = CPOMCPPlusExperiments.CPOMCPOWSolver(;kwargs..., rng = MersenneTwister(i))
                updater(planner) = CPOMCPPlusExperiments.CPOMCPOW.CPOMCPOWBudgetUpdateWrapper(
                    CPOMCPPlusExperiments.ParticleFilters.BootstrapFilter(cpomdp, update_filter_size, solver.rng), 
                    planner)
                hist, R, C, RC, first_val = run_cpomdp_simulation(cpomdp, solver, updater, max_depth, track_history=false) #last number is max steps
                exp1[i] = hist, R, C, RC
                push!(first_vals, first_val)
            end
            
            #data manipualtion for final result stat

            Vr = exp1.Rs
            Vc = [reduce(vcat, vec) for vec in exp1.Cs]
            

            first_actions = [run[1].a_indx for run in first_vals]

            guessedR = [run[1].v_taken_first for run in first_vals]
            realR = reduce(vcat, exp1.Rs)

            guessedC = reduce(vcat, [run[1].cv_taken_first for run in first_vals])
            realC = reduce(vcat, exp1.Cs)

            lambdas = reduce(vcat, [run[1].lambda_first for run in first_vals])

            ns =  [[run[1].n] for run in first_vals]

            file_name = "results/light_dark/ldnew_plf$(plus_flag)_$(nsims)_sims_tq$(tree_queries)_additional.jld2"
            save_data = Dict(
                "R"=>Vr, "C"=> Vc, "a_indx"=>first_actions, "expR"=>guessedR,
                "expC"=>guessedC, "lambda"=>lambdas, "n"=>ns
            )

            FileIO.save(file_name,save_data)

            m = Statistics.mean(realC)
            s = Statistics.std(realC)
            print("Mean realC: $m, stddev: $s")
            print_and_save(exp1,"results/lightdark_pomcpow_$(nsims)sims.jld2")
        end
    end
end