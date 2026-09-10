#!/bin/bash
# Serve Chandra OCR 2 with vLLM, OpenAI-compatible on 127.0.0.1:8000. Blocks; started by hand, outside the
# scheduler, which is why `qrun free` reports the card idle while it is up. The reading chain waits for it to
# answer rather than starting one.
#
# The pixel cap is the setting that matters and it is not a memory knob alone. One visual token covers 32 x 32
# pixels (patch 16, merge 2), so the cap sets both the resolution the model sees and the length of the prompt.
# The chandra_vllm docker recipe's 6291456 puts a letter page at 2205 pixels across the text, which is not enough
# to hold the column boundaries of a dense eight-column table apart: 421 of the 1095 JANAF table pages read at
# that budget break their own arithmetic (notes/findings/2026-09-09-janaf-table-identities.md). 12582912 doubles
# the budget to 12288 visual tokens and 3118 pixels across the text.
#
# The model length then has to hold the image and the whole reply: 12288 visual tokens plus chandra's own
# MAX_OUTPUT_TOKENS of 12384, so 24576. The recipe's 18000 was already short of the old 6144 plus that reply and
# left the longest pages to be clamped.
#
# Render to match: at this cap a page must reach pdftoppm at a long side of 4400 or more, or the render, not the
# cap, is what limits it. chandra_pages.py --long-side.
set -u
PX=${CHANDRA_MAX_PIXELS:-12582912}
LEN=${CHANDRA_MAX_MODEL_LEN:-24576}
SEQS=${CHANDRA_MAX_NUM_SEQS:-16}
UTIL=${CHANDRA_GPU_UTIL:-0.75}
exec "$HOME/.venvs/chandra-vllm/bin/vllm" serve /home/cfutro/models/chandra-ocr-2 --host 127.0.0.1 --port 8000 \
  --served-model-name chandra --dtype bfloat16 --max-model-len "$LEN" --max-num-seqs "$SEQS" \
  --max-num-batched-tokens 2048 --gpu-memory-utilization "$UTIL" --enable-prefix-caching \
  --mm-processor-kwargs "{\"min_pixels\": 3136, \"max_pixels\": $PX}"
