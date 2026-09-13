# The basis lifts and projections: docs/plans/fiddlybits-52v.3-fields.md,
# section "Vectors". Only the Cartesian basis may change support; an
# east-north or edge-normal field crosses through it, lifted at the source
# frames and projected at the destination's.
#
# transform and project are the strict and lossy conversions
# docs/imports/climacore-jl.md names: two functions rather than one with a
# flag, so a caller drops a component only by writing project.

"""
    LocalFrame{Basis,N,M}

The `N` unit vectors a `VectorComponent{Basis}` field's components are
declared against, one 3 by n matrix per axis, in the order `Basis` lists
them: `(east, north)` for `:east_north`, `(normal,)` for `:edge_normal`.
`:cartesian` needs none; its axes are the fixed standard basis and never
travel as data.
"""
struct LocalFrame{Basis,N,M<:AbstractMatrix}
    axes::NTuple{N,M}

    function LocalFrame{Basis,N,M}(axes::NTuple{N,M}) where {Basis,N,M<:AbstractMatrix}
        n = size(axes[1], 2)
        for axis in axes
            size(axis, 1) == 3 || refuse(
                "local frame", "Fields.LocalFrame",
                "an axis of a $(Basis) frame is $(size(axis, 1)) by $(size(axis, 2)); " *
                "every axis is 3 by n")
            size(axis, 2) == n || refuse(
                "local frame", "Fields.LocalFrame",
                "the axes of a $(Basis) frame disagree in column count: $(n) and " *
                "$(size(axis, 2))")
        end
        return new{Basis,N,M}(axes)
    end
end

LocalFrame{Basis}(axes::NTuple{N,M}) where {Basis,N,M<:AbstractMatrix} =
    LocalFrame{Basis,N,M}(axes)

"""
    POLAR_AXIS

The Cartesian direction `(0, 0, 1)` this module reads as the sphere's pole,
the one direction east and north are declared against. The one place this
module names it; `local_east_north` is the one place it is read.
"""
const POLAR_AXIS = (zero(Float64), zero(Float64), one(Float64))

"""
    local_east_north(x, y, z)

The east and north unit tangent vectors at the point `(x, y, z)` on the unit
sphere, as two `(x, y, z)` tuples: `east` is `POLAR_AXIS` crossed with the
point, normalised; `north` is the point crossed with `east`, which completes
a right-handed frame without a second normalisation. Refuses a point on the
polar axis itself, where east has no direction.
"""
function local_east_north(x::Float64, y::Float64, z::Float64)
    ex, ey, ez = -y, x, zero(x)
    en = sqrt(ex^2 + ey^2 + ez^2)
    en > zero(en) || refuse(
        "local frame", "Fields.local_east_north",
        "the point ($(x), $(y), $(z)) sits on the polar axis; east has no direction there")
    ex, ey, ez = ex / en, ey / en, ez / en
    nx = fma(y, ez, -(z * ey))
    ny = fma(z, ex, -(x * ez))
    nz = fma(x, ey, -(y * ex))
    return (ex, ey, ez), (nx, ny, nz)
end

"""
    east_north_frame(locations)

The `LocalFrame{:east_north}` at every column of `locations`, 3 by n points
on the unit sphere. Each column is normalised before `local_east_north` reads
it, so a caller passing a point at any radius still gets unit tangent
vectors.
"""
function east_north_frame(locations::AbstractMatrix{<:Real})
    size(locations, 1) == 3 || refuse(
        "local frame", "Fields.east_north_frame",
        "locations must be 3 by n; got $(size(locations, 1)) by $(size(locations, 2))")
    n = size(locations, 2)
    east = Matrix{Float64}(undef, 3, n)
    north = Matrix{Float64}(undef, 3, n)
    for j in 1:n
        px, py, pz = Float64(locations[1, j]), Float64(locations[2, j]), Float64(locations[3, j])
        r = sqrt(px^2 + py^2 + pz^2)
        x, y, z = px / r, py / r, pz / r
        (ex, ey, ez), (nx, ny, nz) = local_east_north(x, y, z)
        east[1, j], east[2, j], east[3, j] = ex, ey, ez
        north[1, j], north[2, j], north[3, j] = nx, ny, nz
    end
    return LocalFrame{:east_north}((east, north))
