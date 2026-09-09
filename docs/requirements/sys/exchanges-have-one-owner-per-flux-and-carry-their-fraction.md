+++
id = "REQ-SYS-009"
title = "An exchange between components has one owner per flux, recomputes state-dependent terms against live state, and carries its coverage fraction and ledger"
old_path = ["/home/cfutro/docs/world/notes/external-model-survey.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor's survey of some twenty external trees (sections 1, 2, 5, 55 and 59 are
the cross-cutting ones) established, first, the gap this project exists in: every
intermediate-complexity Earth system model runs one planet down to its constants, and
every model that runs other planets is an atmosphere with almost nothing under it; no
existing tree carried a non-Earth planet, a terrain loop, a land surface, drainage and a
biosphere together (section 1). Its cost comparison (section 2) was kept with its own
error stated: CPU-hours per simulated century compared a bare atmosphere against coupled
suites, and the unit itself is undefined for a system whose components advance on
different clocks; the honest units are per unit of the slowest tier's work.

Three of its findings are contracts a coupled system needs:

- **Replayed forcing recomputes state-dependent terms live** (section 59f, from the
  published PLASIM-GENIE coupling). Replaying a stored atmospheric cycle to an ocean is
  stable provided the terms that depend on ocean temperature (saturation humidity and
  hence latent heat, net longwave, sensible heat) are recomputed against the live
  ocean, while only the transfer coefficients and the downward radiative and moisture
  fields are replayed; a naive replay of net heat flux severs the negative feedback
  that holds sea surface temperature. Evaporation is deliberately handed over rather
  than recomputed so the moisture budget has one owner.
- **The ocean's cost must not climb the atmosphere's resolution ladder** (59a to 59c):
  an architecture whose ocean cost is a function of the atmosphere grid is priced out at
  the top of a ladder whatever it is worth at the bottom, and a matched-grid coupling
  that must be geared hard enough to be affordable degrades the property it was paying
  for.
- **Normalisation is a property of the field, not the operation** (55d, from ESMF's
  conservative regridding): an extensive total spreads the source integral over the
  whole destination cell (DSTAREA) and a density or rate averages over the covered part
  only (FRACAREA); either way the coverage fraction must travel with the result,
  because a fraction discarded is a conservation identity that can no longer be
  evaluated. Artificial pole cells are forbidden outright because invented area breaks
  conservation. Second-order remapping silently degrades to first order where a source
  cell has too few unmasked neighbours, which is what a coastline looks like (55e).

## Why it carries

The plan couples in one process with declared ownership (A5), one mesh with exact
nesting (A1) and `Field` semantics that dispatch the reduction on the field's kind
(A2), so the grid crossing the survey studied is unrepresentable. What survives is the
contract at every component seam: one owner per flux, the rule for which terms of a
replayed or accelerated forcing are recomputed against live state (the plan's ocean
spin-up alternates coupled and accelerated segments, B3; the slow tier reads
accumulated statistics, B9), the requirement that a component's cost be a property of
its own profile level and not of another component's, and the fraction and ledger
carried with every reduction.

## What this system must do

- Every `Exchange` names exactly one owner per flux and closes a ledger at the
  boundary; a flux handed over is never recomputed by the receiver.
- Any accelerated or replayed forcing (ocean-only segments, slow-tier statistics, a
  warm climate refresh) declares which terms are replayed and which are recomputed
  against the live receiving state, and the terms that depend on the receiver's
  prognostic state are always recomputed.
- Each component's mesh level and cadence are `Profile` settings of its own; no
  component's cost is a function of another component's level except through a
  declared exchange operator.
- Every reduction returns `(field, ledger)` and carries the coverage fraction; the
  normalisation is chosen by the field's semantics (extensive versus intensive), never
  by the call site; the state store refuses an open ledger.
- A reduction that would degrade its order or invent area (a partial-coverage cell, an
  artificial cap) refuses or reports by cell; it never degrades silently.
- Costs are reported per tier unit at a named profile, and a comparison between
  systems states what each figure covers.

## Enforced by

Decision A2 (`Field` dispatch, refusal table, ledgers); A5 (`Exchange`, single writer);
A10 profiles; C3 mesh oracles (area sums, constant-field and extensive-integral
preservation); C6 benchmarks with A/A scatter.

## References

- /home/cfutro/docs/world/notes/external-model-survey.md, sections 1, 2, 5, 55, 59
- Holden et al. (2016). *PLASIM-GENIE v1.0: a new intermediate complexity AOGCM.* DOI 10.5194/gmd-9-3347-2016 (the flux hand-over rule, section 59f)
- ESMF Regrid source documentation blocks, `references/esmf/` in the old tree (the conservation identity and the DSTAREA/FRACAREA normalisations, section 55); pinned identifier: to confirm
- Plan decisions A1, A2, A5, A10, B3, B9.
