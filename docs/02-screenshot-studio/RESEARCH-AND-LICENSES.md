# Research and licenses

Last researched: 2026-07-14.

## Primary technical sources

- Apple ScreenCaptureKit overview:
  <https://developer.apple.com/documentation/screencapturekit>
- Apple `SCScreenshotManager` single-frame APIs:
  <https://developer.apple.com/documentation/screencapturekit/scscreenshotmanager>
- Apple ScreenCaptureKit sample and permission behavior:
  <https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos>
- Apple Vision text recognition (on-device):
  <https://developer.apple.com/documentation/vision/recognizing-text-in-images>
- Apple Core Image and pixelation:
  <https://developer.apple.com/documentation/coreimage>
  and <https://developer.apple.com/documentation/coreimage/cifilter/3228393-pixellatefilter>
- Shottr public feature/changelog reference only: <https://shottr.cc/>

## Implementation research update — 2026-07-13

- Rechecked Apple `SCScreenshotManager`: it supports capture of a single image
  using a content filter/configuration and is the planned Phase 1 adapter.
- Rechecked Apple Vision text recognition: it supports on-device recognition,
  selectable language configuration, fast/accurate modes, and observation
  bounding boxes. It remains deferred to Phase 3.
- No third-party code or assets were copied for the Phase 0 baseline.

## Open-source references inspected

### Flameshot

- Repository: <https://github.com/flameshot-org/flameshot>
- License: GPL-3.0-or-later for the main code; upstream documents separate
  licenses for icons and a small number of embedded components.
- Public feature reference: <https://flameshot.org/>
- Relevant behavior: persistent annotation tools, per-tool color/thickness,
  arrow/line/shapes/freehand/text/highlight/counter/blur/pixelate, undo/redo,
  keyboard tool selection, copy, and save.
- Decision: behavior and workflow reference only. DropThings uses an original
  Swift/AppKit implementation, SF Symbols, and no Flameshot code or assets.

### macshot

- Repository: <https://github.com/sw33tLie/macshot>
- Inspected commit: `ca1ed30c1681d3bf6d5b2fdf959b6e80a0185a24`.
- License: GPL-3.0.
- Snapshot scale: 102 Swift files, approximately 51,334 Swift lines.
- Relevant areas: `Capture/ScreenCaptureManager.swift`,
  `Capture/ScrollCaptureController.swift`, `UI/Editor`, `UI/Tools`, floating and
  pin window controllers.
- Decision: eligible for selective adaptation after the DropThings GPL change;
  never import the whole application wholesale. Preserve attribution per file.

### ScrollSnap

- Repository: <https://github.com/Brkgng/ScrollSnap>
- License: MIT according to the repository.
- Relevant idea: ScreenCaptureKit capture plus dedicated scrolling stitcher.
- Decision: research candidate only; exact commit must be recorded before reuse.

## Proprietary reference boundary

Shottr is a behavioral reference only. Do not copy its binary, resources,
branding, or implementation. Reproduce independently observable workflows with
original DropThings UI.

## Reuse ledger

No third-party source has been copied into DropThings Screenshot Studio as of
2026-07-14.

| DropThings file | Upstream repository/file | Commit | License | Modification |
| --- | --- | --- | --- | --- |
| _none_ | | | | |

Every copied/substantially adapted file must receive a row and source comment.
GPL notices must remain intact; MIT notices must accompany substantial copies.
