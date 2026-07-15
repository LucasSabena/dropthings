# Experience contract

## Primary surface

Use a dedicated compact utility/document/queue surface when the workflow is larger
than a settings pane. The first screen is usable immediately: drop/select/create,
not a marketing carousel.

## Simple versus Advanced

Simple mode is outcome-oriented and hides implementation vocabulary. Advanced mode
is grouped, truthful and capability-driven. Unsupported options are hidden or
disabled with a reason; no visible setting may be ignored.

## Progress and recovery

- Show meaningful phases rather than a generic spinner.
- Use determinate percentage only when reliable.
- Closing during active work has an explicit outcome.
- Errors use one plain-language sentence plus optional technical details.
- Completed work exposes Reveal/Open/Copy Path and compatible registered actions.
- Originals/source content are visibly protected.

## Accessibility

- Full keyboard path and equivalent buttons for drag-only actions.
- Native semantics and VoiceOver labels include item/document/session context.
- State is never color-only.
- Respect Reduce Motion and throttle progress announcements.
- Large previews are lazy/downsampled.
- Persistent safety controls remain reachable by mouse and keyboard.

## Permission boundary

Explain why a permission is needed immediately before requesting it. Denial leaves
unrelated features available. Returning from System Settings rechecks automatically.

## Required user-visible capabilities

- Text: plain text, trim, whitespace/line normalization, case conversion, line sort/deduplicate, URL/Base64/HTML entity encode/decode and counts.
- URL: normalize, copy Markdown link, remove inspectable tracking parameters, QR, and explicit user-triggered title fetch.
- JSON: validate, pretty print, minify, optional sort keys and precise first parse error.
- Color: parse HEX/RGB/HSL/CSS and convert to HEX, RGB, HSL, CSS, SwiftUI and NSColor while preserving alpha.
- Files/images: reveal, copy names/paths, dimensions/size, save a representation, or invoke Media Converter/Workbench through Core actions.
- Pinned actions, Treat As… for ambiguous text, and sensitive preview hiding.
