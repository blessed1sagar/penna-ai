# Selection-driven hotkey, not inline Grammarly

> **Status:** superseded by ADR-0006. The selection-capture copy-trick and the fix-vs-draft hotkey branching are no longer part of v1 (now: menu-bar Panel, manual clipboard flow). The "no inline Grammarly" reasoning still stands. Kept for history.

A single global hotkey drives the floater, branching on context: if text is selected when the hotkey fires, the floater opens in **fix mode** (correct/rewrite the selection); if nothing is selected, it opens in **draft mode** (generate from a prompt). Accepted results are pasted back with a synthetic ⌘V.

Selection is captured with a **synthetic ⌘C** (one universal code path), chosen over the Accessibility-API-first approach for simplicity: the AX API is unreliable in Electron apps (Slack, VS Code, Notion), so the ⌘C fallback would have to be built regardless — so we build only that. Three mitigations make it well-behaved: (1) momentarily mute the system alert volume to suppress the copy "beep"; (2) snapshot and restore the full pasteboard so the user's clipboard is not clobbered; (3) detect an unchanged pasteboard `changeCount` to mean "nothing was selected" — which doubles as the fix-vs-draft mode detection. An Accessibility-first path may be added later purely as polish.

We deliberately do **not** attempt true inline correction (live underlining inside other apps' text fields, as Grammarly does). That requires a system input-method / keyboard extension injecting UI into every app — an enormous undertaking, especially under the local-only constraint. The select → hotkey → fix pattern delivers most of the value for a fraction of the effort. This is recorded so the inline approach isn't mistaken for an oversight and re-attempted later.
