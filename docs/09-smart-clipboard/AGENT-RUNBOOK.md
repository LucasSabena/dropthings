# Agent runbook

## Mission

Implement Smart Clipboard as the smallest safe vertical slice that satisfies its product
contract. Do not register half-finished behavior in the shipping app.

## Read first

1. Repository `AGENTS.md`.
2. This folder in README order.
3. `docs/architecture/DESIGN-SYSTEM-PLATFORM-DEPENDENCY.md`.
4. `docs/architecture/NEW-MODULES-INTEGRATION-MAP.md`.
5. Existing comparable module/helper/tests.

## Work order

1. Phase 0: characterize every current Clipboard History/Color Picker pasteboard path and add regression tests.
2. Phase 1: introduce PasteboardHub/backend and migrate Clipboard History with no behavior change.
3. Phase 2: copy-only Smart Clipboard with text, URL, JSON and color actions.
4. Phase 3: image/file actions, explicit URL title fetch and optional Accessibility paste.
5. Phase 4: pinned/per-app ordering; no automatic transforms without a separate audit.

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

- Two pasteboard observers or content-hash-only deduplication will create races/duplicates.
- Accessibility must remain optional for basic use.
- Ambiguous strings must retain general text actions.
- Logs/crash diagnostics must contain only type, size and action IDs—not content.
