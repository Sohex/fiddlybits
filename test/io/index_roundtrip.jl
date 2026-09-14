using Test
import Zarr
using Fiddlybits: Provenance, Fields, Mesh, Dimensions

# provenance.index_roundtrip: docs/imports/zarr.md names this file as its leak test;
# decision 0010, section "The index base".

isdefined(@__MODULE__, :StoreFixtures) || include(joinpath(@__DIR__, "store_fixtures.jl"))
import .StoreFixtures as ST

"The known index field: each cell of the fixture level holds the memory index of its parent one level coarser."
known_index_field() = [Mesh.parent(i) for i in 1:Mesh.ncells(ST.level())]

"The disk the known index field is written to: each cell's parent as a 0-based id."
known_disk() = [Mesh.parent(i) - 1 for i in 1:Mesh.ncells(ST.level())]

"The whole Zarr array at `path`."
raw_array(path) = (z = Zarr.zopen(path, "r"); z[:])

@testset "provenance.index_roundtrip" begin
    mktempdir() do root
        store, run, m = ST.seeded(root)
        declaration = ST.declaration(quantity = :parent_cell, semantics = Fields.Intensive())
        f = ST.field(m.support, run, known_index_field(); semantics = Fields.Intensive(),
                     dimension = Dimensions.DIMENSIONLESS)
        cell_ids = Provenance.CellIds(level = ST.level() - 1)
        key, _ = ST.put(store, run, f; declaration = declaration, quantity = :parent_cell, values = cell_ids)
        read_in(s) = ST.read_back(s, key, m.support; quantity = :parent_cell, semantics = Fields.Intensive(),
                                  dimension = Dimensions.DIMENSIONLESS)

        @testset "the known index field reads back 1-based, unchanged in every cell" begin
            @test Fields.data(read_in(store)) == known_index_field()
        end

        @testset "on disk every cell holds its parent's 0-based id" begin
            disk = raw_array(ST.array_path(store, key, :parent_cell))
            @test disk == known_disk()
            @test extrema(disk) == (0, Mesh.ncells(ST.level() - 1) - 1)
        end

        @testset "positive control: an off-by-one in the values at the disk boundary is refused" begin
            mktempdir() do dir
                cp(root, joinpath(dir, "store"))
                copied = Provenance.Store(root = joinpath(dir, "store"))
                ST.edit_values!(x -> x .+ 1, ST.array_path(copied, key, :parent_cell))
                @test ST.refused(ST.caught(() -> read_in(copied)), "values", "outside the 0-based")
            end
        end

        @testset "positive control: an off-by-one in cell position is exposed by the known field" begin
            mktempdir() do dir
                cp(root, joinpath(dir, "store"))
                copied = Provenance.Store(root = joinpath(dir, "store"))
                ST.edit_values!(x -> circshift(x, 1), ST.array_path(copied, key, :parent_cell))
                @test Fields.data(read_in(copied)) != known_index_field()
            end
            constant = fill(1, Mesh.ncells(ST.level()))
            @test circshift(constant, 1) == constant
        end

        @testset "positive control: a disk written 1-based fails the disk check a read-back alone passes" begin
            mktempdir() do dir
                path = joinpath(dir, "untranslated")
                z = Zarr.zcreate(Int, Zarr.DirectoryStore(path), Mesh.ncells(ST.level()); zarr_format = 2)
                z[:] = known_index_field()
                untranslated = raw_array(path)
                @test untranslated == known_index_field()
                @test untranslated != known_disk()
            end
        end

        @testset "cell ids outside their level, or not integers, are refused" begin
            bad = copy(known_index_field())
            bad[7] = Mesh.ncells(ST.level() - 1) + 1
            fb = ST.field(m.support, run, bad; semantics = Fields.Intensive(), dimension = Dimensions.DIMENSIONLESS)
            @test ST.refused(ST.caught(() -> ST.put(store, run, fb; declaration = declaration, quantity = :parent_cell,
                                                    values = cell_ids, operator_version = 2)),
                             "values", "entry 7")
            ff = ST.field(m.support, run, Float64.(known_index_field()); semantics = Fields.Intensive(),
                          dimension = Dimensions.DIMENSIONLESS)
            @test ST.refused(ST.caught(() -> ST.put(store, run, ff; declaration = declaration, quantity = :parent_cell,
                                                    values = cell_ids, operator_version = 3)),
                             "values", "integers")
            @test ST.refused(ST.caught(() -> Provenance.CellIds(level = -1)), "level", "refinement depth")
        end
    end
end
