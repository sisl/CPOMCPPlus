struct RockSampleCPOMDP{P<:RockSamplePOMDP,S,A,O} <: ConstrainPOMDPWrapper{P,S,A,O}
    pomdp::P 
    bad_rock_budget::Float64
end

disc = 0.95

# Names are refering to size, num_rocks, and match the experiments in http://ailab.kaist.ac.kr/papers/pdfs/LKPK2018.pdf when disc = 1
# Note that Julia one indexes
kaist57 = RockSamplePOMDP(rocks_positions=[RSPos(2, 1), RSPos(3, 2), RSPos(2, 3), RSPos(3, 3), RSPos(5, 3), RSPos(1, 4), RSPos(4, 5)], 
                            init_pos=RSPos(1, 3),
                            map_size=(5,5),
                            sensor_efficiency= 20.0,
                            discount_factor= disc,
                            bad_rock_penalty = -10.0,
                            bad_action_penalty = -100.0,
                            good_rock_reward = 10.0
                            )

kaist78 = RockSamplePOMDP(rocks_positions=[RSPos(3, 1), RSPos(1, 2), RSPos(4, 2), RSPos(7, 4), RSPos(3, 5), RSPos(4, 5), RSPos(6, 6), RSPos(2, 7)], 
                            init_pos=RSPos(1, 4),
                            map_size=(7,7),
                            sensor_efficiency= 20.0,
                            discount_factor= disc,
                            bad_rock_penalty = -10.0,
                            bad_action_penalty = -100.0,
                            good_rock_reward = 10.0
                            )

kaist1111 = RockSamplePOMDP(rocks_positions=[RSPos(1, 4), RSPos(1, 8), RSPos(2, 9), RSPos(3, 5), RSPos(4,4), RSPos(4, 8), RSPos(5,4), RSPos(6, 9), RSPos(7, 2), RSPos(10, 4), RSPos(10, 10)], 
                            init_pos=RSPos(1, 6),
                            map_size=(11,11),
                            sensor_efficiency= 20.0,
                            discount_factor= disc,
                            bad_rock_penalty = -10.0,
                            bad_action_penalty = -100.0,
                            good_rock_reward = 10.0
                            )
                            
function RockSampleCPOMDP(;pomdp::P=kaist1111, bad_rock_budget::Float64=1., ) where {P<:RockSamplePOMDP}
    return RockSampleCPOMDP{P, statetype(pomdp), actiontype(pomdp), obstype(pomdp)}(pomdp,bad_rock_budget)
end

function costs(p::RockSampleCPOMDP, s::RSState, a::Int)
    c = 0.
    if RockSample.next_position(s, a)[1] > p.pomdp.map_size[1]
        return [c]
    end
    if a > RockSample.N_BASIC_ACTIONS
        c += 1
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

function QMDP_V(pomdp::RockSamplePOMDP, s::RSState, args...)
    return pomdp.exit_reward * discount(pomdp) ^ (pomdp.map_size[1] - s.pos[1] + 1) 
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
POMDPTools.render(pomdp::RockSampleCPOMDP, step; viz_rock_state=true, viz_belief=true, pre_act_text="") = POMDPTools.render(pomdp.pomdp, step; viz_rock_state=viz_rock_state,viz_belief=viz_belief,pre_act_text=pre_act_text)