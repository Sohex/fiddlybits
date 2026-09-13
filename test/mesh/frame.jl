using Test
using Fiddlybits: Mesh, Fields, Reductions
using Fiddlybits.Verdicts: Refusal

# The body-fixed frame: docs/decisions/0005-one-mesh-icosahedral-triangles.md,
# section "The body-fixed frame and the icosahedron's orientation", and the
# acceptance of fiddlybits-52v.2.16.

const BF = Mesh.BODY_FRAME
const SRC = normpath(joinpath(@__DIR__, "..", "..", "src"))
const FRAME_FILE = joinpath("Mesh", "frame.jl")

"One entry of a triple that may write an axis: zero or plus or minus one, as a literal or a `zero`/`one` call."
const AXIS_ENTRY = raw"-?\s*(?:0|1|0\.0|1\.0|0f0|1f0|zero\([^()]*\)|one\([^()]*\))"

"A tuple, vector or constructor call of three `AXIS_ENTRY` entries."
const AXIS_TRIPLE = Regex("[\\(\\[]\\s*(" * AXIS_ENTRY * ")\\s*,\\s*(" * AXIS_ENTRY *
                          ")\\s*,\\s*(" * AXIS_ENTRY * ")\\s*[\\)\\]]")

"An `AXIS_ENTRY` that is plus or minus one."
const UNIT_ENTRY = r"^-?\s*(?:1|1\.0|1f0|one\([^()]*\))$"

"""
    axis_triples(path, text)

The `(path, line number, match)` of every `AXIS_TRIPLE` in `text` with exactly
one entry plus or minus one, which is a Cartesian axis written by coordinate.
"""
function axis_triples(path::AbstractString, text::AbstractString)
    found = Tuple{String,Int,String}[]
    for (i, line) in enumerate(split(text, '\n')), m in eachmatch(AXIS_TRIPLE, line)
        count(e -> occursin(UNIT_ENTRY, strip(e)), m.captures) == 1 &&
            push!(found, (String(path), i, m.match))
    end
    return found
end

"Every `axis_triples` site in every `.jl` file under `root`, paths relative to `root`."
function axis_triples_under(root::AbstractString)
    found = Tuple{String,Int,String}[]
    for (dir, _, files) in walkdir(root), file in files
        endswith(file, ".jl") || continue
        path = joinpath(dir, file)
        append!(found, axis_triples(relpath(path, root), read(path, String)))
    end
    return found
end

"`p` scaled to unit length."
function unit(p::NTuple{3,Float64})
    n = sqrt(p[1]^2 + p[2]^2 + p[3]^2)
    return (p[1] / n, p[2] / n, p[3] / n)
end

"Column `j` of `m` as a three-tuple."
col(m::AbstractMatrix, j::Integer) = (Float64(m[1, j]), Float64(m[2, j]), Float64(m[3, j]))

"`m` times the three-tuple `v`."
apply(m::AbstractMatrix, v::NTuple{3,Float64}) =
    (Mesh.dot_fma((m[1, 1], m[1, 2], m[1, 3]), v),
     Mesh.dot_fma((m[2, 1], m[2, 2], m[2, 3]), v),
     Mesh.dot_fma((m[3, 1], m[3, 2], m[3, 3]), v))

"""
    placement(meridian, east, pole)

The 3 by 3 orientation carrying `BF.prime_meridian`, `BF.ninety_east` and
`BF.spin_axis` to the outer-frame directions `meridian`, `east` and `pole`: the
sum of the three outer products, built from the frame's names.
"""
function placement(meridian, east, pole)
    m = zeros(3, 3)
    for i in 1:3, j in 1:3
        m[i, j] = fma(meridian[i], BF.prime_meridian[j],
                      fma(east[i], BF.ninety_east[j], pole[i] * BF.spin_axis[j]))
    end
    return m
end

"The cell centres of level `L`, each scaled to unit length."
function cell_centres(L::Integer)
    level = Mesh.hierarchy(L).levels[L + 1]
    g = Mesh.geometry(level, Mesh.stencils(level))
    return [unit(col(g.dual_vertex, j)) for j in axes(g.dual_vertex, 2)]
end

"`v` reflected in the plane through the origin normal to the unit vector `normal`, zeros made positive."
function reflect(v::NTuple{3,Float64}, normal::NTuple{3,Float64})
    d = Mesh.dot_fma(v, normal)
    return (fma(-2d, normal[1], v[1]) + 0.0, fma(-2d, normal[2], v[2]) + 0.0,
            fma(-2d, normal[3], v[3]) + 0.0)
end

"""
    mirror_defect(vertices, normal)

For every vertex of `vertices` (3 by n), the distance from its reflection in the
plane normal to `normal` to the nearest vertex, as a vector.
"""
function mirror_defect(vertices::AbstractMatrix, normal::NTuple{3,Float64})
    points = [col(vertices, j) for j in axes(vertices, 2)]
    return map(points) do p
        r = reflect(p, normal)
        minimum(sqrt((r[1] - q[1])^2 + (r[2] - q[2])^2 + (r[3] - q[3])^2) for q in points)
    end
