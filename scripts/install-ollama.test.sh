#!/usr/bin/env bash
#
# Regression test for issue #41: after install, install.sh detects a missing or
# incomplete local Ollama and prints copy-pasteable guidance, without failing.
#
# We can't run the real installer here — it downloads a release and writes to
# /Applications. Instead we set PENNA_INSTALL_TEST_SOURCE, which makes install.sh
# stop right after it defines its functions (before the download/install flow),
# then we `source` it and call notify_if_ollama_missing directly with `curl`
# stubbed to fake each scenario. No network, no side effects.
#
# Runs under /bin/bash (macOS ships 3.2) to match the real `curl … | bash`
# environment and guard against the bash 3.2 traps surfaced in #38/#40.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SH="$SCRIPT_DIR/install.sh"
MODEL="qwen2.5:7b-instruct-q4_K_M"

fail() {
  echo "FAIL: $1"
  echo "--- output ---"
  echo "${2:-}"
  exit 1
}

# Run notify_if_ollama_missing under /bin/bash with a fully controlled PATH.
#   $1 = curl exit code      (non-zero => server unreachable)
#   $2 = curl stdout body    (the /api/tags JSON when reachable)
#   $3 = "yes" to put an `ollama` CLI stub on PATH (i.e. installed), else absent
# Sets globals OUT (captured output) and RC (exit status). Globals, not a $(...)
# return, so RC survives outside the command substitution.
run_check() {
  local stub
  stub="$(mktemp -d)"
  cat > "$stub/curl" <<STUB
#!/usr/bin/env bash
printf '%s' '$2'
exit $1
STUB
  chmod +x "$stub/curl"
  if [ "${3:-}" = "yes" ]; then
    printf '#!/usr/bin/env bash\n' > "$stub/ollama"
    chmod +x "$stub/ollama"
  fi
  # Pin PATH to our stubs plus the base dirs that hold cat/printf — but NOT the
  # Homebrew dirs where a real `ollama` may live, so $3 alone decides whether
  # `command -v ollama` finds anything. Without this, this machine's own Ollama
  # would leak in and the "not installed" case could never be tested.
  OUT="$(PATH="$stub:/usr/bin:/bin" PENNA_INSTALL_TEST_SOURCE=1 /bin/bash -c \
    'source "$1"; notify_if_ollama_missing' _ "$INSTALL_SH" 2>&1)"
  RC=$?
  rm -rf "$stub"
}

# --- Case 1: not installed (unreachable + no `ollama` CLI) -> install guidance ---
run_check 7 "" no
case "$OUT" in *"unbound variable"*) fail "aborted on unbound variable under bash 3.2" "$OUT";; esac
[ "$RC" -eq 0 ] || fail "expected exit 0 when Ollama unreachable, got $RC" "$OUT"
case "$OUT" in
  *"ollama pull $MODEL"*) : ;;
  *) fail "expected 'ollama pull $MODEL' guidance when Ollama unreachable" "$OUT" ;;
esac
case "$OUT" in
  *"ollama.com"*) : ;;
  *) fail "expected an ollama.com install link when Ollama isn't installed" "$OUT" ;;
esac
echo "PASS: not-installed Ollama prints install guidance and exits 0"

# --- Case 1b: installed but not running (unreachable + `ollama` CLI present) ---
# Must tell the user to START Ollama, NOT to install it again.
run_check 7 "" yes
[ "$RC" -eq 0 ] || fail "expected exit 0 when Ollama installed-but-stopped, got $RC" "$OUT"
case "$OUT" in
  *"ollama serve"*) : ;;
  *) fail "expected a 'start Ollama' hint (ollama serve) when installed but not running" "$OUT" ;;
esac
case "$OUT" in
  *"ollama.com"*) fail "should not tell an installed user to reinstall from ollama.com" "$OUT" ;;
esac
echo "PASS: installed-but-stopped Ollama prints a start hint, not an install link"

# --- Case 2: Ollama reachable WITH the model pulled -> silent, exit 0 ---
run_check 0 "{\"models\":[{\"name\":\"$MODEL\"}]}"
[ "$RC" -eq 0 ] || fail "expected exit 0 when model present, got $RC" "$OUT"
[ -z "$OUT" ] || fail "expected no output when Ollama is ready" "$OUT"
echo "PASS: ready Ollama prints nothing"

# --- Case 3: Ollama reachable but model NOT pulled -> pull guidance, exit 0 ---
run_check 0 '{"models":[{"name":"some-other-model:latest"}]}'
[ "$RC" -eq 0 ] || fail "expected exit 0 when model missing, got $RC" "$OUT"
case "$OUT" in
  *"ollama pull $MODEL"*) : ;;
  *) fail "expected 'ollama pull $MODEL' guidance when model not pulled" "$OUT" ;;
esac
echo "PASS: running Ollama without the model prints pull guidance"

echo "ALL PASS: install-ollama.test.sh"
