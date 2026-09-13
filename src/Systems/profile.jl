# Profile: each component's level, refinement reach and vertical ladder; the radiation
# cadence with its Derived ceiling; the precision of the fast fields; the slow tier; the
# memory ceiling; the daily-tier fallback interval; every loop's exit bracket.
# docs/plans/fiddlybits-52v.4-system.md, section "Scope"; decisions 0005, 0008, 0011,
# 0014 and 0023.

using ..Verdicts: refuse
using ..Dimensions: TIME, LENGTH, DIMENSIONLESS, signature
using ..Dispositions: Disposition, Sourced, Derived, Bracketed, Irreducible, value, dimension
using ..Reductions: error_bound
using ..Backends: refuse_over

"""
    Absent(; argument)

A profile setting declared absent, with the argument for its absence.
"""
struct Absent
    argument::String

    Absent(::Checked, a::String) = new(a)
end

function Absent(; kwargs...)
    site = "Systems.Absent"
    k, _ = read_keywords(site, values(kwargs), (:argument,), ())
    (k.argument isa AbstractString && !isempty(k.argument)) || refuse(
        "argument", site, "the absence carries no argument")
    return Absent(Checked(), String(k.argument))
end

"""
    Undefined(; argument)

A bounding term of the radiation ceiling that the configuration does not define, with
the argument naming why.
"""
struct Undefined
    argument::String

    Undefined(::Checked, a::String) = new(a)
end

function Undefined(; kwargs...)
    site = "Systems.Undefined"
    k, _ = read_keywords(site, values(kwargs), (:argument,), ())
    (k.argument isa AbstractString && !isempty(k.argument)) || refuse(
        "argument", site, "the undefined term carries no argument")
    return Undefined(Checked(), String(k.argument))
end

"Every disposition but `Closure`."
const NON_CLOSURE = (Sourced, Derived, Bracketed, Irreducible)

# ---------------------------------------------------------------- levels

"""
    level_spacing(radius, level)

`sqrt(4 pi radius^2 / (20 * 4^level))` in `GEOMETRY_PRECISION`: the square root of the
mean cell area of `level` of the icosahedral hierarchy on a sphere of `radius`.
"""
function level_spacing(radius::Real, level::Integer)
    r = GEOMETRY_PRECISION(radius)
    cells = ldexp(GEOMETRY_PRECISION(20), 2 * level)
    return sqrt(4 * GEOMETRY_PRECISION(pi) * r^2 / cells)
end

"""
The rounded operations of `level_spacing`: the rounding of `pi`, the square of the
radius, one multiply, one divide and one square root. The multiply by four and the
cell count `20 * 4^level` are exact.
"""
const LEVEL_SPACING_TERMS = 5

"""
    FINEST_INDEXABLE_LEVEL

The finest level whose edge count `30 * 4^level`, the largest of its three element
counts, is at most `typemax(Int)`.
"""
const FINEST_INDEXABLE_LEVEL = ndigits(div(typemax(Int), 30); base = 4) - 1

"""
    level_for_spacing(quantity, site, radius, spacing)

The coarsest level `L` at which `level_spacing(radius, L)` does not exceed `spacing`.
Refuses at `site` naming `quantity` when that level is finer than
`FINEST_INDEXABLE_LEVEL`.
"""
function level_for_spacing(quantity::AbstractString, site::AbstractString,
                           radius::Real, spacing::Real)
    target = GEOMETRY_PRECISION(spacing)
    level = 0
    while level_spacing(radius, level) > target
        level == FINEST_INDEXABLE_LEVEL && refuse(
            quantity, site,
            "the spacing $(spacing) on a radius of $(radius) needs a level finer than " *
            "$(FINEST_INDEXABLE_LEVEL), the finest whose edges an Int indexes")
        level += 1
    end
    return level
end

# ---------------------------------------------------------------- components

