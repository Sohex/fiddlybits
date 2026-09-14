using Test
using Fiddlybits: Systems, Dispositions, Dimensions, Backends
import .SystemFixtures as SF

# Profile: docs/plans/fiddlybits-52v.4-system.md, section "Scope"; decisions 0005, 0011,
# 0014 and 0023. Each testset is one clause of the row's acceptance, named as it names
# it.

module ProfileFixtures

using Fiddlybits: Systems, Dispositions, Dimensions
import ..SystemFixtures as SF

const S = Systems
const TIME = Dimensions.TIME
const LENGTH = Dimensions.LENGTH
const ONE = Dimensions.DIMENSIONLESS

"A `Derived` duration of `value` by `rule`, as the module that derives it would build it."
derived(value, rule) = Dispositions.Derived(value = value, dim = TIME,
                                            from = (:stars, :planet, :orbits), rule = rule,
                                            fields = S.SYSTEM_FIELDS)

"Radiation cycles defining no term of their own; `kw` replaces any keyword."
cycles(T = Float64; kw...) = S.RadiationCycles(; merge(
    (diurnal_cycle = S.Undefined(argument = "the fixture declares no mean solar day"),
     eclipse_durations = S.Undefined(argument = "no body of the fixture eclipses a source"),
     cloud_timescale = SF.irreducible(T(2e3), TIME)), values(kw))...)

"A radiation declaration at a quarter of its ceiling's shortest term; `kw` replaces any keyword."
radiation(T = Float64; kw...) = S.RadiationDeclaration(; merge(
    (g_points = (SF.irreducible(16, ONE), SF.irreducible(8, ONE)),
     interval = SF.irreducible(T(600), TIME),
     ceiling_fraction = SF.irreducible(T(0.25), ONE),
     cycles = cycles(T)), values(kw))...)

"A ladder of three levels on a named depth scale."
ladder(T = Float64) = S.VerticalLadder(
    depth_scale = :scale_height,
    interfaces = Tuple(SF.irreducible(T(v), ONE) for v in (0, 0.1, 0.5, 2)))

"A component declaration; `kw` replaces any keyword."
component(T = Float64; kw...) = S.ComponentDeclaration(; merge(
    (name = :atmosphere, target_spacing = SF.irreducible(T(1e5), LENGTH),
     finest_spacing = SF.irreducible(T(2.5e4), LENGTH), ladder = ladder(T)), values(kw))...)

"An exit bracket in `normalisation`; `kw` replaces any keyword."
exit_bracket(T = Float64; kw...) = S.ExitBracket(; merge(
    (loop = :climate, criterion = :toa_balance, normalisation = :absorbed_instellation,
     tolerance = SF.irreducible(T(1e-3), ONE)), values(kw))...)

"The keywords of a profile with every setting present, over `T`; `kw` replaces any."
keywords(T = Float64; kw...) = merge(
    (label = :fixture, system = SF.system(T), components = (component(T),),
     radiation = radiation(T), fast_precision = T,
     slow_tier = S.SlowTier(acceleration = SF.bracket(T(10), T(1), T(100), ONE),
                            refresh_interval = SF.irreducible(T(3e9), TIME)),
     memory_ceiling = SF.irreducible(1024, ONE),
     write_ceiling = SF.irreducible(256, ONE),
     store_writers = SF.irreducible(4, ONE),
     daily_fallback_interval = SF.bracket(T(1e5), T(600), T(1e6), TIME),
     exit_brackets = (exit_bracket(T),)), values(kw))

"A profile with every setting present, over `T`; `kw` replaces any keyword."
profile(T = Float64; kw...) = S.Profile(; keywords(T; kw...)...)

