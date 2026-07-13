# Agent runbook

## Before editing

1. Read this entire folder and root `AGENTS.md`.
2. Inspect current ScreenshotRegion code, Platform capture adapters, project
  target membership, and tests.
3. Preserve unrelated changes and select one phase slice only.
4. Repeat/extend the Lazyweb record before changing UI.
5. Update the reuse ledger before adapting MacShot/ScrollSnap code.

## Hard constraints

- Request Screen Recording only when the user enables/invokes capture.
- Accessibility is separately requested only when scrolling capture is enabled
  or first invoked; basic capture/editor must not require it.
- Capture, editor, OCR, pin, and scrolling failures remain isolated.
- No private APIs, remote upload, hidden telemetry, or silent protected-content
  workaround.
- AppKit/platform objects stay behind narrow adapters.
- Do not flatten annotations into the source until export.
- Do not declare scrolling success below the documented confidence threshold.

## Completion loop

1. Add pure/adaptor tests and minimal fixtures.
2. Implement one end-to-end slice.
3. Run targeted tests, full Swift tests, and Xcode build.
4. Perform applicable manual checks from `QUALITY.md`.
5. Inspect exported pixels at native scale.
6. Update checklists, reuse ledger, limitations, and any changed decisions.

## Stop conditions

Stop for direction before adding video/audio recording, network/cloud behavior,
AI processing, a new permission, a new binary dependency, or a design that
requires copying proprietary Shottr assets/implementation.
