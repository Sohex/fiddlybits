using Test
using Fiddlybits: Systems, Dispositions, Dimensions, Reductions
import .SystemFixtures as SF

# system.gravity_and_figure (docs/oracles/registry.toml): g(r, phi) reduces to the
# point-mass form at zero rotation, and its equator-pole difference equals the
# centrifugal closed form, both to roundoff; the Derived hydrostatic flattening at the
# uniform-density moment-of-inertia factor equals the closed form 5 q / 4, to roundoff.

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
                period = SF.wide(T(2e4), time)))).planet)
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
                period = SF.irreducible(T(Inf), time)))).planet
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

    # The figure arm. Murray and Dermott (2000), Solar System Dynamics,
    # 10.1017/CBO9781139174817: Eqs. (4.112) and (4.114), p. 153; Eq. (4.110), p. 152,
    # with J2 = q / 2 for uniform density, p. 151.
    one_ = Dimensions.DIMENSIONLESS
    figure(T, c) = Systems.HydrostaticFigure(moment_of_inertia_factor = SF.irreducible(T(c), one_))
    factors(T) = range(T(2) / 15, T(2) / 5; length = 9)
    condensed(T) = T(33) / 100
    stills() = [SF.system(T; planet = SF.planet(T; rotation = Systems.SiderealRotation(
                    period = SF.irreducible(T(Inf), time)))).planet for T in (Float64, Float32)]

    # `q = omega^2 r^3 / (G m)` of `p` at 256 bits, from the fixtures' closed forms.
    rotation_parameter_256(p, r) = setprecision(BigFloat, 256) do
        SF.centrifugal_256(p, r) / SF.polar_gravity_256(p, r)
    end

    @testset "darwin_radau_flattening satisfies Eqs. (4.112) and (4.114) at 256 bits" begin
        setprecision(BigFloat, 256) do
            tolerance = 64 * eps(BigFloat)
            for c in range(big(2) / 15, big(2) / 5; length = 17),
                    q in (big(1) / 10^8, big(1) / 300, big(1) / 10)
                f = Systems.darwin_radau_flattening(BigFloat, c, q)
                @test abs(2 * (1 - 2 * sqrt(5 * q / (2 * f) - 1) / 5) / 3 - c) <= tolerance
                j2 = 2 * (f - q / 2) / 3
                @test abs(j2 / f - (-big(3) / 10 + 5 * c / 2 - 15 * c^2 / 8)) <= tolerance
            end
        end
    end

    # The flattening `resolve` gives for `figure(T, c)` on `p` less the 256-bit
    # evaluation of the rule at the declared factor and `rotation_parameter_256`, its
    # bound, and that 256-bit evaluation.
    function flattening_miss(resolve, p, c)
        T = typeof(value(p.mass))
        r = value(p.volumetric_mean_radius)
        f = value(resolve(figure(T, c), p).flattening)
        q = rotation_parameter_256(p, r)
        expected = setprecision(BigFloat, 256) do
            Systems.darwin_radau_flattening(BigFloat, big(c), q)
        end
        return abs(big(f) - expected), Systems.flattening_rounding(T, f), expected
    end

    @testset "every flattening lies within flattening_rounding of the 256-bit evaluation" begin
        for p in (planets()..., stills()...)
            T = typeof(value(p.mass))
            for c in factors(T)
                miss, bound, _ = flattening_miss(Systems.hydrostatic_flattening, p, c)
                @test miss <= bound
            end
        end
    end

    @testset "the uniform-density interior reproduces the closed form f = 5 q / 4" begin
        for p in (planets()..., stills()...)
            T = typeof(value(p.mass))
            r = value(p.volumetric_mean_radius)
            c = T(2) / 5
            f = value(Systems.hydrostatic_flattening(figure(T, c), p).flattening)
            q = rotation_parameter_256(p, r)
            closed, representable = setprecision(BigFloat, 256) do
                5 * q / 4, abs(Systems.darwin_radau_flattening(BigFloat, big(c), q) -
                               Systems.darwin_radau_flattening(BigFloat, big(2) / 5, q))
            end
            @test abs(big(f) - closed) <= Systems.flattening_rounding(T, f) + representable
        end
    end

    # The arm resolves the flattening on every instance with a finite rotation period,
    # the six of `planets()`.
    @testset "positive control: the uniform-density factor substituted for a condensed one fails the arm" begin
        homogeneous(fig, p) = Systems.hydrostatic_flattening(
            figure(typeof(value(p.mass)), typeof(value(p.mass))(2) / 5), p)
        resolved = 0
        for p in planets()
            c = condensed(typeof(value(p.mass)))
            _, bound, expected = flattening_miss(Systems.hydrostatic_flattening, p, c)
            expected > bound || continue
            resolved += 1
            miss, _, _ = flattening_miss(homogeneous, p, c)
            @test miss > bound
        end
        @test resolved == 6
    end

    @testset "the flattening is Derived from the planet's mass, radius, rotation and figure" begin
        for p in planets()
            T = typeof(value(p.mass))
            h = Systems.hydrostatic_flattening(figure(T, condensed(T)), p)
            @test h isa Systems.HydrostaticFlattening{T}
            @test h.flattening isa Dispositions.Derived
            @test h.flattening.rule === :darwin_radau_flattening
            @test h.flattening.from == (:mass, :volumetric_mean_radius, :rotation, :figure)
            @test value(h.moment_of_inertia_factor) === condensed(T)
        end
    end

    @testset "the figure refuses a factor outside [2/15, 2/5] and a rotation parameter of one or above" begin
        for c in (0.0, 0.13, 0.41, 2 / 3)
            @test SF.refused(SF.caught(() -> figure(Float64, c)), "moment_of_inertia_factor", "outside")
        end
        e = SF.caught(() -> Systems.HydrostaticFigure(
            moment_of_inertia_factor = SF.bracket(0.33, 0.3, 0.45, one_)))
        @test SF.refused(e, "moment_of_inertia_factor", "0.45")
        for T in (Float64, Float32)
            @test figure(T, T(2) / 15) isa Systems.HydrostaticFigure{T}
            @test figure(T, T(2) / 5) isa Systems.HydrostaticFigure{T}
        end
        spinning(period) = SF.planet(rotation = Systems.SiderealRotation(
            period = SF.irreducible(period, time)))
        @test SF.refused(SF.caught(() -> Systems.hydrostatic_flattening(
            figure(Float64, 0.33), spinning(5000.0))), "rotation", "not below one")
        @test Systems.hydrostatic_flattening(figure(Float64, 0.33), spinning(5100.0)) isa
              Systems.HydrostaticFlattening{Float64}
        @test SF.refused(SF.caught(() -> Systems.hydrostatic_flattening(
            figure(Float64, 0.33), SF.planet(rotation = Systems.SynchronousRotation()))),
            "rotation", "resolved")
        @test SF.refused(SF.caught(() -> Systems.hydrostatic_flattening(
            figure(Float32, 0.33), SF.planet())), "planet", "Planet{Float32}")
    end

    @testset "gravity refuses a planet whose synchronous rotation is not resolved" begin
        p = SF.planet(rotation = Systems.SynchronousRotation())
        @test SF.refused(SF.caught(() -> Systems.gravity(p, 7e6, 0.0)), "gravity", "resolved")
    end
end
