#!/usr/bin/env bash
#
# package-app.sh — zip a built Release Penna.app for a GitHub Release (issue #30).
#
# WHY this exists: Penna ships ad-hoc signed (Xcode "Sign to Run Locally"), with NO
# Developer ID and NO notarization (a deliberate decision in issue #30). Gatekeeper
# only blocks apps that carry the download `com.apple.quarantine` flag. A zip the
# user downloads from a browser gets quarantined; the README documents the one-time
# `xattr` strip for that path, and install.sh avoids quarantine entirely via curl.
#
# This script CANNOT build the binary — a Release build needs an Xcode GUI build on
# your Mac. It takes an already-built Penna.app and produces Penna.zip ready to
# attach to a GitHub Release. The manual build + upload steps it can't do are
# printed at the end.
#
# Usage:
#   scripts/package-app.sh <path-to-Penna.app> [output-dir]
#
# Example:
#   scripts/package-app.sh ~/Library/Developer/Xcode/DerivedData/Penna-*/Build/Products/Release/Penna.app dist

set -euo pipefail

APP_PATH="${1:-}"
OUT_DIR="${2:-dist}"

if [[ -z "$APP_PATH" ]]; then
  echo "error: pass the path to a built Penna.app" >&2
  echo "usage: $0 <path-to-Penna.app> [output-dir]" >&2
  exit 1
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: '$APP_PATH' is not a directory — expected a Penna.app bundle" >&2
  exit 1
fi

if [[ "$(basename "$APP_PATH")" != *.app ]]; then
  echo "error: '$APP_PATH' does not look like a .app bundle" >&2
  exit 1
fi

ZIP_PATH="$OUT_DIR/Penna.zip"

mkdir -p "$OUT_DIR"
rm -f "$ZIP_PATH"

# `ditto -c -k --keepParent` is Apple's recommended way to zip an .app: it preserves
# the bundle structure, symlinks, and resource forks that a plain `zip` can mangle —
# which matters because a mangled bundle won't launch. --keepParent keeps the
# Penna.app directory as the top-level entry inside the zip.
echo "Zipping $APP_PATH -> $ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

# Surface the signature so you can confirm it's at least ad-hoc signed. An UNSIGNED
# app won't launch at all on Apple Silicon; ad-hoc ("Signature=adhoc") is what Xcode
# "Sign to Run Locally" produces and is all Penna needs.
echo
echo "Signature check:"
codesign -dv "$APP_PATH" 2>&1 | grep -E "Signature|Identifier" || true

SIZE="$(du -h "$ZIP_PATH" | cut -f1)"
echo
echo "Done: $ZIP_PATH ($SIZE)"
echo
cat <<'EOF'
─────────────────────────────────────────────────────────────────────
Manual steps this script can't do (need Xcode GUI / your GitHub login):

1. Build the Release app in Xcode (if you haven't already):
     open Penna/Penna.xcodeproj
     Product ▸ Scheme ▸ Edit Scheme… ▸ Run ▸ Build Configuration = Release
     Product ▸ Build  (⌘B)
   Then find the built app under DerivedData, e.g.:
     ~/Library/Developer/Xcode/DerivedData/Penna-*/Build/Products/Release/Penna.app
   and re-run this script with that path.

2. Create / edit a GitHub Release and attach dist/Penna.zip, e.g. with gh:
     gh release create v1.0.0 dist/Penna.zip \
       --repo blessed1sagar/ai-pa \
       --title "Penna v1.0.0" \
       --notes "Download Penna.zip, unzip, and see the README install steps."
   (or upload Penna.zip via the GitHub Releases web UI).

3. The one-line installer (scripts/install.sh) downloads the release asset named
   exactly "Penna.zip". Keep that asset name, or update install.sh's ASSET var.
─────────────────────────────────────────────────────────────────────
EOF
