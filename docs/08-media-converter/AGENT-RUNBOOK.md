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

1. Phase 0: spike native capabilities and universal FFmpeg packaging; decide exact configure flags, licenses, signing and source-release process.
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
