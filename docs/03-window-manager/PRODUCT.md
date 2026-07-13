# Product contract

## Keyboard actions

Required:

- Left/right/top/bottom half.
- Four quarters.
- Left/right third and left/right two-thirds.
- First/center/last third where useful on ultrawide displays.
- Maximize to visible frame, almost maximize, center, and restore.
- Move to next/previous display while preserving relative size/position.
- Increase/decrease width/height and center-prominently as later parity actions.

Every action has an optional user-recorded shortcut. Clearing a shortcut
disables only that action. Conflicts are reported without disabling unrelated
shortcuts.

## Repeated execution

- Repeating left/right cycles half → two-thirds → one-third, configurable.
- Cycle resets when another window/action is used or after a bounded timeout.
- Restore returns to the frame captured before the first snap in the sequence.
- History keys use a robust window identity plus PID/bundle context and expire
  when the window/process disappears.

## Drag snapping

- While dragging a standard window, pointer entry into a configured edge/corner
  snap area shows a non-interactive footprint.
- Releasing applies the target; leaving hides the footprint without moving.
- Areas cover halves, maximize, quarters, and optional thirds.
- Modifier can temporarily disable snapping; another optional modifier can select
  alternate sizes.
- Drag snapping can be disabled independently from keyboard actions.

## Window and display behavior

- Use the display containing most of the current window, then center/pointer as
  deterministic fallbacks.
- Respect `visibleFrame` and configured gaps.
- Never move DropThings' own transient palette/capture overlays.
- Skip minimized, full-screen, non-movable, non-resizable, sheet/dialog, or
  unknown windows when the requested action is unsafe; report why.
- If an app clamps the requested frame, treat the actual final frame as truth.

## States and settings

- Disabled, needs Accessibility, running, degraded, unavailable, failed.
- Versioned settings: shortcuts, cycle sequences/timeout, gaps, drag snapping,
  areas, modifier behavior, animations/footprint, ignored apps, and restore.
- Permission revocation removes monitors/hotkeys requiring control and returns
  to needs-permission state.

## Explicit non-goals

- Automatic tiling window manager, workspaces/layout rules, Todo mode,
  application launch layouts, or Rectangle Pro features.
- Private WindowServer APIs.
- Forcing windows that explicitly reject Accessibility move/resize operations.
