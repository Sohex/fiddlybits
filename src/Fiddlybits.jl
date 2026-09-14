module Fiddlybits

# The include order is a topological order of the inter-module reference graph.
# build.module_order_acyclic checks it against the graph recovered from the source.
# Nothing is re-exported: a caller names the module it reads from.

include("Verdicts/Verdicts.jl")
include("Events/Events.jl")
include("Dimensions/Dimensions.jl")
include("Time/Time.jl")
include("Dispositions/Dispositions.jl")
include("EarthRatios/EarthRatios.jl")
include("Backends/Backends.jl")
include("Reductions/Reductions.jl")
include("Systems/Systems.jl")
include("Orbit/Orbit.jl")
include("Mesh/Mesh.jl")
include("Fields/Fields.jl")
include("Instellation/Instellation.jl")
include("Connectivity/Connectivity.jl")
include("Coupling/Coupling.jl")
include("Provenance/Provenance.jl")
include("ShallowWater/ShallowWater.jl")
include("Oracles/Oracles.jl")
include("Render/Render.jl")

using PrecompileTools: @setup_workload, @compile_workload

# The workload is what a run actually does, added by each area as it gains code.
# test/gate/load_latency.jl reads it: a method called here carries a cached
# specialization on a fresh load, and Verdicts.refuse, which is not called here,
# carries none.
@setup_workload begin
    @compile_workload begin
        Verdicts.loop_verdicts()
        Verdicts.oracle_verdicts()
    end
end

end # module Fiddlybits
