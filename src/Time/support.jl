# TimeSupport: where a number sits on the clock, carried beside what it means along
# the time axis. Fields carries one of these in every Field
# (docs/plans/fiddlybits-52v.3-fields.md); this module declares it because it sits
# below Fields and owns the clock types.
#
# Which shape a semantics takes is read from time_support_kind and nowhere else, and
# it is read in the inner constructor, so no door reaches a TimeSupport whose shape
# its semantics does not declare.

using ..Verdicts: refuse

"What `when` a support of `kind` carries."
placement(::Type{Nothing}) = :none
placement(::Type{<:SimTime}) = :instant
placement(::Type{<:Interval}) = :interval
placement(::Type{P}) where {P} = :neither

"""
    TimeSupport(semantics)
    TimeSupport(semantics, instant)
    TimeSupport(semantics, interval)

What places a number on the clock: the time semantics, and the instant or interval it
is placed at. Which of the three forms is admissible is fixed by
`time_support_kind(semantics)`, and a form that does not match is refused naming the
semantics, the shape it declares and the shape it was given.
"""
struct TimeSupport{S<:TimeSemantics,P}
    semantics::S
    when::P

    function TimeSupport{S,P}(semantics::S, when::P) where {S<:TimeSemantics,P}
        declared = time_support_kind(semantics)
        given = placement(P)
        declared === given || refuse("TimeSupport", "Time.TimeSupport",
            "$(nameof(S)) is placed by a $(declared) and was given a $(given)")
        return new{S,P}(semantics, when)
    end
end

TimeSupport(semantics::TimeSemantics) =
    TimeSupport{typeof(semantics),Nothing}(semantics, nothing)

TimeSupport(semantics::TimeSemantics, when) =
    TimeSupport{typeof(semantics),typeof(when)}(semantics, when)

Base.:(==)(a::TimeSupport, b::TimeSupport) = a.semantics == b.semantics && a.when == b.when

function Base.show(io::IO, ts::TimeSupport)
    print(io, "TimeSupport(", nameof(typeof(ts.semantics)))
    ts.when === nothing || print(io, ", ", ts.when)
    print(io, ")")
end

"""
    semantics(ts)

The `TimeSemantics` of `ts`.
"""
semantics(ts::TimeSupport) = ts.semantics

"""
    instant(ts)

The `SimTime` `ts` is placed at. Refused for any semantics not placed by an instant.
"""
instant(ts::TimeSupport) =
    time_support_kind(ts.semantics) === :instant ? ts.when :
    refuse("instant", "Time.instant",
           "$(nameof(typeof(ts.semantics))) is placed by a " *
           "$(time_support_kind(ts.semantics)) and has no instant")

"""
    interval(ts)

The `Interval` `ts` is placed over. Refused for any semantics not placed by an
interval.
"""
interval(ts::TimeSupport) =
    time_support_kind(ts.semantics) === :interval ? ts.when :
    refuse("interval", "Time.interval",
           "$(nameof(typeof(ts.semantics))) is placed by a " *
           "$(time_support_kind(ts.semantics)) and has no interval")

"""
    duration(ts)

The seconds `ts` spans. Refused for any semantics not placed by an interval, because
a quantity with no interval has no duration rather than a duration of zero.
"""
duration(ts::TimeSupport) = duration(interval(ts))
