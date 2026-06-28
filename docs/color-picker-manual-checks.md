# Color Picker Manual Verification

The Color Picker module uses AppKit's native macOS color sampler, copies the
picked color as HEX, and keeps a rolling history.

## Build + launch

1. `xcodebuild ...` -> `** BUILD SUCCEEDED **`.
2. `open .build/xcode/Build/Products/Debug/DropThings.app`.

## Enable

1. Sidebar -> **Color Picker**.
2. Enable the module.
3. Status pill becomes `Running`.
4. No Screen Recording permission is requested.

## Picking a color

1. From Settings, click **Pick color now** or press **⌥⌘C**.
2. The native macOS color sampler opens.
3. Pick a color anywhere on screen.
4. Open any text editor and paste -> you see something like `#3A7BC8`.
5. Settings -> Color Picker shows the picked color in **Recent colors**.

## Cancel

1. Open the sampler.
2. Cancel with Escape or by leaving the sampler without choosing a color.
3. Clipboard and history remain unchanged.

## History

1. Pick three different colors in a row.
2. The **Recent colors** grid shows them newest-first.
3. Click a swatch -> the hex code lands on the clipboard.
4. Right-click a swatch -> **Copy #XXXXXX** or **Remove from history**.
5. Bump **Limit** up to 100 -> the next pick stays; oldest entries are not
   evicted until the limit is crossed.
6. Click **Clear history** -> the grid empties.

## Round-trip

1. Pick two colors, quit DropThings, reopen -> the grid still shows them.
2. The on-disk state lives under the Settings key
   `modules.color-picker.settings` in the `app.dropthings` suite.

## Logs

1. Console.app, filter `subsystem: app.dropthings category: color-picker`.
2. Each pick produces one `Picked #XXXXXX` line at `notice` level.
3. Cancel produces `Picking cancelled`.
4. No `error` or `fault` lines during normal use.

## Not covered

- Magnifier preview around the cursor.
- RGB/HSL/LAB output formats.
- Palette naming or nearest-color suggestions.
