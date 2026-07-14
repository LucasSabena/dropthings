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

## Evidence — 2026-07-13

- `swift test`: final full suite passed (361 tests, 0 failures), including
  deterministic calculator fuzzing and the personalization/web-search slice.
- The XCTest performance fixture ranked 10,000 pre-indexed results in 20 ms on
  average (10 measurements), inside the 50 ms local-results budget.
- Instruments trace `.build/command-palette-metrics-20260713.trace`, captured
  from the locally built app with a 20-character rapid-query sequence, measured
  panel visibility at 20.201 ms. Across 24 local-result signposts the slowest
  event was 19.824 ms; the README Spotlight query completed in 150.884 ms,
  including its deliberate 120 ms debounce. The Potential Hangs table contained
  no events over 250 ms.
- `xcodebuild -project App.xcodeproj -scheme DropThings -configuration Debug
  -derivedDataPath .build/xcode-derived CODE_SIGNING_ALLOWED=NO build`: succeeded.
- Native UI verification confirmed immediate search focus, 90 discovered apps,
  calculator input `2+3*4` → `14`, Command-K actions, two-stage Escape, and
  palette dismissal.
- Available hardware exposed one built-in Retina display (2880×1864). The
  multi-display, Stage Manager, full-screen, and 14-day replacement gates remain
  operational acceptance work and are not claimed complete.
