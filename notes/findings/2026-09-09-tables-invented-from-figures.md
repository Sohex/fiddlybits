# The reader invents tables from figures, and 3839 rows of the corpus are numbers nobody printed

Measured on 2026-09-09 over the whole Chandra read of `references/text`, prompted by a spot check
of the tables in three scanned books.

255 tables, on 224 pages, across 57 of the sources, carry a caption saying their numbers were
estimated from a figure. They total 3839 rows. There was no table on those pages. The reader
looked at a plot, read values off the curves, and emitted them in the same markup it uses for a
transcribed table.

Two were confirmed against the scan by eye.

**Brutsaert, page 182.** The page carries body text and Figure 7.10, a log-log plot of
dimensionless evaporation rate against fetch, with two distinguishable lines. The output
contains a six-row table captioned "Estimated data points for Figure 7.10" with three columns,
one per line named in the caption, identical to each other on every row. The figure reads about
0.07 at the left edge and about 0.011 at the right; the invented table says 0.06 and 0.001.

**Sakai, page 50.** The page carries body text and Figure 3.8, trunk bark temperature against
time of day for four aspects. The output contains a table captioned "Estimated data points from
Figure 3.8" with a column per aspect.

| source | invented tables | rows |
|---|---|---|
| sakai1987 frost survival of plants | 35 | 708 |
| monahan1986 oceanic whitecaps | 21 | 282 |
| naldrett2004 magmatic sulfide deposits | 20 | 318 |
| farouki1981 thermal properties of soils | 16 | 150 |
| brutsaert1982 evaporation into the atmosphere | 15 | 553 |
| dunne1978 field studies of hillslope flow processes | 14 | 172 |
| the whole corpus, 57 sources | 255 | 3839 |

The tables are labelled honestly: every one says "estimated" and names the figure. That is the
only reason they were findable, and it is not a defence. They sit in the same `<table>` markup
as the transcribed tables, on pages whose text is otherwise a faithful read, and nothing
downstream distinguishes them. A search for a number lands on them exactly as it lands on a
real one.

This is not the pixel budget and raising the cap will not touch it. It is what the reader was
asked to do: `ocr_layout` returns the page as structured markdown, and a plot is structure it
can render as a table.

## What the shape screen found in the three books

Chapman and Cowling, Henderson and Brutsaert have no arithmetic identity to check, so their
tables were screened on shape instead: a row narrower than its neighbours, two adjacent columns
identical everywhere, a value breaking the smoothness of a smooth column. 46 flags over 147
tables, and most were header rows with spanning cells. `tools/references/audit_tables_by_shape.py`.

Two real defects came out of it, both in Henderson's page 142 to 143 spread, the worked example
of the standard step method.

**A duplicated column.** The printed table has fourteen numbered columns. Every data row in the
output has fifteen cells, the last one repeated. Column 5 and column 14 are both "Total head, H"
in the original, so the duplicate header is genuine and the duplicate value is not.

**Cancelled rows transcribed as data.** The method takes a trial water surface level and rules a
line through the whole row when the computed head disagrees with the assumed one. Four of the
thirteen rows on that page are struck through in print. All four appear in the output as
ordinary rows, with no strikethrough and nothing else to mark them, beside the accepted rows
that replaced them. The reader can produce strikethrough and does so on 31 other pages of the
corpus; here it did not.

That one was recoverable without re-reading: both cancelled and accepted rows are present and
correct, only unmarked. The four were marked and the duplicate column removed.

The test Henderson states in the facing text, that a line is ruled through when column 14 differs
from column 5, is not exact. Applied as written it marks a fifth row, mile 37.30 at stage 69.75,
which the page does not rule through: its residual is 0.02 ft and Henderson takes that as
converged. The strikethrough on the scan is the ground truth and the arithmetic is only a
candidate generator. Marking that fifth row would have asserted something the page does not say,
which is the failure this whole exercise is about.

Chapman's flags were all false: an index of symbols and page numbers read as a ragged table, and
a genuine jump in a column of molecular weights between krypton and xenon.

## What follows, and what does not

`ask.py` already states the standing rule: an answer names pages, and a value enters a record only
after the page is opened and the table named. So this corpus is a pointer, not a data path, and
that sorts the defects into two piles rather than fifty-seven.

**Repaired, because retrieval would otherwise assert something the page does not say.** The 255
invented tables are gone, each leaving a marker naming the figure it came from
(`tools/references/strip_invented_tables.py`). Henderson's four cancelled rows are marked and the
duplicated column removed.

**Not repaired, deliberately.** Every other damaged table in the corpus, including the 493 JANAF
pages. A garbled number in a table that is not a data path costs nothing, because the standing
rule already requires the page to be opened before the value is used. Re-reading three thousand
pages to fix numbers nobody may read is work with no claim on anyone.

The raised pixel cap stands for reads that have not happened yet. It is not a reason to redo the
ones that have.
