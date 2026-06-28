#!/usr/bin/env bash
# ⚠️  DESTRUCTIVE — wipes everything. Do NOT use this to update DropThings.
#
# Use this script ONLY when you want a complete clean slate:
#   • First-time dev setup
#   • Switching bundle IDs
#   • A settings file got corrupted and you want to start over
#
# This deletes:
#   • /Applications/DropThings.app and ~/Applications/DropThings.app
#   • ~/Library/Application Support/app.dropthings
#   • ~/Library/Caches/app.dropthings
#   • ~/Library/Logs/DropThings
#   • ~/Library/Saved Application State/app.dropthings.savedState
#   • ~/Library/Preferences/app.dropthings.plist
#   • UserDefaults for app.dropthings
#   • Accessibility (TCC) grant for app.dropthings
#
# After this, the next launch starts with onboarding again and every
# module off.
#
# For a NORMAL update that keeps your settings, use one of these instead:
#   • scripts/install-dev.sh /Applications           (dev build, preserves prefs)
#   • curl ... | sh                                 (release DMG, preserves prefs)
#   • brew upgrade --cask LucasSabena/dropthings/dropthings
#
# Usage:
#   scripts/reset-local-install.sh

set -euo pipefail

APP_BUNDLE_ID="app.dropthings"

echo "⚠️  About to wipe DropThings and all per-user state."
echo "    Type 'yes' to continue, anything else to abort:"
read -r CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    echo "Aborted. Nothing was changed."
    exit 0
fi

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

echo "==> Done"
echo "DropThings local install and user state were removed."