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
    kendall_score(ranks)

Kendall's `S = sum(sign(ranks[j] - ranks[i]) for i < j)`: the count of increasing
pairs minus the count of decreasing pairs of `ranks` against position.
"""
function kendall_score(ranks::AbstractVector{Int})
    n = length(ranks)
    s = 0
    for i in 1:n, j in (i + 1):n
        s += sign(ranks[j] - ranks[i])
    end
    return s
end

"""
    trend_statistic(ranks)

`abs(kendall_score(ranks))`.
"""
trend_statistic(ranks::AbstractVector{Int}) = abs(kendall_score(ranks))

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
    q_binomial(n, k)

The coefficients, constant term first, of the q-binomial coefficient `[n, k]_q` as
`BigInt`s, from `[m, 0] = [m, m] = 1` and `[m, j] = [m - 1, j] + q^(m - j) [m - 1, j - 1]`
(Stanley, Enumerative Combinatorics vol. 1, 2nd ed., version of 15 July 2011, eq. 1.67,
p. 62).
"""
function q_binomial(n::Int, k::Int)
    0 <= k <= n ||
        refuse("q-binomial coefficient", "Fields.q_binomial",
               "k must lie in 0:n; got n = $(n), k = $(k)")
    row = [BigInt[1]]
    for m in 1:n
        top = min(m, k)
        next = Vector{Vector{BigInt}}(undef, top + 1)
        for j in 0:top
            if j == 0 || j == m
                next[j + 1] = BigInt[1]
                continue
            end
            kept = row[j + 1]
            shifted = row[j]
            shift = m - j
            span = length(shifted) + shift
            poly = zeros(BigInt, max(length(kept), span))
            for i in eachindex(kept)
                poly[i] += kept[i]
            end
            for i in eachindex(shifted)
                poly[i + shift] += shifted[i]
            end
            next[j + 1] = poly
        end
        row = next
    end
    return row[k + 1]
end

"""
    polynomial_product(a, b)

The coefficients, constant term first, of the product of the polynomials whose
coefficients, constant term first, are `a` and `b`.
"""
function polynomial_product(a::Vector{BigInt}, b::Vector{BigInt})
    span = length(a) + length(b)
    c = zeros(BigInt, span - 1)
    for i in eachindex(a), j in eachindex(b)
        term = a[i] * b[j]
        c[i + j - 1] += term
    end
    return c
end

"""
    inversion_counts(sizes)

`c` with `c[k + 1]` the number of distinct orderings of a multiset with multiplicities
`sizes` that have `k` inversions (pairs `i < j` with the `i`-th element greater): the
coefficients of the q-multinomial coefficient over `sizes`, formed as the product of
`q_binomial(n - sizes[1] - ... - sizes[g - 1], sizes[g])` over `g`, `n = sum(sizes)`
(Stanley, Enumerative Combinatorics vol. 1, 2nd ed., version of 15 July 2011,
Proposition 1.7.1, eq. 1.68, p. 63, and eq. 1.66, p. 62).
"""
function inversion_counts(sizes::AbstractVector{Int})
    remaining = sum(sizes; init = 0)
    counts = BigInt[1]
    for a in sizes
        counts = polynomial_product(counts, q_binomial(remaining, a))
        remaining -= a
    end
    return counts
end

"""
    trend_tail(ranks)

`(d, total)`: `total` the number of distinct orderings of `ranks`, and `d` the number
of them whose `trend_statistic` is at least `trend_statistic(ranks)`. Computed from
`inversion_counts` over the multiplicities of the values of `ranks`: an ordering with
`k` inversions has `kendall_score` equal to `untied - 2k`, `untied` the number of
pairs of unequal values.
"""
function trend_tail(ranks::AbstractVector{Int})
    n = length(ranks)
    sizes = [count(==(v), ranks) for v in sort(unique(ranks))]
    counts = inversion_counts(sizes)
    all_pairs = binomial(n, 2)
    tied_pairs = sum((binomial(a, 2) for a in sizes); init = 0)
    untied = all_pairs - tied_pairs
    observed = trend_statistic(ranks)
    d = big(0)
    for k in 0:(length(counts) - 1)
        twice = 2 * k
        abs(untied - twice) >= observed && (d += counts[k + 1])
    end
    return d, sum(counts)
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
    uniform_index(draw, counter, i)

