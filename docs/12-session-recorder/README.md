# Session Recorder

An explicit, visible local recorder for system audio, microphone or both—optimized for calls, demos and later transcription.

## Read order

1. `PRODUCT.md`
2. `ARCHITECTURE.md`
3. `EXPERIENCE.md`
4. `IMPLEMENTATION.md`
5. `QUALITY.md`
6. `RESEARCH-AND-LICENSES.md`
7. `AGENT-RUNBOOK.md`

## Definition of done

- Explicitly record system audio, microphone or both with persistent visible indicator, elapsed time and Stop.
- Audio-only mode does not request/store screen frames.
- Call-app suggestions are opt-in, rate-limited and can never start recording.
- Outputs are staged, finalized, re-probed and recoverable after interruption.
- Completed recordings can be played, revealed, converted or explicitly queued for Local Transcription through Core actions.
- Stop, disable, quit, permission loss, sleep/wake or device failure leave no hidden capture resource.

## Platform decision

macOS 14. Use ScreenCaptureKit for system audio; AVAudioEngine/AVCapture on macOS 14 for mic, and evaluate ScreenCaptureKit mic output on macOS 15+. Default M4A/AAC; WAV/CAF lossless; optional MP3 via shared conversion.

## Proposed symbol

`record.circle`
