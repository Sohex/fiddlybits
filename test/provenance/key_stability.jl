using Test
using UUIDs: UUIDs, UUID
using Fiddlybits: Fiddlybits, Provenance, Coupling, Systems, Backends, Mesh, Verdicts, Dispositions,
                  Fields, Time

# provenance.key_stability and the key of docs/plans/fiddlybits-52v.6-provenance.md,
# section "The key"; docs/decisions/0010-content-addressed-artifacts.md, section "What the
# key names"; docs/imports/sha-uuids.md.

isdefined(@__MODULE__, :SystemFixtures) ||
    include(joinpath(@__DIR__, "..", "system", "fixtures.jl"))
import .SystemFixtures as SF

module KeyFixtures

using Fiddlybits: Provenance, Coupling, Systems, Backends, Mesh, Verdicts, Fields, Time, Dimensions
using SHA: sha256
import ..SystemFixtures as SF

const ONE = Dimensions.DIMENSIONLESS
const TIME = Dimensions.TIME
const LENGTH = Dimensions.LENGTH

"A fixture component: its declaration and nothing else."
struct Component
    declaration::Coupling.Declaration
end

Coupling.declare(c::Component) = c.declaration

"The level every fixture component writes at."
level() = 2

"A `Mesh.Support` at `level()` on a sphere of radius `radius`."
function support(radius)
    l = Mesh.hierarchy(level()).levels[level() + 1]
    return Mesh.Support(level(), l, Mesh.geometry(l, Mesh.stencils(l)); kind = :icosahedral_bisection,
                        refinement = (), radius = radius, element_type = :Float64, fractions = ())
end

"A fixture `CodeVersion`, clean; `kw` replaces any keyword."
code(; kw...) = Provenance.CodeVersion(; merge(
    (commit = "1"^40, tree = "2"^40, manifest = "3"^40, julia = v"1.12.7", dirty = false),
    values(kw))...)

"The fixture `Time.Interval` over `T`, neither bound a short decimal."
interval(T = Float64) = Time.Interval(T(1) / 10, T(1) / 3)

"A vertical ladder over `T` with interfaces at `positions`."
ladder(T, positions) = Systems.VerticalLadder(
    depth_scale = :scale_height, interfaces = Tuple(SF.irreducible(T(v), ONE) for v in positions))

"The fixture's two component entries over `T`, the atmosphere's ladder at `atmosphere_ladder`."
entries(T = Float64; atmosphere_ladder = (0, 0.1, 0.5, 2)) = (
    Systems.ComponentDeclaration(name = :atmosphere, target_spacing = SF.irreducible(T(1e6), LENGTH),
                                 finest_spacing = SF.irreducible(T(2.5e5), LENGTH),
                                 ladder = ladder(T, atmosphere_ladder)),
    Systems.ComponentDeclaration(name = :ocean, target_spacing = SF.irreducible(T(2e6), LENGTH),
                                 finest_spacing = SF.irreducible(T(5e5), LENGTH),
                                 ladder = ladder(T, (0, 0.25, 1))))

"A `Systems.Profile` over `T` on `SF.system(T)` with every setting present; `kw` replaces any keyword."
profile(T = Float64; kw...) = Systems.Profile(; merge(
    (label = :key_fixture, system = SF.system(T), components = entries(T),
     radiation = Systems.RadiationDeclaration(
         g_points = (SF.irreducible(16, ONE), SF.irreducible(8, ONE)),
         interval = SF.irreducible(T(600), TIME), ceiling_fraction = SF.irreducible(T(0.25), ONE),
         cycles = Systems.RadiationCycles(
             diurnal_cycle = Systems.Undefined(argument = "the key fixture declares no mean solar day"),
             eclipse_durations = Systems.Undefined(argument = "no body of the key fixture eclipses a source"),
             cloud_timescale = SF.irreducible(T(2e3), TIME))),
     fast_precision = T,
     slow_tier = Systems.SlowTier(acceleration = SF.bracket(T(10), T(1), T(100), ONE),
                                  refresh_interval = SF.irreducible(T(3e9), TIME)),
     memory_ceiling = SF.irreducible(1024, ONE),
     daily_fallback_interval = SF.bracket(T(1e5), T(600), T(1e6), TIME),
     exit_brackets = (Systems.ExitBracket(loop = :climate, criterion = :toa_balance,
                                          normalisation = :absorbed_instellation,
                                          tolerance = SF.irreducible(T(1e-3), ONE)),
                      Systems.ExitBracket(loop = :climate, criterion = :deep_drift,
                                          normalisation = :stock_per_relaxation_time,
                                          tolerance = SF.bracket(T(1e-2), T(5e-3), T(2e-2), ONE)))),
    values(kw))...)

