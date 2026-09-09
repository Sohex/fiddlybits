+++
id = "REQ-PROC-009"
title = "A session ends completed or blocked, a defect is never offered as a decision, and the agent that discovers a task works it"
old_path = ["/home/cfutro/docs/world/docs/src/practice/working-agreements.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

The predecessor's working agreements, each with the incident that earned it: a task has
two end states, completed or blocked, and "reported", "diagnosed" or "handed over with a
recommendation" are mid-task; every open thread gets its own verdict named separately,
because one genuinely blocked item let an unblocked one beside it read as resolved; if
you filed a task this turn you have not finished, and if the fix fits in one sentence
that sentence is the commit (three handoffs in one session each turned out to be two or
three commits' worth of work that immediately unblocked the next thing); ask whether the
thing should exist before finishing, fixing or documenting it, and put remove on the
list beside repair and replace; a defect that cannot be removed without removing the
feature it serves is a fact about the feature; preserving behaviour is a virtue only
after the behaviour is known to be wanted ("output is byte-identical" went into a
commit as though it settled something); a thing is a decision only if the project's
declared truth does not already settle it, and if one of the options is "leave the
known-wrong thing as it is" the question has been mis-framed (a radiation weight for
the wrong star and an undeclared spectrum were both put to the user as choices; a
convergence criterion genuinely was one, because two rules pointed opposite ways);
stale derived artifacts are the resting state of the tree and hunting them is not
work, because regenerating one is a step already in the ordering; a delegated
workstream ends resolved or blocked and the agent that discovers a task is the one
that works it, because finding a defect is most of the cost of fixing it and the
context does not survive a handoff; what comes back is a decision declared truth does
not settle, a change the delegator scoped out, or work in another agent's directory,
and the delegator draws the file boundary wide enough that following a thread does not
immediately cross it.

## Why it carries

The plan's risk register names "single developer plus agents" with the mitigation that
briefs name the oracle and the file boundary and the oracle suite acts as reviewer. The
agreements are how a session inside that arrangement conducts itself; none depends on
the old stack. The judgement rules are stated as positive lines, per the practice book's
format, with the incident kept as the one-line cost history that calibrates the rule.

## What this system must do

- A session or delegated workstream ends completed or blocked; blocked means a decision
  only the user can take, a measurement needing hardware or data nobody has, or a run
  that must be authorised; each open thread gets its own named verdict.
- Filing a task is not finishing; a fix that fits in a sentence is executed, not
  reported.
- Before finishing, fixing or documenting a thing, its right to exist is asked;
  removal is on the list; a defect inseparable from a feature is recorded as a fact
  about the feature.
- A question is a decision only where declared truth (`System`, decision records,
  requirement records, findings, the oracle registry) does not settle it; a defect
  that declared truth settles is work, and "leave it as it is" is never an option.
- Stale derived artifacts are regenerated when a step needs them and otherwise left;
  a mismatch that would change a conclusion is stated in a sentence.
- The agent that discovers a task works it to completed or blocked; a brief names the
  oracle and draws the file boundary wide enough for the thread.
- What is handed back is a decision, a scoped-out change, or another owner's
  directory, with the evidence.

## Enforced by

`CLAUDE.md`'s one-line map; `docs/practice.md`; the `bd` session-close protocol; briefs
that name the oracle and boundary (Part E).

## References

- /home/cfutro/docs/world/docs/src/practice/working-agreements.md
- Plan Part E, "Single developer plus agents".
