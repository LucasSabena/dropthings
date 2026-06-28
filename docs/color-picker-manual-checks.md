# Color Picker Manual Verification

The Color Picker module samples any pixel on the screen, copies its hex
code to the clipboard, and keeps a rolling history. Run these checks after
every change to the module, the `ScreenCapture` and `PixelSampler`
adapters, or the overlay window.

## Build + launch

1. `xcodebuild ...` → `** BUILD SUCCEEDED **`.
2. `open .build/xcode/Build/Products/DropThings.app`.

## Permission flow

1. Sidebar → **Color Picker**. Status pill: Needs permission.
2. The Permissions section shows Screen Recording.
3. Click **Request Access** → macOS shows the system prompt.
4. Grant → return to DropThings → status pill: Running.
5. If the prompt does not appear, see the manual instructions printed
   in the Permissions row (System Settings → Privacy & Security →
   Screen Recording → + → DropThings).

If the dialog does not show and DropThings does not appear in the Screen
Recording list, the app is being rebuilt without your previous grant.
Quit, run `tccutil reset ScreenCapture app.dropthings` in Terminal,
relaunch DropThings, click `Request Access` again. The Diagnostics view
has the same hint inline.

## Picking a color

1. From Settings, click **Pick color now** (or press **⌥⌘C**).
2. The screen freezes into a dimmed overlay with a crosshair under the
   cursor. The cursor itself becomes a system crosshair.
3. Move the mouse — the crosshair follows.
4. Click anywhere on the screen → the overlay closes, the color is
   sampled, and the hex code lands on the clipboard.
5. Open any text editor and paste → you see something like `#3A7BC8`.

## Cancel

1. Press **⌥⌘C** again.
2. Press **ESC**.
3. Click anywhere that is not on screen (rare — but the keyboard shortcut
   covers the common case).

All three should leave you with no clipboard change and no new entry in
the history.

## History

1. Pick three different colors in a row.
2. Open Settings → Color Picker → the **Recent colors** grid shows them
   newest-first, each as a swatch with the hex code underneath.
3. Click a swatch → the hex code lands on the clipboard.
4. Right-click a swatch → **Copy #XXXXXX** or **Remove from history**.
5. Bump **Limit** up to 100 → the next pick stays; the oldest one does
   not get evicted until you cross 100.
6. Click **Clear history** → the grid empties.

## Round-trip

1. Pick two colors, quit DropThings, reopen → the grid still shows them.
2. The on-disk state lives under the Settings key
   `modules.color-picker.settings` in the `app.dropthings` suite. Run
   `defaults read app.dropthings modules.color-picker.settings` to see it.

## Logs

1. Console.app, filter `subsystem: app.dropthings category: color-picker`.
2. Each pick produces one `Picked #XXXXXX` line at `notice` level.
3. No `error` or `fault` lines during normal use.

## Failure / edge cases

1. **Screen Recording denied**: click "Pick color now" → nothing visible
   happens. Console.app shows `Pick blocked: Screen Recording not
   granted`.
2. **Multiple displays**: pick across screens → crosshair follows, click
   samples the correct pixel on whichever display is under the cursor.
3. **Permission granted but capture fails**: Console.app shows
   `Capture failed: …` and the overlay does not appear.

## What is NOT covered by these checks

- Magnifier preview around the cursor (planned for v1; v0 just samples
  the click location).
- HSL / RGB / LAB output formats. v0 always copies hex.
- Per-pixel sampling as the user moves the cursor (only on click).
