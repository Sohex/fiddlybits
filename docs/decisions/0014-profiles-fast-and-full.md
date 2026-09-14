+++
id = "0014"
title = "Two named profiles, fast and full, as one struct; the same code at different declared settings"
status = "accepted"
date = 2026-09-08
+++

## Decision

A `Profile` is a value that names, for a run: each component's mesh level, chosen to
hit a target spacing in kilometres derived from the planet's radius, with the ratio
of that spacing to the configuration's deformation radius reported in the profile
record (decision 0005); each component's vertical ladder; the radiation scheme's
number of g-points per band and its call interval, the interval declared in seconds
with a `Derived` ceiling (a declared fraction of the shortest of the mean solar day of
the source of largest instellation, any eclipse duration, and the orbital period;
where none of those is defined, the fast tier's cloud timescale), the constructor
refusing an interval above its ceiling as decision 0008 does for timesteps; the
floating-point type of the fast prognostic fields; the slow-tier acceleration factor
and the climate refresh cadence; the finest level each component may reach under
local refinement; the memory ceiling; the daily-tier fallback interval of decision
0023; and the exit brackets of every loop, stored dimensionless as decision 0023
defines them. A run records its profile in its identity, and a result from a profile
is labelled with it wherever it appears.

Two profiles exist at the founding:

- **fast**: coarser levels, fewer g-points and a longer radiation interval,
  single-precision fast fields, aggressive slow-tier acceleration, wider exit
  brackets. It runs the whole coupled system end to end in hours on the founding
  hardware.
- **full**: the operating levels, the certified precision choice, tighter brackets.
  It may take longer, and a result from it is the one a world's numbers rest on.

Both are the same code. There is no code path that exists in one profile and not the
other; a profile is data.

## Alternatives considered

- **A ladder of several profiles** stepping from fast to full, the way the
  predecessor stepped its spectral truncation. Intermediate points are useful for
  commissioning and for convergence-with-profile checks, at the cost of more registry
  entries and more oracle runs to keep honest. Not chosen at the founding; because
  the profile is a struct, adding rungs is a data change.
- **Per-component overrides** (fast everywhere except a full-resolution terrain).
  Flexible, but the combinatorics make results hard to compare and label. Not chosen
  at the founding; expressible later as data.
- **Resolution as a per-run flag** with no named profiles. Lost; a result then
  carries no label a reader can compare across runs, which is the predecessor's
  "one quantity, several meanings" class.

## Consequences

- Every oracle registry entry names the profile it was registered against.
- Convergence with profile (fast against full on the same system) is itself an
  oracle: a declared metric that moves beyond its bracket between the two is a
  finding about the closures, not a reason to tune either.
- The `Closure` dispositions of decision 0007 are what make a metric converge with
  profile; a metric that does not is where a closure is wrong.

## References

- The predecessor's resolution ladder, its measured stability ceilings and its rule
  that one variable moves per step: `/home/cfutro/docs/world/lib/rungs.py`,
  `/home/cfutro/docs/world/notes/audits/resolution-ladder.md`,
  `/home/cfutro/docs/world/notes/audits/resolution-ladder-wall-clock.md`.

## Amendments

- 2026-09-08: the radiation call interval is declared in seconds with a Derived ceiling from the configuration's shortest geometry cycle; the profile record reports spacing as a ratio to the deformation radius; the daily-tier fallback interval and the dimensionless exit brackets of decision 0023 are profile fields, from notes/findings/2026-09-08-implicit-earth-audit.md.
- 2026-09-13: the profile carries `write_ceiling`, the byte ceiling of the store's writer pool, and `store_writers`, its disk-stage task count, beside `memory_ceiling`, each a declared count above zero with a disposition from `Systems.DECLARED`; the scheduler allocates cores and a share of the card and neither of these, so neither is read from an allocation (decision 0038, docs/plans/fiddlybits-52v.6-provenance.md, section "The writer", fiddlybits-52v.6.25).
- 2026-09-13: the archive this record cites now resolves at /home/cfutro/git/vesper; /home/cfutro/docs/world no longer exists on disk, from notes/findings/2026-09-13-predecessor-archive-relocated-to-vesper.md.
