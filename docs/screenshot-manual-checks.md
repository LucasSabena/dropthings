# Screenshot Manual Verification

The Screenshot module captures the visible screen content and shows it in
a floating window the user can save or copy. v0 captures the whole main
screen; region selection and annotations land in v2.

## Build + launch

1. `xcodebuild ...` → `** BUILD SUCCEEDED **`.
2. `open .build/xcode/Build/Products/DropThings.app`.

## Permission flow

Same shape as Color Picker. Settings → Screenshot → Needs permission →
`Request Access` for Screen Recording → grant → status pill: Running.

## Capture + view

1. From Settings, click **Capture screen now** (or press **⌘⇧4**).
2. A new window opens showing the captured image, fitted to the window
   size.
3. The window title is `Screenshot`. It floats above your other apps.

## Save

1. In the screenshot window, click **Save…** (or press **Return**).
2. The file lands at `~/Downloads/Screenshots/DropThings-<timestamp>.png`.
   The `DropThings-<timestamp>.png` filename is repeated under the
   button in the module's settings page, so you can find it again.
3. Run `open ~/Downloads/Screenshots` in Terminal → the file is there.
4. Open the PNG in Preview → the image matches what was on screen.

## Copy

1. In the screenshot window, click **Copy**.
2. Paste into TextEdit, Slack, or any app that accepts images → the PNG
   appears.
3. Run `osascript -e 'the clipboard as «class PNGf»' | xxd | head` to
   confirm the pasteboard contains a PNG payload.

## Multi-display

1. Plug in a second display.
2. Drag a window to the secondary display.
3. Press **⌘⇧4** → the capture shows the primary display's content.
   Capturing the secondary display requires dragging it to the primary
   first (v0 limitation).

## Logs

1. Console.app, filter `subsystem: app.dropthings category: screenshot`.
2. Each capture produces `Captured full screen`. Each save produces
   `Saved  DropThings-<timestamp>.png`. Each copy produces
   `Copied screenshot to clipboard`.
3. No `error` lines during normal use.

## What is NOT covered by these checks

- Region capture (drag to select).
- Window capture (click a window to capture just it).
- Annotations: rectangles, arrows, freehand, text, color picker.
- Saving as JPEG or other formats.
- Copying to clipboard with annotation baked in.
