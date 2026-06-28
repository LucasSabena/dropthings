#!/usr/bin/env bash
# Download and install the latest DropThings release from GitHub.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/LucasSabena/dropthings/main/scripts/install.sh | sh
#   curl ... | sh -s -- --to ~/Applications
#
# Requirements: bash 3.2+, curl, hdiutil. macOS only.

set -euo pipefail

REPO="${DROPTHINGS_REPO:-LucasSabena/dropthings}"
INSTALL_PATH="${DROPTHINGS_INSTALL_PATH:-/Applications/DropThings.app}"

usage() {
    cat <<USAGE
Usage: $0 [--to PATH] [--repo USER/REPO]

Options:
    --to PATH    Install to PATH instead of /Applications/DropThings.app
    --repo R     GitHub USER/REPO to fetch the latest release from
    -h, --help   Show this message

Environment overrides:
    DROPTHINGS_REPO         (default: LucasSabena/dropthings)
    DROPTHINGS_INSTALL_PATH  (default: /Applications/DropThings.app)
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --to)  INSTALL_PATH="$2"; shift 2 ;;
        --repo) REPO="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
    esac
done

if ! command -v curl >/dev/null 2>&1; then
    echo "curl is required. Install Xcode Command Line Tools:" >&2
    echo "  xcode-select --install" >&2
    exit 1
fi

if [[ "$(uname)" != "Darwin" ]]; then
    echo "DropThings is macOS-only." >&2
    exit 1
fi

echo "==> Fetching latest release metadata for $REPO"
META=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest")
TAG=$(echo "$META" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)
VERSION_NO_V="${TAG#v}"
if [[ -z "$TAG" ]]; then
    echo "Could not find a latest release for $REPO." >&2
    echo "Publish a GitHub release first, then re-run." >&2
    exit 1
fi

ASSET_KIND="dmg"
ASSET_URL=$(echo "$META" | grep -o '"browser_download_url": *"[^"]*\.dmg"' | head -1 | sed 's/.*"browser_download_url": *"\([^"]*\)"/\1/')
if [[ -z "$ASSET_URL" ]]; then
    ASSET_KIND="zip"
    ASSET_URL=$(echo "$META" | grep -o '"browser_download_url": *"[^"]*\.zip"' | head -1 | sed 's/.*"browser_download_url": *"\([^"]*\)"/\1/')
fi
if [[ -z "$ASSET_URL" ]]; then
    echo "Release $TAG has no .dmg or .zip asset." >&2
    exit 1
fi

TMPDIR="$(mktemp -d)"
MOUNT_DIR=""
cleanup() {
    if [[ -n "$MOUNT_DIR" && -d "$MOUNT_DIR" ]]; then
        hdiutil detach "$MOUNT_DIR" -quiet >/dev/null 2>&1 || true
    fi
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

echo "==> Downloading $ASSET_URL"
DOWNLOAD="$TMPDIR/DropThings.$ASSET_KIND"
curl -fsSL -o "$DOWNLOAD" "$ASSET_URL"

echo "==> Verifying archive"
if [[ "$ASSET_KIND" == "dmg" ]]; then
    MOUNT_DIR="$TMPDIR/mount"
    mkdir -p "$MOUNT_DIR"
    hdiutil attach "$DOWNLOAD" -mountpoint "$MOUNT_DIR" -nobrowse -quiet
    APP_SRC="$(find "$MOUNT_DIR" -maxdepth 3 -name 'DropThings.app' -type d | head -1)"
else
    if ! command -v unzip >/dev/null 2>&1; then
        echo "unzip is required to install from a .zip release asset." >&2
        exit 1
    fi
    unzip -qq -d "$TMPDIR/unzipped" "$DOWNLOAD"
    APP_SRC="$(find "$TMPDIR/unzipped" -maxdepth 3 -name 'DropThings.app' -type d | head -1)"
fi
if [[ -z "$APP_SRC" ]]; then
    echo "Archive did not contain DropThings.app" >&2
    exit 1
fi

if [[ -d "$INSTALL_PATH" ]]; then
    echo "==> Removing previous install at $INSTALL_PATH"
    rm -rf "$INSTALL_PATH"
fi

echo "==> Installing to $INSTALL_PATH"
mkdir -p "$(dirname "$INSTALL_PATH")"
cp -R "$APP_SRC" "$INSTALL_PATH"
xattr -dr com.apple.quarantine "$INSTALL_PATH" 2>/dev/null || true

echo "==> Done"
echo
echo "Installed: $INSTALL_PATH"
echo "Open with: open \"$INSTALL_PATH\""
echo
echo "Grant Accessibility from System Settings → Privacy & Security"
echo "when Scroll Control asks. The Diagnostics panel"
echo "inside DropThings shows your bundle path so you can verify the grant."
