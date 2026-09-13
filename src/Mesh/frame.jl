# The body-fixed frame the mesh's Cartesian coordinates are declared in:
# docs/decisions/0005-one-mesh-icosahedral-triangles.md, section "The body-fixed
# frame and the icosahedron's orientation". BODY_FRAME is the one declaration of
# the spin axis and the prime meridian; base_icosahedron places its corners
# against BODY_FRAME's axes, and every east-north frame, latitude, longitude,
# Coriolis parameter and hour angle reads the axes from it by name.
#
# Every multiply that feeds an add below is written as an explicit fma
# (decision 0044).

using ..Verdicts: refuse

"""
    dot_fma(a, b)

The dot product of the three-tuples `a` and `b`, every multiply that feeds an
add written as `fma`.
"""
dot_fma(a::NTuple{3,T}, b::NTuple{3,T}) where {T<:AbstractFloat} =
    fma(a[1], b[1], fma(a[2], b[2], a[3] * b[3]))

"""
    cross_fma(a, b)

The cross product `a` crossed with `b` of the three-tuples `a` and `b`, every
multiply that feeds an add written as `fma`.
"""
cross_fma(a::NTuple{3,T}, b::NTuple{3,T}) where {T<:AbstractFloat} =
    (fma(a[2], b[3], -(a[3] * b[2])),
     fma(a[3], b[1], -(a[1] * b[3])),
     fma(a[1], b[2], -(a[2] * b[1])))

"""
    BodyFrame(; spin_axis, prime_meridian)

A body-fixed frame as three unit vectors in the mesh's Cartesian coordinates.

- `spin_axis` is the positive pole of rotation: the body turns counterclockwise
  about it seen from outside, the right-hand rule, whatever the sense of that
  rotation relative to the orbit normal. Latitude is positive toward it.
- `prime_meridian` is the equatorial direction of longitude zero.
- `ninety_east` is `spin_axis` crossed with `prime_meridian`, derived here and
  never taken: the equatorial direction of longitude ninety degrees east.
  Longitude increases toward it, which is the direction the surface moves.

The keyword constructor derives `ninety_east` and checks nothing else.
`test/mesh/frame.jl` holds `BODY_FRAME`'s two declared axes to exact unit length
and exact orthogonality.
"""
struct BodyFrame
    spin_axis::NTuple{3,Float64}
    prime_meridian::NTuple{3,Float64}
    ninety_east::NTuple{3,Float64}

    BodyFrame(; spin_axis::NTuple{3,Float64}, prime_meridian::NTuple{3,Float64}) =
        new(spin_axis, prime_meridian, cross_fma(spin_axis, prime_meridian))
end

"""
    BODY_FRAME

The body-fixed frame of every level of the hierarchy: the one declaration of the
spin axis and the prime meridian in `src/`, each along one Cartesian axis of the
mesh's coordinates. `base_icosahedron` places the spin axis through the midpoint
of the base edge joining corners 5 and 6 and the prime meridian through the
midpoint of the base edge joining corners 9 and 10.
"""
const BODY_FRAME = BodyFrame(spin_axis = (zero(Float64), zero(Float64), one(Float64)),
                             prime_meridian = (one(Float64), zero(Float64), zero(Float64)))

"""
    in_frame(frame, a, b, c, T)

The point `a * prime_meridian + b * ninety_east + c * spin_axis` of `frame`, as
a three-tuple in `T`, every multiply that feeds an add written as `fma`.
"""
function in_frame(frame::BodyFrame, a::T, b::T, c::T, ::Type{T}) where {T<:AbstractFloat}
    m, e, s = T.(frame.prime_meridian), T.(frame.ninety_east), T.(frame.spin_axis)
    return (fma(a, m[1], fma(b, e[1], c * s[1])),
            fma(a, m[2], fma(b, e[2], c * s[2])),
            fma(a, m[3], fma(b, e[3], c * s[3])))
