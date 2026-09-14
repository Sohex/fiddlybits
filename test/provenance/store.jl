using Test
using TOML
import Zarr
using Fiddlybits: Fiddlybits, Provenance, Fields, Mesh, Time, Dimensions, Backends, Verdicts

# provenance.store_refuses_incomplete and the store of docs/plans/fiddlybits-52v.6-provenance.md,
# section "The store"; decision 0010; docs/imports/zarr.md.

isdefined(@__MODULE__, :StoreFixtures) || include(joinpath(@__DIR__, "..", "io", "store_fixtures.jl"))
import .StoreFixtures as ST
import .SystemFixtures as SF

"A `Ledger{Q}` over the cells of the fixture level taking a stock of 5 to `after`."
store_ledger(Q, after) = Fields.Ledger{Q}(Float64, Mesh.ncells(ST.level()), 1.0, 5.0, after, 0.0; reservoir = false)

"The key the fixture `put` computes at `operator_version` under `code`."
fixture_key(m; operator_version, code = ST.code()) =
    Provenance.ArtifactKey(code = code, declaration = ST.declaration(), system = SF.system(), profile = ST.profile(),
                           inputs = (;), quantity = :surface_mass, support = m.support,
                           interval = Time.interval(ST.interval()), operator_version = operator_version)

"A copy of the store at `root` under `dir`."
store_copy(root, dir) = (cp(root, joinpath(dir, "store")); Provenance.Store(root = joinpath(dir, "store")))

"The manifest of the artifact `key` in `store`."
manifest_of(store, key) = TOML.parsefile(joinpath(Provenance.object_directory(store, key), Provenance.MANIFEST))

