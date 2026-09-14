using Test
using Fiddlybits: Coupling, Systems, Backends, Events, Verdicts, Fields, Mesh, Time,
                  Dimensions, Dispositions

# coupling.assembly_refusals, the declared graph handed to Systems, and the WorldState
# store, on fixture components: docs/plans/fiddlybits-52v.11-coupling.md, section
# "The state and its assembly".

isdefined(@__MODULE__, :SystemFixtures) ||
    include(joinpath(@__DIR__, "..", "system", "fixtures.jl"))
import .SystemFixtures as SF

module CouplingFixtures

using Fiddlybits: Coupling, Backends, Fields, Mesh, Time, Dimensions, Verdicts
using UUIDs: UUID

"A fixture component: its declaration and nothing else."
struct Component
    declaration::Coupling.Declaration
end

Coupling.declare(c::Component) = c.declaration

"A component type with no declare method."
struct Undeclared end

"The level every fixture component writes at unless it names another."
fixture_level() = 2

"A `Coupling.AtLevel` over `measure`."
at_level(measure = Coupling.NoMeasure()) = Coupling.AtLevel(measure = measure)

"A `Coupling.Read` of `q`, every other keyword overridable."
reading(q; level = fixture_level(), operator = at_level(), lagged = false,
        move = false) =
    Coupling.Read(quantity = q, level = level, operator = operator, lagged = lagged, move = move)

"A `Coupling.Write` of `q` with `semantics`, carrying `conserves`."
writing(q; semantics = Fields.Extensive(), conserves = ()) =
    Coupling.Write(quantity = q, semantics = semantics, conserves = conserves)

"A `Coupling.InitialCondition` of `q`."
initial(q; level = fixture_level(), backend = Backends.CPU()) =
    Coupling.InitialCondition(quantity = q, level = level, backend = backend)

"A fixture `Component` named `name`."
component(name; level = fixture_level(), reads = (), writes = (), stocks = (),
          system_fields = (), backend = Backends.CPU()) =
    Component(Coupling.Declaration(name = name, level = level, reads = reads, writes = writes,
                                   stocks = stocks, system_fields = system_fields,
                                   backend = backend))

"`Coupling.assemble` with the fixture's journal header."
assemble(components...; initial_conditions = ()) =
    Coupling.assemble(components...; initial_conditions = initial_conditions, sequence = 7,
                      instant = 0.0, tier = :fast)

"What calling `f` raises, or `nothing`."
caught(f) = try
    f()
    nothing
catch err
    err
end

"`true` when `e` is a `Verdicts.Refusal` of `quantity` whose reason contains `text`."
refused(e, quantity, text) =
    e isa Verdicts.Refusal && e.quantity == quantity && occursin(text, e.reason)

"""
    triad(; lagged)

The components `a`, `b` and `c`: `a` reads `z` and writes `x`, `b` reads `x` and writes
`y`, `c` reads `y` and writes `z`. The read of the quantity `lagged` is declared lagged
and that quantity given an initial condition; `lagged = nothing` lags no read. Returns
`(components, initial_conditions)`.
"""
function triad(; lagged)
    a = component(:a; reads = (reading(:z; lagged = lagged === :z),), writes = (writing(:x),))
    b = component(:b; reads = (reading(:x; lagged = lagged === :x),), writes = (writing(:y),))
    c = component(:c; reads = (reading(:y; lagged = lagged === :y),), writes = (writing(:z),))
    return (a, b, c), lagged === nothing ? () : (initial(lagged),)
end

"Every ordering of `(1, 2, 3)`."
orderings() = ((1, 2, 3), (1, 3, 2), (2, 1, 3), (2, 3, 1), (3, 1, 2), (3, 2, 1))

"A `Mesh.Support` at `level` of a hierarchy three levels deep."
function support(level)
    h = Mesh.hierarchy(3)
    l = h.levels[level + 1]
    g = Mesh.geometry(l, Mesh.stencils(l))
    return Mesh.Support(level, l, g; kind = :icosahedral_bisection, refinement = (),
                        radius = 1.0, element_type = :Float64, fractions = ())
end

"A mass `Fields.Field` on `s` over `data`, static unless another `time` is named."
field(s, data; semantics = Fields.Extensive(), time = Time.TimeSupport(Time.Static())) =
    Fields.Field(semantics = semantics, dimension = Dimensions.MASS, data = data, support = s,
                 time = time,
                 origin = Fields.unstamped(:fixture, UUID("5c0a1e00-0000-4000-8000-000000000011")))

