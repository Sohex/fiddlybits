using Test
using LinearAlgebra: cross, dot
using Fiddlybits: Fields, Dimensions
using Fiddlybits.Verdicts: Refusal

# mesh.vector_round_trip: docs/oracles/registry.toml and
# docs/plans/fiddlybits-52v.3-fields.md, row 52v.3.5.
#
# The shared fixture's one level supplies both the source and the destination
# frames, because a level crossing is not this row's boundary: coarsen and
# refine already refuse an east-north or edge-normal field by name, in
# test/fields/reduce.jl, and this file exercises what they point a caller at.

const V = Fields
const VX = FieldFixtures

"The rotation vector a solid-body test uses, tilted off the mesh's own polar
axis so no cell lands at a pole by symmetry."
const OMEGA = (sin(0.3), 0.0, cos(0.3))

"""
    solid_body(locations)

The Cartesian solid-body rotation vector `cross(OMEGA, p)` at every column `p`
of `locations`, as three vectors `(vx, vy, vz)`. Tangent to the sphere at
every point by construction, whatever `locations` holds.
"""
function solid_body(locations::AbstractMatrix)
    n = size(locations, 2)
    vx, vy, vz = Vector{Float64}(undef, n), Vector{Float64}(undef, n), Vector{Float64}(undef, n)
    for j in 1:n
        p = (locations[1, j], locations[2, j], locations[3, j])
        v = cross(collect(OMEGA), collect(p))
        vx[j], vy[j], vz[j] = v[1], v[2], v[3]
    end
    return vx, vy, vz
end

"A `VectorComponent{basis}` field over `data`, every other declaration the shared fixture's."
vecfield(basis::Symbol, data::AbstractVector) =
    V.Field(semantics = V.VectorComponent{basis}(), dimension = Dimensions.LENGTH / Dimensions.TIME,
            data = data, support = VX.SUPPORT, time = VX.interval_support(),
            origin = V.unstamped(:test, VX.RUN))

"`f`'s data, so a test reads a Field the same way it builds one."
d(f) = V.data(f)

const LOCATIONS = VX.GEOMETRY.dual_vertex
const EDGE_LOCATIONS = VX.GEOMETRY.edge_midpoint
const NORMAL = VX.GEOMETRY.edge_normal

