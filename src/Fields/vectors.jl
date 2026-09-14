# The basis lifts and projections: docs/plans/fiddlybits-52v.3-fields.md,
# section "Vectors". Only the Cartesian basis may change support; an
# east-north or edge-normal field crosses through it, lifted at the source
# frames and projected at the destination's.
#
# transform and project are the strict and lossy conversions
# docs/imports/climacore-jl.md names: two functions rather than one with a
# flag, so a caller drops a component only by writing project.
#
# Every multiply that feeds an add below is written as an explicit fma
# (decision 0044).

using ..Backends: Backend, CPU, GPU, backend_of, on
using ..Mesh: BODY_FRAME, BodyFrame, cross_fma
using ..Reductions: error_bound

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
    local_east_north(frame, x, y, z)

The east and north unit tangent vectors at the point `(x, y, z)` on the unit
sphere, as two `(x, y, z)` tuples, against the `Mesh.BodyFrame` `frame`:
`east` is `frame.spin_axis` crossed with the point, normalised; `north` is the
point crossed with `east`, which completes a right-handed frame without a
second normalisation. Refuses a point on the spin axis itself, where east has
no direction.
"""
function local_east_north(frame::BodyFrame, x::Float64, y::Float64, z::Float64)
    ex, ey, ez = cross_fma(frame.spin_axis, (x, y, z))
    en = sqrt(ex^2 + ey^2 + ez^2)
    en > zero(en) || refuse(
        "local frame", "Fields.local_east_north",
        "the point ($(x), $(y), $(z)) sits on the spin axis; east has no direction there")
    ex, ey, ez = ex / en, ey / en, ez / en
    nx = fma(y, ez, -(z * ey))
    ny = fma(z, ex, -(x * ez))
    nz = fma(x, ey, -(y * ex))
    return (ex, ey, ez), (nx, ny, nz)
end

"""
    east_north_frame(locations)

The `LocalFrame{:east_north}` at every column of `locations`, 3 by n points
on the unit sphere in the mesh's coordinates, read against `Mesh.BODY_FRAME`,
the frame those coordinates are declared in. Each column is normalised before
`local_east_north` reads it, so a caller passing a point at any radius still
gets unit tangent vectors.
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
        (ex, ey, ez), (nx, ny, nz) = local_east_north(BODY_FRAME, x, y, z)
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
    require_same_backend(fields, site)

Returns `nothing` when every field of `fields` holds its data on the same
`Backends.backend_of`, and refuses at `site` naming the first pair of
backends that differ otherwise.
"""
function require_same_backend(fields::Tuple, site::AbstractString)
    first_backend = backend_of(data(fields[1]))
    for i in 2:length(fields)
        this_backend = backend_of(data(fields[i]))
        this_backend === first_backend || refuse(
            "vector component backend", site,
            "component 1 lives on $(first_backend) and component $(i) on $(this_backend)")
    end
    return nothing
end

"""
    target_backend(array)

The `Backends.CPU` or `Backends.GPU` instance matching the backend `array`
already lives on, from `Backends.backend_of`.
"""
target_backend(array::AbstractArray) = backend_of(array) === :cpu ? CPU() : GPU()

"""
    frame_on(frame, backend)

`frame` with every axis moved to `backend` through `Backends.on`, which
records the move and returns an axis unchanged when it already lives there.
"""
frame_on(frame::LocalFrame{Basis}, backend::Backend) where {Basis} =
    LocalFrame{Basis}(map(axis -> on(axis, backend), frame.axes))

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
axes of `components[i] .* frame.axes[i][row, :]`, every multiply that feeds
an add written as `fma`. Always exact: embedding a one- or two-axis
component set into three Cartesian components by this sum drops nothing, so
`lift` never refuses on the values it is given.

Every field of `components` must agree in time semantics, dimension, support
and run (`require_vector_agreement`) and must share one backend
(`require_same_backend`); `frame` is moved to that backend through
`Backends.on` before the sum, so `components` and `frame` broadcast
together whichever backend `components` already lives on.
"""
function lift(components::NTuple{1,Field{VectorComponent{Basis}}},
              frame::LocalFrame{Basis,1}) where {Basis}
    require_vector_agreement(components, "Fields.lift")
    require_same_backend(components, "Fields.lift")
    d1 = data(components[1])
    require_frame_extent(length(d1), frame, "Fields.lift")
    moved = frame_on(frame, target_backend(d1))
    a1 = moved.axes[1]
    f = components[1]
    x = basis_field(f, d1 .* view(a1, 1, :), Val(:cartesian), :lift)
    y = basis_field(f, d1 .* view(a1, 2, :), Val(:cartesian), :lift)
    z = basis_field(f, d1 .* view(a1, 3, :), Val(:cartesian), :lift)
    return (x, y, z)
