# Architecture

## Ownership

- `DropThingsModules/ScreenshotStudio` owns capture orchestration, editor
  session/model, annotations, tool state, export policy, and settings UI.
- `DropThingsPlatform` owns ScreenCaptureKit, CoreGraphics coordinate mapping,
  Accessibility/event synthesis for scrolling, Vision, pasteboard, panels, and
  filesystem adapters.
- `DropThingsDesignSystem` supplies controls/tokens; the image canvas remains an
  AppKit surface where pointer precision and performance require it.

Migrate `ScreenshotRegion` into `ScreenshotStudio`; do not leave two modules
registering overlapping shortcuts or permissions.

## Proposed components

- `CaptureCoordinator`: serializes capture sessions and state transitions.
- `ScreenCaptureService`: narrow async protocol returning `CapturedImage` plus
  scale, color space, source rect, display/window identity, and timestamp.
- `CaptureOverlayController`: selection/hit-testing only; never writes files.
- `ScreenshotDocument`: immutable source plus ordered annotation values, crop,
  presentation settings, and dirty state.
- `AnnotationCanvasView`: AppKit input, selection, handles, zoom, and drawing.
- `AnnotationRenderer`: deterministic CoreGraphics/CoreImage composition used by
  preview and export.
- `ScreenshotEditorWindowController`: native window commands, edited-state,
  save/copy/close protection, and undo manager.
- `OCRService`: async Vision adapter returning plain observations.
- `PinnedImageController`: isolated window lifecycle.
- `ScrollCaptureCoordinator`: explicit state machine around target, scroll,
  capture, alignment, stitch, progress, cancellation, and cleanup.
- `FrameAligner`: pure/testable overlap scoring and seam selection.

## Implemented baseline — 2026-07-13

- `ScreenCaptureKitService` is the default adapter for display/window captures.
  Arbitrary-region capture uses Apple's display-agnostic API on macOS 15.2+
  and a narrow CoreGraphics fallback on older supported macOS releases.
- `ScreenshotDocument`, `AnnotationCanvasView`, `AnnotationRenderer`, and
  `ScreenshotEditorWindowController` form the non-destructive editor slice.
  Annotations and crop are source-pixel values; selection UI is never rendered.
- `VisionImageRecognitionService` provides isolated on-device OCR/QR work.
- `FloatingCaptureThumbnailController` and `PinnedImageController` own their
  respective isolated window lifecycles.
- `ScrollCaptureCoordinator` owns capture cadence, cancellation, and partial
  results. It delegates input to `ScrollDriver` and never assumes scroll
  distance; `FrameAligner` is the sole seam authority.

## Image model

- Keep source `CGImage` and original color space/scale; do not round-trip through
  lossy formats while editing.
- Annotation geometry uses source-image pixel coordinates, not view coordinates.
- Convert pointer/view coordinates through one tested transform.
- Annotation values are immutable structs with stable IDs; selection/tool state
  stays outside the persisted document.
- Renderer clips effects to annotation masks and uses a bounded `CIContext`.

## Capture implementation

Use `SCScreenshotManager`/ScreenCaptureKit on macOS 14+ for display/window/single
frame capture. Keep the existing CoreGraphics wrapper only as a documented
fallback if a verified OS-specific case requires it. Exclude every DropThings
capture/editor/thumbnail/pin window from captured content where APIs allow.

## Scroll state machine

`idle → selecting → priming → capturing(frame N) → aligning → stitching →
finishing`, with terminal `cancelled`, `partial`, and `failed` states.

- A ScrollDriver adapter emits bounded events only after Accessibility is granted.
- Capture cadence waits for visual stability with a timeout; it does not sleep on
  the main actor.
- Frame alignment tries normalized cross-correlation/feature rows in a constrained
  search band and returns confidence.
- Low confidence pauses and asks whether to keep partial output.
- Cleanup releases event taps/monitors and never leaves synthetic input active.

## Persistence and failure

- Unsaved editor sessions stay in memory initially; autosave/recovery is a later
  explicit decision.
- File writes use a temporary sibling and atomic replace.
- Permission failure affects capture only, never editing existing images.
- OCR, pinning, and scrolling can degrade independently.
# Capture archive integration

- `CaptureArchive` in Core is the explicit event boundary between Screenshot
  Studio and File Shelf; modules never import each other.
- Screenshot Studio publishes a PNG for every successful capture before its
  configured output is routed. File Shelf stores it in its persistent
  `Capturas` collection.
- Native macOS screenshots enter the same collection through clipboard image
  observation or a user-selected screenshots folder. Folder observation is a
  narrow Platform adapter and starts only while File Shelf is enabled.
