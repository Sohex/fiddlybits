# The page-text corpus had two layouts, and one of them interleaved the columns

Measured on 2026-09-09 on the held papers, after asking how the text under
`references/text/` is produced for papers this project read with a model and for papers
that arrived with a usable text layer of their own.

Two paths write into the same directory tree. `tools/references/extract_text.py` runs
poppler's text extractor per page for a paper whose own layer is good;
`tools/references/chandra_pages.py` renders the page and has a model read it, returning
markdown with real table markup, for a scan or a bad layer. Both write
`references/text/<stem>/<page>.txt` and both record themselves in the same manifest.

The extractor was running with the layout flag, which lays text out by its position on
the page. On a two-column paper that puts both columns on the same output line:

> cloud type i, u and d denote cumulus updrafts and     several advantages over the
> advective form often used:

A sentence from the left column is interrupted mid-clause by an unrelated sentence from
the right. On a random sample of twelve papers with their own layer, measuring the share
of non-empty lines carrying a run of four or more spaces between two words, which is the
signature of side-by-side columns:

| extraction mode | share of lines with columns side by side |
|---|---|
| layout | 0.38 |
| reading order | 0.00 |

Reading order also rejoins a word broken by a hyphen at a line end, which the layout mode
leaves split.

The flag's usual defence is that it preserves the alignment of a table. On these papers it
does not, and the reason is worth recording: a two-column page aligns the *page's*
columns, so a table in one column is interleaved with the prose in the other. On the
worked example the table's rows came out one per line in reading order and interleaved
with prose under the layout flag, which is the opposite of the intended effect. A paper
whose tables carry the values is read by the model path instead, which returns table
markup rather than aligned whitespace.

## Why it mattered

For the page-cited grep this is cosmetic: the words are all present either way. For the
two instruments that consume the text as prose it is not. An embedding of a page chunk
mixes two unrelated passages, and a retrieved quotation reads as nonsense in a way that
looks like an extraction failure rather than a layout choice. About three quarters of the
held papers were extracted this way.

## What changed

The extractor takes a mode, defaults to reading order, and records the mode it used in
the manifest, so a paper is re-extracted when its bytes change or when the mode it was
extracted under is not the one asked for. It never touches a paper whose manifest entry
names the model as its engine, so a re-extraction cannot overwrite a page that was read.

The index the second instrument builds must be rebuilt from the corrected text, which it
needed anyway after the reading passes: see the rebuild rule in
`docs/references/README.md`.