"""
    VerticalLadder(; depth_scale, interfaces)

A component's vertical ladder: `interfaces`, the level interfaces from the bottom up,
each a dimensionless position in units of the depth scale the component names by
`depth_scale`. A ladder of `n` levels has `n + 1` interfaces, zero or above and
strictly increasing.
"""
struct VerticalLadder{FT,I}
    depth_scale::Symbol
    interfaces::I

    VerticalLadder{FT,I}(::Checked, s, i) where {FT,I} = new{FT,I}(s, i)
end

function VerticalLadder(; kwargs...)
    site = "Systems.VerticalLadder"
    k, _ = read_keywords(site, values(kwargs), (:depth_scale, :interfaces), ())
    scale = require_type("depth_scale", site, k.depth_scale, Symbol)
    interfaces = k.interfaces
    interfaces isa Tuple || refuse(
        "interfaces", site,
        "a $(nameof(typeof(interfaces))) where a tuple of level interfaces is " *
        "required; a scalar is not a value per level (REQ-SYS-103 item 5)")
    length(interfaces) >= 2 || refuse(
        "interfaces", site,
        "$(length(interfaces)) interfaces bound no level; a ladder has two or more")
    FT = float_type("interfaces", site, first(interfaces))
    for d in interfaces
        require_interval("interfaces", site,
            require_disposition("interfaces", site, d, FT, DIMENSIONLESS, DECLARED),
            zero(FT), true, typemax(FT), true)
    end
    for i in 2:length(interfaces)
        value(interfaces[i]) > value(interfaces[i-1]) || refuse(
            "interfaces", site,
            "interface $(i) at $(value(interfaces[i])) does not lie above interface " *
            "$(i - 1) at $(value(interfaces[i-1]))")
    end
    return VerticalLadder{FT,typeof(interfaces)}(Checked(), scale, interfaces)
end

"""
    ComponentDeclaration(; name, target_spacing, finest_spacing, ladder)

What a profile declares for one component: its `name`; `target_spacing`, the length
its level is chosen for; `finest_spacing`, the length local refinement may reach, no
longer than the target; and `ladder`, a `VerticalLadder` or an `Absent`. Both spacings
are declared lengths above zero.
"""
struct ComponentDeclaration{FT,L}
    name::Symbol
    target_spacing::Disposition{FT,typeof(LENGTH)}
    finest_spacing::Disposition{FT,typeof(LENGTH)}
    ladder::L

    ComponentDeclaration{FT,L}(::Checked, n, t, f, l) where {FT,L} = new{FT,L}(n, t, f, l)
end

function ComponentDeclaration(; kwargs...)
    site = "Systems.ComponentDeclaration"
    k, _ = read_keywords(site, values(kwargs),
                         (:name, :target_spacing, :finest_spacing, :ladder), ())
    name = require_type("name", site, k.name, Symbol)
    FT = float_type("target_spacing", site, k.target_spacing)
    spacing(key) = require_positive(String(key), site,
        require_disposition(String(key), site, k[key], FT, LENGTH, DECLARED))
    target = spacing(:target_spacing)
    finest = spacing(:finest_spacing)
    value(finest) <= value(target) || refuse(
        "finest_spacing", site,
        "the finest spacing $(value(finest)) is longer than the target spacing " *
        "$(value(target)); refinement reaches no coarser than the component's own level")
    ladder = require_type("ladder", site, k.ladder, Union{VerticalLadder{FT},Absent})
    return ComponentDeclaration{FT,typeof(ladder)}(Checked(), name, target, finest, ladder)
end

"""
    Component

One component as a `Profile` holds it: the fields of its `ComponentDeclaration`, with
`level` and `finest_level` `Derived` by `level_for_spacing` from the planet's
volumetric mean radius and the target and finest spacings, and
`deformation_radius_ratio`, the ratio of the level's spacing to the first-baroclinic
deformation radius, an `Absent` naming what carries it.
"""
struct Component{FT,L,N}
    name::Symbol
    target_spacing::Disposition{FT,typeof(LENGTH)}
    level::Derived{Int,typeof(DIMENSIONLESS),N}
    finest_spacing::Disposition{FT,typeof(LENGTH)}
    finest_level::Derived{Int,typeof(DIMENSIONLESS),N}
    ladder::L
    deformation_radius_ratio::Absent
