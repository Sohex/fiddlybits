#!/usr/bin/env python
"""PaperQA2 over the held papers: evidence with page citations.

    tools/references/ask.py --build                      # index whatever the index does not hold at its current text
    tools/references/ask.py --reingest henderson1966     # drop one source and read it again, after re-OCR
    tools/references/ask.py --rebuild                    # discard the index entirely; rarely what you want
    tools/references/ask.py --relabel                    # re-apply the manifest's citations to what is already indexed
    tools/references/ask.py "How does Millero 1995 give the pressure dependence of K1?"
    tools/references/ask.py --evidence-only "..."       # gathered passages with page numbers, no synthesised answer

Reads tools/references/paperqa.toml. Every answer is printed with its sources as <file> p.<page>: quote.
The answer text is a pointer to pages, not a source: a value or scheme enters a record only after the page is
opened and the table or equation is named (docs/references/README.md).

--build is incremental and is what to run after an OCR pass. PaperQA decides staleness on the file name alone,
and a re-read paper keeps its name, so ask.py keeps its own record: references/index/text-digests.toml holds a
sha256 of the extracted text behind each indexed PDF. A source whose text no longer matches its digest is
dropped from the index and read again; one that matches is left alone; one the index has never seen is added.
--reingest forces a named source through that regardless, for when the text is unchanged but the chunking or
the embedding model is not. --rebuild discards everything, which is now rarely the right tool.

The index manifest is generated from docs/references/INDEX.md so citations carry the verbatim title and
identifier the index holds. A citation is stored with the chunks it belongs to, so a correction in INDEX.md
reaches an already-indexed source only through --relabel, which rewrites the label and nothing else.
"""
import argparse, asyncio, csv, hashlib, os, pathlib, re, shutil, sys, tomllib
ROOT = pathlib.Path(__file__).resolve().parents[2]
CFG = tomllib.loads((ROOT / 'tools' / 'references' / 'paperqa.toml').read_text())
_EMBEDDING = None   # the one embedding model of this process; see S.get_embedding_model below

def instructed_st_class():
    """Sentence-transformers embedding with query/document modes for instruction-aware models (Qwen3-Embedding):
    left padding, fp16 on the GPU when enough memory is free, bf16 on CPU otherwise; queries get the retrieval
    instruction, documents do not; vectors normalised. Built lazily so `--build` and a single query pay only what they use.

    It subclasses lmi's EmbeddingModel rather than merely matching its shape. Indexing calls the embedder
    directly and a duck type survives that, but PaperQA builds its tools as pydantic models with a typed
    embedding_model field, so a query is refused before it reaches the index unless this is the declared type.
    The class is built inside this function, not at import, so that only the paths that embed anything pay for
    importing lmi.
    """
    from pydantic import ConfigDict, PrivateAttr
    from lmi.embeddings import EmbeddingModel, EmbeddingModes

    class InstructedSTEmbedding(EmbeddingModel):
        model_config = ConfigDict(arbitrary_types_allowed=True)
        path: str
        instruction: str = ''
        kind: str = 'qwen3'
        max_seq: int = 2048
        _m: object = PrivateAttr(default=None)
        _dev: str = PrivateAttr(default='')
        _mode: EmbeddingModes = PrivateAttr(default=EmbeddingModes.DOCUMENT)

        def _model(self):
            if self._m is None:
                import torch
                from sentence_transformers import SentenceTransformer
                free = torch.cuda.mem_get_info()[0] / 2**30 if torch.cuda.is_available() else 0
                want = CFG.get('embedding_device', 'auto')
                dev = want if want in ('cuda', 'cpu') else ('cuda' if free > 18 else 'cpu')
                # Announced, never silent: an 8B embedder on the CPU is about fifty times slower, and the only sign
                # is a warm card doing nothing. Whichever way this goes, it says so once and says why.
                print(f'embedding model on {dev} ({free:.1f} GiB free on the card, threshold 18; '
                      f'embedding_device={want})', file=sys.stderr, flush=True)
                dt = torch.float16 if dev == 'cuda' else torch.bfloat16
                mk = {'torch_dtype': dt, 'low_cpu_mem_usage': True}
                if dev == 'cuda': mk['device_map'] = 'cuda'   # load shards straight onto the card; no 16 GB host copy
                kw = dict(model_kwargs=mk, device=dev)
                if self.kind == 'qwen3': kw['tokenizer_kwargs'] = {'padding_side': 'left'}
                if self.kind == 'jina': kw['trust_remote_code'] = True
                self._m = SentenceTransformer(self.path, **kw); self._m.max_seq_length = self.max_seq; self._dev = dev
            return self._m
        def set_mode(self, mode): self._mode = mode
        async def embed_documents(self, texts):
            import asyncio
            m = self._model(); q = self._mode == EmbeddingModes.QUERY
            if self.kind == 'qwen3' and q: texts = [f'Instruct: {self.instruction}\nQuery:{t}' for t in texts]
            extra = {'task': 'retrieval', 'prompt_name': 'query' if q else 'document'} if self.kind == 'jina' else {}
            bs = 4 if (self.kind == 'qwen3' and self._dev == 'cuda') else 16
            out = await asyncio.to_thread(lambda: m.encode(texts, batch_size=bs, normalize_embeddings=True, convert_to_numpy=True, show_progress_bar=False, **extra))
            return out.tolist()

    return InstructedSTEmbedding


