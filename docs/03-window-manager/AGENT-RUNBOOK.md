# Agent runbook

## Before editing

1. Read this folder and root `AGENTS.md` completely.
2. Inspect current WindowSnap code, ScreenCoordinateMapper, GlobalHotkey,
  PermissionCenter, target membership, and tests.
3. Preserve unrelated edits and choose one implementation phase slice.
4. Repeat/extend Lazyweb research before changing UI.
5. Record Rectangle source in the ledger before copying/adapting it.

## Hard constraints

- Accessibility is lazy: no prompt/listener before module enablement.
- Pure calculations do not import AppKit/ApplicationServices.
- AX/event objects never escape Platform adapters.
- No private WindowServer APIs or application-specific hacks without a recorded
  reproducible failure.
- Apply best effort, reread actual frame, and report typed failure.
- Drag monitoring and footprint always clean up on every exit path.
- Do not add Rectangle Pro scope implicitly.

## Completion loop

1. Add a failing pure/adaptor test or a precise manual reproduction.
2. Implement the smallest vertical behavior.
3. Run targeted tests, full Swift tests, and Xcode build.
4. Execute the relevant application/display/manual matrix.
5. Inspect for leaked monitors and stale restore history.
6. Update checklists, research ledger, and compatibility notes.

## Stop conditions

Stop for direction before using private APIs, requesting another permission,
adding automatic tiling/layout automation, changing global coordinate
conventions, or copying a large Rectangle subsystem instead of adapting the
small required portion.
