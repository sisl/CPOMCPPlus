module CPOMCPPlusExperiments

using Infiltrator
using Debugger 
using ProgressMeter
using Parameters
using POMDPGifs
using ParticleFilters
using LinearAlgebra
using Plots
import Statistics
using Random
using Distributed
using FileIO

using POMDPs
using POMDPTools

# non-constrained baseline
using BasicPOMCP
using MCTS # belief-mcts for belief dpw
using POMCPOW

using CPOMDPs
import CPOMDPs: costs, costs_limit, n_costs

using Revise

# constrained solvers
using CMCTS
using CPOMCP
using CPOMCPOW

# models 
export TigerPOMDP
using POMDPModels

export CTigerExtended, TigerPOMDPTerminal
include("cpomdps/tigerTerminal.jl")

# helpers
export
    plot_lightdark_beliefs,
    SoftConstraintPOMDPWrapper,
    LightExperimentResults,
    ExperimentResults,
    print_and_save,
    load_and_print,
    mean,
    std,
    zero_V,
    QMDP_V,
    LambdaExperiments,
    save_le, load_le,
    SearchProgress
include("utils.jl") 

# experiment scripts
export
    run_pomdp_simulation,
    run_cpomdp_simulation,
    run_lambda_experiments
include("experiments.jl")


end # module