"""
    orbit_system(T; semi_major_axis, eccentricity, obliquity, rotation)

A one-star system whose planet's orbit and obliquity are the given values and whose
rotation is `rotation`, or the fixture's where `rotation` is `nothing`.
"""
function orbit_system(T = Float64; semi_major_axis, eccentricity, obliquity, rotation = nothing)
    planet = rotation === nothing ?
        SF.planet(T; obliquity = SF.irreducible(T(obliquity), ONE)) :
        SF.planet(T; obliquity = SF.irreducible(T(obliquity), ONE), rotation = rotation)
    orbit = SF.planet_orbit(T; semi_major_axis = SF.irreducible(T(semi_major_axis), LENGTH),
                            eccentricity = SF.irreducible(T(eccentricity), ONE))
    return SF.system(T; planet = planet,
                     orbits = S.OrbitHierarchy(planet = orbit, moons = (SF.moon_orbit(T),),
                                               companions = ()))
end

"A system whose planet's volumetric mean radius is `radius`."
radius_system(T, radius) = SF.system(T; planet = SF.planet(T;
    bulk = S.DeclaredBulk(volumetric_mean_radius = SF.irreducible(T(radius), LENGTH))))

"`level_spacing` at 256 bits from the radius's stored value."
spacing_256(radius, level) = setprecision(BigFloat, 256) do
    r = BigFloat(radius; precision = 256)
    sqrt(4 * BigFloat(pi) * r^2 / (20 * BigFloat(4)^level))
end

end # module ProfileFixtures

import .ProfileFixtures as PF