def embedding_from_config():
    """The one embedder paperqa.toml names, built once for the life of the process.

    PaperQA asks for an embedding model once per document (paperqa/docs.py aadd_texts), so handing back a fresh
    one loaded the 15 GB model 736 times: the first landed on the card, and every later one found too little
    free VRAM and went quietly to the CPU. The card sat full and idle while the build crawled. Measured 2026-09-09.
    """
    global _EMBEDDING
    if _EMBEDDING is None:
        _EMBEDDING = instructed_st_class()(
            name=CFG['embedding_path'], path=CFG['embedding_path'],
            instruction=CFG.get('query_instruction', ''), kind=CFG.get('embedding_kind', 'qwen3'),
            max_seq=CFG.get('max_seq', 2048))
    return _EMBEDDING


def parse_from_extracted_text(path, page_size_limit=None, page_range=None, **kwargs):
    """PaperQA2 parser that reads the per-page text extracted by tools/references/extract_text.py instead of
    re-parsing the PDF: the OCR layers are already the text, and pypdf on 700-page scans was the build's bottleneck."""
    from paperqa.types import ParsedText, ParsedMetadata
    from paperqa.utils import ImpossibleParsingError
    import paperqa
    stem = pathlib.Path(path).stem; d = ROOT / 'references' / 'text' / stem
    # A PDF registered but not yet read is a normal state: a scan waits on the OCR chain, and the chain reads from
    # references/pdf, so the file has to sit there first. PaperQA marks such a file failed and moves on only for
    # ImpossibleParsingError and ValueError; anything else it re-raises, which killed the whole query rather than
    # skipping one source. It cannot be parsed yet, so that is what this says.
    if not d.is_dir():
        raise ImpossibleParsingError(
            f'no extracted text for {path}; run tools/references/extract_text.py, '
            f'or tools/references/ocr_read_chain.sh if it is a scan')
    # A source whose data has a machine-readable home keeps a one-page stub naming that home instead of its text,
    # so a query for the quantity lands on the pointer rather than on a number a reader transcribed from a scan.
    content = {}
    for f in sorted(d.glob('*.txt')):
        n = int(f.stem)
        if page_range and isinstance(page_range, tuple) and not (page_range[0] <= n <= page_range[1]): continue
        t = f.read_text(errors='ignore')
        if page_size_limit and len(t) > page_size_limit: t = t[:page_size_limit]
        if t.strip(): content[str(n)] = t
    return ParsedText(content=content, metadata=ParsedMetadata(parsing_libraries=['pdftotext (poppler) via tools/references/extract_text.py'], paperqa_version=paperqa.__version__, total_parsed_text_length=sum(len(t) for t in content.values()), name=f'extracted-text:{stem}'))

