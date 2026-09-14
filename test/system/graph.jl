using Test
using Fiddlybits: Systems, Dispositions, Verdicts
import .SystemFixtures as SF

# system.dependency_subset on fixture readers and fixture declarations: the recorded
# reads against the declared graph, affected over the graph as data, and the tracking
# wrapper inert. docs/plans/fiddlybits-52v.4-system.md, section "The graph".

module GraphFixtures

using Fiddlybits: Dispositions, Systems, Dimensions
import ..SystemFixtures as SF

const value = Dispositions.value

"Fixture readers: each a function of one system, named as the fixture graph names it."
readers() = Dict{Symbol,Any}(
    :surface => s -> (value(s.planet.mass), value(s.planet.volumetric_mean_radius),
                      value(s.planet.rotation.period)),
    :stellar => s -> sum(value(star.luminosity) for star in s.stars),
    :orbital => s -> (value(s.orbits.planet.semi_major_axis),
                      value(s.planet.mass) + sum(value(star.mass) for star in s.stars),
                      s.orbits.planet.primary),
    :crustal => s -> (s.planet.lithosphere.province_classes,
                      map(value, s.planet.lithosphere.crustal_density)),
    :lunar => s -> sum((value(moon.mass) for moon in s.moons); init = 0.0),
    :stochastic => s -> value(s.root_seed))

"The paths the fixture readers declare, as plain data."
declared() = Dict{Symbol,Any}(
    :surface => [(:planet, :mass), (:planet, :volumetric_mean_radius), (:planet, :rotation, :period)],
    :stellar => [(:stars, :, :luminosity)],
    :orbital => [(:planet, :mass), (:stars, :, :mass), (:orbits, :planet, :semi_major_axis),
                 (:orbits, :planet, :primary)],
    :crustal => [(:planet, :lithosphere)],
    :lunar => [(:moons, :, :mass)],
    :stochastic => [(:root_seed,)])

const S = Systems
const ONE = Dimensions.DIMENSIONLESS
const LENGTH = Dimensions.LENGTH
const TIME = Dimensions.TIME

"A component entry named `name` with a ladder of interfaces at `positions`."
entry(name, spacing, positions) = S.ComponentDeclaration(
    name = name, target_spacing = SF.irreducible(spacing, LENGTH),
    finest_spacing = SF.irreducible(spacing / 4, LENGTH),
    ladder = S.VerticalLadder(depth_scale = :scale_height,
                              interfaces = Tuple(SF.irreducible(v, ONE) for v in positions)))

"A fixture profile on `SF.system()` holding two component entries and two exit brackets."
profile() = S.Profile(
    label = :graph_fixture, system = SF.system(),
    components = (entry(:ocean, 2e6, (0.0, 0.25, 1.0)), entry(:atmosphere, 1e6, (0.0, 0.1, 0.5, 2.0))),
    radiation = S.Absent(argument = "the graph fixture declares no radiation scheme"),
    fast_precision = Float32,
    slow_tier = S.Absent(argument = "the graph fixture declares no slow tier"),
    memory_ceiling = SF.irreducible(1024, ONE),
    write_ceiling = SF.irreducible(256, ONE),
    store_writers = SF.irreducible(4, ONE),
    settle_interval = SF.irreducible(3600.0, TIME),
    daily_fallback_interval = S.Absent(argument = "the graph fixture declares no daily tier"),
    exit_brackets = (S.ExitBracket(loop = :climate, criterion = :toa_balance,
                                   normalisation = :absorbed_instellation,
                                   tolerance = SF.irreducible(1e-3, ONE)),
                     S.ExitBracket(loop = :climate, criterion = :deep_drift,
                                   normalisation = :stock_per_relaxation_time,
                                   tolerance = SF.irreducible(1e-2, ONE))))

"Fixture profile readers: each a function of one profile, named as the fixture profile graph names it."
profile_readers() = Dict{Symbol,Any}(
    :surface => p -> (p.fast_precision, value(p.components.atmosphere.level),
                      map(value, p.components.atmosphere.ladder.interfaces)),
    :ocean => p -> (value(p.components[:ocean].finest_level), value(p.components[:ocean].target_spacing)),
    :loops => p -> minimum(value(e.tolerance) for e in p.exit_brackets),
    :levels => p -> sum(value(c.level) for c in p.components),
    :budget => p -> value(p.memory_ceiling))

