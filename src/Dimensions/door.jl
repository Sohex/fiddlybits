# The DynamicQuantities door: docs/imports/dynamicquantities.md.
#
# The package's dimension algebra is read here and nowhere else, and it is read on the
# host only. Nothing below this file passes a Quantity anywhere, so no kernel sees one.

import DynamicQuantities

using ..Verdicts: refuse

"The two base dimensions DynamicQuantities carries that `Dim` does not."
const UNCARRIED_DIMENSIONS = (:current, :luminosity)

"""
    to_dynamic(d)

`d` as a `DynamicQuantities.Dimensions`, with the two base dimensions `Dim` does not
carry left at zero. The result's type does not depend on `d`'s exponents, so this
direction is as inferrable as the signature it is given.
"""
to_dynamic(::Dim{M,L,T,Theta,N}) where {M,L,T,Theta,N} =
    DynamicQuantities.Dimensions(mass = M, length = L, time = T,
                                 temperature = Theta, amount = N)

"""
    from_dynamic(d)

The `Dim` of `d`. Refuses a non-zero current or luminosity exponent, which this
project's five base dimensions cannot express, and refuses any exponent that is not a
whole number, which the integer algebra of `Dim` cannot hold.

The returned type follows `d`'s values, so this direction is a host-side door and no
operator calls it.
"""
function from_dynamic(d::DynamicQuantities.AbstractDimensions)
    for name in UNCARRIED_DIMENSIONS
        e = getproperty(d, name)
        iszero(e) || refuse(
            "dimension signature", "Dimensions.from_dynamic",
            "$(name)^$(e) has no place among $(join(BASE_DIMENSIONS, ", "))")
    end
    values = map(BASE_DIMENSIONS) do name
        e = getproperty(d, name)
        isinteger(e) || refuse(
            "dimension signature", "Dimensions.from_dynamic",
            "the $(name) exponent $(e) is not a whole number")
        Int(e)
    end
    return Dim{values...}()
end
