# Forcing as a list of intervals with one value per interval (decision 0008),
# contiguous and non-overlapping, checked at construction. There is no cadence
# enumeration: a forcing at one rotation's spacing, one at thirty hours and one at
# the timestep are this same list, built the same way and read the same way.

using ..Verdicts: refuse

"""
    Forcing(intervals, values)

One value per interval, the intervals contiguous and non-overlapping and in
increasing time. A gap and an overlap are each refused at construction, naming the
pair of intervals that carries it.

Contiguity is exact: the end of one interval and the start of the next are the same
number, not two numbers within a tolerance. `uniform_forcing` builds a list that way,
and any builder that computes each boundary once does the same.

A `Forcing` holds its own copy of the interval list and its own copy of the value
list, so mutating either vector passed in afterwards leaves it describing what was
checked. The values themselves are not copied: a value holding an array shares that
array with the caller.
"""
struct Forcing{T<:AbstractFloat,V}
    intervals::Vector{Interval{T}}
    values::Vector{V}

    function Forcing(intervals::Vector{Interval{T}}, values::Vector{V}) where {T,V}
        intervals = copy(intervals)
        values = copy(values)
        length(intervals) == length(values) ||
            refuse("Forcing", "Time.Forcing",
                   "$(length(intervals)) intervals carry $(length(values)) values")
        isempty(intervals) &&
            refuse("Forcing", "Time.Forcing", "the list is empty")
        for k in 2:length(intervals)
            previous, current = intervals[k - 1], intervals[k]
            if current.t0.seconds > previous.t1.seconds
                refuse("Forcing", "Time.Forcing",
                       "a gap between interval $(k - 1) ending at $(previous.t1.seconds) " *
                       "and interval $(k) starting at $(current.t0.seconds)")
            elseif current.t0.seconds < previous.t1.seconds
                refuse("Forcing", "Time.Forcing",
                       "an overlap between interval $(k - 1) ending at $(previous.t1.seconds) " *
                       "and interval $(k) starting at $(current.t0.seconds)")
            end
        end
        return new{T,V}(intervals, values)
    end
end

Base.length(f::Forcing) = length(f.intervals)
Base.eachindex(f::Forcing) = eachindex(f.intervals)
Base.getindex(f::Forcing, k::Integer) = (f.intervals[k], f.values[k])

function Base.show(io::IO, f::Forcing)
    s = span(f)
    print(io, "Forcing(", length(f), " intervals over ",
          s.t0.seconds, " to ", s.t1.seconds, ")")
end

"""
    span(f)

The interval from the start of the first interval to the end of the last.
"""
span(f::Forcing) = Interval(first(f.intervals).t0, last(f.intervals).t1)

"""
    index_at(f, t)

The position of the interval holding `t`, read half-open, so an instant on a shared
boundary belongs to the later interval. A `t` outside `span(f)` is refused naming the
span, because a forcing does not extend itself past what it declares.
"""
function index_at(f::Forcing, t::SimTime)
    s = span(f)
    t in s || refuse("forcing value", "Time.index_at",
                     "the instant $(t.seconds) is outside the declared span " *
                     "$(s.t0.seconds) to $(s.t1.seconds)")
    lo, hi = 1, length(f.intervals)
    while lo < hi
        mid = (lo + hi + 1) >> 1
        if f.intervals[mid].t0 <= t
            lo = mid
        else
            hi = mid - 1
        end
    end
    return lo
end

"""
    index_at_reference(f, t)

`index_at` by a serial scan over every interval, the reference path of decision 0027.
"""
function index_at_reference(f::Forcing, t::SimTime)
    s = span(f)
    t in s || refuse("forcing value", "Time.index_at_reference",
                     "the instant $(t.seconds) is outside the declared span " *
                     "$(s.t0.seconds) to $(s.t1.seconds)")
    for k in eachindex(f.intervals)
        t in f.intervals[k] && return k
    end
    refuse("forcing value", "Time.index_at_reference",
           "no interval holds the instant $(t.seconds)")
end

"""
    at(f, t)

The value whose interval holds `t`.
"""
at(f::Forcing, t::SimTime) = f.values[index_at(f, t)]

"""
    uniform_forcing(t0, step, values)

A `Forcing` over `length(values)` intervals of `step` seconds each, the first
starting at `t0`. Every boundary is computed once, from the index rather than from
the boundary before it, so adjacent bounds are identical and the list is contiguous
by construction. The offset is `fma`, which decision 0044 requires of a multiply
feeding an add in source that bitwise mode compiles.

The spacing is an argument and not a named cadence: a list at one rotation's spacing
and a list at thirty hours' differ only in `step`.
"""
function uniform_forcing(t0::SimTime{T}, step::Real, values::AbstractVector) where {T}
    step > 0 || refuse("Forcing", "Time.uniform_forcing",
                       "the spacing $(step) is not positive")
    isempty(values) && refuse("Forcing", "Time.uniform_forcing", "the list is empty")
    bounds = [SimTime(fma(T(step), T(k), t0.seconds)) for k in 0:length(values)]
    intervals = [Interval(bounds[k], bounds[k + 1]) for k in 1:length(values)]
    return Forcing(intervals, collect(values))
end
