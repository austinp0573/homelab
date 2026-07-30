# other useful local-LLM ideas (32GB)

things I have not packaged yet but that fit this box.

## 1. reranker next to embeddings

after vector search, run a small cross-encoder (bge-reranker-v2-m3 Q4, ~1GB) over the top 20 hits. big quality bump for RAG without a bigger chat model. can be a second llama.cpp/embedding-style process or a tiny CPU service.

## 2. summarization / nightly digest

cron a job that: pull new files from `/opt/llm/rag/docs` or a notes git repo -> map-reduce summarize with 14B -> write markdown into the same tree. uses llama for 20 minutes, then downs it. DDR4 host is fine for orchestration; keep the model on GPU.

## 3. structured extraction

same chat server, different prompt: invoices, receipt photos (needs vision GGUF + mmproj), lab inventory CSVs. vision models: Qwen2.5-VL-7B or 32B Q4 if it fits with mmproj. stay under ~20GB weights.

## 4. local "continue.dev" / IDE

no extra GPU service. point Continue / Cline / Aider at `http://<host>:8080/v1`. Aider on the host is lighter than a full agent container when you already trust the machine.

## 5. searxng + browsing chat

run SearXNG on CPU, enable web search in Open WebUI. model stays local; only search snippets leave (or stay on LAN if searx is local). useful and almost free on VRAM.

## 6. second-brain chunker

dedicated docling / unstructured pass on PDFs to markdown before ingest. CPU heavy, GPU idle. better than stuffing raw PDFs into AnythingLLM when layout is messy.

## 7. voice chat loop

Whisper STT -> llama.cpp -> Piper TTS. Open WebUI can do parts of this; a small script also works. keep whisper on medium unless you need large-v3 accuracy.

## 8. speculative decoding

llama.cpp draft model (tiny) + main model. sometimes free speed if both fit. try a 1-3B draft beside a 32B main; measure before committing.

## 9. grammar / GBNF constrained output

for agents and extractors, force JSON with llama.cpp grammar files. fewer broken tool calls than hoping the model behaves.

## 10. offline coding eval

keep a fixed prompt set (humaneval-ish or your own repos' tasks), run against two GGUFs overnight, compare. uses the box while you sleep; no new services.

## skip for now

- full OpenHands / Devika-class agent platforms (heavy, overlap with Pi)
- vLLM on ROCm (more moving parts; llama.cpp is already the t/s choice for single-user)
- multi-model routers (useless until more than one person hits the API)
