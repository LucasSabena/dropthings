# Screenshot Studio

This folder defines the capture and annotation module intended to replace
Shottr for the owner's actual workflows. The roadmap includes long/scrolling
capture, but basic capture and a reliable editor ship first.

## Read order

1. `PRODUCT.md`
2. `ARCHITECTURE.md`
3. `EXPERIENCE.md`
4. `IMPLEMENTATION.md`
5. `QUALITY.md`
6. `RESEARCH-AND-LICENSES.md`
7. `AGENT-RUNBOOK.md`

## Definition of done

- Region, window, and display capture are fast and pixel-correct on mixed-scale
  multi-display setups.
- The user can annotate, undo/redo, crop, redact, copy, and save without losing
  the original image.
- OCR and QR recognition run locally.
- Pinned images are dependable across Spaces.
- Scrolling capture either returns an accurate composite or a clear partial
  result; it never silently creates a misleading image.
- Capture permission is requested only after enabling or invoking the module.

## Current baseline

`ScreenshotRegionModule` already supplies a global shortcut, region-selection
overlay, screen-recording permission state, saving, and clipboard copy. It uses
a CoreGraphics capture wrapper and has no editor, window/display selection,
OCR, pinning, or scrolling stitcher.

## Delivery order

1. Modernize and test the current capture seam.
2. Complete basic capture modes and floating result thumbnail.
3. Build the non-destructive annotation editor.
4. Add local intelligence and presentation tools.
5. Add scrolling capture as a separately gated engine.