end

function lift(components::NTuple{2,Field{VectorComponent{Basis}}},
              frame::LocalFrame{Basis,2}) where {Basis}
    require_vector_agreement(components, "Fields.lift")
    require_same_backend(components, "Fields.lift")
    d1, d2 = data(components[1]), data(components[2])
    require_frame_extent(length(d1), frame, "Fields.lift")
    moved = frame_on(frame, target_backend(d1))
    a1, a2 = moved.axes
    f = components[1]
    x = basis_field(f, fma.(d1, view(a1, 1, :), d2 .* view(a2, 1, :)), Val(:cartesian), :lift)
    y = basis_field(f, fma.(d1, view(a1, 2, :), d2 .* view(a2, 2, :)), Val(:cartesian), :lift)
    z = basis_field(f, fma.(d1, view(a1, 3, :), d2 .* view(a2, 3, :)), Val(:cartesian), :lift)
    return (x, y, z)
end

"""
    project(cartesian, frame)

`cartesian`'s three components read into `frame`'s basis by a dot product
with each axis, every multiply that feeds an add written as `fma`: one field
per axis, in the order `frame` declares them. The lossy conversion: whatever
`cartesian` holds outside `frame`'s subspace is dropped without being
checked, which is why `coarsen` and `refine` name this function rather than
reaching it themselves.

`cartesian` must agree in time semantics, dimension, support and run
(`require_vector_agreement`) and share one backend (`require_same_backend`);
`frame` is moved to that backend through `Backends.on` before the dot
product.
"""
function project(cartesian::NTuple{3,Field{VectorComponent{:cartesian}}},
                  frame::LocalFrame{Basis,1}) where {Basis}
    require_vector_agreement(cartesian, "Fields.project")
    require_same_backend(cartesian, "Fields.project")
    dx, dy, dz = data(cartesian[1]), data(cartesian[2]), data(cartesian[3])
    require_frame_extent(length(dx), frame, "Fields.project")
    moved = frame_on(frame, target_backend(dx))
    a1 = moved.axes[1]
    c1 = fma.(dz, view(a1, 3, :), fma.(dy, view(a1, 2, :), dx .* view(a1, 1, :)))
    return (basis_field(cartesian[1], c1, Val(Basis), :project),)
end

function project(cartesian::NTuple{3,Field{VectorComponent{:cartesian}}},
                  frame::LocalFrame{Basis,2}) where {Basis}
    require_vector_agreement(cartesian, "Fields.project")
    require_same_backend(cartesian, "Fields.project")
    dx, dy, dz = data(cartesian[1]), data(cartesian[2]), data(cartesian[3])
    require_frame_extent(length(dx), frame, "Fields.project")
    moved = frame_on(frame, target_backend(dx))
    a1, a2 = moved.axes
    c1 = fma.(dz, view(a1, 3, :), fma.(dy, view(a1, 2, :), dx .* view(a1, 1, :)))
    c2 = fma.(dz, view(a2, 3, :), fma.(dy, view(a2, 2, :), dx .* view(a2, 1, :)))
    return (basis_field(cartesian[1], c1, Val(Basis), :project),
            basis_field(cartesian[1], c2, Val(Basis), :project))
end