end # module CouplingFixtures

import .CouplingFixtures as CF

@testset "coupling.assembly_refusals" begin
    @testset "a quantity with two declared writers refuses, naming both" begin
        a = CF.component(:a; writes = (CF.writing(:x),))
        b = CF.component(:b; writes = (CF.writing(:x),))
        r = CF.component(:r; reads = (CF.reading(:x),))
        @test CF.refused(CF.caught(() -> CF.assemble(a, b, r)), "x", "2 declared writers, a, b")
        @test CF.assemble(a, r) isa Coupling.Assembly
    end

    @testset "a read with no writer and no initial condition refuses" begin
        a = CF.component(:a; reads = (CF.reading(:ghost),), writes = (CF.writing(:x),))
        b = CF.component(:b; reads = (CF.reading(:x),))
        @test CF.refused(CF.caught(() -> CF.assemble(a, b)), "ghost",
                         "a reads ghost, which has no writer and no initial condition")
        @test CF.assemble(a, b; initial_conditions = (CF.initial(:ghost),)) isa Coupling.Assembly
        lagging = CF.component(:a; reads = (CF.reading(:x; lagged = true),), writes = (CF.writing(:x),))
        @test CF.refused(CF.caught(() -> CF.assemble(lagging, b)), "x",
                         "reads x lagged, and x has no initial condition")
    end

    @testset "a written quantity nothing reads refuses" begin
        a = CF.component(:a; writes = (CF.writing(:x), CF.writing(:void)))
        b = CF.component(:b; reads = (CF.reading(:x),))
        @test CF.refused(CF.caught(() -> CF.assemble(a, b)), "void", "a writes void, which nothing reads")
        @test CF.assemble(CF.component(:a; writes = (CF.writing(:x),)), b) isa Coupling.Assembly
        @test CF.refused(CF.caught(() -> CF.assemble(CF.component(:a; writes = (CF.writing(:x),)), b;
                                                     initial_conditions = (CF.initial(:unused),))),
                         "unused", "the initial condition of unused is read by nothing")
        @test CF.refused(CF.caught(() -> CF.assemble(CF.component(:a; writes = (CF.writing(:x),)), b;
                                                     initial_conditions = (CF.initial(:x),))),
                         "x", "read by no lagged read")
    end

    @testset "an intra-step cycle refuses with the cycle printed" begin
        components, _ = CF.triad(lagged = nothing)
        @test CF.refused(CF.caught(() -> CF.assemble(components...)), "intra-step cycle",
                         "a -(x)-> b -(y)-> c -(z)-> a")
        itself = CF.component(:s; reads = (CF.reading(:w),), writes = (CF.writing(:w),))
        @test CF.refused(CF.caught(() -> CF.assemble(itself)), "intra-step cycle", "s -(w)-> s")
    end

    @testset "positive control: the triad with one read lagged assembles, in the order the lag sets" begin
        for (lagged, expected) in ((:z, [:a, :b, :c]), (:x, [:b, :c, :a]), (:y, [:c, :a, :b]))
            components, initial_conditions = CF.triad(lagged = lagged)
            assembly = CF.assemble(components...; initial_conditions = initial_conditions)
            @test Coupling.order(assembly) == expected
        end
    end

    @testset "a device disagreement at a component boundary without a declared move refuses" begin
        g = CF.component(:g; writes = (CF.writing(:x),), backend = Backends.GPU())
        h = CF.component(:h; reads = (CF.reading(:x),))
        @test CF.refused(CF.caught(() -> CF.assemble(g, h)), "x",
                         "h runs on CPU and reads x, which g holds on GPU, with no declared move")
        moving = CF.component(:h; reads = (CF.reading(:x; move = true),))
        @test CF.assemble(g, moving) isa Coupling.Assembly
        @test CF.refused(CF.caught(() -> CF.assemble(CF.component(:g; writes = (CF.writing(:x),)), moving)),
                         "x", "h declares a move of x, which g holds on CPU")
        @test CF.refused(CF.caught(() -> CF.assemble(h; initial_conditions = (CF.initial(:x; backend = Backends.GPU()),))),
                         "x", "which its initial condition holds on GPU, with no declared move")
        lagging = CF.component(:g; reads = (CF.reading(:x; lagged = true, move = true),),
                               writes = (CF.writing(:x),), backend = Backends.GPU())
        @test CF.refused(CF.caught(() -> CF.assemble(lagging, h; initial_conditions = (CF.initial(:x),))),
                         "x", "the initial condition of x is on CPU and its writer g runs on GPU")
    end

    @testset "a move through AtLevel declares the measure its receipt is integrated under" begin
        water = (Coupling.Stock(conserved = :water, quantities = (:pool,)),)
        label = Fields.CategoricalLabel{(:a, :b)}()
        writer(; cover) = CF.component(:g; writes = (CF.writing(:pool; conserves = (:water,)),
                                                     CF.writing(:vapour; semantics = Fields.FluxDensity(), conserves = (:water,)),
                                                     CF.writing(:tag; semantics = label, conserves = ()),
                                                     (cover ? (CF.writing(:cover; semantics = label, conserves = (:water,)),) : ())...),
                                       stocks = water, backend = Backends.GPU())
        reader(; pool = CF.at_level(), vapour = CF.at_level(:primal_cell_area), tag = CF.at_level(), cover = nothing) =
            CF.component(:h; reads = (CF.reading(:pool; operator = pool, move = true),
                                      CF.reading(:vapour; operator = vapour, move = true),
                                      CF.reading(:tag; operator = tag, move = true),
                                      (cover === nothing ? () : (CF.reading(:cover; operator = cover, move = true),))...))
        placed(h; cover = false) = CF.assemble(writer(cover = cover), h)

        @test placed(reader()) isa Coupling.Assembly
        @test CF.refused(CF.caught(() -> placed(reader(vapour = CF.at_level()))), "vapour",
                         "h moves vapour, which g writes as FluxDensity carrying water, through AtLevel declaring no measure")
        @test CF.refused(CF.caught(() -> placed(reader(pool = CF.at_level(:primal_cell_area)))), "pool",
                         "h declares the primal_cell_area measure on its move of pool, which g writes as Extensive carrying water")
        @test CF.refused(CF.caught(() -> placed(reader(tag = CF.at_level(:dual_area)))), "tag",
                         "a move of a quantity carrying no conserved quantity")
        @test CF.refused(CF.caught(() -> placed(reader(cover = CF.at_level(:primal_cell_area)); cover = true)), "cover",
                         "a CategoricalLabel{(:a, :b)} field holds no amount a receipt ledger closes")
        lagged = CF.component(:g; reads = (CF.reading(:pool; operator = CF.at_level(:primal_cell_area), lagged = true),),
                              writes = (CF.writing(:pool; conserves = (:water,)),), stocks = water)
        @test CF.refused(CF.caught(() -> CF.assemble(lagged; initial_conditions = (CF.initial(:pool),))), "pool",
                         "g declares the primal_cell_area measure on its read of pool through AtLevel, which is not a move")
    end

    @testset "a component that cannot report a stock refuses" begin
        w = CF.component(:w; writes = (CF.writing(:runoff; conserves = (:water,)),))
        r = CF.component(:r; reads = (CF.reading(:runoff),))
        @test CF.refused(CF.caught(() -> CF.assemble(w, r)), "w",
                         "w writes runoff, which carries water, and cannot report a stock of water")
        soil = Coupling.Stock(conserved = :water, quantities = (:soil_water,))
        stocked = CF.component(:w; reads = (CF.reading(:soil_water; lagged = true),),
                               writes = (CF.writing(:runoff; conserves = (:water,)),
                                         CF.writing(:soil_water; conserves = (:water,))),
                               stocks = (soil,))
        @test CF.assemble(stocked, r; initial_conditions = (CF.initial(:soil_water),)) isa Coupling.Assembly
        elsewhere = CF.component(:w; writes = (CF.writing(:runoff; conserves = (:water,)),), stocks = (soil,))
        @test CF.refused(CF.caught(() -> CF.assemble(elsewhere, r)), "w",
                         "w declares its stock of water in soil_water, which it does not write")
    end

    @testset "a read whose operator does not reach its level refuses" begin
        w = CF.component(:w; writes = (CF.writing(:x),))
        coarse(op) = CF.component(:r; level = 1, reads = (CF.reading(:x; level = 1, operator = op),))
        fine(op) = CF.component(:r; level = 3, reads = (CF.reading(:x; level = 3, operator = op),))
        coarsen = Coupling.Coarsen(rule = Coupling.RuleOfSemantics(), measure = Coupling.NoMeasure())
        refine = Coupling.Refine(measure = :primal_cell_area)
        @test CF.refused(CF.caught(() -> CF.assemble(w, coarse(CF.at_level()))), "x",
                         "r reads x at level 1 through AtLevel, and w holds x at level 2, which a read reaches through Coarsen")
        @test CF.assemble(w, coarse(coarsen)) isa Coupling.Assembly
        @test CF.refused(CF.caught(() -> CF.assemble(w, fine(coarsen))), "x", "which a read reaches through Refine")
        @test CF.assemble(w, fine(refine)) isa Coupling.Assembly
        @test CF.refused(CF.caught(() -> CF.assemble(w, CF.component(:r; reads = (CF.reading(:x; operator = refine),)))),
                         "x", "which a read reaches through AtLevel")
    end

    @testset "arrival order never reaches a result" begin
        lagged, initial_conditions = CF.triad(lagged = :x)
        orders = [Coupling.order(CF.assemble(map(i -> lagged[i], p)...; initial_conditions = initial_conditions))
                  for p in CF.orderings()]
        @test all(==([:b, :c, :a]), orders)
        tied = (CF.component(:q; writes = (CF.writing(:v),)), CF.component(:p; writes = (CF.writing(:u),)),
                CF.component(:sink; reads = (CF.reading(:u), CF.reading(:v))))
        orders = [Coupling.order(CF.assemble(map(i -> tied[i], p)...)) for p in CF.orderings()]
        @test all(==([:p, :q, :sink]), orders)
        two_cycles = (CF.component(:c; reads = (CF.reading(:v),), writes = (CF.writing(:u),)),
                      CF.component(:d; reads = (CF.reading(:u),), writes = (CF.writing(:v),)),
                      CF.component(:a; reads = (CF.reading(:y),), writes = (CF.writing(:x),)),
                      CF.component(:b; reads = (CF.reading(:x),), writes = (CF.writing(:y),)))
        @test CF.refused(CF.caught(() -> CF.assemble(two_cycles...)), "intra-step cycle", "a -(x)-> b -(y)-> a")
        doubled = (CF.component(:b; writes = (CF.writing(:x),)), CF.component(:a; writes = (CF.writing(:x),)),
                   CF.component(:r; reads = (CF.reading(:x),)))
        reasons = [CF.caught(() -> CF.assemble(map(i -> two_cycles[i], p)...)).reason
                   for p in ((1, 2, 3, 4), (3, 4, 1, 2), (4, 3, 2, 1), (2, 1, 4, 3))]
        @test all(==(first(reasons)), reasons)
        reasons = [CF.caught(() -> CF.assemble(map(i -> doubled[i], p)...)).reason for p in CF.orderings()]
        @test all(==(first(reasons)), reasons)
    end

    @testset "every refusal past the keywords is emitted as a refusal event" begin
        events = Any[]
        Events.sink!(e -> push!(events, e))
        try
            cyclic, _ = CF.triad(lagged = nothing)
            e = CF.caught(() -> CF.assemble(cyclic...))
            @test length(events) == 1
            event = only(events)
            @test event.header.kind === Events.Refusal()
            @test event.header.component == "Coupling"
            @test event.header.sequence == 7
            @test event.header.tier === :fast
            @test event.payload === e
            empty!(events)
            lagged, initial_conditions = CF.triad(lagged = :z)
            CF.assemble(lagged...; initial_conditions = initial_conditions)
            @test isempty(events)
        finally
            Events.sink!(Events.noop_sink)
        end
    end

    @testset "a declaration and an assembly refuse what they cannot hold" begin
        at = CF.at_level()
        @test CF.refused(CF.caught(() -> Coupling.Read(quantity = :x, level = 2, operator = at, lagged = false)),
                         "move", "missing")
        @test CF.refused(CF.caught(() -> Coupling.AtLevel()), "measure", "missing")
        @test CF.refused(CF.caught(() -> Coupling.AtLevel(measure = :area)), "measure", "not one of")
        @test CF.refused(CF.caught(() -> Coupling.Write(quantity = :x, conserves = ())), "semantics", "missing")
        @test CF.refused(CF.caught(() -> Coupling.Write(quantity = :x, semantics = Fields.Extensive, conserves = ())),
                         "semantics", "Semantics")
        @test CF.refused(CF.caught(() -> CF.reading(:x; level = -1)), "level", "lies outside")
        @test CF.refused(CF.caught(() -> CF.reading(:x; lagged = 0)), "lagged", "Bool")
        @test CF.refused(CF.caught(() -> CF.component(:a; system_fields = ((:planet, "mass"),))), "path", "step")
        @test CF.refused(CF.caught(() -> CF.component(:a; writes = (CF.writing(:x), CF.writing(:x)))),
                         "writes", "twice")
        @test CF.refused(CF.caught(() -> CF.writing(:x; conserves = (:heat,))), "conserves", "not one of")
        @test CF.refused(CF.caught(() -> Coupling.Coarsen(rule = Coupling.RuleOfSemantics(), measure = :area)),
                         "measure", "not one of")
        @test CF.refused(CF.caught(() -> Coupling.Stock(conserved = :water, quantities = ())), "quantities", "no quantity")
        @test CF.refused(CF.caught(() -> CF.assemble(CF.Undeclared())), string(CF.Undeclared), "no declare method")
        a = CF.component(:a; writes = (CF.writing(:x),))
        @test CF.refused(CF.caught(() -> CF.assemble(a, a, CF.component(:r; reads = (CF.reading(:x),)))),
                         "a", "two components are named a")
        @test CF.refused(CF.caught(() -> Coupling.assemble(a; initial_conditions = (), sequence = 1, instant = 0.0)),
                         "tier", "missing")
    end
