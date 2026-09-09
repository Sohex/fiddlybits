# References

`INDEX.md` is tracked. `references/pdf/` at the repository root is untracked pure
payload named `<firstauthor><year><suffix>-<slug>.pdf`, so the directory can be
linked whole into any worktree.

Each row: filename, verbatim published title, identifier (DOI where one exists,
otherwise a stable locator: ISBN, handle, ADS bibcode, publisher record), status,
and anchors.

- **read**: someone here opened the paper and took a number or a scheme from it,
  and the anchor names where.
- **held**: on disk, cited, not yet read for a number. An open exposure, not a
  resource.
- **requested**: listed in `REQUESTS.md` for the user to fetch. Only paywalled works
  reach that list: when an identifier is confirmed, an OpenAlex or Unpaywall lookup
  says whether an open-access copy exists, and open-access papers and datasets are
  fetched directly (arXiv, Copernicus journals, PMC, publisher OA pages, public data
  buckets) through the same ingest path.

A row with no anchor is flagged. A `Sourced` parameter or an oracle bar whose
reference is not `read` is refused. Confirm an identifier resolves to the intended
work before requesting it; a guessed DOI resolves to a real wrong paper and nothing
says so.

## Ingest

A fetched file is identified by its first pages (never by its filename alone),
renamed to the convention, moved from `requested` to `held` in `INDEX.md`, and
removed from `REQUESTS.md`. A PDF with no text layer gets one by OCR at ingest, and
coverage is checked PER PAGE afterwards, never by a file's first pages in aggregate:
a publisher watermark counts as text and makes `ocrmypdf --skip-text` leave a whole
scan alone (Glen 1955, Penman 1948 and Stephens 1978 were silenced that way). A
page with an image and under 150 characters is re-OCR'd by rasterising and running
tesseract directly. A scanned original is detected by its pages being full-page
rasters (`tools/references/detect_scans.py`), never by the absence of a text layer:
publishers' layers on scans are OCR too. For scanned primary sources the per-page
text under `references/text/` is then replaced by Chandra OCR 2 output (equations as LaTeX;
`tools/references/chandra_pages.py`, engine recorded in the text manifest), because
tesseract turns displayed equations into noise
(`notes/findings/2026-09-08-ocr-chandra-vs-tesseract.md`). Files with a native
publisher text layer keep it. A scan identified only by elimination says so in
its index row. A dataset is not a paper: it goes under `oracles/data/<id>/`
(untracked) with a TOML manifest at `docs/oracles/data/<id>.toml` listing every file
by size and sha256, and its index row points at the manifest.

## Instruments

Two search instruments sit over the held papers. Both return locators, never
values: a number or a scheme still enters a record only after the page is opened and
the table or equation is named in its `Sourced` disposition. An answer synthesised by
a model from retrieved passages is a secondhand citation, the predecessor's failure
class 9, and is never cited.

- **Full text, page-cited.** `tools/references/extract_text.py` writes every page of
  every held PDF to `references/text/<stem>/<page>.txt` (untracked, manifested by
  sha256 and extraction mode, incremental). Text comes out in reading order, never in
  page layout: laying text out by position puts both columns of a two-column paper on
  one line, so a sentence is interrupted mid-clause by an unrelated one, which the
  page-cited grep survives and the embedding and evidence instruments do not
  (`notes/findings/2026-09-09-text-extraction-layout.md`). A paper whose tables carry
  the values is read by `chandra_pages.py` instead, which returns table markup rather
  than aligned whitespace, and a paper read that way is never re-extracted here. `tools/references/search.py "words"` prints
  `file | p.N | line` hits. This is the first reach; it costs nothing.
- **PaperQA2, evidence with page citations.** `tools/references/ask.py --build`
  indexes the PDFs into `references/index/` (untracked) with a manifest generated
  from `INDEX.md` so citations carry the verbatim title and identifier; the index is
  derived and disposable, and is deleted rather than kept whenever the corpus beneath
  it changes, so nothing on disk can be mistaken for current;
  `ask.py "question"` gathers page-cited evidence and, unless `--evidence-only`,
  a synthesised pointer. Configuration in `tools/references/paperqa.toml`: Qwen3-Embedding-8B
  from `/home/cfutro/models` (chosen by the A/B/C in
  `notes/findings/2026-09-08-embedding-model-ab.md`) and a local model served by
  `serve_llm.sh` under `qrun`
  on one GPU share, or an Anthropic model with the key read from `~/.anthropic_key`
  at call time. The second reach; it spends model calls. The local model is quantized to fit
  the card; `tools/references/calib/` builds its calibration set from this archive
  and PaperQA2's own prompts, which suits it to the job better than a general corpus.
  Retrieval can pull a broader set and hand it to a cross-encoder that keeps the best
  `evidence_k` (`rerank.py`, configured in `paperqa.toml`): a bi-encoder scores a page
  against a vector built without the query, which is weak at separating a page that
  states a result from one that cites it. The stage is off until `rerank_ab.py` says
  which reranker, since only 0.6B at fp16 and 4B at int8 fit beside the generator.
- **One document per held PDF, everywhere.** The page-text corpus is one directory
  per PDF and the index manifest is one row per PDF, so a work cannot enter either
  instrument twice; a work held in two versions is two rows on purpose and says so
  in its remarks. After any OCR pass, rebuild the index with `ask.py --rebuild`
  rather than `--build`: staleness is keyed on the PDF, whose bytes a re-read does
  not change, so an incremental build would answer from a mixture of the old text
  layer and the new one. `references/text/manifest.jsonl` is append-only and its
  last entry per file wins, which is how a Chandra pass supersedes an earlier
  extraction without the pages being written twice.

## Environments and models

The instruments and the data recipes run in two tool environments outside the tree
(`~/.venvs/fiddlybits-tools`, `~/.venvs/chandra-vllm`); `tools/references/setup.sh`
rebuilds both from the tracked `requirements-tools.txt` and
`requirements-chandra-vllm.txt`. Models are fetched by repository id into `~/models`
per `tools/references/models.toml`; they are replaceable by name and are not kept in
the tree. Datasets are the opposite: every one is physically under `oracles/data/` or
`inputs/data/` with a hashed manifest, because some of them are far harder to fetch
than a model.
