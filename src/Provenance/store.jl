# The content-addressed store: docs/plans/fiddlybits-52v.6-provenance.md, section "The
# store"; decision 0010; REQ-TER-002; docs/imports/zarr.md. Under a store's root:
#
#   objects/<key digest>/manifest.toml          the TOML manifest of a keyed artifact
#   objects/<key digest>/<quantity>/            its Zarr version 2 array
#   scratch/<run uuid>/<key digest>/            the same, written by a ScratchRun
#   runs/<run uuid>/run.toml                    a run's code version and system
#   supports/<support digest>/manifest.toml     a support's declaration and digests
#   supports/<support digest>/cell_area/        its cell areas at its radius
#
# Every digest is written as lowercase hexadecimal. A directory is written under a
# staging name beside its place and renamed into it once complete.

using TOML
using UUIDs: UUID
import Zarr
using ..Verdicts: refuse
using ..Backends: Backend, CPU, LAYOUT, on
using ..Systems: Systems, System, Profile, Checked, read_keywords, require_type
using ..Mesh: Mesh
using ..Fields: Fields
using ..Time: Time
using ..Dimensions: Dimensions, Dim
using ..Coupling: Coupling, Declaration

# ---------------------------------------------------------------- names

"The directory under a store's root holding keyed artifacts."
const OBJECTS = "objects"

"The directory under a store's root holding the artifacts of scratch runs."
const SCRATCH = "scratch"

"The directory under a store's root holding run records."
const RUNS = "runs"

"The directory under a store's root holding supports."
const SUPPORTS = "supports"

"The file name of an artifact's or a support's manifest."
const MANIFEST = "manifest.toml"

"The file name of a run's record."
const RUN_RECORD = "run.toml"

"The kind a field artifact's manifest names."
const FIELD_KIND = "field"

"The attributes every stored array carries; `open_array` refuses an array missing any."
const REQUIRED_ATTRIBUTES = ("support_id", "semantics", "time_semantics", "dimension", "owner", "interval")

"The attribute naming an array's axes in the order Zarr version 2 lays them out on disk."
const AXES_ATTRIBUTE = "_ARRAY_DIMENSIONS"

"The keys every artifact manifest holds; a read refuses a manifest missing any."
const MANIFEST_KEYS = ("kind", "key", "quantity", "owner", "run", "support", "operator_version",
                       "parameter_digest", "profile_digest", "code", "inputs", "parameters", "profile",
                       "stocks", "arrays")

"The keys every array table of a manifest holds; a read refuses a table missing any."
const ARRAY_KEYS = ("attributes", "element_type", "size", "axes", "chunk_level", "cells_per_chunk",
                    "compressor", "values", "ledgers")

"The element types an array is stored in."
const STORED_ELEMENT_TYPES = (Float64, Float32, Int64, Int32, Int16, Int8, UInt64, UInt32, UInt16,
                              UInt8, Bool)

"The name a manifest gives the compressor `compressor()` returns."
const COMPRESSOR_ID = "blosc"

"The compressor every stored array is written with."
compressor() = Zarr.BloscCompressor()

"The name of a support's cell-area array."
const CELL_AREA = "cell_area"

"The owner a support's cell-area array names."
const GEOMETRY_OWNER = :mesh_geometry

# ---------------------------------------------------------------- the store

"""
    Store(; root)

A store at the absolute directory `root`, created when absent. Refuses a `root` that is
not an absolute path, and one that exists and is not a directory.
"""
struct Store
    root::String

    Store(::Checked, r) = new(r)
end

function Store(; kwargs...)
    site = "Provenance.Store"
    k, _ = read_keywords(site, values(kwargs), (:root,), ())
    root = require_type("root", site, k.root, String)
    isabspath(root) || refuse("root", site, "$(repr(root)) is not an absolute path")
    ispath(root) && !isdir(root) && refuse("root", site, "$(root) exists and is not a directory")
    mkpath(root)
    return Store(Checked(), root)
end

"The lowercase hexadecimal digits of the digest `d`."
hex(d::NTuple{32,UInt8}) = bytes2hex(collect(d))

"""
    digest_of(quantity, site, text)

The `NTuple{32,UInt8}` the hexadecimal `text` spells; refuses at `site`, naming `quantity`,
anything else.
"""
function digest_of(quantity::AbstractString, site::AbstractString, text)
    text isa String || refuse(quantity, site, "a $(typeof(text)) where a hexadecimal digest is required")
    bytes = try
        hex2bytes(text)
    catch err
        err isa ArgumentError || rethrow()
        refuse(quantity, site, "$(repr(text)) is not hexadecimal")
    end
    length(bytes) == 32 || refuse(quantity, site, "$(repr(text)) spells $(length(bytes)) bytes, not 32")
    return NTuple{32,UInt8}(bytes)
end

"The directory of the keyed artifact `key` in `store`."
object_directory(store::Store, key::ArtifactKey) = joinpath(store.root, OBJECTS, hex(key.digest))

"The directory of the artifact `key` the scratch run `run` wrote in `store`."
scratch_directory(store::Store, run::RunID, key::ArtifactKey) =
    joinpath(store.root, SCRATCH, string(run.uuid), hex(key.digest))

"The directory of the record of the run `run` in `store`."
run_directory(store::Store, run::RunID) = joinpath(store.root, RUNS, string(run.uuid))

"The directory of `support` in `store`."
support_directory(store::Store, support::Mesh.Support) = joinpath(store.root, SUPPORTS, hex(support.digest))

