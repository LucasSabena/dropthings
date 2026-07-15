# Product contract

## Outcome

An explicit, visible local recorder for system audio, microphone or both—optimized for calls, demos and later transcription.

## Required capabilities

- Sources: System, Microphone, Both; separate tracks later only after synchronization evidence.
- Preflight checks permissions, selected devices, signal levels, destination, file name and free disk.
- Controls: visible countdown, start, pause/resume, marker, stop, mic/system inclusion levels and scoped keep-awake assertion.
- Persistent non-hideable menu-bar stop route during active recording.
- Default M4A/AAC, lossless WAV/CAF and optional MP3 post-conversion; valid intermediate is retained if MP3 conversion fails.
- Local history stores metadata/bookmark, duration, sources, markers, format and status—not audio data.
- Opt-in suggestion based on known/user-configured call app bundle IDs; no browser page/window-title scraping.
- Startup recovery inspects stale owned session directories and offers playable partials honestly.

## Entry points

- Module primary action opens the dedicated product surface.
- Command Palette exposes only deterministic, previewable commands.
- Compatible file actions are published/consumed through a Core-owned registry.
- Module settings remain in the normal DropThings settings hierarchy.

## Permissions and privacy

System audio requests Screen Recording; microphone requests Microphone. Request only the sources selected. Add NSMicrophoneUsageDescription.

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

- Hidden/background or automatic call recording.
- Screen video, webcam, editing, cloud upload, streaming, meeting bots or embedded transcription/summarization.
- Bypassing DRM or macOS privacy controls.
