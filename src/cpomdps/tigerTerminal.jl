
"""
This version of Constrainted Tiger
creates a POMDP Tiger problem
Then adds constraints
Terminal states are added
Custom POMDP values can be used
"""

import Base: ==, +, *, -
using Distributions
using POMDPModelTools

mutable struct TigerPOMDPTerminal <: POMDPs.POMDP{Int64, Int64, Bool} #state, action, obs
    r_listen_noisy::Float64
    r_findtiger::Float64
    r_escapetiger::Float64
    p_listen_noisy::Float64
    discount_factor::Float64
end

TigerPOMDPTerminal() = TigerPOMDPTerminal(-10.0, 0., 10.0, 0.70, 0.95)


POMDPs.states(::TigerPOMDPTerminal) = 0:2
POMDPs.observations(::TigerPOMDPTerminal) = (false, true)

# #terminal if you pick wrong
POMDPs.isterminal(::TigerPOMDPTerminal, s::Int) = s==2

POMDPs.stateindex(::TigerPOMDPTerminal, s::Int) = s + 1
POMDPs.actionindex(::TigerPOMDPTerminal, a::Int) = a + 1
POMDPs.obsindex(::TigerPOMDPTerminal, o::Bool) = Int64(o) + 1

#still want intial to just be the first 2 states
initial_belief(::TigerPOMDPTerminal) = POMDPModelTools.SparseCat([0,1,2], [0.5, 0.5, 0.0]) 

const TIGER_LISTEN_NOISY = 0
const TIGER_OPEN_LEFT_TERMINAL = 1
const TIGER_OPEN_RIGHT_TERMINAL = 2

const TIGER_LEFT_TERMINAL = 0
const TIGER_RIGHT_TERMINAL = 1
const TIGER_END = 2

# Resets the problem after opening door; does nothing after listening
function POMDPs.transition(pomdp::TigerPOMDPTerminal, s::Int64, a::Int64)
    #open doors the tiger is not behind
    if a == TIGER_OPEN_LEFT_TERMINAL && s != TIGER_LEFT_TERMINAL
        p = [0.5, 0.5, 0.0]
    elseif a == TIGER_OPEN_RIGHT_TERMINAL && s != TIGER_RIGHT_TERMINAL
        p = [0.5, 0.5, 0.0] 
    #open doors the tiger is behind
    elseif a == TIGER_OPEN_LEFT_TERMINAL && s == TIGER_LEFT_TERMINAL
        p = [0., 0., 1.]
    elseif a == TIGER_OPEN_RIGHT_TERMINAL && s == TIGER_RIGHT_TERMINAL
        p = [0., 0., 1.]
    #listening
    elseif s==TIGER_RIGHT_TERMINAL
        p = [0.0, 1.0, 0.0]
    else
        p = [1.0, 0.0, 0.0]
    end
    return POMDPModelTools.SparseCat([0,1,2], p) 
end

function POMDPs.observation(pomdp::TigerPOMDPTerminal, a::Int64, sp::Int64)
    pc = pomdp.p_listen_noisy
    p = 1.0
    if a == TIGER_LISTEN_NOISY
        sp==TIGER_RIGHT_TERMINAL ? (p = pc) : (p = 1.0-pc) #if tiger on right, right is true for
        probs = [1.0-p, p, 0.0] 
    else
        p = 0.5
        probs = [1.0-p, p, 0.0]
    end

    return POMDPModelTools.SparseCat([0,1,2], probs) 
end

function POMDPs.observation(pomdp::TigerPOMDPTerminal, s::Int64, a::Int64, sp::Int64)
    return POMDPs.observation(pomdp, a, sp)
end

function POMDPs.reward(pomdp::TigerPOMDPTerminal, s::Int64, a::Int64)
    r = 0.0
    a == TIGER_LISTEN_NOISY && (r+=pomdp.r_listen_noisy)
    if a == TIGER_OPEN_LEFT_TERMINAL
        if s == TIGER_END || s == TIGER_LEFT_TERMINAL
            r += pomdp.r_findtiger
        else
            r += pomdp.r_escapetiger
        end
    end
    if a == TIGER_OPEN_RIGHT_TERMINAL
        if s == TIGER_END || s == TIGER_RIGHT_TERMINAL
            r += pomdp.r_findtiger
        else
            r += pomdp.r_escapetiger
        end
    end
    return r
end
POMDPs.reward(pomdp::TigerPOMDPTerminal, s::Int64, a::Int64, sp::Int64) = POMDPs.reward(pomdp, s, a)

POMDPs.initialstate(pomdp::TigerPOMDPTerminal) = POMDPModelTools.SparseCat([0,1,2], [0.5, 0.5, 0.0]) 

POMDPs.actions(::TigerPOMDPTerminal) = 0:2

function upperbound(pomdp::TigerPOMDPTerminal, s::Int64)
    return pomdp.r_escapetiger
end

POMDPs.discount(pomdp::TigerPOMDPTerminal) = pomdp.discount_factor

POMDPs.initialobs(p::TigerPOMDPTerminal, s::Int) = POMDPs.observation(p, 0, s) # listen noisy

struct CTigerExtended{P<:TigerPOMDPTerminal,S,A,O} <: ConstrainPOMDPWrapper{P,S,A,O}
    pomdp::P 
    cost_budget::Float64
end

function CTigerExtended(;pomdp::P=TigerPOMDPTerminal(),
    cost_budget::Float64=0.9,
    #tiger_found::Bool=true,
    ) where {P<:TigerPOMDPTerminal}
    return CTigerExtended{P, statetype(pomdp), actiontype(pomdp), obstype(pomdp)}(pomdp,cost_budget)
end

#should costs be not trying to be positive
#cost is 1 if tiger is found, states are tiger right/left
costs(p::CTigerExtended, s::Int64, a::Int64) = Float64[ s==0 && a==1 || s==1 && a==2 ]
costs_limit(p::CTigerExtended) = [p.cost_budget]
n_costs(::CTigerExtended) = 1 