"""
    write_directory!(f, dir, site)

Calls `f` on a new empty staging directory beside `dir`, then renames it to `dir`. Removes
the staging directory and rethrows when `f` throws. Refuses at `site` when `dir` exists by
the time of the rename.
"""
function write_directory!(f, dir::AbstractString, site::AbstractString)
    parent = dirname(dir)
    mkpath(parent)
    staging = mktempdir(parent; prefix = ".staging-", cleanup = false)
    try
        f(staging)
    catch
        rm(staging; recursive = true, force = true)
        rethrow()
    end
    if ispath(dir)
        rm(staging; recursive = true, force = true)
        refuse("artifact", site, "$(dir) was written while this write was staged")
    end
    mv(staging, dir)
    return dir
end

"Writes the dictionary `d` to `path` as TOML, keys sorted."
write_toml(path::AbstractString, d::AbstractDict) = open(io -> TOML.print(io, d; sorted = true), path, "w")

# ---------------------------------------------------------------- record values

"The site every refusal of `record_value` names."
const RECORD_SITE = "Provenance.record_value"

"""
    record_value(x)

The TOML value a record holds for `x`: a `Bool` as itself; an integer of at most 32 bits,
signed or unsigned, as an `Int64`; a `UInt64` as itself, which `TOML.print` writes as an
unsigned hexadecimal literal and `TOML.parse` reads back as a `UInt64`; a `Float16`,
`Float32` or `Float64` as the `Float64` of the same value; a `Symbol` as its name; a
`String` as itself, refusing one that is not valid UTF-8; a `VersionNumber`, a `UUID` or a
type as its `string`; a `Tuple` as an array of its elements' values; and as a table with
`type`, the `string` of its type, each of `nothing` (no other key), an `Array` (`size` and
`values`, in column-major order), a `NamedTuple` and an immutable struct (`fields`, a
table from each field name to its value). Refuses any other value.
"""
record_value(x::Bool) = x
record_value(x::Union{Int8,Int16,Int32,Int64,UInt8,UInt16,UInt32}) = Int64(x)
record_value(x::UInt64) = x
record_value(x::Union{Float16,Float32,Float64}) = Float64(x)
record_value(x::Symbol) = String(x)

function record_value(x::String)
    isvalid(x) || refuse("record", RECORD_SITE, "$(repr(x)) is not valid UTF-8")
    return x
end

record_value(x::Union{VersionNumber,UUID,Type}) = string(x)
record_value(::Nothing) = Dict{String,Any}("type" => "Nothing")
record_value(x::Tuple) = Any[record_value(y) for y in x]

function record_value(x::Array)
    for i in eachindex(x)
        isassigned(x, i) || refuse("record", RECORD_SITE, "an $(typeof(x)) holds an unassigned element")
    end
    return Dict{String,Any}("type" => string(typeof(x)), "size" => collect(size(x)),
                            "values" => Any[record_value(y) for y in x])
end

record_value(x::NamedTuple) =
    Dict{String,Any}("type" => "NamedTuple",
                     "fields" => Dict{String,Any}(String(n) => record_value(x[n]) for n in keys(x)))

function record_value(x)
    T = typeof(x)
    (x isa Function || x isa Module || ismutable(x) || !isstructtype(T)) &&
        refuse("record", RECORD_SITE, "a value of type $(T) has no record")
    fields = Dict{String,Any}()
    for n in fieldnames(T)
        isdefined(x, n) || refuse("record", RECORD_SITE, "a $(T) holds no value in its field $(n)")
        fields[String(n)] = record_value(getfield(x, n))
    end
    return Dict{String,Any}("type" => string(T), "fields" => fields)
end

"The record of the code version `code`."
code_record(code::CodeVersion) =
    Dict{String,Any}("commit" => code.commit, "tree" => code.tree, "manifest" => code.manifest,
                     "julia" => string(code.julia), "dirty" => code.dirty)

"The record of the path `path`: each step's `record_value`, and `:` as the string `\":\"`."
path_record(path::Tuple) = Any[step isa Colon ? ":" : record_value(step) for step in path]

"""
    subset_records(root, paths)

One table per path of `paths`, in declared order: `declared`, the path's record, and
`values`, one table per colon-free path `expand_path` gives for it from `root` with `path`
and `value`, the `record_value` of what the path reaches in `root`.
"""
subset_records(root, paths::Tuple) =
    [Dict{String,Any}("declared" => path_record(p),
                      "values" => [Dict{String,Any}("path" => path_record(q),
                                                    "value" => record_value(Systems.at_path(root, q)))
                                   for q in expand_path(root, p)])
     for p in paths]

"`subset_records` of `system` at the paths `declaration.system_fields` names."
parameter_records(declaration::Declaration, system::System) =
    subset_records(system, declaration.system_fields)

"`subset_records` of the `Systems.Profile` `profile` at the paths `declaration.profile_fields` names."
profile_records(declaration::Declaration, profile::Profile) =
    subset_records(profile, declaration.profile_fields)

# ---------------------------------------------------------------- runs

"""
    open_run!(store; run, code, system)

Writes the record of the run `run`: `runs/<uuid>/run.toml`, holding `run`, the uuid;
`code`, the `code_record` of the `CodeVersion` `code`; and `system`, the `record_value` of
the `System` `system`. Returns the run's directory. Every keyword is required. Refuses a
run the store already records.
"""
function open_run!(store::Store; kwargs...)
    site = "Provenance.open_run!"
    k, _ = read_keywords(site, values(kwargs), (:run, :code, :system), ())
    run = require_type("run", site, k.run, RunID)
    code = require_type("code", site, k.code, CodeVersion)
    system = require_type("system", site, k.system, System)
    dir = run_directory(store, run)
    ispath(dir) && refuse("run", site, "the run $(run.uuid) is already recorded at $(dir)")
    record = Dict{String,Any}("run" => string(run.uuid), "code" => code_record(code),
                              "system" => record_value(system))
    return write_directory!(staging -> write_toml(joinpath(staging, RUN_RECORD), record), dir, site)
