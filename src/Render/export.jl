# NetCDF export with the geometry declared in the file: docs/plans/fiddlybits-52v.6-provenance.md,
# section "The store"; decision 0010; docs/imports/ncdatasets.md. A file holds
#
#   global attributes   GEOMETRY_ATTRIBUTES: the sphere radius, the mesh kind and level, the
#                       element type, the support id and its digests, the body frame's axes
#   crs                 a CF grid mapping whose earth_radius is the declared sphere radius
#   cell_corner         (cell, corner, component): each cell's corners on the unit sphere
#   cell_area           (cell): each cell's area at the declared radius
#   lat, lon            (cell): each cell's circumcentre in degrees in the body frame
#   <name>              the field, over the cell axis and the axes Backends.LAYOUT names
#
# read_netcdf rebuilds the support from the declaration and compares the file against it.

import NCDatasets
using ..Verdicts: refuse
using ..Backends: CPU, LAYOUT, on
using ..Systems: read_keywords, require_type
using ..Fields: Fields
using ..Mesh: Mesh
using ..Time: Time
using ..Dimensions: Dimensions

"The global attributes that declare a file's geometry; `read_netcdf` refuses a file missing any."
const GEOMETRY_ATTRIBUTES = ("sphere_radius", "mesh_kind", "mesh_level", "element_type", "support_id",
                             "geometry_constructor_version", "refinement_digest", "fraction_digest",
                             "spin_axis", "prime_meridian")

"The variables a file's geometry occupies; a field may not take one of these names."
const GEOMETRY_VARIABLES = ("crs", "cell_corner", "cell_area", "lat", "lon")

"The names of a file's cell, corner and Cartesian component dimensions."
const CELL_DIMENSION = "cell"
const CORNER_DIMENSION = "corner"
const COMPONENT_DIMENSION = "component"

"The float types a declared element type names."
const ELEMENT_TYPES = (Float64 = Float64, Float32 = Float32)

"""
    cell_corners(level)

The corners of every cell of `level` on the unit sphere as a `Float64` array of size
`(cells, 3, 3)`: entry `[i, c, a]` is component `a` of corner `c` of cell `i`, corners in
the winding order of `level.cells`.
"""
function cell_corners(level::Mesh.Level)
    n = size(level.cells, 2)
    corners = Array{Float64}(undef, n, 3, 3)
    for i in 1:n, c in 1:3, a in 1:3
        corners[i, c, a] = Float64(level.vertices[a, level.cells[c, i]])
    end
    return corners
end

"The area of every cell of `geometry` at `radius`, through `Mesh.at_radius`."
cell_areas(geometry::Mesh.Geometry, radius::Float64) = [Mesh.at_radius(a, radius, 2) for a in geometry.cell_area]

"""
    cell_latitudes(geometry)
    cell_longitudes(geometry)

The latitude and longitude in degrees of every cell circumcentre of `geometry` in
`Mesh.BODY_FRAME`, through `Mesh.latitude` and `Mesh.longitude`.
"""
cell_latitudes(geometry::Mesh.Geometry) =
    [rad2deg(Mesh.latitude(Mesh.BODY_FRAME, geometry.dual_vertex[1, i], geometry.dual_vertex[2, i],
                           geometry.dual_vertex[3, i])) for i in axes(geometry.dual_vertex, 2)]

cell_longitudes(geometry::Mesh.Geometry) =
    [rad2deg(Mesh.longitude(Mesh.BODY_FRAME, geometry.dual_vertex[1, i], geometry.dual_vertex[2, i],
                            geometry.dual_vertex[3, i])) for i in axes(geometry.dual_vertex, 2)]

"""
    uniform_support(level_index, level, geometry; kind, radius, element_type)

The `Mesh.Support` of `level` and `geometry` at `radius` with no refinement regions and no
fractions.
"""
uniform_support(level_index::Integer, level::Mesh.Level, geometry::Mesh.Geometry; kind::Symbol,
                radius::Float64, element_type::Symbol) =
    Mesh.Support(level_index, level, geometry; kind = kind, refinement = (), radius = radius,
                 element_type = element_type, fractions = ())

