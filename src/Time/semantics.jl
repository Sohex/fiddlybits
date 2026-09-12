# The closed TimeSemantics vocabulary (decisions 0006 and 0008). The types are
# declared here and time_reduce over them is declared in Fields, which is the split
# docs/plans/fiddlybits-52v.1-skeleton.md made to break the cycle between the two.

"""
    TimeSemantics

What a number means along the time axis. The closed set decision 0006 declares;
`time_semantics()` enumerates it and the test suites close it against that
enumeration.
"""
abstract type TimeSemantics end

"A quantity with no time axis at all."
struct Static <: TimeSemantics end

"A sample at one instant."
struct Instantaneous <: TimeSemantics end

"The mean over an interval."
struct IntervalMean <: TimeSemantics end

"The total accumulated over an interval."
struct IntervalAccumulation <: TimeSemantics end

"The state at the end of an interval."
struct EndpointState <: TimeSemantics end

"Every `TimeSemantics` singleton, in the order decision 0006 declares them."
time_semantics() =
    (Static(), Instantaneous(), IntervalMean(), IntervalAccumulation(), EndpointState())

"""
    time_support_kind(s)

What `s` needs to be placed on the clock: `:none`, `:instant` or `:interval`. The
`TimeSupport` constructors dispatch on this, so a semantics added without an entry
here has no support to carry and fails the enumeration test rather than defaulting.
"""
time_support_kind(::Static) = :none
time_support_kind(::Instantaneous) = :instant
time_support_kind(::IntervalMean) = :interval
time_support_kind(::IntervalAccumulation) = :interval
time_support_kind(::EndpointState) = :interval