end

"""
    require_run(store, run, code, site)

Refuses at `site` unless `store` records the run `run` under the code version `code`.
"""
function require_run(store::Store, run::RunID, code::CodeVersion, site::AbstractString)
    path = joinpath(run_directory(store, run), RUN_RECORD)
    isfile(path) || refuse("run", site, "the store records no run $(run.uuid); open_run! writes its record")
    TOML.parsefile(path)["code"] == code_record(code) || refuse(
        "code", site, "the run $(run.uuid) is recorded under another code version than the one given")
    return nothing
end

# ---------------------------------------------------------------- array attributes

"""
    instant_record(t)

The record of the `SimTime` `t`: `precision`, the name of its float type, and `whole` and
`fraction`, the pair `Time.encode` gives, the fraction as the `Float64` of its value.
"""
function instant_record(t::Time.SimTime{T}) where {T}
    whole, fraction = Time.encode(t)
    return Dict{String,Any}("precision" => string(T), "whole" => whole, "fraction" => Float64(fraction))
end

"""
    placement_record(time)

The record of where the `Time.TimeSupport` `time` sits on the clock, by
`Time.time_support_kind` of its semantics: `placement = "none"`; `placement = "instant"`
with `t`; or `placement = "interval"` with `t0` and `t1`; each instant an `instant_record`.
"""
function placement_record(time::Time.TimeSupport)
    kind = Time.time_support_kind(Time.semantics(time))
    kind === :none && return Dict{String,Any}("placement" => "none")
    kind === :instant && return Dict{String,Any}("placement" => "instant", "t" => instant_record(Time.instant(time)))
    span = Time.interval(time)
    return Dict{String,Any}("placement" => "interval", "t0" => instant_record(span.t0),
                            "t1" => instant_record(span.t1))
end

"""
    array_attributes(; support, semantics, time, dimension, owner)

The six `REQUIRED_ATTRIBUTES` of an array: `support_id`, the hexadecimal digest of
`support`; `semantics`, `Fields.type_name` of the type of `semantics`; `time_semantics`, the
name of the type of `time`'s semantics; `dimension`, a table from each name of
`Dimensions.BASE_DIMENSIONS` to its exponent in `dimension`; `owner`, the name `owner`;
and `interval`, the `placement_record` of `time`. The one builder of the attributes a write
stores and a read compares against.
"""
array_attributes(; support::Mesh.Support, semantics::Fields.Semantics, time::Time.TimeSupport,
                 dimension::Dim, owner::Symbol) =
    Dict{String,Any}(
        "support_id" => hex(support.digest),
        "semantics" => Fields.type_name(typeof(semantics)),
        "time_semantics" => String(nameof(typeof(Time.semantics(time)))),
        "dimension" => Dict{String,Any}(String(n) => e for (n, e) in
                                        zip(Dimensions.BASE_DIMENSIONS, Dimensions.exponents(dimension))),
        "owner" => String(owner),
        "interval" => placement_record(time))

"The attributes of `support`'s cell-area array."
cell_area_attributes(support::Mesh.Support) =
    array_attributes(support = support, semantics = Fields.Extensive(),
                     time = Time.TimeSupport(Time.Static()),
                     dimension = Dimensions.LENGTH * Dimensions.LENGTH, owner = GEOMETRY_OWNER)

# ---------------------------------------------------------------- values and chunks

"""
    Amounts()

The values of a stored array are held on disk as they are held in memory.
"""
struct Amounts end

"""
    CellIds(; level)

The values of a stored array are cells of hierarchy level `level`: 1-based memory indices in
memory, and on disk the 0-based value of the `Mesh.CellId` `Mesh.disk_id` gives for each,
read back through `Mesh.memory_index`. Refuses a `level` that is not a non-negative integer.
"""
struct CellIds
    level::Int

    CellIds(::Checked, l) = new(l)
end

function CellIds(; kwargs...)
    site = "Provenance.CellIds"
    k, _ = read_keywords(site, values(kwargs), (:level,), ())
    level = k.level
    (level isa Integer && !(level isa Bool)) || refuse("level", site, "a $(typeof(level)) where an Integer is required")
    level >= 0 || refuse("level", site, "a level of $(level) is not a refinement depth")
    return CellIds(Checked(), Int(level))
end

"The record of what an array's values are."
values_record(::Amounts) = Dict{String,Any}("form" => "amounts")
values_record(c::CellIds) = Dict{String,Any}("form" => "cell_ids", "level" => c.level)

"""
    values_of(site, record)

The `Amounts` or `CellIds` `record` names; refuses at `site` any other record.
"""
function values_of(site::AbstractString, record)
    record isa AbstractDict && haskey(record, "form") ||
        refuse("values", site, "$(repr(record)) names no form of values")
    record["form"] == "amounts" && return Amounts()
    record["form"] == "cell_ids" && haskey(record, "level") && return CellIds(level = record["level"])
    refuse("values", site, "$(repr(record)) is neither amounts nor cell ids at a level")
end