end

"""
    edge_normal_frame(normal)

The `LocalFrame{:edge_normal}` over `normal`, 3 by n unit tangent vectors,
read as they stand rather than derived: `Mesh.Geometry.edge_normal` already
carries the one convention this basis names.
"""
function edge_normal_frame(normal::AbstractMatrix{<:Real})
    size(normal, 1) == 3 || refuse(
        "local frame", "Fields.edge_normal_frame",
        "normal must be 3 by n; got $(size(normal, 1)) by $(size(normal, 2))")
    return LocalFrame{:edge_normal}((Matrix{Float64}(normal),))
end

"""
    require_vector_agreement(components, site)

Returns `nothing` when every field of `components` agrees in time semantics,
dimension, support and run, raising at `site` through `require_combinable`
naming the first pair that differs otherwise. Every component already shares
one `Basis` on its type, so their semantics agree by construction.
"""
function require_vector_agreement(components::Tuple, site::AbstractString)
    for i in 2:length(components)
        require_combinable(components[1], components[i], site)
    end
    return nothing
end

"""
    require_frame_extent(n, frame, site)

Returns `nothing` when every axis of `frame` holds `n` columns, one per cell
or edge of the vector `frame` declares components against, and refuses at
`site` naming both counts otherwise.
"""
function require_frame_extent(n::Integer, frame::LocalFrame, site::AbstractString)
    for axis in frame.axes
        size(axis, 2) == n || refuse(
            "local frame extent", site,
            "the field holds $(n) cells and the frame holds $(size(axis, 2))")
    end
    return nothing
end

"""
    basis_field(f, data, ::Val{Basis}, writer)

`data` carrying `f`'s dimension, time support and support, declaring
`VectorComponent{Basis}`, with an unstamped origin written by `writer` in
`f`'s run. The one place `lift`, `project` and `transform` build a result.
"""
basis_field(f::Field{S,T,D}, data::AbstractArray, ::Val{Basis}, writer::Symbol) where {S,T,D,Basis} =
    Field(semantics = VectorComponent{Basis}(), dimension = D(), data = data,
          support = f.support, time = f.time, origin = unstamped(writer, f.origin.run))

"""
    lift(components, frame)

The Cartesian vector `components` and `frame` together declare: three fields
of `VectorComponent{:cartesian}`, `(x, y, z)`, each the sum over `frame`'s
axes of `components[i] .* frame.axes[i][row, :]`. Always exact: embedding a
one- or two-axis component set into three Cartesian components by this sum
drops nothing, so `lift` never refuses on the values it is given.

Every field of `components` must agree in time semantics, dimension, support
and run; `require_vector_agreement` raises naming what differs otherwise.
"""
function lift(components::NTuple{1,Field{VectorComponent{Basis}}},
              frame::LocalFrame{Basis,1}) where {Basis}
    require_vector_agreement(components, "Fields.lift")
    d1 = data(components[1])
    require_frame_extent(length(d1), frame, "Fields.lift")
    a1 = frame.axes[1]
    f = components[1]
    x = basis_field(f, d1 .* view(a1, 1, :), Val(:cartesian), :lift)
    y = basis_field(f, d1 .* view(a1, 2, :), Val(:cartesian), :lift)
    z = basis_field(f, d1 .* view(a1, 3, :), Val(:cartesian), :lift)
    return (x, y, z)
end

function lift(components::NTuple{2,Field{VectorComponent{Basis}}},
              frame::LocalFrame{Basis,2}) where {Basis}
    require_vector_agreement(components, "Fields.lift")
    d1, d2 = data(components[1]), data(components[2])
    require_frame_extent(length(d1), frame, "Fields.lift")
    a1, a2 = frame.axes
    f = components[1]
    x = basis_field(f, d1 .* view(a1, 1, :) .+ d2 .* view(a2, 1, :), Val(:cartesian), :lift)
    y = basis_field(f, d1 .* view(a1, 2, :) .+ d2 .* view(a2, 2, :), Val(:cartesian), :lift)
    z = basis_field(f, d1 .* view(a1, 3, :) .+ d2 .* view(a2, 3, :), Val(:cartesian), :lift)
    return (x, y, z)