end

"The argument the deformation radius ratio of every component is absent with."
const DEFORMATION_RATIO_ABSENCE =
    "the first-baroclinic deformation radius needs the first-guess column of " *
    "REQ-ATM-017, carried by the M3 plan fiddlybits-84a.1 " *
    "(docs/plans/fiddlybits-52v.4-system.md, section Scope)"

"""
    resolve_component(site, system, declaration)

The `Component` of `declaration` on `system`: both levels `Derived` by
`level_for_spacing` from the planet's volumetric mean radius.
"""
function resolve_component(site::AbstractString, s::System, c::ComponentDeclaration)
    radius = value(s.planet.volumetric_mean_radius)
    derive(key, spacing) = Derived(
        value = level_for_spacing(String(key), site, radius, value(spacing)),
        dim = DIMENSIONLESS, from = (:system, :components), rule = :level_for_spacing,
        fields = PROFILE_KEYWORDS)
    return Component(c.name, c.target_spacing, derive(:target_spacing, c.target_spacing),
                     c.finest_spacing, derive(:finest_spacing, c.finest_spacing), c.ladder,
                     Absent(Checked(), DEFORMATION_RATIO_ABSENCE))
end

# ---------------------------------------------------------------- the radiation cadence

"""
    RadiationCycles(; diurnal_cycle, eclipse_durations, cloud_timescale)

The bounding terms of the radiation ceiling that `Systems` does not derive, supplied
by the modules that do. `diurnal_cycle` is the mean solar day of the source of largest
instellation, a `Derived` duration by the rule `:mean_solar_day`, or `Undefined`.
`eclipse_durations` is a tuple of one or more `Derived` durations by the rule
`:eclipse_duration`, or `Undefined`. `cloud_timescale` is the fast tier's cloud
timescale, a duration carrying any disposition but `Closure`. Every duration is above
zero.
"""
struct RadiationCycles{FT,M,E}
    diurnal_cycle::M
    eclipse_durations::E
    cloud_timescale::Disposition{FT,typeof(TIME)}

    RadiationCycles{FT,M,E}(::Checked, m, e, c) where {FT,M,E} = new{FT,M,E}(m, e, c)
end

"""
    require_term(quantity, site, d, FT, rule)

`d` when it is a `Derived` duration of type `FT` above zero whose rule is `rule`;
refuses at `site` naming `quantity` otherwise.
"""
function require_term(quantity::AbstractString, site::AbstractString, d, ::Type{FT},
                      rule::Symbol) where {FT}
    require_positive(quantity, site,
                     require_disposition(quantity, site, d, FT, TIME, (Derived,)))
    d.rule === rule || refuse(
        quantity, site,
        "a Derived value by the rule $(d.rule) where the rule $(rule) is required")
    return d
end

function RadiationCycles(; kwargs...)
    site = "Systems.RadiationCycles"
    k, _ = read_keywords(site, values(kwargs),
                         (:diurnal_cycle, :eclipse_durations, :cloud_timescale), ())
    FT = float_type("cloud_timescale", site, k.cloud_timescale)
    cloud = require_positive("cloud_timescale", site,
        require_disposition("cloud_timescale", site, k.cloud_timescale, FT, TIME, NON_CLOSURE))
    diurnal = k.diurnal_cycle isa Undefined ? k.diurnal_cycle :
        require_term("diurnal_cycle", site, k.diurnal_cycle, FT, :mean_solar_day)
    eclipses = k.eclipse_durations
    if !(eclipses isa Undefined)
        (eclipses isa Tuple && !isempty(eclipses)) || refuse(
            "eclipse_durations", site,
            "a $(nameof(typeof(eclipses))) where a tuple of one or more eclipse " *
            "durations, or Undefined, is required")
        for d in eclipses
            require_term("eclipse_durations", site, d, FT, :eclipse_duration)
        end
    end
    return RadiationCycles{FT,typeof(diurnal),typeof(eclipses)}(
        Checked(), diurnal, eclipses, cloud)
end

