# Fiddlybits

A generic exoplanet-building simulation system, written from scratch in Julia. One
process, one mesh hierarchy, GPU-first with a CPU fallback. The subject is any
planetary system a configuration declares: one or more stars, a planet, zero or more
moons, and the initial inventories. Terrain with real ages, hydrology, atmosphere,
ocean, ice, soil, vegetation, biogeochemistry and managed use are one coupled system
rather than a chain of separate models exchanging files.

No code exists yet. This pass produces the founding documents: decision records, the
requirements archive, the references index, the practice book and the oracle registry.
The predecessor project is an archive of findings at `/home/cfutro/docs/world`,
consulted by absolute path and never copied.

## Founding principles

1. Nail every interface out of the gate so extension is painless; a subsystem may be
   a declared absence, its interface may not.
2. Build the cheap route on the general formulation and buy the expensive route when
   an instrument says a configuration needs it.
3. Everything carried from the predecessor is evaluated on its own merits.
4. Every law, scheme and constant is anchored to a read primary source with a locator.

## Where things are

| Read this | For |
| --- | --- |
| `CLAUDE.md` | the map, the rules that bite, the vocabulary |
| `docs/decisions/` | one decision per file: what was chosen, what lost, why |
| `docs/requirements/` | findings carried from the predecessor, on their merits, with what enforces each |
| `docs/requirements/not-carried.md` | every predecessor audit judged not to carry, with the reason |
| `docs/references/` | the tracked index of primary sources, their read/held status, and the fetch requests |
| `docs/references/REQUESTS.md` | the papers to fetch, by verbatim title and identifier, and how to file them |
| `docs/references/requirement-citations.md` | every source a requirement record cites, and whether it is indexed yet |
| `docs/practice.md` | how a session conducts itself, one line each with the argument's location |
| `docs/failure-modes.md` | how projects of this kind go wrong, by class, and what prevents each here |
| `docs/inputs/` | manifests of the datasets the model READS (spectral libraries), kept apart from the oracle datasets |
| `docs/oracles/` | the three oracle tiers, verdict semantics, and the registry of thresholds |
| `docs/imports/` | one review per dependency: what it carries and how a leak is caught |
| `notes/findings/` | dated measurements with their evidence |
| `bd` | what to do; every issue cites a finding, decision or requirement |
