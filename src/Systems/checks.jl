# The keyword door and the checks every block constructor of System shares:
# docs/plans/fiddlybits-52v.4-system.md, section "The struct"; decisions 0004, 0007.

using ..Verdicts: refuse
using ..Dimensions: Dim, signature
using ..Dispositions: Disposition, Sourced, Derived, Bracketed, Irreducible, Closure,
                      value, dimension
using ..Reductions: error_bound

"The word a keyword is refused for carrying (decision 0008)."
const DAY_WORD = "day"

"The dispositions a caller declares a primary quantity with."
const DECLARED = (Sourced, Bracketed, Irreducible)

"""
    Checked()

The token every inner constructor of a `System` block takes first. The keyword
constructors pass it after their refusals have run; nothing else does.
"""
struct Checked end

"""
    read_keywords(site, given, required, checked)

`given`, a `NamedTuple` of keywords, split into `(declared, supplied)`: `declared`
holds every keyword of `required` in that order, and `supplied` holds the keywords of
`checked` that are present. Refuses at `site`, in this order: any keyword one of whose
underscore-separated words is `day` (decision 0008); any keyword in neither `required`
nor `checked`; any keyword of `required` that is absent. Each refusal names the
keyword.
"""
function read_keywords(site::AbstractString, given::NamedTuple,
                       required::NTuple{N,Symbol},
                       checked::NTuple{M,Symbol}) where {N,M}
    for key in keys(given)
        DAY_WORD in split(String(key), '_') && refuse(
            String(key), site,
            "a field named day is refused; the solar and mean solar day are " *
            "derived from the system (decision 0008)")
    end
    for key in keys(given)
        (key in required || key in checked) || refuse(
            String(key), site,
            "not a keyword of $(site); its keywords are $(join(required, ", "))" *
            (M == 0 ? "" : ", and the Derived values it checks, $(join(checked, ", "))"))
    end
    for key in required
        haskey(given, key) || refuse(
            String(key), site, "the keyword is missing, and $(site) has no defaults")
    end
    declared = NamedTuple{required}(Tuple(given[k] for k in required))
    present = Tuple(k for k in checked if haskey(given, k))
    supplied = NamedTuple{present}(Tuple(given[k] for k in present))
    return declared, supplied
end

"""
    require_disposition(quantity, site, d, FT, dim, admitted)

`d` when it is a `Disposition` of one of the types in `admitted`, carrying `dim`,
with a value of type `FT`. Refuses at `site` naming `quantity` otherwise.
"""
function require_disposition(quantity::AbstractString, site::AbstractString, d,
                             ::Type{FT}, dim::Dim, admitted::Tuple) where {FT}
    d isa Disposition || refuse(
        quantity, site,
        "a $(typeof(d)) where a disposition is required; every constant carries " *
        "one of the five (decision 0007)")
    any(A -> d isa A, admitted) || refuse(
        quantity, site,
        "$(nameof(typeof(d))) is not admitted; admitted: " *
        join(map(nameof, admitted), ", "))
    dimension(d) === dim || refuse(
        quantity, site,
        "the dimension $(signature(dimension(d))) is not $(signature(dim))")
    value(d) isa FT || refuse(
        quantity, site, "the value $(value(d)) is not a $(FT)")
    return d
end

"""
    float_type(quantity, site, d)

The floating-point type of the value `d` carries, which a block takes as its `FT`.
Refuses at `site` naming `quantity` when `d` is not a disposition over a
floating-point type.
"""
function float_type(quantity::AbstractString, site::AbstractString, d)
    (d isa Disposition && value(d) isa AbstractFloat) || refuse(
        quantity, site,
        "a $(typeof(d)) where a disposition over a floating-point value is required")
    return typeof(value(d))
end

"""
    require_type(quantity, site, x, T)

`x` when it is a `T`; refuses at `site` naming `quantity` and both types otherwise.
"""
function require_type(quantity::AbstractString, site::AbstractString, x, T::Type)
    x isa T || refuse(quantity, site, "a $(typeof(x)) where a $(T) is required")
    return x
end

"The values a disposition declares: its value, and a `Bracketed`'s two ends as well."
declared_values(d::Disposition) = (value(d),)
declared_values(d::Bracketed) = (d.value, d.low, d.high)

"""
    require_interval(quantity, site, d, low, low_closed, high, high_closed)

`d` when every value it declares (`declared_values`) lies in the interval from `low`
to `high`, each end included when its flag is `true`. Refuses at `site` naming
`quantity`, the value and the interval otherwise.
"""
function require_interval(quantity::AbstractString, site::AbstractString,
                          d::Disposition, low, low_closed::Bool, high,
                          high_closed::Bool)
    text = (low_closed ? "[" : "(") * "$(low), $(high)" * (high_closed ? "]" : ")")
    for v in declared_values(d)
        above = low_closed ? v >= low : v > low
        below = high_closed ? v <= high : v < high
        (above && below) || refuse(quantity, site, "$(v) lies outside $(text)")
    end
    return d
