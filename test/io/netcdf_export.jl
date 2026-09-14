using Test
import NCDatasets
using Fiddlybits: Render, Provenance, Mesh

# The NetCDF export of docs/plans/fiddlybits-52v.6-provenance.md, section "The store";
# decision 0010; docs/imports/ncdatasets.md.

isdefined(@__MODULE__, :StoreFixtures) || include(joinpath(@__DIR__, "store_fixtures.jl"))
import .StoreFixtures as ST

"A copy of the file at `path` under `dir`, opened for appending and passed to `f!`."
function tampered_copy(f!, path, dir)
    copy_path = joinpath(dir, "tampered-$(length(readdir(dir))).nc")
    cp(path, copy_path)
    NCDatasets.NCDataset(f!, copy_path, "a")
    return copy_path
end

@testset "Render.write_netcdf declares its geometry and read_netcdf refuses a file that does not match it" begin
    mktempdir() do dir
        m = ST.mesh()
        run = Provenance.mint_run_id()
        data = collect(range(1.0, 2.0; length = Mesh.ncells(ST.level())))
        f = ST.field(m.support, run, data)
        path = joinpath(dir, "surface.nc")
        Render.write_netcdf(path; field = f, name = "surface_mass", level = m.level, geometry = m.geometry)

        @testset "positive control: the file as written rebuilds its support and reads back the field" begin
            back = Render.read_netcdf(path; name = "surface_mass")
            @test back.support == m.support
            @test back.data == data
            NCDatasets.NCDataset(path, "r") do ds
                @test ds.attrib["sphere_radius"] == ST.radius()
                @test ds["crs"].attrib["earth_radius"] == ST.radius()
                @test ds["surface_mass"].attrib["grid_mapping"] == "crs"
                @test ds["surface_mass"].attrib["support_id"] == bytes2hex(collect(m.support.digest))
                @test ds["surface_mass"].attrib["t0_seconds"] == 0.0
                @test ds["surface_mass"].attrib["t1_seconds"] == 3600.0
                @test ds["surface_mass"].attrib["dimension_mass"] == 1
            end
        end

        @testset "a declared radius the geometry was not written at refuses, naming support_id" begin
            p = tampered_copy(ds -> ds.attrib["sphere_radius"] = 2 * ST.radius(), path, dir)
            @test ST.refused(ST.caught(() -> Render.read_netcdf(p; name = "surface_mass")), "support_id", "rebuilds")
        end

        @testset "a grid mapping carrying another radius than the declared one refuses" begin
            p = tampered_copy(ds -> ds["crs"].attrib["earth_radius"] = 2 * ST.radius(), path, dir)
            @test ST.refused(ST.caught(() -> Render.read_netcdf(p; name = "surface_mass")), "earth_radius",
                             "declared sphere radius")
        end

        @testset "an altered $(variable) refuses, naming it" for variable in ("cell_area", "lat", "lon", "cell_corner")
            p = tampered_copy(path, dir) do ds
                v = ds[variable].var
                first_entry = ntuple(_ -> 1, ndims(v))
                v[first_entry...] = nextfloat(v[first_entry...])
            end
            @test ST.refused(ST.caught(() -> Render.read_netcdf(p; name = "surface_mass")), variable,
                             "not the one its declared geometry rebuilds")
        end

        @testset "a file missing $(a) refuses, naming it" for a in Render.GEOMETRY_ATTRIBUTES
            p = tampered_copy(ds -> delete!(ds.attrib, a), path, dir)
            @test ST.refused(ST.caught(() -> Render.read_netcdf(p; name = "surface_mass")), a, "declares no")
        end

        @testset "a file written on another sphere under this file's declaration refuses at its areas" begin
            other = ST.mesh(; r = 2 * ST.radius())
            written = joinpath(dir, "other.nc")
            Render.write_netcdf(written; field = ST.field(other.support, run, data), name = "surface_mass",
                                level = other.level, geometry = other.geometry)
            p = tampered_copy(written, dir) do ds
                ds.attrib["sphere_radius"] = ST.radius()
                ds.attrib["support_id"] = bytes2hex(collect(m.support.digest))
                ds["crs"].attrib["earth_radius"] = ST.radius()
            end
            @test ST.refused(ST.caught(() -> Render.read_netcdf(p; name = "surface_mass")), "cell_area",
                             "not the one its declared geometry rebuilds")
        end

        @testset "write_netcdf refuses a level and geometry that are not the field's support" begin
            coarse = ST.mesh(1)
            @test ST.refused(ST.caught(() -> Render.write_netcdf(joinpath(dir, "coarse.nc"); field = f,
                                                                 name = "surface_mass", level = coarse.level,
                                                                 geometry = coarse.geometry)),
                             "support", "the field is on support")
            @test ST.refused(ST.caught(() -> Render.write_netcdf(path; field = f, name = "surface_mass",
                                                                 level = m.level, geometry = m.geometry)),
                             "path", "exists")
            @test ST.refused(ST.caught(() -> Render.write_netcdf(joinpath(dir, "named.nc"); field = f, name = "lat",
                                                                 level = m.level, geometry = m.geometry)),
                             "name", "geometry variable")
        end
    end
end