"Refuses at `site` an element type `T` of cell ids that is not an integer type other than `Bool`."
require_cell_type(site, T) = (T <: Integer && T !== Bool) ||
    refuse("values", site, "cell ids held in a $(T) array, and cell ids are integers")

"""
    to_disk(values, host, site)

The array written to disk for the host array `host` holding `values`: `host` itself for
`Amounts`; for `CellIds`, each entry `i` replaced by `Mesh.disk_id(i).value`, refusing at
`site` an element type that is not an integer and an entry outside the cells of the level.
"""
to_disk(::Amounts, host::AbstractArray, site::AbstractString) = host

function to_disk(c::CellIds, host::AbstractArray, site::AbstractString)
    require_cell_type(site, eltype(host))
    n = Mesh.ncells(c.level)
    disk = similar(host)
    for i in eachindex(host)
        1 <= host[i] <= n || refuse("values", site,
                                    "entry $(i) holds $(host[i]), outside the $(n) cells of level $(c.level)")
        disk[i] = Mesh.disk_id(host[i]).value
    end
    return disk
end

"""
    from_disk(values, disk, site)

The memory array for the array `disk` read from disk holding `values`: `disk` itself for
`Amounts`; for `CellIds`, each entry `v` replaced by `Mesh.memory_index(Mesh.CellId(v))`,
refusing at `site` an element type that is not an integer and an entry outside the 0-based
cells of the level.
"""
from_disk(::Amounts, disk::AbstractArray, site::AbstractString) = disk

function from_disk(c::CellIds, disk::AbstractArray, site::AbstractString)
    require_cell_type(site, eltype(disk))
    n = Mesh.ncells(c.level)
    memory = similar(disk)
    for i in eachindex(disk)
        0 <= disk[i] < n || refuse("values", site,
                                   "entry $(i) holds $(disk[i]) on disk, outside the 0-based $(n) cells of level $(c.level)")
        memory[i] = Mesh.memory_index(Mesh.CellId(disk[i]))
    end
    return memory
end

"""
    require_chunk_level(site, x, level)

`x` as an `Int` when it is an integer in `0:level`; refuses at `site` otherwise.
"""
function require_chunk_level(site::AbstractString, x, level::Integer)
    (x isa Integer && !(x isa Bool)) || refuse("chunk_level", site, "a $(typeof(x)) where an Integer is required")
    0 <= x <= level || refuse("chunk_level", site, "a chunk at level $(x), and the array's cells are at level $(level)")
    return Int(x)
end

"The cells of level `level` in one chunk at the coarse level `chunk_level`: the descendants of one coarse cell."
cells_per_chunk(level::Integer, chunk_level::Integer) = div(Mesh.ncells(level), Mesh.ncells(chunk_level))

"""
    require_host_array(site, host, level)

Refuses at `site` an array whose element type is not one of `STORED_ELEMENT_TYPES`, which has
more axes than `Backends.LAYOUT` names, or whose cell axis does not hold the cells of `level`.
"""
function require_host_array(site::AbstractString, host::AbstractArray, level::Integer)
    eltype(host) in STORED_ELEMENT_TYPES || refuse(
        "element type", site, "$(eltype(host)) is not one of $(join(STORED_ELEMENT_TYPES, ", "))")
    ndims(host) <= length(LAYOUT) || refuse(
        "axes", site, "an array of $(ndims(host)) axes, and Backends.LAYOUT names $(length(LAYOUT))")
    size(host, 1) == Mesh.ncells(level) || refuse(
        "cells", site, "the cell axis holds $(size(host, 1)) cells, and level $(level) has $(Mesh.ncells(level))")
    return nothing
end

"The names of the axes of an array of `n` axes, in memory order, from `Backends.LAYOUT`."
axis_names(n::Integer) = [String(LAYOUT[d]) for d in 1:n]

"""
    write_array!(path, disk, attributes, per_chunk)

Writes `disk` as a new Zarr version 2 array at `path`: chunks of `per_chunk` cells along the
cell axis and whole along every other, no fill value, compressed by `compressor()`, with
`attributes` and `AXES_ATTRIBUTE` naming its axes in on-disk order.
"""
function write_array!(path::AbstractString, disk::AbstractArray, attributes::Dict{String,Any},
                      per_chunk::Integer)
    attrs = merge(attributes, Dict{String,Any}(AXES_ATTRIBUTE => reverse(axis_names(ndims(disk)))))
    z = Zarr.zcreate(eltype(disk), Zarr.DirectoryStore(path), size(disk)...;
                     zarr_format = 2, chunks = (per_chunk, size(disk)[2:end]...), fill_value = nothing,
                     compressor = compressor(), attrs = attrs)
    z[axes(disk)...] = disk
    return nothing
end

"""
    array_table(; attributes, disk, chunk_level, per_chunk, values, ledgers)

The manifest's table of one array: `attributes` as written, `element_type`, `size` and
`axes` in memory order, `chunk_level`, `cells_per_chunk`, `compressor`, the `values_record`
of `values`, and the ledger records `ledgers`.
"""
array_table(; attributes, disk, chunk_level, per_chunk, values, ledgers) =
    Dict{String,Any}("attributes" => attributes, "element_type" => string(eltype(disk)),
                     "size" => collect(size(disk)), "axes" => axis_names(ndims(disk)),
                     "chunk_level" => chunk_level, "cells_per_chunk" => per_chunk,
                     "compressor" => COMPRESSOR_ID, "values" => values_record(values),
                     "ledgers" => ledgers)

