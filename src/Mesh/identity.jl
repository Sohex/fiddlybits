# The support identity: docs/plans/fiddlybits-52v.2-mesh.md, section "The
# support identity". REQ-TER-002 lists every field the digest covers and the
# same-shape-different-support cases that forced it.

using ..Verdicts: Refusal, refuse
using SHA: sha256

"""
    GEOMETRY_CONSTRUCTOR_VERSION

Raised whenever any geometry definition in this module changes, so a changed
constructor changes every `Support` identity built after the change
(REQ-TER-002).
"""
const GEOMETRY_CONSTRUCTOR_VERSION = 1

"""
    write_le!(io, x)

Writes `x` to `io` as fixed-width bytes in a byte order independent of host
endianness, so a digest built from this file reproduces bit for bit in
another process.
"""
write_le!(io::IO, x::UInt64) = write(io, htol(x))
write_le!(io::IO, x::Int64) = write_le!(io, reinterpret(UInt64, x))
write_le!(io::IO, x::Float64) = write_le!(io, reinterpret(UInt64, x))

"""
    write_symbol!(io, s)

Writes `Symbol` `s` to `io` as its length-prefixed UTF-8 name.
"""
function write_symbol!(io::IO, s::Symbol)
    bytes = codeunits(String(s))
    write_le!(io, UInt64(length(bytes)))
    write(io, bytes)
    return io
end

"""
    write_digest!(io, d)

Writes the 32 bytes of the sha256 digest `d` to `io`, in order.
"""
function write_digest!(io::IO, d::NTuple{32,UInt8})
    for b in d
        write(io, b)
    end
    return io
end

"""
    RefinementRegions

The type `Support` and `digest_refinement` take a refinement region set as:
any vector or tuple of `(a, b)` integer pairs. Neither the order the pairs
arrive in nor a repeated pair is part of the identity; `digest_refinement`
canonicalises both away before hashing.
"""
const RefinementRegions = Union{AbstractVector{<:Tuple{Integer,Integer}},
                                 Tuple{Vararg{Tuple{Integer,Integer}}}}

"""
    digest_refinement(refinement)

The digest over the refinement region set: a length prefix, then each
distinct `(a, b)` region as an `(Int64, Int64)` pair, sorted ascending by
`(a, b)`. Two refinements holding the same regions, in any order or with a
region repeated, produce this same digest. A uniform level passes an empty
set and gets the digest of that empty set.
"""
function digest_refinement(refinement::RefinementRegions)
    regions = sort!(collect(Set((Int64(a), Int64(b)) for (a, b) in refinement)))
    io = IOBuffer()
    write_le!(io, UInt64(length(regions)))
    for (a, b) in regions
        write_le!(io, a)
        write_le!(io, b)
    end
    return Tuple(sha256(take!(io)))
end

"""
    digest_coordinates(vertices)

The digest over `vertices`, 3 by `n`: a length prefix, then every column's
three components in column order, each promoted to `Float64` before writing
so the byte width is fixed regardless of the level's own working type.
"""
function digest_coordinates(vertices::AbstractMatrix)
    io = IOBuffer()
    write_le!(io, UInt64(size(vertices, 2)))
    for j in axes(vertices, 2)
        write_le!(io, Float64(vertices[1, j]))
        write_le!(io, Float64(vertices[2, j]))
        write_le!(io, Float64(vertices[3, j]))
    end
    return Tuple(sha256(take!(io)))
end

"""
    digest_lineage(level)

The digest over the base level's vertices, the columns `1:nvertices(0)` of
`level.vertices`. `bisect` carries every existing vertex forward unchanged at
the same column, so those columns hold the same twelve values at every level
one hierarchy produces, and `digest_lineage` returns the same digest for any
of them. A level bisected from a different base icosahedra carries different
values there and gets a different digest, whatever its kind, radius or
element type (`fiddlybits-52v.2.14`, REQ-TER-002).
"""
function digest_lineage(level::Level)
    base = nvertices(0)
    size(level.vertices, 2) >= base || refuse(
        "lineage extent", "Mesh.digest_lineage",
        "a level of $(size(level.vertices, 2)) vertices holds fewer than the " *
        "$(base) vertices of the base level")
    return digest_coordinates(view(level.vertices, :, 1:base))
