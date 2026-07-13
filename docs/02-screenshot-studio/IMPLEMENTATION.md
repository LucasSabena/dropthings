# Implementation plan

## Phase 0 — baseline

- [x] Make screen adapters part of testable build targets; the legacy
  `ScreenshotRegion` implementation remains excluded and is superseded by
  `ScreenshotStudio`.
- [x] Preserve a region-capture vertical slice in the new module.
- [x] Introduce `CapturedImage` metadata and async `ScreenCaptureService`.
- [x] Add explicit settings migration and typed capture errors.

Implementation note — 2026-07-13: Screenshot Studio is registered as the only
active screenshot module. Its settings migrate the existing region hotkey,
output behavior, and save folder once. Region, window-under-pointer, and
display-under-pointer actions each have independently validated shortcuts;
internal duplicate shortcuts fail before Carbon registration. The adapter is
currently a CoreGraphics compatibility implementation behind the new protocol.
The Phase 1 ScreenCaptureKit replacement must be completed before claiming the
pixel-correct mixed-scale gate.

Gate: current workflow works and can be tested without real screen capture.

## Phase 1 — complete capture workflow

- [x] Adopt ScreenCaptureKit single-frame capture, retaining a documented
  bounded fallback for region APIs unavailable before macOS 15.2.
- [x] Add window and display modes; mixed-scale live verification remains in
  the manual matrix.
- [x] Add output routing: clipboard, atomic file save, editor, thumbnail.
- [x] Add floating thumbnail and permission recovery behavior; revocation
  requires live manual verification.

Gate: region/window/display captures are pixel-correct on the manual matrix.

## Phase 2 — editor foundation

- [x] Implement document model, transforms, AppKit canvas, selection/move, and
  crop interaction. Resize handles remain a follow-up interaction refinement.
- [x] Implement renderer shared by preview/export.
- [x] Add arrow, line, rectangle, ellipse, freehand, text, highlight, marker,
  blur, and pixelate tools.
- [x] Add crop, delete, copy, save PNG/JPEG, undo/redo, and dirty-close handling.
- [x] Add blur/pixelate using Core Image with rasterized export.

Gate: reopening/exporting is unnecessary for correctness; the exported image
matches the canvas at 1x/2x and every edit is undoable.

## Phase 3 — local intelligence and utility

- [x] Vision OCR copies local results; language/presentation controls remain
  settings follow-ups.
- [x] QR/barcode recognition with safe URL confirmation.
- [x] Pin windows; presentation/background mode remains a follow-up.
- [ ] Combine captures only after the single-image document model is stable.

Gate: every feature fails independently and keeps the editor usable.

## Phase 4 — scrolling capture

- [x] Build region target selection and bounded `ScrollDriver`.
- [x] Build pure overlap/seam fixtures and confidence scoring.
- [ ] Add progress/live preview, reverse direction, cancellation, max height.
- [ ] Handle sticky headers/dynamic regions conservatively; preserve partials.
- [ ] Test browsers, Finder, chat/text apps, transformed scrolling tools, Retina,
  and mixed-scale monitors.

Gate: no false-success composite in the quality corpus; low-confidence output is
clearly marked partial/failed.

## Deferred parity

Video/GIF, uploads, translation, automatic PII detection, background removal,
and measurement tools require separate product approval and new phases.