"""
    round_trip_terms(n_axes)

The floating point operations one `project` followed by one `lift` performs
to reconstruct a single Cartesian component from a frame of `n_axes` axes,
read as the term count `Reductions.error_bound` takes: each axis costs
`project`'s three-multiply, two-add dot product against the Cartesian
components (5 operations), and `lift` then costs an `n_axes`-multiply,
`n_axes - 1`-add combination of the `n_axes` projected values (`2 * n_axes -
1` operations). Over `Integer`, exempted by name in
`test/lint/lists/fused_multiply_add.toml` rather than restructured
(decision 0044, "Integer arithmetic is exempted by name, not by shape").
"""
round_trip_terms(n_axes::Integer) = 7 * n_axes - 1

"""
    round_trip_magnitude(cartesian, frame)

An upper bound on the absolute value of any term `round_trip_terms` counts,
read off `cartesian` and `frame` rather than declared: the largest sum of
`cartesian`'s three components' absolute values at one cell or edge,
(`Reductions.error_bound`'s `magnitude`), times the square of the largest
single entry any axis of `frame` holds. The square is the two axis-component
factors one term carries, one from `project`'s dot product and one from
`lift`'s combination. The per-cell sum is formed on `cartesian`'s own
backend and read back through `Backends.on` in the one move below;
`frame`'s axes already live on the host, so `axis_magnitude` reads them
directly.
"""
function round_trip_magnitude(cartesian::NTuple{3,Field}, frame::LocalFrame)
    ax, ay, az = data(cartesian[1]), data(cartesian[2]), data(cartesian[3])
    per_cell = on(abs.(ax) .+ abs.(ay) .+ abs.(az), CPU(1))
    cartesian_magnitude = maximum(per_cell)
    axis_magnitude = maximum(maximum(abs, axis) for axis in frame.axes)
    return cartesian_magnitude * axis_magnitude^2
end

"""
    check_round_trip(cartesian, reconstructed, frame, site, basis)

Returns `nothing` when every one of `cartesian`'s three components matches
the corresponding component of `reconstructed` within
`Reductions.error_bound(eltype(data), round_trip_terms(length(frame.axes)),
round_trip_magnitude(cartesian, frame))`, and refuses at `site` naming the
component, the residual and `basis` otherwise. The bound scales with
`cartesian`'s own magnitude and carries no floor, so a field read in
different units is judged against the same relative tolerance.

The three components' residuals are formed on `cartesian`'s own backend and
read back together, in the one move `Backends.on` below, rather than once
per component.
"""
function check_round_trip(cartesian::NTuple{3,Field}, reconstructed::NTuple{3,Field},
                           frame::LocalFrame, site::AbstractString, basis::Symbol)
    labels = (:x, :y, :z)
    terms = round_trip_terms(length(frame.axes))
    magnitude = round_trip_magnitude(cartesian, frame)
    on_device(k) = abs.(data(cartesian[k]) .- data(reconstructed[k]))
    residuals = on(hcat(on_device(1), on_device(2), on_device(3)), CPU(1))
    bound = error_bound(eltype(residuals), terms, magnitude)
    for k in 1:3
        residual = maximum(view(residuals, :, k))
        residual <= bound || refuse(
            "vector transform", site,
            "the $(labels[k]) component of $(type_name(VectorComponent{basis})) drops " *
            "$(residual), beyond the bound $(bound); call Fields.project to allow it")
    end
    return nothing
end

"""
    transform(cartesian, frame)

`project(cartesian, frame)`, refused instead of returned when lifting the
result back through `frame` does not reproduce `cartesian` within
`check_round_trip`'s bound. The strict conversion: a caller who wants the
dropped component silently discarded writes `project` by name, and
`transform` never reaches that path on its own.
"""
function transform(cartesian::NTuple{3,Field{VectorComponent{:cartesian}}},
                    frame::LocalFrame{Basis,N}) where {Basis,N}
    result = project(cartesian, frame)
    reconstructed = lift(result, frame)
    check_round_trip(cartesian, reconstructed, frame, "Fields.transform", Basis)
    return result
end