end

"""
    require_positive(quantity, site, d)

`d` when every value it declares is above zero; refuses at `site` otherwise.
"""
require_positive(quantity::AbstractString, site::AbstractString, d::Disposition) =
    require_interval(quantity, site, d, zero(value(d)), false, typemax(value(d)), true)

"""
    require_length(quantity, site, given, n, members)

`given` when it is a tuple of `n` entries, one per member of `members`. Refuses at
`site` naming `quantity` when `given` is not a tuple, which is a scalar given where
one value per member is required (REQ-SYS-103 item 5), and when its length is not
`n`.
"""
function require_length(quantity::AbstractString, site::AbstractString, given,
                        n::Integer, members::AbstractString)
    given isa Tuple || refuse(
        quantity, site,
        "a $(nameof(typeof(given))) where a tuple of $(n), one per $(members), is " *
        "required; a scalar is not a value per member (REQ-SYS-103 item 5)")
    length(given) == n || refuse(
        quantity, site,
        "$(length(given)) entries where $(n), one per $(members), are required")
    return given
end

"""
    require_names(quantity, site, names)

`names` when it is a non-empty tuple of distinct symbols; refuses at `site` naming
`quantity` otherwise.
"""
function require_names(quantity::AbstractString, site::AbstractString, names)
    (names isa Tuple && all(n -> n isa Symbol, names)) || refuse(
        quantity, site, "$(names) is not a tuple of names")
    isempty(names) && refuse(quantity, site, "names nothing")
    length(unique(names)) == length(names) || refuse(
        quantity, site, "$(names) names one member twice")
    return names
end

"""
    require_unit_sum(quantity, site, fractions)

`fractions`, a tuple of dispositions, when the sum of their values differs from one
by at most `Reductions.error_bound(FT, n, s)`, `n` the number of fractions and `s`
the sum of their absolute values. Refuses at `site` naming `quantity`, the sum and
the bound otherwise.
"""
function require_unit_sum(quantity::AbstractString, site::AbstractString,
                          fractions::Tuple)
    values_ = map(value, fractions)
    FT = typeof(first(values_))
    total = sum(values_)
    bound = error_bound(FT, length(values_), sum(abs, values_))
    abs(total - one(FT)) <= bound || refuse(
        quantity, site,
        "the fractions sum to $(total), which differs from one beyond the rounding " *
        "bound $(bound)")
    return fractions
end

"""
    rounding_bound(FT, terms, magnitude)

`Reductions.error_bound(FT, terms + 1, magnitude)`: the rounding of a rule evaluated
in `terms` rounded operations whose terms sum to at most `magnitude` in absolute
value, together with the one rounding that places a supplied value in `FT`.
"""
rounding_bound(::Type{FT}, terms::Integer, magnitude::Real) where {FT<:AbstractFloat} =
    error_bound(FT, terms + 1, magnitude)

"The number a supplied Derived value states: a plain value, or a disposition's value."
supplied_value(d::Disposition) = value(d)
supplied_value(x) = x

"""
    check_supplied(quantity, site, supplied, computed, terms, magnitude)

`computed` when `supplied`, a caller's value for a `Derived` quantity, is a value of
`computed`'s type within `rounding_bound(typeof(computed), terms, magnitude)` of it.
Refuses at `site` naming `quantity`, both values, their difference and the bound
otherwise (decision 0007).
"""
check_supplied(quantity::AbstractString, site::AbstractString, supplied,
               computed::FT, terms::Integer, magnitude::Real) where {FT<:AbstractFloat} =
    check_supplied_within(quantity, site, supplied, computed,
                          rounding_bound(FT, terms, magnitude))

"""
    check_supplied_within(quantity, site, supplied, computed, bound)

`computed` when `supplied` is a value of `computed`'s type within `bound` of it, the
bound a carried model states for its own evaluation. Refuses at `site` as
`check_supplied` does otherwise.
"""
function check_supplied_within(quantity::AbstractString, site::AbstractString,
                               supplied, computed::FT, bound::Real) where {FT<:AbstractFloat}
    s = supplied_value(supplied)
    s isa FT || refuse(
        quantity, site, "the supplied value $(s) is not a $(FT)")
    difference = abs(s - computed)
    difference <= bound || refuse(
        quantity, site,
        "the supplied value $(s) disagrees with the Derived value $(computed) by " *
        "$(difference), beyond the rounding bound $(bound)")
    return computed
end
