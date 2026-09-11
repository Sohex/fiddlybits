module Verdicts

"""
    LoopVerdict

The closed set a fixed-point loop's exit predicate returns (decision 0009).
`loop_verdicts()` enumerates it.
"""
abstract type LoopVerdict end

struct Converged <: LoopVerdict end
struct Bracketed <: LoopVerdict end
struct Refused <: LoopVerdict end
struct NotEvaluable <: LoopVerdict end
struct BudgetExhausted <: LoopVerdict end

"""
    OracleVerdict

The closed set an oracle returns (decision 0025).
"""
abstract type OracleVerdict end

struct FAIL <: OracleVerdict end
struct REPORT <: OracleVerdict end
struct PASS <: OracleVerdict end

"Every `LoopVerdict` singleton, in the order decision 0009 declares them."
loop_verdicts() = (Converged(), Bracketed(), Refused(), NotEvaluable(), BudgetExhausted())

"Every `OracleVerdict` singleton, in the order decision 0025 declares them."
oracle_verdicts() = (FAIL(), REPORT(), PASS())

"""
    Refusal(quantity, site, reason)

A read that could not be answered. Carries what was read, where it was read and
why it was refused, and never a substitute value.
"""
struct Refusal <: Exception
    quantity::String
    site::String
    reason::String
end

"""
    refuse(quantity, site, reason)

Raise a `Refusal`.
"""
refuse(quantity, site, reason) =
    throw(Refusal(String(quantity), String(site), String(reason)))

function Base.showerror(io::IO, r::Refusal)
    print(io, "refusal: ", r.quantity, " at ", r.site, ": ", r.reason)
end

end # module Verdicts
