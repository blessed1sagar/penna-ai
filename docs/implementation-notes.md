# Implementation Notes

Practical, code-time guidance gathered from prior-art research (2026-06-16). These are *how to build it well* notes — not architectural decisions (those live in `docs/adr/`).

> ⚠️ **Not all of this applies to v1.** The menu-bar pivot (ADR-0006) dropped the floater + copy-trick. Sections marked **[PARKED]** below describe that old design and must **not** be built for v1 — they are kept only for the future floater upgrade. Everything else (global hotkey, Ollama-from-Swift) still applies.

## Selection capture — the "Copy trick" recipe — [PARKED]

> **[PARKED — superseded by ADR-0006.]** v1 does **not** do this. Text now enters via permission-free **Clipboard auto-fill** (just reading `NSPasteboard`), not a synthetic ⌘C. Kept only for the future floater upgrade.

Implements ADR-0003. When the hotkey fires:

1. **Mute the system alert volume** momentarily to suppress the copy "beep".
2. **Snapshot the full pasteboard** — all item types, not just `.string` (otherwise RTF/images on the clipboard are lost on restore).
3. Record the pasteboard's `changeCount`.
4. Post a synthetic **⌘C** via `CGEvent`.
5. **Wait ~100 ms** (or poll `changeCount` every ~10–20 ms up to ~250 ms) before reading — without the wait the clipboard may return stale data.
6. **If `changeCount` is unchanged → nothing was selected** → open the floater in **draft mode**. Otherwise read the copied string → **fix mode**.
7. **Restore** the original pasteboard and alert volume.
8. On accept, paste the result back with a synthetic **⌘V**.

