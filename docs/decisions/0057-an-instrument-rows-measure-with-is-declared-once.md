+++
id = "0057"
title = "An instrument registry rows measure with is declared once in an instrument table and named by id; its parameters name the constants they state and are checked against them, and no row restates its definition"
status = "accepted"
date = 2026-09-13
amends = [{ record = "0052", what = "where the registry states the ensemble's seed, member count, miss rate and its condition: once, in the ulp_ensemble instrument the two repro rows name, with the numbers as parameters checked against the constants of src/Backends/certify.jl, and not in the threshold of each row" }, { record = "0053", what = "the tables a registry row names by id: an instrument table beside the protocol table, an instrument field on a row, and the oracles.registry_wellformed clauses that go with them" }, { record = "0054", what = "which instruments depends_on carries: an instrument a registry row judges stays a dependency on that row, and an instrument no row judges is declared in the instrument table and named in instrument, never an edge between the rows that measure with it" }]
+++

## Decision

**An instrument is declared once, in an instrument table, and named by id.**
`registry.toml` carries `[[instrument]]` entries beside its `[[protocol]]` entries. An
instrument is what a row's statistic or bar is measured with when no row judges the
instrument itself: how it is built, what its numbers mean, and what a measurement by it
is and is not admissible as. Each entry has an `id`, a `definition` in prose, and
optionally `parameters`. A row measured with one names it in `instrument`, a single id.
Every instrument a row names is declared, every declared instrument is named by at least
one row, and an id is used once.

