#!/usr/bin/env bash
# Install DropThings as a real .app for manual testing.
#
# This is the dev install path. It produces an unsigned (or ad-hoc signed)
# binary; macOS will prompt the first time the user opens it. For
# notarized distribution see docs/RELEASE.md.
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

cd "$PROJECT_ROOT"

echo "==> Building Release configuration"
xcodebuild \
    -project App.xcodeproj \
    -scheme DropThings \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
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
echo "If macOS refuses to open it (unidentified developer):"
echo "  Right-click DropThings.app in Finder -> Open -> Open."
echo "  You only need to do this once per build."
echo
echo "Run 'pmset -g assertions' in Terminal while DropThings is running to"
echo "see which power-management assertions are active."
