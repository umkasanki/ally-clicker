#!/bin/bash
# Build AllyClicker and package it as a distributable .dmg (drag-to-Applications).
# Free path — no Apple Developer account needed. The app is self-signed, NOT
# notarized, so users bypass Gatekeeper once on first launch (see README / cask).
# Run on macOS:  ./App/make-dmg.sh
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root

App/build-app.sh

APP="build/AllyClicker.app"
VER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="build/AllyClicker-$VER.dmg"
STAGE="build/dmg-stage"

echo "Packaging $DMG ..."
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"   # drag target

hdiutil create -volname "AllyClicker" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

echo "Built $DMG"
echo "SHA-256 (for the Homebrew cask):"
shasum -a 256 "$DMG"
