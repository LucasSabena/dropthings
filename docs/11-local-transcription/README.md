# Local Transcription

Offline queued transcription of common audio and video files using whisper.cpp, with user-managed models and timestamped exports.

## Read order

1. `PRODUCT.md`
2. `ARCHITECTURE.md`
3. `EXPERIENCE.md`
4. `IMPLEMENTATION.md`
5. `QUALITY.md`
6. `RESEARCH-AND-LICENSES.md`
7. `AGENT-RUNBOOK.md`

## Definition of done

- Select multiple common audio/video files, choose model/language/outputs and run a visible cancellable local queue.
- Model chooser explains actual disk/memory/speed tradeoffs, verifies checksums and lets users delete/import models.
- Outputs include TXT, Markdown, SRT, VTT and versioned JSON with timestamps.
- No audio, transcript, prompt or telemetry leaves the Mac.
- Helper crash, corrupt model or unsupported media cannot crash DropThings or falsely mark completion.

## Platform decision

macOS 14 host. Run whisper.cpp in an isolated bundled helper, use Metal on supported Macs, and normalize input to 16 kHz mono PCM through shared MediaKit/FFmpeg.

## Proposed symbol

`waveform.and.mic`
