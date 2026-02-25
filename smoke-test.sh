#!/bin/bash
#
# Pix3lTools Deploy - Post-deploy smoke test
#
# Verifies that force-dynamic is active on pix3lboard's app/layout.tsx and that
# window.__PIX3L_CONFIG__.pix3lwikiUrl is a valid HTTPS URL, not localhost.
#
# If force-dynamic is accidentally removed from the app, Next.js pre-renders
# the layout at build time, freezing pix3lwikiUrl to whatever value was present
# during the build (typically empty or localhost). This test catches that
# regression silently before users notice the broken cross-app link.
#
# Usage:
#   ./smoke-test.sh [board_url]
#
# Examples:
#   ./smoke-test.sh https://board.example.com
#   ./smoke-test.sh http://localhost:3000
#

set -euo pipefail

BASE="${1:-http://localhost:3000}"
PASS=0
FAIL=0

green()  { printf "\033[32m%s\033[0m" "$1"; }
red()    { printf "\033[31m%s\033[0m" "$1"; }
bold()   { printf "\033[1m%s\033[0m" "$1"; }

check_pass() { echo "  $(green '✓') $1"; PASS=$((PASS + 1)); }
check_fail() { echo "  $(red '✗') $1"; FAIL=$((FAIL + 1)); }

echo ""
echo "$(bold '=== Smoke test: __PIX3L_CONFIG__ ===')"
echo "  URL: $BASE"
echo ""

# --- Fetch root page ---
HTML=$(curl -sf --max-time 10 "$BASE/" 2>/dev/null) || {
  echo "  $(red "ERROR: Could not reach $BASE")"
  echo "  Make sure the stack is running: docker compose ps"
  exit 1
}

# --- Check __PIX3L_CONFIG__ is present ---
# Expected in HTML: window.__PIX3L_CONFIG__ = {"pix3lwikiUrl":"https://..."};
CONFIG_JSON=$(echo "$HTML" | grep -o '__PIX3L_CONFIG__ = {[^}]*}' | grep -o '{[^}]*}' || true)

if [ -z "$CONFIG_JSON" ]; then
  check_fail "__PIX3L_CONFIG__ not found in page HTML"
  echo ""
  echo "  $(red 'CRITICAL: force-dynamic may have been removed from app/layout.tsx.')"
  echo "  The layout is likely pre-rendered statically at build time."
  echo "  Fix: add  export const dynamic = \"force-dynamic\"  to app/layout.tsx"
else
  check_pass "__PIX3L_CONFIG__ found in page HTML"

  # --- Extract pix3lwikiUrl ---
  WIKI_URL=$(echo "$CONFIG_JSON" | grep -oE '"pix3lwikiUrl":"[^"]+"' | cut -d'"' -f4 || true)

  if [ -z "$WIKI_URL" ]; then
    check_fail "pix3lwikiUrl field missing from __PIX3L_CONFIG__"
  else
    check_pass "pix3lwikiUrl present: $WIKI_URL"

    # Must not be localhost / loopback
    if echo "$WIKI_URL" | grep -qiE 'localhost|127\.0\.0\.1|0\.0\.0\.0'; then
      check_fail "pix3lwikiUrl contains localhost — layout is statically pre-rendered!"
      echo ""
      echo "  $(red 'CRITICAL: force-dynamic is missing. Internal URL frozen at build time.')"
      echo "  Fix: add  export const dynamic = \"force-dynamic\"  to app/layout.tsx"
    else
      check_pass "pix3lwikiUrl does not contain localhost"
    fi

    # Must use HTTPS
    if echo "$WIKI_URL" | grep -q '^https://'; then
      check_pass "pix3lwikiUrl uses HTTPS"
    else
      check_fail "pix3lwikiUrl does not use HTTPS: $WIKI_URL"
    fi
  fi
fi

# --- Summary ---
echo ""
echo "$(bold '=== Results ===')"
TOTAL=$((PASS + FAIL))
echo "  $(green "Passed: $PASS") / $TOTAL"
if [ "$FAIL" -gt 0 ]; then
  echo "  $(red "Failed: $FAIL")"
  exit 1
else
  echo "  $(green 'All checks passed!')"
fi