"The fixture profiles built so far, by float type."
const PROFILES = Dict{Type,Systems.Profile}()

"`profile(T)`, built once per `T`."
fixture_profile(T) = get!(() -> profile(T), PROFILES, T)

"The quantity the fixture component `name` writes."
output(name) = Symbol(name, :_out)

"A `Coupling.Read` of `q` at `read_level`, through `operator`, `lagged` and `move` as given."
reading(q; read_level = level(), operator = Coupling.AtLevel(measure = Coupling.NoMeasure()), lagged = false,
        move = false) =
    Coupling.Read(quantity = q, level = read_level, operator = operator, lagged = lagged, move = move)

"A `Coupling.Write` of `q` with `semantics`, carrying `conserves`."
writing(q; semantics = Fields.Intensive(), conserves = ()) =
    Coupling.Write(quantity = q, semantics = semantics, conserves = conserves)

"""
A `Coupling.Declaration` named `name` over `system_fields` and `profile_fields`, reading
`reads` and writing `writes`, each a quantity given its fixture `reading` or `writing`, or a
`Read` or `Write` itself; its `output` unless `writes` says otherwise.
"""
declaration(name, system_fields; profile_fields = (), reads = (), writes = (output(name),),
            backend = Backends.CPU()) =
    Coupling.Declaration(
        name = name, level = level(),
        reads = Tuple(r isa Coupling.Read ? r : reading(r) for r in reads),
        writes = Tuple(w isa Coupling.Write ? w : writing(w) for w in writes),
        stocks = (), system_fields = system_fields, profile_fields = profile_fields, backend = backend)

"The system paths each fixture writer declares."
declared() = (
    surface = ((:planet, :mass), (:planet, :volumetric_mean_radius), (:planet, :rotation, :period)),
    stellar = ((:stars, :, :luminosity),),
    orbital = ((:planet, :mass), (:stars, :, :mass), (:orbits, :planet, :semi_major_axis),
               (:orbits, :planet, :primary)),
    crustal = ((:planet, :lithosphere),),
    lunar = ((:moons, :, :mass),),
    spectral = ((:stars, :, :spectrum), (:moons, :, :reflectance)),
    bookkeeping = ((:numerics,), (:inventories,)),
    stochastic = ((:root_seed,),),
    idle = ())

"The profile paths each fixture writer declares, by the names of `declared()`."
declared_profile() = (
    surface = ((:fast_precision,), (:components, :atmosphere, :ladder)),
    stellar = ((:radiation, :g_points),),
    orbital = ((:components, :ocean),),
    crustal = ((:slow_tier, :acceleration),),
    lunar = ((:exit_brackets, :, :tolerance),),
    spectral = ((:radiation,), (:memory_ceiling,)),
    bookkeeping = ((:daily_fallback_interval,),),
    stochastic = (),
    idle = ())

"The names of the fixture writers."
writers() = collect(keys(declared()))

"The declaration of the fixture writer `name`, over its declared system and profile paths; `kw` replaces any keyword."
declared_declaration(name; kw...) =
    declaration(name, declared()[name]; merge((profile_fields = declared_profile()[name],), values(kw))...)

"The declared profile graph of the fixture writers, as `Systems.affected` reads a graph."
profile_graph() = Dict{Symbol,Set{Tuple}}(n => Set{Tuple}(declared_profile()[n]) for n in writers())

"""
    assembly()

The assembled fixture: one component per entry of `declared()` writing its `output`, and
a `:sink` that reads every output, writes nothing and declares no path.
"""
function assembly()
    components = [Component(declared_declaration(n)) for n in writers()]
    sink = Component(declaration(:sink, (); reads = Tuple(output(n) for n in writers()), writes = ()))
    return Coupling.assemble(components..., sink; initial_conditions = (), sequence = 1,
                             instant = 0.0, tier = :fast)
end

"The float type of the `System` `system`."
float_type(system) = Systems.system_precision(system)

"""
The key of the artifact `output(declaration.name)` the declaration `declaration` writes, on
`SF.system()` at `support(1.0)` over `interval()` with no input; `kw` replaces any keyword.
"""
key_of(declaration; kw...) = Provenance.ArtifactKey(; merge(
    (code = code(), declaration = declaration, system = SF.system(), profile = fixture_profile(Float64),
     inputs = (;), quantity = output(declaration.name), support = support(1.0), interval = interval(),
     operator_version = 1), values(kw))...)

