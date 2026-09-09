# Practice

How a session conducts itself. One line per rule, in its positive form, with a
one-sentence argument and where the full argument lives. Old paths are cited under
`/home/cfutro/docs/world/`; `FM n` is class `n` of
`docs/src/practice/failure-modes.md` there, carried into `docs/failure-modes.md` here.
Each rule is here on its own merits for a generic builder; the predecessor's rules
that were about its own artifacts were left behind.

## Ending work

- **A task has two end states, completed or blocked; anything else is mid-task,
  however well it is reported.** A report that names what remains is not a
  finish. `docs/src/practice/working-agreements.md`.
- **Naming the next step is not taking it: if you can say what would settle a
  question, you are not blocked.** Blocked means an input only the user can give.
  Same file.
- **Every open thread gets its own verdict, named separately.** One blocked item
  does not cover the one beside it. Same file.
- **A delegated agent works the rows it files to resolved or blocked before
  reporting.** Finding a defect is most of the cost of fixing it, so the context
  that found it fixes it; the brief draws the file boundary wide enough. Same file.

## Deciding what to build

- **Ask whether the thing should exist before building, fixing or documenting it;
  deleting is a fix.** Ask what breaks if it simply goes. Same file.
- **A defect is not a decision.** If one option is "leave the known-wrong thing as
  it is", the question is mis-framed; a decision is a choice between declared
  truths or an unfixed threshold. Same file; FM 19.
- **Physics is not a knob.** A process is in the model because it exists; a correct
  term that worsens an agreement is information, never a reason to remove it.
  `docs/src/practice/conventions.md`; FM 16.
- **Constants have exactly five dispositions: Sourced, Derived, Bracketed,
  Irreducible, Closure.** A number held in place only because it made a comparison
  come out has no derivation and cannot be carried to another configuration.
  `docs/src/practice/conventions.md` "No tuned values"; `docs/decisions/`.
- **Build the cheap route on the general formulation; buy the expensive route when
  an instrument says a configuration needs it.** A limit case of the general
  equations is never a different model. `docs/decisions/`.
- **Nail every interface out of the gate.** A subsystem may be a declared absence;
  its interface may not, because a retrofitted interface reaches every consumer.
  `docs/decisions/`.

## Measuring and believing

- **A test needs a right answer: an identity, a conservation law, or a quantity the
  other side already knows.** If you cannot say in advance what result would mean
  "wrong", it is not a test. FM 17.
- **A check that cannot fail is not a check; every probe carries a positive
  control that must fire.** Print one unconditional line at the instrumented site
  before believing a zero. FM 41.
- **Thresholds are fixed before results are seen.** A criterion chosen after the
  run it judges is not a criterion; the registry records the commit that fixed it.
  `docs/src/practice/conventions.md`; `docs/oracles/README.md`.
- **Check the instrument against the size of the effect before believing a
  number.** If the effect is smaller than the instrument's own scatter, the number
  is noise however tidy it looks. FM 34.
- **Standard errors account for autocorrelation.** A series with memory has fewer
  independent samples than it has samples. `docs/decisions/`.
- **Before relying on a recorded conclusion, check the current configuration is
  inside its measured envelope; re-measure rather than inherit.** A claim recorded
  as settled is settled for what it was measured on. FM 6.
- **Name the loop iteration and stage of any number you quote.** A pre-coupling
  artifact is a limit, not a state, and looks exactly like a state. FM 8.
- **Read the source table and say which equation a number multiplies.** A number
  taken from a citation rather than from the paper has cost two corrections, one of
  them half wrong. FM 9; `docs/references/README.md`.
- **Before calling an estimate a bound, enumerate what pushes it the other way;
  otherwise call it an estimate.** FM 10.
- **When a bug is found in one term of a chain, measure the chain before
  correcting the term.** Two errors that nearly cancel are broken by fixing one.
  FM 15.
- **Before measuring to settle whether something should exist, say what value
  would change the conclusion; if none would, do not measure.** FM 23.
- **A comparison needs an established baseline: run the A/A arm before the A/B
  verdict.** FM 27.
- **A stochastic property is tested by an ensemble, not a pair.** FM 30.
- **Characterise a value from where it is used, never from where it is
  declared.** A declaration can be overridden downstream or unreachable by default.
  FM 32; `notes/external-tree-checklist.md` Tier C.
- **Estimates that cannot be verified are bracketed, and the bracket is
  reported.** `docs/src/practice/conventions.md`.
- **Claims are checked against the artifact, not the documentation.** Same file.
- **Convergence claims state their exact criteria and are labelled honestly when
  they miss.** Same file.

## Quantities and their owners

- **One definition per quantity; as many doors as needed; never two definitions.**
  A fix that reaches some consumers of a quantity and not others has cost a whole
  build. FM 1.
- **Every derived quantity states what depends on it, and a consumer reads the
  emitted value or sits inside a loop that re-derives it with a check.** A derived
  value written down somewhere is an update that cannot propagate. FM 5;
  `docs/src/pipeline/loops.md` "a field update has to be able to carry".
- **A producer is named with its arguments.** A re-derivation that names the run
  and not the window is a reading of something else the day the window moves.
  Same file.
