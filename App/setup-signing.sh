#!/bin/bash
# One-time: import a stable self-signed code-signing identity into the login
# keychain, so AllyClicker's Accessibility grant PERSISTS across rebuilds.
#
# Why: ad-hoc signing (codesign -s -) changes the code hash every build, so
# macOS TCC drops the Accessibility permission each time. A stable signing
# identity gives a stable "designated requirement" -> the grant sticks.
#
# Run this ONCE, in Terminal ON THE MAC (needs the unlocked login keychain):
#   ./App/setup-signing.sh
#
set -euo pipefail

CERT=/tmp/allycert.pem
P12=/tmp/allycert.p12
NAME="AllyClicker Self-Signed"

if [ ! -f "$P12" ]; then
    echo "ERROR: $P12 not found. (It was generated over SSH; regenerate if missing.)"
    exit 1
fi

KEYCHAIN=~/Library/Keychains/login.keychain-db

echo "Unlocking login keychain (enter your macOS login password)..."
security unlock-keychain "$KEYCHAIN"

echo "Importing identity into login keychain..."
security import "$P12" -k "$KEYCHAIN" -P allyclicker -T /usr/bin/codesign

echo "Allowing codesign to use the key without prompts..."
echo "  (enter your login password again if asked)"
security set-key-partition-list -S apple-tool:,apple: -s -k "" "$KEYCHAIN" 2>/dev/null || \
    echo "  (partition-list step skipped; codesign may prompt once — approve 'Always Allow')"

echo
echo "Done. Verify:"
security find-identity -v -p codesigning | grep "$NAME" || \
    echo "  Identity not listed yet — open Keychain Access and confirm it imported."
echo
echo "Now rebuild with:  ./App/build-app.sh"
