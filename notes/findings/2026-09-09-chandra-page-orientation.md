# Chandra reads sideways pages, and loses a column doing it

Measured on 2026-09-09 against the live Chandra server (`chandra-ocr-2` under vLLM), on the
scanned fourth edition of the NIST-JANAF Thermochemical Tables, whose data pages carry an
upright running head over a body and table printed at a quarter turn.

Three pages were read twice, once as the page was scanned and once turned upright, with
nothing else changed:

| page | as scanned | turned upright |
|---|---|---|
| a liquid-phase data page | 6,948 characters, 1,400 digits | 7,017 characters, 1,385 digits |
| an ideal-gas data page | 12,299 characters, 2,654 digits | 13,199 characters, 3,011 digits |
| an ion data page | 11,947 characters, 2,517 digits | 12,613 characters, 2,913 digits |

Volume alone would not settle it, so the ideal-gas page was checked against the printed
table. Its last row is eight cells wide. Read as scanned, the model returned seven: the
enthalpy column was missing from every row, and the table was one row short. Read upright,
the row matched the page exactly. The loss is silent: the output is well-formed, the numbers
present are correct, and nothing marks the absent column.

That is the failure to guard against. A sideways table does not produce garbage that a
coverage check would catch; it produces a smaller correct-looking table.

## The detector

Orientation is decided per page by the quarter turn tesseract reads with the most total word
confidence, on a downscaled centre crop. The crop matters: on these pages the running head
points the other way from the body, and the body is what must come up.

That test is reliable about the axis and can still mistake a quarter turn for its opposite.
On a sample of eight pages it placed seven correctly and turned one the wrong way, so the
recipe snaps a page that does not prefer its own direction to the direction the rest of the
file turned. With snapping the same sample is eight of eight, and four upright pages from
four other papers stay upright, which is the control that matters: a detector that turns a
good page is worse than none.

Cost is a third of a second per page across eight threads, against about four seconds per
page of reading, so orientation is a few percent of the pass.

## What this changes

`tools/references/chandra_pages.py` turns pages upright before reading them, and records how
many turned in the extraction manifest. Passes 1 and 2 ran without it, so their files were
read as scanned; the ones with turned pages are re-read afterwards. Nothing that came out of
those passes is wrong in what it says, but a rotated table page may be missing a column.
