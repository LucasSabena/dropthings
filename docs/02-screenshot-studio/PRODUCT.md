# Product contract

## Capture modes

- Region: freeze/select across all screens with dimensions and magnification.
- Window: highlight the window under pointer, capture it without DropThings UI,
  and preserve shadow only when requested/supported.
- Display: capture one selected display, not an accidental union.
- Timed capture: optional delay for menus/popovers.
- Scrolling: select a scrollable region/target, capture increments, stitch, and
  allow cancellation with a valid partial result.

Each mode has configurable shortcuts and output actions: open editor, copy,
save, or show floating thumbnail. Shortcuts that collide must fail explicitly.

## Editor

Required tools:

- Select/move/resize, crop, arrow, line, rectangle, ellipse, freehand pencil,
  text, highlight, numbered marker, blur, and pixelate.
- Stroke/fill/color/width/font controls appropriate to the selected tool.
- Undo/redo for every mutation, including crop and delete.
- Zoom/pan without changing exported pixels.
- Copy and export PNG/JPEG; preserve alpha where the format supports it.
- Original pixels remain immutable until final render/export.

Later tools:

- Combine multiple captures on one canvas.
- Presentation backgrounds, padding, rounded corners, and shadow.
- Image overlays and opacity.
- Measurements/color inspection when a real workflow requires them.

## Local intelligence

- OCR with fast/accurate modes, language auto-detection, selectable text, copy,
  and bounding boxes.
- QR/barcode detection with explicit action before opening a URL.
- No upload or remote OCR.

## Floating and pinned images

- Short-lived post-capture thumbnail supports copy, save, edit, pin, and dismiss.
- Pinned images are borderless, movable, resizable, opacity-adjustable, and
  optionally visible on all Spaces.
- Closing a thumbnail must not delete an already saved image.

## Scrolling capture correctness

- Detect overlap from image content; never concatenate only by assumed scroll
  distance.
- Detect no movement, repeated frames, direction changes, and maximum height.
- Offer reverse scroll direction for transformed scrolling setups.
- Warn about dynamic content, video, sticky elements, and protected content.
- Preserve a partial composite on cancellation/failure when at least one valid
  frame exists.

## States and settings

- Disabled, running, needs Screen Recording, degraded, unavailable, and failed.
- Versioned settings cover shortcuts, default mode/action, format/quality, save
  folder, filename template, cursor/shadow behavior, thumbnail timeout, editor
  defaults, OCR languages, and scrolling limits.
- Permission revocation while running stops new capture and preserves open local
  editor documents.

## Explicit non-goals for replacement v1

- Screen/video/GIF recording, cloud upload, S3, translation, AI redaction,
  background removal, or team sharing.
- Silent capture of protected/DRM content.
- Pixel-identical cloning of Shottr UI/assets.
