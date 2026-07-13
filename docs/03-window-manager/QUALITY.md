# Quality and verification

## Performance budgets

- Shortcut-to-completed AX request p95: 100 ms for normal apps.
- Footprint follows snap-area changes within one visible frame under normal load.
- No event-tap callback performs blocking AX work or filesystem I/O.
- History and observers remain bounded after apps/windows churn.

## Unit tests

- Every action on positive/negative origins, 1x/2x backing scales, odd pixel
  sizes, gaps, minimum sizes, ultrawide/portrait displays.
- Normalized move between displays and clamp behavior.
- Cycle sequence/reset/timeout and restore history identity/expiration.
- Snap-area mapping, corners, adjacent displays, modifiers, and hysteresis.
- Settings migration and duplicate shortcuts.

## Adapter tests

- AX denied/revoked, missing focused/main window, unsupported role/subrole,
  position/size not settable, timeout, app-clamped result, window closed mid-op.
- Event adapter cancellation/disable and display configuration change.
- Footprint is nonactivating/click-through and always hidden on cleanup.

## Manual application matrix

- [ ] Finder, Safari, Chrome, Terminal, Xcode, System Settings, Preview, Messages,
  Electron app, document app with sheets, fixed-size utility/dialog.
- [ ] Minimized, full-screen, multiple windows, no window, modal/sheet, app launch
  and quit during action.
- [ ] One display; mixed scale; display left/right/above; portrait; ultrawide;
  external display unplugged mid-operation.
- [ ] Dock every edge/hidden, menu bar alternate display, Stage Manager, Spaces.
- [ ] Permission denied/granted/revoked and hotkey collision.
- [ ] Drag edges/corners between adjacent displays, fast throw, slow movement,
  cancel modifier, release outside area.

## Invariants

- Never move a window without an explicit shortcut or completed drag.
- Never apply a frame outside all visible screen regions unless restoring a
  still-valid previously visible frame.
- Never leave an event tap/monitor or footprint alive after module stop.
- Never silently claim success when AX reports failure or final frame is invalid.

## Completion evidence

Automated results, application/display matrix, event-monitor leak check, latency
sample, and any compatibility exceptions with reproduction steps.