Reference implementation to read (do not copy — see ADR-0005): [yetone/get-selected-text](https://github.com/yetone/get-selected-text/blob/main/src/macos.rs).

## Floating panel (NSPanel) configuration — [PARKED]

> **[PARKED — superseded by ADR-0006.]** v1's UI is a menu-bar **Panel** (`MenuBarExtra` / a popover from the menu bar icon), **not** an always-on-top `NSPanel` floater. Only `LSUIElement` (Dock-less agent) still applies to v1. Kept for the future floater upgrade.

Implements ADR-0002. The exact flags that make the floater appear without stealing focus and survive Spaces/full-screen:

- Subclass `NSPanel`, host SwiftUI via `NSHostingView`.
- `styleMask: [.nonactivatingPanel, .titled, .resizable, .closable, .fullSizeContentView]`
- `isFloatingPanel = true`, `level = .floating` (or `.statusBar`)
- `becomesKeyOnlyIfNeeded = true`, `hidesOnDeactivate = false`
- **Override `canBecomeKey` and `canBecomeMain` to return `true`** — required or the non-activating panel can't accept text input at all.
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]` — without `.fullScreenAuxiliary` it won't show over full-screen apps; without `.canJoinAllSpaces` it vanishes when switching Spaces.
- Show with `panel.orderFrontRegardless()` — **never** `NSApp.activate(ignoringOtherApps:)`, which steals focus and breaks paste-back.
- Set `LSUIElement` in Info.plist for a Dock-less agent app.
- Refs: [cindori.com/developer/floating-panel](https://cindori.com/developer/floating-panel), [fazm.ai/blog/swiftui-floating-panel](https://fazm.ai/blog/swiftui-floating-panel)

## Global hotkey

Still applies to v1 — but now it is the **Open shortcut** (opens/focuses the menu-bar Panel, issues #14/#15), not the old selection-capture trigger.

Use **`KeyboardShortcuts`** by Sindre Sorhus — actively maintained, SwiftUI-native, ships a `Recorder` view for user rebinding, sandbox-safe. Wraps Carbon `RegisterEventHotKey` (still the de-facto API). Avoid an Option-only default modifier (a macOS 15 bug stopped those firing); ⌃⌥ + a key is safer.
Ref: [github.com/sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)

The default (`⌃⌥P`) is declared in the testable package as `KeyboardShortcuts.Name.openPanel` (`Sources/OllamaKit/OpenShortcut.swift`, ADR-0007), with unit tests guarding it against the Option-only regression. The app registers its handler via the `OpenShortcut.onTrigger` wrapper, so the KeyboardShortcuts import stays inside the package and the app picks it up transitively.

**Avoid Space in the default.** Space-based combos are a minefield of reserved macOS shortcuts — `⌘Space` (Spotlight), `⌃Space`/`⌃⌥Space` (input-source switching), `⌃⌘Space` (emoji picker), `⌥⌘Space` (Finder search). `⌃⌥Space` (the original default) stays reserved at the Carbon level *even when the Keyboard pane shows it disabled*, so `RegisterEventHotKey` fails silently — the menu-bar icon still opens the Panel but the hotkey does nothing. A ⌃⌥ + **letter** combo (P for Penna) registers cleanly. Note: changing the code default does **not** override a binding already persisted to the app's `UserDefaults` (`KeyboardShortcuts_openPanel`); clear that key (or rebind via a Recorder) for the new default to take effect.

## Presenting the Panel (issue #14)

The Open shortcut must *open and focus* the Panel from any frontmost app. SwiftUI's `MenuBarExtra` (the issue #9 shell) has no public API to present its popover programmatically, so v1 drives the menu bar from AppKit instead: an `NSStatusItem` (the icon) plus an `NSPanel` we own (`Penna/Penna/MenuBarController.swift`). Both the icon click and the hotkey funnel into the same `show()` — one surface, as ADR-0006 intends (a Dock-less menu-bar Panel); only the presentation mechanism changed from `MenuBarExtra` to a hand-rolled status item.

- The panel is `.titled` (required for text input to accept focus) with the title/chrome hidden, `isFloatingPanel = true`.
- Showing calls `NSApp.activate(ignoringOtherApps:)` then `makeKeyAndOrderFront` — the opposite of the parked **floater** notes above (which deliberately avoided activation for paste-back). Here focusing the Panel *is* the goal, so activating is correct.
- `windowDidResignKey` orders the panel out, giving the click-away-to-dismiss feel of a menu-bar popover.

## Ollama from Swift

Implements ADR-0004.

- Call `localhost:11434` directly with `URLSession` (`/api/generate` or `/api/chat`). No official Swift SDK; if a wrapper is wanted, [mattt/ollama-swift](https://github.com/mattt/ollama-swift) is active.
- For short grammar fixes, `"stream": false` is fine. For streaming, use `URLSession.bytes(for:)` + `for try await line in bytes.lines` and decode each **NDJSON line** (don't parse the stream as one JSON document — the most common bug).
- Use **structured output** (`"format": {JSON schema}`, Ollama ≥0.5) with **`temperature: 0`** for clean, deterministic corrected text in a known field.
- **Cold start:** loading 7B Q4 takes ~3–10 s. Set **`keep_alive: -1`** and fire a warm-up request at app launch so first real use is instant. Warm throughput ~35–50 tok/s on the M2 GPU.
- Model: `qwen2.5:7b-instruct-q4_K_M` (~5.2 GB).

## Distribution caveat (deferred — not a v1 concern)

Updated for the menu-bar pivot (ADR-0006): v1 no longer posts synthetic keystrokes or uses the Accessibility API, so the old Mac App Store **Guideline 2.4.5** rejection risk ("accessibility features used for non-accessibility purposes") no longer applies to this design.

If the app is ever distributed:

- **Easiest path: a notarized `.dmg` outside the App Store.** Requires an **Apple Developer account (~$99/yr)** for a Developer ID certificate, then **sign + notarize** the build so it opens without the "unidentified developer" warning. People downloading it need **no Apple account** (only the App Store requires that).
- **The real blocker is the Ollama dependency, not Apple.** End users must install Ollama and pull the ~5 GB model on a capable Apple-Silicon Mac before the app does anything — so a plain `.dmg` realistically only serves technical users. Bundling a local runtime/model for non-technical users is a large, separate effort (parked).
- App Store distribution may now be *technically* possible (no synthetic keystrokes), but the Ollama dependency plus App-Sandbox/networking constraints make the notarized-`.dmg` route simpler regardless.

For **v1 run on your own Mac, none of this is needed.**
Ref: [developer.apple.com/forums/thread/820594](https://developer.apple.com/forums/thread/820594)

## Reference projects (read for patterns, do not copy GPL code)

- [theJayTea/WritingTools](https://github.com/theJayTea/WritingTools) — closest architecture twin (GPL-3.0): selection capture/replace, hotkey, Ollama+MLX.
- [Enchanted](https://github.com/gluonfield/enchanted) / [Ollamac](https://github.com/kevinhermawan/Ollamac) — Swift→Ollama networking reference.
- MLX is a lower-latency local runtime on Apple Silicon (WritingTools uses it). Out of scope for v1 (Ollama is simpler), noted as a future latency lever.
