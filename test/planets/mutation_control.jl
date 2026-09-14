# The mutation control decision 0034 and system.derived_fields_reproduce name: a
# Derived rule replaced by the Earth value it happens to equal is caught on the
# synthetic instances. The fault is in the rule itself, not in a stored value, so it
# has to run where the constructor and Systems.rederive both call the mutated rule;
# a fresh process redefines the rule's function, the way test/backends/kernel_fault.jl
# runs its arms, and the parent process reads what it printed.

const PLANETS_JL = normpath(joinpath(@__DIR__, "Planets.jl"))
const MUTATION_PROJECT = normpath(joinpath(@__DIR__, "..", ".."))

"""
    run_mutation(code)

The stdout of a fresh `julia --project=MUTATION_PROJECT` process running `code`.
"""
function run_mutation(code::AbstractString)
    cmd = `julia --startup-file=no --project=$MUTATION_PROJECT -e $code`
    return read(pipeline(ignorestatus(cmd); stderr = devnull), String)
end

"""
    run_effective_temperature_mutation()

`Systems.effective_temperature` redefined, for `Float64` only, to always return the
value it gives on the Sun's declared luminosity and radius, before `test/planets/Planets.jl`
is loaded: the constructor and `Systems.rederive` both call the mutated rule, so
`derived_fields_reproduce`'s own mechanism cannot fail. Each instance's stars are then
checked against the closed form `T = (L / (4 pi R^2 sigma))^(1/4)`, written here and
not by calling `Systems.effective_temperature`.
"""
run_effective_temperature_mutation() = run_mutation("""
    using Fiddlybits: Systems, Dispositions, Reductions
    value = Dispositions.value

    earth_teff = Systems.effective_temperature(Float64, 3.828e26, 6.957e8)
    function Systems.effective_temperature(::Type{Float64}, l::Float64, r::Float64)
        return earth_teff
    end

    include("$PLANETS_JL")
    import .Planets as P

    instances = (("Earth", P.Earth()), ("SyntheticNonEarth", P.SyntheticNonEarth()),
                 ("SyntheticSynchronous", P.SyntheticSynchronous()),
                 ("SyntheticRetrograde", P.SyntheticRetrograde()),
                 ("SyntheticComposition2", P.SyntheticComposition2()))

    reproduces = true
    for (name, s) in instances, (path, d) in Systems.derived_fields(s)
        global reproduces
        reproduces &= (Systems.rederive(s, path) == value(d))
    end
    println("DERIVED_FIELDS_REPRODUCE ", reproduces ? "PASS" : "FAIL")

    sigma = value(Systems.stefan_boltzmann_constant(Float64))
    for (name, s) in instances, star in s.stars
        l, r = value(star.luminosity), value(star.radius)
        closed = (l / (4 * pi * r * r * sigma))^(1 / 4)
        stored = value(star.effective_temperature)
        bound = Reductions.error_bound(Float64, Systems.EFFECTIVE_TEMPERATURE_TERMS, closed)
        agrees = abs(closed - stored) <= bound
        println("CLOSED_FORM ", name, " ", agrees ? "AGREES" : "DISAGREES")
    end
    """)

"""
    run_synchronous_period_mutation()

`Systems.orbital_period` redefined, for `Float64` only, to always return the period
it gives on the Sun-Earth semi-major axis and mass sum, before `test/planets/Planets.jl`
is loaded: `SyntheticSynchronous`'s constructor (`resolve_rotation`) and
`Systems.rederive`'s `:synchronous_rotation_period` branch both reach it through
`Systems.orbital_period`, the one function both call. The instance is then checked
against the closed form `P = 2 pi sqrt(a^3 / (G M))`, written here and not by calling
`Systems.orbital_period`; the same closed form at the Sun-Earth inputs confirms the
mutated value is exactly what it was set to.
"""
run_synchronous_period_mutation() = run_mutation("""
    using Fiddlybits: Systems, Dispositions, Reductions
    value = Dispositions.value

    G = value(Systems.gravitational_constant(Float64))
    earth_a = 1.00000261 * 149_597_870_700.0
    earth_masses = (1.3271244e20 / G, 3.986004e14 / G)
    earth_period = Systems.orbital_period(Float64, earth_a, earth_masses)
    function Systems.orbital_period(::Type{Float64}, a::Float64, masses::Tuple)
        return earth_period
    end

    include("$PLANETS_JL")
    import .Planets as P

    s = P.SyntheticSynchronous()
    reproduces = true
    for (path, d) in Systems.derived_fields(s)
        global reproduces
        reproduces &= (Systems.rederive(s, path) == value(d))
    end
    println("DERIVED_FIELDS_REPRODUCE ", reproduces ? "PASS" : "FAIL")

    a = value(s.orbits.planet.semi_major_axis)
    masses = Systems.orbit_masses(s.stars, s.planet, s.moons, s.orbits.planet)
    closed = 2 * pi * sqrt(a^3 / (G * sum(masses)))
    stored = value(s.planet.rotation.period)
    bound = Reductions.error_bound(Float64, Systems.orbital_period_terms(length(masses)),
                                   closed)
    agrees = abs(closed - stored) <= bound
    println("CLOSED_FORM SyntheticSynchronous ", agrees ? "AGREES" : "DISAGREES")

    earth_closed = 2 * pi * sqrt(earth_a^3 / (G * sum(earth_masses)))
    earth_bound = Reductions.error_bound(Float64, Systems.orbital_period_terms(2),
                                         earth_closed)
    earth_agrees = abs(earth_closed - earth_period) <= earth_bound
    println("CLOSED_FORM Earth ", earth_agrees ? "AGREES" : "DISAGREES")
    """)