`(j, counter)`: `j` in `1:i` from the `UInt64` words `draw(counter + 1)`,
`draw(counter + 2)`, ..., taking the first word `u` with `u >= (2^64 - i) % i` and
returning `j = u % i + 1`, and `counter` advanced by the number of words read.
"""
function uniform_index(draw::F, counter::Int, i::Int) where {F}
    m = UInt64(i)
    lowest = (typemax(UInt64) - m + 1) % m
    while true
        counter += 1
        u = draw(counter)::UInt64
        u >= lowest && return Int(u % m) + 1, counter
    end
end

"""
    shuffle_with_draws!(work, draw, counter)

`work` reordered in place by swapping `work[i]` with `work[j]` for `i` from
`length(work)` down to 2, `j` the `uniform_index(draw, counter, i)` of each step.
Returns `counter` advanced by the number of words read.
"""
function shuffle_with_draws!(work::Vector{Int}, draw::F, counter::Int) where {F}
    for i in length(work):-1:2
        j, counter = uniform_index(draw, counter, i)
        work[i], work[j] = work[j], work[i]
    end
    return counter
end

"""
    random_count_at_least(statistic, values, permutations, draw)

`d`: one for `values` itself, plus the number of `permutations - 1` orderings, each
`values` put through `shuffle_with_draws!` with one word counter running across them
from `0`, whose `statistic` is at least `statistic(values)`.

`d / permutations` is the p-value of the random permutation test of Hemerik and Goeman
(2018, arXiv:1411.7565, Definition 2 and Theorem 2, section 3.3, p. 11), the identity
included and the orderings drawn with replacement.
"""
function random_count_at_least(statistic::F, values::AbstractVector{Int},
                               permutations::Integer, draw::G) where {F,G}
    observed = statistic(values)
    work = collect(values)
    counter = 0
    d = 1
    for _ in 2:permutations
        copyto!(work, values)
        counter = shuffle_with_draws!(work, draw, counter)
        statistic(work) >= observed && (d += 1)
    end
    return d
end

"""
    exchangeable_minimum_length(false_alarm)

The smallest `n >= 2` with `2 / factorial(n) <= false_alarm`, computed exactly: the
series length below which no ordering of `n` distinct values has a `trend_tail` or
`count_at_least` p-value at or under `false_alarm` for `trend_statistic` or
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
    random_permutation_minimum(false_alarm)

The smallest permutation count `w` with `1 / w <= false_alarm`, computed exactly: the
count below which `random_count_at_least` gives no `d / w` at or under `false_alarm`.
"""
function random_permutation_minimum(false_alarm::Real)
    a = Rational{BigInt}(false_alarm)
    return Int(ceil(1 / a))
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

"Refuse `classify` naming `test`, `false_alarm` and what the test needs."
too_short(test, false_alarm, needs) =
    refuse("residual classification", "Fields.classify",
           "the $(test) test at false-alarm probability $(false_alarm) needs $(needs)")

"""
    trend_rejects(residuals, false_alarm)

Whether `trend_tail(doubled_midranks(residuals))` gives `d / total <= false_alarm`.

Refuses naming the trend test and `exchangeable_minimum_length(false_alarm)` when
`residuals` is shorter than that length.
"""
function trend_rejects(residuals::AbstractVector{<:Real}, false_alarm::Real)
    n = length(residuals)
    needed = exchangeable_minimum_length(false_alarm)
    n >= needed || too_short("trend", false_alarm, "at least $(needed) windows; got $(n)")
    d, total = trend_tail(doubled_midranks(residuals))
    return d <= Rational{BigInt}(false_alarm) * total
end

"""
    successive_difference_rejects(residuals, false_alarm, permutations, draw)

Whether the p-value of `successive_difference_statistic` over
`ranks = doubled_midranks(residuals)` is at most `false_alarm`. When
`factorial(length(residuals)) <= permutations` the p-value is `d / total` of
`count_at_least`; otherwise it is `random_count_at_least(..., permutations, draw) /
permutations`.

