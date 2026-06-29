# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

`penna-ai` is a privacy-first, fully local AI personal assistant for macOS. v1 is a **menu-bar app** ("Penna"): a Panel with three modes — **Improve** (grammar fix), **Rephrase** (reword), and **Draft** (write from an instruction) — running entirely on-device via local Ollama. See `docs/CONTEXT.md` for the domain language and `docs/adr/` for decisions (ADR-0006 defines the menu-bar design).

v1 has shipped: the menu-bar app is complete, built on the `OllamaKit` Swift package + tracer. Remaining work (distribution, docs) is tracked in GitHub Issues.

## Stack

- **Swift / SwiftUI** is the primary language — this is a native-macOS app (ADR-0002). The Python/Node patterns in `.gitignore` are unused boilerplate, not the stack.
- **Ollama** (local, `localhost:11434`) for inference — no cloud (ADR-0001, ADR-0004).
- The app is an **Xcode project**; non-UI logic lives in a **local Swift package** (`OllamaKit`) so it stays unit-testable (ADR-0007).

## Repository Layout

```
Package.swift   # Swift package: OllamaKit library + OllamaTracer CLI
Sources/        # OllamaKit (Ollama client), OllamaTracer (connectivity tracer)
Tests/          # OllamaKit unit tests
docs/           # CONTEXT.md (glossary), adr/ (decisions), implementation-notes.md, lessons.md
.claude/        # Claude Code configuration (agents/, rules/, skills/)
```

## Development Commands

- `swift test` — run the OllamaKit unit tests
- `swift run ollama-tracer` — send one real prompt to local Ollama (sanity check)
- The macOS **app** is built and run from **Xcode** (open the `.xcodeproj`).

## Lessons Learned

Captured in `docs/lessons.md`. Update it after any corrected mistakes.

## Agent skills

### Issue tracker

Issues live in GitHub Issues (`blessed1sagar/penna-ai`, private). See `docs/agents/issue-tracker.md`.

### Triage labels

Default five-label vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout — `docs/CONTEXT.md` for domain language and `docs/adr/` for ADRs. See `docs/agents/domain.md`.
