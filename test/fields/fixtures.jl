# One recipe for the fields the suites in this directory build, so a test overrides
# the one part it is checking and states nothing else.

module FieldFixtures

using Fiddlybits: Mesh, Time, Dimensions, Fields
using UUIDs: UUID

const LEVEL_INDEX = 2
const HIERARCHY = Mesh.hierarchy(LEVEL_INDEX)
const LEVEL = HIERARCHY.levels[LEVEL_INDEX + 1]
const STENCILS = Mesh.stencils(LEVEL)
const GEOMETRY = Mesh.geometry(LEVEL, STENCILS)
const NCELLS = Mesh.ncells(LEVEL_INDEX)
const RUN = UUID("2f1d4a80-0000-4000-8000-000000000000")

"A `Mesh.Support` at `LEVEL_INDEX`, every field of it overridable."
support(; level_index = LEVEL_INDEX, kind = :icosahedral_bisection, refinement = (),
          radius = 1.0, element_type = :Float64, fractions = ()) =
    Mesh.Support(level_index, LEVEL, GEOMETRY; kind = kind, refinement = refinement,
                  radius = radius, element_type = element_type, fractions = fractions)

const SUPPORT = support()

"A `Time.TimeSupport` over one hour, placed by an interval."
interval_support(; t0 = 0.0, t1 = 3600.0, semantics = Time.IntervalMean()) =
    Time.TimeSupport(semantics, Time.Interval(Time.SimTime(t0), Time.SimTime(t1)))

"A `Time.TimeSupport` with no time axis."
static_support() = Time.TimeSupport(Time.Static())

"A `Fields.Field` over `NCELLS` ones, every declaration overridable."
field(; semantics = Fields.Extensive(), dimension = Dimensions.MASS,
        data = ones(NCELLS), support = SUPPORT, time = interval_support(),
        origin = Fields.unstamped(:fixture, RUN)) =
    Fields.Field(semantics = semantics, dimension = dimension, data = data,
                 support = support, time = time, origin = origin)

"""
    ShiftedOnes(n)

`n` ones on an axis that does not start at one, which is what every kernel in this
package assumes it will never be handed.
"""
struct ShiftedOnes <: AbstractVector{Float64}
    n::Int
end

Base.size(v::ShiftedOnes) = (v.n,)
Base.axes(v::ShiftedOnes) = (0:(v.n - 1),)
Base.getindex(::ShiftedOnes, ::Int) = 1.0

end # module FieldFixtures
