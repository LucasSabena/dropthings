# Agent runbook

## Mission

Implement Session Recorder as the smallest safe vertical slice that satisfies its product
contract. Do not register half-finished behavior in the shipping app.

## Read first

1. Repository `AGENTS.md`.
2. This folder in README order.
3. `docs/architecture/DESIGN-SYSTEM-PLATFORM-DEPENDENCY.md`.
4. `docs/architecture/NEW-MODULES-INTEGRATION-MAP.md`.
5. Existing comparable module/helper/tests.

## Work order

1. Phase 0: prove audio-only ScreenCaptureKit on macOS 14, mic capture/timestamp alignment, macOS 15 mic output and decide actor versus helper.
2. Phase 1: system-audio-only M4A, permission/preflight, persistent stop route and startup recovery.
3. Phase 2: mic-only/Both, timeline/mix/headroom, pause/markers, WAV/CAF and long sync tests.
4. Phase 3: file actions, optional MP3 post-conversion, completion notification and conservative opt-in suggestions.

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

- Persistent status item cannot be hideable while recording; app shell may need a required-while-active visibility policy.
- System and mic must use sample/host timestamps and bounded drift correction—not UI arrival time.
- Suggestions remain off by default and only open preflight; they never request permission or create a file.
- Recording consent/law reminders should be neutral product copy, not legal advice.
