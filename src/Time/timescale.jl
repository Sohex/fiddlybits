# A timescale declared in rotations and a timescale declared in seconds are different
# declarations, not one with a conversion (decision 0008). The type says which was
# declared, and the arguments `damping` accepts differ with it: a timescale in
# rotations cannot be read without the rotation period it is counted against, and a
# timescale in seconds refuses one.
#
# The identity is system.damping_in_rotations in docs/oracles/registry.toml.

using ..Verdicts: refuse

"""
    Timescale

A declared relaxation time. `InSeconds` and `InRotations` are different declarations
of what a timescale is counted in, and neither converts to the other.
"""
abstract type Timescale end

"""
    InSeconds(seconds)

A timescale counted in SI seconds.
"""
struct InSeconds{T<:AbstractFloat} <: Timescale
    seconds::T

    function InSeconds(seconds::T) where {T<:AbstractFloat}
        (isfinite(seconds) && seconds > 0) ||
            refuse("Timescale", "Time.InSeconds", "the timescale $(seconds) is not positive and finite")
        return new{T}(seconds)
    end
end

InSeconds(seconds::Real) = InSeconds(float(seconds))

"""
    InRotations(rotations)

A timescale counted in rotations of the planet. Reading one takes the rotation period
it is counted against, which is what stops it from silently meaning one planet's day.
"""
struct InRotations{T<:AbstractFloat} <: Timescale
    rotations::T

    function InRotations(rotations::T) where {T<:AbstractFloat}
        (isfinite(rotations) && rotations > 0) ||
            refuse("Timescale", "Time.InRotations", "the timescale $(rotations) is not positive and finite")
        return new{T}(rotations)
    end
end

InRotations(rotations::Real) = InRotations(float(rotations))

"""
    damping(ts::InSeconds, elapsed)

The fraction of a relaxing quantity still present after `elapsed` seconds,
`exp(-elapsed / ts.seconds)`.
"""
function damping(ts::InSeconds, elapsed::Real)
    elapsed >= 0 || refuse("damping", "Time.damping",
                           "the elapsed time $(elapsed) is negative")
    return exp(-elapsed / ts.seconds)
end

"""
    damping(ts::InRotations, elapsed, rotation_period)

The fraction still present after `elapsed` seconds, counted in rotations of
`rotation_period` seconds: `exp(-(elapsed / rotation_period) / ts.rotations)`. At a
fixed number of rotations elapsed the value does not depend on `rotation_period`,
which is `system.damping_in_rotations`.
"""
function damping(ts::InRotations, elapsed::Real, rotation_period::Real)
    elapsed >= 0 || refuse("damping", "Time.damping",
                           "the elapsed time $(elapsed) is negative")
    (isfinite(rotation_period) && rotation_period > 0) ||
        refuse("damping", "Time.damping",
               "the rotation period $(rotation_period) is not positive and finite")
    return exp(-(elapsed / rotation_period) / ts.rotations)
end

damping(ts::InRotations, elapsed::Real) =
    refuse("damping", "Time.damping",
           "a timescale declared in rotations is read against a rotation period, " *
           "which was not given")

damping(ts::InSeconds, elapsed::Real, rotation_period::Real) =
    refuse("damping", "Time.damping",
           "a timescale declared in seconds is not counted in rotations, and a " *
           "rotation period of $(rotation_period) was given")
