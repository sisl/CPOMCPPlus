using Infiltrator

function POMDPs.updater(p::AbstractMCTSPlanner)
    P = typeof(p.mdp)
    @assert P <: GenerativeBeliefMDP "updater called on a AbstractCMCTSPlanner without an underlying BeliefMDP"
    return p.mdp.updater
    # XXX It would be better to automatically use an SIRParticleFilter if possible
    # if !@implemented ParticleFilters.obs_weight(::P, ::S, ::A, ::S, ::O)
    #     return UnweightedParticleFilter(p.problem, p.solver.tree_queries, rng=p.rng)
    # end
    # return SIRParticleFilter(p.problem, p.solver.tree_queries, rng=p.rng)
end

function generate_gif(p::POMDP, s, fname::String)
    try
        sim = GifSimulator(filename=fname, max_steps=30)
        simulate(sim, p, s)
    catch err
        println("Simulation $(fname) failed")
    end
end

function step_through(p::POMDP, planner::Policy, max_steps=100)
    for (s, a, o, r) in stepthrough(p, planner, "s,a,o,r", max_steps=max_steps)
        print("State: $s, ")
        print("Action: $a, ")
        print("Observation: $o, ")
        println("Reward: $r.")
    end
end

function step_through(p::CPOMDP, planner::Policy, max_steps=100)
    #@infiltrate
    for (s, a, o, r, c) in stepthrough(p, planner, "s,a,o,r,c", max_steps=max_steps)
        print("State: $s, ")
        print("Action: $a, ")
        print("Observation: $o, ")
        println("Reward: $r, ")
        println("Cost: $c.")
    end
end


function get_tree(planner)
    if hasproperty(planner, :tree)
        return planner.tree
    elseif hasproperty(planner, :_tree)
        return planner._tree
    else
        @error "Can't find tree for planner of type $(typeof(planner))"
    end
end


function run_cpomdp_simulation(cpomdp::CPOMDP, solver::Solver, 
    bu::Union{Nothing,Updater,Function}=nothing, max_steps=100;track_history::Bool=true)
    planner = solve(solver, cpomdp)
    if bu===nothing
        bu = POMDPs.updater(planner)
    elseif bu isa Function
        bu = bu(planner)
    end
    R = 0
    C = zeros(n_costs(cpomdp))
    RC = 0.0
    γ = 1
    hist = NamedTuple[]
    first_vals = NamedTuple[]

    actiontoind = Dict()
    actions = [-10, -5, -1, 0, 1, 5, 10]
    for (ind, i) in enumerate(actions)
        actiontoind[i] = ind
    end
    
    for (s, a, o, r, c, sp, b, ai) in stepthrough(cpomdp, planner, bu, "s,a,o,r,c,sp,b,action_info", max_steps=max_steps)
                
        R += r*γ
        C .+= c.*γ
        rc = 0.0

        if γ == 1

            if typeof(cpomdp.pomdp) != SpillpointInjectionPOMDP
                tree = :tree in keys(ai) ? ai[:tree] : nothing
                a_indx = actiontoind[a]
                v_taken_first = tree.v[a_indx]
                cv_taken_first = tree.cv[a_indx]
                if solver.plus_flag
                    lambda_first = tree.lambda[1]
                else
                    lambda_first = planner._lambda
                end

                n = [tree.n[actiontoind[a]] for a in actions]
                
                push!(first_vals, (;a_indx, v_taken_first, cv_taken_first, lambda_first, n))
            else
                #@infiltrate
                tree = :tree in keys(ai) ? ai[:tree] : nothing
                idx = findall(x -> x == a, tree.a_labels)                
                v_taken_first = reduce(vcat, tree.v[idx])
                cv_taken_first = reduce(vcat, tree.cv[idx])
                if length(v_taken_first) > 1
                    v_taken_first = reduce(vcat, sum(v_taken_first) / length(v_taken_first)) #mean is redefined
                    cv_taken_first = reduce(vcat, sum(cv_taken_first) / length(cv_taken_first))
                end
                if solver.plus_flag
                    lambda_first = tree.lambda[1]
                else
                    lambda_first = planner._lambda
                end
                push!(first_vals, (;a, v_taken_first, cv_taken_first, lambda_first))
            end

        end

        # @infiltrate
        γ *= discount(cpomdp)
        if track_history
            push!(hist, (;s, a, o, r, c, rc, sp, b, 
                tree = :tree in keys(ai) ? ai[:tree] : nothing,
                lambda = :lambda in keys(ai) ? ai[:lambda] : nothing,
                v_best = :v_best in keys(ai) ? ai[:v_best] : nothing,
                cv_best = :cv_best in keys(ai) ? ai[:cv_best] : nothing,
                v_taken = :v_taken in keys(ai) ? ai[:v_taken] : nothing,
                cv_taken = :cv_taken in keys(ai) ? ai[:cv_taken] : nothing,
                ))
        end
    end
    hist, R, C, RC, first_vals # TODO: Delete RC
end