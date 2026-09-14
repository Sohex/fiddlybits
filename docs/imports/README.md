# Import reviews

One record per dependency. A dependency is adopted only where it is exactly the
right fit, and every one is examined for the assumptions it carries, because the
point of building from scratch is to stop importing conventions built for other
concerns. Infrastructure is not exempt: an index base, a calendar type, a default
radius or a threading model leaks as surely as a physics constant.

The review method below is what a record must carry. What the executable gate checks
is narrower: that a record exists, names a leak check, and that the check resolves.
`fiddlybits-af0` closes the gap, by putting the reviewed surface, the version, the
licence and a status per checklist item into TOML front matter the harness can read.

## Record format

- **What it is** and **what of it is used** (the surface area we depend on).
- **Assumptions it carries**, checked against each of: Earth defaults, calendar or
  time representation, grid or mesh, index base, precision, threading and GPU
  model, mutable global state.
- **How each leak is caught**: a named test or lint in this repository.
- **Licence** and **version** (pinned, or `to pin`; `to verify` where uncertain).
- **Checklist items applied**, from the review method below.

## The review method

The predecessor audited some twenty external trees and recorded where the planet
gets welded in (`/home/cfutro/git/vesper/notes/external-tree-checklist.md`). The
items that carry to a Julia infrastructure dependency, on their merits:

| item | check | clean negative |
| --- | --- | --- |
| A1 | Count the distinct statements of a day and a year in the tree | none; or each enumerated and a calendar type identified |
| A2 | Locate any planetary constant block and classify each member | none; or each classified as default, runtime or derived |
| A3 | Grep the Earth literals (`9.81`, `9.80665`, `6.371e6`, `6371`, `7.2921e-5`, `1361`, `101325`) | none; or each accounted for |
| A6 | Grep compile-time grid and topology bounds and index-base assumptions | none in the used surface; or each named with its rebuild trigger |
| B4 | Read the comment beside every constant found and check it against the value | each mismatch recorded |
| B5 | List every clamp, floor and limiter in the used surface | each with where it binds |
| C1 | For every constant found, open one use site and confirm what it does and whether a later stage overrides it | every carried constant has a use site read |
| C3 | Separate declared from demonstrated capability (a documented feature with no test or shipped configuration) | each capability we rely on has a test upstream or one here |
| C4 | Find the fail-open branches: fallbacks with no refusal threshold, silent defaults | each refuses by default or is recorded with what it substitutes |
| C5 | Duplicate live state and second constant sets | the authoritative copy named |
| D2 | Read the boundary field by field: units, index base, array orientation, calendar dimension | every exchanged array checked on both sides |
| D4 | Run the conservation identity that has a right answer in advance | closes at a tolerance registered in advance |

Method notes that carry: characterise a value from its use site, never its
declaration; a comment is evidence about intent and never about the value; a
name can hide a condition; search the whole tree in every language it contains;
count the uses, not the declarations; a unit is a place a constant can hide;
record negatives so a check is not run twice.
