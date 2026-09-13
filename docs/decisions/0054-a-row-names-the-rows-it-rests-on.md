+++
id = "0054"
title = "A registry row names the rows it rests on in depends_on, states no bar of theirs, and names no row in its statistic or threshold"
status = "accepted"
date = 2026-09-13
amends = [{ record = "0053", what = "where a row that rests on another row's question names it: in a depends_on field checked by oracles.registry_wellformed, not in its statistic" }, { record = "0025", what = "the reduced-radius dynamical-core cases are one row, at tier 1 under the published norms decision 0026 gives them, and not a second tier-3 row carrying the same statistic and bar on the same protocol" }]
+++

## Decision

**A row names the rows it rests on in `depends_on`.** `depends_on` is an optional list of
registry row ids. It names each row that decides a constituent this row's metric rests on
and does not judge: the property its statistic presupposes, or the instrument its
statistic is built from, where that row already defines it. It is written where the
row's subject carries the constituent, so that without the field the statistic would
have to name it. It is not a list of every precondition of a run: that a run closes its
ledgers is presupposed by every row, and a row names `ledger.closure` only where its
published case or its subject carries a conservation property as a constituent.

**A dependency's verdict is its own row's.** The named row is judged where its own entry
says, by its own threshold. The depending row carries no bar for that constituent, and
its verdict does not change with the dependency's; a report of the depending row names
each dependency's verdict beside its own, so a PASS resting on a failed identity reads
as such. No fourth verdict is made: decision 0025's three stand.

**A row depends only on rows of its own tier or a lower one.** The tiers are trusted in
order (decision 0025), so a verdict never rests on a less trusted one: an identity does
not rest on a distance from Earth or on a published spread.

**No statistic or threshold names a registry row.** With the edge in a field, a row id in
prose has nothing left to do. Naming a dependency there is the edge written twice, and it
is where a restatement attaches: `sweep.obliquity` named the insolation identity in its
statistic and restated its bar in its threshold. A row id that is not a dependency, such
as a pointer to where a constituent moved, is history, which git carries.

**A restatement of a dependency's threshold is decided on clauses.** A clause is the text
of a statistic or threshold between semicolons and sentence ends, lowercased, with its
whitespace collapsed and a leading `provisional` marker removed. A row restates a
dependency's threshold when its statistic or threshold carries a clause equal to a clause
of the threshold of a `fail_bar` row it depends on, directly or through other rows. A
`report` row states no bar, so there is nothing of it to restate. A depending row whose
own bar happens to share a bare clause with its dependency's, such as a single tolerance
word, says what its bar is on; a bar that names its quantity is the one a reader can
attribute.

**The check.** `oracles.registry_wellformed` decides the dependency shape in
`test/oracles/wellformed.jl`, beside the verdict-shape clauses of decision 0053:
`depends_on` is a list of ids, each named once, each a row, each on the depending row's
tier or a lower one; no row depends on itself, directly or through other rows; no
statistic or threshold names another row's id; and no statistic or threshold carries a
clause of the threshold of a `fail_bar` row the row depends on. Its positive controls are
a fixture row depending on an absent row and a fixture row carrying a clause of its
dependency's threshold, both of which must be refused; every other clause has a fixture of
its own, and the clean fixture carries edges and must be accepted.

## Alternatives considered

- *Leave the name in the statistic*, as decision 0053 left it. Lost: a name in prose is
  resolved by nobody, so a renamed or removed row leaves a dangling reference that reads
  as a dependency, and the prose beside the name is where the restatement was written.
- *Both the field and the name in prose.* Lost: one edge written twice, and the two copies
  drift the way two definitions of one quantity drift.
- *A dependency that gates the depending verdict*, turning the depending row NotEvaluable
  or FAIL when a dependency fails. Lost: NotEvaluable is a loop verdict and not an oracle
  verdict (decision 0025), and a FAIL that is really another row's FAIL is one defect
  counted twice. Reporting the dependency's verdict beside the row's carries the same
  information without a new verdict.
