# Insolation.jl

**What it is.** CliMA's solar geometry package: declination, hour angle, zenith
and azimuth angle, planet-star distance, and top-of-atmosphere insolation, both
instantaneous and daily-averaged, with an optional Milankovitch mode that reads
Earth's orbital history from a shipped table.

**What of it is used.** Nothing. This is a survey record; the package is read,
not depended on. It is surveyed because decision 0008 makes the orbit's geometry
a pure function of the declared system and this is the one package in the
organisation that computes that geometry.

## The question, answered

Decision 0008 requires that the true anomaly be obtained by solving Kepler's
equation to rounding for any eccentricity below one, and forbids a series
truncated in eccentricity by name. Insolation.jl uses the truncated series. In
`src/SolarGeometry.jl`, `true_anomaly(MA, e)` is, transliterated to ASCII:

    TA = MA + (2*e - e^3/4)*sin(MA) + (5/4)*e^2*sin(2*MA) + (13/12)*e^3*sin(3*MA)

which is the equation of the center to third order, with error of order `e^4`.
The package's own docstring says so, warns that the error exceeds a few degrees
near half an eccentricity unit, and states that for a highly eccentric orbit the
series "should be replaced by an exact solution of Kepler's equation". It is a
warning in prose and not a refusal in code: there is no guard on `e`, no
bracket, no `NotEvaluable`, and the function returns a wrong answer silently for
an eccentric orbit. Every quantity downstream of the true anomaly (declination,
distance, equation of time, and therefore every insolation) inherits the error.

The orbital elements themselves are inputs, not a table lookup, on the default
path. `orbital_params(param_set)` returns the triple (longitude of perihelion,
obliquity, eccentricity) read from the parameter struct, and `true_anomaly`,
`solar_longitude`, `declination` and `equation_of_time` are all written in terms
of that triple. The Laskar (2004) fit is opt-in: `orbital_params(od, dt)` reads
cubic splines built in `src/Insolation.jl` from `INSOL.LA2004.BTL.csv` in the
`laskar2004` artifact, and is reached only when the caller passes
`milankovitch = true`, in which case `get_orbital_parameters` in
`src/InsolationCalc.jl` errors if the splines were not preloaded. The package's
own docstring records that the splines describe Earth's orbital history only and
that applying them to another body would impose Earth's variations on it. So the
Milankovitch half is Earth data behind an explicit flag, correctly fenced; the
refusal this project must make is of the truncated series in the general path,
not of the paleoclimate table.

The stellar term is a total solar irradiance, not a luminosity and a distance.
`solar_flux` in `src/InsolationCalc.jl` reads `tot_solar_irrad(param_set)`, a
scalar in W m-2 defined at the mean orbital distance, and the distance `d` that
`insolation(theta, d, param_set)` receives is already normalised to the
semi-major axis, so the flux is that scalar divided by `d^2`. This is a
solar-constant-shaped input stated in the Earth idiom, but it is one algebraic
step from general: a declared luminosity and semi-major axis determine it, and
the inverse-square scaling that follows is correct for any orbit. There is no
provision for more than one source, for a reflecting moon, or for an eclipse;
a two-star system would be two independent calls the caller sums, with the
declination of each computed against its own assumed ecliptic.

The clock is the deeper problem. `hour_angle` forms the hour angle as

    time_of_day = mod(datetime2julian(date), 1)
    eta_prime_uncorrected = 2*pi * time_of_day

so the planet turns through a full revolution per Julian day of the `DateTime`
axis, and `param_set.day` (a solar day in seconds, and a declared field of the
struct) does not enter the calculation at all. The same struct's `day` does enter
`julian_years_since_epoch`, where `days_per_year = year_anom / day` converts a
difference of Julian day numbers into anomalistic years. A day is therefore
stated twice with two different meanings in the same package, and the diurnal
cycle is welded to the shorter of the two.

## Assumptions it carries

