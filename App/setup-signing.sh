#!/bin/bash
# One-time: create a DEDICATED keychain holding a stable self-signed code-signing
# identity, so AllyClicker's Accessibility grant PERSISTS across rebuilds AND the
# build can sign non-interactively over SSH.
#
# Why a dedicated keychain (not login): the login keychain is GUI-managed and
# refuses non-interactive codesign access over SSH (errSecInternalComponent). A
# separate keychain with a known throwaway password can be fully unlocked and
# partition-listed from the command line. The self-signed identity gives a stable
# designated requirement, so TCC keeps the Accessibility grant.
#
# Safe to run over SSH. Re-runnable (idempotent-ish).
#
set -euo pipefail

KC="$HOME/Library/Keychains/allyclicker.keychain-db"
KCPASS="allyclicker"   # throwaway; only guards a local self-signed cert
P12=/tmp/allycert.p12

if [ ! -f "$P12" ]; then
    echo "ERROR: $P12 not found — regenerate the cert first."
    exit 1
fi

echo "[1/5] Creating dedicated keychain..."
security create-keychain -p "$KCPASS" "$KC" 2>/dev/null || echo "  (already exists)"

echo "[2/5] Unlocking + disabling auto-lock..."
security unlock-keychain -p "$KCPASS" "$KC"
security set-keychain-settings "$KC"   # no timeout, no lock-on-sleep

echo "[3/5] Importing identity (codesign-accessible)..."
security import "$P12" -k "$KC" -P allyclicker -T /usr/bin/codesign 2>&1 | tail -1 || true

echo "[4/5] Allowing codesign to use the key non-interactively..."
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KCPASS" "$KC" >/dev/null

echo "[5/5] Adding keychain to the search list..."
EXISTING=$(security list-keychains -d user | sed 's/[[:space:]]*"//; s/"$//')
if ! echo "$EXISTING" | grep -q "allyclicker.keychain"; then
    # shellcheck disable=SC2086
    security list-keychains -d user -s "$KC" $EXISTING
fi

echo
echo "Done. Identity:"
security find-identity -k "$KC" | grep "AllyClicker Self-Signed" || echo "  (not found — check import)"
echo
echo "Now rebuild:  ./App/build-app.sh"
