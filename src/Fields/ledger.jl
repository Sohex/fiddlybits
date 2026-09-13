# Ledger{Q}: the balance of one conserved quantity across one operation, with an
# inventory of what was lost and to where. docs/plans/fiddlybits-52v.3-fields.md,
# section "Ledgers", docs/requirements/num/closure-tolerance-from-floating-point.md
# (REQ-NUM-004) and docs/requirements/sys/one-declaration-per-quantity.md
# (REQ-SYS-103).

using ..Verdicts: refuse
using ..Reductions: error_bound

"""
    RESERVOIR_ACCUMULATOR

The one accumulator type a quantity declared a reservoir is held in (decision 0011):
`Float64`, whatever the working precision, matching `Reductions.compensated_sum`,
which accumulates in `Float64` regardless of `eltype` (decision 0029).
"""
const RESERVOIR_ACCUMULATOR = Float64

"""
    Ledger{Q,L}

The balance of the conserved quantity `Q`, a `Symbol`, across one operation: the
residual between what the operation should have preserved and what it reports, the
tolerance the residual is judged against, and the inventory of what was lost and to
where, as a `NamedTuple` of type `L` holding named amounts.

Built by the outer constructor below.
"""
struct Ledger{Q,L<:NamedTuple}
    residual::Float64
    tolerance::Float64
    losses::L
end

"""
    quantity(l::Ledger)

The `Symbol` naming the conserved quantity `l` balances.
"""
quantity(::Ledger{Q}) where {Q} = Q

"""
    residual(l::Ledger)
    tolerance(l::Ledger)
    losses(l::Ledger)

What `l` holds: the signed residual, the tolerance it is judged against, and the
named inventory of losses.
"""
residual(l::Ledger) = l.residual
tolerance(l::Ledger) = l.tolerance
losses(l::Ledger) = l.losses

"""
    closed(l::Ledger)

Whether `l`'s residual sits inside its tolerance: `abs(residual(l)) <= tolerance(l)`.
The predicate a state store reads to refuse a field whose ledger is open.
"""
closed(l::Ledger) = abs(l.residual) <= l.tolerance

"""
    Ledger{Q}(::Type{T}, n, magnitude, before, after, flux, losses = NamedTuple();
              reservoir)

The ledger for the conserved quantity `Q` over one operation that summed `n` terms of
magnitude bound `magnitude` while taking a stock from `before` to `after`, with `flux`
crossing the boundary and `losses` (a `NamedTuple` of named amounts) leaving by other
named routes.

`Q` is given as a type parameter, as `Measured{Name}` and `CategoricalLabel{Legend}`
carry a name. `n` and `magnitude` are the term count and the magnitude bound of the
summation the operation performed to reach `after`. `error_bound(T, n, magnitude)`
reads the tolerance from `Reductions` over them.

`T` is the accumulator type that summation ran in. `reservoir` declares whether `Q` is
a reservoir (decision 0011): when it is, `T` must be `RESERVOIR_ACCUMULATOR`, and any
other `T` is refused naming `Q`.

The residual is `(after - before) - flux + sum(losses)`.
"""
function Ledger{Q}(::Type{T}, n::Integer, magnitude::Real, before::Real, after::Real,
                    flux::Real, losses::L = NamedTuple();
                    reservoir::Bool) where {Q,T<:AbstractFloat,L<:NamedTuple}
    reservoir && T !== RESERVOIR_ACCUMULATOR &&
        refuse("ledger accumulator", "Fields.Ledger",
               "$(Q) is declared a reservoir and must accumulate in " *
               "$(RESERVOIR_ACCUMULATOR) or by compensated summation; given $(T)")
    tol = Float64(error_bound(T, n, magnitude))
    loss_values = Float64.(values(losses))
    lost = sum(loss_values; init = zero(Float64))
    res = Float64(after) - Float64(before) - Float64(flux) + lost
    return Ledger{Q,L}(res, tol, losses)
end

"""
    ResidualSignature

The closed set a series of closure residuals is classified into (REQ-NUM-004):
`Leak`, `StockOmission`, `Rounding`, and `Unexplained` for a series none of the other
three fits. `residual_signatures()` enumerates it; `classify` states the test each
member is decided by.
"""
abstract type ResidualSignature end

"A residual series with a trend in the window, beyond its tolerance at some window."
struct Leak <: ResidualSignature end

"A residual series with no trend, independent in level, offset beyond its tolerance."
struct StockOmission <: ResidualSignature end

"A residual series within its tolerance at every window and independent in level."
struct Rounding <: ResidualSignature end

"A residual series that `Leak`, `StockOmission` and `Rounding` do not fit."
struct Unexplained <: ResidualSignature end

"Every `ResidualSignature` singleton, in the order this module declares them."
residual_signatures() = (Leak(), StockOmission(), Rounding(), Unexplained())

