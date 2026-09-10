# The JANAF tables read cleanly and arrive wrong on a third of their pages

Measured on 2026-09-09 over the finished read of the scanned NIST-JANAF Thermochemical Tables,
fourth edition: 1961 pages by `chandra-ocr-2` under vLLM, 1071 of them carrying a
thermochemical data table, 63,426 tabulated rows in all. Every count here is of that read, at
the 6291456 pixel cap the server was started with, before any page was read again.

The prose of that read is excellent. Title page, copyright page, the species index, the
per-species discussion of enthalpy of formation, and the reference lists all come back with
their structure intact, superscripts and subscripts marked, and no visible transcription
error. Judged on the text alone the read would be called a success.

The tables are the problem, and no amount of reading them tells you so.

## The page is its own oracle

Each data page prints eight columns, and two of them are not independent measurements. They
are arithmetic:

    -[G(T) - H(Tr)]/T  =  S(T) - [H(T) - H(Tr)]/T
    log Kf(T)          =  -dfG(T) / (R T ln 10)

Every row of every page must satisfy both, to the rounding of the printed digits. Nothing
external is needed to check a page, no sample is drawn, and there is no threshold to argue
about: at 0.06 J K-1 mol-1 and 0.03 in the logarithm, the tolerances sit two orders of
magnitude above the rounding and far below any real defect. The audit is
`tools/references/audit_janaf_tables.py`, and its positive control breaks a passing page four
ways -- a dropped column, a column slid by one row, a column duplicated over its neighbour, a
lost decimal point -- and requires all four to be caught.

## What the relations find

493 of the 1071 table pages carry at least one defect, 9614 broken relations in all. 578 are
clean throughout.

The audit had to be corrected before that number could be trusted. It first decided which
table on a page was the thermochemical one by counting rows that were eight cells wide, which
meant a page whose every row had lost a cell was not recognised as a table at all and was
reported clean. Two of the worst pages in the corpus passed that way. The gate now counts rows
that begin with a tabulated temperature, and width is a defect rather than a filter.

## The shapes the damage takes

Three failure modes account for nearly all of it, and none of them produces anything a reader
would notice.

**A column slid by one row.** On the aluminium ion page the formation columns are blank for
the first five temperatures and every later value sits one row below where it belongs, so the
row labelled 300 K carries the 298.15 K numbers. The column is smooth, monotone and plausible
at every point. Solving each row for the temperature that would make the relation hold returns
exactly the previous row's temperature, from 300 K to 2900 K, which is how the offset was
identified at all.

**A column duplicated over its neighbour.** On the zirconium oxide page the enthalpy and the
Gibbs energy of formation are identical on all 64 rows. One real column was lost and the one
beside it was written twice.

**A column dropped entirely.** On the boron crystal-liquid page the header cell reads
`S - [G - H(Tr)]/T`, two headings merged into one, and the data rows are eight wide with the
last cell empty: the Gibbs energy function is gone from every row and everything to its right
has moved one place left. The enthalpy column now sits under the entropy heading.

This is the same silent loss recorded for sideways pages in
`notes/findings/2026-09-09-chandra-page-orientation.md`, and it survives the orientation
repair. Turning the page upright fixed the reading; it did not make a dense eight-column table
safe to transcribe.

## Most of it is the pixel budget

The server was started from the chandra_vllm docker recipe's cap of 6291456 pixels. A letter
page rendered at the reader's 3300 pixel long side is 8.4 million, so every page was being
downscaled to 2205 pixels across the text before the model saw it, which is about 24 pixels
for a column of six digits and a sign.

Doubling the cap to 12582912 puts the page at 3118 pixels across the text, at the cost of
doubling the prompt: one visual token covers 32 by 32 pixels, so the model length has to hold
12288 visual tokens and the reply as well. Seven wholly corrupt pages read again at that
budget, whole, at a 4400 pixel render:

| page | broken relations, 6.3 Mpx | at 12.6 Mpx |
|---|---|---|
| aluminium ion | 64 | 3 |
| boron crystal-liquid | 52 | 51 |
| mercury fluoride | 64 | 64 |
| a lanthanum page | 61 | 0 |
| zirconium oxide | 64 | 0 |
| tetraphosphorus trisulfide | 116 | 116 |
| a sulfur page | 122 | 1 |

Sampling is greedy, so the old column is the same page read the same way at the smaller budget
and needed no re-running. Four of the seven come back clean or nearly so.

## What the budget does not fix

The three that do not move share a signature, and it is in the header rather than the data. On
each of them two adjacent column headings are returned as one cell -- `S - [G - H(Tr)]/T`
where the page prints the entropy and the Gibbs energy function as neighbours -- and one data
column then goes missing from every row. The mercury fluoride page came back byte for byte
identical at twice the resolution.

So the model is not failing to resolve those characters. It is parsing two columns as one,
and reading them larger does not change its mind. That residue needs a different lever than
the pixel budget.

## What it means for the reader

9303 of the 63,426 rows break a relation, so 85 percent of rows pass. That is the ceiling, not
the estimate: the two relations constrain four of the eight columns, and the heat capacity, the
entropy and the enthalpy of formation stand on their own with nothing to test them against. A
number lifted from these tables by hand is probably right and gives no sign either way, which
is worse than a read that fails loudly.

The conclusion is not to read the pages again. It is that this scan should never have been a
data path. The same quantities are published as machine-readable NASA polynomial fits in the
Burcat and Ruscic database, 3526 species, fetched and manifested at
`docs/inputs/data/burcat-ruscic-thermochemical.toml`. Coefficients evaluated in closed form
beat a table lookup on a page that has to be transcribed correctly first, and every record
there carries its own source and date. The scanned book keeps a role, and it is the right one:
a species evaluated from the coefficients is checked against the printed table by eye.

## The part that generalises

The pixel budget was not specific to this book. Passes 2 and 3 read every scanned source in
the reference tree at the same 6291456 cap, and only this one could be caught, because only
this one prints columns that check each other. Chapman and Cowling, Henderson's open channel
flow, Brutsaert's evaporation: each has tables, none has an internal identity, and nothing has
looked at them. The cap has been raised for future reads; what was already read at the old one
has no audit and no positive control.