@testset "system profile" begin
    value = Dispositions.value
    TIME, LENGTH, ONE = PF.TIME, PF.LENGTH, PF.ONE

    @testset "every fixture profile constructs and strips to isbits" begin
        for T in (Float64, Float32)
            p = PF.profile(T)
            @test p isa Systems.Profile{T}
            @test isbits(Systems.strip(p))
            @test Systems.strip(p) === Systems.strip(p)
            st = Systems.strip(p)
            @test st isa Systems.StrippedProfile{T,:fixture,T}
            @test st.memory_ceiling === 1024
            @test st.write_ceiling === 256
            @test st.store_writers === 4
            @test st.components.atmosphere isa Systems.StrippedComponent{:atmosphere}
            @test st.components.atmosphere.level === value(p.components.atmosphere.level)
            @test st.components.atmosphere.ladder === map(value, p.components.atmosphere.ladder.interfaces)
            @test st.radiation.ceiling === value(p.radiation.ceiling)
            @test st.radiation.g_points === (16, 8)
            @test st.exit_brackets[1] isa
                  Systems.StrippedExit{:climate,:toa_balance,:absorbed_instellation,T}
            @test st.daily_fallback_interval === value(p.daily_fallback_interval)
        end
    end

    @testset "the Derived radiation ceiling refuses above it, naming the term that bound it" begin
        with_interval(s, c, interval) = PF.profile(system = s, radiation = PF.radiation(
            interval = interval, cycles = c),
            daily_fallback_interval = Systems.Absent(argument = "a radiation fixture"))
        # The declared fraction of every radiation fixture.
        fraction = 0.25

        # The profile at its ceiling constructs, bound by `term`; one ulp above refuses
        # naming it, and so does a bracket whose high end lies one ulp above.
        function binds(s, c, term, shortest)
            ceiling = fraction * shortest
            p = with_interval(s, c, SF.irreducible(ceiling, TIME))
            @test p.radiation.bound_by === term
            @test value(p.radiation.ceiling) === ceiling
            @test p.radiation.ceiling isa Dispositions.Derived
            @test p.radiation.ceiling.rule === :radiation_ceiling
            @test SF.refused(SF.caught(() -> with_interval(s, c,
                                            SF.irreducible(nextfloat(ceiling), TIME))),
                             "interval", "the $(term) $(shortest), which bound it")
            @test SF.refused(SF.caught(() -> with_interval(s, c,
                                            SF.bracket(ceiling / 2, ceiling / 4,
                                                       nextfloat(ceiling), TIME))),
                             "interval", String(term))
            return p
        end

        s = SF.system()
        period = Systems.orbital_period(s, s.orbits.planet)

        @testset "a long mean solar day" begin
            day = 2e6
            @test day < period
            binds(s, PF.cycles(diurnal_cycle = PF.derived(day, :mean_solar_day)),
                  :mean_solar_day, day)
        end

        @testset "a short eclipse" begin
            c = PF.cycles(diurnal_cycle = PF.derived(1e5, :mean_solar_day),
                          eclipse_durations = (PF.derived(7e3, :eclipse_duration),
                                               PF.derived(3e3, :eclipse_duration)))
            binds(s, c, :eclipse_duration, 3e3)
        end

        @testset "a short orbital period" begin
            short = PF.orbit_system(semi_major_axis = 1e9, eccentricity = 0.1, obliquity = 0.4)
            p_short = Systems.orbital_period(short, short.orbits.planet)
            c = PF.cycles(diurnal_cycle = PF.derived(1e5, :mean_solar_day))
            @test p_short < 1e5
            binds(short, c, :orbital_period, p_short)

            # The same orbit circular and at zero obliquity modulates nothing, so the
            # mean solar day binds and an interval above a quarter of the orbit constructs.
            flat = PF.orbit_system(semi_major_axis = 1e9, eccentricity = 0.0, obliquity = 0.0)
            @test !Systems.orbit_modulates(flat)
            binds(flat, c, :mean_solar_day, 1e5)
        end

        @testset "none defined, so the cloud timescale binds" begin
            synchronous = Systems.SynchronousRotation()
            still = PF.orbit_system(semi_major_axis = 1.8e11, eccentricity = 0.0,
                                    obliquity = 0.0, rotation = synchronous)
            @test Systems.ceiling_terms(still, PF.cycles()) == Tuple{Symbol,Float64}[]
            binds(still, PF.cycles(), :cloud_timescale, 2e3)

            # A Bracketed cloud timescale bounds the ceiling at its low end.
            bracketed = PF.cycles(cloud_timescale = SF.bracket(2e3, 1.2e3, 4e3, TIME))
            binds(still, bracketed, :cloud_timescale, 1.2e3)

            # Either arm of the modulation defines the orbital period: an eccentric orbit,
            # and a circular orbit at non-zero obliquity.
            for (e, obliquity) in ((0.1, 0.0), (0.0, 0.4))
                moving = PF.orbit_system(semi_major_axis = 1.8e11, eccentricity = e,
                                         obliquity = obliquity, rotation = synchronous)
                @test Systems.orbit_modulates(moving)
                binds(moving, PF.cycles(), :orbital_period,
                      Systems.orbital_period(moving, moving.orbits.planet))
            end
        end

        @testset "a Bracketed ceiling fraction bounds the ceiling at its low end" begin
            p = PF.profile(radiation = PF.radiation(
                ceiling_fraction = SF.bracket(0.25, 0.125, 0.5, ONE),
                cycles = PF.cycles(diurnal_cycle = PF.derived(1e5, :mean_solar_day))))
            @test value(p.radiation.ceiling) === 0.125 * 1e5
        end
    end

    @testset "a bounding term is Derived by its own rule" begin
        @test SF.refused(SF.caught(() -> PF.cycles(diurnal_cycle = SF.irreducible(1e5, TIME))),
                         "diurnal_cycle", "not admitted")
        @test SF.refused(SF.caught(() -> PF.cycles(diurnal_cycle = PF.derived(1e5, :orbital_period))),
                         "diurnal_cycle", "the rule mean_solar_day is required")
        @test SF.refused(SF.caught(() -> PF.cycles(diurnal_cycle = PF.derived(-1e5, :mean_solar_day))),
                         "diurnal_cycle", "outside")
        @test SF.refused(SF.caught(() -> PF.cycles(eclipse_durations = ())),
                         "eclipse_durations", "one or more")
        @test SF.refused(SF.caught(() -> PF.cycles(eclipse_durations = PF.derived(3e3, :eclipse_duration))),
                         "eclipse_durations", "one or more")
        @test SF.refused(SF.caught(() -> PF.cycles(eclipse_durations = (PF.derived(3e3, :mean_solar_day),))),
                         "eclipse_durations", "the rule eclipse_duration is required")
        @test SF.refused(SF.caught(() -> PF.cycles(cloud_timescale = SF.irreducible(2e3, LENGTH))),
                         "cloud_timescale", "dimension")
        @test SF.refused(SF.caught(() -> Systems.Undefined(argument = "")), "argument", "no argument")
        @test SF.refused(SF.caught(() -> PF.profile(radiation = PF.radiation(Float32))),
                         "radiation", "required")
    end

    @testset "the level chosen for a component reproduces its target spacing from the declared radius" begin
        systems = (SF.system(), SF.system(Float32), PF.radius_system(Float64, 2.5e6),
                   PF.radius_system(Float64, 6.1e7), PF.radius_system(Float32, 3.3e6))
        for s in systems
            T = Systems.system_precision(s)
            radius = value(s.planet.volumetric_mean_radius)
            exact = Systems.level_spacing(radius, 4)
            for target in (T(5e3), T(1e5), T(3.3e5), T(2e7), T(exact), prevfloat(T(exact)),
                           nextfloat(T(exact)))
                p = PF.profile(T; system = s, components = (PF.component(T;
                    target_spacing = SF.irreducible(target, LENGTH),
                    finest_spacing = SF.irreducible(target / 8, LENGTH)),))
                c = p.components.atmosphere
                @test c.level isa Dispositions.Derived{Int}
                @test c.level.rule === :level_for_spacing
                @test value(c.finest_level) >= value(c.level)
                for (level, spacing) in ((value(c.level), target),
                                         (value(c.finest_level), target / 8))
                    at = PF.spacing_256(radius, level)
                    bound = Systems.rounding_bound(Float64, Systems.LEVEL_SPACING_TERMS,
                                                   Float64(at))
                    @test at - bound <= Float64(spacing)
                    level == 0 ||
                        @test PF.spacing_256(radius, level - 1) + bound > Float64(spacing)
                end
                @test c.deformation_radius_ratio isa Systems.Absent
                @test occursin("REQ-ATM-017", c.deformation_radius_ratio.argument)
            end
        end

        @test value(PF.profile(components = (PF.component(target_spacing =
                  SF.irreducible(1e9, LENGTH)),)).components.atmosphere.level) == 0

        finest = Systems.FINEST_INDEXABLE_LEVEL
        @test 30 * big(4)^finest <= typemax(Int) < 30 * big(4)^(finest + 1)
        radius = value(SF.system().planet.volumetric_mean_radius)
        at_finest = Systems.level_spacing(radius, finest)
        deepest = PF.profile(components = (PF.component(
            target_spacing = SF.irreducible(at_finest, LENGTH),
            finest_spacing = SF.irreducible(at_finest, LENGTH)),))
        @test value(deepest.components.atmosphere.level) == finest
        @test SF.refused(SF.caught(() -> PF.profile(components = (PF.component(
                  target_spacing = SF.irreducible(prevfloat(at_finest), LENGTH),
                  finest_spacing = SF.irreducible(prevfloat(at_finest), LENGTH)),))),
              "target_spacing", "finer than $(finest)")
    end

    @testset "a component's declaration" begin
        @test SF.refused(SF.caught(() -> PF.component(finest_spacing = SF.irreducible(2e5, LENGTH))),
                         "finest_spacing", "longer than the target")
        @test SF.refused(SF.caught(() -> PF.component(target_spacing = SF.irreducible(1e5, TIME))),
                         "target_spacing", "dimension")
        @test SF.refused(SF.caught(() -> PF.component(target_spacing = SF.irreducible(0.0, LENGTH))),
                         "target_spacing", "outside")
        @test SF.refused(SF.caught(() -> PF.profile(components = (PF.component(), PF.component()))),
                         "components", "twice")
        @test SF.refused(SF.caught(() -> PF.profile(components = PF.component())),
                         "components", "one or more")
        @test SF.refused(SF.caught(() -> PF.profile(components = (PF.component(Float32),))),
                         "components", "required")
        @test SF.refused(SF.caught(() -> Systems.VerticalLadder(depth_scale = :scale_height,
                                                               interfaces = SF.irreducible(0.5, ONE))),
                         "interfaces", "REQ-SYS-103 item 5")
        @test SF.refused(SF.caught(() -> Systems.VerticalLadder(depth_scale = :scale_height,
                                                               interfaces = (SF.irreducible(0.5, ONE),))),
                         "interfaces", "two or more")
        @test SF.refused(SF.caught(() -> Systems.VerticalLadder(depth_scale = :scale_height,
                  interfaces = (SF.irreducible(0.0, ONE), SF.irreducible(0.5, ONE),
                                SF.irreducible(0.5, ONE)))),
                         "interfaces", "does not lie above")
        @test SF.refused(SF.caught(() -> Systems.VerticalLadder(depth_scale = :scale_height,
                  interfaces = (SF.irreducible(-0.1, ONE), SF.irreducible(0.5, ONE)))),
                         "interfaces", "outside")
        absent = PF.profile(components = (PF.component(ladder =
            Systems.Absent(argument = "a single-layer fixture")),))
        @test Systems.strip(absent).components.atmosphere.ladder === nothing
    end

    @testset "components are held by name, in sorted name order" begin
        ocean = PF.component(name = :ocean, target_spacing = SF.irreducible(2e5, LENGTH))
        atmosphere = PF.component()
        forward = PF.profile(components = (atmosphere, ocean))
        backward = PF.profile(components = (ocean, atmosphere))
        @test forward.components isa NamedTuple{(:atmosphere, :ocean)}
        @test backward.components isa NamedTuple{(:atmosphere, :ocean)}
        @test value(backward.components.ocean.target_spacing) == 2e5
        @test value(backward.components.atmosphere.target_spacing) == 1e5
        st = Systems.strip(backward)
        @test isbits(st)
        @test st.components isa NamedTuple{(:atmosphere, :ocean)}
        @test st.components.ocean isa Systems.StrippedComponent{:ocean}
        @test Systems.strip(forward) === st
        @test Systems.holds_declaration(forward.components)
        @test Systems.reaches(forward, (:components, :ocean, :ladder))

        @testset "positive control: a name the profile does not hold, and a position, reach nothing" begin
            @test !Systems.reaches(forward, (:components, :land))
            @test !Systems.reaches(forward, (:components, 1))
            @test !Systems.reaches(forward, (:components, :, :ladder))
            @test !Systems.holds_declaration((a = 1.0, b = :x))
        end
    end

    @testset "every exit bracket is stored dimensionless and an absolute tolerance is refused" begin
        @test fieldtype(Systems.ExitBracket{Float64}, :tolerance) ===
              Dispositions.Disposition{Float64,typeof(ONE)}
        for n in Systems.EXIT_NORMALISATIONS
            e = PF.exit_bracket(normalisation = n)
            @test Dispositions.dimension(e.tolerance) === ONE
        end
        for dim in (Systems.IRRADIANCE, Dimensions.TEMPERATURE, Systems.PRESSURE)
            @test SF.refused(SF.caught(() -> PF.exit_bracket(tolerance = SF.irreducible(0.5, dim))),
                             "tolerance", "an absolute tolerance")
        end
        @test SF.refused(SF.caught(() -> PF.exit_bracket(tolerance = 1e-3)),
                         "tolerance", "disposition")
        @test SF.refused(SF.caught(() -> PF.exit_bracket(tolerance = SF.irreducible(0.0, ONE))),
                         "tolerance", "outside")
        @test SF.refused(SF.caught(() -> PF.exit_bracket(normalisation = :watts_per_square_metre)),
                         "normalisation", "not one of")
        @test SF.refused(SF.caught(() -> PF.profile(exit_brackets = (PF.exit_bracket(),
                                                                      PF.exit_bracket()))),
                         "exit_brackets", "twice")
        two = PF.profile(exit_brackets = (PF.exit_bracket(),
                                           PF.exit_bracket(criterion = :deep_ocean_drift,
                                                           normalisation = :stock_per_relaxation_time)))
        @test length(two.exit_brackets) == 2
    end

    @testset "the memory ceiling reads the Backends budget" begin
        p = PF.profile()
        at = [("h", Float64, 64), ("u", Float64, 64)]
        over = [("h", Float64, 64), ("u", Float64, 64), ("q", UInt8, 1)]
        @test Backends.budget(at) == value(p.memory_ceiling)
        @test Systems.refuse_over_ceiling(p, at) === nothing
        @test SF.refused(SF.caught(() -> Systems.refuse_over_ceiling(p, over)),
                         "memory budget", "exceeds ceiling 1024")
        @test SF.refused(SF.caught(() -> PF.profile(memory_ceiling = SF.irreducible(1024.0, ONE))),
                         "memory_ceiling", "is not a Int64")
        @test SF.refused(SF.caught(() -> PF.profile(memory_ceiling = SF.irreducible(0, ONE))),
                         "memory_ceiling", "outside")
    end

    @testset "write_ceiling and store_writers are declared Ints above zero (decision 0038)" begin
        p = PF.profile()
        @test value(p.write_ceiling) === 256
        @test value(p.store_writers) === 4
        closure(v) = Dispositions.Closure(law = :law,
            coefficient = Dispositions.Bracketed(value = v, dim = ONE, low = 1, high = 2 * v,
                                                 pushes_down = "a smaller ceiling",
                                                 pushes_up = "a larger ceiling", sweep = :sweep),
            levels = (3, 4))
        for key in (:write_ceiling, :store_writers)
            given(v) = PF.profile(; NamedTuple{(key,)}((v,))...)
            @test SF.refused(SF.caught(() -> given(SF.irreducible(1024.0, ONE))),
                             String(key), "is not a Int64")
            @test SF.refused(SF.caught(() -> given(SF.irreducible(0, ONE))),
                             String(key), "outside")
            @test SF.refused(SF.caught(() -> given(SF.irreducible(-1, ONE))),
                             String(key), "outside")
            @test SF.refused(SF.caught(() -> given(closure(1024))),
                             String(key), "Closure")
        end

        @testset "positive control: the same closure disposition constructs where a Closure is admitted" begin
            @test closure(1024) isa Dispositions.Closure
        end
    end

    @testset "the slow tier and the daily-tier fallback" begin
        @test SF.refused(SF.caught(() -> Systems.SlowTier(acceleration = SF.irreducible(10.0, ONE),
                                                         refresh_interval = SF.irreducible(3e9, TIME))),
                         "acceleration", "not admitted")
        @test SF.refused(SF.caught(() -> Systems.SlowTier(acceleration = SF.bracket(10.0, 0.5, 100.0, ONE),
                                                         refresh_interval = SF.irreducible(3e9, TIME))),
                         "acceleration", "outside")
        s = SF.system()
        period = Systems.orbital_period(s, s.orbits.planet)
        @test PF.profile(daily_fallback_interval = SF.bracket(1e5, 600.0, period, TIME)) isa
              Systems.Profile
        @test SF.refused(SF.caught(() -> PF.profile(daily_fallback_interval =
                                                        SF.bracket(1e5, 600.0, nextfloat(period), TIME))),
                         "daily_fallback_interval", "exceeds the orbital period")
        @test SF.refused(SF.caught(() -> PF.profile(daily_fallback_interval = SF.irreducible(1e5, TIME))),
                         "daily_fallback_interval", "not admitted")
    end

    @testset "the radiation declaration" begin
        @test SF.refused(SF.caught(() -> PF.radiation(g_points = SF.irreducible(16, ONE))),
                         "g_points", "REQ-SYS-103 item 5")
        @test SF.refused(SF.caught(() -> PF.radiation(g_points = (SF.irreducible(0, ONE),))),
                         "g_points", "outside")
        @test SF.refused(SF.caught(() -> PF.radiation(ceiling_fraction = SF.irreducible(0.0, ONE))),
                         "ceiling_fraction", "outside")
        @test SF.refused(SF.caught(() -> PF.radiation(ceiling_fraction = SF.irreducible(1.5, ONE))),
                         "ceiling_fraction", "outside")
        @test PF.radiation(ceiling_fraction = SF.irreducible(1.0, ONE)) isa Systems.RadiationDeclaration
        @test SF.refused(SF.caught(() -> PF.radiation(interval = SF.irreducible(0.0, TIME))),
                         "interval", "outside")
    end

    @testset "the keywords of Profile" begin
        full = PF.keywords()
        for key in keys(full)
            without = Base.structdiff(full, NamedTuple{(key,)})
            @test SF.refused(SF.caught(() -> Systems.Profile(; without...)), String(key), "missing")
        end
        @test SF.refused(SF.caught(() -> PF.profile(fast_precision = Float16)),
                         "fast_precision", "not one of")
        @test SF.refused(SF.caught(() -> PF.profile(day = 1.0)), "day", "field named day")
        @test isempty(intersect(fieldnames(Systems.Profile), fieldnames(Systems.Numerics)))
    end

    @testset "fast and full construct on every fixture system" begin
        systems = (SF.system(), SF.system(Float32), SF.two_star_system(),
                   SF.synchronous_system(), SF.flux_system())
        for s in systems, (build, label, precision) in
                ((Systems.fast_profile, :fast, Float32), (Systems.full_profile, :full, Float64))
            full = (system = s, memory_ceiling = SF.irreducible(1 << 34, ONE),
                    write_ceiling = SF.irreducible(1 << 20, ONE),
                    store_writers = SF.irreducible(4, ONE))
            p = build(; full...)
            @test p.label === label
            @test p.fast_precision === precision
            @test value(p.memory_ceiling) === 1 << 34
            @test value(p.write_ceiling) === 1 << 20
            @test value(p.store_writers) === 4
            for name in (:components, :radiation, :slow_tier, :daily_fallback_interval,
                         :exit_brackets)
                setting = getfield(p, name)
                @test setting isa Systems.Absent
                @test occursin("fiddlybits-", setting.argument)
            end
            st = Systems.strip(p)
            @test isbits(st)
            @test st isa Systems.StrippedProfile{Systems.system_precision(s),label,precision}
            @test st.write_ceiling === 1 << 20
            @test st.store_writers === 4
            override(key, v) = build(; merge(full, NamedTuple{(key,)}((v,)))...)
            @test SF.refused(SF.caught(() -> override(:memory_ceiling, SF.irreducible(0, ONE))),
                             "memory_ceiling", "outside")
            @test SF.refused(SF.caught(() -> override(:write_ceiling, SF.irreducible(0, ONE))),
                             "write_ceiling", "outside")
            @test SF.refused(SF.caught(() -> override(:store_writers, SF.irreducible(0, ONE))),
                             "store_writers", "outside")

            @testset "each keyword is required, with no default to fall back on" begin
                for key in (:memory_ceiling, :write_ceiling, :store_writers)
                    without = Base.structdiff(full, NamedTuple{(key,)})
                    @test SF.refused(SF.caught(() -> build(; without...)), String(key), "missing")
                end
            end
        end
    end
end
