# Input datasets

Datasets the MODEL READS, as distinct from the oracle datasets it is judged against
(`docs/oracles/data/`). Each has a TOML manifest here naming its source, licence,
identifier, hashes and the decisions and requirements it anchors, with the payload
untracked under `inputs/data/<id>/`. An input dataset enters the model only through a
`Sourced` disposition that names the file and the record within it; a value derived from
one (a band-integrated albedo, say) is `Derived` from that source and the declared
spectrum, never copied in.

A manifest here whose bytes an oracle also reads names that registry entry in its
`oracles` key, and the entry names the manifest back in `datasets`
(`docs/oracles/README.md`, Registration).
