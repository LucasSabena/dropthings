# Implementation plan

## Delivery phases

1. Phase 0: compare SwiftUI Canvas, custom AppKit/layer-backed and hybrid approaches on 300 mixed items; prove atomic package recovery.
2. Phase 1: schema/package/recovery, library, pan/zoom/selection, text/image/file/basic shapes and undo.
3. Phase 2: notes, arrows, freehand, frames, groups, alignment, search, fragments and accessible Outline.
4. Phase 3: file actions, URL metadata, templates, presentation and PNG/PDF/frame export.

## Repository work expected

- Add module source folder and module-focused tests.
- Add only justified Core/Platform/shared-kit abstractions.
- Add ModuleID, icon mapping and settings navigation.
- Add Info.plist usage strings/entitlements only when the selected feature requires
  them.
- Update root README inventory, product docs, third-party notices and release
  packaging in the same change.
- Register in `AppServices` only after the Quality release gate has evidence.

## Engineering rules

- Start with the smallest end-to-end vertical slice.
- Inject file system, clocks, permissions, process/helper clients and platform
  adapters.
- Do not add an abstraction for imaginary future products; shared abstractions in
  this plan are justified by at least two real modules.
- Add a regression test before fixing each discovered failure.
- No `npm`; use native Swift/SwiftUI/AppKit and pinned native dependencies.
- Do not use `/bin/sh -c` with user data.

## Stop conditions

- Autosave must never write every pointer sample or replace a valid package with a partial one.
- Unknown future item types should be preserved or opened read-only, not silently discarded.
- Undo/image memory needs strict budgets and downsampling.
- Do not commit private/client assets as fixtures.
