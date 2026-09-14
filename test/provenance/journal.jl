using Test
using TOML: TOML
using Fiddlybits: Fiddlybits, Provenance, Events, Verdicts, Coupling, Connectivity, Fields, Mesh,
                  Backends, Time, Dimensions, Systems

# provenance.journal_is_inert and provenance.event_vocabulary_closed, and the journal writer of
# docs/plans/fiddlybits-52v.6-provenance.md, section "The journal"; decisions 0042 and 0046.

isdefined(@__MODULE__, :SystemFixtures) ||
    include(joinpath(@__DIR__, "..", "system", "fixtures.jl"))
isdefined(@__MODULE__, :ConnectivityFixtures) ||
    include(joinpath(@__DIR__, "..", "connectivity", "fixtures.jl"))

module JournalCase

using Fiddlybits: Provenance, Events, Verdicts, Coupling, Connectivity, Fields, Mesh, Backends, Time,
                  Dimensions, Systems
using UUIDs: UUID
import ..SystemFixtures as SF
import ..ConnectivityFixtures as CF

# ---------------------------------------------------------------- the coupled fixture

"A fixture component: its declaration and nothing else."
struct Component
    declaration::Coupling.Declaration
end

Coupling.declare(c::Component) = c.declaration

"Levels 2 and 1 of a hierarchy two levels deep: each support and its primal cell areas."
function mesh()
    h = Mesh.hierarchy(2)
    function built(level)
        l = h.levels[level + 1]
        g = Mesh.geometry(l, Mesh.stencils(l))
        s = Mesh.Support(level, l, g; kind = :icosahedral_bisection, refinement = (), radius = 1.0,
                         element_type = :Float64, fractions = ())
        return s, g.cell_area
    end
    fine, fine_area = built(2)
    coarse, coarse_area = built(1)
    return (fine = fine, coarse = coarse, fine_area = fine_area, coarse_area = coarse_area)
end

reading(q, level, operator; lagged = false) =
    Coupling.Read(quantity = q, level = level, operator = operator, lagged = lagged, move = false)
at_level() = Coupling.AtLevel(measure = Coupling.NoMeasure())
by_sum() = Coupling.Coarsen(rule = Coupling.RuleOfSemantics(), measure = Coupling.NoMeasure())
by_area_mean() = Coupling.Coarsen(rule = Coupling.RuleOfSemantics(), measure = :primal_cell_area)
by_area_split() = Coupling.Refine(measure = :primal_cell_area)
water(q, semantics) = Coupling.Write(quantity = q, semantics = semantics, conserves = (:water,))
water_stock(qs...) = (Coupling.Stock(conserved = :water, quantities = qs),)
initial(q, level) = Coupling.InitialCondition(quantity = q, level = level, backend = Backends.CPU())

component(name; level, reads, writes, stocks) =
    Component(Coupling.Declaration(name = name, level = level, reads = reads, writes = writes,
                                   stocks = stocks, system_fields = (), profile_fields = (),
                                   backend = Backends.CPU()))

land() = component(:land; level = 2,
                   reads = (reading(:soil_water, 2, at_level(); lagged = true),
                            reading(:precipitation, 2, by_area_split(); lagged = true)),
                   writes = (water(:runoff, Fields.Extensive()), water(:soil_water, Fields.Extensive()),
                             water(:evaporation, Fields.FluxDensity())),
                   stocks = water_stock(:soil_water))
river() = component(:river; level = 1,
                    reads = (reading(:runoff, 1, by_sum()), reading(:soil_water, 1, by_sum()),
                             reading(:channel, 1, at_level(); lagged = true)),
                    writes = (water(:channel, Fields.Extensive()),), stocks = water_stock(:channel))
air() = component(:air; level = 1,
                  reads = (reading(:evaporation, 1, by_area_mean()),
                           reading(:humidity, 1, at_level(); lagged = true)),
                  writes = (water(:humidity, Fields.Extensive()), water(:precipitation, Fields.FluxDensity())),
                  stocks = water_stock(:humidity))

"The initial conditions of the fixture assembly."
initial_conditions() = (initial(:soil_water, 2), initial(:channel, 1), initial(:humidity, 1),
                        initial(:precipitation, 1))

"The fixture assembly of `land`, `river` and `air`."
assembly() = Coupling.assemble(land(), river(), air(); initial_conditions = initial_conditions(),
                               sequence = 2, instant = 0.0, tier = :fast)

field(support, data, semantics, time) =
    Fields.Field(semantics = semantics, dimension = Dimensions.MASS, data = data, support = support,
                 time = time, origin = Fields.unstamped(:fixture, UUID("6e1c0a2e-0000-4000-8000-000000000607")))

"`n` values `1 + sin(phase * i) / 2`."
varying(n, phase) = [1.0 + 0.5 * sin(phase * i) for i in 1:n]

