# OCR quality: Chandra OCR 2 against the tesseract text layer, on scanned primary sources

Measured on 2026-09-08 on five pages rendered at 300 dpi from held PDFs whose text layer
came from OCR (tesseract 5 through ocrmypdf), compared against the page images read by
eye. Chandra OCR 2 (Datalab, `/home/cfutro/models/chandra-ocr-2`, Qwen3.5-based vision
model, bf16 on the RTX 4090 via transformers, `tools/references/chandra_ocr.py`).

## What was found

- **Stefan 1891, p. 274 (German, two displayed equations, signed decimals).** Tesseract
  dropped the first equation entirely and rendered the second as
  `A% (1 + g) h, ( 1 + g ) = 2x / la ( T - T I )`; it read "84 Zoll" as "84 2011" and
  "-1,2" as "- 1 2". Chandra returned both equations as LaTeX, exactly as printed
  (`h_1^2 (1 + cf_1/3\lambda) = 2KT_1/\lambda\sigma` and the difference form), and every
  number and unit correctly.
- **Courant, Friedrichs and Lewy 1928, p. 36 (German, difference operators, two Green
  formulas, the five-point Laplacian).** Tesseract produced noise for every displayed
  expression (`u ~ u,~-~+ uu9`, `h ~ Z ~ : (u~ + u~) = - - h ' Z Z u A u`). Chandra
  returned `\Delta u = u_{x\bar{x}} + u_{y\bar{y}}`, both Green formulas with their
  sums over `G_h`, `G'_h` and `\Gamma_h`, and the stencil
  `\Delta u = \frac{1}{h^2}\{u(x+h,y) + u(x,y+h) + u(x-h,y) + u(x,y-h) - 4u(x,y)\}`,
  all matching the page.
- **Glen 1955, p. 520 (English prose with mid-dot decimals).** Before this pass the page
  had no OCR text at all: the publisher's "Downloaded from" watermark counted as an
  existing text layer and `ocrmypdf --skip-text` left the scan alone. The same trap had
  silenced Penman 1948 (27 of 29 pages) and Stephens 1978 (all 10 pages); a per-page
  sweep of the whole archive found those three files and 505 thin pages in total, the
  rest being figure-only pages. The three were re-OCR'd by rasterising and running
  tesseract directly. Chandra read the page's prose and its mid-dot decimals correctly.
- **Sasamori 1968, p. 723 and Held and Hou 1980, p. 518 (two-column with figures).**
  Both engines read the prose; Chandra kept column order and figure captions in place.

## Cost

Chandra through transformers, one page per call: 24 to 57 s per page (longer pages
slower), model load 3 s, about 10 GB of GPU memory. The archive's 63 OCR-layered files
hold 1,846 pages (`tools/references/ocr_layer_files.txt`), so a single-page pass is
about 15 hours single-page. Measured on the same eight pages: transformers batched
4 at a time, 23.4 s per page at 16 GB peak (batch 8 exhausted the card); vLLM 0.28
(`tools/references/serve_chandra_vllm.sh`, 75 percent of the card, 16 sequences), 19.7 s
for one page alone and 4.9 s per page at batch 8, with output identical to the
transformers path on the Courant page (nine display equations, no difference). The
full pass therefore runs through vLLM (`tools/references/chandra_pages.py --method
vllm`), about 2.5 hours for the 1,846 pages. Files with a native publisher text layer are not re-OCR'd: their layers
are exact and Chandra would only add cost.

## Decision

For the 63 OCR-layered files, the per-page text under `references/text/` is replaced
by Chandra's Markdown (equations as LaTeX), with the manifest recording the engine per
file, so that search and PaperQA2 see the equations rather than noise. The PDFs keep
their tesseract layers for viewer search. The rule stands: a value is taken from the
opened page; the text layer is for finding it.

The watermark trap is added to the ingest rule: coverage is checked per page, never
by a file's first pages in aggregate.

## Addendum: publishers' text layers on scanned originals

A text layer on a PDF is not evidence that the text is good. Of the 631 held files that
never went through this project's OCR, 155 are scanned originals, detected by the only
reliable sign (a page that is one full-page raster: `tools/references/detect_scans.py`,
first 30 pages, at least 60 percent of pages), and their layers are the publishers' OCR
from older engines. The one-letter-token rate exposes the worst of them as
character-spaced junk (Rothermel 1972 at 79 percent of tokens, Kahan 1965 and Stommel
1948 at 52 percent, the Carmichael rock-properties handbook at 43 percent), and none of
them carries equations. A dictionary out-of-vocabulary rate was tried and rejected as a
signal: it flags German and French primary sources for being German and French.

Policy: every scanned original dated 2004 or earlier (147 files, 7,258 pages) plus the
SIAM reprint of Cottle et al. (a scan) is re-read by Chandra through the same recipe
(`tools/references/scanned_native_layer_files.txt`); born-digital papers with full-page
figures, which the raster test also flags, keep their exact publisher layers. Font
inspection cannot separate the two cases, because publishers embed OCR text invisibly
under ordinary font names.

## Addendum: the first replacement pass, complete

All 63 files that carried this project's own tesseract layer are now read by Chandra
(1,846 pages, `engine = chandra-ocr-2` in `references/text/manifest.jsonl`). The pass
crashed once on a page whose declared size at 300 dpi exceeded Pillow's decompression
limit; the recipe now renders every page to a bounded long side (3,300 pixels) instead
of a fixed dpi, so a page's declared physical size no longer decides the raster. The
per-page coverage sweep over the Chandra output flags 16 pages under 200 characters,
and each one was opened: the Dupuit facsimile's blank leaves and plates, the Dunne
chapter's cover scan and a figure page, and one Anderson figure page. None carries text.
Throughput while the GPU was shared with another job fell to 0.14 pages per second,
against 0.2 when the server had the card to itself.