"""
    require_keys(site, what, d, keys)

Refuses at `site`, naming every absent key, a dictionary `d` read from `what` that lacks
any of `keys`.
"""
function require_keys(site::AbstractString, what::AbstractString, d, keys)
    d isa AbstractDict || refuse(what, site, "$(what) is a $(typeof(d)), not a table")
    absent = [k for k in keys if !haskey(d, k)]
    isempty(absent) || refuse(join(absent, ", "), site, "$(what) holds no $(join(absent, ", "))")
    return nothing
end

"""
    open_array(path, expected, site)

The Zarr array at `path`. Refuses at `site`, when there is no Zarr version 2 array there;
naming every absent attribute, when it lacks any of `REQUIRED_ATTRIBUTES`; and naming the
attribute, when one differs from `expected[name]`.
"""
function open_array(path::AbstractString, expected::Dict{String,Any}, site::AbstractString)
    isfile(joinpath(path, ".zarray")) || refuse("array", site, "there is no Zarr version 2 array at $(path)")
    z = Zarr.zopen(path, "r")
    absent = [a for a in REQUIRED_ATTRIBUTES if !haskey(z.attrs, a)]
    isempty(absent) || refuse(
        join(absent, ", "), site,
        "the array at $(path) carries no $(join(absent, ", ")) attribute, and every stored array " *
        "carries $(join(REQUIRED_ATTRIBUTES, ", "))")
    for a in REQUIRED_ATTRIBUTES
        z.attrs[a] == expected[a] || refuse(
            a, site, "the array at $(path) declares $(a) $(repr(z.attrs[a])), and $(repr(expected[a])) is read")
    end
    return z
end

"""
    read_array(z, table, path, site)

The whole of the Zarr array `z` at `path` as an `Array`, after refusing at `site` an element
type, size, chunk shape or compressor other than the manifest table `table` names, and any
chunk absent from the store.
"""
function read_array(z, table::AbstractDict, path::AbstractString, site::AbstractString)
    string(eltype(z)) == table["element_type"] || refuse(
        "element type", site, "the array at $(path) holds $(eltype(z)), and its manifest names $(table["element_type"])")
    shape = collect(size(z))
    shape == table["size"] || refuse(
        "size", site, "the array at $(path) has size $(shape), and its manifest names $(table["size"])")
    chunks = (table["cells_per_chunk"], shape[2:end]...)
    collect(z.metadata.chunks) == collect(chunks) || refuse(
        "chunks", site, "the array at $(path) is chunked $(z.metadata.chunks), and its manifest names $(chunks)")
    (table["compressor"] == COMPRESSOR_ID && z.metadata.compressor isa typeof(compressor())) || refuse(
        "compressor", site, "the array at $(path) is compressed by $(typeof(z.metadata.compressor)), " *
        "and its manifest names $(repr(table["compressor"]))")
    for ci in Zarr.chunkindices(z)
        Zarr.store_isinitialized(z.storage, z.path, ci, z.metadata.chunk_key_encoding) || refuse(
            "chunk", site, "the array at $(path) holds no chunk $(Tuple(ci))")
    end
    return z[ntuple(_ -> Colon(), ndims(z))...]
end

# ---------------------------------------------------------------- supports

"""
    put_support!(store; support, level, geometry, chunk_level)

Holds `support` in `store` once: `supports/<digest>/manifest.toml`, naming `support`,
`kind`, `level`, `radius`, `element_type`, `constructor_version` and every digest the
`Mesh.Support` carries, and the array `cell_area`, `geometry`'s cell areas at the support's
radius through `Mesh.at_radius`, chunked at `chunk_level`. Returns the support's directory,
writing nothing when `store` already holds it. Every keyword is required. Refuses a
`level` whose coordinates, and a `geometry` whose measures at the radius, are not the ones
`support` covers.
"""
function put_support!(store::Store; kwargs...)
    site = "Provenance.put_support!"
    k, _ = read_keywords(site, values(kwargs), (:support, :level, :geometry, :chunk_level), ())
    support = require_type("support", site, k.support, Mesh.Support)
    level = require_type("level", site, k.level, Mesh.Level)
    geometry = require_type("geometry", site, k.geometry, Mesh.Geometry)
    Mesh.digest_coordinates(level.vertices) == support.coordinate_digest || refuse(
        "level", site, "the level's coordinates are not the ones support $(hex(support.digest)) covers")
    Mesh.digest_measures(geometry, support.radius) == support.measure_digest || refuse(
        "geometry", site, "the geometry's measures at radius $(support.radius) are not the ones " *
        "support $(hex(support.digest)) covers")
    chunk_level = require_chunk_level(site, k.chunk_level, support.level)
    dir = support_directory(store, support)
    isdir(dir) && return dir
    area = [Mesh.at_radius(a, support.radius, 2) for a in geometry.cell_area]
    require_host_array(site, area, support.level)
    per_chunk = cells_per_chunk(support.level, chunk_level)
    attributes = cell_area_attributes(support)
    manifest = Dict{String,Any}(
        "support" => hex(support.digest), "kind" => String(support.kind), "level" => support.level,
        "radius" => support.radius, "element_type" => String(support.element_type),
        "constructor_version" => support.constructor_version,
        "refinement_digest" => hex(support.refinement_digest),
        "coordinate_digest" => hex(support.coordinate_digest),
        "measure_digest" => hex(support.measure_digest),
        "fraction_digest" => hex(support.fraction_digest),
        "lineage_digest" => hex(support.lineage_digest),
        "arrays" => Dict{String,Any}(CELL_AREA => array_table(
            attributes = attributes, disk = area, chunk_level = chunk_level, per_chunk = per_chunk,
            values = Amounts(), ledgers = Any[])))
    return write_directory!(dir, site) do staging
        write_array!(joinpath(staging, CELL_AREA), area, attributes, per_chunk)
        write_toml(joinpath(staging, MANIFEST), manifest)
    end
