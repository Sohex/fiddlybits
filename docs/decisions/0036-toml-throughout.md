+++
id = "0036"
title = "TOML for every configuration, manifest, registry and record header"
status = "accepted"
date = 2026-09-08
+++

## Decision

Every structured, human-edited or human-read data file in this project is TOML:
system and profile configurations, artifact manifests, the oracle registry, import
and requirement and decision record headers, and any table of declared values.
Record headers in Markdown files use TOML front matter delimited by `+++` lines.
YAML and JSON are not used for anything a person edits or reads. JSON remains
acceptable only where a tool emits it for another tool (a Zarr array's own metadata
is Zarr's business), and even then a TOML manifest beside it carries what a person
needs.

Numbers are written so the parser reads them as numbers; TOML has one syntax for a
float and one for an integer, so a declared numeric cannot silently become a string.
Dates in headers are TOML dates, not quoted strings.

The parser is Julia's standard-library `TOML`, which adds no dependency and needs no
import review beyond the standard library's.

## Alternatives considered

- *YAML.* Rejected. The predecessor recorded that `5.0e4` and `1e+10` are strings
  under YAML 1.1 and `5.0e+4` is a float, and had to add a smoke check refusing the
  string forms (`/home/cfutro/docs/world/CLAUDE.md`, conventions; the check was
  `smoke_test.py:check_declared_numerics_resolve_to_numbers`). A format whose number
  syntax needs a lint is the wrong format for declared constants. YAML also admits
  implicit typing of `yes`, `no`, `on`, `off` and unquoted times.
- *JSON.* Rejected for human-edited files: no comments, no dates, trailing-comma
  fragility, and numbers with no integer/float distinction.
- *Julia source as configuration.* Rejected: a configuration that is code cannot be
  read by a tool in another language, hashed as data, or diffed as declarations.

## Consequences

- `docs/requirements/README.md` and `docs/decisions/README.md` specify `+++` TOML
  front matter; records written earlier with `---` YAML front matter are converted.
- The oracle registry, import records, and the future `params/*.toml` and Zarr
  manifests are TOML.
- A `Sourced` disposition's locator, a `Bracketed` disposition's bounds, and a
  `Closure` disposition's scaling law are TOML tables, so they are diffable and
  hashable as data.
- The doc lint checks that every Markdown record under `docs/` opens with `+++`.

## References

- TOML v1.0.0 specification, https://toml.io/en/v1.0.0 (no DOI).
- Julia standard library `TOML` module documentation, https://docs.julialang.org/en/v1/stdlib/TOML/ (no DOI).

## Amendments

- 2026-09-13: the archive this record cites now resolves at /home/cfutro/git/vesper; /home/cfutro/docs/world no longer exists on disk, from notes/findings/2026-09-13-predecessor-archive-relocated-to-vesper.md.