"""
    stepped(a, m, window)

A `WorldState` of `a` with its first step begun over the interval from 0 to `window` and
`land`'s three writes placed. Returns `(state, interval)`.
"""
function stepped(a, m, window)
    interval = Time.Interval(0.0, window)
    before = Time.Interval(-window, 0.0)
    nf, nc = length(m.fine_area), length(m.coarse_area)
    endpoint(i) = Time.TimeSupport(Time.EndpointState(), i)
    state = Coupling.WorldState(a; initial = (
        channel = field(m.coarse, varying(nc, 0.7), Fields.Extensive(), endpoint(before)),
        humidity = field(m.coarse, varying(nc, 1.1), Fields.Extensive(), endpoint(before)),
        precipitation = field(m.coarse, varying(nc, 1.9), Fields.FluxDensity(),
                              Time.TimeSupport(Time.IntervalMean(), before)),
        soil_water = field(m.fine, varying(nf, 2.3), Fields.Extensive(), endpoint(before))))
    Coupling.begin_step!(state)
    Coupling.write_quantity!(state, :land, :runoff,
                             field(m.fine, window .* varying(nf, 3.0), Fields.Extensive(),
                                   Time.TimeSupport(Time.IntervalAccumulation(), interval)))
    Coupling.write_quantity!(state, :land, :soil_water,
                             field(m.fine, varying(nf, 2.9), Fields.Extensive(), endpoint(interval)))
    Coupling.write_quantity!(state, :land, :evaporation,
                             field(m.fine, varying(nf, 3.7), Fields.FluxDensity(),
                                   Time.TimeSupport(Time.IntervalMean(), interval)))
    return state, interval
end

"The exchange from `land` to `river` of runoff and soil water at the coarse support."
function to_river(m)
    draw = (identity, counter) -> Provenance.philox_draw(20260913, m.coarse, 0, 1, 0, counter)[1]
    crossing(q) = Coupling.Crossing(quantity = q, support = m.coarse, measure = Coupling.NoMeasure(),
                                    legend = Coupling.NoLegend())
    return Coupling.Exchange(from = :land, to = :river, crossings = (crossing(:runoff), crossing(:soil_water)),
                             conserved = (:water,), replayed = (), recomputed = (),
                             classification = Coupling.Classification(false_alarm = 1 // 100,
                                                                      permutations = 1000, draw = draw))
end

# ---------------------------------------------------------------- the loops

"The profile the fixture loops bind their exit brackets from."
profile() = Systems.Profile(
    label = :journal, system = SF.system(Float64),
    components = Systems.Absent(argument = "the journal fixture has no component"),
    radiation = Systems.Absent(argument = "the journal fixture has no radiation"),
    fast_precision = Float64,
    slow_tier = Systems.Absent(argument = "the journal fixture has no slow tier"),
    memory_ceiling = SF.irreducible(1024, Dimensions.DIMENSIONLESS),
    daily_fallback_interval = Systems.Absent(argument = "the journal fixture has no vegetation tier"),
    exit_brackets = Tuple(Systems.ExitBracket(loop = name, criterion = :alternation,
                                              normalisation = :aa_scatter,
                                              tolerance = SF.irreducible(1 / 16, Dimensions.DIMENSIONLESS))
                          for name in (:map, :unseen)))

"""
    antitone_loop(p; name, damping, cap, sampled_at)

An antitone loop `name` at level 5 on the map `x -> 8 - damping * (x - 8)` from 12, its
samples measured at `sampled_at`, exiting on the alternation of `x`.
"""
antitone_loop(p; name, damping, cap, sampled_at) = Coupling.FixedPointLoop(
    name = name,
    body = (state, i) -> Coupling.Iteration(state = state, instant = i, samples = (
        x = Coupling.Sample(value = 8 + 4 * (-damping)^i, level = sampled_at),
        offset = Coupling.Sample(value = 4 * (-damping)^i, level = sampled_at),
        scatter = Coupling.Sample(value = 1, level = sampled_at))),
    exit = (Coupling.Straddle(criterion = :alternation, quantity = :x, overshoot = :offset,
                              scale = :scatter, normalisation = :aa_scatter),),
    monotonicity = Coupling.Antitone(), cap = cap, floor = 2, level = 5, profile = p)

# ---------------------------------------------------------------- the case

"The connectivity graphs before and after the strait closes."
graphs() = (open = CF.graph(CF.elevation()), closed = CF.graph(CF.edited(first.(CF.STRAIT), CF.LAND)))

"A clean fixture `CodeVersion`."
code() = Provenance.CodeVersion(commit = "1"^40, tree = "2"^40, manifest = "3"^40, julia = v"1.12.7",
                                dirty = false)

"What calling `f` raises, or `nothing`."
caught(f) = try
    f()
    nothing
catch err
    err
end

"A `Verdicts.Refusal` calling `f` raises, or what it returns; any other exception is rethrown."
raised(f) = try
    f()
