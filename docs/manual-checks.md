# DropThings — Manual Verification Guide

Single-page checklist covering everything built so far: the app shell, the
File Shelf, and Scroll Control. Run after every change. Per-module deep dives
live in `docs/file-shelf-manual-checks.md` and
`docs/scroll-control-manual-checks.md`.

## 0. Build + verify

```bash
swift test                          # 50 tests, must be 0 failures
xcodebuild -project App.xcodeproj \
           -scheme DropThings \
           -configuration Debug \
           -derivedDataPath .build/xcode build
open .build/xcode/Build/Products/Debug/DropThings.app
```

What you should see:

- The DropThings logo appears in the menu bar.
- No dock icon (`LSUIElement = true`).
- Clicking the menu bar icon shows `Show File Shelf` (when File Shelf is
  registered), `Open Settings…`, `Quit DropThings`.

## 1. App shell

- [ ] Sidebar in Settings lists `Modules`, `Diagnostics`, `About`, plus one
      entry per registered module under "Modules".
- [ ] Switching sidebar items updates the detail pane without flicker.
- [ ] `Diagnostics` shows the current state of every `SystemPermission`
      (Accessibility, Screen Recording, Full Disk Access, Automation) and a
      list of recent log entries (empty until you use a module).
- [ ] `About` shows the app name and native utility hub summary.

## 2. Fake module (diagnostic)

- [ ] Toggle the Fake module on → status pill shows "Running".
- [ ] Open the Fake module detail pane → it shows `Started 1 times`,
      `Stopped 0 times`.
- [ ] Toggle off → status pill returns to "Off"; counter on next toggle-on
      shows `Started 2 times`, `Stopped 1 times`.

## 3. File Shelf

Full checklist in `docs/file-shelf-manual-checks.md`. Smoke version:

- [ ] Toggle the File Shelf module on → status pill: Off → Starting → Running.
- [ ] Click `Show Shelf` in the module detail pane → the floating panel
      appears with an empty state ("Drop files, text, or URLs here").
- [ ] Drag a file from Finder onto the panel → it appears as a row.
- [ ] Press **⌥⌘S** from any app → the panel toggles open/closed.
- [ ] Click the menu bar icon → `Show File Shelf` → the panel appears.
- [ ] Right-click a file row → menu offers `Reveal in Finder`, `Copy Path`,
      `Remove from Shelf`. The first two are absent on text rows.
- [ ] Drag a row out into Finder or a text editor → Finder accepts the file,
      the editor receives the text.
- [ ] Click `Clear` → the panel empties.
- [ ] Toggle the module off → items are cleared if "Clear shelf when
      disabled" is on, kept otherwise.
- [ ] Toggle off, then on → settings (max items, clear-on-disable) are
      remembered.

Conflict case:

- [ ] Bind ⌥⌘S to another app (e.g. a Shortcuts shortcut) → enable File
      Shelf → status pill shows "Degraded" with a message about the
      conflict; the menu bar entry still works.

## 4. Scroll Control

Full checklist in `docs/scroll-control-manual-checks.md`. Smoke version:

- [ ] Toggle Scroll Control on **before** granting Accessibility → status pill
      shows "Needs permission".
- [ ] Click the `Open System Settings…` button in the Permissions section →
      Accessibility pane opens. Enable DropThings.
- [ ] If the system prompt does **not** appear, click `Request Access`
      → macOS shows its native accessibility prompt. DropThings now
      appears in System Settings → Privacy & Security → Accessibility.
- [ ] Return to DropThings → status pill moves to "Running".
- [ ] Swipe two fingers up on the trackpad with default settings (Trackpad =
      Natural) → page scrolls down.
- [ ] Switch Trackpad to Inverted → swipe up again → page scrolls up.
- [ ] Plug in an external mouse with a wheel, scroll forward with Mouse wheel
      set to Inverted (default) → page scrolls up (Windows-style).
