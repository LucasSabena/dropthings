# Implementation plan

## Delivery phases

1. Phase 0: spike native capabilities and universal FFmpeg packaging; decide exact configure flags, licenses, signing and source-release process.
2. Phase 1: MediaKit models plus native image-only vertical slice, safe naming, resizing, metadata and re-probe.
3. Phase 2: Simple/Advanced image UX, queue, cancellation, Finder/Command Palette and file actions.
4. Phase 3: isolated FFmpeg helper plus audio and transcription-normalization operations.
5. Phase 4: video, stream/subtitle policy, hardware encoder selection and long-file testing.

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

- FFmpeg must be pinned and reproducibly built; publish exact source, configure line, patches, checksums and notices.
- Do not expose a setting the chosen backend ignores.
- Do not finalize an output before successful re-probe.
- Replace-original stays disabled until rollback/recovery is proven.
