# EarthRatios: docs/plans/fiddlybits-52v.4-system.md, section "The quarantine";
# decision 0007; REQ-SYS-101.
#
# Every member is a unit-conversion denominator, not a physical quantity: a report
# divides a computed value by one of these to state it as a count of Earth units, in
# `Render` only. Each name closes with `_unit` so that member, used anywhere physics
# is computed, reads as what it is: a unit, not a value to compute with. Each is a
# zero-argument function, called on a caller's own call and never as a side effect of
# loading the package: notes/findings/2026-09-13-a-const-sourced-value-leaks-refuse-into-the-package-image.md.

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
        identifier = "10.3847/0004-6256/152/2/41",
        table = "Section 2, the gn = 9.80665 m/s^2 statement"))

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

end # module EarthRatios
