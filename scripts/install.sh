#!/usr/bin/env bash
#
# install.sh — one-line installer for Penna (issue #30).
#
# Run with:
#   curl -fsSL https://raw.githubusercontent.com/blessed1sagar/ai-pa/main/scripts/install.sh | bash
#
# WHY this works with no "Open Anyway" dance: Gatekeeper only blocks apps that carry
# the download `com.apple.quarantine` flag, and that flag is set by the app that
# does the download (browsers, etc.) — NOT by curl. So an app fetched and unzipped
# by this script is never quarantined, and launches straight away even though Penna
# is only ad-hoc signed (no Developer ID, no notarization — a deliberate choice in
# issue #30). Belt-and-braces, we still strip the flag at the end in case a future
# transfer added it.

set -euo pipefail

REPO="blessed1sagar/ai-pa"
ASSET="Penna.zip"          # must match the release asset produced by package-app.sh
APP_NAME="Penna.app"
DEST="/Applications"

echo "Installing Penna from $REPO…"

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
