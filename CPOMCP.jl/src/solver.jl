make_tree(s::CPOMCPSolver, p::CPOMDP, b; kwargs...) = CPOMCPTree(p, b, s.tree_queries; kwargs...) #if call make_tree with key word will pass to CPOMCPTree
make_tree(s::CPOMCPDPWSolver, p::CPOMDP, b) = CPOMCPDPWTree(p, b, s.tree_queries)

get_top_level_costs(tree::CPOMCPTree, nodes::Vector{Int}) = tree.top_level_costs[nodes]
get_top_level_costs(tree::CPOMCPDPWTree, nodes::Vector{Int}) = map(i->tree.top_level_costs[i],nodes)

function POMDPTools.action_info(p::AbstractCPOMCPPlanner, b; tree_in_info=false)
    local a::actiontype(p.problem)
    info = Dict{Symbol, Any}()
    try
        #print("make tree")
        tree = make_tree(p.solver, p.problem, b; init_λ = p.solver.init_λ)
        policy = search(p, b, tree, info)
        info[:policy] = policy
        a = tree.a_labels[rand(p.rng, policy)]
        p._cost_mem = dot(get_top_level_costs(tree,policy.vals), policy.probs)
        if any(isnan.(p._cost_mem))
            @warn "cost memory going nan"
        end
        @infiltrate isnan(p._cost_mem[1])
        p._tree = tree
        if p.solver.tree_in_info || tree_in_info
            info[:tree] = tree
        end
    catch ex
        # Note: this might not be type stable, but it shouldn't matter too much here
        a = convert(actiontype(p.problem), default_action(p.solver.default_action, p.problem, b, ex))
        info[:exception] = ex
    end
    return a, info
end

action(p::AbstractCPOMCPPlanner, b) = first(action_info(p, b))

function search(p::AbstractCPOMCPPlanner, b, t::AbstractCPOMCPTree, info::Dict)
    all_terminal = true
    nquery = 0
    start_us = CPUtime_us()
    #p._lambda = rand(p.rng, t.n_costs) .* p.solver.max_clip # random initialization
    #commmenting for now to discuss max_clip = (max_reward(p.problem) - min_reward(p.problem))/(1-discount(p.problem)) ./ p._tau
    if p.solver.search_progress_info
        #NOTE: sizehint for lambda?
        info[:lambda] = sizehint!(Vector{Float64}[t.lambda[1]], p.solver.tree_queries)
        info[:v_best] = sizehint!(Float64[], p.solver.tree_queries)
        info[:cv_best] = sizehint!(Vector{Float64}[], p.solver.tree_queries)
        info[:v_taken] = sizehint!(Float64[], p.solver.tree_queries)
        info[:cv_taken] = sizehint!(Vector{Float64}[], p.solver.tree_queries)
    end

    for i in 1:p.solver.tree_queries
        nquery += 1
        if CPUtime_us() - start_us >= 1e6*p.solver.max_time
            break
        end
        @infiltrate isnan(p.budget[1])
        s = rand(p.rng, b)
        if !POMDPs.isterminal(p.problem, s)
            simulate(p, s, CPOMCPObsNode(t,1), p.solver.max_depth, p.budget)
            all_terminal = false
        else
            continue
        end

        hnode = CPOMCPObsNode(t,1) #trouble shooting tbcleaned
        #t = hnode.tree this is passed in, circular here
        h = hnode.node
    
        #throwing errors, need to determine which
        #lambda = maximum(t.lambda) #ERROR
    
        if p.plus_flag == false
            lambda = t.lambda[1] #for CPOMDP single lambda from planner
        else
            #testing out to see a difference from t.lambda[1]
            lambda = t.lambda[h]
        end

        # # dual ascent w/ clipping
        # ha = rand(p.rng, action_policy_UCB(CPOMCPObsNode(t,1), p._lambda, 0.0, 0.0))
        ha = rand(p.rng, action_policy_UCB(CPOMCPObsNode(t,1), t.lambda[h], 0.0, 0.0))
        # p._lambda += alpha(p.solver.alpha_schedule, i) .* (t.cv[ha] - p.budget)
        # p._lambda = min.(max.(p._lambda, 0.), p.solver.max_clip)
        
        # tracking
        if p.solver.search_progress_info
            push!(info[:lambda], lambda) #display the latest lambda
            push!(info[:v_taken], t.v[ha])
            push!(info[:cv_taken], t.cv[ha])

            # get absolute best node (no lambda weights)
            max_q = -Inf
            ha_best = nothing
            for nd in t.children[1]
                if t.v[nd] > max_q
                    max_q = t.v[nd]
                    ha_best = nd
                end
            end
            push!(info[:v_best],t.v[ha_best] )
            push!(info[:cv_best],t.cv[ha_best] )
        end
    end
    info[:search_time_us] = CPUtime_us() - start_us
    info[:tree_queries] = nquery

    if all_terminal
        throw(AllSamplesTerminal(b))
    end

    #@infiltrate
    hnode = CPOMCPObsNode(t,1) #trouble shooting tbcleaned
    #t = hnode.tree this is passed in, circular here
    h = hnode.node

    #throwing errors, need to determine which
    #lambda = maximum(t.lambda) #ERROR

    if p.plus_flag == false
        lambda = t.lambda[1] #for CPOMDP single lambda from planner
    else
        #testing out to see a difference from t.lambda[1]
        lambda = t.lambda[h]
    end
    return action_policy_UCB(CPOMCPObsNode(t,1), lambda, 0.0, p.solver.nu)