def manifest(paper_dir, index_dir):
    rows = {}
    for l in (ROOT / 'docs' / 'references' / 'INDEX.md').read_text().splitlines():
        m = re.match(r'\| `([^`]+\.pdf)` \| (.+?) \| (.+?) \| (read|held|requested) \| (.*?) \|', l)
        if m: rows[m.group(1)] = (m.group(2).replace('"', "'"), m.group(3).strip('`'))
    index_dir.mkdir(parents=True, exist_ok=True); mf = index_dir / 'manifest.csv'
    with open(mf, 'w', newline='') as f:
        # citation and docname supplied here so Docs.aadd never asks the language model for either during indexing.
        # KEEP is the one column that makes PaperQA honour them. Every manifest row is passed through
        # DocDetails before Docs.aadd sees it, and that validator rebuilds the bibtex of any row that carries
        # none -- which a manifest row never does -- and then, for each field named in
        # fields_to_overwrite_from_metadata, replaces what the row said with what it just built. The default
        # names citation, key and docname, so the verbatim citation below arrived as "Unknown authors. <title>.
        # Unknown journal, Unknown year." with a docname to match. Naming only the fields PaperQA has to fill
        # for itself leaves the three this manifest is for alone.
        KEEP = 'doc_id,dockey,content_hash'
        w = csv.writer(f)
        w.writerow(['file_location', 'doi', 'title', 'citation', 'docname', 'fields_to_overwrite_from_metadata'])
        for p in sorted(paper_dir.glob('*.pdf')):
            title, ident = rows.get(p.name, (p.stem, ''))
            doi = ident if re.match(r'10\.\d{4,}/', ident) else ''
            # One period between the parts, whether or not the INDEX.md row already ended in one.
            citation = '. '.join(x.rstrip('.') for x in (title, ident) if x) + f'. [{p.name}]'
            # The stem is the docname because it is the handle an answer is checked against: evidence prints as
            # <file> p.<page>, and the file is what a reader opens.
            w.writerow([p.name, doi, title, citation, p.stem, KEEP])
    return mf
def settings(evidence_only=False):
    from paperqa import Settings
    from paperqa.settings import AgentSettings
    key = pathlib.Path.home() / '.anthropic_key'
    if CFG['llm'].startswith('anthropic/') and key.is_file(): os.environ.setdefault('ANTHROPIC_API_KEY', key.read_text().strip())
    if CFG['llm'].startswith('openai/'): os.environ.setdefault('OPENAI_API_KEY', 'local')
    # enable_thinking rides through litellm as extra_body; it has to match how the local
    # model was calibrated (paperqa.toml, thinking)
    _params = {'model': CFG['llm'], 'api_base': CFG.get('api_base'), 'api_key': os.environ.get('OPENAI_API_KEY', 'local'), 'temperature': 0.0}
    if 'thinking' in CFG: _params['extra_body'] = {'enable_thinking': bool(CFG['thinking']), 'chat_template_kwargs': {'enable_thinking': bool(CFG['thinking'])}}
    llm_cfg = {'model_list': [{'model_name': CFG['llm'], 'litellm_params': _params}]} if CFG['llm'].startswith('openai/') else None
    paper_dir = ROOT / CFG['paper_directory']; index_dir = ROOT / CFG['index_directory']
    mf = manifest(paper_dir, index_dir)
    class S(Settings):
        def get_embedding_model(self):
            if CFG.get('embedding_path'): return embedding_from_config()
            return super().get_embedding_model()
    s = S(llm=CFG['llm'], summary_llm=CFG['summary_llm'], embedding=CFG['embedding'], temperature=0.0,
                 llm_config=llm_cfg, summary_llm_config=llm_cfg,
                 agent=AgentSettings(index=dict(paper_directory=str(paper_dir), index_directory=str(index_dir), manifest_file=str(mf), concurrency=1, batch_size=1), agent_llm=CFG['llm'], agent_llm_config=llm_cfg))
    s.answer.evidence_k = CFG.get('evidence_k', 12); s.answer.answer_max_sources = CFG.get('answer_max_sources', 6)
    s.parsing.reader_config = {'chunk_chars': CFG.get('chunk_chars', 4000), 'overlap': CFG.get('overlap', 200)}
    s.parsing.multimodal = False   # text only; the OCR layers are the text
    s.parsing.parse_pdf = parse_from_extracted_text
    s.parsing.use_doc_details = False   # no network lookups of metadata; the manifest carries title and DOI
    return s
def text_digest(stem):
    """A source's extracted text as one hash: every page file, in page order, name and bytes. This is what the
    index is stale against. PaperQA decides staleness on the file name alone (its process_file calls filecheck
    without a body hash), and the name never changes when a paper is read again, so without this a rebuild from
    scratch was the only way to pick up new text."""
    d = ROOT / 'references' / 'text' / stem
    h = hashlib.sha256()
    for f in sorted(d.glob('*.txt'), key=lambda x: x.name):
        h.update(f.name.encode()); h.update(f.read_bytes())
    return h.hexdigest()

