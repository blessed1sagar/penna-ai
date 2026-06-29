#!/usr/bin/env bash
#
# install.sh — one-line installer for Penna (issue #30).
#
# Run with:
#   curl -fsSL https://raw.githubusercontent.com/blessed1sagar/penna-ai/main/scripts/install.sh | bash
#
# WHY this works with no "Open Anyway" dance: Gatekeeper only blocks apps that carry
# the download `com.apple.quarantine` flag, and that flag is set by the app that
# does the download (browsers, etc.) — NOT by curl. So an app fetched and unzipped
# by this script is never quarantined, and launches straight away even though Penna
# is only ad-hoc signed (no Developer ID, no notarization — a deliberate choice in
# issue #30). Belt-and-braces, we still strip the flag at the end in case a future
# transfer added it.

set -euo pipefail

REPO="blessed1sagar/penna-ai"
ASSET="Penna.zip"          # must match the release asset produced by package-app.sh
APP_NAME="Penna.app"
DEST="/Applications"
MODEL="qwen2.5:7b-instruct-q4_K_M"   # must match README Requirements

# Penna is useless without a local Ollama on :11434 with the model pulled (see
# README). After install we check that's true and, if not, print copy-pasteable
# next steps. This only READS state (a curl to the local API) — it never installs
# or changes anything — and is non-fatal: a missing Ollama is a warning, not a
# failed install (issue #41).
notify_if_ollama_missing() {
  local tags
  # Ask the local Ollama server which models it has. -f makes a non-2xx status a
  # failure, -s silent, -S still surfaces real errors. When nothing is listening
  # the command fails and $tags is empty.
  if ! tags="$(curl -fsS "http://localhost:11434/api/tags" 2>/dev/null)"; then
    # Nothing is listening. Distinguish "installed but not started" (the `ollama`
    # CLI is on PATH) from "not installed at all", so we don't tell someone who
    # already has Ollama to go reinstall it.
    if command -v ollama >/dev/null 2>&1; then
      cat >&2 <<EOF

Note: Ollama is installed but not running on localhost:11434.
Penna needs it running. Start it — open the Ollama app, or run \`ollama serve\` —
then make sure the model is pulled:
  ollama pull $MODEL
EOF
    else
      cat >&2 <<EOF

Note: Ollama isn't installed (nothing is listening on localhost:11434).
Penna needs a local model to do anything. Install Ollama from https://ollama.com,
then pull the model:
  ollama pull $MODEL
EOF
    fi
    return 0
  fi

  # Server is up — is our model among the pulled ones? /api/tags lists model
  # names, so a substring match on the model name is enough.
  case "$tags" in
    *"$MODEL"*) : ;;   # present — stay quiet
    *)
      cat >&2 <<EOF

Note: Ollama is running but the model isn't pulled yet.
Penna needs it — pull it with:
  ollama pull $MODEL
EOF
      ;;
  esac
}

# Test hook: when set, stop here so a test can source this file and exercise the
# functions above without running the real installer (which writes to
# /Applications). Unset in normal use, so curl|bash runs the full flow below.
if [[ -n "${PENNA_INSTALL_TEST_SOURCE:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi

echo "Installing Penna from ${REPO}…"

# Download the asset from the LATEST release. The /releases/latest/download/<asset>
# redirect always points at the newest published release, so this needs no version
# bump here when a new Penna is released.
URL="https://github.com/$REPO/releases/latest/download/$ASSET"

TMP="$(mktemp -d)"
# Clean up the temp dir on any exit, success or failure.
trap 'rm -rf "$TMP"' EXIT

echo "Downloading $URL"
# -f fail on HTTP errors, -L follow redirects, -S show errors even when -s (silent).
curl -fSL "$URL" -o "$TMP/$ASSET"

echo "Unzipping…"
ditto -x -k "$TMP/$ASSET" "$TMP/unzipped"

SRC="$TMP/unzipped/$APP_NAME"
if [[ ! -d "$SRC" ]]; then
  echo "error: $APP_NAME not found inside $ASSET" >&2
  exit 1
fi

# Replace any existing install so re-running upgrades cleanly.
if [[ -d "$DEST/$APP_NAME" ]]; then
  echo "Removing existing $DEST/$APP_NAME"
  rm -rf "$DEST/$APP_NAME"
fi

echo "Installing to $DEST/$APP_NAME"
ditto "$SRC" "$DEST/$APP_NAME"

# Strip quarantine just in case (no-op when not set). This is the same one-time step
# the README documents for the drag-to-Applications path.
xattr -dr com.apple.quarantine "$DEST/$APP_NAME" 2>/dev/null || true

echo
echo "Done. Launch Penna with:"
echo "  open \"$DEST/$APP_NAME\""
echo "Penna lives in the menu bar (no Dock icon). Click the pencil to open it,"
echo "or press ⌃⌥P. Turn on \"Launch at login\" from its Settings if you like."

# Heads-up if the Ollama side of the requirements isn't satisfied yet.
notify_if_ollama_missing
