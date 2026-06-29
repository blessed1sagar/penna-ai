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

## Install (no Xcode needed)

Penna is a small, ad-hoc-signed menu-bar app. It is **not** signed with an Apple Developer ID and **not** notarized — a deliberate choice so anyone can build and ship it without a paid Apple account. macOS Gatekeeper only blocks apps that carry the download "quarantine" flag, so getting past it is one quick step (or zero, with the curl installer).

Penna lives in the menu bar (the pencil icon) — there is no Dock icon and no app window. After installing, click the icon or press ⌃⌥P to open it. You can turn on **Launch at login** from Penna's Settings (right-click the menu-bar icon ▸ Settings).

### Option A — one-line install (no manual step)

```
curl -fsSL https://raw.githubusercontent.com/blessed1sagar/ai-pa/main/scripts/install.sh | bash
```

This downloads the latest release, installs `Penna.app` to `/Applications`, and launches without any Gatekeeper prompt — `curl` doesn't set the quarantine flag, so there's nothing to clear.

### Option B — download and drag

1. Download `Penna.zip` from the [latest Release](https://github.com/blessed1sagar/ai-pa/releases/latest) and unzip it.
2. Drag `Penna.app` into `/Applications`.
3. Run this once to clear the download quarantine flag, then open Penna normally:
   ```
   xattr -dr com.apple.quarantine /Applications/Penna.app
   ```
   On macOS 15.1+ the Finder "Open Anyway" path is unreliable for apps without a Developer ID, so this `xattr` strip is the reliable way through Gatekeeper.

### Option C — build from source (developers)

This is the zero-friction path: an app you build locally is never quarantined, so it just runs. Open `Penna/Penna.xcodeproj` in Xcode and Build & Run. To produce a distributable zip for a Release, build with the Release configuration, then run `scripts/package-app.sh <path-to-Penna.app>` and attach the resulting `Penna.zip` to a GitHub Release (the script prints the exact build + upload steps).

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
