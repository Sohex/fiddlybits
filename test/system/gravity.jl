using Test
using Fiddlybits: Systems, Dispositions, Dimensions, Reductions
import .SystemFixtures as SF

# system.gravity_and_figure (docs/oracles/registry.toml): g(r, phi) reduces to the
# point-mass form at zero rotation, and its equator-pole difference equals the
# centrifugal closed form, both to roundoff. The figure arm is fiddlybits-52v.4.11.

@testset "system.gravity_and_figure" begin
    value = Dispositions.value
    time = Dimensions.TIME

    # The planets the arms run on: each fixture instance, at both precisions.
    function planets()
        out = Any[]
        for T in (Float64, Float32)
            push!(out, SF.system(T).planet)
            push!(out, SF.synchronous_system(T).planet)
            push!(out, SF.system(T; planet = SF.planet(T; rotation = Systems.SiderealRotation(
                period = SF.wide(T(2e4), time), sense = :retrograde))).planet)
        end
        return out
    end

    @testset "every evaluation lies within gravity_rounding of the 256-bit evaluation" begin
        for p in planets()
            T = typeof(value(p.mass))
            r = value(p.volumetric_mean_radius)
            for phi in range(-T(pi) / 2, T(pi) / 2; length = 181)
                g = Systems.gravity(p, r, T(phi))
                @test abs(big(g) - SF.gravity_256(p, r, T(phi))) <= Systems.gravity_rounding(p, r, T(phi))
            end
        end
    end

    @testset "g reduces to the point-mass form at zero rotation" begin
        for T in (Float64, Float32)
            still = SF.system(T; planet = SF.planet(T; rotation = Systems.SiderealRotation(
                period = SF.irreducible(T(Inf), time), sense = :prograde))).planet
            r = value(still.volumetric_mean_radius)
            point_mass = setprecision(BigFloat, 256) do
                value(Systems.gravitational_constant(BigFloat)) * big(value(still.mass)) / big(r)^2
            end
            for phi in range(-T(pi) / 2, T(pi) / 2; length = 37)
                @test abs(big(Systems.gravity(still, r, T(phi))) - point_mass) <=
                      Systems.gravity_rounding(still, r, T(phi))
            end
        end
    end

    # The equator-pole difference of `g` less the centrifugal closed form, and its bound.
    function difference_and_bound(g, p)
        T = typeof(value(p.mass))
        r = value(p.volumetric_mean_radius)
        pole = T(pi) / 2
        difference = g(p, r, pole) - g(p, r, zero(T))
        closed = SF.centrifugal_256(p, r)
        representable = abs(SF.gravity_256(p, r, pole) - SF.polar_gravity_256(p, r))
        bound = Systems.gravity_rounding(p, r, pole) + Systems.gravity_rounding(p, r, zero(T)) +
                Reductions.error_bound(T, 1, abs(difference)) + representable
        return abs(big(difference) - closed), bound, closed
    end

    @testset "the equator-pole difference equals the centrifugal closed form" begin
        for p in planets()
            miss, bound, _ = difference_and_bound(Systems.gravity, p)
            @test miss <= bound
        end
    end

    # The arm resolves the centrifugal term only where the closed form exceeds the
    # arm's own bound; the synchronous Float32 instance's does not, and the control is
    # asserted on the instances where it does, which must be the other five.
    @testset "positive control: gravity with the centrifugal term dropped fails the arm" begin
        point_mass(p, r, phi) = Systems.gravitational_parameter(typeof(r), value(p.mass)) / (r * r)
        resolved = 0
        for p in planets()
            _, bound, closed = difference_and_bound(Systems.gravity, p)
            closed > bound || continue
            resolved += 1
            miss, _, _ = difference_and_bound(point_mass, p)
            @test miss > bound
        end
        @test resolved == 5
    end

    @testset "the figure arm: the hydrostatic figure is not carried" begin
        e = SF.caught(() -> Systems.HydrostaticFigure(
            moment_of_inertia_factor = SF.bracket(0.33, 0.3, 0.4, Dimensions.DIMENSIONLESS)))
        @test SF.refused(e, "figure", "fiddlybits-52v.4.11")
    end

    @testset "gravity refuses a planet whose synchronous rotation is not resolved" begin
        p = SF.planet(rotation = Systems.SynchronousRotation())
        @test SF.refused(SF.caught(() -> Systems.gravity(p, 7e6, 0.0)), "gravity", "resolved")
    end
end
