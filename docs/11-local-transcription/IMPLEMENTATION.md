# Implementation plan

## Delivery phases

1. Phase 0: pin/build whisper.cpp, measure Tiny/Base/Small Spanish/English, prove helper packaging/cancel/crash and decide Metal/Core ML policy.
2. Phase 1: TranscriptionKit, model manager, one WAV/PCM vertical slice and TXT/JSON.
3. Phase 2: shared broad-media normalization, batch queue, persistence and SRT/VTT/Markdown.
4. Phase 3: VAD, review/playback, file actions, Finder/Command Palette and recorder handoff.

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

- Pin exact whisper.cpp/model/VAD artifacts, versions, checksums, licenses and build flags.
- Do not claim resume unless a real checkpoint format exists; interrupted jobs restart honestly.
- Core ML is optional until generation/distribution is reproducible.
- Do not add diarization without separate model/license/privacy research.