- **No silent default across a component boundary; check at the point of
  reading.** A fallback returns a plausible number from a different world instead
  of an error. FM 2, FM 3; `lib/provenance.py` docstring.
- **Conventions travel by name, never by coordinate.** Two labelings of one axis
  are compared as two names; a translation layer implies there is something to
  translate. FM "one quantity, two meanings"; `lib/gridding.py` docstring.
- **A structure that can carry variation holds variation, or says why it does
  not.** A per-band array initialised from one scalar carries a spectrum nowhere.
  FM 31.
- **Refuse rather than snap, interpolate or backfill.** An off-axis label snapped
  to the nearest column matched every cell half a planet away. `lib/gridding.py`.
- **Earth constants are unit-conversion denominators with names that forbid
  physical use.** Earth is a comparison to report the distance from, never a
  target. `docs/src/reference/vocabulary.md` "implicit-Earth".

## Documents and records

- **Findings, decisions and tasks are kept apart.** A finding says what is true
  with its evidence (`notes/findings/`); a decision says what was chosen
  (`docs/decisions/`); `bd` says what to do and cites one of the other two.
  `docs/src/practice/conventions.md` "The issue tracker".
- **Retrieval returns locators, never values.** The search instruments over the
  held papers say where to look; a value or scheme is taken only from the opened
  page, with its table or equation named. `docs/references/README.md`, Instruments.
- **TOML for everything a person edits or reads.** Configurations, manifests, the
  oracle registry and every record header are TOML; a declared numeric then has one
  syntax and cannot become a string. The predecessor needed a smoke check to catch
  `5.0e4` parsing as a string under YAML. Decision 0036.
- **No current values in prose.** A number earns a place in a document only as a
  decision, a threshold, an identity, or a magnitude an argument fails without;
  dated findings are the exception and carry "measured on". Same file, "Documents
  and numbers".
- **Rewrite superseded content; do not mark it.** A reader grepping for a number
  lands on the number, not the warning above it. Same file.
- **A sentence earns its place by the future work it can inform.** Process
  narration, correction stories and commentary about the document itself are
  byproduct; git carries how a document came to be right. FM 25.
- **State the positive form, the decision procedure, and an issue; do not print
  what a rule forbids or announce tensions between rules.** FM 26.
- **A derived summary is regenerated from its primitives or deleted.** A count in
  prose drifts from the list it counts. FM 24.
- **State what gates what.** A gate asks its question through a channel that
  answers that question and nothing else. FM 38.
- **An undocumented component is not complete.** The test for done is that
  someone who has never seen it can find it and use it without reading the diff.
  Old `CLAUDE.md`.
- **Every constant, law and scheme is anchored to a read primary source with a
  locator.** "Held" is an open exposure, not a resource; request a paper from the
  user by verbatim title and DOI, after checking the index. `docs/references/README.md`.
- **No line-count, person-week, schedule or MVP framing anywhere.** Describe
  scope, dependencies and gates. User direction, 2026-09-07.
- **Write about the simulation in the simulation's terms, and never frame the
  project around a specific planet or star.** The predecessor's world appears only
  as the place a finding was measured. `docs/requirements/README.md`.
- **ASCII punctuation; no em dashes; citations and table cells on one line.**
  They get copied out. Proper names keep their diacritics; the rule is about
  punctuation and prose symbols, not about people. `docs/src/practice/conventions.md`
  "Prose registers".

## Working with the user and the machine

- **Raise decisions in prose with description, options, pros and cons, and expect
  a back-and-forth.** Do not use the AskUserQuestion tool. User direction,
  2026-09-07.
- **Heavy work goes through `qrun`, never directly; never detach; never size
  parallelism with `nproc`.** `~/.claude/CLAUDE.md`.
- **A killed job usually means a limit, not a bug.** Raise the limit that was hit
  and say which. Same file.
- **Record the load beside any timing you keep.** The scheduler gives a job its
  cores, not the memory bandwidth around them. Old `CLAUDE.md`.

## Working the board

- **Three layers, never mixed in one row.** An epic states a gate; a plan row (frontier)
  writes `docs/plans/<epic>-<slug>.md` and files the implementation rows; an
  implementation row does one bounded thing in its own worktree. Decision 0037.
- **Pick a ready row of your tier, claim it, work in its worktree.** `bd ready`, then
  `bd update <id> --claim`, then `bd worktree create <id>`; work only inside the row's
  file boundary; `bd worktree remove <id>` after merge.
- **Acceptance is fixed before the work.** A row without named oracles in its
  acceptance field is not ready; ask the planner, do not invent a criterion.
- **Two end states.** A row ends completed (its oracles ran and passed, reported by
  name) or blocked (what would unblock it, named). File follow-on rows for what you
  find; never widen your own.
- **A filing is not an end state.** Writing a finding, filing a row, or naming what
  should change is bookkeeping on the way to the work, not the work. A stream is
  complete when the tree carries the change it called for: the record amended, the
  registry entry added, the recipe run and its manifest written. When the context to
  make the change is in hand, make it; file a row only for what genuinely needs another
  session, another tier, or the user's decision, and say which.
- **Every merge is reviewed by a frontier model against the plan**, including
  `tier:local` rows, whose failure mode is confident wrongness.