"""
    field_attributes(field)

The attributes of a field's variable: `semantics`, `time_semantics`, `dimension_<base>` for
each name of `Dimensions.BASE_DIMENSIONS`, `owner`, `support_id`, `time_placement` with
`t_seconds` or `t0_seconds` and `t1_seconds` in SI seconds since the run epoch, and the CF
`cell_measures`, `coordinates` and `grid_mapping` naming the geometry variables.
"""
function field_attributes(field::Fields.Field)
    time = Fields.time_support(field)
    kind = Time.time_support_kind(Time.semantics(time))
    attributes = Pair{String,Any}[
        "semantics" => Fields.type_name(typeof(Fields.semantics(field))),
        "time_semantics" => String(nameof(typeof(Fields.time_semantics(field)))),
        "owner" => String(Fields.origin(field).writer),
        "support_id" => bytes2hex(collect(Fields.support(field).digest)),
        "time_placement" => String(kind),
        "cell_measures" => "area: cell_area",
        "coordinates" => "lat lon",
        "grid_mapping" => "crs"]
    for (n, e) in zip(Dimensions.BASE_DIMENSIONS, Dimensions.exponents(Fields.dimension(field)))
        push!(attributes, "dimension_$(n)" => e)
    end
    kind === :instant && push!(attributes, "t_seconds" => Float64(Time.instant(time).seconds))
    if kind === :interval
        span = Time.interval(time)
        push!(attributes, "t0_seconds" => Float64(span.t0.seconds), "t1_seconds" => Float64(span.t1.seconds))
    end
    return attributes
end

"""
    write_netcdf(path; field, name, level, geometry)

Writes `field` to a new NetCDF file at `path` as the variable `name`, with the geometry of
its support declared in the file as the header of this file lists: the global
`GEOMETRY_ATTRIBUTES`, `crs`, `cell_corner` from `cell_corners(level)`, `cell_area` from
`cell_areas(geometry, radius)`, and `lat` and `lon` from `geometry`. The field's data is
moved to the host through `Backends.on` and written over `cell` and the names
`Backends.LAYOUT` gives its further axes, with `field_attributes`. Every keyword is
required.

Refuses when `uniform_support` of `level` and `geometry` at the field's support's level,
kind, radius and element type is not the field's support; a `name` that is one of
`GEOMETRY_VARIABLES`; a field of more axes than `Backends.LAYOUT` names; and a `path` that
exists.
"""
function write_netcdf(path::AbstractString; kwargs...)
    site = "Render.write_netcdf"
    k, _ = read_keywords(site, values(kwargs), (:field, :name, :level, :geometry), ())
    field = require_type("field", site, k.field, Fields.Field)
    name = require_type("name", site, k.name, String)
    level = require_type("level", site, k.level, Mesh.Level)
    geometry = require_type("geometry", site, k.geometry, Mesh.Geometry)
    support = Fields.support(field)
    rebuilt = uniform_support(support.level, level, geometry; kind = support.kind, radius = support.radius,
                              element_type = support.element_type)
    rebuilt.digest == support.digest || refuse(
        "support", site,
        "the level and geometry given, at radius $(support.radius) with no refinement regions and no " *
        "fractions, are support $(bytes2hex(collect(rebuilt.digest))), and the field is on support " *
        "$(bytes2hex(collect(support.digest)))")
    name in GEOMETRY_VARIABLES && refuse("name", site, "$(name) is a geometry variable of the file")
    ispath(path) && refuse("path", site, "$(path) exists")
    host = on(Fields.data(field), CPU())
    ndims(host) <= length(LAYOUT) || refuse(
        "axes", site, "a field of $(ndims(host)) axes, and Backends.LAYOUT names $(length(LAYOUT))")
    NCDatasets.NCDataset(path, "c") do ds
        ds.attrib["sphere_radius"] = support.radius
        ds.attrib["mesh_kind"] = String(support.kind)
        ds.attrib["mesh_level"] = support.level
        ds.attrib["element_type"] = String(support.element_type)
        ds.attrib["support_id"] = bytes2hex(collect(support.digest))
        ds.attrib["geometry_constructor_version"] = support.constructor_version
        ds.attrib["refinement_digest"] = bytes2hex(collect(support.refinement_digest))
        ds.attrib["fraction_digest"] = bytes2hex(collect(support.fraction_digest))
        ds.attrib["spin_axis"] = collect(Mesh.BODY_FRAME.spin_axis)
        ds.attrib["prime_meridian"] = collect(Mesh.BODY_FRAME.prime_meridian)
        NCDatasets.defDim(ds, CELL_DIMENSION, size(host, 1))
        NCDatasets.defDim(ds, CORNER_DIMENSION, 3)
        NCDatasets.defDim(ds, COMPONENT_DIMENSION, 3)
        NCDatasets.defVar(ds, "crs", Int32, (); attrib = ["grid_mapping_name" => "latitude_longitude",
                                                          "earth_radius" => support.radius])
        corner = NCDatasets.defVar(ds, "cell_corner", Float64, (CELL_DIMENSION, CORNER_DIMENSION, COMPONENT_DIMENSION))
        corner.var[:, :, :] = cell_corners(level)
        area = NCDatasets.defVar(ds, "cell_area", Float64, (CELL_DIMENSION,); attrib = ["units" => "m2"])
        area.var[:] = cell_areas(geometry, support.radius)
        lat = NCDatasets.defVar(ds, "lat", Float64, (CELL_DIMENSION,); attrib = ["units" => "degrees_north"])
        lat.var[:] = cell_latitudes(geometry)
        lon = NCDatasets.defVar(ds, "lon", Float64, (CELL_DIMENSION,); attrib = ["units" => "degrees_east"])
        lon.var[:] = cell_longitudes(geometry)
        dims = [CELL_DIMENSION]
        for d in 2:ndims(host)
            NCDatasets.defDim(ds, String(LAYOUT[d]), size(host, d))
            push!(dims, String(LAYOUT[d]))
        end
        v = NCDatasets.defVar(ds, name, eltype(host), Tuple(dims); attrib = field_attributes(field))
        v.var[ntuple(_ -> Colon(), ndims(host))...] = host
    end
    return path