"""
    run_darwin_radau_mutation()

`Systems.darwin_radau_flattening` redefined, for `Float64` only, to always return the
flattening it gives on Earth's declared mass, volumetric mean radius and sidereal
rotation period, at the moment-of-inertia factor 0.3307 commonly cited for Earth
(Earth's own figure is `AbsentFigure`, so this is a value computed from Earth's
declared inputs through the true rule, not a stored field of `Earth()`), before
`test/planets/Planets.jl` is loaded: `SyntheticNonEarth`'s constructor
(`hydrostatic_flattening`) and `Systems.rederive`'s `:darwin_radau_flattening` branch
both call it with the rotation parameter and moment-of-inertia factor already
computed, the one step both share. The instance is then checked against the closed
form `f = (5q/2) / (1 + (25/4)(1 - 3C/2)^2)`, `q = omega^2 R^3 / (G M)`, from Murray
and Dermott (2000), Eq. (4.112), p. 153 (`fiddlybits-52v.4.11`), written here and not
by calling `Systems.darwin_radau_flattening` or `Systems.rotation_parameter`.
"""
run_darwin_radau_mutation() = run_mutation("""
    using Fiddlybits: Systems, Dispositions, Reductions
    value = Dispositions.value

    G = value(Systems.gravitational_constant(Float64))
    earth_mass = 3.986004e14 / G
    earth_radius = 6_371_008.4
    earth_period = 2 * pi / 7.292115e-5
    earth_c = 0.3307
    earth_q = Systems.rotation_parameter(Float64, earth_mass, earth_radius, earth_period)
    earth_flattening = Systems.darwin_radau_flattening(Float64, earth_c, earth_q)
    function Systems.darwin_radau_flattening(::Type{Float64}, c::Float64, q::Float64)
        return earth_flattening
    end

    include("$PLANETS_JL")
    import .Planets as P

    instances = (("Earth", P.Earth()), ("SyntheticNonEarth", P.SyntheticNonEarth()),
                 ("SyntheticSynchronous", P.SyntheticSynchronous()),
                 ("SyntheticRetrograde", P.SyntheticRetrograde()),
                 ("SyntheticComposition2", P.SyntheticComposition2()))

    reproduces = true
    for (name, s) in instances, (path, d) in Systems.derived_fields(s)
        global reproduces
        reproduces &= (Systems.rederive(s, path) == value(d))
    end
    println("DERIVED_FIELDS_REPRODUCE ", reproduces ? "PASS" : "FAIL")

    s = P.SyntheticNonEarth()
    mass = value(s.planet.mass)
    radius = value(s.planet.volumetric_mean_radius)
    period = value(s.planet.rotation.period)
    c = value(s.planet.figure.moment_of_inertia_factor)
    omega = 2 * pi / period
    q = omega * omega * radius^3 / (G * mass)
    u = 1 - 3 * c / 2
    closed = (5 * q / 2) / (1 + (25 / 4) * u * u)
    stored = value(s.planet.figure.flattening)
    bound = Reductions.error_bound(Float64,
        Systems.ROTATION_PARAMETER_TERMS + Systems.DARWIN_RADAU_TERMS, closed)
    agrees = abs(closed - stored) <= bound
    println("CLOSED_FORM SyntheticNonEarth ", agrees ? "AGREES" : "DISAGREES")

    earth_u = 1 - 3 * earth_c / 2
    earth_closed = (5 * earth_q / 2) / (1 + (25 / 4) * earth_u * earth_u)
    earth_bound = Reductions.error_bound(Float64,
        Systems.ROTATION_PARAMETER_TERMS + Systems.DARWIN_RADAU_TERMS, earth_closed)
    earth_agrees = abs(earth_closed - earth_flattening) <= earth_bound
    println("CLOSED_FORM Earth ", earth_agrees ? "AGREES" : "DISAGREES")
    """)

