#!/usr/bin/env bash
# Remove local DropThings installs and per-user state for a clean reinstall.
#
# Usage:
#   scripts/reset-local-install.sh

set -euo pipefail

APP_BUNDLE_ID="app.dropthings"

echo "==> Quitting DropThings"
osascript -e 'tell application "DropThings" to quit' >/dev/null 2>&1 || true
pkill -x DropThings >/dev/null 2>&1 || true

echo "==> Removing installed apps"
rm -rf "/Applications/DropThings.app"
rm -rf "$HOME/Applications/DropThings.app"

echo "==> Removing app data"
rm -rf "$HOME/Library/Application Support/$APP_BUNDLE_ID"
rm -rf "$HOME/Library/Caches/$APP_BUNDLE_ID"
rm -rf "$HOME/Library/Logs/DropThings"
rm -rf "$HOME/Library/Saved Application State/$APP_BUNDLE_ID.savedState"
rm -f "$HOME/Library/Preferences/$APP_BUNDLE_ID.plist"

echo "==> Clearing UserDefaults"
defaults delete "$APP_BUNDLE_ID" >/dev/null 2>&1 || true

echo "==> Resetting privacy grants"
tccutil reset Accessibility "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
tccutil reset ScreenCapture "$APP_BUNDLE_ID" >/dev/null 2>&1 || true

echo "==> Done"
echo "DropThings local install and user state were removed."