**A row states its bar and not its instrument.** No statistic or threshold carries a
clause of an instrument's definition, on the clause rule of decision 0054: text between
semicolons and sentence ends, lowercased, whitespace collapsed, a leading `provisional`
removed. The rule holds for every row, not only the rows naming the instrument, because
the defect is the definition written twice wherever the second copy lands. A definition
names no verdict in capitals, which is decision 0053's prose rule applied to the text a
bar is read through, and names no row id: the rows name the instrument, and the edge is
stored once on the side that acts (decision 0040's rule for records, applied here).

**A parameter names the constant it states, and is checked against it.** `parameters` is
an inline table whose keys are constants qualified from the package module, such as
`Backends.ENSEMBLE_MEMBERS`, and whose values are numbers. The constant in the code is
the one definition, with its disposition in its own docstring; the parameter is the door
through which the registry shows it. `oracles.registry_wellformed` resolves each key in
`Fiddlybits` and refuses a name that is no constant and a value that differs. The
definition refers to the numbers by those names and does not write them.

**An instrument is not a dependency.** `depends_on` names a row whose verdict another rests
on (decision 0054), and a report of the depending row carries that verdict beside its own.
The ulp ensemble is judged by no registry row: `repro.backend_ulp_envelope` asks whether
the CPU and GPU agree and `repro.fp32_kernel_certification` whether FP32 agrees with FP64,
and each uses the ensemble's envelope as its bar. An instrument a registry row does judge,
such as the enumerated inference walk `build.inference_suite_cost` times, stays a
dependency on that row.

**The check.** `oracles.registry_wellformed`, in `test/oracles/wellformed.jl`, adds to the
clauses of decisions 0053 and 0054: an instrument has an id used once and a non-empty
definition; its definition names no verdict in capitals and no row id; its `parameters`,
where present, is a table of qualified constant names each stating a number; a row's
`instrument` is an id and is declared; every declared instrument is named; no statistic
or threshold carries a clause of an instrument's definition; and every parameter equals
the constant it names. Its positive control is a fixture in which the definition is
written into the threshold of a second row naming the instrument, which must be refused;
every other clause has a fixture of its own, the parameter clause is held against a
fixture module with one value that differs and one name that resolves to nothing, and
the clean fixture declares an instrument two rows name and must be accepted by both.

## Alternatives considered

- *One row owns the definition and the other names it*, through `depends_on` or a field of
  its own. Lost. Through `depends_on` it is the edge decision 0054 withholds: the naming
  row would report the owner's verdict beside its own, and the CPU and GPU comparison does
  not rest on whether FP32 agrees with FP64. Through a new field it is still arbitrary
  which row owns it, the owner's threshold carries prose that is not its bar, and removing
  or renaming the owner strands the other row's instrument.
- *Keep both copies and check them equal.* Lost: two definitions held equal by a check are
  still two, the check says nothing about where the next row's copy goes, and an edit
  must be made in every copy before the check stops failing.
- *The definition in a finding or in decision 0052, cited by path from each row.* Lost. A
  finding is a dated measurement and is not rewritten when the instrument changes; a
  decision argues for a choice and does not declare the numbers a bar is run with; and a
  path in prose is resolved by nobody, which is the argument decision 0054 made against a
  row id in prose.
- *The numbers in the code alone, the registry naming the constants without values.* Lost
  on the registration rule of decision 0025: a threshold is fixed and recorded before the
  results it judges, so what the bar is run with has to be visible in the registry and to
  move only with a registry edit. With the value in both places and an equality check, a
  change to the constant fails the suite until the registry states it.
- *The code reads its constants from the registry.* Lost: `Backends` sits near the bottom
  of the include order and the registry is the record of what is judged, so a registry
  edit would change what a kernel does, and the constants are Derived and Irreducible
  values whose dispositions belong beside the code that uses them.
- *Instruments as entries of the protocol table.* Lost: a protocol is the system a bar
  applies to, with a system and a normalisation the check requires, and an instrument is
  how the bar is measured; a row can name one of each, and one table would need two
  shapes.
- *`instrument` as a list.* Lost for now: a row is one bar (decision 0053), and each row
  naming an instrument measures its bar with one, so a list would add a shape no row
  uses. The record that meets a bar measured two ways widens the field.
- *Decide restatement by the parameter values*, refusing a row that writes an instrument's
  numbers. Lost: a number shared by chance, such as a seed of zero, would refuse unrelated
  rows, and the defect this record answers is the definition's prose, which the clause
  rule decides. A paraphrase of a definition that shares no clause with it stays review's,
  as decision 0054 leaves a paraphrase of a dependency's bar.

## Consequences

- `docs/oracles/registry.toml` declares the `ulp_ensemble` instrument: the seeded draw and
  the probability over its seed, the admissibility rule for a case declaring an
  `Obligation`, and the injection amplitude and step, with `Backends.ENSEMBLE_MEMBERS`,
  `Backends.ENSEMBLE_SEED`, `Backends.ENSEMBLE_MISS_RATE` and
  `Backends.ENSEMBLE_CONFIDENCE_RECIPROCAL` as parameters. `repro.backend_ulp_envelope` and
  `repro.fp32_kernel_certification` name it, and their thresholds keep their own bars.
  The reciprocal of the miss rate the rows wrote beside it is not carried: it is derived
  from the parameter.
- The oracles suite loads `Fiddlybits` to resolve parameters; the registry shape clauses
  still read TOML alone, so the fixtures need no package.
- `test/certify/member_count.jl` asserts the member count, the confidence and the miss-rate
  reciprocal as literal known quantities. Those are the code's tests of its own
  derivation, and a change to a constant fails them and this record's check together.
- `docs/oracles/README.md` states the table, the field and its rules;
  `docs/plans/fiddlybits-52v.7-kernels.md` says the rows name the instrument and the
  instrument carries the admissibility rule.
- The docstring of `Backends.detectable_miss_rate` says the registry rows state the miss
  rate; `fiddlybits-52v.7.58` carries its rewording.

## References

- Decision 0025, the registration rule.
- Decision 0052, the seeded draw whose statement the rows carried.
- Decision 0053, the protocol table this record's table stands beside, and the prose rule.
- Decision 0054, `depends_on` and the clause rule for a restatement.
- `docs/plans/fiddlybits-52v.8-oracles.md`: the loader's `Entry`, which reads the fields
  `oracles.registry_wellformed` checks rather than deciding them a second time.
- Decisions 0039 (the argument lives here, not in the harness) and 0040 (the amends edge).