"""
    RadiationDeclaration(; g_points, interval, ceiling_fraction, cycles)

What a profile declares for the radiation scheme: `g_points`, a tuple holding the
count of g-points of each band, each one or more, or an `Absent`; `interval`, the call
interval, a declared duration above zero; `ceiling_fraction`, the declared fraction in
`(0, 1]` of the shortest bounding term the ceiling is; and `cycles`, the
`RadiationCycles` the ceiling reads.
"""
struct RadiationDeclaration{FT,G,C}
    g_points::G
    interval::Disposition{FT,typeof(TIME)}
    ceiling_fraction::Disposition{FT,typeof(DIMENSIONLESS)}
    cycles::C

    RadiationDeclaration{FT,G,C}(::Checked, g, i, f, c) where {FT,G,C} =
        new{FT,G,C}(g, i, f, c)
end

function RadiationDeclaration(; kwargs...)
    site = "Systems.RadiationDeclaration"
    k, _ = read_keywords(site, values(kwargs),
                         (:g_points, :interval, :ceiling_fraction, :cycles), ())
    FT = float_type("interval", site, k.interval)
    interval = require_positive("interval", site,
        require_disposition("interval", site, k.interval, FT, TIME, DECLARED))
    fraction = require_interval("ceiling_fraction", site,
        require_disposition("ceiling_fraction", site, k.ceiling_fraction, FT, DIMENSIONLESS,
                            DECLARED),
        zero(FT), false, one(FT), true)
    g = k.g_points
    if !(g isa Absent)
        (g isa Tuple && !isempty(g)) || refuse(
            "g_points", site,
            "a $(nameof(typeof(g))) where a tuple of one count per band is required; a " *
            "scalar is not a value per band (REQ-SYS-103 item 5)")
        for d in g
            require_interval("g_points", site,
                require_disposition("g_points", site, d, Int, DIMENSIONLESS, DECLARED),
                1, true, typemax(Int), true)
        end
    end
    cycles = require_type("cycles", site, k.cycles, RadiationCycles{FT})
    return RadiationDeclaration{FT,typeof(g),typeof(cycles)}(
        Checked(), g, interval, fraction, cycles)
end

"""
The rounded operations of the orbital distance over the semi-major axis,
`1 - e cos(E)`: one library transcendental at two, being within one ulp, one multiply
and one subtraction.
"""
const ORBIT_DISTANCE_TERMS = 4

"""
    orbit_modulates(system)

`true` where the planet's orbit modulates the instellation: the eccentricity of the
planet's orbit exceeds `error_bound(FT, ORBIT_DISTANCE_TERMS, 1)`, or the sine of the
planet's obliquity exceeds `error_bound(FT, DECLINATION_TERMS, 1)`.
"""
function orbit_modulates(s::System{FT}) where {FT}
    e = value(s.orbits.planet.eccentricity)
    obliquity = value(s.planet.obliquity)
    return e > error_bound(FT, ORBIT_DISTANCE_TERMS, one(FT)) ||
           sin(obliquity) > error_bound(FT, DECLINATION_TERMS, one(FT))
end

"""
    ceiling_terms(system, cycles)

The bounding terms of the radiation ceiling that `system` and `cycles` define, as
`(name, duration)` pairs in the order mean solar day, eclipse duration, orbital
period: the mean solar day where `cycles` holds one; the shortest eclipse duration
where it holds any; and the orbital period of the planet's orbit where
`orbit_modulates(system)`.
"""
function ceiling_terms(s::System{FT}, cycles::RadiationCycles{FT}) where {FT}
    terms = Tuple{Symbol,FT}[]
    cycles.diurnal_cycle isa Undefined ||
        push!(terms, (:mean_solar_day, value(cycles.diurnal_cycle)))
    cycles.eclipse_durations isa Undefined ||
        push!(terms, (:eclipse_duration, minimum(value, cycles.eclipse_durations)))
    orbit_modulates(s) &&
        push!(terms, (:orbital_period, orbital_period(s, s.orbits.planet)))
    return terms
end

