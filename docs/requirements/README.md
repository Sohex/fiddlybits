# Requirements archive

One record per finding carried from the predecessor project at
`/home/cfutro/docs/world` (archived at commit `6aa93489d233d4e9d531d6479d338c643e34bc5e`,
2026-09-07). No code is copied. A record cites the old document by absolute path and
states what this system must do and what will enforce it.

**The rule: a finding is carried only on its own merits for a generic exoplanet
builder.** Old-stack tooling defects, configuration-specific numbers, and
Earth-normative couplings are not requirements. The *lesson* behind a coupling may
be. Every old audit has exactly one disposition: a record here, or a line in
`not-carried.md` with the reason.

The old world appears in these records only as the place a finding was measured.
No record frames this project around any planetary or stellar configuration.

## Record format

Headers are TOML front matter between `+++` lines (decision 0036). `old_path` is
always a list, even with one entry.

```
+++
id = "REQ-<AREA>-<NNN>"
title = "<one line>"
old_path = ["/home/cfutro/docs/world/<...>"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"   # carried | superseded | not_applicable
+++

## What is true
<one or two paragraphs; numbers allowed, each with "measured on <what>">

## Why it carries
<the merit argument for a generic builder; the generalised lesson, not the specific>

## What this system must do
<the requirement, stated positively>

## Enforced by
<planned test, type, lint, oracle or decision record; name it>

## References
<primary sources the requirement rests on, by verbatim title and DOI or locator>
```

Areas: `atm` (atmosphere, radiation, clouds, aerosol), `ocn` (ocean, sea ice),
`ter` (terrain, mesh, spatial reductions, crossings), `hyd` (hydrology, lakes,
groundwater, carve), `ped` (pedology, weathering, minerals), `bio` (vegetation,
biogeochemistry, fire, managed biosphere), `cry` (cryosphere), `num` (numerics,
precision, reproducibility), `prov` (provenance, identity, artifacts, build),
`proc` (process, records, verification method), `sys` (system parameters, time,
constants and their dispositions).
