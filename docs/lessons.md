# Lessons Learned

## Don't convert "explain it simply" into "decide for me"

**2026-06-16.** During the grill-with-docs session on selection capture, the user said they were confused by both options and asked me to "make every technical decision simple to understand." I treated that as permission to pick the option myself and started writing the ADR. The user stopped me: they wanted a *simpler explanation so they could choose*, not for me to choose.

**Rule reinforced:** "Simplify this for me" / "I'm confused" is a request for a clearer explanation, NOT authorization to make the decision. Always re-present the choice and let the user pick, unless they explicitly say "you decide." Never collapse a 2-option decision into a silent pick.

## Check the branch matches the work BEFORE committing

**2026-06-26.** Committed the OllamaKit/Improve code onto the branch `docs/menu-bar-pivot`. That branch is named for documentation work, so committing Swift code there is off-label — noticed only after the commit was made.

**Rule:** Before the first commit of a turn, look at the current branch name and confirm it fits the kind of work (code vs docs) and isn't `main`. If it doesn't fit, stop and offer to create a properly-named feature branch (`feat/…`, `fix/…`) *before* committing, not after. Catching it post-commit means an extra branch-move step.

## Never commit Xcode personal state — and stage deliberately

**2026-06-26.** Creating the `Penna.xcodeproj` auto-staged everything, including `UserInterfaceState.xcuserstate` (personal window/cursor/scroll state) and a large, unrelated `.agents/` skill tree — a blind `git add` had pulled them into the index. Both were one `git commit` away from entering history.

**Rule:** Never `git add -A` / `git add .` blindly — stage the *exact* files the change needs. Xcode editor state (`xcuserdata/`, `*.xcuserstate`) and build output (`DerivedData/`) must be in `.gitignore` and never committed. Run the **`pre-commit-check`** skill before every commit; it catches all of this.

## The menu-bar app dev loop: run / stop / quit

**2026-06-26.** Pressing ⌘R repeatedly in Xcode without stopping spawned duplicate menu-bar icons (multiple live instances of Penna). Because a menu-bar app has no Dock icon or window, it was unclear how to quit, and a paused debugger showing assembly looked like a crash (it wasn't).

**Rule:** In Xcode, **⌘R** to run, **⌘.** to stop — always stop before re-running, or you get duplicate icons. Quitting the app (`NSApplication.terminate` / the in-app **Quit**) also ends the Xcode debug session. A Dock-less menu-bar app **must** ship an explicit in-app Quit (⌘Q) — without it there's no clean way to exit. A debugger paused on `mach_msg2_trap` / a `ViewBridge … benign` log line are normal, not errors.
