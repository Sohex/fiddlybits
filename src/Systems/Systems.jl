module Systems

# System{FT} and its blocks, the constructor refusals, and strip:
# docs/plans/fiddlybits-52v.4-system.md, sections "The struct" and "Oracles";
# decisions 0004 and 0007.

using ..Verdicts
using ..Dimensions
using ..Dispositions
using ..Reductions

include("checks.jl")
include("constants.jl")
include("spectrum.jl")
include("star.jl")
include("figure.jl")
include("planet.jl")
include("orbits.jl")
include("moon.jl")
include("inventories.jl")
include("numerics.jl")
include("system.jl")
include("profile.jl")
include("gravity.jl")
include("derived.jl")
include("tracking.jl")
include("strip.jl")

end # module Systems