end

"""
    latitude(frame, x, y, z)

The latitude in radians of the point `(x, y, z)` in `frame`: `atan` of its
component along `spin_axis` over the length of its component in the equatorial
plane, positive toward `spin_axis`. The point need not be of unit length.
"""
function latitude(frame::BodyFrame, x::Float64, y::Float64, z::Float64)
    p = (x, y, z)
    a = dot_fma(frame.prime_meridian, p)
    b = dot_fma(frame.ninety_east, p)
    return atan(dot_fma(frame.spin_axis, p), sqrt(fma(a, a, b * b)))
end

"""
    longitude(frame, x, y, z)

The longitude in radians, in `(-pi, pi]`, of the point `(x, y, z)` in `frame`:
`atan` of its component along `ninety_east` over its component along
`prime_meridian`, increasing east. The `ninety_east` component has `zero` added
before `atan` reads it, so a negative zero there returns `pi` rather than
`-pi`. Refuses a point on the spin axis, where longitude has no value.
"""
function longitude(frame::BodyFrame, x::Float64, y::Float64, z::Float64)
    p = (x, y, z)
    a = dot_fma(frame.prime_meridian, p)
    b = dot_fma(frame.ninety_east, p)
    (a != zero(a) || b != zero(b)) || refuse(
        "longitude", "Mesh.longitude",
        "the point ($(x), $(y), $(z)) sits on the spin axis; longitude has no value there")
    return atan(b + zero(b), a)
end

"""
    require_body_orientation(frame, orientation, angular_velocity, site)

Returns `nothing` when the 3 by 3 `orientation` places `frame` in an outer frame
as declared, and refuses at `site` naming what fails otherwise. Column `j` of
`orientation` is the outer-frame image of the mesh's Cartesian axis `j`, and
`angular_velocity` is the body's rotation vector in the outer frame.

Two signs decide it: the determinant of `orientation`, the `dot_fma` of its
first column with the `cross_fma` of its second and third, must be positive, so
the placed frame is right-handed; and the image of `frame.spin_axis` must have a
positive `dot_fma` with `angular_velocity`, so the placed spin axis is the
positive pole. A zero `angular_velocity` has no positive pole and is refused.
Orthonormality is not checked here.
"""
function require_body_orientation(frame::BodyFrame, orientation::AbstractMatrix{Float64},
                                  angular_velocity::NTuple{3,Float64}, site::AbstractString)
    size(orientation) == (3, 3) || refuse(
        "body orientation", site,
        "an orientation is 3 by 3; got $(size(orientation, 1)) by $(size(orientation, 2))")
    all(iszero, angular_velocity) && refuse(
        "body orientation", site,
        "a zero angular velocity has no positive pole to place the spin axis on")
    c1 = (orientation[1, 1], orientation[2, 1], orientation[3, 1])
    c2 = (orientation[1, 2], orientation[2, 2], orientation[3, 2])
    c3 = (orientation[1, 3], orientation[2, 3], orientation[3, 3])
    determinant = dot_fma(c1, cross_fma(c2, c3))
    determinant > zero(determinant) || refuse(
        "body orientation", site,
        "the orientation has determinant $(determinant); the placed frame is not right-handed")
    rows = ((orientation[1, 1], orientation[1, 2], orientation[1, 3]),
            (orientation[2, 1], orientation[2, 2], orientation[2, 3]),
            (orientation[3, 1], orientation[3, 2], orientation[3, 3]))
    placed = (dot_fma(rows[1], frame.spin_axis), dot_fma(rows[2], frame.spin_axis),
              dot_fma(rows[3], frame.spin_axis))
    along = dot_fma(placed, angular_velocity)
    along > zero(along) || refuse(
        "body orientation", site,
        "the spin axis is placed at $(placed), against the angular velocity " *
        "$(angular_velocity); the spin axis is the positive pole of rotation")
    return nothing
end
