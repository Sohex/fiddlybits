using Test
using Fiddlybits: Systems, Dispositions, Verdicts
import .SystemFixtures as SF

# system.dependency_subset on fixture readers and fixture declarations: the recorded
# reads against the declared graph, affected over the graph as data, and the tracking
# wrapper inert. docs/plans/fiddlybits-52v.4-system.md, section "The graph".

module GraphFixtures

using Fiddlybits: Dispositions

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
    :lunar => s -> sum((value(moon.mass) for moon in s.moons); init = 0.0))

"The paths the fixture readers declare, as plain data."
declared() = Dict{Symbol,Any}(
    :surface => [(:planet, :mass), (:planet, :volumetric_mean_radius), (:planet, :rotation, :period)],
    :stellar => [(:stars, :, :luminosity)],
    :orbital => [(:planet, :mass), (:stars, :, :mass), (:orbits, :planet, :semi_major_axis),
                 (:orbits, :planet, :primary)],
    :crustal => [(:planet, :lithosphere)],
    :lunar => [(:moons, :, :mass)])

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
