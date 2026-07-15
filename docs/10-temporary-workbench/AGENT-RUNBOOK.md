# Agent runbook

## Mission

Implement Temporary Workbench as the smallest safe vertical slice that satisfies its product
contract. Do not register half-finished behavior in the shipping app.

## Read first

1. Repository `AGENTS.md`.
2. This folder in README order.
3. `docs/architecture/DESIGN-SYSTEM-PLATFORM-DEPENDENCY.md`.
4. `docs/architecture/NEW-MODULES-INTEGRATION-MAP.md`.
5. Existing comparable module/helper/tests.

## Work order

1. Phase 0: compare SwiftUI Canvas, custom AppKit/layer-backed and hybrid approaches on 300 mixed items; prove atomic package recovery.
2. Phase 1: schema/package/recovery, library, pan/zoom/selection, text/image/file/basic shapes and undo.
3. Phase 2: notes, arrows, freehand, frames, groups, alignment, search, fragments and accessible Outline.
4. Phase 3: file actions, URL metadata, templates, presentation and PNG/PDF/frame export.

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

- Autosave must never write every pointer sample or replace a valid package with a partial one.
- Unknown future item types should be preserved or opened read-only, not silently discarded.
- Undo/image memory needs strict budgets and downsampling.
- Do not commit private/client assets as fixtures.