end

dot(a::Vector,b::Vector) = sum(a .* b)

# return sparse categorical policy over best action node indices
function action_policy_UCB(hnode::CPOMCPObsNode, lambda::Vector{Float64}, c::Float64, nu::Float64)
    t = hnode.tree
    h = hnode.node

    # Q_lambda = Q_value - lambda'Q_c + c sqrt(log(N)/N(h,a))
    ltn = log(t.total_n[h])
    best_nodes = Int[]
    #push!(best_nodes, 1) #ERROR: this is for no nodes being pushed current cases

    criterion_values = sizehint!(Float64[],length(t.children[h]))
    best_criterion_val = -Inf

    if length(t.children[h]) < 1 
        println("here1")   
        @infiltrate
    end
    #println(t.children[h])
    for node in t.children[h]
        n = t.n[node]
        if n == 0 && ltn <= 0.0
            criterion_value = t.v[node] - dot(lambda,t.cv[node])
        elseif n == 0 && t.v[node] == -Inf
            criterion_value = Inf
        else
            criterion_value = t.v[node] - dot(lambda,t.cv[node])
            if c > 0
                criterion_value += c*sqrt(ltn/n)
            end
        end
        push!(criterion_values,criterion_value)
        if criterion_value > best_criterion_val
            best_criterion_val = criterion_value
            empty!(best_nodes)
            push!(best_nodes, node)
        elseif criterion_value == best_criterion_val
            push!(best_nodes, node)
        end
    end
    
    # get next best nodes
    if nu > 0.
        val_diff = best_criterion_val .- criterion_values 
        next_best_nodes = t.children[h][0 .< val_diff .< nu]
        append!(best_nodes, next_best_nodes)
    end
    
    if length(best_nodes) == 0
        println("here") 
        @infiltrate
    end
    # weigh actions
    if length(best_nodes) == 1
        weights = [1.0]
    else
        weights = solve_lp(t, best_nodes)
    end
    # println(best_nodes)
    # println(weights)
    
    return SparseCat(best_nodes, weights)
end

function solve_lp(t::AbstractCPOMCPTree, best_nodes::Vector{Int})
    # error("Multiple CPOMCP best actions not implemented")
    # random for now
    return ones(Float64, length(best_nodes)) / length(best_nodes)
end

