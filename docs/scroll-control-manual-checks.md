# Scroll Control Manual Verification

Scroll Control routes every scroll event through a `CGEventTap`, classifies the
source device, and flips the sign of the deltas for the categories the user set
to **Inverted**. The tap only works after macOS grants Accessibility
permission. Run through these checks after every change to the scroll module,
the event-tap adapter, or the transformer.

## Build + launch

1. `xcodebuild -project App.xcodeproj -scheme DropThings -configuration Debug -derivedDataPath .build/xcode build` → `** BUILD SUCCEEDED **`.
2. `open .build/xcode/Build/Products/Debug/DropThings.app`.

## Permission flow

1. Open Settings → click **Scroll Control** in the sidebar.
2. With Accessibility **not** granted yet:
   - Status pill says "Needs permission".
   - Inline alert lists Accessibility.
   - Toggle does nothing.
3. Click the `Open System Settings…` button in the permission row → macOS opens Accessibility with DropThings selected.
4. Enable the toggle next to DropThings → return to DropThings (or click the menu bar icon to bring it to front).
5. Status pill turns to "Off" or "Starting" depending on timing, then to "Running".
6. Disable Accessibility in System Settings → return to DropThings → status pill goes back to "Needs permission".

## Per-device behavior

Default settings on first run:
- Trackpad → Natural
- Mouse wheel → Inverted
- Magic Mouse → Natural

### Trackpad

1. With Trackpad = Natural, swipe two fingers up on the trackpad → page scrolls down (macOS default).
2. Switch Trackpad to Inverted, click the toggle, swipe two fingers up → page scrolls up.
3. Set the multiplier to 2.0, swipe → the page scrolls roughly twice as far per gesture.
4. Set the multiplier back to 1.0.

### Mouse wheel (external USB / Bluetooth mouse)

1. Plug in a mouse with a physical wheel.
2. With Mouse wheel = Inverted (default), scroll the wheel forward → page scrolls up (Windows-style).
3. Switch Mouse wheel to Natural → page scrolls down (macOS default).
4. With Natural, scroll fast through a long page → verify the per-tick feel matches what you get without the module.

### Magic Mouse

1. With a Magic Mouse connected, slide a finger down the touch surface → page scrolls up (Natural).
2. Switch Magic Mouse to Inverted → page scrolls down.
3. Slide horizontally → verify horizontal scroll behaves correctly for the chosen direction.

### Horizontal scroll

1. With horizontal scroll enabled, on a mouse that supports tilt-wheel or a trackpad, swipe sideways → page moves horizontally.
2. Disable horizontal scroll, repeat → page does not move horizontally. Vertical scroll still works.
3. Re-enable horizontal scroll.

## Round-trip

1. Set all three devices to **Natural** → close DropThings (`Quit` from menu bar) → reopen → settings are still Natural.
2. Set Trackpad to Inverted, Mouse wheel to Natural, Magic Mouse to Inverted → quit and reopen → the same mix is restored.
3. Reset the multiplier to 1.0, quit, reopen → the new value persists.

## Disabling restores system behavior

1. With Scroll Control running and Trackpad = Inverted, disable the toggle from the Settings → modules list.
2. Swipe on the trackpad → macOS default natural scrolling returns immediately.
3. Re-enable the module → Inverted comes back without relaunching the app.

## Logs

1. Open Console.app, filter on subsystem `app.dropthings`.
2. Start, stop, and change settings for the module → look for lines tagged `category = scroll-control`.
3. Trigger a timeout by stalling the main thread (e.g. open a 1 GB file in a SwiftUI preview while the app is running) → macOS should disable the tap briefly, then the client re-enables it. The module does not enter `failed` for this transient state.
4. No `error` lines under normal use.

## Failure / edge cases

1. Deny Accessibility → enable the module → status pill says "Needs permission"; no crashes.
2. Revoke Accessibility while the module is running → toggle off and on in Settings → state moves `Running → needsPermission → Running`.
3. Quit DropThings while the tap is active → the deinit path tears down the tap. Open Console.app → no warnings about a leaked run-loop source.

## What is NOT covered by these checks

- IOKit-based device classification (deferred — see `docs/decisions.md`).
- Hot-rebind of the multiplier mid-gesture (the transformer reads settings per event; verifying this requires scripting scroll events).
- Cross-display behavior on multi-monitor setups (the tap is session-scoped, so this should be free, but worth a manual pass).
