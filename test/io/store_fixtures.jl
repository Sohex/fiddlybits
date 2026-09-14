# One recipe for the stores the suites in test/io and test/provenance/store.jl build. Every
# number is a synthetic declaration; none is a real body's.

isdefined(@__MODULE__, :SystemFixtures) ||
    include(joinpath(@__DIR__, "..", "system", "fixtures.jl"))

module StoreFixtures

using Fiddlybits: Provenance, Coupling, Backends, Mesh, Fields, Time, Dimensions, Verdicts, Systems
using UUIDs: UUID
import Zarr
import ..SystemFixtures as SF

"The profile every fixture field is keyed under: its fast fields in `Float64` and every other setting absent."
profile() = Systems.Profile(
    label = :store, system = SF.system(),
    components = Systems.Absent(argument = "the store fixture has no component"),
    radiation = Systems.Absent(argument = "the store fixture has no radiation"),
    fast_precision = Float64,
    slow_tier = Systems.Absent(argument = "the store fixture has no slow tier"),
    memory_ceiling = SF.irreducible(1024, Dimensions.DIMENSIONLESS),
    write_ceiling = SF.irreducible(256, Dimensions.DIMENSIONLESS),
    store_writers = SF.irreducible(4, Dimensions.DIMENSIONLESS),
    settle_interval = SF.irreducible(3600.0, Dimensions.TIME),
    daily_fallback_interval = Systems.Absent(argument = "the store fixture has no vegetation tier"),
    exit_brackets = Systems.Absent(argument = "the store fixture has no loop"))

"The level every fixture field sits at."
level() = 2

"The radius of the fixture sphere."
radius() = 3.0e6

"`(support, level, geometry)` at level `L` on a sphere of radius `r`."
function mesh(L = level(); r = radius())
    l = Mesh.hierarchy(L).levels[L + 1]
    g = Mesh.geometry(l, Mesh.stencils(l))
    s = Mesh.Support(L, l, g; kind = :icosahedral_bisection, refinement = (), radius = r,
                     element_type = :Float64, fractions = ())
    return (support = s, level = l, geometry = g)
end

"A fixture `CodeVersion`, clean; `kw` replaces any keyword."
code(; kw...) = Provenance.CodeVersion(; merge(
    (commit = "1"^40, tree = "2"^40, manifest = "3"^40, julia = v"1.12.7", dirty = false), values(kw))...)

"A declaration named `name` writing `quantity` with `semantics` at `level()`, declaring `system_fields` and `profile_fields`."
declaration(; name = :surface, quantity = :surface_mass, semantics = Fields.Extensive(),
            system_fields = ((:planet, :mass), (:stars, :, :luminosity)),
            profile_fields = ((:fast_precision,), (:memory_ceiling,))) =
    Coupling.Declaration(
        name = name, level = level(), reads = (),
        writes = (Coupling.Write(quantity = quantity, semantics = semantics, conserves = ()),),
        stocks = (), system_fields = system_fields, profile_fields = profile_fields, backend = Backends.CPU())

"The interval every fixture field is placed over."
interval() = Time.TimeSupport(Time.IntervalMean(), Time.Interval(0.0, 3600.0))

"A field on `support` written by `writer` in `run` over `data`; `kw` replaces any keyword of `Fields.Field`."
field(support, run::Provenance.RunID, data; writer = :surface, kw...) = Fields.Field(; merge(
    (semantics = Fields.Extensive(), dimension = Dimensions.MASS, data = data, support = support,
     time = interval(), origin = Fields.unstamped(writer, run.uuid)), values(kw))...)

"A closed `Ledger{:mass}` over the cells of `level()`."
closed_ledger() = Fields.Ledger{:mass}(Float64, Mesh.ncells(level()), 1.0, 5.0, 5.0, 0.0; reservoir = false)

"A `Ledger{:mass}` whose residual is outside its tolerance."
open_ledger() = Fields.Ledger{:mass}(Float64, Mesh.ncells(level()), 1.0, 5.0, 6.0, 0.0; reservoir = false)

"""
    seeded(root)

A store at `root` holding the fixture support at chunk level one and the record of a new
run under the clean fixture code: `(store, run, mesh)`.
"""
function seeded(root)
    store = Provenance.Store(root = root)
    m = mesh()
    Provenance.put_support!(store; support = m.support, level = m.level, geometry = m.geometry, chunk_level = 1)
    run = Provenance.mint_run_id()
    Provenance.open_run!(store; run = run, code = code(), system = SF.system())
    return store, run, m
end

"`Provenance.put_field!` under `run` of `f` with the fixture keywords; `kw` replaces any."
put(store, run, f; kw...) = Provenance.put_field!(store, run; merge(
    (code = code(), declaration = declaration(), system = SF.system(), profile = profile(), inputs = (;),
     quantity = :surface_mass,
     operator_version = 1, field = f, ledgers = (closed_ledger(),), chunk_level = 1,
     values = Provenance.Amounts(), interval = Time.interval(interval())), values(kw))...)

"`Provenance.read_field` of `key` with the fixture keywords for `support`; `kw` replaces any."
read_back(store, key, support; kw...) = Provenance.read_field(store, key; merge(
    (quantity = :surface_mass, semantics = Fields.Extensive(), dimension = Dimensions.MASS, time = interval(),
     support = support, backend = Backends.CPU()), values(kw))...)

"The Zarr array directory of `quantity` in the artifact `key` of `store`."
array_path(store, key, quantity = :surface_mass) =
    joinpath(Provenance.object_directory(store, key), String(quantity))

"Replaces the attributes of the Zarr array at `path` by `f` of them."
function edit_attributes!(f, path)
    s = Zarr.DirectoryStore(path)
    v = Zarr.ZarrFormat(2)
    Zarr.writeattrs(v, s, "", f(Zarr.getattrs(v, s, "")))
    return nothing
end

"Replaces every value of the Zarr array at `path` by `f` of the whole array, attributes kept."
function edit_values!(f, path)
    z = Zarr.zopen(path, "w")
    x = z[ntuple(_ -> Colon(), ndims(z))...]
    z[axes(x)...] = f(x)
    return nothing
end

"`f()`; the exception it raises, or `nothing`."
caught(f) = try
    f()
    nothing
catch err
    err
end

"`true` when `e` is a `Verdicts.Refusal` of `quantity` whose reason contains `text`."
refused(e, quantity, text) = e isa Verdicts.Refusal && e.quantity == quantity && occursin(text, e.reason)

end # module StoreFixtures
