+++
id = "REQ-PROC-010"
title = "One quantity has one name, a word names one concept, and prose about the simulation is written in the simulation's terms"
old_path = ["/home/cfutro/docs/world/docs/src/reference/vocabulary.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor's vocabulary existed because words had been doing several jobs. A
landform (a basin notched but not cut through), an uncertainty (a basin the two bounding
climates disagree about) and an estimator disagreement (two evaporation estimators
disagreeing about one climate) were briefly one word, which put a landform and an error
bar under one name in one file; three concepts, three words. "Re-baseline" read as an
iteration and meant one of two other things, and the gap cost a misunderstanding.
"Canonical" named a lineage, not a build with no outstanding trigger today, and a bound
arm was a bound, not a world. Tuned, opaque, implicit-Earth and frozen were four
different defects with four different repairs, ordered by how much is known, and moving
a constant between them was progress even when the number did not change; a number's
class is not a verdict on the number. Conventions added that an invisible component is
reimplemented beside itself, which is how the tree came to hold four copies of a path
resolver and three of a grid convention, so the test for done is that a fresh reader
can find the thing: record what it is and where it lives, never what it says. The prose
register rule: write about the simulation in the simulation's terms, name the simulated
subject explicitly, keep established technical terms whose context disambiguates them
(a euphemism for a standard term is one quantity with two names), state the frame up
front in any standalone document, and never enumerate the phrases the rule exists to
avoid.

## Why it carries

The plan's types are its vocabulary: `Sourced | Derived | Bracketed | Irreducible |
Closure`, `Converged | Bracketed | Refused | NotEvaluable`, memory time versus relaxation
time, run versus profile versus tag, field semantics as a closed enumeration. A word
that means two things in a type system is a bug; in prose it is the same bug found
later. Fresh sessions read the vocabulary before anything else.

## What this system must do

- A tracked vocabulary defines each project term once; a term is used without
  synonyms, and a concept that needs distinguishing gets its own word rather than a
  qualifier on a shared one.
- Type and verdict names in code are the vocabulary's words, and the vocabulary cites
  the type.
- A status word names provenance (what stands behind a value) or lineage, never age or
  preference.
- A defect class (an Earth-fitted value, an unreachable derivation, a frozen copy, a
  tuning) is named by its repair, and a reclassification is recorded as knowledge
  gained, not as a fix.
- A bound, an arm, a test instance and a reference arm are labelled as such wherever
  their numbers appear.
- Every new module, component, oracle and step is registered where a fresh reader will
  find it, and a record says what it is and where it lives, not what it currently says.
- Documents name the simulated subject explicitly, keep standard technical terms, and
  state the frame up front when they can be read standalone.

## Enforced by

`docs/vocabulary.md` (or the practice book's vocabulary section) with a doc lint that
project terms used in `docs/` appear in it; `CLAUDE.md`'s map; the A2 and A5 type names.

## References

- /home/cfutro/docs/world/docs/src/reference/vocabulary.md
- /home/cfutro/docs/world/docs/src/practice/conventions.md ("An undocumented component is not complete"; "Prose registers")
- Plan decisions A2, A3, A5, A6.