"The key of the component `name` of `a` on `system` at `support`; `kw` replaces any other keyword."
key(a::Coupling.Assembly, name, system, support; kw...) = Provenance.ArtifactKey(; merge(
    (code = code(), declaration = Coupling.declaration(a, name), system = system,
     profile = fixture_profile(float_type(system)), inputs = (;), quantity = output(name),
     support = support, interval = interval(float_type(system)), operator_version = 1), values(kw))...)

"""
    leaves(x)

Every value in `x` a flip can change, as `(path, value)`: the floats, integers, `Bool`s,
`Symbol`s and `String`s reached through tuples and arrays by position and through named
tuples and the fields of immutable structs by name.
"""
leaves(x) = leaves!(Tuple{Tuple,Any}[], (), x)

leaves!(found, path, x::Union{AbstractFloat,Integer,Symbol,String}) = push!(found, (path, x))

function leaves!(found, path, x::Union{Tuple,Array})
    foreach(i -> leaves!(found, (path..., i), x[i]), eachindex(x))
    return found
end

function leaves!(found, path, x::NamedTuple)
    foreach(n -> leaves!(found, (path..., n), x[n]), keys(x))
    return found
end

function leaves!(found, path, x)
    (x isa Type || ismutable(x) || !isstructtype(typeof(x))) && return found
    foreach(n -> leaves!(found, (path..., n), getfield(x, n)), fieldnames(typeof(x)))
    return found
end

"""
    replace_at(x, path, f)

A copy of `x` with the value at `path` replaced by `f` of it: tuples, named tuples and
arrays rebuilt, and immutable structs built by `new` over their fields, no constructor
run.
"""
replace_at(x, path::Tuple, f) = isempty(path) ? f(x) : replace_step(x, first(path), Base.tail(path), f)

replace_step(x::Tuple, i::Int, rest, f) = ntuple(j -> j == i ? replace_at(x[j], rest, f) : x[j], length(x))

replace_step(x::NamedTuple, n::Symbol, rest, f) = merge(x, NamedTuple{(n,)}((replace_at(x[n], rest, f),)))

function replace_step(x::Array, i::Int, rest, f)
    y = copy(x)
    y[i] = replace_at(x[i], rest, f)
    return y
end

function replace_step(x, n::Symbol, rest, f)
    T = typeof(x)
    fields = [m === n ? replace_at(getfield(x, m), rest, f) : getfield(x, m) for m in fieldnames(T)]
    return Core.eval(@__MODULE__, Expr(:new, T, map(QuoteNode, fields)...))
end

"`x` changed by the least step of its kind."
flip(x::Bool) = !x
flip(x::AbstractFloat) = nextfloat(x)
flip(x::Integer) = x + one(x)
flip(x::Symbol) = Symbol(x, :_flipped)
flip(x::String) = x * "_flipped"

"The shortest decimal text that parses back to `x`."
shortest(x::Float64) = string(x)
shortest(x::Float32) = replace(string(x), "f" => "e")

"The exact decimal expansion of the binary value of `x`."
expanded(x::AbstractFloat) = string(BigFloat(x; precision = 256))

"`x` with every float replaced by the parse of `printer` of it."
reparsed(x, printer) = foldl((s, (p, v)) -> replace_at(s, p, y -> parse(typeof(y), printer(y))),
                             [(p, v) for (p, v) in leaves(x) if v isa AbstractFloat];
                             init = x)

"The positive control of the text round trip: SHA-256 over the printed decimal of every float in `x`, printed by `printer`."
decimal_digest(x, printer) =
    sha256(join([printer(v) for (p, v) in leaves(x) if v isa AbstractFloat], "\n"))

"`f()`; the exception it raises, or `nothing`."
caught(f) = try
    f()
    nothing
catch err
    err
end

"`true` when `e` is a `Verdicts.Refusal` of `quantity` whose reason contains `text`."
refused(e, quantity, text) =
    e isa Verdicts.Refusal && e.quantity == quantity && occursin(text, e.reason)

"The stripped standard output of `git -C root` with `args`, every `GIT_` variable removed."
git(root, args) = String(strip(read(setenv(`git -C $(root) $(args)`,
                                           [k => v for (k, v) in ENV if !startswith(k, "GIT_")]), String)))

"Initialises a git repository at `root` on the branch `fixture`."
init(root) = git(root, `-c init.defaultBranch=fixture init -q`)

"Commits everything under `root` as a fixture author, with no hooks and no signing."
commit_all(root) = (git(root, `add -A`);
                    git(root, `-c user.name=fixture -c user.email=fixture@invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null commit -q -m fixture`))

end # module KeyFixtures

import .KeyFixtures as KF

