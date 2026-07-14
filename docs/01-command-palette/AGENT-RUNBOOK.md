# Agent runbook

## Before editing code

1. Read every Markdown file in this folder and root `AGENTS.md`.
2. Inspect current code and tests; docs describe target behavior, not proof that
   the repository already implements it.
3. Check `git status` and preserve unrelated user changes.
4. Select exactly one unchecked phase slice from `IMPLEMENTATION.md`.
5. For external code, update the reuse ledger before copying.

## Implementation constraints

- Keep providers private to CommandPalette until a second module needs them.
- Platform types return plain Sendable values; no AppKit/Metadata objects cross
  into pure ranking logic.
- Never perform file queries, icon decoding, or calculator parsing synchronously
  in a SwiftUI `body` or on the main thread.
- Never request Full Disk Access merely to improve result count.
- Preserve all other providers when one fails.
- Use design-system tokens; new tokens require a demonstrated repeated need.

## Completion loop

1. Add/adjust tests first for pure logic and adapter contracts.
2. Implement the smallest end-to-end behavior.
3. Run targeted tests, then the full Swift test and Xcode build commands.
4. Execute applicable manual checks from `QUALITY.md`.
5. Mark a checklist item only when evidence exists.
6. Record a durable deviation in the relevant document, with reason and date.
7. Leave the module in a working state; do not mark a phase complete with known
   required work remaining.

## Stop conditions

Stop and request direction if a change would add network search, AI, a plugin
runtime, Full Disk Access, private APIs, destructive system actions, or a shared
Core abstraction not justified by a second consumer.
