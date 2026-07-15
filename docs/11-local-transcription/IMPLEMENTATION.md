# Implementation plan

## Current status — 2026-07-15

Broad-media normalization is now part of the vertical slice. Intake does not
filter by extension: the pinned FFmpeg 8.1.2 helper extracts the first/primary
audio stream from audio or video containers and produces a temporary 16 kHz,
mono, signed-16-bit PCM WAV before Whisper runs. This covers Opus/Ogg, MP3,
M4A/AAC, WAV, FLAC, MKV, MP4, MOV, WebM and the other demuxers/decoders present
in the shipped manifest. Temporary normalized audio is deleted after success,
failure or cancellation. A file with no decodable audio stream fails explicitly.
Cancellation now maps to Cancelled rather than a helper failure and terminates
both XPC operations. Queue traversal uses stable item identities, so adding or
removing other waiting files during a transcription cannot invalidate indices.

The Phase 1 vertical slice is implemented, packaged and registered in `AppServices`:

- Foundation-only `DropThingsTranscriptionKit` owns the versioned request,
  transcript/model schemas, strict WAV inspection and atomic TXT/JSON export.
- `TranscriptionEngine.xpc` owns the whisper context and inference. The host uses a
  versioned `Data`-based XPC contract, validates job identity and maps typed failures
  without exposing whisper.cpp to the app process.
- `DropThingsWhisperEngine` links the official whisper.cpp v1.9.1
  XCFramework and uses Metal where available. Core ML is not bundled or required.
- The module owns a sequential queue, typed settings, a dedicated keyboard-usable
  window and explicit model download/import/delete actions.
- Tiny/Base/Small downloads use `.partial` staging, exact byte counts, SHA-256
  verification, atomic replacement and active-job leases.
- File transcription requests no microphone or screen permission. Network access
  occurs only after an explicit model Download action.

The packaged helper and a real Tiny-model fixture have been proven. Queue
persistence, SRT/VTT/Markdown, VAD and review remain explicitly in Phases 2–3.

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
