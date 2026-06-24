# Call Ollama directly from Swift, no Python service in v1

Local inference runs on **Ollama** (`localhost:11434`), the standard one-command model server on Apple Silicon. The v1 AI logic is small — a couple of prompt templates for grammar correction and short drafting — so the Swift app calls Ollama's HTTP API directly and holds the prompt templates itself. No intermediate Python/FastAPI service.

This deviates from the repo's Python-first default deliberately: a second process would add RAM pressure and startup complexity for no v1 benefit. A Python "brain" earns its place only if the parked features (which need model routing and richer orchestration) are built later.

v1 ships a **single model: Qwen2.5 7B Instruct (Q4)** — no fallback, to keep setup simple. Research (a 2025 17-model grammar-correction study) ranked it #2 overall, confirming it as a strong default; the earlier candidate Llama 3.1 8B ranked #8 for correction and was dropped. If correction quality ever disappoints, the documented next model to try is **Gemma 2 9B** (ranked #1, fits 16GB) — not Llama.
