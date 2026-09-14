# EarthRatios: docs/plans/fiddlybits-52v.4-system.md, section "The quarantine";
# decision 0007; REQ-SYS-101.
#
# Every member is a unit-conversion denominator, not a physical quantity: a report
# divides a computed value by one of these to state it as a count of Earth units, in
# `Render` only. Each name closes with `_unit`. Each is a zero-argument function, not
# a `const`: notes/findings/2026-09-13-a-const-sourced-value-leaks-refuse-into-the-package-image.md.

module EarthRatios

using ..Dispositions: Sourced, Locator
using ..Dimensions: LENGTH, MASS, TIME

"""
    gravity_unit()

One Earth gravity: the standard acceleration of gravity gn, adopted by the 3rd
General Conference on Weights and Measures (1901).
"""
gravity_unit() = Sourced(
    value = 9.80665,
    dim = LENGTH / TIME / TIME,
    locator = Locator(
        identifier = "10.59161/CGPM1901DECL2E",
        table = "Declaration 2, p.70: 980.665 cm/sec^2"))

"""
    radius_unit()

One Earth radius: Earth's volumetric mean radius, matching the mean-radius
convention decision 0005 uses for the mesh radius of every configuration.
"""
radius_unit() = Sourced(
    value = 6_371_008.4,
    dim = LENGTH,
    locator = Locator(
        identifier = "10.1007/s10569-017-9805-5",
        table = "Table 4, Earth mean radius row"))

"""
    solar_constant_unit()

One Earth solar constant: the IAU 2015 Resolution B3 nominal total solar
irradiance at one astronomical unit.
"""
solar_constant_unit() = Sourced(
    value = 1361.0,
    dim = MASS / TIME / TIME / TIME,
    locator = Locator(
        identifier = "10.3847/0004-6256/152/2/41",
        table = "Table 1, nominal total solar irradiance"))

"""
    pressure_unit()

One Earth atmosphere: the CODATA standard atmosphere, an exact defined pressure.
"""
pressure_unit() = Sourced(
    value = 101325.0,
    dim = MASS / LENGTH / TIME / TIME,
    locator = Locator(
        identifier = "10.1063/5.0064853",
        table = "Table XXXI, standard atmosphere"))

"""
    rotation_rate_unit()

One Earth rotation rate: the GRS80 defining angular velocity of the Earth's
rotation, adopted at the XVII General Assembly of the IUGG (1979).
"""
rotation_rate_unit() = Sourced(
    value = 7.292115e-5,
    dim = inv(TIME),
    locator = Locator(
        identifier = "10.1007/s001900050278",
        table = "p.131, Defining Constants (exact): angular velocity of the Earth"))

end # module EarthRatios
