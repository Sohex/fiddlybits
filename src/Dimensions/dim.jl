# The dimension signature a Field carries on its type:
# docs/plans/fiddlybits-52v.3-fields.md, section "Types and functions".
#
# The exponents are type parameters, so two signatures that differ are two types and a
# mismatched operation is resolved by the method table rather than by comparing two
# values at run time. The numbers a Field holds stay plain floats; no quantity type
# reaches a kernel (docs/imports/dynamicquantities.md).

using ..Verdicts: refuse

"The five SI base dimensions this project uses, in the order `Dim` takes them."
const BASE_DIMENSIONS = (:mass, :length, :time, :temperature, :amount)

"""
    Dim{M,L,T,Theta,N}

A dimension signature: the integer exponents of mass, length, time, temperature and
amount, in that order. A singleton, so a `Field` parameterised on one carries no
storage for it.

The exponents are checked to be `Int` in the inner constructor. A type written with a
float or a rational exponent is a type Julia will form and this constructor refuses,
because the algebra below adds exponents and a signature outside the integers would
compare unequal to the one meant.
"""
struct Dim{M,L,T,Theta,N}
    function Dim{M,L,T,Theta,N}() where {M,L,T,Theta,N}
        exponents = (M, L, T, Theta, N)
        all(e -> e isa Int, exponents) || refuse(
            "dimension signature", "Dimensions.Dim",
            "the exponents of $(join(BASE_DIMENSIONS, ", ")) must be Int, and " *
            "$(exponents) is not")
        return new{M,L,T,Theta,N}()
    end
end

"The dimensionless signature: every exponent zero."
const DIMENSIONLESS = Dim{0,0,0,0,0}()

"The mass signature."
const MASS = Dim{1,0,0,0,0}()

"The length signature."
const LENGTH = Dim{0,1,0,0,0}()

"The time signature."
const TIME = Dim{0,0,1,0,0}()

"The thermodynamic temperature signature."
const TEMPERATURE = Dim{0,0,0,1,0}()

"The amount-of-substance signature."
const AMOUNT = Dim{0,0,0,0,1}()

"""
    exponents(d)

The five exponents of `d` as an `NTuple{5,Int}`, in `BASE_DIMENSIONS` order.
"""
exponents(::Dim{M,L,T,Theta,N}) where {M,L,T,Theta,N} = (M, L, T, Theta, N)

"""
    signature(d)

`d` written as a product of base dimensions with their exponents, `"dimensionless"`
when every exponent is zero. This is the text every refusal below names a signature
with.
"""
function signature(d::Dim)
    parts = String[]
    for (name, e) in zip(BASE_DIMENSIONS, exponents(d))
        e == 0 && continue
        push!(parts, e == 1 ? String(name) : "$(name)^$(e)")
    end
    return isempty(parts) ? "dimensionless" : join(parts, " ")
end

Base.show(io::IO, d::Dim) = print(io, "Dim(", signature(d), ")")

"""
    *(a::Dim, b::Dim)

The signature whose exponents are the sums of `a`'s and `b`'s.
"""
Base.:*(::Dim{M1,L1,T1,Th1,N1}, ::Dim{M2,L2,T2,Th2,N2}) where
        {M1,L1,T1,Th1,N1,M2,L2,T2,Th2,N2} =
    Dim{M1 + M2, L1 + L2, T1 + T2, Th1 + Th2, N1 + N2}()

"""
    /(a::Dim, b::Dim)

The signature whose exponents are `a`'s less `b`'s.
"""
Base.:/(::Dim{M1,L1,T1,Th1,N1}, ::Dim{M2,L2,T2,Th2,N2}) where
        {M1,L1,T1,Th1,N1,M2,L2,T2,Th2,N2} =
    Dim{M1 - M2, L1 - L2, T1 - T2, Th1 - Th2, N1 - N2}()

"""
    inv(d)

The signature with every exponent negated.
"""
Base.inv(::Dim{M,L,T,Theta,N}) where {M,L,T,Theta,N} = Dim{-M, -L, -T, -Theta, -N}()

"""
    ^(d, ::Val{P})

`d` with every exponent multiplied by `P`. The power is taken in the type domain
through `Val` so the result's type is known without the value; `d^2` written with a
literal reaches this through `Base.literal_pow`.
"""
Base.:^(::Dim{M,L,T,Theta,N}, ::Val{P}) where {M,L,T,Theta,N,P} =
    Dim{M * P, L * P, T * P, Theta * P, N * P}()

Base.literal_pow(::typeof(^), d::Dim, ::Val{P}) where {P} = d^Val(P)

"""
    one(d)
    one(::Type{<:Dim})

The dimensionless signature, the identity of the multiplication above.
"""
Base.one(::Dim) = DIMENSIONLESS
Base.one(::Type{<:Dim}) = DIMENSIONLESS

"""
    require_same_dim(a, b, site)

Returns `nothing` when `a` and `b` are the same signature, and raises the `Refusal` of
`Verdicts` at `site` naming both signatures when they are not. Declared here because
the algebra is declared here; `Fields` calls it on every binary operation between two
fields, and the refusal table of `docs/plans/fiddlybits-52v.3-fields.md` names it as
what raises a mismatched `Dim`.
"""
function require_same_dim(a::Dim, b::Dim, site::AbstractString)
    typeof(a) === typeof(b) && return nothing
    refuse("dimension signature", site,
           "$(signature(a)) does not match $(signature(b))")
end

"""
    +(a::Dim, b::Dim)
    -(a::Dim, b::Dim)

The shared signature of `a` and `b`, refused through `require_same_dim` when they
differ. An addition never promotes one signature to another.
"""
function Base.:+(a::Dim, b::Dim)
    require_same_dim(a, b, "Dimensions.+")
    return a
end

function Base.:-(a::Dim, b::Dim)
    require_same_dim(a, b, "Dimensions.-")
    return a
end
