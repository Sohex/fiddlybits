# The universal constants System's Derived rules read, each declared once
# (REQ-SYS-101 item 1).

using ..Dimensions: Dim
using ..Dispositions: Sourced, Locator

"The dimension of the Newtonian constant of gravitation: length^3 mass^-1 time^-2."
const GRAVITATION = Dim{-1,3,-2,0,0}()

"The dimension of the Stefan-Boltzmann constant: mass time^-3 temperature^-4."
const STEFAN_BOLTZMANN = Dim{1,0,-3,-4,0}()

"""
    gravitational_constant(FT)

The Newtonian constant of gravitation as a `Sourced` value of type `FT`: the CODATA
2018 recommended value, parsed from its decimal digits directly into `FT`.
"""
gravitational_constant(::Type{FT}) where {FT<:AbstractFloat} = Sourced(
    value = parse(FT, "6.67430e-11"), dim = GRAVITATION,
    locator = Locator(identifier = "10.1063/5.0064853",
                      table = "Table XXX, p. 033105-45: Newtonian constant of gravitation"))

"""
    stefan_boltzmann_constant(FT)

The Stefan-Boltzmann constant as a `Sourced` value of type `FT`: the expression
`(pi^2 / 60) k^4 / (hbar^3 c^2)` of CODATA 2018 Table XXX, evaluated at 256 bits from
the exact Boltzmann constant, Planck constant and speed of light of the same table,
then rounded once into `FT`.
"""
function stefan_boltzmann_constant(::Type{FT}) where {FT<:AbstractFloat}
    sigma = setprecision(BigFloat, 256) do
        k = parse(BigFloat, "1.380649e-23")
        h = parse(BigFloat, "6.62607015e-34")
        c = parse(BigFloat, "299792458")
        hbar = h / (2 * BigFloat(pi))
        (BigFloat(pi)^2 / 60) * k^4 / (hbar^3 * c^2)
    end
    return Sourced(
        value = FT(sigma), dim = STEFAN_BOLTZMANN,
        locator = Locator(identifier = "10.1063/5.0064853",
                          table = "Table XXX, p. 033105-45: Stefan-Boltzmann constant " *
                                  "(pi^2/60)k^4/hbar^3c^2, with the exact k, h and c of " *
                                  "the same table"))
end
