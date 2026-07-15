#!/usr/bin/env bash
# Install DropThings as a real .app for manual testing.
#
# This is the dev install path. When a Developer ID Application or Apple
# Development identity exists in Keychain, the script reuses it so macOS sees
# a stable code identity across local updates. Without one, the build remains
# ad-hoc and Accessibility must be granted again after each changed build.
#
# Usage:
#   scripts/install-dev.sh                # install to /Applications
#   scripts/install-dev.sh ~/Applications # install to a custom path
#   scripts/install-dev.sh --build-only   # just build, do not install

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "Usage: scripts/install-dev.sh [install-path] | --build-only"
    exit 0
fi

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/.build/release-install"
APP_PATH="$BUILD_DIR/Build/Products/Release/DropThings.app"
INSTALL_PATH="${1:-/Applications/DropThings.app}"
SIGNING_IDENTITY="${DROPTHINGS_SIGNING_IDENTITY:-}"

cd "$PROJECT_ROOT"

echo "==> Building Release configuration"
xcodebuild \
    -project App.xcodeproj \
    -scheme DropThings \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    -destination 'generic/platform=macOS' \
    ARCHS=arm64 \
    -quiet \
    build

if [[ "${1:-}" == "--build-only" ]]; then
    echo "==> Built $APP_PATH"
    echo "Run scripts/install-dev.sh again without --build-only to install."
    exit 0
fi

if [[ ! -d "$APP_PATH" ]]; then
    echo "Build did not produce $APP_PATH" >&2
    exit 1
fi

echo "==> Thinning embedded frameworks to Apple Silicon"
while IFS= read -r -d '' binary; do
    ARCHITECTURES="$(lipo -archs "$binary" 2>/dev/null || true)"
    if [[ "$ARCHITECTURES" == *arm64* && "$ARCHITECTURES" == *x86_64* ]]; then
        THINNED="${binary}.arm64"
        lipo "$binary" -thin arm64 -output "$THINNED"
        chmod "$(stat -f '%Lp' "$binary")" "$THINNED"
        mv "$THINNED" "$binary"
    fi
done < <(find "$APP_PATH" -type f -perm -111 -print0)

if [[ -z "$SIGNING_IDENTITY" ]]; then
    AVAILABLE_IDENTITIES="$(security find-identity -v -p codesigning 2>/dev/null || true)"
    SIGNING_IDENTITY="$(printf '%s\n' "$AVAILABLE_IDENTITIES" | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' | head -1)"
    if [[ -z "$SIGNING_IDENTITY" ]]; then
        SIGNING_IDENTITY="$(printf '%s\n' "$AVAILABLE_IDENTITIES" | sed -n 's/.*"\(Apple Development:[^"]*\)".*/\1/p' | head -1)"
    fi
fi

if [[ -n "$SIGNING_IDENTITY" ]]; then
    echo "==> Re-signing with stable identity: $SIGNING_IDENTITY"
    FFMPEG_DIR="$APP_PATH/Contents/XPCServices/MediaConverterEngine.xpc/Contents/SharedSupport/FFmpeg"
    for executable in "$FFMPEG_DIR/ffmpeg" "$FFMPEG_DIR/ffprobe"; do
        [[ ! -f "$executable" ]] || codesign --force --options runtime --sign "$SIGNING_IDENTITY" "$executable"
    done
    while IFS= read -r bundle; do
        codesign --force --options runtime --deep --sign "$SIGNING_IDENTITY" "$bundle"
    done < <(find "$APP_PATH/Contents/XPCServices" -type d -name '*.xpc' -print 2>/dev/null)
    while IFS= read -r framework; do
        codesign --force --options runtime --deep --sign "$SIGNING_IDENTITY" "$framework"
    done < <(find "$APP_PATH/Contents/Frameworks" -type d -name '*.framework' -print 2>/dev/null)
    codesign --force --options runtime --deep \
        --entitlements "$PROJECT_ROOT/App/DropThings.entitlements" \
        --sign "$SIGNING_IDENTITY" "$APP_PATH"
    codesign --verify --deep --strict --verbose "$APP_PATH"
else
    echo "==> WARNING: no code-signing identity is installed"
    echo "    This build is ad-hoc. macOS ties Accessibility to this exact build,"
    echo "    so changing and reinstalling it will require granting access again."
    echo "    A reboot alone will not. Install a stable signing identity to preserve TCC grants."
fi

echo "==> Removing previous install (if any)"
if [[ -d "$INSTALL_PATH" ]]; then
    rm -rf "$INSTALL_PATH"
fi

echo "==> Copying to $INSTALL_PATH"
mkdir -p "$(dirname "$INSTALL_PATH")"
cp -R "$APP_PATH" "$INSTALL_PATH"

echo "==> Removing quarantine attribute"
xattr -dr com.apple.quarantine "$INSTALL_PATH" 2>/dev/null || true

echo "==> Done"
echo
echo "Open DropThings from:"
echo "  $INSTALL_PATH"
echo
echo "If macOS refuses to open an ad-hoc build (unidentified developer):"
echo "  Right-click DropThings.app in Finder -> Open -> Open."
echo "  You only need to do this once per build."
echo
echo "Run 'pmset -g assertions' in Terminal while DropThings is running to"
echo "see which power-management assertions are active."
