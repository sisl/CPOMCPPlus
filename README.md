This branch is for running Rocksample experiments.
Please switch to the branch for the experiments you wish to run.
### Installation Instructions

1. Clone the following packages to within this folder:
    - CPOMCP (lambda branch)
    - CPOMCPOW (lambda_prop branch)
    - CMCTS (lambda_prop branch)
    - SpillpointPOMDP
    - CPOMDPs

2. Run `develop.jl` to develop the packages

    - Develop all non-registered packages, even if not changing them.

3. If `CPOMCPOW.jl` fails to build

    - Rewrite 'CPOMCPOW.jl\src\CPOMCPOW.jl' file with the '\scratch\CPOMCPOW.jl' contents
    - Start the Julia REPL
        - activate the env with ']' then 'activate .'
        - run using Pkg; Pkg.add("POMDPLinter") from the Julia command line
        - rebuild with Pkg.precompile()