end

@testset "Mesh.frame" begin
    @testset "one declaration: no other site in src/ names an axis by coordinate" begin
        found = axis_triples_under(SRC)
        @test length(found) == 2
        @test all(site -> site[1] == FRAME_FILE, found)
        lines = split(read(joinpath(SRC, FRAME_FILE), String), '\n')
        at = findfirst(l -> startswith(l, "const BODY_FRAME"), lines)
        @test at !== nothing
        @test Set(site[2] for site in found) == Set((at, at + 1))

        @testset "positive control: the scan flags an axis written by coordinate" begin
            @test length(axis_triples("x.jl",
                "const POLAR_AXIS = (zero(Float64), zero(Float64), one(Float64))")) == 1
            @test length(axis_triples("x.jl", "north = [0.0, 0.0, 1.0]")) == 1
            @test length(axis_triples("x.jl", "meridian = SVector(1, 0, 0)")) == 1
            @test length(axis_triples("x.jl", "down = (0, 0, -1)")) == 1
        end

        @testset "negative control: a zero vector, a golden-ratio corner and a longer tuple pass" begin
            @test isempty(axis_triples("x.jl", "origin = (zero(Float64), zero(Float64), zero(Float64))"))
            @test isempty(axis_triples("x.jl", "(-one(T), phi, zero(T)), (zero(T), -one(T), phi),"))
            @test isempty(axis_triples("x.jl", "LENGTH = Dim((0, 0, 1, 0, 0, 0, 0))"))
        end
    end

    @testset "the declared frame is exactly orthonormal and right-handed" begin
        orthonormal(f) = Mesh.dot_fma(f.spin_axis, f.spin_axis) == 1.0 &&
                         Mesh.dot_fma(f.prime_meridian, f.prime_meridian) == 1.0 &&
                         Mesh.dot_fma(f.spin_axis, f.prime_meridian) == 0.0
        @test orthonormal(BF)
        @test BF.ninety_east == Mesh.cross_fma(BF.spin_axis, BF.prime_meridian)
        @test Mesh.dot_fma(BF.ninety_east, BF.ninety_east) == 1.0
        @test Mesh.dot_fma(BF.prime_meridian, Mesh.cross_fma(BF.ninety_east, BF.spin_axis)) == 1.0

        @testset "positive control: a half-length meridian and a meridian along the spin axis are not orthonormal" begin
            half = (BF.prime_meridian[1] / 2, BF.prime_meridian[2] / 2, BF.prime_meridian[3] / 2)
            @test !orthonormal(Mesh.BodyFrame(spin_axis = BF.spin_axis, prime_meridian = half))
            @test !orthonormal(Mesh.BodyFrame(spin_axis = BF.spin_axis, prime_meridian = BF.spin_axis))
        end
    end

    @testset "latitude and longitude read the frame by name" begin
        s, m, e = BF.spin_axis, BF.prime_meridian, BF.ninety_east
        @test Mesh.latitude(BF, s...) == pi / 2
        @test Mesh.latitude(BF, (.-s)...) == -pi / 2
        @test Mesh.longitude(BF, m...) == 0.0
        @test Mesh.longitude(BF, e...) == pi / 2
        @test Mesh.longitude(BF, (.-m)...) == Float64(pi)
        err = try
            Mesh.longitude(BF, s...)
        catch ex
            ex
        end
        @test err isa Refusal
        @test occursin("spin axis", err.reason)

        # From a stored cell centre to the residual: the renormalisation in `unit`
        # (7 operations), the three components the two functions form (15), the
        # equatorial length (3), two atan (2), four cos and sin (4), two products
        # (2), in_frame (5) and the difference (1).
        bound = Reductions.error_bound(Float64, 39, 1.0)
        rebuild(p, lat, lon) =
            maximum(abs.(Mesh.in_frame(BF, cos(lat) * cos(lon), cos(lat) * sin(lon), sin(lat), Float64) .- p))
        centres = cell_centres(2)
        worst = maximum(rebuild(p, Mesh.latitude(BF, p...), Mesh.longitude(BF, p...)) for p in centres)
        @test worst <= bound

        @testset "positive control: longitude with its arguments swapped does not rebuild the point" begin
            swapped = maximum(rebuild(p, Mesh.latitude(BF, p...),
                                      atan(Mesh.dot_fma(m, p), Mesh.dot_fma(e, p))) for p in centres)
            @test swapped > bound
        end
    end

    @testset "east cross north is the local up at every cell centre of levels 1 and 3" begin
        # From a stored cell centre to the residual, one component passes through the
        # renormalisation in east_north_frame (7 operations), east (10), north (3),
        # the cross product below (3) and the difference (1).
        bound = Reductions.error_bound(Float64, 24, 1.0)
        for L in (1, 3)
            level = Mesh.hierarchy(L).levels[L + 1]
            g = Mesh.geometry(level, Mesh.stencils(level))
            east, north = Fields.east_north_frame(g.dual_vertex).axes
            worst = 0.0
            worst_reversed = Inf
            toward_pole = true
            for j in axes(g.dual_vertex, 2)
                p = unit(col(g.dual_vertex, j))
                ej, nj = col(east, j), col(north, j)
                worst = max(worst, maximum(abs.(Mesh.cross_fma(ej, nj) .- p)))
                reversed = Mesh.cross_fma(ej, p)
                worst_reversed = min(worst_reversed, maximum(abs.(Mesh.cross_fma(ej, reversed) .- p)))
                toward_pole &= Mesh.dot_fma(nj, BF.spin_axis) > 0.0
            end
            @test worst <= bound
            @test toward_pole

            @testset "positive control at level $L: north taken as east cross up gives down" begin
                @test worst_reversed > bound
            end
        end

        @testset "positive control: a frame with its spin axis flipped keeps east cross north up and turns north away from the pole" begin
            flipped = Mesh.BodyFrame(spin_axis = .-(BF.spin_axis), prime_meridian = BF.prime_meridian)
            bound = Reductions.error_bound(Float64, 24, 1.0)
            handed = true
            away = true
            for p in cell_centres(1)
                ej, nj = Fields.local_east_north(flipped, p...)
                handed &= maximum(abs.(Mesh.cross_fma(ej, nj) .- p)) <= bound
                away &= Mesh.dot_fma(nj, BF.spin_axis) < 0.0
            end
            @test handed
            @test away
        end
    end

    @testset "a retrograde rotator keeps the frame's handedness, and a flipped placement is caught" begin
        # An outer frame whose third axis is the orbit normal; the pole on the orbit
        # normal's side of the orbit plane is tilted from it by `obliquity`.
        obliquity = 0.4
        normal_side = (sin(obliquity), 0.0, cos(obliquity))
        meridian = (cos(obliquity), 0.0, -sin(obliquity))
        rate = 2pi / 3.0e4
        site = "test/mesh/frame.jl"

        prograde = (omega = rate .* normal_side, pole = normal_side)
        retrograde = (omega = -rate .* normal_side, pole = .-normal_side)

        # Whether every cell centre of levels 1 and 2, placed by `orientation`,
        # moves east under `omega`, and whether every one moves west.
        function motion(orientation, omega)
            east_all, west_all = true, true
            for L in (1, 2), p in cell_centres(L)
                ej, _ = Fields.local_east_north(BF, p...)
                velocity = Mesh.cross_fma(omega, apply(orientation, p))
                along = Mesh.dot_fma(apply(orientation, ej), velocity)
                east_all &= along > 0.0
                west_all &= along < 0.0
            end
            return (east = east_all, west = west_all)
        end

        for (name, spin) in ((:prograde, prograde), (:retrograde, retrograde))
            @testset "$(name)" begin
                orientation = placement(meridian, Mesh.cross_fma(spin.pole, meridian), spin.pole)
                @test Mesh.require_body_orientation(BF, orientation, spin.omega, site) === nothing
                @test motion(orientation, spin.omega).east
            end
        end

        @testset "positive control: the retrograde rotator placed with the pole on the orbit normal's side" begin
            flipped = placement(meridian, Mesh.cross_fma(normal_side, meridian), normal_side)
            err = try
                Mesh.require_body_orientation(BF, flipped, retrograde.omega, site)
            catch ex
                ex
            end
            @test err isa Refusal
            @test occursin("positive pole", err.reason)
            @test motion(flipped, retrograde.omega).west
        end

        @testset "positive control: the retrograde rotator placed left-handed" begin
            left = placement(meridian, .-Mesh.cross_fma(retrograde.pole, meridian), retrograde.pole)
            err = try
                Mesh.require_body_orientation(BF, left, retrograde.omega, site)
            catch ex
                ex
            end
            @test err isa Refusal
            @test occursin("not right-handed", err.reason)
            @test motion(left, retrograde.omega).west
        end

        @testset "a zero angular velocity has no positive pole" begin
            orientation = placement(meridian, Mesh.cross_fma(prograde.pole, meridian), prograde.pole)
            @test_throws Refusal Mesh.require_body_orientation(BF, orientation, 0.0 .* prograde.omega, site)
        end
    end

    @testset "the hierarchy is mirror-symmetric about the equator and the prime meridian's plane" begin
        L = 3
        level = Mesh.hierarchy(L).levels[L + 1]
        @test maximum(mirror_defect(level.vertices, BF.spin_axis)) == 0.0
        @test maximum(mirror_defect(level.vertices, BF.ninety_east)) == 0.0

        @testset "positive control: the mirror normal to a base vertex or a base face centre is not a symmetry" begin
            half_edge = minimum(Mesh.geometry(level, Mesh.stencils(level)).primal_edge_length) / 2
            base = Mesh.hierarchy(0).levels[1]
            vertex_axis = col(base.vertices, 1)
            face = base.cells[:, 1]
            face_axis = unit(col(base.vertices, face[1]) .+ col(base.vertices, face[2]) .+
                             col(base.vertices, face[3]))
            @test maximum(mirror_defect(level.vertices, vertex_axis)) > half_edge
            @test maximum(mirror_defect(level.vertices, face_axis)) > half_edge
        end
    end
end
