# One recipe for the fixture components and profile the suites in test/provenance and
# test/coupling build, so the key stability arms and coupling.declared_profile_graph read
# one assembly. Every number is a synthetic declaration; none is a real body's.

isdefined(@__MODULE__, :SystemFixtures) ||
    include(joinpath(@__DIR__, "..", "system", "fixtures.jl"))

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
     write_ceiling = SF.irreducible(256, ONE),
     store_writers = SF.irreducible(4, ONE),
     settle_interval = SF.irreducible(T(3600), TIME),
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
