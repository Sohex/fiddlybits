+++
id = "REQ-NUM-007"
title = "Dead code is measured and removed; a switch that gates nothing does not exist"
old_path = ["/home/cfutro/git/vesper/notes/audits/dead-code-and-unreachable-paths.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the predecessor's vendored GCM after it was declared a hard fork. Three
instruments were kept apart because they carry different weight: unreachable by
construction (in no build, or behind a constant-false guard), unreachable by
configuration (never executed in any configuration the project ran, checked against
the model's own configuration echo rather than against defaults), and unreferenced
(no caller anywhere). Fifteen source files were in no build; three alternative
convection schemes had no build knob and declared incompatible configuration groups
that would abort the current build; a documented build option could not compile;
about half of the postprocessing package was reachable from nothing, with three
modules that could not be imported at all. Of 368 configuration keys, 167 had no
writer and several had no reader: a "negative humidity fixer off" switch was tested
nowhere and the fixer ran unconditionally. Two radiation terms were multiplied by a
zero switch rather than branched around and were computed on every step. A coupler
stub had drifted from its call sites (six arguments declared, eight passed, integers
landing in a real array's position) with no diagnostic. Uncompiled files were hashed
into every binary's provenance, so editing dead code invalidated live binaries. An
entropy diagnostic block was deleted rather than declared off, because enabling it
would have written duplicate output codes over fields the project read. The energy
diagnostics that were on had sites the transform migration missed because a comment
said the block was off by default and the configuration said otherwise.

## Why it carries

"Physics is not a knob" (idea 17) and the scope fence (decision 0002) say a process
is in the model because it exists; a switch that toggles nothing, a term multiplied
by a zero coefficient, and a path no profile reaches are each a trap for the next
reader and a hole in the coverage the mutation run needs, since a mutation in
unreached code is never caught and reads as a false pass. Julia accumulates
unreachable methods easily under multiple dispatch, and every method costs
compile latency, which the risk register names. The measured dependency graph
(recorded is a subset of declared, A3) is the same instrument pointed at parameters.

## What this system must do

1. Reachability is measured per commit: the set of methods executed by the oracle
   suite and by both profiles is recorded, and a method in a physics module reached
   by no oracle and no profile is a defect to be removed or covered, never left.
2. Every field of `System` and `Profile` has at least one reader measured by the
   tracking wrapper (A3); a field with no measured reader fails the registry test.
3. An absent process is a declared absence with its interface complete (founding
   principle 1), never a coefficient of zero; a lint bans multiplying a computed
   term by a boolean or zero-valued switch in kernels.
4. Interfaces are checked at every module boundary: keyword-only constructors, no
   untyped positional pass-through, and JET in CI so an argument mismatch is a
   build failure (A2).
5. The code version in the artifact key is the tree hash of the package that is
   loaded, and the package contains no file that is not loaded.
6. Dead code is removed with the reason in the commit; a scheme kept as a reference
   arm is a named oracle (C4) with a test that executes it.

## Enforced by

A coverage job over the oracle suite and the profiles; the dependency-tracking test
(A3); JET and the interface lint; the mutation run (C4), in which a mutation no
oracle catches is itself reported as uncovered code; decision records A2, A3, C4 and
0002.

## References

- DeMillo, R. A., Lipton, R. J., Sayward, F. G. 1978. Hints on Test Data Selection: Help for the Practicing Programmer. Computer 11(4). DOI: 10.1109/C-M.1978.218136
- Jia, Y., Harman, M. 2011. An Analysis and Survey of the Development of Mutation Testing. IEEE Transactions on Software Engineering 37(5). DOI: 10.1109/TSE.2010.62
- Ivankovic, M., Petrovic, G., Just, R., Fraser, G. 2019. Code coverage at Google. Proceedings of the 2019 27th ACM Joint Meeting on European Software Engineering Conference and Symposium on the Foundations of Software Engineering. DOI: to confirm
