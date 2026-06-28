# Release Build, Signing, and Notarization

How to take DropThings from a local debug build to a signed, notarized
distribution. The project is not App-Store-bound; direct signed + notarized
distribution matches the documented `docs/product-plan.md` path.

## Prerequisites

- Apple Developer account (the $99/year program). Personal teams work for
  ad-hoc / development but **not** for notarized `Developer ID` builds.
- `Xcode` with command-line tools selected (`xcode-select --install` plus the
  Xcode app from the App Store).
- An App Store Connect API key **or** an Apple ID with an app-specific
  password for `notarytool`.

## One-time: Configure the Xcode project for release

1. Open `App.xcodeproj`, select the `DropThings` target → **Signing & Capabilities**.
2. Set **Team** to your Apple Developer team.
3. Set **Signing Certificate** to `Developer ID Application` (not `Apple
   Distribution` — that one is for the App Store).
4. Confirm the **Bundle Identifier** is `app.dropthings`. Change it if you
   ship under a different team.
5. Hardened Runtime is already enabled (`ENABLE_HARDENED_RUNTIME = YES`).
   Leave it on; notarization rejects apps without it.

## Build the release binary

```bash
xcodebuild \
  -project App.xcodeproj \
  -scheme DropThings \
  -configuration Release \
  -derivedDataPath .build/release \
  -archivePath .build/release/DropThings.xcarchive \
  archive
```

The archive lands in `.build/release/DropThings.xcarchive`. Then:

```bash
xcodebuild \
  -exportArchive \
  -archivePath .build/release/DropThings.xcarchive \
  -exportPath .build/release/Export \
  -exportOptionsPlist .build/release/export-options.plist
```

`export-options.plist` contents:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>YOUR_10_CHAR_TEAM_ID</string>
</dict>
</plist>
```

The signed `.app` is in `.build/release/Export/DropThings.app`.

## Notarize

Pick one of the two methods below.

### Method A — App Store Connect API key (recommended for CI)

```bash
xcrun notarytool submit .build/release/Export/DropThings.app \
  --key <path-to-authkey.p8> \
  --key-id <KEY_ID> \
  --issuer <ISSUER_ID> \
  --wait
```

The `AuthKey_XXXXXX.p8` file is downloaded once from
<https://appstoreconnect.apple.com/access/integrations/api>. Keep it out of
git.

### Method B — Apple ID + app-specific password

```bash
xcrun notarytool submit .build/release/Export/DropThings.app \
  --apple-id "you@example.com" \
  --password "abcd-efgh-ijkl-mnop" \
  --team-id "YOUR_10_CHAR_TEAM_ID" \
  --wait
```

App-specific passwords live at
<https://appleid.apple.com/account/manage>.

## Staple the ticket

After notarization succeeds, staple the ticket to the `.app` so Gatekeeper
lets users open it without a network round-trip:

```bash
xcrun stapler staple .build/release/Export/DropThings.app
xcrun stapler validate .build/release/Export/DropThings.app
```

## Verify before shipping

```bash
# Code signature
codesign --verify --deep --strict --verbose=2 .build/release/Export/DropThings.app
codesign -dvv .build/release/Export/DropThings.app

# Notarization status
spctl --assess --verbose=4 --type execute .build/release/Export/DropThings.app

# Bundle structure
ls .build/release/Export/DropThings.app/Contents/MacOS/
ls .build/release/Export/DropThings.app/Contents/Frameworks/
```

`spctl` should report `accepted`. If it does not, the most common cause is a
missing or unstapled notarization ticket.

## Package as a DMG (optional)

```bash
mkdir .build/release/dmg-staging
cp -R .build/release/Export/DropThings.app .build/release/dmg-staging/
ln -s /Applications .build/release/dmg-staging/Applications
hdiutil create -volname "DropThings" \
  -srcfolder .build/release/dmg-staging \
  -ov -format UDZO \
  .build/release/DropThings.dmg
```

## What to check after release-installing

1. **First launch shows the welcome window** (until you click Skip).
2. **Menu bar icon** is the only visible UI — no dock icon.
3. **Open Settings…** opens the manually-managed window.
4. **Scroll Control** + **Menu Bar Cleaner** still need Accessibility.
   The "Request Access" button must trigger the system prompt (it now
   uses `AXIsProcessTrustedWithOptions`).
5. Run `Console.app` filtered to `subsystem: app.dropthings` — modules
   should log start/stop without permission warnings.
6. `swift test` from the source tree still passes (65 tests).

## Update flow

There is no Sparkle or auto-update yet. For v1 distribution:

1. Build, sign, notarize, staple as above with the new version.
2. Replace the old `.app` on your distribution server (S3, GitHub
   Releases, your website).
3. Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in the Xcode
   project for the next build.

If you want auto-update later, integrate Sparkle 2 (`SUFeedURL`,
`SUPublicEDKey`, `SUEnableAutomaticChecks`) and host an `appcast.xml`.

## Common failure modes

- **"The signature is not valid"** — re-run `xcodebuild archive` after
  selecting `Developer ID Application` in Signing & Capabilities. Make
  sure the keychain entry has not been revoked.
- **"notarytool failed to upload"** — check the App Store Connect API key
  is not revoked, and that the bundle identifier matches one registered
  for your team.
- **`spctl` rejects** — the ticket is missing or unstapled. Re-run
  `stapler staple`.
- **App still does not appear in System Settings → Privacy & Security →
  Accessibility** — the new build was not launched at least once with
  `AXIsProcessTrustedWithOptions({prompt: true})`. Open Settings, click
  "Request Access" on the Accessibility row; the prompt should appear.
