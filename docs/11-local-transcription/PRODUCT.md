# Product contract

## Outcome

Offline queued transcription of common audio and video files using whisper.cpp, with user-managed models and timestamped exports.

## Required capabilities

- Target inputs: Opus/Ogg, MP3, M4A/AAC, WAV, FLAC, MKV, MP4, MOV and WebM, gated by runtime capability manifest.
- Video extracts selected/primary audio; multitrack files expose Advanced track selection.
- Curated Tiny/Base/Small model UX, with Medium/Large/Turbo advanced after measured hardware evidence.
- Language Auto/Spanish/English/selected language; transcribe or translate-to-English only where model supports it.
- Optional verified VAD, initial vocabulary prompt and advanced inference controls.
- Queue phases: inspect, decode, VAD, model load, transcribe, finalize; one inference job by default.
- Light transcript review: playback at timestamp, search, edit segment text, merge/split simple segments and raw-versus-edited state.
- Explicit file actions so Session Recorder can queue completed files without direct imports.

## Entry points

- Module primary action opens the dedicated product surface.
- Command Palette exposes only deterministic, previewable commands.
- Compatible file actions are published/consumed through a Core-owned registry.
- Module settings remain in the normal DropThings settings hierarchy.

## Permissions and privacy

No microphone/screen permission for file transcription. Network only for explicit model download; file access is user selected.

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

- Speaker diarization/identification in v1; Whisper does not provide reliable speaker labels.
- Live dictation, automatic summaries/action items, LLM post-processing or cloud fallback.
- Claims of legal/medical/court-grade accuracy.