end

"""
    write_measure!(io, values, radius, power)

Writes one native measure to `io`: a length prefix, then every entry of
`values` scaled to `radius` through `at_radius` and nowhere else, each
promoted to `Float64` before scaling.
"""
function write_measure!(io::IO, values::AbstractVector, radius::Float64, power::Integer)
    write_le!(io, UInt64(length(values)))
    for v in values
        write_le!(io, at_radius(Float64(v), radius, power))
    end
    return io
end

"""
    digest_measures(geometry, radius)

The digest over both native measures of `geometry` as formed at `radius`:
primal cell area and dual cell area at power two, primal edge length and
dual edge length at power one, in that order.
"""
function digest_measures(geometry::Geometry, radius::Float64)
    io = IOBuffer()
    write_measure!(io, geometry.cell_area, radius, 2)
    write_measure!(io, geometry.dual_area, radius, 2)
    write_measure!(io, geometry.primal_edge_length, radius, 1)
    write_measure!(io, geometry.dual_edge_length, radius, 1)
    return Tuple(sha256(take!(io)))
end

"""
    digest_fractions(fractions)

The digest over any effective fraction a field uses: a count of the
fractions, then for each one, in the order `fractions` iterates, a length
prefix and every entry promoted to `Float64`. A caller with no effective
fraction passes an empty `fractions` and gets the digest of that empty set.
"""
function digest_fractions(fractions)
    io = IOBuffer()
    write_le!(io, UInt64(length(fractions)))
    for values in fractions
        write_le!(io, UInt64(length(values)))
        for v in values
            write_le!(io, Float64(v))
        end
    end
    return Tuple(sha256(take!(io)))
end

"""
    Support{L}

The versioned support identity of hierarchy level `L` (REQ-TER-002). Carries
one field for every quantity the digest covers, plus the digest itself, so a
consumer holding two arrays compares two identities and never two axes or
shapes.

`kind` is the family recipe symbol, `:icosahedral_bisection` for this
hierarchy. `level` equals the type parameter `L`. `refinement_digest` covers
the refinement region set, empty for a uniform level. `constructor_version`
is `GEOMETRY_CONSTRUCTOR_VERSION`, read here rather than taken from the
caller, so a changed geometry constructor changes every identity built after
it and no caller can carry a stale one. `coordinate_digest` covers the
finest-level vertex coordinates.
`measure_digest` covers both native measures as formed at `radius`.
`element_type` is the type the geometry was formed in. `fraction_digest`
covers any effective fraction a field uses, empty when there is none.
`digest` covers every field above.

`lineage_digest` is `digest_lineage(level)`, carried outside `digest` because
REQ-TER-002 does not name it among the digest's own fields: it answers
whether a coarser support could be another's ancestor, which `require_ancestor`
reads it for, and it is not part of what makes two supports the same support.
"""
struct Support{L}
    kind::Symbol
    level::Int
    refinement_digest::NTuple{32,UInt8}
    constructor_version::Int
    coordinate_digest::NTuple{32,UInt8}
    measure_digest::NTuple{32,UInt8}
    radius::Float64
    element_type::Symbol
    fraction_digest::NTuple{32,UInt8}
    digest::NTuple{32,UInt8}
    lineage_digest::NTuple{32,UInt8}
end

"""
    support_digest(; kind, level, refinement_digest, constructor_version,
                     coordinate_digest, measure_digest, radius, element_type,
                     fraction_digest)

The digest over every field of a `Support`, in the order REQ-TER-002 lists
them. Separate from the constructor so a test can vary one field, including
`constructor_version`, which the constructor does not take.
"""
function support_digest(; kind::Symbol, level::Integer, refinement_digest::NTuple{32,UInt8},
                          constructor_version::Integer, coordinate_digest::NTuple{32,UInt8},
                          measure_digest::NTuple{32,UInt8}, radius::Float64,
                          element_type::Symbol, fraction_digest::NTuple{32,UInt8})
    io = IOBuffer()
    write_symbol!(io, kind)
    write_le!(io, Int64(level))
    write_digest!(io, refinement_digest)
    write_le!(io, Int64(constructor_version))
    write_digest!(io, coordinate_digest)
    write_digest!(io, measure_digest)
    write_le!(io, radius)
    write_symbol!(io, element_type)
    write_digest!(io, fraction_digest)
    return Tuple(sha256(take!(io)))
