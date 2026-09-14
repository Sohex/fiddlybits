# Numerics: the declared conventions of how a system is represented that no profile
# may vary. docs/plans/fiddlybits-52v.4-system.md, section "The struct"; decisions
# 0013 (the Exner reference pressure) and 0014.

using ..Verdicts: refuse
using ..Dimensions: Dim
using ..Dispositions: Disposition

"The dimension of a pressure: mass length^-1 time^-2."
const PRESSURE = Dim{1,-1,-2,0,0}()

"The precision the mesh geometry is formed in."
const GEOMETRY_PRECISION = Float64

"""
    Numerics

The conventions of a system's representation that no profile may vary. Build it with
the keyword constructor, which has no defaults:

    Numerics(; exner_reference_pressure, geometry_precision)

`exner_reference_pressure` is a declared pressure above zero; `geometry_precision` is
the type the geometry is formed in, and anything but `Float64` is refused. `Numerics`
carries no epoch: `t = 0` is the instant the declared orbital elements and rotation
phase hold (decision 0008, section The epoch).
"""
struct Numerics{FT}
    exner_reference_pressure::Disposition{FT,typeof(PRESSURE)}
    geometry_precision::Type{Float64}

    Numerics{FT}(::Checked, p, g) where {FT} = new{FT}(p, g)
end

function Numerics(; kwargs...)
    site = "Systems.Numerics"
    k, _ = read_keywords(site, values(kwargs), (:exner_reference_pressure, :geometry_precision), ())
    FT = float_type("exner_reference_pressure", site, k.exner_reference_pressure)
    pressure = require_positive("exner_reference_pressure", site,
        require_disposition("exner_reference_pressure", site, k.exner_reference_pressure,
                            FT, PRESSURE, DECLARED))
    k.geometry_precision === GEOMETRY_PRECISION || refuse(
        "geometry_precision", site,
        "$(k.geometry_precision) where the geometry is formed in $(GEOMETRY_PRECISION)")
    return Numerics{FT}(Checked(), pressure, GEOMETRY_PRECISION)
end