end

"""
    read_cell_area(store; support, backend)

The cell areas `store` holds for `support`, on `backend`. Every keyword is required. Refuses
a support the store does not hold, and whatever `open_array` and `read_array` refuse.
"""
function read_cell_area(store::Store; kwargs...)
    site = "Provenance.read_cell_area"
    k, _ = read_keywords(site, values(kwargs), (:support, :backend), ())
    support = require_type("support", site, k.support, Mesh.Support)
    backend = require_type("backend", site, k.backend, Backend)
    dir = support_directory(store, support)
    path = joinpath(dir, MANIFEST)
    isfile(path) || refuse("support", site, "the store holds no support $(hex(support.digest))")
    manifest = TOML.parsefile(path)
    require_keys(site, path, manifest, ("arrays",))
    require_keys(site, "the arrays of $(path)", manifest["arrays"], (CELL_AREA,))
    table = manifest["arrays"][CELL_AREA]
    require_keys(site, "the $(CELL_AREA) table of $(path)", table, ARRAY_KEYS)
    array = joinpath(dir, CELL_AREA)
    z = open_array(array, cell_area_attributes(support), site)
    return on(read_array(z, table, array, site), backend)
end

# ---------------------------------------------------------------- ledgers

"""
    first_open(ledger)

`nothing` when `ledger` is closed, and otherwise `(where, l)`: `l` the first open `Ledger`,
and `where` the class and column it balances, empty for a lone `Ledger`.
"""
first_open(l::Fields.Ledger) = Fields.closed(l) ? nothing : ("", l)

function first_open(c::Fields.ColumnLedgers)
    ledgers = Fields.ledgers(c)
    for idx in CartesianIndices(ledgers)
        found = first_open(ledgers[idx])
        found === nothing || return ("column $(Tuple(idx)) " * found[1], found[2])
    end
    return nothing
end

function first_open(c::Fields.ClassLedgers)
    for (class, l) in zip(Fields.classes(c), Fields.ledgers(c))
        found = first_open(l)
        found === nothing || return ("class $(repr(class)) " * found[1], found[2])
    end
    return nothing
end

"""
    ledger_record(l)

The record of the ledger form `l`: `form`, and for a `Ledger` its `quantity`, `residual`,
`tolerance` and `inventory`, the `record_value` of its losses; for a `ColumnLedgers` its
`quantity`, `size` and `columns` in column-major order; for a `ClassLedgers` its `quantity`,
`classes` by `repr` and `ledgers`; and for a `NotConserved` its `operator`, `semantics` and
`sentence`.
"""
ledger_record(l::Fields.Ledger) =
    Dict{String,Any}("form" => "Ledger", "quantity" => String(Fields.quantity(l)),
                     "residual" => Fields.residual(l), "tolerance" => Fields.tolerance(l),
                     "inventory" => record_value(Fields.losses(l)))

ledger_record(c::Fields.ColumnLedgers) =
    Dict{String,Any}("form" => "ColumnLedgers", "quantity" => String(Fields.quantity(c)),
                     "size" => collect(size(Fields.ledgers(c))),
                     "columns" => [ledger_record(l) for l in Fields.ledgers(c)])

ledger_record(c::Fields.ClassLedgers) =
    Dict{String,Any}("form" => "ClassLedgers", "quantity" => String(Fields.quantity(c)),
                     "classes" => [repr(x) for x in Fields.classes(c)],
                     "ledgers" => [ledger_record(l) for l in Fields.ledgers(c)])

ledger_record(n::Fields.NotConserved) =
    Dict{String,Any}("form" => "NotConserved", "operator" => String(n.operator),
                     "semantics" => n.semantics, "sentence" => n.sentence)

"""
    ledger_records(site, quantity, ledgers)

The `ledger_record` of each element of the tuple `ledgers` of the artifact `quantity`.
Refuses at `site` a `ledgers` that is not a tuple and an element that is not a `Ledger`,
`ColumnLedgers`, `ClassLedgers` or `NotConserved`; and, naming the conserved quantity, a
ledger with an open balance. A `NotConserved` is recorded and never asked whether it is
closed.
"""
function ledger_records(site::AbstractString, quantity::Symbol, ledgers)
    ledgers isa Tuple || refuse("ledgers", site, "a $(typeof(ledgers)) where a tuple of ledgers is required")
    for l in ledgers
        l isa Union{Fields.Ledger,Fields.ColumnLedgers,Fields.ClassLedgers,Fields.NotConserved} || refuse(
            "ledgers", site, "a $(typeof(l)) is not a Ledger, ColumnLedgers, ClassLedgers or NotConserved")
        l isa Fields.NotConserved && continue
        found = first_open(l)
        found === nothing && continue
        where, open = found
        refuse(String(Fields.quantity(open)), site,
               "the ledger of $(Fields.quantity(open)) $(where)over the artifact $(quantity) is open: " *
               "residual $(Fields.residual(open)) against tolerance $(Fields.tolerance(open))")
    end
    return Any[ledger_record(l) for l in ledgers]
end

# ---------------------------------------------------------------- fields

"The keywords `put_field!` reads besides the code version."
const PUT_KEYWORDS = (:declaration, :system, :profile, :inputs, :quantity, :operator_version, :field,
                      :ledgers, :chunk_level, :values)