end

"""
    Support(level_index, level, geometry; kind, refinement, radius,
            element_type, fractions)

The `Support{level_index}` built from `level`'s coordinates and `geometry`'s
native measures at `radius`, which reaches the measures through `at_radius`
and nowhere else. Every keyword is required: a silent default across this
boundary is what REQ-TER-002 is built against.

`refinement` is a `RefinementRegions`: any vector or tuple of `(a, b)`
integer pairs, passed on to `digest_refinement`.

`constructor_version` is not a keyword. It is read from
`GEOMETRY_CONSTRUCTOR_VERSION` here, so a caller cannot hold an identity at a
version the geometry no longer has.
"""
function Support(level_index::Integer, level::Level, geometry::Geometry;
                  kind::Symbol, refinement::RefinementRegions, radius::Float64,
                  element_type::Symbol, fractions)
    L = Int(level_index)
    refinement_digest = digest_refinement(refinement)
    coordinate_digest = digest_coordinates(level.vertices)
    measure_digest = digest_measures(geometry, radius)
    fraction_digest = digest_fractions(fractions)
    lineage_digest = digest_lineage(level)

    digest = support_digest(; kind = kind, level = L,
                             refinement_digest = refinement_digest,
                             constructor_version = GEOMETRY_CONSTRUCTOR_VERSION,
                             coordinate_digest = coordinate_digest,
                             measure_digest = measure_digest, radius = radius,
                             element_type = element_type,
                             fraction_digest = fraction_digest)

    return Support{L}(kind, L, refinement_digest, GEOMETRY_CONSTRUCTOR_VERSION,
                       coordinate_digest, measure_digest, radius, element_type,
                       fraction_digest, digest, lineage_digest)
end

"""
    ==(a::Support, b::Support)

Compares the digest alone, never the shape.
"""
Base.:(==)(a::Support, b::Support) = a.digest == b.digest

"""
    hash(s::Support, h::UInt)

Hashes on the digest, consistent with `==`.
"""
Base.hash(s::Support, h::UInt) = hash(s.digest, h)

"""
    require_same_support(a, b, site)

Raises the `Refusal` of `Verdicts` at `site`, naming both digests, when `a`
and `b` carry different digests. Returns `nothing` when they match. Declared
here because the identity is declared here; `Fields` calls this on every
binary operation between two fields.
"""
function require_same_support(a::Support, b::Support, site::AbstractString)
    a.digest == b.digest && return nothing
    refuse("support identity", site,
           "support $(bytes2hex(a.digest)) does not match support $(bytes2hex(b.digest))")
end

"""
    require_ancestor(from, to, site)

Returns `nothing` when `to` could be a level of the same hierarchy as `from`,
coarser or finer, and refuses at `site` naming the first field that differs
otherwise. Compares `kind`, `radius`, `element_type`, `refinement_digest` and
`lineage_digest` (REQ-TER-002).
"""
function require_ancestor(from::Support, to::Support, site::AbstractString)
    for name in (:kind, :radius, :element_type, :refinement_digest, :lineage_digest)
        a, b = getproperty(from, name), getproperty(to, name)
        a == b || refuse("support ancestry", site,
                         "the supports differ in $(name): $(repr(a)) and $(repr(b))")
    end
    return nothing
end

"""
    shape_digest(level, geometry, radius)

The positive control of `mesh.support_identity`: a digest over shape alone,
vertex count, cell count and edge count, with no coordinates and no
measures. Takes `radius` and never reads it, so two calls that differ only
in `radius` collide, which `Support`'s own digest must not do.
"""
function shape_digest(level::Level, geometry::Geometry, radius::Float64)
    io = IOBuffer()
    write_le!(io, UInt64(size(level.vertices, 2)))
    write_le!(io, UInt64(size(level.cells, 2)))
    write_le!(io, UInt64(length(geometry.primal_edge_length)))
    return Tuple(sha256(take!(io)))
end
