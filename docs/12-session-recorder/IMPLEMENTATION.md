# Implementation plan

## Delivery phases

1. Phase 0: prove audio-only ScreenCaptureKit on macOS 14, mic capture/timestamp alignment, macOS 15 mic output and decide actor versus helper.
2. Phase 1: system-audio-only M4A, permission/preflight, persistent stop route and startup recovery.
3. Phase 2: mic-only/Both, timeline/mix/headroom, pause/markers, WAV/CAF and long sync tests.
4. Phase 3: file actions, optional MP3 post-conversion, completion notification and conservative opt-in suggestions.

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

- Persistent status item cannot be hideable while recording; app shell may need a required-while-active visibility policy.
- System and mic must use sample/host timestamps and bounded drift correction—not UI arrival time.
- Suggestions remain off by default and only open preflight; they never request permission or create a file.
- Recording consent/law reminders should be neutral product copy, not legal advice.
