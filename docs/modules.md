# Modules

See also `docs/modulos/` for the 2026-06-28 audit and planning notes for
Keep Awake, Color Picker, Screenshot, and permissions diagnostics.

## Module 1: Scroll Control

Goal: let the user keep natural scrolling on the trackpad and Windows-style wheel scrolling on the mouse.

References:

- LinearMouse: per-device mouse and trackpad customization.
- Scroll Reverser: independent settings for trackpads and mice.
- UnnaturalScrollWheels: small focused wheel inversion app.

Likely APIs:

- `CGEventTap` for observing and modifying scroll events.
- IOKit or event metadata for device classification.
- Accessibility permission for event taps.

Settings:

- Enable scroll control.
- Trackpad direction: natural or inverted.
- Mouse wheel direction: natural or inverted.
- Magic Mouse direction.
- Horizontal scroll behavior.
- Optional scroll multiplier.

Risks:

- Device classification can vary by hardware.
- Event taps can be disabled by macOS if slow.
- Sandboxing/App Store distribution may be constrained.

## Module 2: File Shelf

Goal: create a temporary shelf where the user can drop files while navigating to another app or destination.

References:

- DropPoint.
- Dropp.
- ShakePin.
- Yoink and Dropover as commercial UX references.

Likely APIs:

- `NSPanel` for a floating shelf.
- `NSDraggingDestination` for accepting drops.
- `NSDraggingSource` or pasteboard writing for dragging items out.
- Security-scoped bookmarks for pinned files.

Settings:

- Show shelf on drag near screen edge.
- Show shelf with hotkey.
- Shelf position.
- Auto-hide behavior.
- Clear temporary items on quit.
- Persist pinned items.

Risks:

- Cross-Space behavior is constrained by macOS.
- Dragging from sandboxed apps can expose limited pasteboard data.
- File permissions can expire or require bookmarks.

## Module 3: Menu Bar Cleaner

Goal: hide low-priority menu bar icons and reveal them with a small control, similar to Windows overflow.

References:

- Ice.
- Hidden Bar.
- Bartender as commercial benchmark.

Likely APIs:

- `NSStatusItem` for DropThings controls.
- Accessibility APIs for observing/manipulating status items.
- Screen Recording may be required for visual detection.

Settings:

- Always visible group.
- Hidden group.
- Reveal on click.
- Reveal on hover.
- Auto-hide delay.
- Compact mode for small screens and notched MacBooks.

Risks:

- This is the most macOS-version-sensitive module.
- Some system items may not be movable or hideable.
- Requires high-trust permissions.

## Future Module Template

Each new module needs:

- Problem statement.
- User-facing behavior.
- Required permissions.
- Platform APIs.
- Settings model.
- Failure states.
- Test strategy.
- Manual verification checklist.
