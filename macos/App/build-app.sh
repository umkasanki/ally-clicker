#!/bin/bash
# Assemble a runnable AllyClicker.app WITHOUT Xcode -- using Command Line Tools only.
# For quick on-device testing before the Xcode project exists. Run on macOS.
#
#   ./macos/App/build-app.sh && open macos/build/AllyClicker.app
#
set -euo pipefail
cd "$(dirname "$0")/.."   # macos/ (the Swift package root)

echo "[1/4] Building core (swift build)..."
swift build

APP="build/AllyClicker.app"
MACOS="$APP/Contents/MacOS"
echo "[2/4] Assembling $APP..."
rm -rf "$APP"
mkdir -p "$MACOS"

echo "[3/4] Compiling app layer against AppKit..."
swiftc -framework AppKit \
    -I .build/debug/Modules \
    $(find App -name "*.swift") \
    .build/debug/AllyClickerCore.build/*.o \
    -o "$MACOS/AllyClicker"

cp App/Info.plist "$APP/Contents/Info.plist"

# Version from the nearest v* tag, so a local build reads like a release: v0.2.0
# four commits on gives "0.2.0 (4)", the tag itself "0.2.0 (0)". Only the bundle's
# copy is stamped. Without git or tags (a tagless CI checkout) App/Info.plist
# stands as it is.
if DESC=$(git describe --tags --match 'v[0-9]*' 2>/dev/null); then
    TAG="${DESC%-*-g*}"
    AHEAD=0
    [ "$TAG" != "$DESC" ] && AHEAD="${DESC#"$TAG"-}" && AHEAD="${AHEAD%%-*}"
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${TAG#v}" \
                            -c "Set :CFBundleVersion $AHEAD" "$APP/Contents/Info.plist"
    echo "  version ${TAG#v} ($AHEAD)"
fi

# Bundle resources (icons etc.)
mkdir -p "$APP/Contents/Resources"
cp -R App/AllyClicker/Resources/ "$APP/Contents/Resources/"

echo "[4/4] Code signing..."
# Prefer the stable self-signed identity (Accessibility grant persists across
# rebuilds); fall back to ad-hoc if it isn't installed yet (see setup-signing.sh).
IDENTITY="AllyClicker Self-Signed"
ALLY_KC="$HOME/Library/Keychains/allyclicker.keychain-db"
# Note: a self-signed identity is untrusted (CSSMERR_TP_NOT_TRUSTED) so it never
# shows under `-v` (valid only) — but codesign can still sign with it. Detect via
# the unfiltered identity list.
if [ -f "$ALLY_KC" ] && security find-identity 2>/dev/null | grep -q "$IDENTITY"; then
    echo "  using stable identity: $IDENTITY"
    security unlock-keychain -p allyclicker "$ALLY_KC" 2>/dev/null || true
    codesign --force --sign "$IDENTITY" --keychain "$ALLY_KC" "$APP"
else
    echo "  stable identity not found -> ad-hoc (grant will reset each build)."
    echo "  run ./macos/App/setup-signing.sh once to make the grant persist."
    codesign --force --sign - "$APP"
fi

echo "Built $APP"
echo "  Launch:  open $APP"
echo "  Then grant Accessibility in System Settings and relaunch."
