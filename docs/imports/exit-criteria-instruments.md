# The instruments for the coupled loop's exits: ConceptualClimateModels.jl, Attractors.jl, TransitionsInTimeseries.jl

**What they are.** Three trees from the JuliaDynamics organisation, read together
because between them they cover the two halves of decision 0023's hardest requirement:
that every exit be evaluable, and that convergence never be declared on a system that is
merely wandering slowly. `ConceptualClimateModels.jl` builds low-order energy balance
models with a known bifurcation structure. `Attractors.jl` characterises basins and
attractors for a system whose rule is known. `TransitionsInTimeseries.jl` asks whether an
observed series has changed character, which is the situation an exit predicate is
actually in.

**What of any of them is used.** Nothing as a dependency of the model. One method is
carried and reimplemented, named below.

**Licence.** MIT, all three. **Read at.** `ConceptualClimateModels.jl`
`aa249d70065f122d935eeb4b619ed92078fe8c46` (2026-07-15), `Attractors.jl`
`2ac1e8395b48a22557c06a1a80ba8ce940f4cc36` (2026-08-12),
`TransitionsInTimeseries.jl` `35e234b8e13360fb4ea93a789fdd1353ae0ca3a1` (2025-05-21),
all in `/home/cfutro/git/JuliaDynamics/`.

**Verdict.** Algorithmic reference, all three, and one of them changes what this project
builds. The surrogate-based significance test in `TransitionsInTimeseries.jl` answers the
question REQ-NUM-001 currently answers with a formula, and answers it without assuming
the formula's model of the noise. It is reimplemented rather than imported, because the
place it belongs is the reporting and oracle path and the package brings a statistics
stack with it.

## Which of them can be a dependency at all

None of the three, on the dependency graph, and the reason is the one
`docs/imports/fastpower-jl.md` already established.
`ConceptualClimateModels.jl` depends on `OrdinaryDiffEqNonlinearSolve`, which depends on
`OrdinaryDiffEqCore`, which depends on `FastPower`, which the manifest check refuses. It
also depends on `NaNMath`, whose silent NaN-returning arithmetic decision 0029 declines
on its own terms, and on `ProcessBasedModelling` and the symbolic assembly that decision
0012 declined. `Attractors.jl` brings `BlackBoxOptim`, `Clustering`, `Distributions`,
`Optim` and a nearest-neighbour stack. `TransitionsInTimeseries.jl` brings `FFTW`,
`HypothesisTests`, `LsqFit`, `StatsBase` and `TimeseriesSurrogates`.

That is not an argument against reading them. It settles the shape of what carries: a
method, reimplemented, or an analysis run outside the model's own environment against
artifacts the model wrote.

## The drift criterion, and the thing the package does better

Decision 0023 states every exit tolerance dimensionlessly: a fraction of a reservoir's
stock per unit of that reservoir's own relaxation time, or a multiple of the measured A/A
scatter, over a window that REQ-NUM-001 requires be corrected for autocorrelation. The
correction it names is the autocorrelation-corrected standard error: estimate the
integrated autocorrelation time, divide the sample count by it, and widen the error bar.

`TransitionsInTimeseries.jl`'s pipeline is `estimate_changes(config, x, t)` followed by
`significant_transitions(results, significance)`. The first takes an `indicator`, which is
any `f(x) -> Real` over a sliding or segmented window, and a `change_metric`, which is any
function of the indicator series, with a least-squares slope and a difference of means
already provided (`src/change_metrics/slope.jl`, `valuediff.jl`). A reservoir's stock is a
legal indicator and a slope per relaxation time is a legal change metric, so the framework
expresses decision 0023's quantities without adaptation.

The significance half is where the value is. `SurrogatesSignificance`
(`src/significance/surrogates_significance.jl`) generates surrogate series from the
observed one, recomputes the whole indicator and change-metric chain on each, and reports
the fraction of surrogates whose change metric exceeds the original. With a phase-randomised
surrogate, the default `RandomFourier`, the null series has the same power spectrum and
therefore the same autocorrelation structure as the run, and differs only in phase. The
question "is this drift larger than this run's own scatter, given how correlated that
scatter is" is then answered by resampling rather than by an effective-sample-size
formula.

That is strictly better than the formula for this purpose, and it is better in a specific
way worth writing down. The autocorrelation-corrected standard error assumes the series is
stationary with an exponentially decaying autocorrelation, and a coupled climate series
with a seasonal cycle, a stellar cycle and a slow reservoir adjustment satisfies none of
those. A phase-randomised surrogate of the series itself carries whatever spectrum the
series actually has, including the cycles, so the null is the run's own variability rather
than a model of it. The cost is a few hundred recomputations of a scalar statistic over a
series that is already in memory, which is nothing beside a coupled run.

**What this project takes:** the surrogate null, reimplemented. A phase-randomised
surrogate is a real fast Fourier transform, a randomisation of the phases with the
amplitudes kept, and an inverse transform; the project's own counter-based generator
supplies the phases so the test is reproducible under decision 0029 and keyed like every
other stochastic stream. The exit report then carries, beside the declared dimensionless
bracket and its SI value, the fraction of surrogates whose drift over the same window
exceeded the observed drift. The bracket still decides the verdict: a significance level
is not a tolerance, and decision 0023 fixes tolerances before the run.

