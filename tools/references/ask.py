#!/usr/bin/env python
"""PaperQA2 over the held papers: evidence with page citations.

    tools/references/ask.py --build                      # index new files only; keeps existing chunks
    tools/references/ask.py --rebuild                    # discard the index and index every file again
    tools/references/ask.py "How does Millero 1995 give the pressure dependence of K1?"
    tools/references/ask.py --evidence-only "..."       # gathered passages with page numbers, no synthesised answer

Reads tools/references/paperqa.toml. Every answer is printed with its sources as <file> p.<page>: quote.
The answer text is a pointer to pages, not a source: a value or scheme enters a record only after the page is
opened and the table or equation is named (docs/references/README.md).

Use --rebuild after any OCR pass. The index keys staleness on the PDF, and re-OCR changes only the extracted
text under references/text/, so an incremental --build would leave a re-read paper indexed under its old text
and answer from both. --rebuild removes the index directory first, which is the only way the replacement is
complete. The index manifest is generated from
docs/references/INDEX.md so citations carry the verbatim title and identifier the index holds.
"""
import argparse, asyncio, csv, os, pathlib, re, shutil, sys, tomllib
ROOT = pathlib.Path(__file__).resolve().parents[2]
CFG = tomllib.loads((ROOT / 'tools' / 'references' / 'paperqa.toml').read_text())

class InstructedSTEmbedding:
    """Sentence-transformers embedding with query/document modes for instruction-aware models (Qwen3-Embedding):
    left padding, fp16 on the GPU when enough memory is free, bf16 on CPU otherwise; queries get the retrieval
    instruction, documents do not; vectors normalised. Built lazily so `--build` and a single query pay only what they use."""
    def __init__(self, path, instruction, kind='qwen3', max_seq=2048, dim=None):
        from lmi.embeddings import EmbeddingModes
        self.name = path; self.ndim = dim; self.config = {}; self._m = None; self._mode = EmbeddingModes.DOCUMENT
        self.path, self.instruction, self.kind, self.max_seq = path, instruction, kind, max_seq
    def _model(self):
        if self._m is None:
            import torch
            from sentence_transformers import SentenceTransformer
            free = torch.cuda.mem_get_info()[0] / 2**30 if torch.cuda.is_available() else 0
            dev = 'cuda' if free > 18 else 'cpu'; dt = torch.float16 if dev == 'cuda' else torch.bfloat16
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
        from lmi.embeddings import EmbeddingModes
        m = self._model(); q = self._mode == EmbeddingModes.QUERY
        if self.kind == 'qwen3' and q: texts = [f'Instruct: {self.instruction}\nQuery:{t}' for t in texts]
        extra = {'task': 'retrieval', 'prompt_name': 'query' if q else 'document'} if self.kind == 'jina' else {}
        bs = 4 if (self.kind == 'qwen3' and self._dev == 'cuda') else 16
        out = await asyncio.to_thread(lambda: m.encode(texts, batch_size=bs, normalize_embeddings=True, convert_to_numpy=True, show_progress_bar=False, **extra))
        return out.tolist()
    async def embed_document(self, text): return (await self.embed_documents([text]))[0]
    async def check_rate_limit(self, *a, **k): return None


def parse_from_extracted_text(path, page_size_limit=None, page_range=None, **kwargs):
    """PaperQA2 parser that reads the per-page text extracted by tools/references/extract_text.py instead of
    re-parsing the PDF: the OCR layers are already the text, and pypdf on 700-page scans was the build's bottleneck."""
    from paperqa.types import ParsedText, ParsedMetadata
    import paperqa
    stem = pathlib.Path(path).stem; d = ROOT / 'references' / 'text' / stem
    if not d.is_dir(): raise FileNotFoundError(f'no extracted text for {path}; run tools/references/extract_text.py')
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
        # citation supplied here so Docs.aadd never asks the language model for one during indexing
        w = csv.writer(f); w.writerow(['file_location', 'doi', 'title', 'citation'])
        for p in sorted(paper_dir.glob('*.pdf')):
            title, ident = rows.get(p.name, (p.stem, ''))
            doi = ident if re.match(r'10\.\d{4,}/', ident) else ''
            w.writerow([p.name, doi, title, f'{title}. {ident}. [{p.name}]'.replace('. .', '.')])
    return mf
def settings(evidence_only=False):
    from paperqa import Settings
    from paperqa.settings import AgentSettings
    key = pathlib.Path.home() / '.anthropic_key'
    if CFG['llm'].startswith('anthropic/') and key.is_file(): os.environ.setdefault('ANTHROPIC_API_KEY', key.read_text().strip())
    if CFG['llm'].startswith('openai/'): os.environ.setdefault('OPENAI_API_KEY', 'local')
    llm_cfg = {'model_list': [{'model_name': CFG['llm'], 'litellm_params': {'model': CFG['llm'], 'api_base': CFG.get('api_base'), 'api_key': os.environ.get('OPENAI_API_KEY', 'local'), 'temperature': 0.0}}]} if CFG['llm'].startswith('openai/') else None
    paper_dir = ROOT / CFG['paper_directory']; index_dir = ROOT / CFG['index_directory']
    mf = manifest(paper_dir, index_dir)
    class S(Settings):
        def get_embedding_model(self):
            if CFG.get('embedding_path'): return InstructedSTEmbedding(CFG['embedding_path'], CFG.get('query_instruction', ''), CFG.get('embedding_kind', 'qwen3'), CFG.get('max_seq', 2048))
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
async def build(fresh=False):
    from paperqa.agents.search import get_directory_index
    if fresh:
        d = ROOT / CFG['index_directory']
        if d.exists(): shutil.rmtree(d); print('removed', d)
    s = settings(); idx = await get_directory_index(settings=s); print('indexed', len(await idx.index_files), 'files')
async def ask(q, evidence_only):
    from paperqa import Docs
    from paperqa.agents.search import get_directory_index
    s = settings(evidence_only); idx = await get_directory_index(settings=s, build=False)
    import rerank
    rr = rerank.from_config()
    docs = rerank.reranked_docs_class(rr, CFG.get('rerank_fetch_k', 50))() if rr else Docs()
    # gather across the whole index rather than an agent loop: deterministic, cheaper, and every source is page-cited
    from paperqa.agents.main import agent_query
    from paperqa.agents.models import QueryRequest
    resp = await agent_query(QueryRequest(query=q, settings=s), docs=docs)
    ses = resp.session
    if not evidence_only:
        print('\n=== answer (a pointer to pages, not a source) ===\n'); print(ses.answer)
    print('\n=== evidence ===')
    for c in ses.contexts:
        t = c.text; name = getattr(t.doc, 'docname', '') or getattr(t.doc, 'dockey', ''); print(f"- {t.doc.citation[:90]} | {t.name} | score {c.score}\n  {c.context[:400].strip()}\n")
def main():
    ap = argparse.ArgumentParser(); ap.add_argument('query', nargs='?'); ap.add_argument('--build', action='store_true'); ap.add_argument('--rebuild', action='store_true'); ap.add_argument('--evidence-only', action='store_true'); a = ap.parse_args()
    if a.build or a.rebuild: asyncio.run(build(fresh=a.rebuild))
    elif a.query: asyncio.run(ask(a.query, a.evidence_only))
    else: ap.print_help()
if __name__ == '__main__': main()
