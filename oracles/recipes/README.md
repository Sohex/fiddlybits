# Oracle data recipes

Each script here regenerates one extract under `oracles/data/<id>/` (untracked) from
its public source, and writes the granule manifest the TOML file under
`docs/oracles/data/` is built from. They are fetch-and-reduce tools, not model code:
Python with `earthaccess` for NASA Earthdata (credentials from `~/.netrc`), run through
`qrun`. The reduction rule a script applies is declared in its manifest before the
first granule is read, and a change to the rule is a new extract id, never an edit of
an existing one.