end

"""
    project(cartesian, frame)

`cartesian`'s three components read into `frame`'s basis by a dot product
with each axis: one field per axis, in the order `frame` declares them. The
lossy conversion: whatever `cartesian` holds outside `frame`'s subspace is
dropped without being checked, which is why `coarsen` and `refine` name this
function rather than reaching it themselves.
"""
function project(cartesian::NTuple{3,Field{VectorComponent{:cartesian}}},
                  frame::LocalFrame{Basis,1}) where {Basis}
    require_vector_agreement(cartesian, "Fields.project")
    dx, dy, dz = data(cartesian[1]), data(cartesian[2]), data(cartesian[3])
    require_frame_extent(length(dx), frame, "Fields.project")
    a1 = frame.axes[1]
    c1 = dx .* view(a1, 1, :) .+ dy .* view(a1, 2, :) .+ dz .* view(a1, 3, :)
    return (basis_field(cartesian[1], c1, Val(Basis), :project),)
end

function project(cartesian::NTuple{3,Field{VectorComponent{:cartesian}}},
                  frame::LocalFrame{Basis,2}) where {Basis}
    require_vector_agreement(cartesian, "Fields.project")
    dx, dy, dz = data(cartesian[1]), data(cartesian[2]), data(cartesian[3])
    require_frame_extent(length(dx), frame, "Fields.project")
    a1, a2 = frame.axes
    c1 = dx .* view(a1, 1, :) .+ dy .* view(a1, 2, :) .+ dz .* view(a1, 3, :)
    c2 = dx .* view(a2, 1, :) .+ dy .* view(a2, 2, :) .+ dz .* view(a2, 3, :)
    return (basis_field(cartesian[1], c1, Val(Basis), :project),
            basis_field(cartesian[1], c2, Val(Basis), :project))
end

"""
    TRANSFORM_ULPS

The rounding bound `transform` refuses beyond, in units of `eps` of the
Cartesian data's own element type: one epsilon per floating point operation
a `project` followed by a `lift` performs on one component, the dot product
and the sum back that `check_round_trip` re-derives.
"""
const TRANSFORM_ULPS = 16

"""
    check_round_trip(cartesian, reconstructed, site, basis)

Returns `nothing` when every one of `cartesian`'s three components matches
the corresponding component of `reconstructed` within `TRANSFORM_ULPS` times
`eps` of its element type, scaled by its own magnitude, and refuses at `site`
naming the component, the residual and `basis` otherwise.
"""
function check_round_trip(cartesian::NTuple{3,Field}, reconstructed::NTuple{3,Field},
                           site::AbstractString, basis::Symbol)
    labels = (:x, :y, :z)
    for k in 1:3
        a = data(cartesian[k])
        b = data(reconstructed[k])
        bound = TRANSFORM_ULPS * eps(eltype(a)) .* max.(one(eltype(a)), abs.(a))
        residual = abs.(a .- b)
        all(residual .<= bound) || refuse(
            "vector transform", site,
            "the $(labels[k]) component of $(type_name(VectorComponent{basis})) drops " *
            "$(maximum(residual)); call Fields.project to allow it")
    end
    return nothing
end

"""
    transform(cartesian, frame)

`project(cartesian, frame)`, refused instead of returned when lifting the
result back through `frame` does not reproduce `cartesian` within
`TRANSFORM_ULPS`. The strict conversion: a caller who wants the dropped
component silently discarded writes `project` by name, and `transform` never
reaches that path on its own.
"""
function transform(cartesian::NTuple{3,Field{VectorComponent{:cartesian}}},
                    frame::LocalFrame{Basis,N}) where {Basis,N}
    result = project(cartesian, frame)
    reconstructed = lift(result, frame)
    check_round_trip(cartesian, reconstructed, "Fields.transform", Basis)
    return result
end
