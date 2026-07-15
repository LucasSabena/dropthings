# Agent runbook

## Mission

Implement Media Converter as the smallest safe vertical slice that satisfies its product
contract. Do not register half-finished behavior in the shipping app.

## Read first

1. Repository `AGENTS.md`.
2. This folder in README order.
3. `docs/architecture/DESIGN-SYSTEM-PLATFORM-DEPENDENCY.md`.
4. `docs/architecture/NEW-MODULES-INTEGRATION-MAP.md`.
5. Existing comparable module/helper/tests.

## Work order

1. Phase 0: spike native capabilities and Apple Silicon FFmpeg packaging; decide exact configure flags, licenses, signing and source-release process.
2. Phase 1: MediaKit models plus native image-only vertical slice, safe naming, resizing, metadata and re-probe.
3. Phase 2: Simple/Advanced image UX, queue, cancellation, Finder/Command Palette and file actions.
4. Phase 3: isolated FFmpeg helper plus audio and transcription-normalization operations.
5. Phase 4: video, stream/subtitle policy, hardware encoder selection and long-file testing.

## PR discipline

- Keep pure models, platform adapters, UI and helper/process boundaries separate.
- Include tests and documentation in every behavior/architecture change.
- Split risky helpers/dependencies from the final registration/release PR.
- Attach measured evidence, not assertions.

## Commands before each PR

- `swift test --parallel`
- Debug `xcodebuild` for DropThings and any new helper.
- Release `xcodebuild` for DropThings and any new helper.
- Deep signature/bundle verification when packaging changes.
- Product-specific manual checks from `QUALITY.md`.

## Stop and escalate

- FFmpeg must be pinned and reproducibly built; publish exact source, configure line, patches, checksums and notices.
- Do not expose a setting the chosen backend ignores.
- Do not finalize an output before successful re-probe.
- Replace-original stays disabled until rollback/recovery is proven.

## Progress (2026-07-15)

All phases (0–4) are implemented and the module is **registered** in `AppServices`.
FFmpeg is reproducibly built and bundled.

- **Phase 0 — done.** FFmpeg 8.1.2 (LGPL-2.1+) pinned, reproducibly built by
  `scripts/build-ffmpeg.sh`, and embedded at
  `MediaConverterEngine.xpc/Contents/SharedSupport/FFmpeg/`. No GPL components,
  no external libraries (VideoToolbox/AudioToolbox only). Full provenance in
  `RESEARCH-AND-LICENSES.md`.
- **Phase 1 — done.** `DropThingsMediaConverterKit` + native image probe/encode
  adapters. Safe naming, re-probe before finalize, atomic move.
- **Phase 2 — done.** Simple/Advanced image UX, queue with throttled progress,
  cancellation, Command Palette command, cross-module "Convert" action via
  `FileActionRegistry`.
- **Phase 3 — done.** Isolated `MediaConverterEngine` XPC helper executes
  FFmpeg out-of-process; `MediaConverterEngineService` runs typed argv with
  `Process` (never a shell); `ffprobe` powers richer media probing.
- **Phase 4 — done.** Video (H.264 via `h264_videotoolbox`), audio
  (AAC/FLAC/Opus/WAV), and the pipeline routing for audio/video through the
  helper. Capability manifest hides MP3/WebM (external libs not bundled).

### Remaining QUALITY gate

The module is registered and compiles, but the QUALITY.md release gate still
requires before tagging a release:

1. Manual matrix: corrupt/huge/hostile-name files; permission deny/grant/revoke;
   keyboard-only/VoiceOver/Reduce Motion; sleep/wake; low disk.
2. 1,000 start/cancel cycles leave no helper/child process; 24-hour mixed
   queue leaves no growing temp storage.
3. Seven days of owner daily use for the core workflow.
4. Evidence recorded (hardware/macOS/Xcode versions, screenshots of every state).