function simulate(p::CPOMCPPlanner, s, hnode::CPOMCPObsNode, steps::Int, budget::Vector{Float64})
    @infiltrate isnan(budget[1]) 
    if steps == 0 || isterminal(p.problem, s)
        return 0.0, zeros(Float64, hnode.tree.n_costs)
    end

    t = hnode.tree
    h = hnode.node

    if p.plus_flag == false
        lambda = t.lambda[1] #for CPOMDP single lambda from planner
    else
        lambda = t.lambda[h] #for Plus use observation node lambda
    end
    if isnan(lambda[1])
        @infiltrate
    end
    acts = action_policy_UCB(hnode, lambda, p.solver.c, p.solver.nu)
    p._best_node_mem = acts.vals
    ha = rand(p.rng, acts)
    a = t.a_labels[ha]

    sp, o, r, c = @gen(:sp, :o, :r, :c)(p.problem, s, a, p.rng) #black box
    
    hao = get(t.o_lookup, (ha, o), 0)
    if hao == 0
        hao = insert_obs_node!(t, p, ha, sp, o, h)
        v, cv = estimate_value(p.solved_estimator,
                           p.problem,
                           sp,
                           CPOMCPObsNode(t, hao),
                           steps-1)
    else
        if p.plus_flag
            budget = (budget - t.top_level_costs[ha])/discount(p.problem) #only want single step costs update for lambda nodes
        end
            v, cv = simulate(p, sp, CPOMCPObsNode(t, hao), steps-1, budget)
    end

    R = r + discount(p.problem)*v
    C = c + discount(p.problem)*cv

    t.total_n[h] += 1
    t.n[ha] += 1
    t.v[ha] += (R-t.v[ha])/t.n[ha]
    t.cv[ha] += (C-t.cv[ha])/t.n[ha]
    
    # top level cost estimator or single step cost update
    if steps == p.solver.max_depth || p.plus_flag
        t.top_level_costs[ha] += (c-t.top_level_costs[ha])/t.n[ha]
        @infiltrate isnan(t.top_level_costs[ha][1])
    end

    # dual ascent w/ clipping
    if p.plus_flag || h == 1
        #ha_best = rand(p.rng, action_policy_UCB(CPOMCPObsNode(t,1), t.lambda[h], 0.0, 0.0)) #may no longer want to find best action to lambda update, may want to take action took for lambda update
        ha_best = ha
        t.lambda[h] += alpha(p.solver.alpha_schedule, t.total_n[h]) .* (t.cv[ha_best] - budget) #budget only updated is p.plus_flag before also
        t.lambda[h] = min.(max.(t.lambda[h], 0.), p.solver.max_clip)
        # if isnan(t.lambda[1])
        #     @infiltrate
        # end
    end

    if p.solver.return_best_cost

        LC = dot( lambda .+ 1e-3, C)

        for ch in t.children[h]
            LC_temp = dot(lambda .+ 1e-3, t.cv[ch])
            if LC_temp < LC
                LC = LC_temp
                C = t.cv[ch]
            end
        end
    end

    return R, C
end

function simulate(p::CPOMCPDPWPlanner, s, hnode::CPOMCPObsNode, steps::Int)
    if steps == 0 || isterminal(p.problem, s)
        return 0.0, zeros(Float64, hnode.tree.n_costs)
    end
    sol = p.solver
    t = hnode.tree
    h = hnode.node
    top_level = steps==p.solver.max_depth
    # action pw
    if sol.enable_action_pw
        if length(t.children[h]) <= sol.k_action*t.total_n[h]^sol.alpha_action
            a = next_action(p.next_action, p.problem, s, hnode)
            if !sol.check_repeat_act || !haskey(t.a_lookup,(h,a))
                insert_action_node!(t,h,a;top_level=top_level)
            end
        end
    elseif isempty(t.children[h]) 
        for a in actions(p.problem, s)
            insert_action_node!(t,h,a;top_level=top_level)
        end
    end

    t.total_n[h] += 1
    acts = action_policy_UCB(hnode, p._lambda, sol.c, sol.nu)
    p._best_node_mem = acts.vals
    ha = rand(p.rng, acts)
    a = t.a_labels[ha]

    # observation progressive widening
    new_node = false
    if (sol.enable_observation_pw && t.n_a_children[ha] <= sol.k_observation*t.n[ha]^sol.alpha_observation) || t.n_a_children[ha] == 0
        sp, o, r, c = @gen(:sp, :o, :r, :c)(p.problem, s, a, p.rng)
        if sol.check_repeat_obs && haskey(t.o_lookup, (ha,o))
            hao = t.o_lookup[(ha,o)]
            push!(t.states[hao],sp)
        else
            hao = insert_obs_node!(t, p, ha, sp, o, h)
            new_node = true
        end
        
        push!(t.transitions[ha],hao)

        if !sol.check_repeat_obs
            t.n_a_children[ha] += 1
        elseif !((ha,hao) in t.unique_transitions)
            push!(t.unique_transitions, (ha,hao))
            t.n_a_children[ha] += 1
        end
    else
        hao= rand(p.rng,t.transitions[ha])
        sp = rand(p.rng,t.states[hao])
        r = reward(p.problem,s,a,sp)
        c = costs(p.problem,s,a,sp)
    end
    
    if new_node
        v, cv = estimate_value(p.solved_estimator, p.problem, sp,
            CPOMCPObsNode(t, hao),steps-1)
    else
        v, cv = simulate(p, sp, CPOMCPObsNode(t, hao), steps-1)
    end

    R = r + discount(p.problem)*v
    C = c + discount(p.problem)*cv

    t.total_n[h] += 1
    t.n[ha] += 1
    t.v[ha] += (R-t.v[ha])/t.n[ha]
    t.cv[ha] += (C-t.cv[ha])/t.n[ha]

    # top level cost estimator
    if steps == p.solver.max_depth
        if ha in keys(t.top_level_costs)
            t.top_level_costs[ha] += (c-t.top_level_costs[ha])/t.n[ha]
        else
            t.top_level_costs[ha] = c
        end
    end
    return R, C
end