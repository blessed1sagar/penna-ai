#!/usr/bin/env bash
#
# Regression test for the curl|bash one-liner aborting under macOS's system bash.
#
# THE BUG (issue #38): macOS ships bash 3.2.57, which is not multibyte-aware when
# parsing a variable name. A non-ASCII byte glued directly to a $variable — e.g.
# "$REPO…" — gets read as PART OF the variable name, so bash looks up a variable
# whose name includes the ellipsis bytes. Under `set -u` that is an unbound
# variable and the installer dies on the very first echo, before downloading
# anything. The one-line installer therefore never worked on a clean Mac.
#
# This test reproduces the real failure environment by running install.sh under
# /bin/bash (always 3.2 on macOS — exactly what `curl … | bash` resolves to on a
# clean machine) with `curl` stubbed to fail at the download step. The stub fails
# AFTER the variable-expansion lines but BEFORE any /Applications write, so the
# test has no side effects. It asserts the installer reached the download step
# instead of aborting on an unbound variable.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SH="$SCRIPT_DIR/install.sh"

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

# Stub curl: print a sentinel proving the download step was reached, then exit
# non-zero so install.sh's `set -e` stops it before it touches /Applications.
cat > "$SANDBOX/curl" <<'STUB'
#!/usr/bin/env bash
echo "STUB_CURL_REACHED"
exit 22
STUB
chmod +x "$SANDBOX/curl"

output="$(PATH="$SANDBOX:$PATH" /bin/bash "$INSTALL_SH" 2>&1 || true)"

fail() {
  echo "FAIL: $1"
  echo "--- installer output ---"
  echo "$output"
  exit 1
}

case "$output" in
  *"unbound variable"*)
    fail "installer aborted on an unbound variable (bash 3.2 multibyte-in-varname bug)" ;;
esac

case "$output" in
  *STUB_CURL_REACHED*) : ;;
  *) fail "installer never reached the download step" ;;
esac

echo "PASS: installer passes variable expansion and reaches the download step"
