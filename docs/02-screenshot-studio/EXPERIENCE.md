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

- Invoking capture preserves visible windows and popovers so DropThings itself
  can be captured; the selection overlay is never included in acquired pixels.
- Region mode shows precise crosshair, magnifier, and pixel dimensions.
- Escape cancels; Space temporarily switches window/region selection only if the
  behavior is taught in the overlay.
- Multi-display overlays preserve each display's native scale and coordinates.
- After capture, the configured action occurs immediately; no unnecessary modal.

## Workflow refinement — 2026-07-14

Lazyweb was unavailable in the active toolset, so this work follows the existing
record above. Shortcut rows now describe complete recipes: shortcut plus output.
Region has two independent defaults (quick copy and open editor), while window,
display, and scrolling retain their own recipe. Scrolling copy explains that the
user selects a fixed viewport before DropThings scrolls and stitches it.

## Editor rebuild workflow note — 2026-07-14

Lazyweb was queried again before rebuilding the editor, but its indexed surface
returned no usable screenshot-annotation flow. Flameshot's public feature list
and shortcut documentation were used as the behavioral reference instead. The
new editor is an original AppKit implementation: it uses a pixel-sized canvas,
native scroll-view zoom, an explicit SF Symbol tool map, contextual color/stroke
controls, predictable text commit/cancel, selection/move/resize, and quiet
copy/save feedback.

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