@testset "provenance.store_refuses_incomplete" begin
    mktempdir() do root
        store, run, m = ST.seeded(root)
        data = collect(range(1.0, 2.0; length = Mesh.ncells(ST.level())))
        f = ST.field(m.support, run, data)
        key, stamped = ST.put(store, run, f)

        @testset "positive control: a complete array opens and reads back the field it stored" begin
            back = ST.read_back(store, key, m.support)
            @test back == stamped
            @test Fields.data(back) == data
            @test Fields.content_key(Fields.origin(back)) == key.digest
            @test Fields.origin(back).run == run.uuid
        end

        @testset "the required attributes are the six the registry names" begin
            @test collect(Provenance.REQUIRED_ATTRIBUTES) ==
                  ["support_id", "semantics", "time_semantics", "dimension", "owner", "interval"]
        end

        @testset "an array with $(name) dropped refuses, naming it" for name in Provenance.REQUIRED_ATTRIBUTES
            mktempdir() do dir
                copied = store_copy(root, dir)
                ST.edit_attributes!(a -> (delete!(a, name); a), ST.array_path(copied, key))
                @test ST.refused(ST.caught(() -> ST.read_back(copied, key, m.support)), name,
                                 "carries no $(name) attribute")
            end
        end

        @testset "an array with $(name) altered refuses, naming it" for name in Provenance.REQUIRED_ATTRIBUTES
            mktempdir() do dir
                copied = store_copy(root, dir)
                ST.edit_attributes!(a -> (a[name] = "altered"; a), ST.array_path(copied, key))
                @test ST.refused(ST.caught(() -> ST.read_back(copied, key, m.support)), name, "declares $(name)")
            end
        end

        @testset "a support's cell-area array with $(name) dropped refuses, naming it" for name in Provenance.REQUIRED_ATTRIBUTES
            mktempdir() do dir
                copied = store_copy(root, dir)
                area = joinpath(Provenance.support_directory(copied, m.support), Provenance.CELL_AREA)
                ST.edit_attributes!(a -> (delete!(a, name); a), area)
                @test ST.refused(ST.caught(() -> Provenance.read_cell_area(copied; support = m.support,
                                                                           backend = Backends.CPU())),
                                 name, "carries no $(name) attribute")
            end
        end

        @testset "the support's cell areas are held once at its radius" begin
            @test Provenance.read_cell_area(store; support = m.support, backend = Backends.CPU()) ==
                  [Mesh.at_radius(a, ST.radius(), 2) for a in m.geometry.cell_area]
            dir = Provenance.support_directory(store, m.support)
            @test Provenance.put_support!(store; support = m.support, level = m.level, geometry = m.geometry,
                                          chunk_level = 1) == dir
            @test manifest_of(store, key)["support"] == bytes2hex(collect(m.support.digest))
            other = ST.mesh(1)
            @test ST.refused(ST.caught(() -> Provenance.put_support!(store; support = m.support, level = other.level,
                                                                     geometry = m.geometry, chunk_level = 1)),
                             "level", "coordinates")
        end

        @testset "a manifest with $(name) dropped refuses, naming it" for name in Provenance.MANIFEST_KEYS
            mktempdir() do dir
                copied = store_copy(root, dir)
                path = joinpath(Provenance.object_directory(copied, key), Provenance.MANIFEST)
                manifest = TOML.parsefile(path)
                delete!(manifest, name)
                open(io -> TOML.print(io, manifest), path, "w")
                @test ST.refused(ST.caught(() -> ST.read_back(copied, key, m.support)), name, "holds no $(name)")
            end
        end

        @testset "an array table with $(name) dropped refuses, naming it" for name in Provenance.ARRAY_KEYS
            mktempdir() do dir
                copied = store_copy(root, dir)
                path = joinpath(Provenance.object_directory(copied, key), Provenance.MANIFEST)
                manifest = TOML.parsefile(path)
                delete!(manifest["arrays"]["surface_mass"], name)
                open(io -> TOML.print(io, manifest), path, "w")
                @test ST.refused(ST.caught(() -> ST.read_back(copied, key, m.support)), name, "holds no $(name)")
            end
        end

        @testset "a read declaring other attributes than the manifest records refuses" begin
            @test ST.refused(ST.caught(() -> ST.read_back(store, key, m.support; semantics = Fields.Intensive())),
                             "attributes", "Intensive")
            @test ST.refused(ST.caught(() -> ST.read_back(store, key, m.support; dimension = Dimensions.LENGTH)),
                             "attributes", "records attributes")
            later = Time.TimeSupport(Time.IntervalMean(), Time.Interval(3600.0, 7200.0))
            @test ST.refused(ST.caught(() -> ST.read_back(store, key, m.support; time = later)),
                             "attributes", "records attributes")
            @test ST.refused(ST.caught(() -> ST.read_back(store, key, ST.mesh(; r = 2 * ST.radius()).support)),
                             "support", "names support")
        end

        @testset "a field whose ledger is open refuses, naming the conserved quantity, and writes nothing" begin
            k2 = fixture_key(m; operator_version = 2)
            @test ST.refused(ST.caught(() -> ST.put(store, run, f; operator_version = 2,
                                                    ledgers = (store_ledger(:mass, 6.0),))),
                             "mass", "is open")
            classes = Fields.ClassLedgers{:water}((:ice, :liquid), (store_ledger(:water, 5.0), store_ledger(:water, 6.0)))
            @test ST.refused(ST.caught(() -> ST.put(store, run, f; operator_version = 2, ledgers = (classes,))),
                             "water", "class :liquid")
            columns = Fields.ColumnLedgers{:energy}([store_ledger(:energy, 5.0), store_ledger(:energy, 6.0)])
            @test ST.refused(ST.caught(() -> ST.put(store, run, f; operator_version = 2,
                                                    ledgers = (store_ledger(:mass, 5.0), columns))),
                             "energy", "column (2,)")
            @test !ispath(Provenance.object_directory(store, k2))

            @testset "positive control: the same forms closed are stored and recorded" begin
                closed = (store_ledger(:mass, 5.0),
                          Fields.ClassLedgers{:water}((:ice, :liquid), (store_ledger(:water, 5.0), store_ledger(:water, 5.0))),
                          Fields.ColumnLedgers{:energy}([store_ledger(:energy, 5.0), store_ledger(:energy, 5.0)]))
                k3, _ = ST.put(store, run, f; operator_version = 3, ledgers = closed)
                forms = [l["form"] for l in manifest_of(store, k3)["arrays"]["surface_mass"]["ledgers"]]
                @test forms == ["Ledger", "ClassLedgers", "ColumnLedgers"]
            end
        end

        @testset "a NotConserved is recorded as not conserved and never asked whether it is closed" begin
            endpoint = Time.TimeSupport(Time.EndpointState(), Time.Interval(0.0, 3600.0))
            fe = ST.field(m.support, run, data; time = endpoint)
            nc = Fields.not_conserved(:time_reduce, fe, Nothing)
            k4, _ = ST.put(store, run, fe; operator_version = 4, ledgers = (nc,))
            record = only(manifest_of(store, k4)["arrays"]["surface_mass"]["ledgers"])
            @test record["form"] == "NotConserved"
            @test record["sentence"] == nc.sentence

            @testset "positive control: asking a NotConserved whether it is closed refuses" begin
                e = ST.caught(() -> Fields.closed(nc))
                @test e isa Verdicts.Refusal && e.reason == nc.sentence
            end
        end

        @testset "a dirty code version refuses a keyed artifact and may write a scratch run" begin
            dirty = ST.code(dirty = true)
            drun = Provenance.mint_run_id()
            Provenance.open_run!(store; run = drun, code = dirty, system = SF.system())
            fd = ST.field(m.support, drun, data)
            dkey = fixture_key(m; operator_version = 1, code = dirty)
            @test ST.refused(ST.caught(() -> ST.put(store, drun, fd; code = dirty)), "code version", "uncommitted")
            @test !ispath(Provenance.object_directory(store, dkey))

            scratch = Provenance.ScratchRun(run = drun, code = dirty)
            skey, sfield = Provenance.put_field!(store, scratch; declaration = ST.declaration(), system = SF.system(),
                                                 profile = ST.profile(), inputs = (;), quantity = :surface_mass, operator_version = 1,
                                                 field = fd, ledgers = (ST.closed_ledger(),), chunk_level = 1,
                                                 values = Provenance.Amounts())
            @test skey == dkey
            @test Provenance.read_field(store, scratch, skey; quantity = :surface_mass, semantics = Fields.Extensive(),
                                        dimension = Dimensions.MASS, time = ST.interval(), support = m.support,
                                        backend = Backends.CPU()) == sfield
            @test !ispath(Provenance.object_directory(store, dkey))

            @testset "positive control: the clean key of the same field was admitted" begin
                @test isdir(Provenance.object_directory(store, key))
            end
        end

        @testset "an array is chunked by hierarchy ranges" begin
            L = ST.level()
            for chunk_level in 0:L
                k = fixture_key(m; operator_version = 10 + chunk_level)
                ST.put(store, run, f; operator_version = 10 + chunk_level, chunk_level = chunk_level)
                z = Zarr.zopen(ST.array_path(store, k), "r")
                per = z.metadata.chunks[1]
                @test per * Mesh.ncells(chunk_level) == Mesh.ncells(L)
                @test length(Zarr.chunkindices(z)) == Mesh.ncells(chunk_level)
                for (c, start) in enumerate(1:per:Mesh.ncells(L))
                    ancestors = collect(start:(start + per - 1))
                    for _ in chunk_level:(L - 1)
                        ancestors = Mesh.parent.(ancestors)
                    end
                    @test all(==(c), ancestors)
                end
                @test manifest_of(store, k)["arrays"]["surface_mass"]["chunk_level"] == chunk_level
            end
            @test ST.refused(ST.caught(() -> ST.put(store, run, f; operator_version = 20, chunk_level = L + 1)),
                             "chunk_level", "level $(L + 1)")
        end

        @testset "an array missing a chunk refuses, naming it" begin
            mktempdir() do dir
                copied = store_copy(root, dir)
                rm(joinpath(ST.array_path(copied, key), "0"))
                @test ST.refused(ST.caught(() -> ST.read_back(copied, key, m.support)), "chunk", "(1,)")
            end
        end

        @testset "the manifest names what the artifact rests on" begin
            manifest = manifest_of(store, key)
            @test manifest["kind"] == "field"
            @test manifest["key"] == bytes2hex(collect(key.digest))
            @test manifest["owner"] == "surface"
            @test manifest["run"] == string(run.uuid)
            @test manifest["code"]["tree"] == "2"^40
            @test manifest["code"]["dirty"] == false
            @test manifest["inputs"] == Dict{String,Any}()
            @test [p["declared"] for p in manifest["parameters"]] == [["planet", "mass"], ["stars", ":", "luminosity"]]
            @test only(manifest["parameters"][1]["values"])["value"]["type"] ==
                  string(typeof(SF.system().planet.mass))
            @test manifest["parameter_digest"] ==
                  bytes2hex(collect(Provenance.parameter_digest(ST.declaration(), SF.system())))
            @test [p["declared"] for p in manifest["profile"]] == [["fast_precision"], ["memory_ceiling"]]
            @test only(manifest["profile"][1]["values"])["value"] == "Float64"
            @test manifest["profile_digest"] ==
                  bytes2hex(collect(Provenance.profile_digest(ST.declaration(), ST.profile())))
            @test manifest["profile_digest"] != manifest["parameter_digest"]
            table = manifest["arrays"]["surface_mass"]
            @test table["attributes"]["semantics"] == "Extensive"
            @test table["attributes"]["interval"]["t1"]["whole"] == 3600
            @test table["axes"] == ["cells"]
            @test only(table["ledgers"])["form"] == "Ledger"
            run_record = TOML.parsefile(joinpath(Provenance.run_directory(store, run), Provenance.RUN_RECORD))
            @test run_record["code"] == manifest["code"]
            @test run_record["system"]["type"] == string(typeof(SF.system()))
        end

        @testset "a two-axis field stores its axes by Backends.LAYOUT" begin
            wide = ST.field(m.support, run, hcat(data, 2 .* data))
            k = fixture_key(m; operator_version = 30)
            ST.put(store, run, wide; operator_version = 30)
            @test manifest_of(store, k)["arrays"]["surface_mass"]["axes"] == ["cells", "levels"]
            @test Zarr.zopen(ST.array_path(store, k), "r").attrs[Provenance.AXES_ATTRIBUTE] == ["levels", "cells"]
            @test Fields.data(ST.read_back(store, k, m.support)) == hcat(data, 2 .* data)
        end

        @testset "the store refuses what it cannot place" begin
            @test ST.refused(ST.caught(() -> ST.put(store, run, f)), "artifact", "already holds")
            mktempdir() do dir
                bare = Provenance.Store(root = dir)
                @test ST.refused(ST.caught(() -> ST.put(bare, run, f; operator_version = 40)), "run", "records no run")
                Provenance.open_run!(bare; run = run, code = ST.code(), system = SF.system())
                @test ST.refused(ST.caught(() -> ST.put(bare, run, f; operator_version = 40)), "support", "holds no support")
                @test ST.refused(ST.caught(() -> Provenance.open_run!(bare; run = run, code = ST.code(), system = SF.system())),
                                 "run", "already recorded")
            end
            intensive = ST.field(m.support, run, data; semantics = Fields.Intensive())
            @test ST.refused(ST.caught(() -> ST.put(store, run, intensive; operator_version = 41)),
                             "surface_mass", "as Extensive")
            elsewhere = ST.field(m.support, run, data; writer = :elsewhere)
            @test ST.refused(ST.caught(() -> ST.put(store, run, elsewhere; operator_version = 41)), "owner", "elsewhere")
            @test ST.refused(ST.caught(() -> ST.put(store, run, stamped; operator_version = 41)), "origin", "stamped")
            @test ST.refused(ST.caught(() -> ST.put(store, run, f; operator_version = 41, ledgers = ST.closed_ledger())),
                             "ledgers", "tuple")
            @test ST.refused(ST.caught(() -> ST.read_back(store, fixture_key(m; operator_version = 42), m.support)),
                             "artifact", "holds no artifact")
            still = ST.field(m.support, run, data; time = Time.TimeSupport(Time.Static()))
            @test ST.refused(ST.caught(() -> ST.put(store, run, still; operator_version = 43)), "interval",
                             "Static, placed by none")
            at = ST.field(m.support, run, data; time = Time.TimeSupport(Time.Instantaneous(), Time.SimTime(3600.0)))
            @test ST.refused(ST.caught(() -> ST.put(store, run, at; operator_version = 43)), "interval",
                             "Instantaneous, placed by instant")
            given = (code = ST.code(), declaration = ST.declaration(), system = SF.system(), profile = ST.profile(),
                     inputs = (;), quantity = :surface_mass, operator_version = 44, field = f,
                     ledgers = (ST.closed_ledger(),), chunk_level = 1, values = Provenance.Amounts())
            @test ST.refused(ST.caught(() -> Provenance.put_field!(store, run; Base.structdiff(given, NamedTuple{(:profile,)})...)),
                             "profile", "missing")

            @testset "positive control: the same field over a later interval is another artifact" begin
                later = ST.field(m.support, run, data; time = Time.TimeSupport(Time.IntervalMean(), Time.Interval(3600.0, 7200.0)))
                klater, _ = ST.put(store, run, later)
                @test klater != key
                @test isdir(Provenance.object_directory(store, klater))
            end
            @test ST.refused(ST.caught(() -> Provenance.Store(root = "relative")), "root", "not an absolute path")
            @test ST.refused(ST.caught(() -> Provenance.record_value(sin)), "record", "has no record")
        end
    end
end
