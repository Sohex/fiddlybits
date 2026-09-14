module Connectivity

# The connectivity graph derived from a terrain-level field:
# docs/plans/fiddlybits-52v.2-mesh.md, section "Connectivity"; decision 0031, layer 1;
# REQ-TER-012.

using ..Verdicts: refuse

include("levels.jl")
include("surface.jl")
include("terminals.jl")
include("gates.jl")
include("graph.jl")
include("topology.jl")

end # module Connectivity