"""
    doubled_midranks(x)

Twice the midrank of each element of `x`, as `Int`: for `x[i]`,
`2 * count(<(x[i]), x) + count(==(x[i]), x) + 1`.
"""
function doubled_midranks(x::AbstractVector{<:Real})
    n = length(x)
    ranks = Vector{Int}(undef, n)
    for i in 1:n
        below = count(<(x[i]), x)
        tied = count(==(x[i]), x)
        twice_below = 2 * below
        ranks[i] = twice_below + tied + 1
    end
    return ranks
end

"""
    trend_statistic(ranks)

`abs(S)` for Kendall's `S = sum(sign(ranks[j] - ranks[i]) for i < j)`: the count of
increasing pairs minus the count of decreasing pairs of `ranks` against position.
"""
function trend_statistic(ranks::AbstractVector{Int})
    n = length(ranks)
    s = 0
    for i in 1:n, j in (i + 1):n
        s += sign(ranks[j] - ranks[i])
    end
    return abs(s)
end

"""
    successive_difference_statistic(ranks)

`-sum((ranks[i + 1] - ranks[i])^2 for i in 1:(length(ranks) - 1))`: the negated sum of
squared successive differences of `ranks`.
"""
function successive_difference_statistic(ranks::AbstractVector{Int})
    total = 0
    for i in 1:(length(ranks) - 1)
        total += (ranks[i + 1] - ranks[i])^2
    end
    return -total
end

"""
    count_at_least(statistic, values)

`(d, total)`: `total = factorial(length(values))` as a `BigInt`, and `d` the number of
the `total` orderings of `values` whose `statistic` is at least `statistic(values)`.
Every ordering is visited once, each position from the first filled in turn by every
value not yet placed.

`d / total` is the permutation p-value `D / #G` over the full permutation group of
Hemerik and Goeman (2018, "Exact testing with random permutations", arXiv:1411.7565,
section 2.2), whose level is their Theorem 1.
"""
function count_at_least(statistic::F, values::AbstractVector{Int}) where {F}
    observed = statistic(values)
    work = collect(values)
    d = orderings_at_least!(statistic, work, 1, observed)
    return d, factorial(big(length(values)))
end

"""
    orderings_at_least!(statistic, work, k, observed)

The number of orderings of `work` that keep `work[1:(k - 1)]` in place and have
`statistic` at least `observed`. `work` holds its original order on return.
"""
function orderings_at_least!(statistic::F, work::Vector{Int}, k::Int, observed) where {F}
    n = length(work)
    k > n && return statistic(work) >= observed ? 1 : 0
    d = 0
    for j in k:n
        work[k], work[j] = work[j], work[k]
        d += orderings_at_least!(statistic, work, k + 1, observed)
        work[k], work[j] = work[j], work[k]
    end
    return d
end

"""
    exchangeable_minimum_length(false_alarm)

The smallest `n >= 2` with `2 / factorial(n) <= false_alarm`, computed exactly: the
series length below which `count_at_least` over `n` distinct values returns no
`d / total` at or under `false_alarm` for `trend_statistic` or
`successive_difference_statistic`, whose most extreme value each is reached by exactly
the two monotone orderings.
"""
function exchangeable_minimum_length(false_alarm::Real)
    a = Rational{BigInt}(false_alarm)
    n = 2
    while factorial(big(n)) * a < 2
        n += 1
    end
    return n
end

"""
    offset_count(residuals, tolerances)

`max(above, below)`: `above` the number of `i` with `residuals[i] > tolerances[i]`, and
`below` the number with `residuals[i] < -tolerances[i]`.
"""
function offset_count(residuals::AbstractVector{<:Real}, tolerances::AbstractVector{<:Real})
    above = 0
    below = 0
    for i in eachindex(residuals, tolerances)
        residuals[i] > tolerances[i] && (above += 1)
        residuals[i] < -tolerances[i] && (below += 1)
    end
    return max(above, below)
end

"""
    binomial_upper_tail(n, k)

`sum(binomial(n, j) for j in k:n)` as a `BigInt`: the number of the `2^n` sign patterns
of `n` values with at least `k` of one sign.
"""
function binomial_upper_tail(n::Integer, k::Integer)
    tail = big(0)
    for j in max(k, 0):n
        tail += binomial(big(n), j)
    end
    return tail
end

"""
    offset_minimum_length(false_alarm)

The smallest `n >= 1` with `2 / 2^n <= false_alarm`, computed exactly: the series
length below which the offset test in `classify` rejects at no count.
"""
function offset_minimum_length(false_alarm::Real)
    a = Rational{BigInt}(false_alarm)
    n = 1
    while big(2)^n * a < 2
        n += 1
    end
    return n
end

"""
    exchangeability_rejects(statistic, test, residuals, false_alarm)

Whether `count_at_least(statistic, doubled_midranks(residuals))` returns
`d / total <= false_alarm`.

Refuses naming `test` and `exchangeable_minimum_length(false_alarm)` when `residuals`
is shorter than that length.
"""
function exchangeability_rejects(statistic::F, test::AbstractString,
                                 residuals::AbstractVector{<:Real},
                                 false_alarm::Real) where {F}
    n = length(residuals)
    needed = exchangeable_minimum_length(false_alarm)
    n >= needed ||
        refuse("residual classification", "Fields.classify",
               "the $(test) test at false-alarm probability $(false_alarm) needs at " *
               "least $(needed) windows; got $(n)")
    d, total = count_at_least(statistic, doubled_midranks(residuals))
    return d <= Rational{BigInt}(false_alarm) * total