catch err
    err isa Verdicts.Refusal || rethrow()
    err
end

"""
    content_keys(a, m, system; interval, operator_version)

`(component, quantity, digest)` of the `ArtifactKey` of every write of `a` over `interval`
under `profile()` in evaluation order, each read's input the key of its writer's write
when read in the step and of its initial condition when lagged; an initial condition's
key is that of a declaration of its own name writing it with no reads.
"""
function content_keys(a, m, system; interval, operator_version)
    support(level) = level == m.fine.level ? m.fine : m.coarse
    key(d, q, inputs) = Provenance.ArtifactKey(code = code(), declaration = d, system = system,
                                               profile = profile(), inputs = inputs, quantity = q,
                                               support = support(d.level), interval = interval,
                                               operator_version = operator_version)
    initial_keys = Dict{Symbol,Provenance.ArtifactKey}()
    for ic in initial_conditions()
        d = Coupling.Declaration(name = Symbol(:initial_, ic.quantity), level = ic.level, reads = (),
                                 writes = (Coupling.Write(quantity = ic.quantity, semantics = Fields.Intensive(),
                                                          conserves = ()),),
                                 stocks = (), system_fields = (), profile_fields = (), backend = Backends.CPU())
        initial_keys[ic.quantity] = key(d, ic.quantity, NamedTuple())
    end
    written = Dict{Symbol,Provenance.ArtifactKey}()
    found = Tuple{Symbol,Symbol,NTuple{32,UInt8}}[]
    for name in Coupling.order(a)
        d = Coupling.declaration(a, name)
        names = Tuple(r.quantity for r in d.reads)
        inputs = NamedTuple{names}(Tuple((r.lagged ? initial_keys : written)[r.quantity] for r in d.reads))
        for w in d.writes
            k = key(d, w.quantity, inputs)
            written[w.quantity] = k
            push!(found, (name, w.quantity, k.digest))
        end
    end
    return found
end

"`(residual, tolerance)` of a `Fields.Ledger` by `canonical_bytes`."
ledger_bytes(l::Fields.Ledger) = Provenance.canonical_bytes((Fields.residual(l), Fields.tolerance(l)))

