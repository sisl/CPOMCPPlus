struct RockSampleCPOMDP{P<:RockSamplePOMDP,S,A,O} <: ConstrainPOMDPWrapper{P,S,A,O}
    pomdp::P 
    bad_rock_budget::Float64
end

function RockSampleCPOMDP(;pomdp::P=RockSamplePOMDP(), # default 0 incorrect_r, goes into cost
    bad_rock_budget::Float64=3.,
    ) where {P<:RockSamplePOMDP}
    return RockSampleCPOMDP{P, statetype(pomdp), actiontype(pomdp), obstype(pomdp)}(pomdp,bad_rock_budget)
end

function costs(p::RockSampleCPOMDP, s::RSState, a::Int)
    c = 0.
    if RockSample.next_position(s, a)[1] > p.pomdp.map_size[1]
        return [c]
    end
    if a == RockSample.BASIC_ACTIONS_DICT[:sample] && in(s.pos, p.pomdp.rocks_positions) # sample 
        rock_ind = findfirst(isequal(s.pos), p.pomdp.rocks_positions) # slow ?
        c += s.rocks[rock_ind] ? 0. : 1.
    end
    return [c]

end

costs_limit(pomdp::RockSampleCPOMDP) = [pomdp.bad_rock_budget]
n_costs(::RockSampleCPOMDP) = 1
min_reward(p::RockSampleCPOMDP) = p.pomdp.step_penalty + min(p.pomdp.bad_rock_penalty, p.pomdp.sensor_use_penalty)
max_reward(p::RockSampleCPOMDP) = p.pomdp.step_penalty + max(p.pomdp.exit_reward, p.pomdp.good_rock_reward)

# QMDP_V(pomdp::RockSamplePOMDP, s::RSState, args...) = 0 # Learn what to put here 
function QMDP_V(pomdp::RockSamplePOMDP, s::RSState, args...)
    n_bad_rocks = count(x -> x == false, s.rocks)
    n_good_rocks = count(x -> x == true, s.rocks)
    rew = n_good_rocks * pomdp.good_rock_reward + n_bad_rocks * pomdp.bad_rock_penalty
    if (s.pos[1] > pomdp.map_size[1])
        rew += pomdp.exit_reward
    end
    return rew
end

QMDP_V(cpomdp::RockSampleCPOMDP, args...) = (QMDP_V(cpomdp.pomdp, args...), zeros(Float64, n_costs(cpomdp))) 
function QMDP_V(p::CPOMDPs.GenerativeBeliefCMDP{P}, s::ParticleFilters.ParticleCollection{S}, args...) where {P<:RockSampleCPOMDP, S<:RSState}
    V = 0.
    ws = weights(s)
    for (part, w) in zip(particles(s),ws)
        V += QMDP_V(p.cpomdp, part, args...)[1] * w
    end
    V /= sum(ws)
    return (V, zeros(Float64, n_costs(p.cpomdp))) # replaces old weight_sum(particle collections) that was 1 

end

Base.iterate(pomdp::RockSampleCPOMDP, i::Int=1) = Base.iterate(pomdp.pomdp, i)
POMDPTools.render(pomdp::RockSampleCPOMDP, step;
    viz_rock_state=true,
    viz_belief=true,
    pre_act_text=""
) = POMDPTools.render(pomdp.pomdp, step; viz_rock_state=viz_rock_state,viz_belief=viz_belief,pre_act_text=pre_act_text)