- *Decide restatement by textual similarity* between a row and its dependency. Lost: a
  similarity cutoff is a number nobody can source, and the defect this record answers was
  a paraphrase with a different bar, which no similarity measure reliably separates from
  an unrelated sentence on the same subject.
- *Decide restatement by the tolerance vocabulary*, refusing a tier-3 row whose threshold
  carries an identity's tolerance word. Lost: it binds a word list to tiers, refuses a
  depending row's own identity bar, and says nothing about which row the bar belongs to.
- *Decide restatement by name alone.* Lost: two rows of the tree carried a dependency's
  bar clause verbatim without naming it (`physics.water_roughness_identity` the log-law
  bar of `physics.monin_obukhov_neutral`, `seaice.mass_salt_conservation` the exchange bar
  of `ledger.closure`), and a copied clause is decidable once the edge is declared.
- *An edge from every row to every row it logically presupposes.* Lost: every coupled
  row would name every ledger, identity and mesh check below it, and a field naming
  everything distinguishes nothing.

What the check cannot decide stays review's: a paraphrase of a dependency's bar that
neither names the row nor copies a clause, and a restatement of a row not declared as a
dependency. The audit that accompanied this record is that review applied once to every
row.

## Consequences

- `docs/oracles/registry.toml` carries `depends_on`, and every row id that stood in a
  statistic or threshold is gone from it. The four edges decision 0053 left as names
  become the field: `sweep.obliquity` on `system.orbit_mean_insolation`,
  `core.held_suarez` on `ledger.closure`, `sweep.gravity` on
  `physics.gravity_column_identities`, `sweep.rotation_rate` on
  `core.hadley_small_rossby_limit`. So do the names found in other rows:
  `build.inference_suite_cost` on `fields.inference_tight`, `rad.line_by_line_reference`
  on `rad.broadening_partner_identity`, `terrain.denudation_vs_relief` on
  `terrain.age_rate_identity`; the reciprocal move notes between
  `terrain.drainage_isotropy` and `terrain.hack_exponent` are removed.
- The audit of every row found restatements that named nothing, and each is rewritten:
  `physics.water_roughness_identity` judges the Charnock roughness and rests on
  `physics.monin_obukhov_neutral` for the log law; `seaice.mass_salt_conservation` judges
  advection and ridging and rests on `ledger.closure` for the exchange with the ocean;
  `terrain.stream_power_steady` no longer carries the gravity exponent that
  `terrain.incision_gravity_identity` judges, and the latter rests on it;
  `column.richards_philip` judges the late-time rate against `K_s` at each gravity and
  rests on `land.gravity_identities` for the scaling of `K_s`;
  `system.gravity_and_figure` no longer carries the disagreeing-caller refusal that
  `system.derived_fields_reproduce` judges, and rests on it.
  `core.held_suarez_rotation_scaling` rests on `core.hadley_small_rossby_limit`, as
  `sweep.rotation_rate` does.
- `sweep.dcmip_reduced_radius` is removed. It carried the statistic and the bar of
  `core.dcmip_small_planet` on the same protocol; its elapsed-time scaling clause moves
  into that row.
- `repro.backend_ulp_envelope` and `repro.fp32_kernel_certification` carry one ensemble
  definition twice in their thresholds. Neither rests on the other's question, so this is
  not a dependency; where a bar instrument shared by rows is declared is
  `fiddlybits-859`.
- `docs/oracles/README.md` states the field and its rules;
  `docs/plans/fiddlybits-52v.8-oracles.md` gives the loader's `Entry` a `depends_on` and
  the oracle its dependency clauses; `fiddlybits-52v.8.2` resolves each id to its `Entry`
  and does not decide the shape a second time.

## References

- Decision 0025, the three tiers in order of trust and the three verdicts.
- Decision 0053, the verdict shape and the names this record turns into a field.
- Decision 0026, the reduced-radius small-planet cases under published norms.
- `docs/oracles/README.md`, Verdicts and Registration.
- Decisions 0039 (the argument lives here, not in the harness) and 0040 (the amends edge).