end

"""
    offset_rejects(residuals, tolerances, false_alarm)

Whether `2 * binomial_upper_tail(n, offset_count(residuals, tolerances)) / 2^n <=
false_alarm`, `n = length(residuals)`.

Refuses naming the offset test and `offset_minimum_length(false_alarm)` when
`residuals` is shorter than that length.
"""
function offset_rejects(residuals::AbstractVector{<:Real},
                        tolerances::AbstractVector{<:Real}, false_alarm::Real)
    n = length(residuals)
    needed = offset_minimum_length(false_alarm)
    n >= needed ||
        refuse("residual classification", "Fields.classify",
               "the offset test at false-alarm probability $(false_alarm) needs at " *
               "least $(needed) windows; got $(n)")
    tail = binomial_upper_tail(n, offset_count(residuals, tolerances))
    doubled = 2 * tail
    return doubled <= Rational{BigInt}(false_alarm) * big(2)^n
end

"""
    classify(windows, residuals, tolerances; false_alarm)

The `ResidualSignature` of closure residuals measured at the strictly increasing
`windows`, each against the tolerance at its window, with every test run at the
false-alarm probability `false_alarm` the caller declares.

Three tests, `n = length(residuals)`:

- trend: `exchangeability_rejects(trend_statistic, ...)`. Null model: the residuals
  are exchangeable, as independent errors of one distribution about one level are.
- successive difference: `exchangeability_rejects(successive_difference_statistic,
  ...)`, rejecting when the ranks move by less between neighbouring windows than
  reorderings do. Null model: the same.
- offset: `offset_rejects(residuals, tolerances, false_alarm)`. Null model: the
  residuals are independent and each lies above its tolerance with probability at
  most one half and below its negated tolerance with probability at most one half, as
  an offset within the tolerance at every window plus errors of median zero does.

When `abs(residuals[i]) <= tolerances[i]` at every window, `Unexplained` when the
successive-difference test rejects and `Rounding` otherwise. When some residual lies
beyond its tolerance, `Leak` when the trend test rejects; otherwise `Unexplained` when
the successive-difference test rejects; otherwise `StockOmission` when the offset test
rejects; otherwise `Unexplained`.

The trend and successive-difference tests enumerate all `factorial(n)` orderings.

Refuses when `windows`, `residuals` and `tolerances` disagree in length; when `windows`
is not strictly increasing; when a residual is not finite or a tolerance is negative
or not finite; when `false_alarm` does not lie strictly between 0 and 1; and when a
test is reached with fewer windows than its minimum length
(`exchangeable_minimum_length` for the trend and successive-difference tests,
`offset_minimum_length` for the offset test), naming the test.
"""
function classify(windows::AbstractVector{<:Real}, residuals::AbstractVector{<:Real},
                  tolerances::AbstractVector{<:Real}; false_alarm::Real)
    length(windows) == length(residuals) == length(tolerances) ||
        refuse("residual classification", "Fields.classify",
               "windows, residuals and tolerances must share one length; got " *
               "$(length(windows)), $(length(residuals)) and $(length(tolerances))")
    all(w -> w > 0, diff(windows)) ||
        refuse("residual classification", "Fields.classify",
               "windows must be strictly increasing; got $(windows)")
    all(isfinite, residuals) ||
        refuse("residual classification", "Fields.classify",
               "every residual must be finite; got $(residuals)")
    all(t -> isfinite(t) && t >= 0, tolerances) ||
        refuse("residual classification", "Fields.classify",
               "every tolerance must be finite and non-negative; got $(tolerances)")
    isfinite(false_alarm) && 0 < false_alarm < 1 ||
        refuse("residual classification", "Fields.classify",
               "false_alarm must lie strictly between 0 and 1; got $(false_alarm)")

    within = all(i -> abs(residuals[i]) <= tolerances[i], eachindex(residuals, tolerances))
    if within
        exchangeability_rejects(successive_difference_statistic, "successive-difference",
                                residuals, false_alarm) && return Unexplained()
        return Rounding()
    end
    exchangeability_rejects(trend_statistic, "trend", residuals, false_alarm) &&
        return Leak()
    exchangeability_rejects(successive_difference_statistic, "successive-difference",
                            residuals, false_alarm) && return Unexplained()
    offset_rejects(residuals, tolerances, false_alarm) && return StockOmission()
    return Unexplained()
end

"""
    classify(ledgers, windows; false_alarm)

`classify` read off a series of `Ledger`s at their `windows`, one length per ledger.
"""
classify(ledgers::AbstractVector{<:Ledger}, windows::AbstractVector{<:Real};
         false_alarm::Real) =
    classify(windows, residual.(ledgers), tolerance.(ledgers); false_alarm = false_alarm)