def digest_path():
    return ROOT / CFG['index_directory'] / 'text-digests.toml'

def load_digests():
    p = digest_path()
    return tomllib.loads(p.read_text())['digest'] if p.is_file() else {}

def save_digests(d):
    p = digest_path(); p.parent.mkdir(parents=True, exist_ok=True)
    body = '\n'.join(f'"{k}" = "{v}"' for k, v in sorted(d.items()))
    p.write_text('# sha256 of the extracted text behind each indexed PDF, written by ask.py --build.\n'
                 '# A source whose digest here differs from its text on disk is dropped from the index and read\n'
                 '# again; one whose digest matches is left alone. Delete a line to force that source to be\n'
                 '# re-ingested, or use --reingest.\n\n[digest]\n' + body + '\n')

async def build(fresh=False, reingest=()):
    """Index whatever the index does not already hold at its current text. Nothing else is touched."""
    from paperqa.agents.search import SearchIndex, get_directory_index
    os.environ.setdefault('PQA_INDEX_ENABLE_PROGRESS_BAR', '1')   # the bar is CLI-gated upstream; this is a CLI
    if fresh:
        d = ROOT / CFG['index_directory']
        if d.exists(): shutil.rmtree(d); print('removed', d)
    s = settings()
    pdfs = sorted((ROOT / CFG['paper_directory']).glob('*.pdf'))
    forced = set()
    for r in reingest:
        stem = pathlib.Path(r).stem
        hits = [p for p in pdfs if p.stem == stem or stem in p.stem]
        if not hits: sys.exit(f'--reingest {r}: no PDF matches')
        forced.update(p.name for p in hits)
    on_disk = {p.name: text_digest(p.stem) for p in pdfs}
    stored = {} if fresh else load_digests()

    if not fresh:
        idx = SearchIndex(fields=[*SearchIndex.REQUIRED_FIELDS, 'title', 'year'],
                          index_name=s.agent.index.name or s.get_index_name(),
                          index_directory=s.agent.index.index_directory)
        index_files = await idx.index_files
        indexed = set(index_files)
        # A file PaperQA failed to parse is recorded under the name with ERROR for its hash. It is listed, so it is
        # not new, and it carries no digest, so without naming it here it would fall into adopt below and be
        # written off as read. That is how a scan queued for OCR would silently never be indexed once it was read.
        errored = {n for n, h in index_files.items() if h == 'ERROR'}
        stale = [n for n in indexed if n in forced or n in errored or stored.get(n) != on_disk.get(n)]
        # An indexed file with no digest recorded predates this bookkeeping; adopt its current text rather than
        # reading the whole archive again to learn what it already knows.
        adopt = [n for n in stale if n not in forced and n not in errored and n not in stored]
        stale = [n for n in stale if n not in adopt]
        for n in adopt: stored[n] = on_disk[n]
        if adopt: print(f'adopted the current text of {len(adopt)} already-indexed sources')
        for n in stale:
            await idx.remove_from_index(n); stored.pop(n, None)
        if stale: await idx.save_index()
        new = [p.name for p in pdfs if p.name not in indexed]
        print(f'{len(indexed)} indexed, {len(new)} new, {len(stale)} changed or forced'
              + (f' ({", ".join(sorted(stale)[:3])}{" ..." if len(stale) > 3 else ""})' if stale else ''))
        if not new and not stale:
            save_digests(stored); print('nothing to do'); return

    idx = await get_directory_index(settings=s)
    save_digests({**stored, **{n: h for n, h in on_disk.items() if n in set(await idx.index_files)}})
    print('indexed', len(await idx.index_files), 'files')
