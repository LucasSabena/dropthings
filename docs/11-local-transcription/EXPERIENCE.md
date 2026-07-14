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

- Target inputs: Opus/Ogg, MP3, M4A/AAC, WAV, FLAC, MKV, MP4, MOV and WebM, gated by runtime capability manifest.
- Video extracts selected/primary audio; multitrack files expose Advanced track selection.
- Curated Tiny/Base/Small model UX, with Medium/Large/Turbo advanced after measured hardware evidence.
- Language Auto/Spanish/English/selected language; transcribe or translate-to-English only where model supports it.
- Optional verified VAD, initial vocabulary prompt and advanced inference controls.
- Queue phases: inspect, decode, VAD, model load, transcribe, finalize; one inference job by default.