@testset "Fields.vectors" begin
    @testset "local_east_north is orthonormal and refuses at the pole" begin
        for j in 1:20:size(LOCATIONS, 2)
            p = (LOCATIONS[1, j], LOCATIONS[2, j], LOCATIONS[3, j])
            n = sqrt(p[1]^2 + p[2]^2 + p[3]^2)
            x, y, z = p[1] / n, p[2] / n, p[3] / n
            (ex, ey, ez), (nx, ny, nz) = V.local_east_north(x, y, z)
            @test ex^2 + ey^2 + ez^2 ≈ 1.0 atol=1e-14
            @test nx^2 + ny^2 + nz^2 ≈ 1.0 atol=1e-14
            @test ex * x + ey * y + ez * z ≈ 0.0 atol=1e-14
            @test nx * x + ny * y + nz * z ≈ 0.0 atol=1e-14
            @test ex * nx + ey * ny + ez * nz ≈ 0.0 atol=1e-14
        end

        @testset "positive control: the pole itself has no east" begin
            err = try
                V.local_east_north(0.0, 0.0, 1.0)
            catch e
                e
            end
            @test err isa Refusal
            @test occursin("polar axis", err.reason)
        end
    end

    @testset "LocalFrame refuses a malformed axis" begin
        @test_throws Refusal V.LocalFrame{:east_north}((ones(2, 4), ones(3, 4)))
        @test_throws Refusal V.LocalFrame{:east_north}((ones(3, 4), ones(3, 5)))
    end

    @testset "mesh.vector_round_trip: east-north lifted at the source, projected at the destination" begin
        frame = V.east_north_frame(LOCATIONS)
        vx, vy, vz = solid_body(LOCATIONS)
        cartesian = (vecfield(:cartesian, vx), vecfield(:cartesian, vy), vecfield(:cartesian, vz))

        source = V.project(cartesian, frame)
        @test length(source) == 2

        lifted = V.lift(source, frame)
        @test all(isapprox.(d(lifted[1]), vx, atol = 1e-12))
        @test all(isapprox.(d(lifted[2]), vy, atol = 1e-12))
        @test all(isapprox.(d(lifted[3]), vz, atol = 1e-12))

        destination = V.project(lifted, frame)
        @test all(isapprox.(d(destination[1]), d(source[1]), atol = 1e-12))
        @test all(isapprox.(d(destination[2]), d(source[2]), atol = 1e-12))

        @testset "transform agrees with project on a field that fits exactly" begin
            strict = V.transform(lifted, frame)
            @test all(d(strict[1]) .== d(destination[1]))
            @test all(d(strict[2]) .== d(destination[2]))
        end

        @testset "positive control: coarsen refuses an east-north field directly" begin
            err = try
                V.coarsen(source[1], VX.SUPPORT)
            catch e
                e
            end
            @test err isa Refusal
            @test occursin("lift to :cartesian", err.reason)
        end

        @testset "positive control: transform refuses what project silently drops" begin
            radial = vecfield(:cartesian, vx .+ 0.1 .* LOCATIONS[1, :]),
                     vecfield(:cartesian, vy .+ 0.1 .* LOCATIONS[2, :]),
                     vecfield(:cartesian, vz .+ 0.1 .* LOCATIONS[3, :])

            dropped = V.project(radial, frame)
            @test all(isapprox.(d(dropped[1]), d(source[1]), atol = 1e-12))
            @test all(isapprox.(d(dropped[2]), d(source[2]), atol = 1e-12))

            err = try
                V.transform(radial, frame)
            catch e
                e
            end
            @test err isa Refusal
            @test occursin("call Fields.project", err.reason)
        end

        @testset "both are concrete under @inferred" begin
            @test (@inferred V.project(cartesian, frame)) isa NTuple{2,V.Field}
            @test (@inferred V.lift(source, frame)) isa NTuple{3,V.Field}
            @test (@inferred V.transform(lifted, frame)) isa NTuple{2,V.Field}
        end
    end

    @testset "edge-normal support" begin
        frame_n = V.edge_normal_frame(NORMAL)
        vx, vy, vz = solid_body(EDGE_LOCATIONS)
        cartesian = (vecfield(:cartesian, vx), vecfield(:cartesian, vy), vecfield(:cartesian, vz))

        normal_component = V.project(cartesian, frame_n)
        @test length(normal_component) == 1
        manual = [dot((vx[j], vy[j], vz[j]), (NORMAL[1, j], NORMAL[2, j], NORMAL[3, j])) for j in axes(NORMAL, 2)]
        @test all(isapprox.(d(normal_component[1]), manual, atol = 1e-12))

        pure_normal = V.lift(normal_component, frame_n)
        @testset "a field that lies purely along the normal transforms without loss" begin
            back = V.transform(pure_normal, frame_n)
            @test all(isapprox.(d(back[1]), d(normal_component[1]), atol = 1e-12))
        end

        @testset "positive control: the full velocity is not purely normal" begin
            err = try
                V.transform(cartesian, frame_n)
            catch e
                e
            end
            @test err isa Refusal
            dropped = V.project(cartesian, frame_n)
            @test all(isapprox.(d(dropped[1]), d(normal_component[1]), atol = 1e-12))
        end

        @testset "concrete under @inferred" begin
            @test (@inferred V.project(cartesian, frame_n)) isa NTuple{1,V.Field}
            @test (@inferred V.lift(normal_component, frame_n)) isa NTuple{3,V.Field}
            @test (@inferred V.transform(pure_normal, frame_n)) isa NTuple{1,V.Field}
        end
    end

    @testset "require_frame_extent refuses a mismatched frame" begin
        frame = V.east_north_frame(LOCATIONS)
        short = vecfield(:east_north, ones(2))
        other = vecfield(:east_north, ones(2))
        err = try
            V.lift((short, other), frame)
        catch e
            e
        end
        @test err isa Refusal
        @test occursin("frame holds", err.reason)
    end

    @testset "require_vector_agreement refuses components that disagree" begin
        frame = V.east_north_frame(LOCATIONS)
        e = vecfield(:east_north, zeros(VX.NCELLS))
        n_other_dimension = V.Field(semantics = V.VectorComponent{:east_north}(),
                                    dimension = Dimensions.MASS, data = zeros(VX.NCELLS),
                                    support = VX.SUPPORT, time = VX.interval_support(),
                                    origin = V.unstamped(:test, VX.RUN))
        err = try
            V.lift((e, n_other_dimension), frame)
        catch ex
            ex
        end
        @test err isa Refusal
    end
end