async def relabel():
    """Rewrite the citation and docname of every indexed source from the manifest, in place.

    A source's citation is stored in the index alongside its chunks, so a source already indexed keeps whatever
    citation it was indexed with; correcting the manifest does nothing until the index is written to. This reads
    each stored record, replaces those two fields with what the manifest now says, and writes it back. Nothing is
    re-read, re-chunked or re-embedded, so no model is loaded and the text and its vectors are untouched: this is
    a relabelling, and the only thing it can change is what a citation says."""
    import pickle, zlib
    from paperqa.agents.search import SearchIndex
    s = settings()   # regenerates the manifest first, so the labels applied are the current ones
    rows = {r['file_location']: r for r in csv.DictReader((ROOT / CFG['index_directory'] / 'manifest.csv').read_text().splitlines())}
    idx = SearchIndex(fields=[*SearchIndex.REQUIRED_FIELDS, 'title', 'year'],
                      index_name=s.agent.index.name or s.get_index_name(),
                      index_directory=s.agent.index.index_directory)
    files = await idx.index_files
    if not files: sys.exit(f'no index at {await idx.index_directory}; nothing to relabel')
    docs_dir = pathlib.Path(str(await idx.docs_index_directory))
    changed = missing = 0
    for loc, filehash in sorted(files.items()):
        row = rows.get(loc); rec = docs_dir / f'{filehash}.{idx.storage.extension()}'
        if not row or filehash == 'ERROR' or not rec.is_file():
            missing += 1; continue
        obj = pickle.loads(zlib.decompress(rec.read_bytes()))
        touched = False
        for doc in obj.docs.values():
            if (doc.citation, doc.docname) == (row['citation'], row['docname']): continue
            was = doc.docname
            doc.citation, doc.docname = row['citation'], row['docname']
            # A chunk is named "<docname> pages 3-5" and that name is what the evidence lines print, so the
            # chunks are renamed with the doc rather than left pointing at the name it no longer has.
            for t in obj.texts:
                if t.name.startswith(was): t.name = row['docname'] + t.name[len(was):]
            touched = True
        if not touched: continue
        obj.docnames = {d.docname for d in obj.docs.values()}
        rec.write_bytes(zlib.compress(pickle.dumps(obj)))
        changed += 1
    print(f'relabelled {changed} of {len(files)} indexed sources'
          + (f'; {missing} had no manifest row or no stored record' if missing else ''))
async def ask(q, evidence_only):
    from paperqa import Docs
    from paperqa.agents.search import get_directory_index
    s = settings(evidence_only); idx = await get_directory_index(settings=s, build=False)
    import rerank
    rr = rerank.from_config()
    docs = rerank.reranked_docs_class(rr, CFG.get('rerank_fetch_k', 50))() if rr else Docs()
    # gather across the whole index rather than an agent loop: deterministic, cheaper, and every source is page-cited
    from paperqa.agents.main import agent_query
    # agent_query takes the query and the settings directly; the QueryRequest wrapper this was written against
    # does not exist in the pinned paperqa. agent_type='fake' is what makes the comment above true: it runs
    # search, gather and answer in that fixed order instead of letting a tool-selecting loop choose. It is also
    # the only path that runs, because the ToolSelector agent reaches for LiteLLMModel.get_router, which the
    # pinned fhlmi no longer has.
    resp = await agent_query(q, settings=s, docs=docs, agent_type='fake')
    ses = resp.session
    if not evidence_only:
        print('\n=== answer (a pointer to pages, not a source) ===\n'); print(ses.answer)
    print('\n=== evidence ===')
    for c in ses.contexts:
        t = c.text; name = getattr(t.doc, 'docname', '') or getattr(t.doc, 'dockey', ''); print(f"- {t.doc.citation[:90]} | {t.name} | score {c.score}\n  {c.context[:400].strip()}\n")
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('query', nargs='?')
    ap.add_argument('--build', action='store_true', help='index what the index does not already hold at its current text')
    ap.add_argument('--reingest', action='append', default=[], metavar='PDF', help='drop this source and read it again, whatever its digest says; repeatable. Use after re-OCR of one file')
    ap.add_argument('--rebuild', action='store_true', help='discard the whole index and read every source again. Rarely what you want: --build already picks up changed text')
    ap.add_argument('--relabel', action='store_true', help='rewrite the citation and docname of every indexed source from the manifest, without re-reading or re-embedding anything. Use after a title or identifier changes in docs/references/INDEX.md')
    ap.add_argument('--evidence-only', action='store_true')
    a = ap.parse_args()
    if a.relabel: asyncio.run(relabel())
    elif a.build or a.rebuild or a.reingest: asyncio.run(build(fresh=a.rebuild, reingest=a.reingest))
    elif a.query: asyncio.run(ask(a.query, a.evidence_only))
    else: ap.print_help()
if __name__ == '__main__': main()
