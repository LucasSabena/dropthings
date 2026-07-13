# Experience contract

## Lazyweb workflow note — 2026-07-13

Lazyweb was queried first for screenshot editors, annotation canvases, and
desktop capture flows. Its accessible indexed corpus did not provide a directly
relevant Shottr/CleanShot macOS editor flow. The design therefore uses native
macOS interaction conventions and product/API research; no unsupported
Lazyweb-derived visual claim or asset is used.

Lazyweb entry point: <https://www.lazyweb.com/>

Follow-up — 2026-07-13: the entry point was rechecked while implementing the
baseline. It still supplied no applicable indexed screenshot-editor flow, so
the module uses native controls, SF Symbols, and original layout only.

Follow-up — 2026-07-13: Lazyweb was consulted before adding the Shelf capture
archive. Its browser-accessible surface did not expose a macOS capture-history
flow suitable for direct comparison. The feature therefore follows native
macOS expectations: copied screenshots remain pasteable and saved screenshots
are watched only in an explicitly user-selected folder.

## Capture interaction

- Invoking capture temporarily hides DropThings capture UI before acquiring
  pixels, without visible flicker in the output.
- Region mode shows precise crosshair, magnifier, and pixel dimensions.
- Escape cancels; Space temporarily switches window/region selection only if the
  behavior is taught in the overlay.
- Multi-display overlays preserve each display's native scale and coordinates.
- After capture, the configured action occurs immediately; no unnecessary modal.

## Editor interaction

- Standard macOS window with familiar Save, Save As, Copy, Undo, Redo, Close,
  zoom, and tool shortcuts.
- Canvas receives most space. Tools are compact and persistent; properties are
  contextual to the selected tool/object.
- Selection handles remain usable at different zoom levels and do not export.
- Text editing uses a native text editor overlay and commits predictably on
  Escape/click/shortcut.
- Destructive close of an unsaved session asks once with clear options.

## Visual rules

- Use shared DropThings tokens for chrome, typography, controls, alerts, and
  spacing. Canvas checkerboard and selection/handle visuals may add dedicated
  reusable design-system tokens only after both editor and another surface need
  them, or when system semantic colors cannot express the state.
- Do not copy Shottr icons, layout, branding, or assets.
- Tool icons use SF Symbols where semantically accurate; custom original vectors
  require accessible labels.

## Feedback

- Successful copy/save has quiet, transient feedback.
- Scrolling capture has progress, Stop, and Cancel; it never traps the pointer.
- OCR shows processing state without blocking other editor actions.
- Errors name the affected step and preserve recoverable work.

## Accessibility

- Every tool and inspector control is keyboard/VoiceOver reachable.
- Canvas objects appear as an ordered accessibility collection with type and
  position; keyboard nudging supports coarse/fine increments.
- Respect Reduce Motion and Increase Contrast.
- Redaction tools explain that blur/pixelation are visual effects; exported
  results must be rasterized so original text is not recoverable as a layer.