| assumption | present | how a leak would be caught here |
| --- | --- | --- |
| Earth defaults | not in the struct: `InsolationParameters` is a `@kwdef` with no default for any field, so every element must be supplied. Earth's values arrive only through the `ClimaParams` package extension in `ext/CreateParametersExt.jl`, which maps `orbit_eccentricity_at_epoch`, `orbit_obliquity_at_epoch`, `longitude_perihelion_at_epoch`, `mean_anomaly_at_epoch`, `anomalistic_year_length`, `day`, `epoch_time` and `total_solar_irradiance` out of a TOML dictionary. A clean separation of code from data, and the good half of this package | n/a; not adopted |
| calendar or time | yes, and it is not separable. `Dates` is a hard dependency; `epoch` is typed `DateTime`; every user-facing entry point takes a `date::DateTime`; the hour angle advances `2*pi` per Julian day rather than per the declared rotation period; `days_per_julian_year = 365.25` appears in `julian_years_since_epoch` as the unit the Laskar table is indexed in | n/a; decision 0008's `SimTime` in SI seconds has no `DateTime` and no `Dates` import is permitted in a physics module |
| grid or mesh | none. Every function takes a scalar latitude and longitude in radians and is broadcast by the caller; there is no grid, no space and no `ClimaCore` dependency. A clean negative, and the reason the package is worth reading at all | n/a |
| index base | none; nothing is indexed except the Laskar spline, whose knots are a `t_range` in Julian years | n/a |
| precision | type-generic on `FT`; every literal is wrapped `FT(...)`; the Laskar splines are built in `Float64` and converted, and a `TSIDataSpline` can be constructed per type | n/a |
| threading and GPU | GPU-clean by construction: no allocation in `insolation`, `Adapt` is a dependency so `OrbitalDataSplines` and `TSIDataSpline` adapt to a device array, and `test/test_gpu.jl` exercises it. The Milankovitch path refuses rather than lazily loading on device, which is the right shape | n/a |
| mutable global state | none found; the artifact is loaded by an explicit `OrbitalDataSplines()` constructor the caller holds, not by a module-level cache | n/a |
| fail-open branches | two. The eccentricity series has no guard and no refusal, only a docstring warning (C4). `param_set.day` is silently not used by the hour angle, so a caller who sets it expecting the diurnal cycle to follow gets no error and no effect | n/a |
| clamps and limiters | `mu = max(0, cos(theta))`, zeroing insolation at night, which is physical rather than fitted; `acos` arguments clamped to [-1, 1] in `zenith_angle` and in the daily half-day angle, the latter deliberately giving polar day and polar night branchlessly (B5) | n/a |

## Which half is Earth-fitted and which is general

General in code: the parameter struct with no defaults; declination and solar
longitude as functions of the three orbital elements; the equation of time
likewise, taking obliquity, eccentricity and longitude of perihelion as
arguments rather than a fitted polynomial in the day of year; the distance
normalised to the semi-major axis, so the inverse-square law is dimensionless;
the daily-mean formula with correct polar branches.

Earth-fitted in data: the Laskar (2004) spline table, correctly fenced behind
`milankovitch = true` and documented as Earth-only; the `TSIDataSpline` of
observed total solar irradiance; the parameter values in the ClimaParams TOML.

Welded to one planet in code, which is the finding: the third-order series in
eccentricity, and the hour angle's Julian day.

**Licence.** Apache 2.0. **Version.** Read against `main` at version 1.2.1,
2026-09-09. Nothing is pinned; nothing is adopted.

**Checklist items applied.** A1: two distinct statements of a day (the struct's
`day` in seconds, and the Julian day implicit in `datetime2julian`), and two of a
year (`year_anom` in seconds and `days_per_julian_year = 365.25`); recorded.
A2: the planetary constant block is `InsolationParameters`; every member
classified as runtime with no default, with the Earth values living in the
ClimaParams extension. A3: no bare Earth literal in the used surface; the
numeric literals in `SolarGeometry.jl` are `365.25`, the series coefficients
`1/4`, `5/4`, `13/12`, and multiples of `pi`. A6: no grid or index-base
assumption; clean negative. B4: the `true_anomaly` docstring is accurate about
its own error and about the fix, and the code does not act on it; the mismatch is
between the comment and the absence of a guard, not between the comment and the
value. B5: the two clamps and the night floor listed above. C1: `tot_solar_irrad`
read at its use site in `solar_flux`, where it is divided by the squared
normalised distance; `day` read at its use sites, where it is used for the year
conversion and not for the hour angle. C3: the non-Earth capability is declared
(the elements are arguments) and demonstrated only for near-circular orbits;
`test/test_orbit_param.jl` and `test/test_daily_insolation.jl` test against
Earth's values, so the general capability is declared and not demonstrated.
C4: the two fail-open branches above. C5: the Laskar splines and the epoch
elements are two constant sets for the same three quantities, selected by a
boolean flag; the flag is the authoritative selector and is explicit.

**Verdict: do not adopt.** The two quantities decision 0008 most needs from an
insolation package are the two this one welds to a single planet: the true
anomaly comes from a series truncated at third order in eccentricity that
decision 0008 forbids by name and that this package does not guard, and the hour
angle advances a full turn per Julian day rather than per the declared sidereal
rotation period.

**What is worth carrying anyway,** as an idea and not as code: expressing the
equation of time in the three orbital elements rather than as a fitted
day-of-year polynomial, and normalising the planet-star distance to the
semi-major axis so the flux law is dimensionless. Both are already implied by
decision 0008; this record confirms that the shape is workable.

**If a later decision proposed adopting it,** the assumption to catch is the
clock, and the test that would catch it is the solar-day oracle already implied
by decision 0008 and registered in the `system.*` section: run the geometry on a
synthetic instance whose sidereal rotation period is not one Julian day and
assert the subsolar longitude returns to its start after exactly one declared
solar day. Insolation.jl fails that test as written. A second test, the
eccentricity one, follows decision 0008's Kepler oracle: assert the true anomaly
against a Newton solve of Kepler's equation at an eccentricity well away from
zero. The decision that would have to be taken is a new one amending decision
0008 to permit a truncated series, which is the decision this project has already
refused.
