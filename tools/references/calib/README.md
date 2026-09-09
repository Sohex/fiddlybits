# Calibration set for the generator quant

PaperQA2 needs a model to drive, and it has to fit on the card, so it gets quantized.
What a quant keeps is decided by the calibration data it is measured against.
exllamav3 ships a general corpus, which is the sensible default for a model that will
be asked anything. This one only ever does two things: summarise a retrieved chunk
against a question, then write an answer over the summaries that survive. Calibrating
on that instead of on generic web text is the whole idea here.

These four stages build it. Only the third is heavy.

    python build_chunks.py     # references/text -> chunks.jsonl              6 s
    python build_seeds.py      # questions + BM25 retrieval -> seeds.jsonl     5 s
    qrun -p gpu -m 44G --vram 21G -t 12:00:00 -- python gen_trace.py
    python pack_cal.py         # blend and pack -> cal.safetensors            20 s

Then point the conversion at the result:

    python /home/cfutro/git/exllamav3/convert.py \
        -i <model> -o <out> -w <work> -b 4.0 \
        -cd tools/references/calib/cal.safetensors

`dump_prompts.py` runs separately under the venv that holds paperqa and copies its
prompt templates into `prompts.json`. Re-run it after upgrading paperqa. Nothing here
transcribes a prompt by hand, so a template that changes shows up as a diff.

Settings are in `calib.toml`. Chunk size, `evidence_k` and `answer_max_sources` are
not there: they are read from `tools/references/paperqa.toml`, so the calibration
cannot quietly describe a differently configured service.

## Things worth knowing

**Thinking mode has to match the server.** This model reasons by default. `calib.toml`
sets it per role, currently off for the summary call and on for the answer call. The
summary call is extractive, JSON-shaped and made `evidence_k` times per question, so
reasoning costs a lot there and buys little; the answer call is where it helps. If you
serve differently, change both together.

**The trace is blended, not used alone.** A fifth of exllamav3's bundled mix is random
token rows that exercise the whole vocabulary. This archive is one field of one
discipline, so on its own it would leave most of a large vocabulary untouched during
calibration. `calib.toml` carries the blend weights.

**The question count is solved for, not set.** One question costs `evidence_k` summary
calls plus one answer call, and the pack needs a known number of tokens, so the bank
widens only until that is covered. Generating past it just makes the heavy stage
longer. The curated bank in `questions.toml` covers the default budget on its own.

**Intermediates are disposable.** Everything but the scripts is regenerated in seconds
and is gitignored. Rebuild after the corpus changes, same as the index.