"""
    put_field!(store, run::RunID; code, declaration, system, profile, inputs, quantity,
               operator_version, field, ledgers, chunk_level, values)
    put_field!(store, scratch::ScratchRun; declaration, system, profile, inputs, quantity,
               operator_version, field, ledgers, chunk_level, values)

Writes the field `field` of `quantity` as an artifact and returns `(key, stamped)`: `key`,
the `ArtifactKey` of `code` (the scratch run's for the second form), `declaration`,
`system`, `profile`, `inputs`, `quantity`, `operator_version`, the field's support, and
the `Time.Interval` the field's time support is placed over; and `stamped`,
`field` with the origin `Fields.stamped` of its writer, the run, the key and the parameter
digest. The first form writes under `objects/` after `admit(key)`, the second under
`scratch/<uuid>/` after `admit(scratch)`.

The artifact is its manifest and one Zarr array named by `quantity`: the field's data
moved to the host through `Backends.on`, translated by `to_disk` for `values` (an
`Amounts` or a `CellIds`), chunked at `chunk_level` so a chunk is the descendants of one
cell of that level, and carrying the `array_attributes` of the field. The manifest names
`kind`, `key`, `quantity`, `owner`, `run`, `support`, `operator_version`,
`parameter_digest`, `profile_digest`, `code`, `inputs` (each read quantity's key),
`parameters` (`parameter_records`), `profile` (`profile_records`), `stocks` (the
declaration's) and `arrays` (`array_table`), with the `ledger_records` of `ledgers`, a
tuple.

Every keyword is required. Refuses a field whose time support is not placed over an
interval, naming its time semantics; whatever `ArtifactKey` and `admit` refuse; a field whose
semantics is not the one the declaration writes `quantity` with, whose origin names another
writer or run, or whose origin is stamped; what `ledger_records` refuses, an open ledger by
its conserved quantity; a run the store does not record under the code version; a support
the store does not hold; what `require_host_array`, `require_chunk_level` and `to_disk`
refuse; and an artifact the store already holds.
"""
function put_field!(store::Store, run::RunID; kwargs...)
    site = "Provenance.put_field!"
    k, _ = read_keywords(site, values(kwargs), (:code, PUT_KEYWORDS...), ())
    code = require_type("code", site, k.code, CodeVersion)
    return write_field!(store, site, run, code, k, key -> object_directory(store, admit(key)))
end

function put_field!(store::Store, scratch::ScratchRun; kwargs...)
    site = "Provenance.put_field!"
    k, _ = read_keywords(site, values(kwargs), PUT_KEYWORDS, ())
    return write_field!(store, site, scratch.run, scratch.code, k,
                        key -> scratch_directory(store, admit(scratch).run, key))
end

"""
    write_field!(store, site, run, code, k, place)

The write both forms of `put_field!` make, with `place` giving the directory of the key
after admitting it.
"""
function write_field!(store::Store, site::AbstractString, run::RunID, code::CodeVersion, k, place)
    field = require_type("field", site, k.field, Fields.Field)
    declaration = require_type("declaration", site, k.declaration, Declaration)
    quantity = require_type("quantity", site, k.quantity, Symbol)
    support = Fields.support(field)
    time = Fields.time_support(field)
    placed_by = Time.time_support_kind(Time.semantics(time))
    placed_by === :interval || refuse(
        "interval", site,
        "the field of $(quantity) is $(nameof(typeof(Time.semantics(time)))), placed by $(placed_by) and " *
        "not by the interval its key names")
    key = ArtifactKey(code = code, declaration = declaration, system = k.system, profile = k.profile,
                      inputs = k.inputs, quantity = quantity, support = support,
                      interval = Time.interval(time), operator_version = k.operator_version)
    system = k.system
    profile = k.profile
    semantics = Fields.semantics(field)
    declared = Coupling.write_of(declaration, quantity).semantics
    typeof(declared) === typeof(semantics) || refuse(
        String(quantity), site,
        "$(declaration.name) writes $(quantity) as $(Coupling.semantics_name(declared)), and the field is " *
        Fields.describe(field))
    origin = Fields.origin(field)
    Fields.is_stamped(origin) && refuse(
        "origin", site, "the field is stamped with a content key already, and the store holds it under that key")
    origin.writer === declaration.name || refuse(
        "owner", site, "the field was written by $(origin.writer), and the declaration is $(declaration.name)'s")
    origin.run == run.uuid || refuse(
        "run", site, "the field was written in run $(origin.run), and it is stored under run $(run.uuid)")
    ledgers = ledger_records(site, quantity, k.ledgers)
    values = require_type("values", site, k.values, Union{Amounts,CellIds})
    level = Fields.level(field)
    chunk_level = require_chunk_level(site, k.chunk_level, level)
    dir = place(key)
    require_run(store, run, code, site)
    isfile(joinpath(support_directory(store, support), MANIFEST)) || refuse(
        "support", site, "the store holds no support $(hex(support.digest)); put_support! writes it")
    ispath(dir) && refuse("artifact", site, "the store already holds $(hex(key.digest)) at $(dir)")
    host = on(Fields.data(field), CPU())
    require_host_array(site, host, level)
    disk = to_disk(values, host, site)
    per_chunk = cells_per_chunk(level, chunk_level)
    attributes = array_attributes(support = support, semantics = semantics, time = time,
                                  dimension = Fields.dimension(field), owner = declaration.name)
    parameters = parameter_digest(declaration, system)
    manifest = Dict{String,Any}(
        "kind" => FIELD_KIND, "key" => hex(key.digest), "quantity" => String(quantity),
        "owner" => String(declaration.name), "run" => string(run.uuid), "support" => hex(support.digest),
        "operator_version" => record_value(k.operator_version), "parameter_digest" => hex(parameters),
        "profile_digest" => hex(profile_digest(declaration, profile)),
        "code" => code_record(code),
        "inputs" => Dict{String,Any}(String(q) => hex(k.inputs[q].digest) for q in keys(k.inputs)),
        "parameters" => parameter_records(declaration, system),
        "profile" => profile_records(declaration, profile),
        "stocks" => [Dict{String,Any}("conserved" => String(s.conserved),
                                      "quantities" => [String(q) for q in s.quantities])
                     for s in declaration.stocks],
        "arrays" => Dict{String,Any}(String(quantity) => array_table(
            attributes = attributes, disk = disk, chunk_level = chunk_level, per_chunk = per_chunk,
            values = values, ledgers = ledgers)))
    write_directory!(dir, site) do staging
        write_array!(joinpath(staging, String(quantity)), disk, attributes, per_chunk)
        write_toml(joinpath(staging, MANIFEST), manifest)
    end
    stamped = Fields.Field(semantics = semantics, dimension = Fields.dimension(field), data = Fields.data(field),
                           support = support, time = Fields.time_support(field),
                           origin = Fields.stamped(declaration.name, run.uuid, key.digest, parameters))
    return key, stamped
