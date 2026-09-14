+++
id = "REQ-PROC-008"
title = "An import review runs the external-tree checklist, records clean negatives, checks a claimed limitation against the candidate, and costs the fork before deciding on the physics"
old_path = ["/home/cfutro/git/vesper/notes/external-tree-checklist.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor derived, from reading some twenty independently authored trees, a
checklist of where the home planet is welded into an external Earth-system tree. An
item observed in four or more independently authored trees is a class; one observed
once is an anecdote, quarantined until a second instance promotes it. Every item has a
clean negative, what completing it looks like, because an item without one cannot be
closed, only abandoned. The order is not uniform over the tree: physics cores and unit
conversions carry compile-time constants where biogeochemical parameters are exposed,
so an audit that samples evenly spends its effort where the model is already
configurable. The tiers:

- **A, grep before opening anything**: count the distinct statements of the year and
  the day in every language the tree contains; locate the planetary constant block and
  classify each member as compile-time, runtime or derived; grep the Earth numeric
  literals directly (9.81, 6371, 7.2921e-5, 1361, 101325 and their kin), because
  constants escape a named block by being retyped; grep irradiance-to-photon and
  band-split scalars with their integration window and weighting spectrum; grep
  latitude constants and region ids in branch position; grep compile-time grid and
  topology bounds; grep the tuning and validation surface (cost functions, bias
  corrections, observational targets, fitted tables).
- **B, one file open per item**: the non-dimensionalisation or unit-conversion module,
  where the planet is welded even in otherwise exposed trees; every coefficient whose
  units carry a length, pressure or head in the denominator, recomputed into SI
  material form, because a unit absorbs a planetary constant (head in metres absorbs
  rho g); every per-day and per-year rate classified as physical (the day is 86400 s
  and must not be rescaled), biological and entrained (calibrated under a 24-hour
  light cycle; whether it moves is a modelling decision), or not temporal at all; the
  comment beside every constant checked against the value, because the comment is the
  only place provenance appears and the place it is wrong; every clamp, floor, cap and
  limiter, with where it binds at this configuration's parameters.
- **C, read a use site**: confirm what each constant does and whether a later stage
  overrides it or the default switch makes it unreachable; open every name that carries
  a condition; separate declared from demonstrated capability; find the fail-open
  branches; find duplicate live state and second constant sets.
- **D, once a live candidate**: the geography preprocessing that alters mask,
  bathymetry or elevation (depression filling, minimum-depth flooring, boundary
  treatment) and whether it can be declined; the coupling boundary field by field
  including the calendar dimension of exchange arrays; every accelerator's validity
  statement and drift scalar; the conservation identity with its tolerance registered
  in advance; whether an offline driver exists; whether spectral band arrays hold
  distinct per-band values.

Method notes that each cost a wrong claim: characterise a value from its use site,
never its declaration (Tier A and B produce leads; only C produces findings); a comment
is evidence about intent and never about the value; a name can hide a condition; search
the whole tree in every language (a year length was a bash literal overriding the
config it was appended to); count the uses, not the declarations; a unit is a place a
constant can hide; where several independent trees make the same choice, the departure
is what needs the argument; disagreement between published schemes shipped in one tree
is a free bracket; record negatives so a check is not run twice; purpose does not
exempt a tree (an exoplanet-capable code let a derived radiative constant through as a
compile-time product of Earth gravity, specific heat and day length). Two orderings
follow: correctness-preserving work against a regression suite comes before any change
to planetary parameters, because the suite's references are computed at Earth's; and a
rule that reads only what an open task names cannot find a blind spot.

The orchestration survey supplies a discipline for verdicts: seven claims of the form
"this candidate does not do this" were made about one framework and all seven were
false, so the decision procedure for anything that looks like a gap is to check it
against the candidate's own mechanisms before recording it; the rejections that stood
named a mismatch in kind (the unit of value is a scheduler submission; the calendar
cannot express the orbit; the diagnostics compare against Earth observations). The
design-intent chapter supplies the frame: an external model becomes a maintained fork,
and that is the expected end state rather than a cost to weigh against adopting one;
the question is whether its physics is worth the fork its runtime and Earth content will
require, so cost the fork, then decide on the physics. The survey's section 5 is the
one thing worth borrowing from a CMIP-class Julia stack: an externally maintained
enumeration of planetary and orbital parameters as named defaults, and a radiation
package that treats the stellar source as data while its k-tables are Earth-trained.

## Why it carries

Decision A8 requires an import-review record for every dependency, including
infrastructure, stating the assumptions it carries, what of it is used, and the test
that would catch the assumption leaking; the risk register's tripwire is a dependency
without a record. The checklist is the method for producing that record, and its items
are the classes an import can carry. Its old-stack instances do not carry; the classes,
the clean negatives and the reading discipline do.

## What this system must do

- Every dependency, borrowed idea and comparison tree has a record under
  `docs/imports/` with: pinned identifier (commit, tarball hash, version) and licence;
  what of it is used or borrowed, with the primary source for a borrowed scheme; the
  Tier A to C items each closed with its clean negative or its finding, and Tier D once
  the tree is a live candidate; the calendar, grid, precision and threading assumptions
  found; every switch, calibration factor and Earth reference pattern with its shipped
  state (REQ-SYS-004); the leak test that would catch each assumption in this system.
- A claimed limitation of a candidate is checked against the candidate's own
  mechanisms before it is recorded; a rejection names the mismatch in kind.
- A regression suite is run and passing before any planetary parameter is changed in
  an imported component.
- The fork cost is stated before the physics verdict, and adoption of a component is
  recorded as a maintained fork with the subtree layout that makes maintaining it
  ordinary work.
- A single-tree observation is recorded as an anecdote and promoted to a checklist
  item at its second independent instance; a departure from a convergence of
  independent trees carries an argument.
- A per-band structure imported from any tree is checked to hold distinct per-band
  values under the declared spectrum; a limiter is checked for where it binds at the
  declared gravity.

## Enforced by

Decision A8; `docs/imports/` record format; a lint that every entry in the package
manifest has a record; the risk register's "imported assumptions" tripwire; the
references index rule that a borrowed scheme names its primary source as `read`.

## References

- /home/cfutro/git/vesper/notes/external-tree-checklist.md
- /home/cfutro/git/vesper/notes/external-model-survey.md, sections 5, 55e, and the sections each checklist row cites
- /home/cfutro/git/vesper/notes/orchestration-frameworks.md, "Before recording another limitation, check it"
- /home/cfutro/git/vesper/docs/src/reference/design-intent.md ("cost the fork, then decide on the physics")
- Plan decisions A8; Part G references discipline.
