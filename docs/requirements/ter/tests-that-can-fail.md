+++
id = "REQ-TER-004"
title = "Every conversion carries tests with a right answer, each with a control that proves it discriminates; a check that cannot fail is not a test"
old_path = ["/home/cfutro/docs/world/config/spatial_conversion.yaml"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor's conversion envelope required six tests of every crossing
(constant, identity, reduction, round_trip, operator_order, common_support),
each passing or naming why it did not apply. The audits record what a test
that cannot fail costs. `scripts/check_consistency.py` opened each coupling
matrix, asserted that the variable `cell_lon` was present, and stopped; its
own docstring named the antipodal longitude bug as the reason the check
existed. Presence of a variable has no right answer to be wrong about. The
quantity that did, the fraction of endorheic catchment area landing on cells
the climate model called ocean, read 1.01 per cent index-for-index and 49.77
per cent under the remap in use (measured on the predecessor's
`precarve-craton` build; REQ-TER-010), and was never computed. The controls
that made later tests real are also recorded: the order-of-operations lint on
a weathering intensity required the two arms to agree exactly on identical
time bins and to differ by exactly cosh(dT/tau) otherwise, "without it the
check could pass on two arms that were not two evaluations of one function";
the albedo-mixing arm's one-class control agreed in both orders to 1.8e-15
against a 1e-12 bar; the vector crossing's discriminating check was not a
full-sphere integral, which a rigid rotation makes analytically zero and which
the wrong componentwise remap also passes to roundoff because the frame error
is a pure phase around every row, but an integral over a region that is not
zonally symmetric, where the right and wrong forms separate by four orders. A
resolution claim needed a same-resolution control (REQ-TER-016), and two
mechanism hypotheses about glaciation were killed by a control that switched
the mechanism off, in minutes.

## Why it carries

Design idea 18: tests need a right answer, not a comparison that can only
differ. A builder that accumulates operators, crossings and closures needs each
to ship with the tests that can fail it and with a control showing the test
sees the effect it was written for. Symmetric integrals, presence checks and
comparisons between two products of one root are the recurring shapes of a
check that passes on a wrong answer.

## What this system must do

- Each operator ships: a constant test (an intensive constant is preserved
  exactly), an identity test (same support in and out is bitwise identity), a
  reduction test (extensive sum and coverage), a round-trip test (coarsen then
  refine of a coarse-representable field is exact), an operator-order test (a
  declared nonlinear law on a two-point distribution has a known analytic gap
  and the test reproduces it, with an identical-inputs control that must give
  zero), and a common-support test (two fields are compared only on a declared
  common support).
- Every test has a named control that must fail on a deliberate break; a test
  whose only failure mode is a missing attribute is not counted.
- Full-sphere or zonally symmetric integrals are not accepted as discriminating
  for vector or convention errors; the test region is one where the wrong
  answer does not cancel.
- A consistency check between two products of one root is recorded as such
  and never stands in for an independent oracle.
- A bar is fixed before the value it judges has been seen (decision C2); a bar
  placed after the result is not a criterion.

## Enforced by

- The oracle registry (Part C): `registered_at` names the commit holding the
  bar, and the oracle runner refuses an unregistered entry's value on a model
  result (decision 0025, amendment of 2026-09-13).
- The weekly mutation run (C4): each named break must be caught by at least
  one test.
- Review rule: a pull request adding an operator without the six tests and
  their controls is refused.

## References

- Roache, P. J. (1998). "Verification of Codes and Calculations". AIAA Journal
  36(5), 696-702. DOI: 10.2514/2.457.
- Salari, K., Knupp, P. (2000). "Code Verification by the Method of
  Manufactured Solutions". Sandia National Laboratories report SAND2000-1444.
  DOI: 10.2172/759450.
- Oberkampf, W. L., Roy, C. J. (2010). "Verification and Validation in
  Scientific Computing". Cambridge University Press.
  DOI: 10.1017/CBO9780511760396.
