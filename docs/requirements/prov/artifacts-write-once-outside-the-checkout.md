+++
id = "REQ-PROV-003"
title = "Artifacts are content-addressed, write-once and outside any checkout, so a worktree can neither strand a payload nor write through"
old_path = ["/home/cfutro/git/vesper/notes/audits/worktree-stranded-payload.md", "/home/cfutro/git/vesper/notes/audits/worktree-write-through.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the predecessor's tooling, which linked ignored payload into git
worktrees file by file wherever a directory also held tracked content. The
arrangement failed in both directions. A file created in such a directory in a
worktree was real there and nowhere else, matched the ignore rules, and died with
the worktree, while the tracked index row written for it in the same session
survived: thirteen reference PDFs cited by filename were absent, eleven marked as
read with numbers transcribed out of them, and one of those numbers turned out on
recovery to come from a different paper than the row named. Twenty-one files were
in that state across 84 standing worktrees; a climate run or a terrain export
written under a worktree had the same exposure. In the other direction, an existing
linked file was a symlink into the main checkout, so a worktree that regenerated one
wrote straight through: a generated header was regenerated in a worktree and the
main checkout's binary, built against the previous bytes, began failing its own
verification with nothing naming the cause. 594 files totalling 11.6 GB were
exposed. A read-only link is not constructible (a symlink carries no mode of its
own); a copy-on-write shadow would have cost about a terabyte across the standing
worktrees and pinned each to stale inputs. The repair was a refusal at each write
door plus a per-worktree link ledger checked at commit, which names the fact and
not the culprit, since from inside a worktree a write from there and a regeneration
in the main checkout are indistinguishable.

## Why it carries

The plan's risk register names a single developer plus agents working in parallel
worktrees, and the references discipline of Part G rests on an index whose `read`
rows must be checkable against a file. Both failure directions are properties of
mutable, path-addressed artifacts shared across checkouts, and both are
unrepresentable under content addressing outside the tree (A6): a key is never
overwritten, so a regeneration is a new key and write-through has nothing to write
through; the store is not in any checkout, so a payload cannot be stranded in one;
and a ledger row cites a key, not a path, so an absent payload is a reportable fact
rather than a silent loss.

## What this system must do

1. The artifact store lives at one declared location outside every checkout. The
   tree carries only keys, the ledger and the references index; no checkout holds
   payload.
2. Keys are write-once: a put with an existing key verifies the bytes are equal and
   refuses otherwise. There is no in-place regeneration; a regenerated artifact is
   a new key, and the ledger records supersession with the reason (superseded means
   wrong, not old; registered, present and activatable are three states).
3. A ledger row is written in the same transaction as the payload. A row whose
   payload is absent from the store is reported by key, and a gate that needs it
   reports NotEvaluable by name; absence is never read as deletion and never as
   presence.
4. The references index has the same shape: a row claims a file only if the file
   exists in the untracked payload directory under the name the row gives; the doc
   lint fails on a row whose file is absent; a row is `read` only when an anchor
   names the number or scheme taken from it.
5. Writes to the store go through one function with no override flag; a write
   outside it is lint-banned.
6. Concurrent writers converge: an id is minted with its row under a lock, and two
   processes putting the same content obtain one key.

## Enforced by

The store API tests (write-once refusal, absent-payload reporting, concurrent put);
the doc lint over the references index; decision records A6 and the Part G
references discipline.

## References

- Secure Hash Standard (SHS). FIPS PUB 180-4. DOI: 10.6028/NIST.FIPS.180-4
- Merkle, R. C. 1988. A Digital Signature Based on a Conventional Encryption Function. Advances in Cryptology (CRYPTO '87), Lecture Notes in Computer Science 293. DOI: to confirm
- Zarr core specification, version 3. Locator: https://zarr-specs.readthedocs.io/en/latest/v3/core/index.html