@testset "provenance.key_stability" begin
    a = KF.assembly()
    s1 = KF.support(1.0)

    @testset "the canonical serialisation is the stated little-endian layout" begin
        P = Provenance
        zeros7 = fill(0x00, 7)
        @test P.canonical_bytes(1.5) == [P.TAG_FLOAT; 0x08; zeros(UInt8, 6); 0xf8; 0x3f]
        @test P.canonical_bytes(Float32(1.5)) == [P.TAG_FLOAT; 0x04; 0x00; 0x00; 0xc0; 0x3f]
        @test P.canonical_bytes(-0.0) == [P.TAG_FLOAT; 0x08; zeros7; 0x80]
        @test P.canonical_bytes(:ab) == [P.TAG_SYMBOL; 0x02; zeros7; 0x61; 0x62]
        @test P.canonical_bytes((1, true)) == [P.TAG_TUPLE; 0x02; zeros7; P.TAG_SIGNED; 0x01; zeros7;
                                                P.TAG_BOOL; 0x01]
        @test P.canonical_bytes((b = 1, a = 2)) ==
              [P.TAG_NAMED_TUPLE; 0x02; zeros7; 0x01; zeros7; 0x61; P.TAG_SIGNED; 0x02; zeros7;
               0x01; zeros7; 0x62; P.TAG_SIGNED; 0x01; zeros7]
    end

    @testset "canonical_bytes refuses a value with no canonical serialisation" begin
        for bad in (big(1.0), Int128(1), Ref(1), sin, Dict(1 => 2), Fiddlybits)
            @test KF.refused(KF.caught(() -> Provenance.canonical_bytes(bad)), "canonical serialisation",
                             "no canonical serialisation")
        end

        @testset "positive control: each kind it takes serialises" begin
            for good in (1.0, Int32(1), UInt8(1), true, :a, "a", nothing, (1, 2), (a = 1,), [1.0 2.0],
                         Float32, SF.star().mass)
                @test Provenance.canonical_bytes(good) isa Vector{UInt8}
            end
        end
    end

    @testset "the key is identical after every float of the parameter subset and both bounds of the interval are printed and reparsed" begin
        for system in (SF.system(), SF.system(Float32), SF.two_star_system())
            T = KF.float_type(system)
            iv = KF.interval(T)
            for printer in (KF.shortest, KF.expanded)
                round_tripped = KF.reparsed(system, printer)
                iv_round_tripped = KF.reparsed(iv, printer)
                for n in KF.writers()
                    @test KF.key(a, n, round_tripped, s1; interval = iv_round_tripped) ==
                          KF.key(a, n, system, s1; interval = iv)
                end
            end

            @testset "positive control: a hash over printed decimal moves on the text round trip" begin
                @test KF.decimal_digest((system, iv), KF.shortest) !=
                      KF.decimal_digest(KF.reparsed((system, iv), KF.expanded), KF.expanded)
                @test KF.shortest(iv.t0.seconds) != KF.expanded(iv.t0.seconds)
                @test KF.shortest(iv.t1.seconds) != KF.expanded(iv.t1.seconds)
            end
        end
    end

    @testset "flipping each leaf by reflection moves exactly the keys of the components that declared it" begin
        graph = Coupling.declared_graph(a)
        writers = Set(KF.writers())
        for system in (SF.two_star_system(),)
            base = Dict(n => KF.key(a, n, system, s1) for n in writers)
            moved_any, moved_none, seed_moved = false, false, nothing
            for (path, x) in KF.leaves(system)
                flipped = KF.replace_at(system, path, KF.flip)
                moved = Set(n for n in writers if KF.key(a, n, flipped, s1) != base[n])
                expected = intersect(Systems.affected(path, graph), writers)
                @test moved == expected
                moved_any |= !isempty(moved)
                moved_none |= isempty(moved)
                path == (:root_seed, :value) && (seed_moved = moved)
            end

            @testset "positive control: some flip moves a key and some flip moves none" begin
                @test moved_any
                @test moved_none
            end

            @testset "positive control: the root seed is a leaf the reflection flips, and its flip moves the stochastic key alone" begin
                @test seed_moved == Set([:stochastic])
            end
        end
    end

    @testset "two systems differing only in the root seed give two keys for a component declaring (:root_seed,)" begin
        system = SF.two_star_system()
        reseeded = SF.two_star_system(root_seed = SF.seed(Dispositions.value(system.root_seed) + 1))
        @test (:root_seed,) in KF.declared().stochastic
        @test KF.key(a, :stochastic, reseeded, s1) != KF.key(a, :stochastic, system, s1)

        @testset "positive control: a component not declaring it keeps its key" begin
            others = [n for n in KF.writers() if !any(p -> first(p) === :root_seed, KF.declared()[n])]
            @test length(others) == length(KF.writers()) - 1
            for n in others
                @test KF.key(a, n, reseeded, s1) == KF.key(a, n, system, s1)
            end
        end
    end

    @testset "two intervals from identical inputs give two keys" begin
        system = SF.system()
        k(iv) = KF.key(a, :idle, system, s1; interval = iv)
        @test k(Time.Interval(0.0, 600.0)) != k(Time.Interval(600.0, 1200.0))
        @test k(Time.Interval(0.0, 600.0)) != k(Time.Interval(300.0, 600.0))
        @test k(Time.Interval(0.0, 600.0)) != k(Time.Interval(0.0, 1200.0))
        @test k(Time.Interval(0.0f0, 600.0f0)) != k(Time.Interval(0.0, 600.0))

        @testset "positive control: an interval rebuilt from the bit patterns of its bounds gives one key" begin
            iv = KF.interval()
            rebuilt = Time.Interval(reinterpret(Float64, reinterpret(UInt64, iv.t0.seconds)),
                                    reinterpret(Float64, reinterpret(UInt64, iv.t1.seconds)))
            @test k(rebuilt) == k(iv)
        end
    end

    @testset "two fast precisions give two keys for a component declaring (:fast_precision,)" begin
        system = SF.system()
        p64 = KF.fixture_profile(Float64)
        p32 = KF.profile(Float64; fast_precision = Float32)
        @test (:fast_precision,) in KF.declared_profile().surface
        @test KF.key(a, :surface, system, s1; profile = p32) != KF.key(a, :surface, system, s1; profile = p64)

        @testset "positive control: a component not declaring it keeps one key" begin
            for n in KF.writers()
                any(p -> first(p) === :fast_precision, KF.declared_profile()[n]) && continue
                @test KF.key(a, n, system, s1; profile = p32) == KF.key(a, n, system, s1; profile = p64)
            end
        end
    end

    @testset "flipping each leaf of the profile by reflection moves exactly the keys of the components whose declared profile paths overlap it" begin
        system = SF.system()
        graph = KF.profile_graph()
        writers = Set(KF.writers())
        base_profile = KF.fixture_profile(Float64)
        base = Dict(n => KF.key(a, n, system, s1) for n in writers)
        moved_any, moved_none = false, false
        for (path, x) in KF.leaves(base_profile)
            flipped = KF.replace_at(base_profile, path, KF.flip)
            moved = Set(n for n in writers if KF.key(a, n, system, s1; profile = flipped) != base[n])
            @test moved == Systems.affected(path, graph)
            moved_any |= !isempty(moved)
            moved_none |= isempty(moved)
        end

        @testset "positive control: some flip moves a key and some flip moves none" begin
            @test moved_any
            @test moved_none
        end
    end

    @testset "a component's own entry is reached by its name" begin
        system = SF.system()
        forward = KF.profile(Float64; components = KF.entries(Float64))
        backward = KF.profile(Float64; components = reverse(KF.entries(Float64)))
        for n in KF.writers()
            @test KF.key(a, n, system, s1; profile = backward) == KF.key(a, n, system, s1; profile = forward)
        end

        @testset "positive control: one entry's ladder changed moves the key of the component declaring it and of no other" begin
            changed = KF.profile(Float64; components = reverse(KF.entries(Float64; atmosphere_ladder = (0, 0.2, 0.5, 2))))
            moved = Set(n for n in KF.writers()
                        if KF.key(a, n, system, s1; profile = changed) != KF.key(a, n, system, s1; profile = forward))
            @test moved == Set([:surface])
        end
    end

    @testset "one input key read through two operators, two measures, or lagged and not, gives two keys" begin
        x = KF.key(a, :surface, SF.system(), s1)
        k(r) = KF.key_of(KF.declaration(:reader, (); reads = (r,)); inputs = (surface_out = x,))
        at_level = Coupling.AtLevel(measure = Coupling.NoMeasure())
        coarsen(; rule = Coupling.RuleOfSemantics(), measure = Coupling.NoMeasure()) =
            Coupling.Coarsen(rule = rule, measure = measure)
        @test k(KF.reading(:surface_out; operator = at_level)) != k(KF.reading(:surface_out; operator = coarsen()))
        @test k(KF.reading(:surface_out; operator = coarsen())) !=
              k(KF.reading(:surface_out; operator = coarsen(rule = Fields.AreaMean())))
        @test k(KF.reading(:surface_out; operator = coarsen(measure = :primal_cell_area))) !=
              k(KF.reading(:surface_out; operator = coarsen(measure = :dual_area)))
        @test k(KF.reading(:surface_out; lagged = true)) != k(KF.reading(:surface_out; lagged = false))
        @test k(KF.reading(:surface_out; move = true)) != k(KF.reading(:surface_out; move = false))
        @test k(KF.reading(:surface_out; read_level = 1, operator = coarsen())) != k(KF.reading(:surface_out; operator = coarsen()))

        @testset "positive control: two identical reads give one key" begin
            @test k(KF.reading(:surface_out; operator = coarsen(measure = :primal_cell_area))) ==
                  k(KF.reading(:surface_out; operator = coarsen(measure = :primal_cell_area)))
            @test k(KF.reading(:surface_out; lagged = true)) == k(KF.reading(:surface_out; lagged = true))
        end
    end

    @testset "the write's semantics, and its conserved quantities, each move the key" begin
        base = KF.key_of(KF.declaration(:writer, (); writes = (KF.writing(:writer_out),)))
        @test KF.key_of(KF.declaration(:writer, (); writes = (KF.writing(:writer_out; semantics = Fields.Extensive()),))) != base
        @test KF.key_of(KF.declaration(:writer, (); writes = (KF.writing(:writer_out; conserves = (:water,)),))) != base
        @test KF.key_of(KF.declaration(:writer, (); writes = (KF.writing(:writer_out; conserves = (:water, :salt)),))) !=
              KF.key_of(KF.declaration(:writer, (); writes = (KF.writing(:writer_out; conserves = (:water,)),)))

        @testset "positive control: a second write added to the same declaration does not" begin
            second = KF.writing(:other_out; semantics = Fields.Extensive(), conserves = (:mass,))
            @test KF.key_of(KF.declaration(:writer, (); writes = (KF.writing(:writer_out), second))) == base
        end
    end

    @testset "a name derived from printed parameters collides where the key does not" begin
        system = SF.system()
        flipped = KF.replace_at(system, (:planet, :mass, :value), nextfloat)
        derived_name(s) = "planet_mass_" * string(round(Dispositions.value(s.planet.mass); sigdigits = 6))
        @test derived_name(flipped) == derived_name(system)
        @test KF.key(a, :surface, flipped, s1) != KF.key(a, :surface, system, s1)
    end

    @testset "each part of the key moves it, and the commit alone does not" begin
        system = SF.system()
        base = KF.key(a, :surface, system, s1)
        @test KF.key(a, :surface, system, s1; code = KF.code(tree = "4"^40)) != base
        @test KF.key(a, :surface, system, s1; code = KF.code(manifest = "4"^40)) != base
        @test KF.key(a, :surface, system, s1; code = KF.code(julia = v"1.12.8")) != base
        @test KF.key(a, :surface, system, s1; code = KF.code(dirty = true)) != base
        @test KF.key(a, :surface, system, KF.support(2.0)) != base
        @test KF.key(a, :surface, system, s1; operator_version = 2) != base
        @test KF.key(a, :surface, system, s1; interval = Time.Interval(0.0, 1.0)) != base
        @test KF.key(a, :surface, system, s1; profile = KF.profile(Float64; fast_precision = Float32)) != base
        d = KF.declared_declaration(:surface)
        @test KF.key(a, :surface, system, s1; declaration = d) == base
        renamed = KF.declaration(:elsewhere, KF.declared().surface; profile_fields = KF.declared_profile().surface,
                                 writes = (:surface_out,))
        @test KF.key(a, :surface, system, s1; declaration = renamed) != base
        other_quantity = KF.declared_declaration(:surface; writes = (:surface_out, :other_out))
        @test KF.key(a, :surface, system, s1; declaration = other_quantity) == base
        @test KF.key(a, :surface, system, s1; declaration = other_quantity, quantity = :other_out) != base
        bitwise = KF.declared_declaration(:surface; backend = Backends.CPU(bitwise = true))
        @test KF.key(a, :surface, system, s1; declaration = bitwise) != base
        pinned = KF.declared_declaration(:surface; backend = Backends.CPU(8))
        @test KF.key(a, :surface, system, s1; declaration = pinned) == base
        relabelled = KF.profile(Float64; label = :another_label)
        @test KF.key(a, :surface, system, s1; profile = relabelled) == base

        @testset "the commit is a locator and not part of the key" begin
            @test KF.key(a, :surface, system, s1; code = KF.code(commit = "5"^40)) == base
        end
    end

    @testset "the declared order of paths and of input keys reaches no key" begin
        system = SF.system()
        forward = KF.declared_declaration(:orbital)
        backward = KF.declaration(:orbital, reverse(KF.declared().orbital);
                                  profile_fields = KF.declared_profile().orbital)
        @test Provenance.parameter_digest(forward, system) == Provenance.parameter_digest(backward, system)
        @test KF.key(a, :orbital, system, s1; declaration = backward) == KF.key(a, :orbital, system, s1)

        p = KF.fixture_profile(Float64)
        forward_profile = KF.declared_declaration(:surface)
        backward_profile = KF.declared_declaration(:surface; profile_fields = reverse(KF.declared_profile().surface))
        @test Provenance.profile_digest(forward_profile, p) == Provenance.profile_digest(backward_profile, p)
        @test KF.key(a, :surface, system, s1; declaration = backward_profile) == KF.key(a, :surface, system, s1)

        x, y = KF.key(a, :surface, system, s1), KF.key(a, :stellar, system, s1)
        k(inputs) = KF.key_of(KF.declaration(:reader, (); reads = (:surface_out, :stellar_out)); inputs = inputs)
        @test k((surface_out = x, stellar_out = y)) == k((stellar_out = y, surface_out = x))

        @testset "positive control: input keys swapped between names, and a path removed, move the key" begin
            @test k((surface_out = y, stellar_out = x)) != k((surface_out = x, stellar_out = y))
            fewer = KF.declaration(:orbital, KF.declared().orbital[2:end]; profile_fields = KF.declared_profile().orbital)
            @test KF.key(a, :orbital, system, s1; declaration = fewer) != KF.key(a, :orbital, system, s1)
            fewer_profile = KF.declared_declaration(:surface; profile_fields = KF.declared_profile().surface[2:end])
            @test KF.key(a, :surface, system, s1; declaration = fewer_profile) != KF.key(a, :surface, system, s1)
        end

        @testset "an input key moves every key that reads it" begin
            moved_upstream = KF.key(a, :surface, system, s1; operator_version = 2)
            @test k((surface_out = moved_upstream, stellar_out = y)) != k((surface_out = x, stellar_out = y))
        end
    end

    @testset "ArtifactKey refuses what it cannot key" begin
        system = SF.system()
        reader = KF.declaration(:reader, (); reads = (:surface_out,))
        x = KF.key(a, :surface, system, s1)
        given = (code = KF.code(), declaration = reader, system = system, profile = KF.fixture_profile(Float64),
                 inputs = (surface_out = x,), quantity = :reader_out, support = s1, interval = KF.interval(),
                 operator_version = 1)
        k(; kw...) = Provenance.ArtifactKey(; merge(given, values(kw))...)
        @test k() isa Provenance.ArtifactKey
        @test KF.refused(KF.caught(() -> k(inputs = (;))), "surface_out", "no input key")
        @test KF.refused(KF.caught(() -> k(inputs = (surface_out = x, other_out = x))), "other_out", "does not read")
        @test KF.refused(KF.caught(() -> k(inputs = (surface_out = x.digest,))), "surface_out", "not an ArtifactKey")
        @test KF.refused(KF.caught(() -> k(quantity = :surface_out)), "quantity", "no write of surface_out")
        s0 = let l = Mesh.hierarchy(1).levels[2]
            Mesh.Support(1, l, Mesh.geometry(l, Mesh.stencils(l)); kind = :icosahedral_bisection,
                         refinement = (), radius = 1.0, element_type = :Float64, fractions = ())
        end
        @test KF.refused(KF.caught(() -> k(support = s0)), "support", "level 1")
        @test KF.refused(KF.caught(() -> k(operator_version = -1)), "operator_version", "negative")
        for missing_keyword in (:operator_version, :interval, :profile)
            @test KF.refused(KF.caught(() -> Provenance.ArtifactKey(; Base.structdiff(given, NamedTuple{(missing_keyword,)})...)),
                             String(missing_keyword), "missing")
        end
        @test KF.refused(KF.caught(() -> k(interval = (0.0, 1.0))), "interval", "Interval")
        @test KF.refused(KF.caught(() -> k(profile = system)), "profile", "Profile")
        unreachable = KF.declaration(:reader, ((:stars, 2, :mass),); reads = (:surface_out,))
        @test KF.refused(KF.caught(() -> k(declaration = unreachable)), "system_fields", "does not reach")

        @testset "the profile subset refuses the label, a path through no entry, and a profile in another float type" begin
            @test KF.refused(KF.caught(() -> KF.declaration(:reader, (); profile_fields = ((:label,),))),
                             "profile_fields", "reader declares (:label,), which reaches the profile's label")
            for path in ((:components, :land, :ladder), (:components, 1, :ladder), (:components, :, :ladder),
                         (:fast_precision, :x))
                beyond = KF.declaration(:reader, (); reads = (:surface_out,), profile_fields = (path,))
                @test KF.refused(KF.caught(() -> k(declaration = beyond)), "profile_fields",
                                 "reader declares $(path), which does not reach through the profile")
            end
            @test KF.refused(KF.caught(() -> k(profile = KF.fixture_profile(Float32))), "profile",
                             "a profile resolved in Float32 and a system in Float64")

            @testset "positive control: a path to a named entry reaches, and a profile on a system of its float type keys" begin
                named = KF.declaration(:reader, (); reads = (:surface_out,), profile_fields = ((:components, :ocean, :ladder),))
                @test k(declaration = named) isa Provenance.ArtifactKey
                @test k(profile = KF.fixture_profile(Float32), system = SF.system(Float32)) isa Provenance.ArtifactKey
            end
        end
    end

    @testset "a dirty code version refuses to write a keyed artifact and may write a scratch run" begin
        system = SF.system()
        clean = KF.key(a, :surface, system, s1)
        dirty = KF.key(a, :surface, system, s1; code = KF.code(dirty = true))
        @test KF.refused(KF.caught(() -> Provenance.admit(dirty)), "code version", "uncommitted")
        scratch = Provenance.ScratchRun(run = Provenance.mint_run_id(), code = KF.code(dirty = true))
        @test Provenance.admit(scratch) === scratch

        @testset "a clean key resting on a dirty input key is refused" begin
            reader = KF.declaration(:reader, (); reads = (:surface_out,))
            downstream = KF.key_of(reader; inputs = (surface_out = dirty,))
            @test KF.refused(KF.caught(() -> Provenance.admit(downstream)), "code version", "uncommitted")
        end

        @testset "positive control: a clean key is admitted" begin
            @test Provenance.admit(clean) === clean
        end
    end

    @testset "read_code_version reads the commit, the src tree, the manifest and the dirty state" begin
        mktempdir() do root
            KF.init(root)
            mkpath(joinpath(root, "src"))
            write(joinpath(root, "src", "A.jl"), "module A end\n")
            write(joinpath(root, "Manifest.toml"), "# fixture manifest\n")
            write(joinpath(root, "README.md"), "fixture\n")
            KF.commit_all(root)

            v = Provenance.read_code_version(root)
            @test v.commit == KF.git(root, `rev-parse HEAD`)
            @test v.tree == KF.git(root, `rev-parse HEAD:src`)
            @test v.manifest == KF.git(root, `rev-parse HEAD:Manifest.toml`)
            @test v.julia == VERSION
            @test !v.dirty

            write(joinpath(root, "README.md"), "changed outside the code\n")
            @test !Provenance.read_code_version(root).dirty

            write(joinpath(root, "src", "A.jl"), "module A f() = 1 end\n")
            @test Provenance.read_code_version(root).dirty
            KF.git(root, `checkout -- src`)
            @test !Provenance.read_code_version(root).dirty

            write(joinpath(root, "src", "B.jl"), "module B end\n")
            @test Provenance.read_code_version(root).dirty
            rm(joinpath(root, "src", "B.jl"))

            write(joinpath(root, "Manifest.toml"), "# changed manifest\n")
            @test Provenance.read_code_version(root).dirty
            KF.commit_all(root)
            committed = Provenance.read_code_version(root)
            @test !committed.dirty
            @test committed.manifest != v.manifest
            @test committed.tree == v.tree
            @test committed.commit != v.commit
        end

        mktempdir() do root
            @test KF.refused(KF.caught(() -> Provenance.read_code_version(root)), "code version",
                             "rev-parse --is-inside-work-tree failed")
        end

        mktempdir() do root
            KF.init(root)
            write(joinpath(root, "Manifest.toml"), "# fixture manifest\n")
            KF.commit_all(root)
            @test KF.refused(KF.caught(() -> Provenance.read_code_version(root)), "code version", "HEAD:./src")
        end

        @testset "loaded_code_version reads the directory the package was loaded from" begin
            root = pkgdir(Fiddlybits)
            v = Provenance.loaded_code_version()
            @test v.tree == KF.git(root, `rev-parse HEAD:./src`)
            @test v.manifest == KF.git(root, `rev-parse HEAD:./Manifest.toml`)
        end
    end

    @testset "a run id is a version 4 UUID" begin
        r = Provenance.mint_run_id()
        @test UUIDs.uuid_version(r.uuid) == 4
        @test Provenance.mint_run_id() != r
        @test Provenance.RunID(uuid = r.uuid) == r
        @test KF.refused(KF.caught(() -> Provenance.RunID(uuid = UUID("6ba7b810-9dad-11d1-80b4-00c04fd430c8"))),
                         "uuid", "version 1")
        @test KF.refused(KF.caught(() -> Provenance.RunID(uuid = UUID("5c0a1e00-0000-4000-0000-000000000011"))),
                         "uuid", "variant")
    end
end
