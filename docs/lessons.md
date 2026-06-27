# Lessons Learned

> Note: this file is **not** auto-loaded into an agent's context. It's a normal repo doc — an agent sees it only when it opens the file. The reliably auto-loaded channel each session is the memory system (`MEMORY.md` + recalled memories). Durable behaviour rules therefore live in **both** places.

## Don't convert "explain it simply" into "decide for me"

**2026-06-16.** During the grill-with-docs session on selection capture, the user said they were confused by both options and asked me to "make every technical decision simple to understand." I treated that as permission to pick the option myself and started writing the ADR. The user stopped me: they wanted a *simpler explanation so they could choose*, not for me to choose.

**Rule reinforced:** "Simplify this for me" / "I'm confused" is a request for a clearer explanation, NOT authorization to make the decision. Always re-present the choice and let the user pick, unless they explicitly say "you decide." Never collapse a 2-option decision into a silent pick.

## Check the branch matches the work BEFORE committing

**2026-06-26.** Committed the OllamaKit/Improve code onto the branch `docs/menu-bar-pivot`. That branch is named for documentation work, so committing Swift code there is off-label — noticed only after the commit was made.

**Rule:** Before the first commit of a turn, look at the current branch name and confirm it fits the kind of work (code vs docs) and isn't `main`. If it doesn't fit, stop and offer to create a properly-named feature branch (`feat/…`, `fix/…`) *before* committing, not after. Catching it post-commit means an extra branch-move step.

## Never commit Xcode personal state — and stage deliberately

**2026-06-26.** Creating the `Penna.xcodeproj` auto-staged everything, including `UserInterfaceState.xcuserstate` (personal window/cursor/scroll state) and a large, unrelated `.agents/` skill tree — a blind `git add` had pulled them into the index. Both were one `git commit` away from entering history.

**Rule:** Never `git add -A` / `git add .` blindly — stage the *exact* files the change needs. Xcode editor state (`xcuserdata/`, `*.xcuserstate`) and build output (`DerivedData/`) must be in `.gitignore` and never committed. Run the **`pre-commit-check`** skill before every commit; it catches all of this.

## On `ready-for-agent` (AFK) issues, decide and proceed — don't gate on the user

**2026-06-27.** Starting issue #10 (labeled `ready-for-agent` = "Fully specified, AFK-agent ready"), I stopped to ask the user two design questions (Panel logic shape, auto-fill scope) — even though both answers were already dictated by the existing ADRs and the issue's scope. The user pushed back: if it's an AFK task, why is input required?

**Rule:** When an issue is `ready-for-agent` / meant to be done AFK, the global "always ask before non-trivial decisions" rule is overridden. **Make the call myself using the ADRs + issue scope, state the assumption in one plain line, and proceed.** Only stop for a genuinely blocking ambiguity that the docs can't resolve. (Contrast with the interactive grill/design sessions in the first lesson above, where the user *is* in the loop and wants to choose — there, explain and let them pick.)

## Always say what I'm suggesting and why — in very simple terms

**2026-06-27.** The user asked to always know what I'm recommending and the reason, explained simply.

**Rule:** Whenever I pick an approach (especially when proceeding without asking), lead with a one-line "**I'm doing X because Y**" in plain language — no jargon dumps. The user is a beginner ([[user-beginner-explain-everything]]); a short why beats a long how.

## Explain the git / PR / merge workflow in plain newbie terms

**2026-06-27.** After opening PR #16, I asked "want me to leave PR #16 for you to review and merge, or anything else on #10?" The user (new to git) found the phrasing unclear and asked me to explain it simply.

**Rule:** This user is a beginner with git/GitHub ([[user-beginner-explain-everything]]). When doing or describing any version-control step, explain in plain words *what it means* and *what happens next* — don't assume the vocabulary. Useful framings:
- **PR (pull request)** = "please merge this finished slice into `main`"; one issue → one PR.
- **Merge** = the button that actually copies the branch's work into `main`; usually the human's call.
- **The per-issue loop:** `git checkout main && git pull` → `git checkout -b feat/<thing>` → TDD + commit → push → open one PR that `Closes #<n>` → review → merge → repeat for the next issue.
- A PR is opened **when one issue's slice is done**, not "at the very end of the project" — there is no single end; each issue is its own slice.

## Don't default a global hotkey to a Space-based combo