end

@testset "coupling.declared_graph" begin
    value = Dispositions.value
    surface = CF.component(:surface; reads = (CF.reading(:x; lagged = true),), writes = (CF.writing(:x),),
                           system_fields = ((:planet, :mass), (:planet, :rotation, :period)))
    stellar = CF.component(:stellar; reads = (CF.reading(:x),), system_fields = ((:stars, :, :luminosity),))
    assembly = CF.assemble(surface, stellar; initial_conditions = (CF.initial(:x),))
    graph = Coupling.declared_graph(assembly)

    @testset "the graph is each component's declared system paths" begin
        @test graph == Dict(:surface => Set{Tuple}([(:planet, :mass), (:planet, :rotation, :period)]),
                            :stellar => Set{Tuple}([(:stars, :, :luminosity)]))
    end

    @testset "Systems.affected reads it" begin
        @test Systems.affected((:planet, :mass), graph) == Set([:surface])
        @test Systems.affected((:stars, 2, :luminosity), graph) == Set([:stellar])
        @test isempty(Systems.affected((:planet, :obliquity), graph))
    end

    @testset "Systems.dependency_subset reads it, and fails a reader outside it" begin
        readers = Dict{Symbol,Any}(
            :surface => s -> (value(s.planet.mass), value(s.planet.rotation.period)),
            :stellar => s -> sum(value(star.luminosity) for star in s.stars))
        @test Systems.dependency_subset(readers, graph, SF.two_star_system()).verdict === Verdicts.PASS()
        readers[:surface] = s -> value(s.planet.mass) * sin(value(s.planet.obliquity))
        r = Systems.dependency_subset(readers, graph, SF.system())
        @test r.verdict === Verdicts.FAIL()
        @test r.undeclared[:surface] == Set{Tuple}([(:planet, :obliquity)])
    end
