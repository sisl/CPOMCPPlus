using Pkg
Pkg.activate(".")

root = dirname(@__FILE__)

dev_packages = [
    PackageSpec(url= joinpath(root, "CPOMCP.jl")),
    PackageSpec(url= joinpath(root, "CMCTS.jl")),
    PackageSpec(url= joinpath(root, "SpillpointPOMDP.jl")),
    PackageSpec(url= joinpath(root, "CPOMDPs.jl")),
    PackageSpec(url= joinpath(root, "RockSample.jl")),
    PackageSpec(url= joinpath(root, "CPOMCPOW.jl")),
]
ci = haskey(ENV, "CI") && ENV["CI"] == "true"

if ci
    # remove "own" package when on CI
    pop!(dev_packages)
end

# Run dev altogether
# This is important that it's run together so there
# are no "expected pacakge X to be registered" errors.
Pkg.develop(dev_packages)
Pkg.instantiate()