"The profile paths the fixture profile readers declare, as plain data."
declared_profile() = Dict{Symbol,Any}(
    :surface => [(:fast_precision,), (:components, :atmosphere, :level), (:components, :atmosphere, :ladder)],
    :ocean => [(:components, :ocean)],
    :loops => [(:exit_brackets, :, :tolerance)],
    :levels => [(:components,)],
    :budget => [(:memory_ceiling,)])

"A reader that reaches `path` by property access and indexing, and returns what it reaches."
path_reader(path) = s -> foldl((y, step) -> step isa Symbol ? getproperty(y, step) : y[step],
                               path; init = s)

end # module GraphFixtures

import .GraphFixtures as GF

moonless() = SF.system(moons = (), orbits = Systems.OrbitHierarchy(
    planet = SF.planet_orbit(), moons = (), companions = ()))

@testset "system.dependency_subset" begin
    instances = (SF.system(), SF.system(Float32), SF.two_star_system(),
                 SF.synchronous_system(), SF.flux_system(), moonless())

    @testset "a tracked run is bitwise the run on the bare System" begin
        for s in instances, (name, reader) in GF.readers()
            @test reader(s) === reader(Systems.TrackingSystem(s))
        end
    end

    @testset "a recorded read is named by the path derived_fields reports" begin
        modelled = SF.system(stars = (SF.star(structure = SF.linear_model(), spectrum = SF.grid()),))
        for s in (instances..., modelled), (path, d) in Systems.derived_fields(s)
            t = Systems.TrackingSystem(s)
            @test GF.path_reader(path)(t) === d
            @test Systems.recorded_reads(t) == Set{Tuple}([path])
        end
    end

    @testset "a read ends at a value that holds no declaration, returned itself" begin
        s = SF.two_star_system()
        t = Systems.TrackingSystem(s)
        @test t.orbits.planet.primary === s.orbits.planet.primary
        @test t.planet.lithosphere.province_classes === s.planet.lithosphere.province_classes
        @test t.stars[1].spectrum.wavelengths === s.stars[1].spectrum.wavelengths
        @test t.planet isa Systems.Tracked
        @test length(t.stars) == 2
        @test Systems.recorded_reads(t) == Set{Tuple}([
            (:orbits, :planet, :primary), (:planet, :lithosphere, :province_classes),
            (:stars, 1, :spectrum, :wavelengths), (:stars, :)])
        t = Systems.TrackingSystem(moonless())
        @test t.moons === ()
        @test Systems.recorded_reads(t) == Set{Tuple}([(:moons, :)])
    end

    @testset "a read ends at an array holding declarations, recorded by its own path and returned itself" begin
        s = SF.system()
        @test s.stars[1].spectrum isa Systems.BracketedSpectrum
        spectral = q -> sum(Dispositions.value, q.stars[1].spectrum.surface_flux_density)
        t = Systems.TrackingSystem(s)
        @test t.stars[1].spectrum isa Systems.Tracked
        @test t.stars[1].spectrum.surface_flux_density === s.stars[1].spectrum.surface_flux_density
        t = Systems.TrackingSystem(s)
        @test spectral(t) === spectral(s)
        @test Systems.recorded_reads(t) == Set{Tuple}([(:stars, 1, :spectrum, :surface_flux_density)])
        r = Systems.dependency_subset(Dict{Symbol,Any}(:spectral => spectral),
                                      Dict{Symbol,Any}(:spectral => [(:stars, :, :spectrum)]), s)
        @test r.verdict === Verdicts.PASS()
        @test r.recorded[:spectral] == Set{Tuple}([(:stars, 1, :spectrum, :surface_flux_density)])
        @test Systems.reaches(s, (:stars, :, :spectrum, :surface_flux_density))
    end

    @testset "a declared path stepping past an array does not reach, and dependency_subset refuses it by name" begin
        s = SF.system()
        spectral = Dict{Symbol,Any}(:spectral => q -> sum(Dispositions.value, q.stars[1].spectrum.surface_flux_density))
        for bad in ((:stars, 1, :spectrum, :surface_flux_density, :size),
                    (:stars, 1, :spectrum, :surface_flux_density, :ref),
                    (:stars, :, :spectrum, :surface_flux_density, 1))
            @test !Systems.reaches(s, bad)
            @test SF.refused(SF.caught(() -> Systems.dependency_subset(spectral, Dict{Symbol,Any}(:spectral => [bad]), s)),
                             "path", "spectral declares $(bad), which does not reach through the system")
        end
    end

    @testset "recorded is a subset of declared on every instance" begin
        for s in instances
            r = Systems.dependency_subset(GF.readers(), GF.declared(), s)
            @test r.verdict === Verdicts.PASS()
            @test all(isempty, values(r.undeclared))
            unread = isempty(s.moons) ? Set{Tuple}([(:moons, :, :mass)]) : Set{Tuple}()
            @test r.unread[:lunar] == unread
            @test all(isempty, (r.unread[n] for n in keys(r.unread) if n !== :lunar))
        end
        r = Systems.dependency_subset(GF.readers(), GF.declared(), SF.two_star_system())
        @test r.recorded[:stellar] ==
              Set{Tuple}([(:stars, :), (:stars, 1, :luminosity), (:stars, 2, :luminosity)])
    end

    @testset "control: a reader touching a field it did not declare fails" begin
        readers = merge(GF.readers(), Dict{Symbol,Any}(
            :leaky => s -> Dispositions.value(s.planet.mass) * sin(Dispositions.value(s.planet.obliquity))))
        declared = merge(GF.declared(), Dict{Symbol,Any}(:leaky => [(:planet, :mass)]))
        r = Systems.dependency_subset(readers, declared, SF.system())
        @test r.verdict === Verdicts.FAIL()
        @test r.undeclared[:leaky] == Set{Tuple}([(:planet, :obliquity)])
        @test all(isempty, (r.undeclared[n] for n in keys(GF.declared())))
    end

    @testset "control: a read of every star declared for one star fails" begin
        readers = Dict{Symbol,Any}(:stellar => GF.readers()[:stellar])
        declared = Dict{Symbol,Any}(:stellar => [(:stars, 1, :luminosity)])
        r = Systems.dependency_subset(readers, declared, SF.two_star_system())
        @test r.verdict === Verdicts.FAIL()
        @test r.undeclared[:stellar] == Set{Tuple}([(:stars, :), (:stars, 2, :luminosity)])
    end

    @testset "a declared edge with no recorded read is reported, not failed" begin
        readers = Dict{Symbol,Any}(:idle => s -> nothing)
        declared = Dict{Symbol,Any}(:idle => [(:planet, :obliquity)])
        r = Systems.dependency_subset(readers, declared, SF.system())
        @test r.verdict === Verdicts.PASS()
        @test r.unread[:idle] == Set{Tuple}([(:planet, :obliquity)])
    end

    @testset "dependency_subset refuses what it cannot check" begin
        readers = GF.readers()
        declared = GF.declared()
        delete!(declared, :crustal)
        @test SF.refused(SF.caught(() -> Systems.dependency_subset(readers, declared, SF.system())),
                         "graph", "different sets")
        for bad in ((:planet, :day), (:stars, 2, :mass), (:orbits, :planet, :primary, :index))
            declared = merge(GF.declared(), Dict{Symbol,Any}(:surface => [bad]))
            @test SF.refused(SF.caught(() -> Systems.dependency_subset(GF.readers(), declared, SF.system())),
                             "path", "does not reach")
        end
    end

    @testset "affected lists exactly the names declaring an overlapping path" begin
        g = GF.declared()
        @test Systems.affected((:planet, :mass), g) == Set([:surface, :orbital])
        @test Systems.affected((:stars, 2, :luminosity), g) == Set([:stellar])
        @test Systems.affected((:stars, :), g) == Set([:stellar, :orbital])
        @test Systems.affected((:planet,), g) == Set([:surface, :orbital, :crustal])
        @test Systems.affected((:planet, :lithosphere, :crustal_density, 1), g) == Set([:crustal])
        @test isempty(Systems.affected((:stars, 1, :age), g))
        @test Systems.affected((:moons,), g) == Set([:lunar])
        @test Systems.affected((:moons, 1, :radius), g) == Set{Symbol}()
        @test Systems.affected((:root_seed,), g) == Set([:stochastic])
        @test Systems.affected((:root_seed, :value), g) == Set([:stochastic])
    end

    @testset "a read of the root seed is recorded as (:root_seed,) and returns the seed's declaration" begin
        s = SF.system(root_seed = SF.seed(0xD1CE5EED00000001))
        t = Systems.TrackingSystem(s)
        @test t.root_seed === s.root_seed
        @test Dispositions.value(t.root_seed) === 0xD1CE5EED00000001
        @test Systems.recorded_reads(t) == Set{Tuple}([(:root_seed,)])
    end

    @testset "control: a declared edge removed stops being reported by affected" begin
        g = GF.declared()
        g[:surface] = [(:planet, :volumetric_mean_radius), (:planet, :rotation, :period)]
        @test Systems.affected((:planet, :mass), g) == Set([:orbital])
        g[:orbital] = [(:stars, :, :mass), (:orbits, :planet, :semi_major_axis), (:orbits, :planet, :primary)]
        @test isempty(Systems.affected((:planet, :mass), g))
    end

    @testset "affected takes the graph as data and refuses anything else" begin
        @test SF.refused(SF.caught(() -> Systems.affected((:planet, :mass),
                                                         Dict(:surface => GF.readers()[:surface]))),
                         "graph", "not a collection")
        @test SF.refused(SF.caught(() -> Systems.affected((:planet, :mass), collect(GF.declared()))),
                         "graph", "not a dictionary")
        @test SF.refused(SF.caught(() -> Systems.affected((:planet, :mass),
                                                         Dict(:surface => [[:planet, :mass]]))),
                         "path", "not a tuple")
        @test SF.refused(SF.caught(() -> Systems.affected((:stars, 0), GF.declared())), "path", "step")
        @test SF.refused(SF.caught(() -> Systems.affected((:planet, "mass"), GF.declared())), "path", "step")
    end