Refuses naming the successive-difference test: in the first case when `residuals` is
shorter than `exchangeable_minimum_length(false_alarm)`, and in the second when
`permutations` is below `random_permutation_minimum(false_alarm)`.
"""
function successive_difference_rejects(residuals::AbstractVector{<:Real},
                                       false_alarm::Real, permutations::Integer,
                                       draw::F) where {F}
    n = length(residuals)
    a = Rational{BigInt}(false_alarm)
    ranks = doubled_midranks(residuals)
    test = "successive-difference"
    if factorial(big(n)) <= permutations
        needed = exchangeable_minimum_length(false_alarm)
        n >= needed ||
            too_short(test, false_alarm,
                      "at least $(needed) windows when all $(factorial(big(n))) " *
                      "orderings are enumerated; got $(n)")
        d, total = count_at_least(successive_difference_statistic, ranks)
        return d <= a * total
    end
    needed = random_permutation_minimum(false_alarm)
    permutations >= needed ||
        too_short(test, false_alarm,
                  "at least $(needed) random permutations; got $(permutations)")
    d = random_count_at_least(successive_difference_statistic, ranks, permutations, draw)
    return d <= a * permutations
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
    n >= needed || too_short("offset", false_alarm, "at least $(needed) windows; got $(n)")
    tail = binomial_upper_tail(n, offset_count(residuals, tolerances))
    doubled = 2 * tail
    return doubled <= Rational{BigInt}(false_alarm) * big(2)^n
end

"""
    classify(windows, residuals, tolerances; false_alarm, permutations, draw)

The `ResidualSignature` of closure residuals measured at the strictly increasing
`windows`, each against the tolerance at its window, with every test run at the
false-alarm probability `false_alarm` the caller declares.

`permutations` is the permutation count the successive-difference test declares, and
`draw` the function it reads its random words from: `draw(i)` a `UInt64` for each
counter `i = 1, 2, ...`, read in that order and only when
`factorial(length(residuals)) > permutations`.

Three tests, `n = length(residuals)`:

- trend: `trend_rejects(residuals, false_alarm)`, exact at every length. Null model:
  the residuals are exchangeable, as independent errors of one distribution about one
  level are.
- successive difference: `successive_difference_rejects(residuals, false_alarm,
  permutations, draw)`, rejecting when the ranks move by less between neighbouring
  windows than reorderings do. Null model: the same.
- offset: `offset_rejects(residuals, tolerances, false_alarm)`. Null model: the
  residuals are independent and each lies above its tolerance with probability at
  most one half and below its negated tolerance with probability at most one half, as
  an offset within the tolerance at every window plus errors of median zero does.

When `abs(residuals[i]) <= tolerances[i]` at every window, `Unexplained` when the
successive-difference test rejects and `Rounding` otherwise. When some residual lies
beyond its tolerance, `Leak` when the trend test rejects; otherwise `Unexplained` when
the successive-difference test rejects; otherwise `StockOmission` when the offset test
rejects; otherwise `Unexplained`.

Refuses when `windows`, `residuals` and `tolerances` disagree in length; when `windows`
is not strictly increasing; when a residual is not finite or a tolerance is negative
or not finite; when `false_alarm` does not lie strictly between 0 and 1; when
`permutations` is below 1; and when a test is reached that its minimum length or
permutation count refuses, naming the test.
"""
function classify(windows::AbstractVector{<:Real}, residuals::AbstractVector{<:Real},
                  tolerances::AbstractVector{<:Real}; false_alarm::Real,
                  permutations::Integer, draw)
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
    permutations >= 1 ||
        refuse("residual classification", "Fields.classify",
               "permutations must be at least 1; got $(permutations)")

    within = all(i -> abs(residuals[i]) <= tolerances[i], eachindex(residuals, tolerances))
    if within
        successive_difference_rejects(residuals, false_alarm, permutations, draw) &&
            return Unexplained()
        return Rounding()
    end
    trend_rejects(residuals, false_alarm) && return Leak()
    successive_difference_rejects(residuals, false_alarm, permutations, draw) &&
        return Unexplained()
    offset_rejects(residuals, tolerances, false_alarm) && return StockOmission()
    return Unexplained()
end

"""
    classify(ledgers, windows; false_alarm, permutations, draw)

`classify` read off a series of `Ledger`s at their `windows`, one length per ledger.
"""
classify(ledgers::AbstractVector{<:Ledger}, windows::AbstractVector{<:Real};
         false_alarm::Real, permutations::Integer, draw) =
    classify(windows, residual.(ledgers), tolerance.(ledgers);
             false_alarm = false_alarm, permutations = permutations, draw = draw)