end

"""
    read_netcdf(path; name)

`(support, data)` from the NetCDF file at `path`: `support`, the `uniform_support` rebuilt
from the declared `mesh_level`, `mesh_kind`, `sphere_radius` and `element_type` over
`Mesh.hierarchy` and `Mesh.geometry`; and `data`, the variable `name` as an `Array`. The
keyword is required.

Refuses a `path` that is not a file; a file missing any of `GEOMETRY_ATTRIBUTES`, naming
every absent one; an element type not in `ELEMENT_TYPES`; a declared refinement or
fraction digest other than that of no regions and no fractions, and a declared body frame
other than `Mesh.BODY_FRAME`; a rebuilt support whose digest is not the declared
`support_id`, naming `support_id`; a `crs` whose `earth_radius` is not the declared radius;
a `cell_corner`, `cell_area`, `lat` or `lon` that is absent or not the rebuilt one, naming
it; and an absent variable `name`.
"""
function read_netcdf(path::AbstractString; kwargs...)
    site = "Render.read_netcdf"
    k, _ = read_keywords(site, values(kwargs), (:name,), ())
    name = require_type("name", site, k.name, String)
    isfile(path) || refuse("path", site, "$(path) is not a file")
    return NCDatasets.NCDataset(path, "r") do ds
        absent = [a for a in GEOMETRY_ATTRIBUTES if !haskey(ds.attrib, a)]
        isempty(absent) || refuse(join(absent, ", "), site,
                                  "$(path) declares no $(join(absent, ", ")), and its geometry is not declared")
        element = Symbol(ds.attrib["element_type"])
        haskey(ELEMENT_TYPES, element) || refuse(
            "element_type", site, "$(path) declares element type $(element), not one of $(join(keys(ELEMENT_TYPES), ", "))")
        ds.attrib["refinement_digest"] == bytes2hex(collect(Mesh.digest_refinement(()))) || refuse(
            "refinement_digest", site, "$(path) declares refinement regions, which this reader does not rebuild")
        ds.attrib["fraction_digest"] == bytes2hex(collect(Mesh.digest_fractions(()))) || refuse(
            "fraction_digest", site, "$(path) declares fractions, which this reader does not rebuild")
        for (a, axis) in (("spin_axis", Mesh.BODY_FRAME.spin_axis), ("prime_meridian", Mesh.BODY_FRAME.prime_meridian))
            collect(ds.attrib[a]) == collect(axis) || refuse(
                a, site, "$(path) declares $(a) $(ds.attrib[a]), and Mesh.BODY_FRAME's is $(axis)")
        end
        L = Int(ds.attrib["mesh_level"])
        radius = Float64(ds.attrib["sphere_radius"])
        level = Mesh.hierarchy(L; T = ELEMENT_TYPES[element]).levels[L + 1]
        geometry = Mesh.geometry(level, Mesh.stencils(level))
        support = uniform_support(L, level, geometry; kind = Symbol(ds.attrib["mesh_kind"]), radius = radius,
                                  element_type = element)
        bytes2hex(collect(support.digest)) == ds.attrib["support_id"] || refuse(
            "support_id", site,
            "$(path) declares support $(ds.attrib["support_id"]), and its declared geometry rebuilds " *
            "support $(bytes2hex(collect(support.digest)))")
        haskey(ds, "crs") || refuse("crs", site, "$(path) holds no crs")
        haskey(ds["crs"].attrib, "earth_radius") && ds["crs"].attrib["earth_radius"] == radius || refuse(
            "earth_radius", site, "the crs of $(path) does not carry the declared sphere radius $(radius)")
        for (variable, rebuilt) in (("cell_corner", cell_corners(level)), ("cell_area", cell_areas(geometry, radius)),
                                    ("lat", cell_latitudes(geometry)), ("lon", cell_longitudes(geometry)))
            haskey(ds, variable) || refuse(variable, site, "$(path) holds no $(variable)")
            v = ds[variable].var
            Array(v[ntuple(_ -> Colon(), ndims(v))...]) == rebuilt || refuse(
                variable, site, "the $(variable) of $(path) is not the one its declared geometry rebuilds")
        end
        haskey(ds, name) || refuse(name, site, "$(path) holds no variable $(name)")
        v = ds[name].var
        return (support = support, data = Array(v[ntuple(_ -> Colon(), ndims(v))...]))
    end
end