"""
    radiation_ceiling(system, cycles, fraction)

`(ceiling, bound_by, shortest)`: `shortest`, the shortest duration of
`ceiling_terms(system, cycles)`, the first of equal ones, and `bound_by` its name, or
the least value the cloud timescale declares and `:cloud_timescale` where there is
none; and `ceiling`, `fraction * shortest`.
"""
function radiation_ceiling(s::System{FT}, cycles::RadiationCycles{FT}, fraction::FT) where {FT}
    terms = ceiling_terms(s, cycles)
    bound_by, shortest = isempty(terms) ?
        (:cloud_timescale, minimum(declared_values(cycles.cloud_timescale))) :
        terms[argmin(map(last, terms))]
    return fraction * shortest, bound_by, shortest
end

"""
    RadiationCadence

The radiation scheme as a `Profile` holds it: the `g_points`, `interval` and
`ceiling_fraction` of its `RadiationDeclaration`, the `ceiling` `Derived` by
`radiation_ceiling` at the least value the ceiling fraction declares, and `bound_by`,
the name of the term that bound it.
"""
struct RadiationCadence{FT,G,N}
    g_points::G
    interval::Disposition{FT,typeof(TIME)}
    ceiling_fraction::Disposition{FT,typeof(DIMENSIONLESS)}
    ceiling::Derived{FT,typeof(TIME),N}
    bound_by::Symbol
end

"""
    resolve_radiation(site, system, declaration)

The `RadiationCadence` of `declaration` on `system`. Refuses at `site` when any value
the interval declares exceeds the `Derived` ceiling, naming the term that bound it
(decision 0014).
"""
function resolve_radiation(site::AbstractString, s::System{FT},
                           r::RadiationDeclaration{FT}) where {FT}
    fraction = minimum(declared_values(r.ceiling_fraction))
    ceiling, bound_by, shortest = radiation_ceiling(s, r.cycles, fraction)
    for v in declared_values(r.interval)
        v <= ceiling || refuse(
            "interval", site,
            "the radiation interval $(v) exceeds its Derived ceiling $(ceiling), the " *
            "fraction $(fraction) of the $(bound_by) $(shortest), which bound it " *
            "(decision 0014)")
    end
    derived = Derived(value = ceiling, dim = TIME, from = (:system, :radiation),
                      rule = :radiation_ceiling, fields = PROFILE_KEYWORDS)
    return RadiationCadence(r.g_points, r.interval, r.ceiling_fraction, derived, bound_by)
end

# ---------------------------------------------------------------- slow tier and exits

"""
    SlowTier(; acceleration, refresh_interval)

The slow tier of decision 0023: `acceleration`, the `Bracketed` dimensionless ratio of
terrain time to climate time, every declared value one or above; and
`refresh_interval`, the longest declared duration between two climate refreshes,
above zero.
"""
struct SlowTier{FT}
    acceleration::Bracketed{FT,typeof(DIMENSIONLESS)}
    refresh_interval::Disposition{FT,typeof(TIME)}

    SlowTier{FT}(::Checked, a, r) where {FT} = new{FT}(a, r)
end

function SlowTier(; kwargs...)
    site = "Systems.SlowTier"
    k, _ = read_keywords(site, values(kwargs), (:acceleration, :refresh_interval), ())
    FT = float_type("acceleration", site, k.acceleration)
    acceleration = require_interval("acceleration", site,
        require_disposition("acceleration", site, k.acceleration, FT, DIMENSIONLESS,
                            (Bracketed,)),
        one(FT), true, typemax(FT), true)
    refresh = require_positive("refresh_interval", site,
        require_disposition("refresh_interval", site, k.refresh_interval, FT, TIME, DECLARED))
    return SlowTier{FT}(Checked(), acceleration, refresh)
end

"The dimensionless normalisations an exit tolerance is stored in (decision 0023)."
const EXIT_NORMALISATIONS = (:absorbed_instellation, :aa_scatter,
                             :stock_per_relaxation_time, :roundoff_bound)

