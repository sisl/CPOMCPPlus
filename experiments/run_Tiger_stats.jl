using Plots

using CPOMCPPlusExperiments
using Debugger
using ProgressMeter
using Distributed
using Random
using Plots

using Infiltrator
using DataFrames
using FileIO

nsims = 100
run = [true] #(cpomcp)

cpomdp = CTigerExtended()

# global parameters
k_observation = 5.
alpha_observation = 1/15
enable_action_pw = false
max_depth = 5
c = 90.0
nu = 0.0
asched = 0.5
update_filter_size = Int(1e4)
pf_filter_size = 10

tree_in_info = true
search_progress_info = true

for plus_flag in [false, true]
    for tree_queries in [1e2, 1e3, 2e3, 4e3, 6e3, 8e3, 1e4]
        if run[1] # CPOMCP

            kwargs = Dict(
                :tree_queries=>Int(tree_queries),
                :max_depth => max_depth,
                :c=>c,
                :nu=>nu, 
                :alpha_schedule => CPOMCPPlusExperiments.CPOMCP.ConstantAlphaSchedule(asched),
                :tree_in_info=>tree_in_info,
                :search_progress_info=>search_progress_info,
            )

            first_vals = []

            exp1 = LightExperimentResults(nsims)
            @showprogress 1 for i = 1:nsims
                Random.seed!(i)
                solver = CPOMCPPlusExperiments.CPOMCPSolver(;kwargs..., rng = MersenneTwister(i), plus_flag)#() #CPOMCPDPWSolver(;kwargs..., rng = MersenneTwister(i))

                updater(planner) = CPOMCPPlusExperiments.CPOMCP.CPOMCPBudgetUpdateWrapper(
                    CPOMCPPlusExperiments.ParticleFilters.BootstrapFilter(cpomdp, update_filter_size, solver.rng), 
                    planner)

                hist, R, C, RC, first_val = run_cpomdp_simulation(cpomdp, solver, updater, max_depth, track_history=false) #last number is max steps
                exp1[i] = hist, R, C, RC
                push!(first_vals, first_val)
                
            end

            #data manipualtion for final result stat

            Vr = reduce(vcat, exp1.Rs)
            Vc = reduce(vcat, exp1.Cs)

            first_actions = [run[1].a for run in first_vals]

            guessedR = [run[1].v_taken_first for run in first_vals]
            realR = reduce(vcat, exp1.Rs)

            guessedC = reduce(vcat, [run[1].cv_taken_first for run in first_vals])
            realC = reduce(vcat, exp1.Cs)

            #this is the top level lambdas after the full iteration
            lambdas =  reduce(vcat, [run[1].lambda_first for run in first_vals])
            
            #total n for first action in first tree search
            ns =  [[run[1].n] for run in first_vals]
            
            print_and_save(exp1,"results/tiger_cpomcp_$(plus_flag)_$(nsims)sims.jld2")

            file_name = "results/additional_data/Tiger/tiger_cpomcp_$(plus_flag)pf_$(nsims)sims_$(tree_queries)tq.jld2"
            save_data = Dict(
                "R"=>Vr, "C"=> Vc, "a"=>first_actions, "expR"=>guessedR,
                "expC"=>guessedC, "lambda"=>lambdas, "n"=>ns
            )
            FileIO.save(file_name,save_data)

        end
    end
end