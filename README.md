# ai-pa

A privacy-first, fully local AI personal assistant for macOS — a **menu-bar app** that helps you write, running entirely on-device.

Click the menu bar icon (or press the Open shortcut) to open a small **Panel** with three modes:

- **Improve** — fix grammar, spelling, and punctuation, keeping your wording.
- **Rephrase** — reword text to say the same thing differently.
- **Draft** — write a new message or email from a short instruction.

You paste text in (or it auto-fills from your clipboard), pick a mode, and the result is auto-copied back to your clipboard. Nothing leaves your machine.

## Requirements

- macOS on Apple Silicon
- [Ollama](https://ollama.com) running locally, with the model pulled:
  ```
  ollama pull qwen2.5:7b-instruct-q4_K_M
  ```

## Development

- `swift test` — run the `OllamaKit` unit tests
- `swift run ollama-tracer` — send one real prompt to local Ollama (connectivity check)
- The macOS app is built and run from **Xcode** (open the `.xcodeproj`).

## Docs

- `docs/CONTEXT.md` — the domain glossary (what each term means)
- `docs/adr/` — architecture decisions (start with ADR-0006 for the menu-bar design)
- `docs/implementation-notes.md` — code-time how-to notes
- Work is tracked in GitHub Issues (`blessed1sagar/ai-pa`).

## Status

Early development. The `OllamaKit` package works; the menu-bar app is being built (issues #9–#15).
