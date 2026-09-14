using Test
using UUIDs: UUIDs, UUID
using Fiddlybits: Fiddlybits, Provenance, Coupling, Systems, Backends, Mesh, Verdicts, Dispositions

# provenance.key_stability and the key of docs/plans/fiddlybits-52v.6-provenance.md,
# section "The key"; decision 0010; docs/imports/sha-uuids.md.

isdefined(@__MODULE__, :SystemFixtures) ||
    include(joinpath(@__DIR__, "..", "system", "fixtures.jl"))
import .SystemFixtures as SF

module KeyFixtures

using Fiddlybits: Provenance, Coupling, Systems, Backends, Mesh, Verdicts
using SHA: sha256

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

"The quantity the fixture component `name` writes."
output(name) = Symbol(name, :_out)

"A `Coupling.Declaration` named `name` over `system_fields`, reading `reads`, writing its `output` unless `writes` says otherwise."
declaration(name, system_fields; reads = (), writes = (output(name),), backend = Backends.CPU()) =
    Coupling.Declaration(
        name = name, level = level(),
        reads = Tuple(Coupling.Read(quantity = q, level = level(), operator = Coupling.AtLevel(),
                                    lagged = false, move = false) for q in reads),
        writes = Tuple(Coupling.Write(quantity = q, conserves = ()) for q in writes),
        stocks = (), system_fields = system_fields, backend = backend)

"The paths each fixture writer declares."
declared() = (
    surface = ((:planet, :mass), (:planet, :volumetric_mean_radius), (:planet, :rotation, :period)),
    stellar = ((:stars, :, :luminosity),),
    orbital = ((:planet, :mass), (:stars, :, :mass), (:orbits, :planet, :semi_major_axis),
               (:orbits, :planet, :primary)),
    crustal = ((:planet, :lithosphere),),
    lunar = ((:moons, :, :mass),),
    spectral = ((:stars, :, :spectrum), (:moons, :, :reflectance)),
    bookkeeping = ((:numerics,), (:inventories,)),
    idle = ())

"The names of the fixture writers."
writers() = collect(keys(declared()))

"""
    assembly()

The assembled fixture: one component per entry of `declared()` writing its `output`, and
a `:sink` that reads every output, writes nothing and declares no path.
"""
function assembly()
    components = [Component(declaration(n, p)) for (n, p) in pairs(declared())]
    sink = Component(declaration(:sink, (); reads = Tuple(output(n) for n in writers()), writes = ()))
    return Coupling.assemble(components..., sink; initial_conditions = (), sequence = 1,
                             instant = 0.0, tier = :fast)
end

"The key of the component `name` of `a` on `system` at `support`; `kw` replaces any other keyword."
key(a::Coupling.Assembly, name, system, support; kw...) = Provenance.ArtifactKey(; merge(
    (code = code(), declaration = Coupling.declaration(a, name), system = system, inputs = (;),
     quantity = output(name), support = support, operator_version = 1), values(kw))...)

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

"`system` with every float replaced by the parse of `printer` of it."
reparsed(system, printer) = foldl((s, (p, x)) -> replace_at(s, p, y -> parse(typeof(y), printer(y))),
                                  [(p, x) for (p, x) in leaves(system) if x isa AbstractFloat];
                                  init = system)