"""
    ExitBracket(; loop, criterion, normalisation, tolerance)

One exit criterion of one loop: the `loop` and `criterion` names, the `normalisation`
the tolerance is a multiple of, one of `EXIT_NORMALISATIONS`, and `tolerance`, a
dimensionless disposition above zero. A tolerance carrying any other dimension is
refused as absolute.
"""
struct ExitBracket{FT}
    loop::Symbol
    criterion::Symbol
    normalisation::Symbol
    tolerance::Disposition{FT,typeof(DIMENSIONLESS)}

    ExitBracket{FT}(::Checked, l, c, n, t) where {FT} = new{FT}(l, c, n, t)
end

function ExitBracket(; kwargs...)
    site = "Systems.ExitBracket"
    k, _ = read_keywords(site, values(kwargs),
                         (:loop, :criterion, :normalisation, :tolerance), ())
    loop = require_type("loop", site, k.loop, Symbol)
    criterion = require_type("criterion", site, k.criterion, Symbol)
    k.normalisation in EXIT_NORMALISATIONS || refuse(
        "normalisation", site,
        "$(k.normalisation) is not one of $(join(EXIT_NORMALISATIONS, ", "))")
    t = k.tolerance
    FT = float_type("tolerance", site, t)
    dimension(t) === DIMENSIONLESS || refuse(
        "tolerance", site,
        "an absolute tolerance in $(signature(dimension(t))) is refused; the profile " *
        "stores the dimensionless bracket (decision 0023)")
    tolerance = require_positive("tolerance", site,
        require_disposition("tolerance", site, t, FT, DIMENSIONLESS, NON_CLOSURE))
    return ExitBracket{FT}(Checked(), loop, criterion, k.normalisation, tolerance)
end

# ---------------------------------------------------------------- the profile

"The keywords of `Profile`, the set a `Derived` value of a profile names its inputs in."
const PROFILE_KEYWORDS = (:label, :system, :components, :radiation, :fast_precision,
                          :slow_tier, :memory_ceiling, :daily_fallback_interval,
                          :exit_brackets)

"The floating-point types the fast prognostic fields may be held in."
const FAST_PRECISIONS = (Float32, Float64)

"""
    Profile

A named set of the levels, ladders, cadences, precision, ceilings and exit brackets a
run of one system uses (decision 0014). Build it with the keyword constructor, which
has no defaults:

    Profile(; label, system, components, radiation, fast_precision, slow_tier,
              memory_ceiling, daily_fallback_interval, exit_brackets)

`label` is a `Symbol`; `system` the `System{FT}` the profile is resolved on, read and
not held; `components` a tuple of `ComponentDeclaration{FT}` with distinct names, or an
`Absent`, held as `Component`s; `radiation` a `RadiationDeclaration{FT}` or an
`Absent`, held as a `RadiationCadence`; `fast_precision` one of `FAST_PRECISIONS`;
`slow_tier` a `SlowTier{FT}` or an `Absent`; `memory_ceiling` a declared count of
bytes above zero, an `Int`; `daily_fallback_interval` a `Bracketed` duration above
zero whose every declared value is at most the orbital period of the planet's orbit,
or an `Absent`; `exit_brackets` a tuple of `ExitBracket{FT}` naming each loop and
criterion once, or an `Absent`.
"""
struct Profile{FT,C,R,P,S,D,E}
    label::Symbol
    components::C
    radiation::R
    fast_precision::Type{P}
    slow_tier::S
    memory_ceiling::Disposition{Int,typeof(DIMENSIONLESS)}
    daily_fallback_interval::D
    exit_brackets::E

    Profile{FT,C,R,P,S,D,E}(::Checked, fields...) where {FT,C,R,P,S,D,E} =
        new{FT,C,R,P,S,D,E}(fields...)
end

"The `FT` of a system."
system_precision(::System{FT}) where {FT} = FT

