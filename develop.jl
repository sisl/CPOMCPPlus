using Pkg
Pkg.activate(".")
root = "/"

dev_packages = [
    PackageSpec(url="$root/.julia/dev/CPOMCP/"),
    PackageSpec(url="$root/.julia/dev/CPOMCPOW/"),
    PackageSpec(url="$root/.julia/dev/CMCTS/"),
    PackageSpec(url="$root/.julia/dev/SpillpointPOMDP/"),
    PackageSpec(url="$root/.julia/dev/CPOMDPs/"),
    PackageSpec(url="$root/.julia/dev/RockSample.jl/"),
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