end

@testset "coupling.world_state" begin
    fine, coarse = CF.support(2), CF.support(1)
    n = Mesh.ncells(2)
    coarsen = Coupling.Coarsen(rule = Coupling.RuleOfSemantics(), measure = Coupling.NoMeasure())
    w = CF.component(:w; reads = (CF.reading(:x; lagged = true),), writes = (CF.writing(:x),))
    c = CF.component(:c; level = 1, reads = (CF.reading(:x; level = 1, operator = coarsen),))
    d = CF.component(:d; reads = (CF.reading(:x),))
    assembly = CF.assemble(d, c, w; initial_conditions = (CF.initial(:x),))
    @test Coupling.order(assembly) == [:w, :c, :d]

    start = CF.field(fine, ones(n))
    next = CF.field(fine, fill(2.0, n))
    received = CF.field(coarse, ones(Mesh.ncells(1)))

    @testset "the initial fields are exactly the initial conditions, at their placement" begin
        @test CF.refused(CF.caught(() -> Coupling.WorldState(assembly; initial = NamedTuple())), "x", "given no field")
        @test CF.refused(CF.caught(() -> Coupling.WorldState(assembly; initial = (x = start, y = start))),
                         "y", "has no initial condition")
        @test CF.refused(CF.caught(() -> Coupling.WorldState(assembly; initial = (x = received,))),
                         "x", "level 2 is declared")
        @test CF.refused(CF.caught(() -> Coupling.WorldState(assembly; initial = (x = CF.field(fine, view(ones(n), 1:n)),))),
                         "x", "and CPU holds a Array")
        @test CF.refused(CF.caught(() -> Coupling.WorldState(assembly; initial = (x = CF.field(fine, ones(n); semantics = Fields.FluxDensity()),))),
                         "x", "which w declares it writes as Extensive")
    end

    state = Coupling.WorldState(assembly; initial = (x = start,))

    @testset "nothing is read or written before a step begins" begin
        @test CF.refused(CF.caught(() -> Coupling.read_quantity(state, :w, :x)), "step", "no step has begun")
        @test CF.refused(CF.caught(() -> Coupling.write_quantity!(state, :w, :x, next)), "step", "no step has begun")
    end

    Coupling.begin_step!(state)

    @testset "a read is served as declared" begin
        @test Coupling.read_quantity(state, :w, :x) === start
        @test CF.refused(CF.caught(() -> Coupling.read_quantity(state, :d, :x)), "x",
                         "its writer w has not written it in this step")
        @test CF.refused(CF.caught(() -> Coupling.read_quantity(state, :d, :y)), "y", "d declares no read of y")
        @test CF.refused(CF.caught(() -> Coupling.read_quantity(state, :nobody, :x)), "nobody", "not a component")
    end

    @testset "a write is refused unless its writer, placement, type and array are the declared ones" begin
        @test CF.refused(CF.caught(() -> Coupling.write_quantity!(state, :d, :x, next)), "x",
                         "d writes x, whose declared writer is w")
        @test CF.refused(CF.caught(() -> Coupling.write_quantity!(state, :w, :x, CF.field(fine, start.data))),
                         "x", "held when the step began")
        @test CF.refused(CF.caught(() -> Coupling.write_quantity!(state, :w, :x, CF.field(fine, fill(2.0, n); semantics = Fields.Intensive()))),
                         "x", "which w declares it writes as Extensive")
        interval_mean = Time.TimeSupport(Time.IntervalMean(), Time.Interval(0.0, 1.0))
        @test CF.refused(CF.caught(() -> Coupling.write_quantity!(state, :w, :x, CF.field(fine, fill(2.0, n); time = interval_mean))),
                         "x", "was first placed")
        @test CF.refused(CF.caught(() -> Coupling.write_quantity!(state, :w, :x, received)), "x", "level 2 is declared")
        Coupling.write_quantity!(state, :w, :x, next)
        @test Coupling.read_quantity(state, :d, :x) === next
        @test Coupling.read_quantity(state, :w, :x) === start
        @test CF.refused(CF.caught(() -> Coupling.write_quantity!(state, :w, :x, CF.field(fine, fill(3.0, n)))),
                         "x", "already written x in this step")
    end

    @testset "a crossing read is served only from what is received for it" begin
        @test Coupling.source_field(state, :c, :x) === next
        @test CF.refused(CF.caught(() -> Coupling.read_quantity(state, :c, :x)), "x", "nothing has been received")
        @test CF.refused(CF.caught(() -> Coupling.receive!(state, :d, :x, next)), "x", "not a crossing")
        @test CF.refused(CF.caught(() -> Coupling.receive!(state, :c, :x, next)), "x", "level 1 is declared")
        Coupling.receive!(state, :c, :x, received)
        @test Coupling.read_quantity(state, :c, :x) === received
        @test CF.refused(CF.caught(() -> Coupling.receive!(state, :c, :x, received)), "x", "already received")
    end

    @testset "a new step reads what the last one wrote as lagged, and receives afresh" begin
        Coupling.begin_step!(state)
        @test Coupling.read_quantity(state, :w, :x) === next
        @test CF.refused(CF.caught(() -> Coupling.read_quantity(state, :c, :x)), "x", "nothing has been received")
        @test CF.refused(CF.caught(() -> Coupling.read_quantity(state, :d, :x)), "x", "has not written it")
    end
end
