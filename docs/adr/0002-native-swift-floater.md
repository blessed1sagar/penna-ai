# Native Swift/SwiftUI floater, not a web app

> **Status:** superseded by ADR-0006. The native Swift/SwiftUI choice still holds; the *floater* UI surface does not — v1 is now a menu-bar Panel. Kept for history.

The product is a macOS floater that must hover above other apps without stealing focus (`NSPanel`, non-activating), register a global hotkey, and read selected text from any app via the Accessibility API. A browser tab cannot do any of these, and a web shell (Electron) carries 150–300MB of overhead that competes with the local LLM for RAM on a 16GB M2. We chose native **Swift/SwiftUI** for the lowest memory footprint and first-class access to the macOS primitives we depend on.

## Considered Options

- **Web app in a browser** — rejected: can't do global hotkey, always-on-top, or cross-app text capture.
- **Tauri / Electron (web UI in a desktop shell)** — viable, and the initial instinct was "web-based," but the floater UX is better served natively and Electron's RAM cost is significant on a 16GB machine shared with Ollama.
- **Native Swift/SwiftUI** — chosen.

## Consequences

This is a deliberate deviation from the repo's default language posture (Python-first, TypeScript for frontend). Swift is used here because it is a native-macOS task — the same kind of carve-out as "TypeScript when it's a frontend task."
