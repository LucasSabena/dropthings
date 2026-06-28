# Menu Bar Cleaner Manual Verification

The Menu Bar Cleaner module hides macOS menu bar icons the user does not
want to see. It uses the Accessibility API to enumerate and toggle items.
Run these checks after every change to the menu bar module, the
`MenuBarController` adapter, or the settings view.

## Build + launch

1. `xcodebuild -project App.xcodeproj -scheme DropThings -configuration Debug -derivedDataPath .build/xcode build` → `** BUILD SUCCEEDED **`.
2. `open .build/xcode/Build/Products/Debug/DropThings.app`.

## First launch + permission flow

1. Open DropThings for the first time → welcome window appears.
2. Click "Skip for now" or "Enable File Shelf and continue". Welcome does
   not appear again on subsequent launches.
3. Click menu bar icon → "Open Settings…" → Settings opens.
4. Sidebar → **Menu Bar Cleaner**.
5. Status pill says "Needs permission". The Permissions section shows
   Accessibility with state "Not granted".
6. Click **"Request Access"** → macOS shows a system dialog: "DropThings
   wants to control your computer. Allow?"
7. Click "Open System Settings" (or equivalent) → Settings → Privacy &
   Security → Accessibility opens with DropThings selected.
8. Toggle DropThings on → return to DropThings → the "Refresh menu bar"
   button is now enabled and the item list appears within seconds (we
   refresh permissions on `applicationDidBecomeActive`).

If the system prompt does not appear, see the fallback instructions in
the Permissions section of the settings page: manually open System
Settings → Privacy & Security → Accessibility → `+` → choose
`DropThings.app`.

## Discovery + per-item toggles

1. Click "Refresh menu bar" → the settings list populates with detected
   items (Wi-Fi, Battery, Spotlight, etc.).
2. Toggle one item off in the settings list → that item disappears from
   the menu bar within ~100 ms.
3. Toggle it back on → reappears at its original position.
4. Quit DropThings → reopen → your hide list is still applied.

## Reveal button

1. With at least one item hidden, look at the right side of the menu bar.
   You should see:
   - a small circular dot (separator)
   - a chevron-down icon followed by the hidden count, e.g. `▼ 3`.
2. Click the chevron → all hidden items become visible; the icon flips to
   `▲` and the count clears.
3. Click again → hidden items disappear; icon returns to `▼ 3`.
4. Quit and reopen → the reveal state is per-session (default: hidden list
   honored).

## Auto-refresh on app install / uninstall

1. Launch an app that adds a menu bar item (e.g. Spotlight, a third-party
   status app).
2. Within ~1 second, the item appears in the settings list automatically.
3. Quit that app → the item disappears from the list within ~1 second.

## Round-trip

1. Hide a few items, reveal-all, hide-again. Quit and reopen.
2. Settings persist exactly what you set.
3. Toggle "Clear unpinned" (in File Shelf) and similar across modules →
   Menu Bar Cleaner settings stay intact because they live in a different
   storage area.

## Disable the module

1. From the Modules list, toggle Menu Bar Cleaner off.
2. The separator and reveal button disappear from the menu bar.
3. Every item is restored to visible (`controller.applyHidden([])`).
4. Re-enable the module → the hide list re-applies.

## Logs

1. Open Console.app, filter `subsystem: app.dropthings category: menu-bar-cleaner`.
2. Start, refresh, hide, reveal, disable, re-enable → one info line per
   action.
3. No warnings or errors during normal use.

## Failure / edge cases

1. **Accessibility denied**: status pill stays "Needs permission", the
   reveal button is hidden (status items are not installed), the
   settings list shows the explanation copy.
2. **No menu bar items detected**: the settings list shows "Click
   Refresh menu bar to detect items." This is normal on a freshly
   installed system with very few status items.
3. **System items you cannot hide**: the toggle still works in settings,
   but the item remains visible because macOS refuses the write. We
   surface this as no error (we do not detect it explicitly). Manual
   verification: try toggling the Apple clock on/off.

## What is NOT covered by these checks

- Hover-to-reveal (deferred).
- Auto-hide after N seconds of inactivity (deferred).
- Compact mode for notch / small screens (deferred).
- Custom reveal animations (not implemented; the menu bar redraws
  immediately when items toggle visibility).
- Per-app "always hide for X" rules (would require a separate settings
  surface; not in v1).
