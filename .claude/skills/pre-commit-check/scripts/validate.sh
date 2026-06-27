#!/usr/bin/env bash
# Pre-commit validation for ai-pa. Run BEFORE every `git commit`.
#
# Usage:  validate.sh ["proposed commit message"]
# Exit:   0 = safe to commit · 1 = blockers found · 2 = misuse (nothing staged)
#
# Checks STAGED changes only (what `git commit` would actually record).
set -uo pipefail

MSG="${1:-}"
BLOCKERS=0
WARNINGS=0
note_block() { echo "  ✘ BLOCK: $1"; BLOCKERS=$((BLOCKERS + 1)); }
note_warn()  { echo "  ⚠ WARN:  $1"; WARNINGS=$((WARNINGS + 1)); }

cd "$(git rev-parse --show-toplevel)" 2>/dev/null || { echo "Not in a git repo"; exit 2; }

staged=$(git diff --cached --name-only)
if [ -z "$staged" ]; then
  echo "Nothing staged. Run 'git add …' first, then re-run this check."
  exit 2
fi
added=$(git diff --cached --unified=0 | grep '^+' | grep -v '^+++' || true)

echo "── 1. .gitignore hygiene ───────────────────────────"
while IFS= read -r f; do
  case "$f" in
    *xcuserdata/*|*.xcuserstate) note_block "Xcode user state staged: $f  →  git rm --cached \"$f\"" ;;
    *DerivedData/*)              note_block "DerivedData (build output) staged: $f" ;;
    .build/*|*/.build/*|.swiftpm/*|*/.swiftpm/*) note_block "build artifact staged: $f" ;;
    *.example)                   : ;;  # .env.example etc. are fine
    .env|.env.*|*/.env|*.env)    note_block ".env file staged (secrets risk): $f" ;;
    .DS_Store|*/.DS_Store)       note_warn ".DS_Store staged: $f" ;;
  esac
done <<< "$staged"

echo "── 2. secret scan (staged content) ─────────────────"
echo "$added" | grep -qE -- '-----BEGIN [A-Z ]*PRIVATE KEY-----' && note_block "private key in staged diff"
echo "$added" | grep -qE '(AKIA|ASIA)[0-9A-Z]{16}'              && note_block "AWS access key in staged diff"
echo "$added" | grep -qE 'sk-[A-Za-z0-9]{20,}'                  && note_block "OpenAI-style secret (sk-…) in staged diff"
echo "$added" | grep -qE 'gh[pousr]_[A-Za-z0-9]{20,}'           && note_block "GitHub token in staged diff"
echo "$added" | grep -qiE '(api[_-]?key|secret|password|token)[[:space:]]*[:=][[:space:]]*["'"'"']?[A-Za-z0-9_-]{12,}' \
  && note_warn "possible hardcoded credential — eyeball the staged diff"

echo "── 3. tests (swift test) ───────────────────────────"
if echo "$staged" | grep -qE '^(Sources/|Tests/|Package\.swift)'; then
  if swift test >/tmp/penna_swift_test.log 2>&1; then echo "  ✓ swift test passed"
  else note_block "swift test FAILED — see /tmp/penna_swift_test.log"; fi
else
  echo "  • skipped (no package sources staged)"
fi

echo "── 4. app build (xcodebuild) ───────────────────────"
if echo "$staged" | grep -qE '^Penna/'; then
  if xcodebuild -project Penna/Penna.xcodeproj -scheme Penna -configuration Debug \
       -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build >/tmp/penna_build.log 2>&1; then
    echo "  ✓ app builds"
  else note_block "app build FAILED — see /tmp/penna_build.log"; fi
else
  echo "  • skipped (no app sources staged)"
fi

echo "── 5. branch ───────────────────────────────────────"
branch=$(git rev-parse --abbrev-ref HEAD)
case "$branch" in
  main|master) note_block "on '$branch' — never commit here; use a feature branch" ;;
  *)           echo "  ✓ branch: $branch" ;;
esac
if echo "$staged" | grep -qE '\.swift$' && [[ "$branch" == docs/* ]]; then
  note_warn "Swift code staged on a docs/* branch ('$branch') — name may not fit the work"
fi

echo "── 6. commit message ───────────────────────────────"
if [ -n "$MSG" ]; then
  first=$(printf '%s' "$MSG" | head -1)
  if printf '%s' "$first" | grep -qE '^(feat|fix|chore|refactor|docs|test|style|perf|build|ci)(\(.+\))?: .+'; then
    echo "  ✓ conventional: $first"
  else
    note_block "message not conventional: \"$first\" (use feat:/fix:/docs:/chore:/…)"
  fi
else
  note_warn "no message passed — pass it as arg 1 so the format gets checked"
fi

echo "── 7. debug / leftover lines (staged .swift) ───────"
dbg=$(git diff --cached --unified=0 -- '*.swift' | grep '^+' | grep -v '^+++' \
      | grep -nE '(\bprint\(|debugPrint\(|\bdump\(|// *DEBUG|FIXME)' || true)
if [ -n "$dbg" ]; then note_warn "review these added lines (may be debug leftovers):"; echo "$dbg" | sed 's/^/        /'; fi

echo "════════════════════════════════════════════════════"
echo "Blockers: $BLOCKERS    Warnings: $WARNINGS"
if [ "$BLOCKERS" -gt 0 ]; then
  echo "✘ DO NOT COMMIT — resolve the blockers above first."
  exit 1
fi
echo "✓ Safe to commit. Read any warnings above before proceeding."
exit 0