end

@testset "system.dependency_subset over a Profile" begin
    p = GF.profile()

    @testset "a tracked run is bitwise the run on the bare Profile" begin
        for (name, reader) in GF.profile_readers()
            @test reader(p) === reader(Systems.TrackingProfile(p))
        end
    end

    @testset "a read of a component's own entry is recorded by its name" begin
        t = Systems.TrackingProfile(p)
        @test t.fast_precision === Float32
        @test t.components.atmosphere.ladder.depth_scale === :scale_height
        @test t.components[:ocean].level === p.components.ocean.level
        @test t.components isa Systems.Tracked
        @test Systems.recorded_reads(t) == Set{Tuple}([
            (:fast_precision,), (:components, :atmosphere, :ladder, :depth_scale), (:components, :ocean, :level)])
        t = Systems.TrackingProfile(p)
        @test keys(t.components) === (:atmosphere, :ocean)
        @test map(c -> c.name, t.components) === (atmosphere = :atmosphere, ocean = :ocean)
        @test Systems.recorded_reads(t) == Set{Tuple}([
            (:components,), (:components, :atmosphere, :name), (:components, :ocean, :name)])
        absent = Systems.fast_profile(system = SF.system(Float32), memory_ceiling = SF.irreducible(1024, GF.ONE),
                                      write_ceiling = SF.irreducible(256, GF.ONE),
                                      store_writers = SF.irreducible(4, GF.ONE),
                                      settle_interval = SF.irreducible(3600.0f0, GF.TIME))
        t = Systems.TrackingProfile(absent)
        @test t.components === absent.components
        @test Systems.recorded_reads(t) == Set{Tuple}([(:components,)])
    end

    @testset "recorded is a subset of declared" begin
        r = Systems.dependency_subset(GF.profile_readers(), GF.declared_profile(), p)
        @test r.verdict === Verdicts.PASS()
        @test all(isempty, values(r.undeclared))
        @test all(isempty, values(r.unread))
        @test r.recorded[:ocean] == Set{Tuple}([(:components, :ocean, :finest_level), (:components, :ocean, :target_spacing)])
        @test r.recorded[:loops] == Set{Tuple}([(:exit_brackets, :), (:exit_brackets, 1, :tolerance),
                                                (:exit_brackets, 2, :tolerance)])
        @test r.recorded[:levels] == Set{Tuple}([(:components,), (:components, :atmosphere, :level),
                                                 (:components, :ocean, :level)])
    end

    @testset "control: a reader reading fast_precision without declaring it fails" begin
        readers = merge(GF.profile_readers(), Dict{Symbol,Any}(
            :precise => q -> Dispositions.value(q.memory_ceiling) * sizeof(q.fast_precision)))
        declared = merge(GF.declared_profile(), Dict{Symbol,Any}(:precise => [(:memory_ceiling,)]))
        r = Systems.dependency_subset(readers, declared, p)
        @test r.verdict === Verdicts.FAIL()
        @test (:fast_precision,) in r.undeclared[:precise]
        @test r.undeclared[:precise] == Set{Tuple}([(:fast_precision,)])
        @test all(isempty, (r.undeclared[n] for n in keys(GF.declared_profile())))
    end

    @testset "control: a read of every component's entry declared for one entry fails" begin
        readers = Dict{Symbol,Any}(:levels => GF.profile_readers()[:levels])
        declared = Dict{Symbol,Any}(:levels => [(:components, :ocean, :level)])
        r = Systems.dependency_subset(readers, declared, p)
        @test r.verdict === Verdicts.FAIL()
        @test r.undeclared[:levels] == Set{Tuple}([(:components,), (:components, :atmosphere, :level)])
    end

    @testset "a declared profile path no read covers is reported in unread, not failed" begin
        readers = Dict{Symbol,Any}(:idle => q -> nothing, :budget => GF.profile_readers()[:budget])
        declared = Dict{Symbol,Any}(:idle => [(:components, :ocean, :ladder)],
                                    :budget => [(:memory_ceiling,), (:exit_brackets, :, :tolerance)])
        r = Systems.dependency_subset(readers, declared, p)
        @test r.verdict === Verdicts.PASS()
        @test r.unread[:idle] == Set{Tuple}([(:components, :ocean, :ladder)])
        @test r.unread[:budget] == Set{Tuple}([(:exit_brackets, :, :tolerance)])
    end

    @testset "dependency_subset refuses a declared path that does not reach through the profile" begin
        for bad in ((:components, :land), (:components, 1), (:components, :, :level), (:fast_precision, :x))
            declared = merge(GF.declared_profile(), Dict{Symbol,Any}(:ocean => [bad]))
            @test SF.refused(SF.caught(() -> Systems.dependency_subset(GF.profile_readers(), declared, p)),
                             "path", "ocean declares $(bad), which does not reach through the profile")
        end
        declared = merge(GF.declared(), Dict{Symbol,Any}(:surface => [(:planet, :day)]))
        @test SF.refused(SF.caught(() -> Systems.dependency_subset(GF.readers(), declared, SF.system())),
                         "path", "does not reach through the system")
    end

    @testset "affected answers what a profile change reaches" begin
        g = GF.declared_profile()
        @test Systems.affected((:fast_precision,), g) == Set([:surface])
        @test Systems.affected((:components, :atmosphere, :ladder, :interfaces, 2), g) == Set([:surface, :levels])
        @test Systems.affected((:components, :ocean, :level), g) == Set([:ocean, :levels])
        @test Systems.affected((:components,), g) == Set([:surface, :ocean, :levels])
        @test Systems.affected((:exit_brackets, 2, :tolerance), g) == Set([:loops])
        @test isempty(Systems.affected((:label,), g))
    end
end
