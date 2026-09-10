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

## What followed

The first resolution was wrong and is recorded here because the reasoning is the finding. It
said: repair what would make retrieval misquote a page, ignore what merely garbles a number,
because numbers do not come from the corpus. That treats a known-wrong number as harmless if a
rule downstream says not to use it. It is not harmless. A corpus that returns wrong numbers with a
page citation is worse than no corpus, and the rule downstream is a second check, not a licence
for the first one to lie.

The second resolution was also wrong, in shape: treat every scanned source as a data source, and
for each find a dataset, a born-digital copy, or re-read it. Most scanned sources are held for a
scheme or an argument. That framing sent out a request for 22 books and a search of a plant trait
archive for a book the model takes no numbers from.

The resolution that stands is mechanical. OCR prose came back faithful everywhere it was checked;
OCR tables did not, and a re-read at twice the pixel budget fixed four of seven wholly corrupt
pages and left the rest unverifiable. So no OCR'd table cell stays in the queryable text. Each
table becomes a marker carrying its caption, row count and page, the prose around it stays
searchable, and the scan is what a reader opens. 1889 tables on 1511 pages across 189 sources,
one pass, `tools/references/strip_ocr_tables.py`, and it runs as the last step of the reading
chain so a fresh read cannot bring them back. Sources with a real text layer are untouched.

Separately, and per constant rather than per book: where the data a scan carries has a
machine-readable home, that home is the input dataset. NIST-JANAF's tables are the NASA CEA
polynomials, 214 of whose records cite that book; Carmichael's rock spectra are ECOSTRESS and
USGS splib07, already held. Both scans are deleted from the text and kept as scans to open by eye.

The residual risk is a number garbled in OCR prose, which this does not touch. It is diffuse
rather than concentrated, the page-opening rule applies to it as to everything, and it is stated
here rather than claimed away.
