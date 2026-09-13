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

The closed set a closure residual's time signature is classified into (REQ-NUM-004):
`Leak` grows linearly with the window, `StockOmission` is flat and independent of the
window at a magnitude the tolerance does not explain, and `Rounding` is flat within
the tolerance. `residual_signatures()` enumerates it.
"""
abstract type ResidualSignature end

"A residual that grows with the window: a flux counted on the wrong side, twice."
struct Leak <: ResidualSignature end

"A residual flat in the window at a magnitude the tolerance does not explain: a pool
missing from the inventory."
struct StockOmission <: ResidualSignature end

"A residual flat in the window and within the tolerance: the quantisation of the
arithmetic itself."
struct Rounding <: ResidualSignature end

"Every `ResidualSignature` singleton, in the order this module declares them."
residual_signatures() = (Leak(), StockOmission(), Rounding())

"""
    linear_fit(x, y)

`(a, b)` of the least-squares line `y = a + b*x` through the points `(x, y)`.

Refuses when the values of `x` are not all distinct.
"""
function linear_fit(x::AbstractVector{<:Real}, y::AbstractVector{<:Real})
    n = length(x)
    xf = Float64.(x)
    yf = Float64.(y)
    xm = sum(xf) / n
    ym = sum(yf) / n
    sxx = sum((xi - xm)^2 for xi in xf)
    sxx > 0 ||
        refuse("linear fit", "Fields.linear_fit",
               "the x values are not all distinct; got $(x)")
    sxy = sum((xf[i] - xm) * (yf[i] - ym) for i in 1:n)
    b = sxy / sxx
    bxm = b * xm
    a = ym - bxm
    return a, b
end

"""
    fit_residuals(x, y)

`(a, b, resid)`: `linear_fit(x, y)`'s intercept and slope, and `y` minus the fitted
line's value at each `x`, as `Float64`.
"""
function fit_residuals(x::AbstractVector{<:Real}, y::AbstractVector{<:Real})
    a, b = linear_fit(x, y)
    n = length(x)
    resid = Vector{Float64}(undef, n)
    for i in 1:n
        term = b * Float64(x[i])
        resid[i] = Float64(y[i]) - a - term
    end
    return a, b, resid
end

"""
    leak_signal(windows, residuals)

Whether `residuals` shows significant growth against `windows`.

`fit_residuals(windows, residuals)` is fit and its residual sum of squares `rss` is
formed. When `rss` is `0`, the value is `true` exactly when the fitted slope `b` is
nonzero. Otherwise, at `df = length(windows) - 2` residual degrees of freedom and
`n = length(windows)`, the value is `false` when `df <= 2`; when `df > 2`, it is
`abs(t) > sqrt(n^2 * df / (df - 2))`, `t` being `b` divided by its standard error
`sqrt((rss / df) / sxx)`, `sxx` the sum of squared deviations of `windows` from their
mean. `sqrt(df / (df - 2))` is the standard deviation of a `t`-distributed variable
with `df` degrees of freedom; `n^2` scales it against the `n` windows compared.
"""
function leak_signal(windows::AbstractVector{<:Real}, residuals::AbstractVector{<:Real})
    _, b, resid = fit_residuals(windows, residuals)
    rss = sum(abs2, resid)
    rss == 0 && return b != 0
    n = length(windows)
    df = n - 2
    df > 2 || return false
    xf = Float64.(windows)
    xm = sum(xf) / n
    sxx = sum((xi - xm)^2 for xi in xf)
    s2 = rss / df
    se_b = sqrt(s2 / sxx)
    se_b == 0 && return b != 0
    t = b / se_b
    dfm2 = df - 2
    nsq = n^2
    return abs(t) > sqrt(nsq * df / dfm2)
end

"""
    lag1_autocorrelation(series)

`(r1, bartlett_se)`: the lag-1 autocorrelation `r1` of the first differences of
`series`, and the Bartlett standard error `bartlett_se = 1 / sqrt(m)` of a lag-1
sample autocorrelation of a length-`m` white-noise series, `m = length(series) - 1`
the number of differences.

Refuses when `series` has fewer than 4 elements, `m - 1 < 2`, the minimum for the
autocorrelation's numerator to sum more than one term.
"""
function lag1_autocorrelation(series::AbstractVector{<:Real})
    n = length(series)
    n >= 4 ||
        refuse("lag-1 autocorrelation", "Fields.lag1_autocorrelation",
               "$(n) values give $(max(n - 1, 0)) first differences, and at least 3 " *
               "are needed for the numerator to sum more than one term")
    d = diff(Float64.(series))
    m = length(d)
    dbar = sum(d) / m
    numerator = sum((d[i] - dbar) * (d[i + 1] - dbar) for i in 1:(m - 1))
    denominator = sum((di - dbar)^2 for di in d)
    r1 = denominator == 0 ? zero(Float64) : numerator / denominator
    return r1, 1 / sqrt(m)
end

"""
    classify(windows, residuals, tolerances)

The `ResidualSignature` of a closure residual measured at each window length of
`windows`, against the residual and the tolerance measured at that window.

`Leak` when `leak_signal(windows, residuals)`. Otherwise, `r1, bartlett_se =
lag1_autocorrelation(residuals)` are formed, along with the mean of `residuals` and
the mean of `tolerances`; at `n = length(residuals)`, the value is `Rounding` when
the mean residual is at most the mean tolerance and
`abs(r1 - (-1 / 2)) <= sqrt(n) * bartlett_se`, and `StockOmission` otherwise.

Refuses when `windows`, `residuals` and `tolerances` disagree in length, when
`windows` is not strictly increasing, or when `windows` holds fewer than 4 values,
what `lag1_autocorrelation` needs.
"""
function classify(windows::AbstractVector{<:Real}, residuals::AbstractVector{<:Real},
                   tolerances::AbstractVector{<:Real})
    length(windows) == length(residuals) == length(tolerances) ||
        refuse("residual classification", "Fields.classify",
               "windows, residuals and tolerances must share one length; got " *
               "$(length(windows)), $(length(residuals)) and $(length(tolerances))")
    all(w -> w > 0, diff(windows)) ||
        refuse("residual classification", "Fields.classify",
               "windows must be strictly increasing; got $(windows)")
    length(windows) >= 4 ||
        refuse("residual classification", "Fields.classify",
               "at least 4 windows are needed; got $(length(windows))")

    leak_signal(windows, residuals) && return Leak()

    r1, bartlett_se = lag1_autocorrelation(residuals)
    n = length(residuals)
    mean_residual = sum(abs, residuals) / n
    mean_tolerance = sum(tolerances) / n
    target = -1 / 2
    band = sqrt(n) * bartlett_se
    near_minus_half = abs(r1 - target) <= band
    mean_residual <= mean_tolerance && near_minus_half && return Rounding()
    return StockOmission()
end

"""
    classify(ledgers, windows)

`classify` read off a series of `Ledger`s at their `windows`, one length per ledger.
"""
classify(ledgers::AbstractVector{<:Ledger}, windows::AbstractVector{<:Real}) =
    classify(windows, residual.(ledgers), tolerance.(ledgers))
