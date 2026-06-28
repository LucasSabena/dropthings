# Keep Awake Manual Verification

Keep Awake holds an `IOPMAssertion` so the Mac does not sleep while the
module is on. Run these checks after every change to the module, the
adapter, or the view.

## Build + launch

1. `xcodebuild ...` → `** BUILD SUCCEEDED **`.
2. `open .build/xcode/Build/Products/Debug/DropThings.app`.

## Toggle behavior

1. Sidebar → **Keep Awake**. Status pill goes `Off → Running` once the
   module loads.
2. Toggle **Keep system awake** on → macOS stops scheduling sleep; the
   schedule in **System Settings → Energy → Battery → Schedule** is
   suppressed while the assertion is held.
3. Toggle off → the assertion is released and the system can sleep again.
4. Switch the segmented control between **System sleep** and **Display
   sleep only**. The setting is sticky: when you next turn Keep Awake on,
   the assertion uses the most recently selected reason.

## Verify the assertion is real

In Terminal:

```bash
pmset -g assertions
```

You should see a row like:

```
pid 12345(coreaudiod): PreventUserIdleSystemSleep 0000-00-00 00:00:00 ...
```

(or `PreventUserIdleDisplaySleep` if you picked "Display sleep only"). The
description contains the word `DropThings`. When you toggle off, the row
disappears.

## Edge cases

1. **Battery critical**: macOS still lets the Mac sleep if the battery is
   at the critical level, regardless of the assertion. This is by
   design.
2. **Lid close**: closing the lid still sleeps the Mac. The assertion is
   for idle timeouts, not for power state transitions.
3. **Logout / shutdown**: the assertion is released automatically when
   the user logs out or shuts down.

## Logs

1. Console.app, filter `subsystem: app.dropthings category: keep-awake`.
2. Toggle on → `Assertion acquired (systemSleep)`.
3. Toggle off → `Assertion released`.
4. Switching reasons while on → one `released` + one `acquired`.

No warnings or errors in normal use.

## What is NOT covered by these checks

- A user-customizable hotkey for Keep Awake (currently a Settings toggle
  only).
- A scheduler (e.g. "keep awake only between 9 AM and 5 PM").
