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

- Probe container, codec, dimensions, duration, frame rate, channels, sample rate, alpha, orientation, metadata and color profile.
- Image outputs: PNG, JPEG, TIFF, HEIC and WebP where the shipped capability manifest confirms support.
- Audio outputs: M4A/AAC, WAV, FLAC, Opus and MP3 only when the approved backend includes the encoder.
- Video outputs: MP4/MOV/MKV/WebM with explicit codec compatibility; H.264/AAC MP4 is the default compatibility preset.
- Resize by exact dimensions, fit, fill, percentage or maximum edge; no-upscale toggle.
- Metadata policies: preserve, remove location only, strip nonessential, or custom.
