#!/usr/bin/env bash
# Build a normal macOS drag-to-Applications DMG for DropThings.
#
# Usage:
#   scripts/build-dmg.sh
#   scripts/build-dmg.sh --skip-build
#
# Output:
#   .build/dist/DropThings-<version>.dmg

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/.build/dmg-build"
DIST_DIR="$PROJECT_ROOT/.build/dist"
STAGING_DIR="$DIST_DIR/dmg-staging"
APP_PATH="$BUILD_DIR/Build/Products/Release/DropThings.app"

SKIP_BUILD=false
if [[ "${1:-}" == "--skip-build" ]]; then
    SKIP_BUILD=true
elif [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    sed -n '1,14p' "$0"
    exit 0
elif [[ $# -gt 0 ]]; then
    echo "Unknown argument: $1" >&2
    exit 1
fi

cd "$PROJECT_ROOT"

if [[ "$SKIP_BUILD" != true ]]; then
    echo "==> Building Release configuration"
    xcodebuild \
        -project App.xcodeproj \
        -scheme DropThings \
        -configuration Release \
        -derivedDataPath "$BUILD_DIR" \
        -quiet \
        build
fi

if [[ ! -d "$APP_PATH" ]]; then
    echo "Missing app at $APP_PATH" >&2
    echo "Run scripts/build-dmg.sh without --skip-build first." >&2
    exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
DMG_PATH="$DIST_DIR/DropThings-$VERSION.dmg"

echo "==> Staging DMG"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/DropThings.app"
ln -s /Applications "$STAGING_DIR/Applications"

echo "==> Creating $DMG_PATH"
mkdir -p "$DIST_DIR"
rm -f "$DMG_PATH"
hdiutil create \
    -volname "DropThings" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null

echo "==> Verifying DMG"
hdiutil verify "$DMG_PATH" >/dev/null

echo "==> Done"
echo "DMG: $DMG_PATH"
echo "SHA256: $(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
