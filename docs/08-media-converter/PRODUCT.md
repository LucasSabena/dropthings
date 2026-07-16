# Product contract

## Outcome

Local batch conversion, resizing, compression and optimization with a calm Simple mode and a precise Advanced mode.

## Required capabilities

- Probe container, codec, dimensions, duration, frame rate, channels, sample rate, alpha, orientation, metadata and color profile.
- Image outputs: PNG, JPEG, TIFF and HEIC. WebP remains hidden until a shipped encoder is verified.
- Audio outputs: M4A/AAC, WAV, FLAC, Opus and MP3 only when the approved backend includes the encoder.
- Video outputs: MP4/MOV/MKV/WebM with explicit codec compatibility; H.264/AAC MP4 is the default compatibility preset.
- Resize by exact dimensions, fit, fill, percentage or maximum edge; no-upscale toggle.
- Metadata policies: preserve, remove location only, strip nonessential, or custom.
- Conflict policies: skip, suffix, choose destination, or explicit confirmed replace.
- Versioned custom presets and a truthful resolved-plan preview.

## Entry points

- Module primary action opens the dedicated product surface.
- Command Palette exposes only deterministic, previewable commands.
- Compatible file actions are published/consumed through a Core-owned registry.
- Module settings remain in the normal DropThings settings hierarchy.

## Permissions and privacy

No broad permission. Security-scoped access for selected files/folders; optional Finder Automation only for Finder-selection shortcuts.

All processing is local. User content is excluded from default diagnostics. Any
network action must be explicit, narrowly scoped and described before it runs.

## States

The implementation must represent disabled, starting, running, needs-permission,
degraded and failed states, plus product-specific per-job/document/session states.
A failure must remain actionable and must not silently discard work.

## Settings

Use a versioned typed settings model with migrations. Persist stable identifiers,
not localized names. Corrupt settings are sanitized or quarantined and cannot crash
module startup.

## Explicit non-goals for v1

- Timeline editing, retouching, filters, compositing or replacing a full NLE.
- DRM removal, protected-stream capture, downloading online media or arbitrary FFmpeg commands.
- Cloud compression, telemetry or watched folders in the first release.