- [ ] Switch Mouse wheel to Natural → scroll forward → page scrolls down.
- [ ] Disable the module → system scroll behavior returns immediately
      (trackpad reverts to natural, wheel to natural too).
- [ ] Disable the module, then quit DropThings → no leftover event tap
      warnings in Console.app (`subsystem app.dropthings`).

## 5. Menu Bar Cleaner

Full checklist in `docs/menu-bar-cleaner-manual-checks.md`. Smoke version:

- [ ] First launch shows the welcome window. Skip or "Enable File Shelf
      and continue". Welcome does not show again.
- [ ] Sidebar → Menu Bar Cleaner → status pill: Running after enabling.
- [ ] Two DropThings-owned menu bar controls appear: a divider and a
      chevron.
- [ ] Hold Command and drag one low-priority icon to the left of the divider.
- [ ] Click `Collapse icons` in settings or the menu bar chevron → the
      left-of-divider area moves off-screen.
- [ ] Click again → the overflow area is visible.
- [ ] Enable `Collapse on launch`, quit, reopen → the divider starts
      collapsed.
- [ ] Disable the module from the registry → divider and chevron disappear.

## 6. File Shelf pin + persistence

- [ ] Drop two files. Right-click one → `Pin`. It gets a pin badge.
- [ ] Click `Clear all` in the File Shelf settings → only the pinned item
      remains.
- [ ] Quit and reopen DropThings → the pinned item is still there.
- [ ] Inspect `~/Library/Application Support/app.dropthings/file-shelf-pinned.json`
      → JSON array of `FileShelfItem`.

## 7. Keep Awake

Full checklist in `docs/keep-awake-manual-checks.md`. Smoke version:

- [ ] Sidebar → Keep Awake → toggle on → run `pmset -g assertions` in
      Terminal → there is a `DropThings` row.
- [ ] Toggle off → the assertion row disappears.
- [ ] Switch between **System sleep** and **Display sleep only** while on
      → the assertion type changes accordingly.

## 8. Color Picker

Full checklist in `docs/color-picker-manual-checks.md`. Smoke version:

- [ ] Sidebar → Color Picker → status pill: Running after enabling.
- [ ] Click **Pick color now** (or press ⌥⌘C) → the native macOS color
      sampler opens.
- [ ] Pick a color → hex code lands on the clipboard.
- [ ] Settings shows the picked color in the **Recent colors** grid.

## 9. Settings import / export

- [ ] Menu bar icon → `Export Settings…` → choose a file → the `.plist`
      exists on disk. Run `defaults read app.dropthings` in Terminal to
      see the same data.
- [ ] Change a setting in DropThings (e.g. shake-to-show toggle).
- [ ] Menu bar icon → `Import Settings…` → choose the file you exported
      before the change → the toggle is restored to the exported value.

## 10. Logs

Console.app → filter `subsystem:app.dropthings`.

- [ ] Modules you interact with produce `info` lines with the right category
      (`file-shelf`, `scroll-control`, `menu-bar-cleaner`, `keep-awake`,
      `color-picker`).
- [ ] No `error` or `fault` lines under normal use.
- [ ] `warning` lines appear only when expected (hotkey conflict on File
      Shelf, tap timeout on Scroll Control).

## 11. Settings persistence

- [ ] Quit DropThings, reopen → every toggle and settings value is
      remembered.
- [ ] The user defaults live under suite `app.dropthings`
      (`defaults read app.dropthings` in Terminal).
- [ ] Pinned File Shelf items persist across launches from
      `~/Library/Application Support/app.dropthings/file-shelf-pinned.json`.

## 12. What to do when something fails

1. Check `Console.app` filtered to `app.dropthings` for the failing
   category. The logger writes one line per event with a useful message.
2. Cross-reference with the matching per-module manual checklist for the
   narrow set of failure modes.
3. If the app hangs or a tap does not get torn down, `killall DropThings`
   is safe; the deinit path also runs on `applicationWillTerminate`.
4. If you suspect a regression in a previous module, `swift test` is the
   fastest sanity check (50 tests, runs in under half a second).