function Profile(; kwargs...)
    site = "Systems.Profile"
    k, _ = read_keywords(site, values(kwargs), PROFILE_KEYWORDS, ())
    label = require_type("label", site, k.label, Symbol)
    system = require_type("system", site, k.system, System)
    FT = system_precision(system)

    components = k.components
    if !(components isa Absent)
        (components isa Tuple && !isempty(components)) || refuse(
            "components", site,
            "a $(nameof(typeof(components))) where a tuple of one or more component " *
            "declarations, or an Absent, is required")
        for c in components
            require_type("components", site, c, ComponentDeclaration{FT})
        end
        names = map(c -> c.name, components)
        length(unique(names)) == length(names) || refuse(
            "components", site, "$(names) names one component twice")
        components = map(c -> resolve_component(site, system, c), components)
    end

    radiation = k.radiation isa Absent ? k.radiation :
        resolve_radiation(site, system,
                          require_type("radiation", site, k.radiation, RadiationDeclaration{FT}))

    k.fast_precision in FAST_PRECISIONS || refuse(
        "fast_precision", site,
        "$(k.fast_precision) is not one of $(join(FAST_PRECISIONS, ", "))")

    slow_tier = require_type("slow_tier", site, k.slow_tier, Union{SlowTier{FT},Absent})

    memory_ceiling = require_positive("memory_ceiling", site,
        require_disposition("memory_ceiling", site, k.memory_ceiling, Int, DIMENSIONLESS,
                            DECLARED))

    fallback = k.daily_fallback_interval
    if !(fallback isa Absent)
        require_positive("daily_fallback_interval", site,
            require_disposition("daily_fallback_interval", site, fallback, FT, TIME,
                                (Bracketed,)))
        period = orbital_period(system, system.orbits.planet)
        for v in declared_values(fallback)
            v <= period || refuse(
                "daily_fallback_interval", site,
                "$(v) exceeds the orbital period $(period) of the planet's orbit, the " *
                "high end of the fallback interval (decision 0023)")
        end
    end

    exits = k.exit_brackets
    if !(exits isa Absent)
        (exits isa Tuple && !isempty(exits)) || refuse(
            "exit_brackets", site,
            "a $(nameof(typeof(exits))) where a tuple of one or more exit brackets, or " *
            "an Absent, is required")
        for e in exits
            require_type("exit_brackets", site, e, ExitBracket{FT})
        end
        pairs = map(e -> (e.loop, e.criterion), exits)
        length(unique(pairs)) == length(pairs) || refuse(
            "exit_brackets", site, "$(pairs) names one criterion of one loop twice")
    end

    return Profile{FT,typeof(components),typeof(radiation),k.fast_precision,
                   typeof(slow_tier),typeof(fallback),typeof(exits)}(
        Checked(), label, components, radiation, k.fast_precision, slow_tier,
        memory_ceiling, fallback, exits)
end

"""
    refuse_over_ceiling(profile, declarations)

`Backends.refuse_over(declarations, value(profile.memory_ceiling))`: refuses before
allocating when the budget of `declarations` exceeds the profile's memory ceiling.
"""
refuse_over_ceiling(p::Profile, declarations) =
    refuse_over(declarations, value(p.memory_ceiling))

# ---------------------------------------------------------------- fast and full

"""
    founding_absences()

The `Absent` settings of `fast_profile` and `full_profile`, by keyword, each naming the
row or milestone that carries its owner.
"""
founding_absences() = (
    components = Absent(argument =
        "no component of decision 0009 is in the tree; each component's target " *
        "spacing, finest spacing and ladder enter fast and full with the component, " *
        "the atmosphere core's with fiddlybits-52v.4.14"),
    radiation = Absent(argument =
        "the radiation scheme of decision 0016, whose bands the g-points count and " *
        "whose calls the interval spaces, is milestone M4, fiddlybits-53e"),
    slow_tier = Absent(argument =
        "the slow tier of decision 0023 couples the terrain to the climate, first run " *
        "at milestone M7, fiddlybits-caz"),
    daily_fallback_interval = Absent(argument =
        "the daily tier of decision 0023 steps vegetation, milestone M9, fiddlybits-pie"),
    exit_brackets = Absent(argument =
        "the loops of decision 0023 are built by fiddlybits-52v.11.3 and first " *
        "evaluated on the coupled case at milestone M7, fiddlybits-caz"))

