# Permissions And Security

## Permission Principles

- Ask late: request permission when the user enables a module that needs it.
- Explain first: show why the permission is needed before macOS prompts.
- Fail clearly: denied permissions should produce a useful state and recovery action.
- Minimize scope: do not request Full Disk Access unless a module truly needs it.
- Keep everything local by default.

## Expected Permissions

Accessibility:

- Needed for scroll event taps.
- Required by many system utility apps.
- Diagnostics includes a `Reset & Request Accessibility` recovery action for
  stale TCC entries caused by replacing local/ad-hoc builds at the same bundle
  identifier.

Screen Recording:

- Not needed by active modules after removing Screenshot and switching Color
  Picker to the native sampler.
- Avoid unless a future module genuinely captures pixels or images.

Full Disk Access:

- Avoid for MVP.
- File Shelf should prefer user-granted drops and security-scoped bookmarks.

Automation:

- Avoid unless a future module controls other apps explicitly.

Login Items:

- The global `Open DropThings at login` setting uses `SMAppService.mainApp`.
- macOS remains the source of truth; users can revoke or approve it from
  System Settings → General → Login Items.
- This is not a permission for input or data access, and it should stay in
  app-level settings rather than module settings.

## Security Review Checklist

- Does the module request only the permissions it needs?
- Does disabling the module stop listeners, event taps, and observers?
- Are file bookmarks scoped and revocable?
- Are logs free of file contents, private paths where possible, and tokens?
- Can the user export diagnostics without leaking private data?
- Are open-source dependencies license-compatible?

## Threat Model Seeds

Risks to document before implementation:

- Event tap misuse or accidental input modification.
- File shelf exposing sensitive dropped files in previews.
- Menu bar layout relying on macOS status-item ordering and Command-drag setup.
- Supply-chain risk from dependencies.
- Notarization/signing integrity.
