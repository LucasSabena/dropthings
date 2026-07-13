# Quality and verification

## Performance budgets

- Warm shortcut-to-visible-panel p95: 100 ms or less.
- First cached app/command snapshot p95 after panel visibility: 50 ms or less.
- Keystroke-to-local-results p95: 50 ms or less with 10,000 catalog entries.
- First file results p95 on a healthy warm Spotlight index: target 250 ms; report
  slower provider state without blocking input.
- Main-thread stalls longer than 16 ms during typing are defects.
- History and caches remain bounded and survive corrupt entries by resetting only
  the affected data.

## Unit tests

- Tokenization, fuzzy matching, scoring weights, and stable tie-breaking.
- Calculator precedence, unary operators, invalid input, division by zero,
  overflow/non-finite results, and locale formatting.
- App deduplication, helpers filtering, aliases, exclusions, and stable IDs.
- History decay, frequency caps, successful-action recording, migrations, and
  corruption recovery.
- Query generations discard late provider results.

## Adapter/integration tests

- Fake providers with controlled latency, errors, cancellation, and duplicates.
- Spotlight result mapping without leaking Foundation metadata objects.
- Application launch failure and missing bundle recovery.
- Panel target-screen calculation using synthetic screen geometries.

## Manual matrix

- [ ] One display; two displays left/right; display above; mixed scaling.
- [ ] Dock on every edge and auto-hidden; menu bar on alternate display.
- [ ] Normal Space, another Space, Stage Manager, and full-screen app.
- [ ] Rapid open/close and 20-character rapid typing.
- [ ] Spotlight indexing, disabled/excluded folder, offline iCloud file, external
  volume removal, and renamed/deleted result.
- [ ] Hotkey conflict, keyboard layout change, VoiceOver, Reduce Motion, Increase
  Contrast, light/dark appearance.
- [ ] Module disabled while its command is visible.

## Required evidence before completion

- Test command and result.
- Instruments/signpost latency summary on the owner's Mac.
- Screenshots or short recording of multi-display/full-screen behavior.
- Remaining known limitations recorded in `RESEARCH-AND-LICENSES.md`.
