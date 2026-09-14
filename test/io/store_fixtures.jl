# One recipe for the stores the suites in test/io and test/provenance/store.jl build. Every
# number is a synthetic declaration; none is a real body's.

isdefined(@__MODULE__, :SystemFixtures) ||
    include(joinpath(@__DIR__, "..", "system", "fixtures.jl"))

module StoreFixtures

using Fiddlybits: Provenance, Coupling, Backends, Mesh, Fields, Time, Dimensions, Verdicts, Systems
using UUIDs: UUID
import Zarr
import ..SystemFixtures as SF

"""
The profile every fixture field is keyed under: its fast fields in `Float64`, the writer's
ceiling `write_ceiling` bytes and its disk tasks `store_writers`, and every other setting
absent. Neither writer setting is a path the fixture declaration keys on.
"""
profile(; write_ceiling = 256, store_writers = 4) = Systems.Profile(
    label = :store, system = SF.system(),
    components = Systems.Absent(argument = "the store fixture has no component"),
    radiation = Systems.Absent(argument = "the store fixture has no radiation"),
    fast_precision = Float64,
    slow_tier = Systems.Absent(argument = "the store fixture has no slow tier"),
    memory_ceiling = SF.irreducible(1024, Dimensions.DIMENSIONLESS),
    write_ceiling = SF.irreducible(write_ceiling, Dimensions.DIMENSIONLESS),
    store_writers = SF.irreducible(store_writers, Dimensions.DIMENSIONLESS),
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
    seeded(root; run)

A store at `root` holding the fixture support at chunk level one and the record of the run
`run`, a new one unless given, under the clean fixture code: `(store, run, mesh)`.
"""
function seeded(root; run = Provenance.mint_run_id())
    store = Provenance.Store(root = root)
    m = mesh()
    Provenance.put_support!(store; support = m.support, level = m.level, geometry = m.geometry, chunk_level = 1)
    Provenance.open_run!(store; run = run, code = code(), system = SF.system())
    return store, run, m
end

"The keywords `put` and `submit` give `put_field!` and `submit!` for `f`; the `NamedTuple` `kw` replaces any."
put_keywords(f, kw::NamedTuple) = merge(
    (code = code(), declaration = declaration(), system = SF.system(), profile = profile(), inputs = (;),
     quantity = :surface_mass,
     operator_version = 1, field = f, ledgers = (closed_ledger(),), chunk_level = 1,
     values = Provenance.Amounts(), interval = Time.interval(interval())), kw)

"`Provenance.put_field!` under `run` of `f` with the fixture keywords; `kw` replaces any."
put(store, run, f; kw...) = Provenance.put_field!(store, run; put_keywords(f, values(kw))...)

"`Provenance.submit!` to `writer` under `run` of `f` with the fixture keywords; `kw` replaces any."
submit(writer, run, f; kw...) = Provenance.submit!(writer, run; put_keywords(f, values(kw))...)

"Each file under `root` by its path relative to `root`, to its bytes."
function tree(root)
    files = Dict{String,Vector{UInt8}}()
    for (dir, _, names) in walkdir(root), name in names
        path = joinpath(dir, name)
        files[relpath(path, root)] = read(path)
    end
    return files
end

"Every path under `root` whose name begins with `Provenance.STAGING_PREFIX`."
staging_left(root) = [joinpath(dir, name) for (dir, dirs, names) in walkdir(root)
                      for name in vcat(dirs, names) if startswith(name, Provenance.STAGING_PREFIX)]

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
