#!/bin/bash
# Build AllyClicker and install it to /Applications — a stable home so its icon,
# Accessibility grant, and login-item registration stay valid across rebuilds.
# Run on macOS:  ./App/install.sh
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root

App/build-app.sh

DEST="/Applications/AllyClicker.app"
echo "Installing to $DEST ..."
osascript -e 'tell application "AllyClicker" to quit' 2>/dev/null || true
killall AllyClicker 2>/dev/null || true
sleep 1
rm -rf "$DEST"
cp -R build/AllyClicker.app "$DEST"
open "$DEST"

echo "Installed and launched $DEST"
echo "Tip: re-toggle 'Launch at login' once so the login item points at /Applications."
