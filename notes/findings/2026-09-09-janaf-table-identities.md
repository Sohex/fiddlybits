# The JANAF tables read cleanly and arrive wrong on a third of their pages

Measured on 2026-09-09 over the finished read of the scanned NIST-JANAF Thermochemical Tables,
fourth edition: 1961 pages by `chandra-ocr-2` under vLLM, 1095 of them carrying a
thermochemical data table, 64,327 tabulated rows in all.

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

| broken rows | kind |
|---|---|
| 3501 | the equilibrium constant does not follow from the Gibbs energy beside it |
| 928 | the row is not eight cells wide; a value is simply absent |
| 251 | the Gibbs energy function does not follow from the entropy and enthalpy beside it |

| pages | how much of the page |
|---|---|
| 281 | one to four rows |
| 128 | five or more rows, short of the whole |
| 12 | more than four fifths of the rows |

421 of the 1095 table pages carry at least one defect. 674 are clean throughout.

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

## What it means for the reader

4398 of the 64,327 rows break a relation, so 93 percent of rows pass. That is the ceiling, not
the estimate: the two relations constrain four of the eight columns, and the heat capacity, the
entropy and the enthalpy of formation stand on their own with nothing to test them against. A
number lifted from these tables by hand is probably right and gives no sign either way, which
is worse than a read that fails loudly.

So the tables are not a usable source yet. The flagged pages are re-read and put back through
the audit, and a page that carries a constant into the model is checked against the scan by eye
whatever the audit says about it.

The 421 flagged pages are listed for re-reading in `references/work/janaf_repair_list.txt`, in
the form `chandra_pages.py --repair` takes.
