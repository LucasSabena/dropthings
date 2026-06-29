#!/usr/bin/env bash
# Build, sign, notarize, and stage a Sparkle-ready release for DropThings.
#
# Usage:
#   scripts/release.sh
#
# Environment:
#   DEVELOPER_ID      — "Developer ID Application: Your Name (TEAM_ID)". If unset,
#                       the build is ad-hoc signed (Gatekeeper will warn).
#   APPLE_ID          — Apple ID for notarization (required with DEVELOPER_ID).
#   APP_SPECIFIC_PASSWORD — app-specific password for notarization.
#   TEAM_ID           — Apple Developer Team ID for notarization.
#
# Output:
#   .build/dist/DropThings-<version>.dmg
#   .build/dist/appcast.xml

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/.build/release-build"
DIST_DIR="$PROJECT_ROOT/.build/dist"
APP_PATH="$BUILD_DIR/Build/Products/Release/DropThings.app"

cd "$PROJECT_ROOT"

echo "==> Building Release configuration"
xcodebuild \
    -project App.xcodeproj \
    -scheme DropThings \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    build

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP_PATH/Contents/Info.plist")
DMG_PATH="$DIST_DIR/DropThings-$VERSION.dmg"
ZIP_PATH="$DIST_DIR/DropThings-$VERSION.zip"

echo "==> Version $VERSION (build $BUILD)"

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# Sign the app. With a Developer ID we sign with that identity (Gatekeeper
# clean). Without one we sign ad-hoc; the app's entitlements carry
# com.apple.security.cs.disable-library-validation so dyld accepts the
# ad-hoc-signed embedded Sparkle.framework despite the Team-ID mismatch
# that Hardened Runtime library validation would otherwise reject.
#
# Sparkle.framework must be re-signed in the same pass as the app so both
# share a consistent signature. `--deep` walks nested code; we sign the
# framework explicitly first to guarantee it is covered even if `--deep`
# is ever removed.
ENTITLEMENTS="$PROJECT_ROOT/App/DropThings.entitlements"
if [[ -n "${DEVELOPER_ID:-}" ]]; then
    echo "==> Signing app with $DEVELOPER_ID"
    codesign --force --options runtime --deep --sign "$DEVELOPER_ID" "$APP_PATH"
else
    echo "==> No DEVELOPER_ID set; ad-hoc signing (Gatekeeper will warn)"
    codesign --force --options runtime --sign - \
        "$APP_PATH/Contents/Frameworks/Sparkle.framework"
    codesign --force --options runtime \
        --entitlements "$ENTITLEMENTS" --sign - "$APP_PATH"
fi
codesign --verify --verbose "$APP_PATH"

echo "==> Creating DMG"
STAGING_DIR="$DIST_DIR/dmg-staging"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/DropThings.app"
ln -s /Applications "$STAGING_DIR/Applications"
hdiutil create \
    -volname "DropThings" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null

echo "==> Creating Sparkle ZIP"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

# Notarize and staple if credentials are present.
if [[ -n "${DEVELOPER_ID:-}" && -n "${APPLE_ID:-}" && -n "${APP_SPECIFIC_PASSWORD:-}" && -n "${TEAM_ID:-}" ]]; then
    echo "==> Notarizing DMG"
    xcrun notarytool submit "$DMG_PATH" \
        --apple-id "$APPLE_ID" \
        --password "$APP_SPECIFIC_PASSWORD" \
        --team-id "$TEAM_ID" \
        --wait
    xcrun stapler staple "$DMG_PATH"

    echo "==> Notarizing ZIP"
    xcrun notarytool submit "$ZIP_PATH" \
        --apple-id "$APPLE_ID" \
        --password "$APP_SPECIFIC_PASSWORD" \
        --team-id "$TEAM_ID" \
        --wait
else
    echo "==> Skipping notarization (set APPLE_ID, APP_SPECIFIC_PASSWORD, TEAM_ID)"
fi

echo "==> Generating appcast.xml"
# Sparkle cannot generate an appcast when both a ZIP and a DMG with the
# same bundle version exist. The ZIP is what Sparkle downloads for updates;
# the DMG is for manual installation. Generate the appcast from the ZIP.
APPCAST_DIR="$DIST_DIR/appcast-input"
rm -rf "$APPCAST_DIR"
mkdir -p "$APPCAST_DIR"
cp "$ZIP_PATH" "$APPCAST_DIR/"
"$PROJECT_ROOT/.build/release-build/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast" \
    --download-url-prefix "https://github.com/LucasSabena/dropthings/releases/download/v$VERSION/" \
    "$APPCAST_DIR"
mv "$APPCAST_DIR/appcast.xml" "$DIST_DIR/appcast.xml"
rm -rf "$APPCAST_DIR"

echo "==> Verifying DMG"
hdiutil verify "$DMG_PATH" >/dev/null

echo "==> Done"
echo "DMG: $DMG_PATH"
echo "ZIP: $ZIP_PATH"
echo "SHA256: $(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