"""
    fast_profile(; system, memory_ceiling)

The fast profile of decision 0014 on `system`: labelled `:fast`, its fast prognostic
fields in `Float32`, `memory_ceiling` the declared bytes of the card it runs on, and
every other setting from `founding_absences`.
"""
function fast_profile(; kwargs...)
    k, _ = read_keywords("Systems.fast_profile", values(kwargs),
                         (:system, :memory_ceiling), ())
    return Profile(; label = :fast, system = k.system, fast_precision = Float32,
                   memory_ceiling = k.memory_ceiling, founding_absences()...)
end

"""
    full_profile(; system, memory_ceiling)

The full profile of decision 0014 on `system`: labelled `:full`, its fast prognostic
fields in `Float64`, `memory_ceiling` the declared bytes of the card it runs on, and
every other setting from `founding_absences`.
"""
function full_profile(; kwargs...)
    k, _ = read_keywords("Systems.full_profile", values(kwargs),
                         (:system, :memory_ceiling), ())
    return Profile(; label = :full, system = k.system, fast_precision = Float64,
                   memory_ceiling = k.memory_ceiling, founding_absences()...)
end

# ---------------------------------------------------------------- strip

"A component's levels and ladder, its name carried by the type parameter `Name`."
struct StrippedComponent{Name,L}
    level::Int
    finest_level::Int
    ladder::L
end

"The radiation cadence's values, the term that bound its ceiling named by `BoundBy`."
struct StrippedRadiation{FT,BoundBy,G}
    g_points::G
    interval::FT
    ceiling::FT
end

"The slow tier's values."
struct StrippedSlowTier{FT}
    acceleration::FT
    refresh_interval::FT
end

"One exit tolerance, its loop, criterion and normalisation named by type parameters."
struct StrippedExit{Loop,Criterion,Normalisation,FT}
    tolerance::FT
end

"""
The isbits values of a `Profile`, its label and fast precision named by the type
parameters `Label` and `Precision`. An `Absent` setting strips to `nothing`.
"""
struct StrippedProfile{FT,Label,Precision,C,R,S,D,E}
    components::C
    radiation::R
    slow_tier::S
    memory_ceiling::Int
    daily_fallback_interval::D
    exit_brackets::E
end

"The plain values of one profile setting; `nothing` for an `Absent`."
strip_setting(::Absent) = nothing
strip_setting(d::Bracketed) = value(d)
strip_setting(counts::Tuple) = map(value, counts)
strip_setting(l::VerticalLadder) = map(value, l.interfaces)
strip_setting(c::Component) = StrippedComponent{c.name,typeof(strip_setting(c.ladder))}(
    value(c.level), value(c.finest_level), strip_setting(c.ladder))
strip_setting(r::RadiationCadence{FT}) where {FT} =
    StrippedRadiation{FT,r.bound_by,typeof(strip_setting(r.g_points))}(
        strip_setting(r.g_points), value(r.interval), value(r.ceiling))
strip_setting(t::SlowTier{FT}) where {FT} =
    StrippedSlowTier{FT}(value(t.acceleration), value(t.refresh_interval))
strip_setting(e::ExitBracket{FT}) where {FT} =
    StrippedExit{e.loop,e.criterion,e.normalisation,FT}(value(e.tolerance))
strip_setting(members::Tuple{Vararg{Union{Component,ExitBracket}}}) = map(strip_setting, members)

"""
    strip(profile)

The `StrippedProfile` of `profile`: every value it holds as a plain `FT` or `Int`, the
names a kernel reads members by carried as type parameters. A function of `profile`
alone.
"""
function strip(p::Profile{FT,C,R,P}) where {FT,C,R,P}
    c = strip_setting(p.components)
    r = strip_setting(p.radiation)
    s = strip_setting(p.slow_tier)
    d = strip_setting(p.daily_fallback_interval)
    e = strip_setting(p.exit_brackets)
    return StrippedProfile{FT,p.label,P,typeof(c),typeof(r),typeof(s),typeof(d),typeof(e)}(
        c, r, s, value(p.memory_ceiling), d, e)
end