end

"The keywords `read_field` reads."
const READ_KEYWORDS = (:quantity, :semantics, :dimension, :time, :support, :backend)

"""
    read_field(store, key::ArtifactKey; quantity, semantics, dimension, time, support, backend)
    read_field(store, scratch::ScratchRun, key::ArtifactKey; quantity, semantics, dimension,
               time, support, backend)

The field of `quantity` the artifact `key` holds (under `scratch/<uuid>/` for the second
form), on `backend`, declaring `semantics`, `dimension`, the `Time.TimeSupport` `time` and
`support`, with the origin `Fields.stamped` of the manifest's owner, run and parameter digest
and `key`'s digest.

Every keyword is required. Refuses an artifact the store does not hold; a manifest missing
any of `MANIFEST_KEYS`, or an array table missing any of `ARRAY_KEYS`, naming what is
absent; a manifest naming another key, kind, quantity or support; attributes in the
manifest other than the ones `array_attributes` gives for the keywords and the owner; and
whatever `open_array`, `read_array`, `values_of` and `from_disk` refuse, among them an array
missing any of `REQUIRED_ATTRIBUTES`, naming it.
"""
read_field(store::Store, key::ArtifactKey; kwargs...) =
    read_field_at(object_directory(store, key), key, kwargs)

read_field(store::Store, scratch::ScratchRun, key::ArtifactKey; kwargs...) =
    read_field_at(scratch_directory(store, scratch.run, key), key, kwargs)

"The read both forms of `read_field` make, from the artifact directory `dir`."
function read_field_at(dir::AbstractString, key::ArtifactKey, kwargs)
    site = "Provenance.read_field"
    k, _ = read_keywords(site, values(kwargs), READ_KEYWORDS, ())
    quantity = require_type("quantity", site, k.quantity, Symbol)
    semantics = require_type("semantics", site, k.semantics, Fields.Semantics)
    dimension = require_type("dimension", site, k.dimension, Dim)
    time = require_type("time", site, k.time, Time.TimeSupport)
    support = require_type("support", site, k.support, Mesh.Support)
    backend = require_type("backend", site, k.backend, Backend)
    path = joinpath(dir, MANIFEST)
    isfile(path) || refuse("artifact", site, "the store holds no artifact $(hex(key.digest)) at $(dir)")
    manifest = TOML.parsefile(path)
    require_keys(site, path, manifest, MANIFEST_KEYS)
    for (name, expected) in (("key", hex(key.digest)), ("kind", FIELD_KIND), ("quantity", String(quantity)),
                             ("support", hex(support.digest)))
        manifest[name] == expected || refuse(
            name, site, "$(path) names $(name) $(repr(manifest[name])), and $(repr(expected)) is read")
    end
    require_keys(site, "the arrays of $(path)", manifest["arrays"], (String(quantity),))
    table = manifest["arrays"][String(quantity)]
    require_keys(site, "the $(quantity) table of $(path)", table, ARRAY_KEYS)
    owner = manifest["owner"]
    owner isa String || refuse("owner", site, "$(path) names owner $(repr(owner)), not a name")
    expected = array_attributes(support = support, semantics = semantics, time = time, dimension = dimension,
                                owner = Symbol(owner))
    table["attributes"] == expected || refuse(
        "attributes", site, "$(path) records attributes $(repr(table["attributes"])), and $(repr(expected)) are read")
    array = joinpath(dir, String(quantity))
    z = open_array(array, expected, site)
    memory = from_disk(values_of(site, table["values"]), read_array(z, table, array, site), site)
    run = try
        UUID(manifest["run"])
    catch err
        err isa ArgumentError || rethrow()
        refuse("run", site, "$(path) names run $(repr(manifest["run"])), not a UUID")
    end
    origin = Fields.stamped(Symbol(owner), run, key.digest,
                            digest_of("parameter_digest", site, manifest["parameter_digest"]))
    return Fields.Field(semantics = semantics, dimension = dimension, data = on(memory, backend),
                        support = support, time = time, origin = origin)
end
