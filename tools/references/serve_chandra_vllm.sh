#!/bin/bash
# Serve Chandra OCR 2 with vLLM on one GPU share, OpenAI-compatible on 127.0.0.1:8000, the way chandra_vllm's docker
# recipe does for a 24 GB card (max-num-batched-tokens 2048, max-num-seqs 16). Blocks; run under qrun:
#   qrun -p gpu-share -s 1 --vram 22G -m 24G -c 4 -t 12:00:00 -- tools/references/serve_chandra_vllm.sh
exec "$HOME/.venvs/chandra-vllm/bin/vllm" serve /home/cfutro/models/chandra-ocr-2 --host 127.0.0.1 --port 8000 \
  --served-model-name chandra --dtype bfloat16 --max-model-len 18000 --max-num-seqs 16 --max-num-batched-tokens 2048 \
  --gpu-memory-utilization 0.75 --enable-prefix-caching --mm-processor-kwargs '{"min_pixels": 3136, "max_pixels": 6291456}'
