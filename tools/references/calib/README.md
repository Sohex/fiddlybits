# Calibration set for the generator quant

PaperQA2 needs a model to drive, and it has to fit on the card, so it gets quantized.
What a quant keeps is decided by the calibration data it is measured against.
exllamav3 ships a general corpus, which is the sensible default for a model that will
be asked anything. This one only ever does two things: summarise a retrieved chunk
against a question, then write an answer over the summaries that survive. Calibrating
on that instead of on generic web text is the whole idea here.

## Running it

Two of the four stages need different environments, because retrieval needs paperqa and
generation needs the model. They are separate processes and share no dependencies.

    # paperqa venv: pull real chunks out of the real index
    ~/.venvs/fiddlybits-tools/bin/python build_seeds.py

    # torch venv, on the card: sample the responses            HEAVY
    qrun -p gpu -m 52G --vram 22G -t 4:00:00 -- \
        <torch-venv>/bin/python -u gen_trace.py

    # exllamav3 venv: blend and pack
    <exl3-venv>/bin/python pack_cal.py

Then point the conversion at the result:

    convert.py -i <model> -o <out> -w <work> -b 4.5 -mb 8 \
        -cd tools/references/calib/cal.safetensors

`dump_prompts.py` runs under the paperqa venv and copies its prompt templates into
`prompts.json`. Re-run it after upgrading paperqa. Nothing here transcribes a prompt by
hand, so a template that changes shows up as a diff.

## Where the excerpts come from

`calib.toml` names an index under `[index]`, and `build_seeds.py` reads it: the actual
chunks, the actual citation strings, and the actual context keys that appear in the
answer prompt's valid-keys list. Chunk vectors are cached in the index, so this costs
one query embedding per question and no corpus pass.

Name the index explicitly rather than deriving it from settings. PaperQA2 keys the
index name on parsing and embedding configuration, so a config edit silently points at
a different, absent index; a calibration run should read the index that exists.

With `[index] name` empty it falls back to `build_chunks.py` plus BM25, which re-cuts
the reference text at the same geometry and ranks it lexically. That approximates the
index rather than reading it, and is only there for when no index has been built.

Chunk size, `evidence_k` and `answer_max_sources` are not declared here either. They
come from `tools/references/paperqa.toml`, so this cannot describe a service configured
differently.

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
calls plus one answer call, and the pack needs a known number of tokens, so only that
many seeds are used. To widen the bank, add to `questions.toml` and rerun
`build_seeds.py`; nothing derives questions automatically.

**Tuning the heavy stage.** The model does not fit on the card, so `--gpu-gib` and
`--cpu-gib` split it and the rest is read from system RAM every forward pass. That read
is the bottleneck, and it is amortised across the batch, so throughput scales with
`--batch-size` far more than with anything else. Two limits bound it. The two budgets
together must exceed the model, or accelerate spills to disk, which is catastrophic and
is announced only as "offloaded to the cpu and disk" rather than as an error. And the
card needs headroom above `--gpu-gib` for the offloaded weights that get paged onto it:
this vocabulary makes `lm_head` a single 2.5 GB tensor, so a `--gpu-gib` set close to
the vram cap dies in CUDA OOM partway through, not at load. Leave about 3 GiB.

**Intermediates are disposable.** Everything but the scripts is regenerated and is
gitignored. Rebuild after the corpus or the index changes.
