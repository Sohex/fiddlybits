# Retrieval when the question does not name the paper

Measured on 2026-09-10 with `tools/references/ask.py` against the 737-source index,
TabbyAPI serving the generator, the cross-encoder on the card. Five questions written
the way someone building the model would ask them: a law, a coefficient or a scheme is
wanted and the source is not known. This is the test that matters. An earlier set the
same day named the paper in the question, which makes the retrieval a lookup and proves
nothing.

| question | primary source found | wall |
|---|---|---|
| what controls silicate weathering drawdown with temperature and runoff | Berner 1983, Gaillardet 1999, Dessert 2003, Maher 2014 | 33 s |
| how much darker a soil gets when wet, across soil types | Post 2000, Twomey 1986, Nolet 2014 | 30 s |
| keeping tracer mass conserved across the pentagons of an icosahedral grid | none; ICON papers only, low scores | 29 s |
| what flow law and what exponent and activation energy for glacier ice | Glen 1955, Greve 2005, Bueler 2009 | 31 s |
| how mantle dissipation depends on temperature, and the tidal quality factor | none; Turcotte only, scores 3 and 3 | 26 s |

## What the claims check out against

Every number checked was on the page cited.

- Greve 2005 pages 44-46: `A0 = 3.985e-13`, `Q = 60 kJ/mol` for `T <= 263.15 K`, and
  `A0 = 1.916e3`, `Q = 139 kJ/mol` for `T >= 263.15 K`. Reported exactly.
- Post 2000 page 5: wet albedo reduced 32 to 58 percent, mean 45 percent; the Pima soil
  0.220 dry and 0.115 wet, a 48 percent reduction. Reported exactly, including the soil.
- Dessert 2003 page 6: `fw = Rf x 18.41 exp(0.0553 T)`. Reported exactly, and this one is
  worth its own line below.

The ice question is the strongest result. Asked without a name, it returned Glen's 1955
measurement of about 3.2, the value 3 that models actually use, the Arrhenius rate factor
and both activation energies, from four sources that agree. That is the shape an answer
should have: the primary measurement, the modelling convention, and the distance between
them.

## The two that found nothing said so

Neither gap produced an invented answer. On pentagons the reply states that the texts
"do not detail a unique, distinct mechanism for handling tracer mass specifically across
pentagons"; on tidal dissipation, that the material "does not explicitly describe the
mathematical dependence of dissipation on temperature or define the tidal quality factor".
Evidence scores tell the same story from outside the text: 8 to 10 where the archive holds
the source, 2 to 6 where it does not. A low top score is the signal that the archive, not
the retrieval, is what came up short.

## What the Dessert check turned up instead

The coefficients did not appear on a first search of the paper, which looked like a
fabricated citation. They are there. The extraction renders the line as

    fw ¼ Rf  18:41 expd0:0553 T P

with the equals sign as a vulgar fraction, the decimal points as colons and the
parentheses as eth and thorn. 89 of 736 papers carry that substitution, 41 of them with
the decimal corruption appearing more than five times. `extract_text.py` exists so that
`rg` across the archive is a page-cited search, and on those 89 a search for a coefficient
or an exponent returns nothing. The model read through it correctly; a grep does not, and
neither does a person transcribing a constant. Filed separately with the list.

## Also fixed here

Registering the Heikes Part II scan in `references/pdf` with no text yet killed the first
query outright: PaperQA re-raises anything that is not `ValueError` or
`ImpossibleParsingError`, and the parser was raising `FileNotFoundError`. It now raises
the parsing error, so an unread scan is skipped with a warning and the query runs. The
file was also left marked ERROR in the index, which `--build` would have swept into its
adopt branch and written off as read, so an ERROR entry is now always treated as stale.