"""
    run_case(install, g; operator_version = 1)

The short fixture case. `install(live)` is called first, `live` a `Ref` that holds the
exchanged `WorldState` once it exists. Then, in order: an assembly refused for a read
with no writer (a `refusal` event); an exchange from land to river; an exchange whose
receipt holds the runoff twice, refused as open (a `ledger_open` event); an antitone
loop that brackets, one that reaches its cap (a `budget` event), and one whose samples
lie at another level than it reads (a `verdict` with a `NaN` statistic); the strait of
the connectivity graphs `g` closing (a `topology_change` event); and one event of each
kind no component in `src` emits, through `Events.emit`. Returns `(artifacts, keys)`:
`artifacts` a vector of `(name, bytes)`, the bytes by `canonical_bytes`; `keys` from
`content_keys`.
"""
function run_case(install, g; operator_version = 1)
    live = Ref{Any}(nothing)
    install(live)
    m = mesh()
    artifacts = Tuple{String,Vector{UInt8}}[]
    record!(name, x) = push!(artifacts, (name, Provenance.canonical_bytes(x)))

    refused = caught(() -> Coupling.assemble(river(); initial_conditions = (initial(:channel, 1),),
                                             sequence = 1, instant = 0.0, tier = :fast))
    record!("refused assembly", refused.reason)

    a = assembly()
    state, interval = stepped(a, m, 100.0)
    live[] = state
    ex = to_river(m)
    _, ledgers = Coupling.exchange!(state, ex, interval; sequence = 3, tier = :fast)

    doubled, _ = stepped(a, m, 100.0)
    handed = Coupling.hand_over(doubled, ex)
    foreach(values(handed)) do h
        result = h.crossing.quantity === :runoff ? h.result + h.result : h.result
        Coupling.receive!(doubled, :river, h.crossing.quantity, result)
    end
    opened = caught(() -> Coupling.settle(doubled, ex, handed; sequence = 4, instant = 100.0, tier = :fast))
    record!("open ledger", opened.reason)

    p = profile()
    numbering = Coupling.Numbering(first = 10, tier = :slow)
    outcomes = [Coupling.run_loop(antitone_loop(p; name = :map, damping = 1 // 2, cap = 20, sampled_at = 5);
                                  state = nothing, instant = 0, numbering = numbering),
                Coupling.run_loop(antitone_loop(p; name = :map, damping = 1 // 1, cap = 10, sampled_at = 5);
                                  state = nothing, instant = 0, numbering = numbering),
                Coupling.run_loop(antitone_loop(p; name = :unseen, damping = 1 // 2, cap = 20, sampled_at = 4);
                                  state = nothing, instant = 0, numbering = numbering)]

    edits = Connectivity.emit_topology_changes(g.open, g.closed; sequence = 100, instant = 3.5e9,
                                               tier = :slow)

    found = content_keys(a, m, SF.system(Float64); interval = interval, operator_version = operator_version)
    hex(digest) = bytes2hex(collect(digest))
    emitted(kind, sequence, payload) =
        Events.emit(Events.Event(kind, sequence, 3.6e9, :slow, "JournalCase", payload))
    emitted(Events.Refresh(), 200, Events.RefreshPayload(trigger = "sea ice extent", field = "albedo",
                                                         change = 0.25, restart_seconds = 3600.0,
                                                         restart_orbits = 0.125))
    emitted(Events.LevelChange(), 201, Events.LevelChangePayload(from = 1, to = 2, window = 86400.0))
    emitted(Events.Artifact(), 202, Events.ArtifactPayload(key = hex(last(first(found))), kind = "field",
                                                           support = hex(m.fine.digest)))
    emitted(Events.Checkpoint(), 203, Events.CheckpointPayload(key = hex(last(last(found))),
                                                               precision = Float64))
    emitted(Events.Oracle(), 204, Events.OraclePayload(registry_id = "loop.drift_against_its_own_scatter",
                                                       verdict = Verdicts.REPORT(), statistic = 0.5,
                                                       threshold = NaN))

    for q in sort(collect(keys(state.current)))
        record!("field $(q)", Fields.data(state.current[q]))
    end
    for q in sort(collect(keys(ledgers)))
        push!(artifacts, ("operator ledger $(q)", ledger_bytes(ledgers[q].operator)))
        push!(artifacts, ("receipt ledger $(q)", ledger_bytes(ledgers[q].receipt)))
    end
    for (i, o) in enumerate(outcomes)
        record!("loop $(i) records",
                Tuple((r.loop, r.iteration, r.instant, Tuple((n, s.value, s.level) for (n, s) in pairs(r.samples)))
                      for r in o.records))
        record!("loop $(i) verdict", nameof(typeof(o.report.verdict)))
    end
    record!("topology edits", edits)
    return (artifacts = artifacts, keys = found)
end

"The name of the first entry at which `a` and `b` differ, or `nothing` when every name and every byte agree."
function first_difference(a::Vector{Tuple{String,Vector{UInt8}}}, b::Vector{Tuple{String,Vector{UInt8}}})
    length(a) == length(b) || return "the count of artifacts"
    for ((na, ba), (nb, bb)) in zip(a, b)
        (na == nb && ba == bb) || return na
    end
    return nothing
end

# ---------------------------------------------------------------- journals under a temporary directory

"`f(journal, file)` with a journal installed for a new run, opened through the door
`Provenance.start_run!` under a new temporary store; the no-op sink is installed again
on return."
function with_journal(f)
    mktempdir() do root
        store = Provenance.Store(root = root)
        run = Provenance.mint_run_id()
        ctx = Provenance.start_run!(store; run = run, code = code(), system = SF.system(Float64))
        try
            return f(ctx.journal, joinpath(Provenance.run_directory(store, run), Provenance.JOURNAL_PATH))
        finally
            Events.sink!(Events.noop_sink)
        end
    end
end

"A `verdict` event numbered `sequence` at `instant` on the fast tier from `component`, carrying `statistic`."
verdict_event(sequence, instant, component, statistic) =
    Events.Event(Events.Verdict(), sequence, instant, :fast, component,
                 Events.VerdictPayload(predicate = "fixture", verdict = Verdicts.Converged(),
                                       statistic = statistic, bracket = (0.0, 1.0)))

"The `.jl` files under `root` naming `sink!(` or `SINK[`, relative to `root`, other than `Events/Events.jl`, sorted."
function sink_installers(root::AbstractString)
    found = String[]
    pattern = r"(?<![A-Za-z0-9_])(?:sink!\(|SINK\[)"
    for (dir, _, files) in walkdir(root), f in files
        endswith(f, ".jl") || continue
        path = relpath(joinpath(dir, f), root)
        path == joinpath("Events", "Events.jl") && continue
        occursin(pattern, read(joinpath(dir, f), String)) && push!(found, path)
    end
    return sort!(found)
end

"The `.jl` files under `root` naming `install_journal!(`, relative to `root`, other than
`Provenance/journal.jl`, where it is declared, sorted."
function install_journal_callers(root::AbstractString)
    found = String[]
    pattern = r"(?<![A-Za-z0-9_])install_journal!\("
    for (dir, _, files) in walkdir(root), f in files
        endswith(f, ".jl") || continue
        path = relpath(joinpath(dir, f), root)
        path == joinpath("Provenance", "journal.jl") && continue
        occursin(pattern, read(joinpath(dir, f), String)) && push!(found, path)
    end
    return sort!(found)
end

# ---------------------------------------------------------------- the schema a record is read against

"The type of the payload of `kind` whose fields a journal record carries."
record_type(kind::Events.Kind) = kind isa Events.TopologyChange ?
    Events.TopologyChangePayload{Mesh.CellId} : Events.payload_type(kind)

"""
    value_violation(T, value, record)

`nothing` when `value` is a TOML value a field of type `T` is written as, text naming
the mismatch otherwise. A cell is an integer at least zero and below the cell count of
the level the record's payload names.
"""
function value_violation(T::Type, value, record)
    ok = if T === String || T === Symbol
        value isa String
    elseif T === Int
        value isa Int64
    elseif T === Float64
        value isa Float64
    elseif T === Tuple{Float64,Float64}
        value isa Vector{Float64} && length(value) == 2
    elseif T === Verdicts.LoopVerdict
        value in [string(nameof(typeof(v))) for v in Verdicts.loop_verdicts()]
    elseif T === Verdicts.OracleVerdict
        value in [string(nameof(typeof(v))) for v in Verdicts.oracle_verdicts()]
    elseif T === DataType
        value in ("Float16", "Float32", "Float64")
    elseif T === Events.Kind
        value in [String(Events.name(k)) for k in Events.kinds()]
    elseif T === Vector{Mesh.CellId}
        level = record[Provenance.PAYLOAD_KEY]["level"]
        value isa Vector && all(c -> c isa Int64 && 0 <= c < Mesh.ncells(level), value)
    else
        false
    end
    return ok ? nothing : "$(repr(value)) is not a journal value of a $(T)"
end

"""
    schema_violations(record)

Text for every way the parsed `[[event]]` table `record` departs from the schema of its
kind: keys other than the fields of `Events.Header` and the payload; a kind outside
`Events.kinds()`; payload keys other than the fields of `record_type`; and each value
`value_violation` reports.
"""
function schema_violations(record::AbstractDict)
    found = String[]
    header = Set(String.(fieldnames(Events.Header)))
    Set(keys(record)) == union(header, [Provenance.PAYLOAD_KEY]) ||
        return ["keys $(sort(collect(keys(record))))"]
    for (f, T) in zip(fieldnames(Events.Header), fieldtypes(Events.Header))
        v = value_violation(T, record[String(f)], record)
        v === nothing || push!(found, "header $(f): $(v)")
    end
    matched = [k for k in Events.kinds() if String(Events.name(k)) == record["kind"]]
    length(matched) == 1 || return push!(found, "kind $(repr(record["kind"])) is outside the vocabulary")
    T = record_type(only(matched))
    payload = record[Provenance.PAYLOAD_KEY]
    Set(keys(payload)) == Set(String.(fieldnames(T))) ||
        return push!(found, "payload keys $(sort(collect(keys(payload)))) of $(T)")
    for (f, FT) in zip(fieldnames(T), fieldtypes(T))
        v = value_violation(FT, payload[String(f)], record)
        v === nothing || push!(found, "payload $(f): $(v)")
    end
    return found
end

end # module JournalCase

import .JournalCase as JNL

const JOURNAL_CASE_RECORDS = Dict{String,Any}[]

@testset "provenance.journal_is_inert" begin
    g = JNL.graphs()
    off = JNL.run_case(live -> Events.sink!(Events.noop_sink), g)
    on, records = JNL.with_journal() do journal, file
        JNL.run_case(live -> Events.sink!(journal), g), Provenance.read_journal(file)
    end
    append!(JOURNAL_CASE_RECORDS, records)

    @testset "the case journals every kind" begin
        @test Set(r["kind"] for r in records) == Set(String(Events.name(k)) for k in Events.kinds())
    end

    @testset "journaling on and off gives bitwise identical artifacts and identical content keys" begin
        @test !isempty(off.artifacts)
        @test JNL.first_difference(on.artifacts, off.artifacts) === nothing
        @test on.keys == off.keys
    end

    @testset "the journal is in no content key" begin
        JNL.with_journal() do journal, file
            e = JNL.raised(() -> Provenance.canonical_bytes(journal))
            @test e isa Verdicts.Refusal && e.quantity == "canonical serialisation"
            m = JNL.mesh()
            writer = Coupling.Declaration(name = :writer, level = m.fine.level, reads = (),
                                          writes = (Coupling.Write(quantity = :x, semantics = Fields.Intensive(),
                                                                   conserves = ()),),
                                          stocks = (), system_fields = (), profile_fields = (),
                                          backend = Backends.CPU())
            given = (code = JNL.code(), declaration = writer, system = SystemFixtures.system(Float64),
                     profile = JNL.profile(), inputs = NamedTuple(), quantity = :x, support = m.fine,
                     interval = Time.Interval(0.0, 100.0), operator_version = 1)
            e = JNL.raised(() -> Provenance.ArtifactKey(; given..., journal = journal))
            @test e isa Verdicts.Refusal && e.quantity == "journal"

            @testset "positive control: the same keywords without the journal give a key" begin
                @test Provenance.ArtifactKey(; given...) isa Provenance.ArtifactKey
            end
        end
    end

    @testset "positive control: a sink with an effect on the state, and keys over another operator version, are reported" begin
        perturbed = JNL.with_journal() do journal, file
            JNL.run_case(g) do live
                Events.sink!(event -> begin
                    journal(event)
                    live[] === nothing && return nothing
                    d = Fields.data(live[].current[:channel])
                    d[1] = nextfloat(d[1])
                    return nothing
                end)
            end
        end
        @test JNL.first_difference(perturbed.artifacts, off.artifacts) == "field channel"
        @test JNL.content_keys(JNL.assembly(), JNL.mesh(), SystemFixtures.system(Float64);
                               interval = Time.Interval(0.0, 100.0), operator_version = 2) != off.keys
    end
end

@testset "provenance.event_vocabulary_closed" begin
    @testset "every kind has a payload type" begin
        @test all(Events.has_payload_type, Events.kinds())
    end

    @testset "every event the case emitted validates against the schema of its kind" begin
        @test !isempty(JOURNAL_CASE_RECORDS)
        for r in JOURNAL_CASE_RECORDS
            @test JNL.schema_violations(r) == String[]
        end
    end

    @testset "positive control: a kind outside the vocabulary is refused at the emitter" begin
        @test_throws MethodError Events.Event(:move, 1, 0.0, :fast, "Fixture",
                                              Events.BudgetPayload(cap = 1.0, which = "moves"))
        @test_throws MethodError Events.emit(Events.Moved([1.0], :cpu, :gpu))
    end

    @testset "positive control: a record departing from the schema of its kind is reported" begin
        of_kind(word) = first(r for r in JOURNAL_CASE_RECORDS if r["kind"] == word)
        mutations = (
            ("verdict", r -> (r["kind"] = "move")),
            ("verdict", r -> (r["kind"] = "budget")),
            ("verdict", r -> delete!(r[Provenance.PAYLOAD_KEY], "bracket")),
            ("verdict", r -> (r[Provenance.PAYLOAD_KEY]["reason"] = "extra")),
            ("verdict", r -> (r[Provenance.PAYLOAD_KEY]["verdict"] = "Passed")),
            ("verdict", r -> delete!(r, "tier")),
            ("verdict", r -> (r["sequence"] = 1.0)),
            ("topology_change", r -> (r[Provenance.PAYLOAD_KEY]["cells"] = [-1])),
            ("topology_change", r -> (r[Provenance.PAYLOAD_KEY]["cells"] =
                                          [Mesh.ncells(r[Provenance.PAYLOAD_KEY]["level"])])),
            ("checkpoint", r -> (r[Provenance.PAYLOAD_KEY]["precision"] = "BigFloat")),
        )
        for (word, mutate!) in mutations
            r = deepcopy(of_kind(word))
            @test isempty(JNL.schema_violations(r))
            mutate!(r)
            @test !isempty(JNL.schema_violations(r))
        end
    end
end

@testset "the journal writes each kind's payload as its disk values" begin
    CellId = Mesh.CellId
    samples = (
        (Events.VerdictPayload(predicate = "map.alternation", verdict = Verdicts.BudgetExhausted(),
                               statistic = -0.0, bracket = (5.0e-324, Inf)),
         Dict("predicate" => "map.alternation", "verdict" => "BudgetExhausted", "statistic" => -0.0,
              "bracket" => [5.0e-324, Inf])),
        (Verdicts.Refusal("cells", "Site \"quoted\"", "line one\nline two"),
         Dict("quantity" => "cells", "site" => "Site \"quoted\"", "reason" => "line one\nline two")),
        (Events.LedgerOpenPayload(ledger = "runoff receipt total", imbalance = 1.0e-3, tolerance = 2.5e-14,
                                  exchange = "land -> river"),
         Dict("ledger" => "runoff receipt total", "imbalance" => 1.0e-3, "tolerance" => 2.5e-14,
              "exchange" => "land -> river")),
        (Events.RefreshPayload(trigger = "sea ice extent", field = "albedo", change = 0.1,
                               restart_seconds = 3600.0, restart_orbits = NaN),
         Dict("trigger" => "sea ice extent", "field" => "albedo", "change" => 0.1,
              "restart_seconds" => 3600.0, "restart_orbits" => NaN)),
        (Events.TopologyChangePayload(edit = "seaway_closed", level = 1, cells = [CellId(0), CellId(79)],
                                      quantity = 150.0),
         Dict("edit" => "seaway_closed", "level" => 1, "cells" => [0, 79], "quantity" => 150.0)),
        (Events.LevelChangePayload(from = 3, to = 4, window = 86400.0),
         Dict("from" => 3, "to" => 4, "window" => 86400.0)),
        (Events.ArtifactPayload(key = "ab01", kind = "field", support = "cd23"),
         Dict("key" => "ab01", "kind" => "field", "support" => "cd23")),
        (Events.CheckpointPayload(key = "ab01", precision = Float32),
         Dict("key" => "ab01", "precision" => "Float32")),
        (Events.OraclePayload(registry_id = "mesh.area_closure", verdict = Verdicts.PASS(), statistic = 1.0e-9,
                              threshold = 1.0e-8),
         Dict("registry_id" => "mesh.area_closure", "verdict" => "PASS", "statistic" => 1.0e-9,
              "threshold" => 1.0e-8)),
        (Events.BudgetPayload(cap = 1.0e9, which = "memory"), Dict("cap" => 1.0e9, "which" => "memory")),
    )
    kinds = Dict(Events.payload_type(k) => k for k in Events.kinds())
    kind_of(payload) = payload isa Events.TopologyChangePayload ? Events.TopologyChange() : kinds[typeof(payload)]
    @test length(samples) == length(Events.kinds())

    records = JNL.with_journal() do journal, file
        @test isfile(file) && isempty(Provenance.read_journal(file))
        for (payload, _) in samples
            Events.emit(Events.Event(kind_of(payload), 7, 3.5e9, :slow, "Fixture", payload))
        end
        Provenance.read_journal(file)
    end
    @test length(records) == length(samples)
    for (payload, expected) in samples
        word = String(Events.name(kind_of(payload)))
        r = only(r for r in records if r["kind"] == word)
        @test isequal(r, Dict("sequence" => 7, "instant" => 3.5e9, "tier" => "slow", "component" => "Fixture",
                              "kind" => word, Provenance.PAYLOAD_KEY => expected))
        @test JNL.schema_violations(r) == String[]
    end
    cells = only(r for r in records if r["kind"] == "topology_change")[Provenance.PAYLOAD_KEY]["cells"]
    @test cells isa Vector{Int64}
end

@testset "the journal's order is decided by each record, never by the order events arrive in" begin
    events = [JNL.verdict_event(3, 2.0, "B", 0.1), JNL.verdict_event(1, 1.0, "B", 0.2),
              JNL.verdict_event(2, 1.0, "A", 0.4), JNL.verdict_event(2, 1.0, "A", 0.3),
              JNL.verdict_event(1, 2.0, "A", 0.5), JNL.verdict_event(1, 1.0, "A", 0.6)]
    read_both(order) = JNL.with_journal() do journal, file
        foreach(Events.emit, order)
        Provenance.read_journal(file), TOML.parsefile(file)["event"]
    end
    forward, forward_file = read_both(events)
    backward, backward_file = read_both(reverse(events))
    @test forward == backward
    @test [(r["instant"], r["component"], r["sequence"], r[Provenance.PAYLOAD_KEY]["statistic"]) for r in forward] ==
          [(1.0, "A", 1, 0.6), (1.0, "A", 2, 0.3), (1.0, "A", 2, 0.4), (1.0, "B", 1, 0.2),
           (2.0, "A", 1, 0.5), (2.0, "B", 3, 0.1)]

    @testset "positive control: the file holds the records in the order they arrived" begin
        @test backward_file == reverse(forward_file)
        @test backward_file != backward
    end

    @testset "events emitted from concurrent tasks are each appended whole, and read back as emitted serially" begin
        many = [JNL.verdict_event(i, Float64(i % 7), "task $(i % 3)", Float64(i)) for i in 1:400]
        serial = JNL.with_journal() do journal, file
            foreach(Events.emit, many)
            Provenance.read_journal(file)
        end
        concurrent = JNL.with_journal() do journal, file
            @sync for chunk in Iterators.partition(reverse(many), 25)
                Threads.@spawn foreach(Events.emit, chunk)
            end
            Provenance.read_journal(file)
        end
        @test length(concurrent) == length(many)
        @test concurrent == serial
    end
end

@testset "the writer refuses what has no journal form, and appends nothing for it" begin
    JNL.with_journal() do journal, file
        named = Events.TopologyChangePayload(edit = "seaway_closed", level = 1, cells = [:a, :b], quantity = 1.0)
        e = JNL.raised(() -> Events.emit(Events.Event(Events.TopologyChange(), 1, 0.0, :slow, "Fixture", named)))
        @test e isa Verdicts.Refusal && e.quantity == "cells"
        wide = Events.CheckpointPayload(key = "ab01", precision = BigFloat)
        e = JNL.raised(() -> Events.emit(Events.Event(Events.Checkpoint(), 2, 0.0, :slow, "Fixture", wide)))
        @test e isa Verdicts.Refusal && e.quantity == "precision"
        @test filesize(file) == 0

        @testset "positive control: the same events with a CellId cell and a Float64 precision are appended" begin
            Events.emit(Events.Event(Events.TopologyChange(), 1, 0.0, :slow, "Fixture",
                                     Events.TopologyChangePayload(edit = "seaway_closed", level = 1,
                                                                  cells = [Mesh.CellId(3)], quantity = 1.0)))
            Events.emit(Events.Event(Events.Checkpoint(), 2, 0.0, :slow, "Fixture",
                                     Events.CheckpointPayload(key = "ab01", precision = Float64)))
            @test length(Provenance.read_journal(file)) == 2
        end
    end
end

@testset "install_journal! refuses what it cannot install, and keeps what a journal holds" begin
    Events.sink!(Events.noop_sink)
    mktempdir() do runs
        run = Provenance.mint_run_id()
        for (quantity, kwargs) in (("run", (runs = runs,)),
                                   ("runs", (runs = joinpath(runs, "absent"), run = run)),
                                   ("runs", (runs = SubString(runs, 1), run = run)),
                                   ("run", (runs = runs, run = run.uuid)),
                                   ("flush", (runs = runs, run = run, flush = true)))
            e = JNL.raised(() -> Provenance.install_journal!(; kwargs...))
            @test e isa Verdicts.Refusal && e.quantity == quantity
        end
        @test Events.SINK[] === Events.noop_sink

        try
            file = Provenance.journal_file(runs, run)
            @test file == joinpath(runs, string(run.uuid), Provenance.JOURNAL_PATH)
            Provenance.install_journal!(runs = runs, run = run)
            Events.emit(JNL.verdict_event(1, 0.0, "Fixture", 0.5))
            journal = Provenance.install_journal!(runs = runs, run = run)
            @test Events.SINK[] === journal
            Events.emit(JNL.verdict_event(2, 0.0, "Fixture", 0.5))
            @test [r["sequence"] for r in Provenance.read_journal(file)] == [1, 2]
        finally
            Events.sink!(Events.noop_sink)
        end
    end
end

@testset "a device move is counted and never journalled" begin
    JNL.with_journal() do journal, file
        @test Events.SINK[] === journal
        @test Events.MOVE_SINK[] !== journal
        Events.reset_move_counts!()
        Events.moved([1.0], :cpu, :gpu)
        @test isempty(Provenance.read_journal(file))
        @test Events.move_counts() == Dict((:cpu, :gpu) => 1)
        @test_throws MethodError journal(Events.Moved([1.0], :cpu, :gpu))

        @testset "positive control: an event is journalled by the same installed sink" begin
            Events.emit(JNL.verdict_event(1, 0.0, "Fixture", 0.5))
            @test length(Provenance.read_journal(file)) == 1
        end
        Events.reset_move_counts!()
    end
end

@testset "the journal is the only sink src installs, install_journal! has one caller, and the path constant is declared in the emitter the lint names" begin
    src = joinpath(pkgdir(Fiddlybits), "src")
    @test JNL.sink_installers(src) == [joinpath("Provenance", "journal.jl")]
    @test JNL.install_journal_callers(src) == [joinpath("Provenance", "run.jl")]

    list = TOML.parsefile(joinpath(@__DIR__, "..", "lint", "lists", "journal.toml"))
    @test isdefined(Provenance, Symbol(list["path_constant"]))
    @test occursin(Regex("(?m)^const " * list["path_constant"] * " = "),
                   read(joinpath(src, list["emitter"]), String))

    @testset "positive control: a second installer, by sink! or by SINK, is reported" begin
        mktempdir() do root
            for (path, text) in ((joinpath("Provenance", "journal.jl"), read(joinpath(src, "Provenance", "journal.jl"), String)),
                                 (joinpath("Coupling", "tap.jl"), "tap!() = Events.sink!(println)\n"),
                                 (joinpath("Fields", "tap.jl"), "tap!() = (Events.SINK[] = println)\n"),
                                 (joinpath("Events", "Events.jl"), "sink!(f) = (SINK[] = f; nothing)\n"))
                mkpath(dirname(joinpath(root, path)))
                write(joinpath(root, path), text)
            end
            @test JNL.sink_installers(root) ==
                  sort([joinpath("Coupling", "tap.jl"), joinpath("Fields", "tap.jl"), joinpath("Provenance", "journal.jl")])
        end
    end

    @testset "positive control: a second caller of install_journal!, beside the door, is reported" begin
        mktempdir() do root
            for (path, text) in ((joinpath("Provenance", "journal.jl"), read(joinpath(src, "Provenance", "journal.jl"), String)),
                                 (joinpath("Provenance", "run.jl"), read(joinpath(src, "Provenance", "run.jl"), String)),
                                 (joinpath("Coupling", "tap.jl"), "tap!(runs, run) = Provenance.install_journal!(runs = runs, run = run)\n"))
                mkpath(dirname(joinpath(root, path)))
                write(joinpath(root, path), text)
            end
            @test JNL.install_journal_callers(root) ==
                  sort([joinpath("Coupling", "tap.jl"), joinpath("Provenance", "run.jl")])
        end
    end
end
