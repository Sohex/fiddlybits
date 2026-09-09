#!/bin/bash
# Serve the local LLM PaperQA2 uses, on one GPU share, OpenAI-compatible on 127.0.0.1:8080. Blocks; run under qrun.
#   qrun -p gpu-share -s 1 --vram 21G -t 12:00:00 -- tools/references/serve_llm.sh
MODEL=${LLM_GGUF:-"$HOME/Downloads/Qwen3.6-27B-Fable-Fus-711-UnHeretic-NM-DAU-NEO-MAX-NEO-MTP-Q4_K_M.gguf"}
exec "$HOME/git/llama.cpp/build/bin/llama-server" -m "$MODEL" --host 127.0.0.1 --port 8080 --alias local \
  -ngl 99 -c 16384 -ctk q8_0 -ctv q8_0 -fa on --parallel 2 -t ${SLURM_CPUS_PER_TASK:-4}