**What it does not take:** the shipped indicators. Variance, lag-one autocorrelation,
low-frequency spectral power and the Kolmogorov-Smirnov distance
(`src/indicators/`) are early-warning signals of an approaching bifurcation, statistics of
the fluctuations rather than of the mean. They answer "is this system about to tip",
which is a genuinely interesting question about a planet and is not the exit criterion's
question. Keeping them apart matters: an exit criterion that fired on rising variance
would refuse a run for becoming interesting.

## The known-rule half, and why it stays a surrogate

`Attractors.jl` characterises basins of attraction, basin fractions, nonlocal stability
and the continuation of attractors along a parameter, for a system whose rule is given.
The coupled loop's rule is not given in that sense: it is a million lines of physics over
a mesh, and its state space is not something a basin-finding algorithm can be handed.

The use that survives is the one the survey names and it is a good one. A reduced
surrogate of the loop, a low-order energy balance model with the fast and slow tiers
represented by two timescales, has a rule, and its attractors and basins can be computed
exactly. The exit-criteria implementation can then be run on trajectories of that
surrogate whose true status is known in advance: one that has genuinely settled, one
oscillating tightly about an attractor, and one crawling along a slow manifold toward a
distant fixed point. The third is the case decision 0023 names as the failure, and it is
the positive control the exit criteria otherwise lack. This is a test of the criteria, not
of the model, and it can be written before the coupled loop exists.

`ConceptualClimateModels.jl` supplies the surrogate's physics, as reading rather than as
code: its `GlobalMeanEBM` submodule composes Budyko and Sellers energy balance models with
named, swappable closures for longwave emissivity, cloud longwave forcing and meridional
diffusion. The ice-albedo bistability of that family is classical and closed-form enough
to write here in a few dozen lines against this project's own `System` rather than
Earth's, which is also the only way it can be useful: a bifurcation diagram at Earth's
instellation and Earth's albedo law is not an oracle for a generic builder. Its value as a
tier-one oracle is that the reduced model's threshold is a number the full model's
reduced-physics limit should reproduce, and that is a comparison to build when decision
0026's analytic rows are built, not now.

## The three answers, stated plainly

1. **Does the change-point machinery generalise to decision 0023's tolerances?** The
   framework does, because its indicator and change metric are arbitrary functions. Its
   shipped indicators do not, because they are early-warning statistics of fluctuation
   rather than drift of a mean. The piece worth carrying is the surrogate null, and it
   replaces a formula with a resampling.
2. **Can a reduced energy balance model give a first-tier oracle?** Yes, as a known
   bifurcation threshold the model's own reduced-physics limit must reproduce, built at
   this project's declared parameters and not at Earth's, and timed to decision 0026's
   analytic rows rather than to M0.
3. **Can basin-stability machinery pre-test the exit criteria?** Yes, on a surrogate with
   a known rule, and that test is the positive control decision 0023's exit criteria
   currently lack: a trajectory crawling along a slow manifold that the criteria must
   refuse to call converged. It can be written before the coupled loop exists, and it
   should be, because a criterion whose failure mode has never been exhibited is a
   criterion nobody has tested.

## Checklist

Recorded for the read surface; no adoption is proposed.

| item | result |
| --- | --- |
| A1 day and year | `ConceptualClimateModels.jl` works in years and in Earth-normalised insolation throughout its examples; it is read for structure, not for values |
| A2 planetary constant block | the same package's default closures carry Earth solar constant, albedo and emissivity values as defaults |
| A3 Earth literals | present in `ConceptualClimateModels.jl` by design; not examined exhaustively, since nothing is adopted |
| A6 grid and index base | not applicable; all three are zero-dimensional or series-level |
| B4 comment against value | not examined |
| B5 clamps and limiters | `NaNMath` in `ConceptualClimateModels.jl`, which substitutes NaN for a domain error rather than refusing |
| C1 use site of every constant | not examined |
| C3 declared against demonstrated | `TransitionsInTimeseries.jl` documents and tests its pipeline; its applicability to a drift-of-the-mean criterion is declared nowhere and is this record's judgement |
| C4 fail-open branches | `NaNMath`'s silent NaN; a p-value threshold used as if it were a tolerance, which is a failure mode of the caller rather than of the package |
| C5 duplicate state and second constant sets | not examined |
| D2 boundary field by field | the only boundary that would exist is a series of scalars with its own time axis in SI seconds |
| D4 conservation identity | not applicable |

## References

- The survey entry: `docs/surveys/biogeochemistry-and-conceptual.md`, the
  `ConceptualClimateModels.jl`, `Attractors.jl` and `TransitionsInTimeseries.jl` closer
  looks.
- `docs/imports/fastpower-jl.md`, for the manifest check that decides the first section.
- Decision 0023 (the coupled loop and its exit criteria), decision 0025 and decision 0026
  (the oracle tiers and the analytic oracles), decision 0027 (a check that cannot fail is
  not a check), decision 0029 (reproducible stochastic streams).
- `docs/requirements/num/precision-is-a-type-parameter.md` (REQ-NUM-001), whose
  autocorrelation-corrected window is what the surrogate null replaces.
- The rows that consume this: the coupled-loop epic's exit-criteria rows, and
  `fiddlybits-52v.8.3` for the surrogate-trajectory positive control.
