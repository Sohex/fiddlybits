isdefined(@__MODULE__, :SharedFixtureHelper) ||
    include(joinpath(@__DIR__, "helper.jl"))
using .SharedFixtureHelper: answer