"""
    run_flux_semi_major_axis_mutation()

`Systems.semi_major_axis_from_flux` redefined, for `Float64` only, to always return
the semi-major axis it gives on the Sun's declared luminosity and the IAU nominal
total solar irradiance at one astronomical unit (Earth's own orbit declares its
semi-major axis directly, not by flux, so this is a value computed from Earth's
declared inputs and the published solar constant through the true rule), before
`test/planets/Planets.jl` is loaded: `SyntheticComposition2`'s constructor
(`resolve_planet_orbit`) and `Systems.rederive`'s `:flux_semi_major_axis` branch both
call it. The instance is then checked against the closed form
`a = sqrt(L / (4 pi F))`, written here and not by calling
`Systems.semi_major_axis_from_flux`.
"""
run_flux_semi_major_axis_mutation() = run_mutation("""
    using Fiddlybits: Systems, Dispositions, Reductions
    value = Dispositions.value

    earth_l = 3.828e26
    earth_f = 1361.0
    earth_a = Systems.semi_major_axis_from_flux(Float64, earth_l, earth_f)
    function Systems.semi_major_axis_from_flux(::Type{Float64}, l::Float64, f::Float64)
        return earth_a
    end

    include("$PLANETS_JL")
    import .Planets as P

    instances = (("Earth", P.Earth()), ("SyntheticNonEarth", P.SyntheticNonEarth()),
                 ("SyntheticSynchronous", P.SyntheticSynchronous()),
                 ("SyntheticRetrograde", P.SyntheticRetrograde()),
                 ("SyntheticComposition2", P.SyntheticComposition2()))

    reproduces = true
    for (name, s) in instances, (path, d) in Systems.derived_fields(s)
        global reproduces
        reproduces &= (Systems.rederive(s, path) == value(d))
    end
    println("DERIVED_FIELDS_REPRODUCE ", reproduces ? "PASS" : "FAIL")

    s = P.SyntheticComposition2()
    l = value(s.stars[s.orbits.planet.primary.index].luminosity)
    f = value(s.orbits.planet.flux_at_semi_major_axis)
    closed = sqrt(l / (4 * pi * f))
    stored = value(s.orbits.planet.semi_major_axis)
    bound = Reductions.error_bound(Float64, Systems.FLUX_SEMI_MAJOR_AXIS_TERMS, closed)
    agrees = abs(closed - stored) <= bound
    println("CLOSED_FORM SyntheticComposition2 ", agrees ? "AGREES" : "DISAGREES")

    earth_closed = sqrt(earth_l / (4 * pi * earth_f))
    earth_bound = Reductions.error_bound(Float64, Systems.FLUX_SEMI_MAJOR_AXIS_TERMS,
                                         earth_closed)
    earth_agrees = abs(earth_closed - earth_a) <= earth_bound
    println("CLOSED_FORM Earth ", earth_agrees ? "AGREES" : "DISAGREES")
    """)

@testset "mutation control: a Derived rule replaced by the Earth value it happens to equal" begin
    @testset "stefan_boltzmann_effective_temperature, on every star of every instance" begin
        out = run_effective_temperature_mutation()
        @test occursin("DERIVED_FIELDS_REPRODUCE PASS", out)
        @test occursin("CLOSED_FORM Earth AGREES", out)
        for name in ("SyntheticNonEarth", "SyntheticSynchronous", "SyntheticRetrograde",
                    "SyntheticComposition2")
            @test occursin("CLOSED_FORM $(name) DISAGREES", out)
        end
    end

    @testset "synchronous_rotation_period, on SyntheticSynchronous" begin
        out = run_synchronous_period_mutation()
        @test occursin("DERIVED_FIELDS_REPRODUCE PASS", out)
        @test occursin("CLOSED_FORM Earth AGREES", out)
        @test occursin("CLOSED_FORM SyntheticSynchronous DISAGREES", out)
    end

    @testset "darwin_radau_flattening, on SyntheticNonEarth" begin
        out = run_darwin_radau_mutation()
        @test occursin("DERIVED_FIELDS_REPRODUCE PASS", out)
        @test occursin("CLOSED_FORM Earth AGREES", out)
        @test occursin("CLOSED_FORM SyntheticNonEarth DISAGREES", out)
    end

    @testset "flux_semi_major_axis, on SyntheticComposition2" begin
        out = run_flux_semi_major_axis_mutation()
        @test occursin("DERIVED_FIELDS_REPRODUCE PASS", out)
        @test occursin("CLOSED_FORM Earth AGREES", out)
        @test occursin("CLOSED_FORM SyntheticComposition2 DISAGREES", out)
    end

    @testset "root_origin: planet_mean_longitude_at_epoch takes only the float type" begin
        # decision 0004, section The reference directions of the orbit hierarchy.
        for FT in (Float64,)
            @test Systems.planet_mean_longitude_at_epoch(FT).from == (:secondary,)
            @test value(Systems.planet_mean_longitude_at_epoch(FT)) == zero(FT)
        end
    end
end
