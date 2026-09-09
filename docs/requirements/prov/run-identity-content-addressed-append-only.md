+++
id = "REQ-PROV-002"
title = "Run identity is content-addressed and append-only, never rebuilt by scanning, and the code that ran is part of the key"
old_path = ["/home/cfutro/docs/world/notes/audits/run-identity.md", "/home/cfutro/docs/world/notes/audits/executable-provenance-at-the-consumer.md", "/home/cfutro/docs/world/notes/audits/model-build-driver.md"]
old_commit = "6aa93489d233d4e9d531d6479d338c643e34bc5e"
status = "carried"
+++

## What is true

Measured on the predecessor's run bookkeeping. Run ids were opaque, which was
right, and the record that gave them meaning was rebuilt by scanning the untracked
run directory, which recorded what existed at the scan rather than what had
existed. Forty run ids cited by notes and analyses had no record anywhere; what was
gone for each was the configuration, its hash, the executable hash, the source
build, the orbit count and the convergence assessment. Reconstructing two of them
from surviving analysis artifacts showed the two arms of a published comparison
had differed in a filter exponent as well as in their starting state, and a
finding that had stood for six days was wrong. A later registration passed a
single row through a merge that read absence as deletion and marked 33 live runs
as having lost their payloads (297.8 GB on disk, untouched); consumers filtered on
that flag and reported two indexed runs as "in no run index at all".

A stability probe took its executable from a template run directory selected by
modification time; its results recorded no executable name, hash or path, so no
entry could be attributed and sixteen of sixty cells that declarations rested on
had to be re-derived. After a source patch and a verified registry rebuild, that
probe integrated a run directory's older copy and printed the pre-repair values,
which read as the patch having failed. The manifest itself recorded a binary that a
rebuild-on-first-use path had silently replaced before any orbit ran.

The build driver fell through to defaults on an unrecognised value (a resolution
spelled `170` built the coarsest rung; a precision of `16` built single precision)
and left the caller's expected filename pointing at a stale binary; a build tag
composed from arguments but not from the source state let a patched control arm
occupy the registry's own directory under the registry's own tag; a source glob
hashed uncompiled files into every binary's provenance. The same sources at two
checkout paths produced different binaries because the toolchain embedded the path.
The predecessor's provenance module reached the durable lessons: namespace by
identity rather than stamp and check where possible; check at the read, not at the
end; compare parsed values, never a file hash of a configuration; hash the derived
input files a generator read, because their names are stable across a change; a
deliberate cross-identity read names the identity it means, never a flag that
turns the check off; a hash in prose is a current value wearing the costume of an
identity (`/home/cfutro/docs/world/lib/provenance.py`,
`/home/cfutro/docs/world/docs/src/reference/builds.md`). Registered, present and
activatable were three states of a build, and a registry entry carried a
machine-readable refusal where the reasons had begun as prose no gate could reach.

## Why it carries

This system runs sweeps, ladders, reference arms and A/B comparisons as its
verification method (C1 to C6, M4b), and every one of them is controlled only if
each number can be attributed to code version, parameter subset, inputs, support,
backend and precision. The three mechanisms that lost identity (a scan as the
record, modification time as selection, a default on an unrecognised input) are
representable in any language and any tooling. Content addressing (A6) and a
keyword-only, default-free `System` (A3) make the first and third
unrepresentable; the second is a lint. The code-version lesson has a Julia form:
there is no compiled artifact to copy, so the version is the tree hash of the
loaded package and its dependency manifest, computed at load, and a path-dependent
artifact cannot exist.

## What this system must do

1. Artifact key = hash(code version, the parameter subset the component declared
   and was measured to read, input keys, support id, operator version) (A6). A run
   id is a UUID minted with its ledger row before any step executes; human names
   are detachable tags.
2. The run ledger is append-only. A row is written at creation and updated at every
   segment end and at every termination including failure. A scan never deletes a
   row or rewrites an identity field; payload absence is a separate flag set only
   by a full authoritative listing of the store; the ledger's identity is tested
   (a merge against an empty scan returns every row unchanged; an upsert of one row
   leaves every other row's flags alone).
3. The code version is the git tree hash of the loaded package plus the hash of the
   dependency manifest, computed at load by the package itself; no consumer selects
   code by path, glob or modification time (lint-banned), and there is no "latest".
4. Configuration is keyword-only with no defaults (A3); an unrecognised key or value
   is a refusal that names it. A patched or modified source has a different code
   version by construction, so a control arm cannot collide with a registry entry;
   nothing is published under a key it does not hash to.
5. Identity is checked at the read: a consumer requests an artifact by key; a
   deliberate cross-key read names the key it means; there is no flag that
   disables the check; configuration comparison is over parsed values; every
   derived input file a generator read is hashed into the artifact's record.
6. Every measurement artifact (probe, benchmark, oracle verdict) carries the full
   key of what it measured; a verdict without one is NotEvaluable.
7. Backend and precision are part of the run identity (C6).

## Enforced by

The content store and its identity tests at M0; the ledger tests; the lints (no
path, glob or mtime selection; no defaults); JET on constructors; decision records
A3, A6, C2 and C6; the references discipline of Part G for prose that cites an
identity.

## References

- Secure Hash Standard (SHS). FIPS PUB 180-4. DOI: 10.6028/NIST.FIPS.180-4
- Merkle, R. C. 1988. A Digital Signature Based on a Conventional Encryption Function. Advances in Cryptology (CRYPTO '87), Lecture Notes in Computer Science 293. DOI: to confirm
- Zarr core specification, version 3. Locator: https://zarr-specs.readthedocs.io/en/latest/v3/core/index.html
