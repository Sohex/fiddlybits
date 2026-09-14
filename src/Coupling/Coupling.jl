module Coupling

# WorldState, the component declaration and assemble, Exchange, FixedPointLoop and
# Ladder: docs/plans/fiddlybits-52v.11-coupling.md; decision 0009.

using ..Verdicts

include("state.jl")
include("exchange.jl")

end # module Coupling
