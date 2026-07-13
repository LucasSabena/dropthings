# Quality and verification

## Performance budgets

- Shortcut-to-selection overlay warm p95: 120 ms or less.
- Capture completion-to-thumbnail/editor visible p95 for one 5K display: 500 ms
  target, with no main-thread image encoding.
- Pointer tracking and annotation interaction: 60 fps under normal documents.
- Undo/redo action latency: under 50 ms for vector edits.
- Memory must be bounded for scrolling capture; do not retain redundant decoded
  copies of every frame plus composite.

## Unit tests

- All view/image coordinate transforms at 1x, 2x, translated and negative-origin
  displays.
- Annotation geometry, hit testing, resize/rotate constraints, crop clipping,
  renderer determinism, and undo grouping.
- File naming, collision handling, format/quality, atomic save, and migrations.
- Frame alignment with exact, noisy, repeated, blank, sticky-header, dynamic,
  reverse-direction, and no-overlap fixtures.
- Scroll state transitions, timeouts, partial preservation, and cleanup.

## Adapter tests

- Fake capture service for permission denied/revoked, protected content, missing
  window/display, capture failure, and cancellation.
- OCR fake for slow/empty/error/cancelled responses.
- Pasteboard and filesystem failures.

## Manual matrix

- [ ] Intel if available and Apple Silicon; macOS 14 and current macOS.
- [ ] 1x/2x/mixed scaling; displays left/right/above; menu bar/Dock variations.
- [ ] Region across screen boundary, exact window, full display, menus, cursor,
  shadow, timed capture, full-screen app, and Stage Manager.
- [ ] Permission denied, granted after return, revoked while running.
- [ ] All editor tools with undo/redo, zoom, crop, copy/save, overwrite failure,
  unsaved close, transparent source, wide-gamut and large image.
- [ ] VoiceOver, keyboard-only, Reduce Motion, Increase Contrast.
- [ ] Scrolling: Safari/Chrome, Finder list, Messages/chat-like view, document,
  lazy images, sticky header, video/dynamic content, Scroll Reverser-like input,
  reaching bottom, no movement, cancellation, app/window closed mid-capture.

## Golden fixtures

Store small synthetic images/metadata in tests, not personal screenshots. Golden
exports compare pixels with an explicit tolerance for color-space/filter paths.
Every scrolling bug receives a minimal fixture before its fix.

## Completion evidence

- Test commands/results, memory/performance sample, multi-display screenshots,
  scroll fixture report, and known limitations.

## Current automated evidence — 2026-07-13

- `swift test`: 296 tests passed.
- `xcodebuild -project App.xcodeproj -scheme DropThings -configuration Debug
  build CODE_SIGNING_ALLOWED=NO`: succeeded.
- Screenshot Studio fixtures cover shortcut collisions/settings migration,
  document undo/crop/render dimensions, canvas coordinate round-trips, exact
  and blank-frame alignment, and a scrolling sequence that stops on a repeated
  frame while preserving every pixel row of a valid 160-pixel composite.

Manual evidence is deliberately still outstanding. Actual Screen Recording and
Accessibility behavior must be exercised on a consented desktop before the
manual matrix may be checked off.
