# Quality Plan

## Test Layers

Unit tests:

- Settings models.
- Module state transitions.
- Permission state mapping.
- File shelf item models.
- Scroll direction transformation logic.

Integration tests:

- Module registry lifecycle.
- Settings migrations.
- Platform adapter fakes.

Manual macOS verification:

- Accessibility permission denied, granted, revoked.
- Event tap timeout and recovery.
- Drag/drop between Finder, browser, Mail, and common upload controls.
- Multiple displays.
- Multiple Spaces.
- Light/dark mode.
- Menu bar with notch and without notch.

## Release Checklist

- Build signed app.
- Run unit tests.
- Run module manual checks.
- Verify permissions copy.
- Verify first-run flow.
- Verify modules can be disabled independently.
- Verify app quits cleanly and removes event taps.
- Verify no secrets or local-only files are committed.
- Review licenses for any copied or bundled code.

## Definition Of Done

A module is done when:

- It has settings.
- It has permission handling.
- It has enabled, disabled, denied, failed, and unavailable states.
- It stops cleanly.
- It is documented in `docs/modules.md`.
- It has automated tests for pure logic.
- It has manual verification notes for macOS-specific behavior.

