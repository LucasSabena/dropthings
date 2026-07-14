# Implementation plan

## Delivery phases

1. Phase 0: characterize every current Clipboard History/Color Picker pasteboard path and add regression tests.
2. Phase 1: introduce PasteboardHub/backend and migrate Clipboard History with no behavior change.
3. Phase 2: copy-only Smart Clipboard with text, URL, JSON and color actions.
4. Phase 3: image/file actions, explicit URL title fetch and optional Accessibility paste.
5. Phase 4: pinned/per-app ordering; no automatic transforms without a separate audit.

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

- Two pasteboard observers or content-hash-only deduplication will create races/duplicates.
- Accessibility must remain optional for basic use.
- Ambiguous strings must retain general text actions.
- Logs/crash diagnostics must contain only type, size and action IDs—not content.