**2026-06-27.** Issue #14 shipped `⌃⌥Space` as the Open shortcut default (the example from the issue). The menu-bar icon opened the Panel fine, but the hotkey did nothing. Diagnosis: Space-based combos are reserved by macOS — `⌘Space` (Spotlight), `⌃Space`/`⌃⌥Space` (input-source), `⌃⌘Space` (emoji), `⌥⌘Space` (Finder). `⌃⌥Space` stays reserved at the Carbon level **even when the Keyboard pane shows it disabled**, so `RegisterEventHotKey` fails silently. Fix: keep ⌃⌥ but use a **letter** (`⌃⌥P`).

**Rule:** For a global hotkey default, never use Space — pick ⌃⌥ + a letter and sanity-check it isn't a system shortcut. Also: a working menu-bar icon but a dead hotkey localises the bug to *registration*, not the Panel/presentation code. And changing the code default does **not** override a shortcut already saved to the app's `UserDefaults` (`KeyboardShortcuts_<name>`) — that key must be cleared (or rebound) for the new default to apply.

## The menu-bar app dev loop: run / stop / quit

**2026-06-26.** Pressing ⌘R repeatedly in Xcode without stopping spawned duplicate menu-bar icons (multiple live instances of Penna). Because a menu-bar app has no Dock icon or window, it was unclear how to quit, and a paused debugger showing assembly looked like a crash (it wasn't).

**Rule:** In Xcode, **⌘R** to run, **⌘.** to stop — always stop before re-running, or you get duplicate icons. Quitting the app (`NSApplication.terminate` / the in-app **Quit**) also ends the Xcode debug session. A Dock-less menu-bar app **must** ship an explicit in-app Quit (⌘Q) — without it there's no clean way to exit. A debugger paused on `mach_msg2_trap` / a `ViewBridge … benign` log line are normal, not errors.

## SwiftUI's `Settings` scene won't open in a Dock-less menu-bar app — own the window

**2026-06-27.** Issue #15 (rebind the Open shortcut) first hosted the recorder in SwiftUI's `Settings { }` scene, opened from the menu-bar menu via the `showSettingsWindow:` command. The app built and the menu showed, but clicking "Open Shortcut…" did **nothing** — no window. Cause: `showSettingsWindow:` (and the older `showPreferencesWindow:`) is dispatched through the responder chain, which needs an active/key window to route through. A Dock-less (`LSUIElement`) app usually has no key window, so the command silently goes unhandled. Gating on `NSApp.responds(to:)` made it worse — `NSApplication` never implements that selector (SwiftUI installs it elsewhere), so the check is always false.

**Rule:** In a menu-bar-only app, don't rely on SwiftUI's `Settings` scene / `showSettingsWindow:` to present settings. **Own the window** the same way the app owns its Panel: create an `NSWindow`, set `contentViewController = NSHostingController(rootView:)`, `NSApp.activate(ignoringOtherApps:)`, then `makeKeyAndOrderFront`. Set `isReleasedWhenClosed = false` on a code-created window so reopening it after a close doesn't crash on a freed object. Reserve the `Settings` scene for apps that have a real menu bar.

## `.onChange` runs *inside* the view update — defer state mutations off the render

**2026-06-27.** Issue #25 flooded the console with "Publishing changes from within view updates is not allowed" when switching the Panel's mode Picker. My first fix bound the Picker straight to `$model.selectedMode` and moved the side effect into `.onChange(of:)`, assuming `.onChange` fires *after* the update. It doesn't — SwiftUI runs the `.onChange` action *within the same update transaction* that observed the change, so writing the `@Published input` there tripped the exact same warning (verified in the running app: warnings persisted). What actually fixed it: defer the whole mode switch to the next main-actor turn — `set: { newMode in Task { @MainActor in model.selectMode(newMode) } }` — so every `@Published` write lands after the render. The issue's *prime suspect* (the on-open `prefillFromClipboard()`) was a red herring: a backtrace showed it runs from a plain AppKit click handler, outside any render, so it never warned.

**Rule:** "Publishing changes from within view updates" means an `@Published` / `ObservableObject` mutation ran during a SwiftUI render. `.onChange`, custom `Binding` setters, and `body` itself all execute *inside* the update — mutating published state in any of them trips it, and moving it to `.onChange` does **not** help. The reliable fix is to hop the mutation to the next main-actor turn (`Task { @MainActor in … }`), and defer the *whole* action (e.g. a Picker's selection write too, not just its side effect — the segmented control commits its selection mid-layout). To localise the trigger fast: the warning fires once per user action that mutates state mid-render (here, once per tab switch), and a backtrace tells you whether the offending write sits inside a render (SwiftUI frames like `body` / `ViewGraph` present) or in a safe AppKit event handler.
