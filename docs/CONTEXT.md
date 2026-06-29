# Penna

A privacy-first, fully local AI personal assistant for macOS. The first deliverable (v1) is a **menu-bar app** whose single UI is a **Panel** that improves, rephrases, and drafts short text entirely on-device. Later tasks (docs, decks, notes, podcasts, etc.) are parked for future projects.

## Language

**Panel**:
The menu-bar-anchored window that is the assistant's single UI surface. It opens when the user clicks the **Menu bar icon** or presses the **Open shortcut**, and holds the mode selector, the input box, and the result.
_Avoid_: floater, popup, popover, window, overlay.

**Menu bar icon**:
The macOS status-bar icon (top-right of the screen). Clicking it opens the **Panel**. The app is Dock-less (`LSUIElement`).
_Avoid_: tray icon, status icon, menu item.

**Open shortcut**:
The global hotkey that opens and focuses the **Panel** (e.g. ⌃⌥Space). A pure convenience for summoning the UI — permission-free, and unrelated to reading text from other apps.
_Avoid_: hotkey, trigger, capture key.

**Improve**:
The mode that fixes grammar, spelling, and punctuation while changing the wording **as little as possible** — the sentence stays the user's own, it just stops being broken. The default mode when the Panel opens.
_Avoid_: fix, correct, grammar mode.

**Rephrase**:
The mode that rewords and restructures text to say the same thing **differently**, even when the original was already correct.
_Avoid_: reword mode, rewrite, polish.

**Draft**:
The mode that generates **new** text (a message or email) from a typed instruction. Takes an instruction only; any context to reply to is pasted into that same instruction.
_Avoid_: compose, generate, write mode. (The user may call it "Draft/Write"; **Draft** is canonical.)

**Clipboard auto-fill**:
Pre-filling the Panel's input box with the current clipboard contents when the Panel opens — only in **Improve** and **Rephrase**. A permission-free *read* of whatever is already on the clipboard; **not** a synthetic copy out of another app.
_Avoid_: selection capture, grab, paste-in, scrape.

**Auto-copy**:
Placing the finished result onto the clipboard automatically once generation completes, so the user can paste it into their own app. The user always pastes; the app never writes into other apps.
_Avoid_: replace, paste-back, apply, commit.

**Parked**:
A task on the original wishlist (deck, podcast, TTS, image generation, summary, notes, etc.) deliberately excluded from v1 — not abandoned, but deferred to a future project. See `docs/adr/0001-local-only-no-cloud.md`.
_Avoid_: backlog, later, out-of-scope.

## Flagged ambiguities

**Improve vs Rephrase** — both take pasted text and return changed text, so they blur easily. Resolution: **Improve = minimal correction** (fix only what is broken, keep the wording); **Rephrase = deliberate rewording** (change how it is said). If the user wants the meaning expressed differently, that is Rephrase; if they only want errors gone, that is Improve.

## Example dialogue

> **Dev:** The user copies a sentence and clicks the Menu bar icon. What do they see?
> **Domain:** The Panel opens in Improve mode with that copied text already in the box — that's Clipboard auto-fill. They run it and get the corrected sentence back, Auto-copied to the clipboard, ready to paste.
> **Dev:** What if they wanted to reword it rather than just fix it?
> **Domain:** They switch the mode to Rephrase. Improve only fixes what's broken; Rephrase says the same thing a different way.
> **Dev:** And writing a brand-new email?
> **Domain:** That's Draft. Switching to Draft clears the box — there's nothing to auto-fill — and they type an instruction like "email my landlord about the broken heating." Draft generates it from scratch.
> **Dev:** Does the app ever paste the result back into their email for them?
> **Domain:** No. It only Auto-copies the result. The user pastes it themselves — we never write into other apps. That's the whole reason we dropped the old floater and copy-trick.