"The positive control of the text round trip: SHA-256 over the printed decimal of every float in `system`, printed by `printer`."
decimal_digest(system, printer) =
    sha256(join([printer(x) for (p, x) in leaves(system) if x isa AbstractFloat], "\n"))

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

    @testset "the key is identical after every float of the parameter subset is printed and reparsed" begin
        for system in (SF.system(), SF.system(Float32), SF.two_star_system())
            for printer in (KF.shortest, KF.expanded)
                round_tripped = KF.reparsed(system, printer)
                for n in KF.writers()
                    @test KF.key(a, n, round_tripped, s1) == KF.key(a, n, system, s1)
                end
            end

            @testset "positive control: a hash over printed decimal moves on the text round trip" begin
                @test KF.decimal_digest(system, KF.shortest) !=
                      KF.decimal_digest(KF.reparsed(system, KF.expanded), KF.expanded)
            end
        end
    end

    @testset "flipping each leaf by reflection moves exactly the keys of the components that declared it" begin
        graph = Coupling.declared_graph(a)
        writers = Set(KF.writers())
        for system in (SF.two_star_system(),)
            base = Dict(n => KF.key(a, n, system, s1) for n in writers)
            moved_any, moved_none = false, false
            for (path, x) in KF.leaves(system)
                flipped = KF.replace_at(system, path, KF.flip)
                moved = Set(n for n in writers if KF.key(a, n, flipped, s1) != base[n])
                expected = intersect(Systems.affected(path, graph), writers)
                @test moved == expected
                moved_any |= !isempty(moved)
                moved_none |= isempty(moved)
            end

            @testset "positive control: some flip moves a key and some flip moves none" begin
                @test moved_any
                @test moved_none
            end
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
        d = KF.declaration(:surface, KF.declared().surface)
        @test KF.key(a, :surface, system, s1; declaration = d) == base
        renamed = KF.declaration(:elsewhere, KF.declared().surface; writes = (:surface_out,))
        @test KF.key(a, :surface, system, s1; declaration = renamed) != base
        other_quantity = KF.declaration(:surface, KF.declared().surface; writes = (:surface_out, :other_out))
        @test KF.key(a, :surface, system, s1; declaration = other_quantity) == base
        @test KF.key(a, :surface, system, s1; declaration = other_quantity, quantity = :other_out) != base
        bitwise = KF.declaration(:surface, KF.declared().surface; backend = Backends.CPU(bitwise = true))
        @test KF.key(a, :surface, system, s1; declaration = bitwise) != base
        pinned = KF.declaration(:surface, KF.declared().surface; backend = Backends.CPU(8))
        @test KF.key(a, :surface, system, s1; declaration = pinned) == base

        @testset "the commit is a locator and not part of the key" begin
            @test KF.key(a, :surface, system, s1; code = KF.code(commit = "5"^40)) == base
        end
    end

    @testset "the declared order of paths and of input keys reaches no key" begin
        system = SF.system()
        forward = KF.declaration(:orbital, KF.declared().orbital)
        backward = KF.declaration(:orbital, reverse(KF.declared().orbital))
        @test Provenance.parameter_digest(forward, system) == Provenance.parameter_digest(backward, system)
        @test KF.key(a, :orbital, system, s1; declaration = backward) == KF.key(a, :orbital, system, s1)

        x, y = KF.key(a, :surface, system, s1), KF.key(a, :stellar, system, s1)
        reader = KF.declaration(:reader, (); reads = (:surface_out, :stellar_out))
        k(inputs) = Provenance.ArtifactKey(code = KF.code(), declaration = reader, system = system,
                                           inputs = inputs, quantity = :reader_out, support = s1,
                                           operator_version = 1)
        @test k((surface_out = x, stellar_out = y)) == k((stellar_out = y, surface_out = x))

        @testset "positive control: input keys swapped between names, and a path removed, move the key" begin
            @test k((surface_out = y, stellar_out = x)) != k((surface_out = x, stellar_out = y))
            fewer = KF.declaration(:orbital, KF.declared().orbital[2:end])
            @test KF.key(a, :orbital, system, s1; declaration = fewer) != KF.key(a, :orbital, system, s1)
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
        k(; kw...) = Provenance.ArtifactKey(; merge(
            (code = KF.code(), declaration = reader, system = system, inputs = (surface_out = x,),
             quantity = :reader_out, support = s1, operator_version = 1), values(kw))...)
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
        @test KF.refused(KF.caught(() -> Provenance.ArtifactKey(code = KF.code(), declaration = reader,
                                                                system = system, inputs = (surface_out = x,),
                                                                quantity = :reader_out, support = s1)),
                         "operator_version", "missing")
        unreachable = KF.declaration(:reader, ((:stars, 2, :mass),); reads = (:surface_out,))
        @test KF.refused(KF.caught(() -> k(declaration = unreachable)), "system_fields", "does not reach")
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
            downstream = Provenance.ArtifactKey(code = KF.code(), declaration = reader, system = system,
                                                inputs = (surface_out = dirty,), quantity = :reader_out,
                                                support = s1, operator_version = 1)
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
