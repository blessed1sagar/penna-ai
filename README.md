# Penna

A private, on-device writing assistant for macOS. Penna lives in your menu bar and helps you fix, reword, and draft text — entirely on your Mac, powered by a local [Ollama](https://ollama.com) model. Nothing you type ever leaves your machine.

## What it does

- **Improve** — fix grammar, spelling, and punctuation while keeping your wording.
- **Rephrase** — reword text to say the same thing differently.
- **Draft** — write a new message from a short instruction.

Open the Panel from the menu-bar icon or the Open shortcut (default ⌃⌥P), pick a mode, and the result is copied straight back to your clipboard.

## Requirements

- macOS 13 or later (Apple Silicon)
- [Ollama](https://ollama.com) running locally, with the model pulled:

  ```
  ollama pull qwen2.5:7b-instruct-q4_K_M
  ```

## Install

**One line (no prompts):**

```
curl -fsSL https://raw.githubusercontent.com/blessed1sagar/penna-ai/main/scripts/install.sh | bash
```

**Or download manually:** grab `Penna.zip` from the [latest release](https://github.com/blessed1sagar/penna-ai/releases/latest), unzip it, and drag `Penna.app` to `/Applications`. macOS quarantines apps downloaded outside the App Store, so clear that flag once:

```
xattr -dr com.apple.quarantine /Applications/Penna.app
```

Penna runs in the menu bar (no Dock icon). Turn on **Launch at login** from its Settings.

## Build from source

```
git clone https://github.com/blessed1sagar/penna-ai.git
open penna-ai/Penna/Penna.xcodeproj   # then Build & Run in Xcode
```

`swift test` runs the `OllamaKit` unit tests. See `docs/CONTEXT.md` for the domain language and `docs/adr/` for the architecture decisions.
