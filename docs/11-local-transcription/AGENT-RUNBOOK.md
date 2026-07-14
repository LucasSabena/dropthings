# Agent runbook

## Mission

Implement Local Transcription as the smallest safe vertical slice that satisfies its product
contract. Do not register half-finished behavior in the shipping app.

## Read first

1. Repository `AGENTS.md`.
2. This folder in README order.
3. `docs/architecture/DESIGN-SYSTEM-PLATFORM-DEPENDENCY.md`.
4. `docs/architecture/NEW-MODULES-INTEGRATION-MAP.md`.
5. Existing comparable module/helper/tests.

## Work order

1. Phase 0: pin/build whisper.cpp, measure Tiny/Base/Small Spanish/English, prove helper packaging/cancel/crash and decide Metal/Core ML policy.
2. Phase 1: TranscriptionKit, model manager, one WAV/PCM vertical slice and TXT/JSON.
3. Phase 2: shared broad-media normalization, batch queue, persistence and SRT/VTT/Markdown.
4. Phase 3: VAD, review/playback, file actions, Finder/Command Palette and recorder handoff.

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

- Pin exact whisper.cpp/model/VAD artifacts, versions, checksums, licenses and build flags.
- Do not claim resume unless a real checkpoint format exists; interrupted jobs restart honestly.
- Core ML is optional until generation/distribution is reproducible.
- Do not add diarization without separate model/license/privacy research.
