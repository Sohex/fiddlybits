using Test
using Fiddlybits: Systems, Dispositions, Dimensions, Provenance
import .SystemFixtures as SF

# strip(system): an isbits struct of plain FT for every instance, a function of the
# system alone, reading its members by name. docs/plans/fiddlybits-52v.4-system.md,
# section "The struct".

@testset "system strip" begin
    value = Dispositions.value
    one_ = Dimensions.DIMENSIONLESS
    figure(T, c) = Systems.HydrostaticFigure(moment_of_inertia_factor = SF.irreducible(T(c), one_))
    hydrostatic(T; kw...) = SF.system(T; planet = SF.planet(T; figure = figure(T, T(33) / 100), kw...))
    instances = (hydrostatic(Float64), hydrostatic(Float32),
                 hydrostatic(Float64; rotation = Systems.SynchronousRotation()),
                 hydrostatic(Float32; rotation = Systems.SynchronousRotation()),SF.system(), SF.system(Float32), SF.two_star_system(), SF.synchronous_system(),
                 SF.flux_system(), SF.circumbinary_system(),
                 SF.system(orbits = Systems.OrbitHierarchy(
                     planet = SF.planet_orbit(reference_plane = :primary_equator),
                     moons = (SF.moon_orbit(),), companions = ())),
                 SF.system(stars = (SF.star(structure = SF.linear_model(), spectrum = SF.grid()),)),
                 SF.system(inventories = SF.inventories(condensable =
                     Systems.NoCondensable(argument = "the fixture's volatiles do not condense"))))

    @testset "isbits(strip(system)) holds for every instance, the root seed carried as a UInt64" begin
        for s in instances
            @test isbits(Systems.strip(s))
            @test Systems.strip(s).root_seed === value(s.root_seed)
            @test Systems.strip(s).root_seed isa UInt64
        end
    end

    @testset "a philox_draw keyed on strip(system).root_seed equals one keyed on the declared seed" begin
        declared = 0xD1CE5EED00000001
        digest = ntuple(i -> UInt8(i), 32)
        draw(seed) = Provenance.philox_draw(seed, digest, 3, 2, 5, 0)
        @test draw(Systems.strip(SF.system(root_seed = SF.seed(declared))).root_seed) == draw(declared)
        @test draw(Systems.strip(SF.system(Float32; root_seed = SF.seed(declared))).root_seed) == draw(declared)

        @testset "control: a flipped seed moves the draw" begin
            flipped = Systems.strip(SF.system(root_seed = SF.seed(declared + 1))).root_seed
            @test draw(flipped) != draw(declared)
            @test draw(flipped) == draw(declared + 1)
        end
    end

    @testset "two strips of one system are identical" begin
        for s in instances
            @test Systems.strip(s) === Systems.strip(s)
        end
    end

    @testset "every value is the system's own, of its FT" begin
        s = SF.two_star_system(Float32)
        st = Systems.strip(s)
        @test st isa Systems.StrippedSystem{Float32}
        @test st.stars[2].effective_temperature === value(s.stars[2].effective_temperature)
        @test st.planet.gravitational_parameter ===
              Systems.gravitational_parameter(Float32, value(s.planet.mass))
        @test st.orbits.companions[1].primary_mass === value(s.stars[1].mass)
        @test st.numerics.exner_reference_pressure === value(s.numerics.exner_reference_pressure)
        @test st.planet.sub_primary_longitude_at_epoch ===
              value(s.planet.sub_primary_longitude_at_epoch)
    end

    @testset "strip carries the longitudes of the orbit hierarchy and the equator's node" begin
        for T in (Float64, Float32)
            s = SF.two_star_system(T)
            st = Systems.strip(s)
            @test st.planet.equator_ascending_node_longitude === value(s.planet.equator_ascending_node_longitude)
            for (o, so) in ((s.orbits.planet, st.orbits.planet), (s.orbits.moons[1], st.orbits.moons[1]),
                            (s.orbits.companions[1], st.orbits.companions[1]))
                @test so.longitude_of_ascending_node === value(o.longitude_of_ascending_node)
                @test so.longitude_of_periapsis === value(o.longitude_of_periapsis)
                @test so.mean_longitude_at_epoch === value(o.mean_longitude_at_epoch)
            end
            @test st.orbits.planet.mean_longitude_at_epoch === zero(T)
            @test Systems.strip(SF.flux_system(T)).orbits.planet.mean_longitude_at_epoch === zero(T)
        end

        @testset "control: a changed declaration moves its stripped value" begin
            one_ = Dimensions.DIMENSIONLESS
            moved = SF.system(planet = SF.planet(equator_ascending_node_longitude = SF.irreducible(3.0, one_)),
                              orbits = Systems.OrbitHierarchy(
                                  planet = SF.planet_orbit(longitude_of_periapsis = SF.irreducible(4.0, one_)),
                                  moons = (SF.moon_orbit(mean_longitude_at_epoch = SF.irreducible(5.0, one_)),),
                                  companions = ()))
            st, base = Systems.strip(moved), Systems.strip(SF.system())
            @test st.planet.equator_ascending_node_longitude === 3.0 !== base.planet.equator_ascending_node_longitude
            @test st.orbits.planet.longitude_of_periapsis === 4.0 !== base.orbits.planet.longitude_of_periapsis
            @test st.orbits.moons[1].mean_longitude_at_epoch === 5.0 !== base.orbits.moons[1].mean_longitude_at_epoch
        end
    end

    @testset "strip carries the figure by its kind" begin
        for T in (Float64, Float32)
            s = SF.system(T)
            st = Systems.strip(s)
            @test st.planet.figure isa Systems.StrippedAbsentFigure{T}
            @test st.planet.figure.equator_pole_gravity_difference ===
                  value(s.planet.figure.equator_pole_gravity_difference)
            for h in (hydrostatic(T), hydrostatic(T; rotation = Systems.SynchronousRotation()))
                sh = Systems.strip(h)
                @test isbits(sh)
                @test sh.planet.figure isa Systems.StrippedHydrostaticFlattening{T}
                @test sh.planet.figure.flattening === value(h.planet.figure.flattening)
                @test sh.planet.figure.moment_of_inertia_factor === T(33) / 100
            end
        end

        @testset "control: a changed factor moves the stripped flattening" begin
            condensed = Systems.strip(hydrostatic(Float64)).planet.figure
            uniform = Systems.strip(SF.system(planet = SF.planet(figure = figure(Float64, 0.4)))).planet.figure
            @test uniform.moment_of_inertia_factor === 0.4
            @test uniform.flattening !== condensed.flattening
            @test uniform.flattening === Dispositions.value(Systems.hydrostatic_flattening(
                figure(Float64, 0.4), SF.system().planet).flattening)
        end
    end

    @testset "members are read by name" begin
        s = SF.system()
        st = Systems.strip(s)
        @test Systems.province_value(st.planet.lithosphere, :crustal_thickness, :thick) ===
              value(s.planet.lithosphere.crustal_thickness[2])
        @test SF.refused(SF.caught(() -> Systems.province_value(st.planet.lithosphere,
                                                               :crustal_density, :absent)),
                         "province class", "absent")
        @test Systems.named_value(st.inventories.atmosphere, :CO2) ===
              value(s.inventories.atmosphere.fractions[2])
        @test typeof(st.orbits.planet).parameters[2] === Systems.StarBody(1)
        @test typeof(st.orbits.moons[1]).parameters[4] === :planet_equator
        @test typeof(st.planet).parameters[2] === :prograde
        @test typeof(Systems.strip(SF.synchronous_system()).planet).parameters[2] === :prograde
    end
end
