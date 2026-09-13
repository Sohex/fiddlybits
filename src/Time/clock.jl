# The one clock (decision 0008): SimTime is seconds since the run epoch and an
# Interval carries both of its bounds in SI seconds. No quantity here is a day and
# no constant here is both a day and a unit of time.

using ..Verdicts: refuse

"""
    SimTime(seconds)

Seconds since the run epoch. The only time coordinate in the model; a calendar is a
rendering of one of these and never a substitute for it.
"""
struct SimTime{T<:AbstractFloat}
    seconds::T
end

SimTime(seconds::Real) = SimTime(float(seconds))

Base.show(io::IO, t::SimTime) = print(io, "SimTime(", t.seconds, ")")

Base.:(==)(a::SimTime, b::SimTime) = a.seconds == b.seconds
Base.isless(a::SimTime, b::SimTime) = isless(a.seconds, b.seconds)
Base.hash(t::SimTime, h::UInt) = hash(t.seconds, hash(:SimTime, h))

"Seconds from `b` to `a`."
Base.:-(a::SimTime, b::SimTime) = a.seconds - b.seconds

"The instant `seconds` after `t`."
Base.:+(t::SimTime, seconds::Real) = SimTime(t.seconds + seconds)

"The instant `seconds` before `t`."
Base.:-(t::SimTime, seconds::Real) = SimTime(t.seconds - seconds)

"""
    Interval(t0, t1)

The span from `t0` to `t1`, both bounds explicit. Read half-open, `[t0, t1)`: an
instant equal to `t1` belongs to the next interval and never to this one.

A span whose duration is not positive is refused, naming both bounds, because a
component that acts over one has no interval to act over.
"""
struct Interval{T<:AbstractFloat}
    t0::SimTime{T}
    t1::SimTime{T}

    function Interval(t0::SimTime{T}, t1::SimTime{T}) where {T}
        if !(isfinite(t0.seconds) && isfinite(t1.seconds))
            refuse("Interval", "Time.Interval",
                   "a bound is not finite: t0 = $(t0.seconds), t1 = $(t1.seconds)")
        end
        if !(t1.seconds > t0.seconds)
            refuse("Interval", "Time.Interval",
                   "the duration is not positive: t0 = $(t0.seconds), t1 = $(t1.seconds)")
        end
        return new{T}(t0, t1)
    end
end

Interval(t0::Real, t1::Real) = Interval(SimTime(t0), SimTime(t1))

Base.show(io::IO, i::Interval) = print(io, "Interval(", i.t0.seconds, ", ", i.t1.seconds, ")")

Base.:(==)(a::Interval, b::Interval) = a.t0 == b.t0 && a.t1 == b.t1
Base.hash(i::Interval, h::UInt) = hash(i.t1, hash(i.t0, hash(:Interval, h)))

"""
    duration(i)

The seconds `i` spans.
"""
duration(i::Interval) = i.t1 - i.t0

"""
    t in i

Whether `t` lies in `i` read half-open, `i.t0 <= t < i.t1`.
"""
Base.in(t::SimTime, i::Interval) = i.t0 <= t < i.t1

"The largest magnitude of whole seconds `encode` and `decode` carry."
const WHOLE_SECONDS_LIMIT = Int64(2)^62

"""
    encode(t)

`(whole, fraction)`: the whole seconds of `t` as an `Int64` and the remainder in
`[0, 1)` as the float type of `t`. The pair is what a record header carries, so that
the integer part survives a write and a read with no rounding at all.

A `t` that is not finite, or whose whole part falls outside `WHOLE_SECONDS_LIMIT`, is
refused rather than wrapped.
"""
function encode(t::SimTime{T}) where {T}
    isfinite(t.seconds) ||
        refuse("SimTime", "Time.encode", "the instant is not finite: $(t.seconds)")
    whole = floor(t.seconds)
    abs(whole) < WHOLE_SECONDS_LIMIT ||
        refuse("SimTime", "Time.encode",
               "the whole part $(whole) is outside the range Int64 carries here, " *
               "$(WHOLE_SECONDS_LIMIT)")
    return (Int64(whole), T(t.seconds - whole))
end

"""
    decode(whole, fraction)

The instant `whole + fraction` seconds after the run epoch, the inverse of `encode`.
A `fraction` outside `[0, 1)` is refused: it would name an instant a second pair also
names, and the round trip would then not be one.
"""
function decode(whole::Integer, fraction::T) where {T<:AbstractFloat}
    -WHOLE_SECONDS_LIMIT < whole < WHOLE_SECONDS_LIMIT ||
        refuse("SimTime", "Time.decode",
               "the whole part $(whole) is outside the range Int64 carries here, " *
               "$(WHOLE_SECONDS_LIMIT)")
    (isfinite(fraction) && zero(T) <= fraction < one(T)) ||
        refuse("SimTime", "Time.decode",
               "the fraction $(fraction) is outside [0, 1)")
    return SimTime(T(whole) + fraction)
end
