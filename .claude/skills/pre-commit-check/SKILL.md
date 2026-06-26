---
name: pre-commit-check
description: Validate the staged changes in the ai-pa repo and block the commit until they are clean. Use ALWAYS, immediately before running any `git commit` in this repo — checks .gitignore hygiene (no Xcode user state, build output, .env/secrets), runs swift test and the Xcode build when relevant files changed, verifies the branch and a conventional commit message, and flags debug leftovers.
---

# Pre-commit check (ai-pa)

A gate that runs before **every** commit in this repo. Catch mistakes (committing
`xcuserstate`, secrets, broken tests, a non-conventional message, the `main`
branch) *before* they enter git history, where they are painful to remove.

## When to use

Invoke this **immediately before any `git commit`** — after staging, before committing.
No exceptions, even for "tiny" or docs-only commits.

## Workflow

1. **Stage** the exact files you intend to commit (`git add …`). Don't `git add -A` blindly.
2. **Run the validator**, passing your proposed commit message so its format is checked too:
   ```bash
   bash .claude/skills/pre-commit-check/scripts/validate.sh "feat: short summary"
   ```
3. **Read the report.** It prints per-check results and a final tally.
   - **Blockers (✘)** → exit code 1. **Do not commit.** Fix every blocker, re-stage, re-run.
   - **Warnings (⚠)** → not auto-blocking, but read each one and decide consciously. If a
     warning reflects a real problem (debug `print(`, code on a `docs/*` branch), fix it.
4. **Only when the script exits 0 and you've cleared the warnings**, run the actual
   `git commit` with the same message you validated.

## What it checks

| # | Check | Blocks? |
|---|-------|---------|
| 1 | No `xcuserdata/` · `*.xcuserstate` · `DerivedData/` · `.build/` · `.swiftpm/` · `.env` staged | ✘ |
| 2 | No private keys / AWS / `sk-…` / `ghp_…` tokens in the staged diff | ✘ (heuristic creds → ⚠) |
| 3 | `swift test` passes (only if `Sources/`, `Tests/`, or `Package.swift` staged) | ✘ |
| 4 | Xcode app builds (only if `Penna/` staged) | ✘ |
| 5 | Not on `main`/`master`; warns if Swift code is on a `docs/*` branch | ✘ / ⚠ |
| 6 | Commit message is conventional (`feat:`/`fix:`/`docs:`/…) | ✘ if message passed |
| 7 | No obvious debug leftovers (`print(`, `dump(`, `FIXME`) in staged Swift | ⚠ |

## Fixing the common blocker

Xcode auto-stages your personal window state. To unstage and ignore it:
```bash
git rm --cached --ignore-unmatch "**/xcuserdata/**" "**/*.xcuserstate"
# ensure .gitignore has the Xcode rules (xcuserdata/, *.xcuserstate, DerivedData/)
```

## Notes

- The script reads **staged** changes only — it mirrors exactly what `git commit` records.
- Test/build steps are **scoped**: they run only when relevant files are staged, so a
  docs-only commit stays fast.
- Logs for failures land in `/tmp/penna_swift_test.log` and `/tmp/penna_build.log`.
