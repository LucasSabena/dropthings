# Architecture

## Ownership

- `DropThingsModules/WindowManager` owns actions, cycles, history policy, drag
  orchestration, settings, module state, and settings UI.
- `DropThingsPlatform` owns Accessibility calls, global mouse/event monitoring,
  window hit-testing/observation, screen geometry, and footprint panel behavior.
- Pure frame calculation stays free of AppKit/Accessibility objects and receives
  plain geometry/capability values.

Migrate/rename `WindowSnap`; do not keep two active window-control modules.

## Proposed components

- `WindowAction`: stable Codable action identifiers and display metadata.
- `WindowGeometryEngine`: pure target-frame calculations, gaps, constraints,
  display mapping, and repeated sequences.
- `WindowSystemClient`: narrow Platform protocol for focused window snapshot,
  capabilities, actual frame, set frame, and screen list.
- `AccessibilityWindowClient`: production AX implementation.
- `WindowIdentity`: stable-enough session identity; no persisted raw AX reference.
- `WindowFrameHistory`: bounded in-memory pre-snap frames and cycle state.
- `WindowActionExecutor`: reads snapshot, calculates, applies best effort, rereads
  actual frame, updates history, and reports typed outcome.
- `DragSnapController`: event lifecycle and snap-area state machine.
- `SnapAreaResolver`: pure screen-edge/modifier → action mapping.
- `FootprintPanelController`: click-through/nonactivating preview only.

## Geometry contract

- Declare one canonical coordinate space for pure calculations (AppKit global
  coordinates is acceptable); convert AX/CoreGraphics exactly once at adapter
  boundaries.
- All targets derive from a display's visible frame minus user gaps.
- Round to backing-pixel boundaries using target screen scale to avoid drift.
- Moving display preserves normalized frame within source visible frame, then
  clamps to destination visible frame.
- Minimum/maximum sizes from AX are respected when available; final AX frame is
  reread because applications may clamp/reorder size and position writes.

## Accessibility behavior

- Verify trust immediately before control; permission can be revoked at runtime.
- Inspect role/subrole, minimized/full-screen state, position/size settable
  attributes, and focused/main window fallbacks.
- AX callbacks never mutate module state directly; bridge onto the main actor.
- Time out and degrade individual operations rather than blocking the app.

## Drag state machine

`idle → observingDown → dragging(window) → previewing(area) → applying → idle`.
Every terminal/cancel path hides the footprint and releases transient state.
Global mutable callback state, if unavoidable for event taps, is isolated inside
the Platform adapter and documented.

## History

- Record original frame only before the first managed move in a cycle.
- User/manual movement invalidates cycle state but need not discard a valid
  restore frame until policy timeout/window destruction.
- Never persist AX window references across launches.
