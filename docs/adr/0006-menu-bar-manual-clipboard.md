# Menu-bar app with manual clipboard flow, superseding the floater + copy-trick

v1 is a Dock-less **menu-bar app**: clicking the **Menu bar icon** (or pressing an **Open shortcut**) opens a **Panel** with three modes — **Improve** (minimal grammar/spelling correction), **Rephrase** (deliberate rewording), and **Draft** (generate new text from a typed instruction). Text comes in via permission-free **Clipboard auto-fill** (a read-only read of the existing clipboard, in Improve/Rephrase only) and goes out via **Auto-copy**; the user pastes the result themselves. The app never writes into other apps.

We chose this over the previously documented floater + global-hotkey + synthetic-⌘C/⌘V flow because it needs **no Accessibility permission**, has **no fragile synthetic-keystroke, clipboard-restore, or focus-stealing edge cases**, and is realistic to build and maintain solo while still learning Swift. The cost — manual copy/paste instead of seamless in-place Replace — is acceptable for a personal v1.

## Status

accepted — supersedes ADR-0002 and ADR-0003

## Considered Options

- **Floater + hotkey + copy-trick** (ADR-0002, ADR-0003) — seamless (select → hotkey → result pasted back in place), but requires the Accessibility permission and a fragile synthetic-keystroke + pasteboard-snapshot/restore machine. Remains available as a future upgrade if the manual flow proves too slow.
- **Menu-bar app + manual clipboard flow** — chosen.

## Consequences

- ADR-0004 (Ollama direct, local-only) and ADR-0001 (local-only, no cloud) are unaffected and still hold.
- The two-mode model (Fix / Draft) is replaced by three modes (Improve / Rephrase / Draft); "Fix" splits into Improve and Rephrase.
- `KeyboardShortcuts` is still used, but only to *open the Panel*, not to capture selected text. The macOS-15 Option-only-modifier bug still applies, so the default uses ⌃⌥.
- The selection-capture "copy trick" recipe in `docs/implementation-notes.md` is no longer part of v1; it stays as reference for the parked floater upgrade.
