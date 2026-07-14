# Media Converter

Local batch conversion, resizing, compression and optimization with a calm Simple mode and a precise Advanced mode.

## Read order

1. `PRODUCT.md`
2. `ARCHITECTURE.md`
3. `EXPERIENCE.md`
4. `IMPLEMENTATION.md`
5. `QUALITY.md`
6. `RESEARCH-AND-LICENSES.md`
7. `AGENT-RUNBOOK.md`

## Definition of done

- Drop/select mixed image, audio and video batches and see compatibility before starting.
- Simple presets cover Web Image, Transparent Web, Email, Smaller Video, Audio Only and Audio for Transcription.
- Advanced mode exposes typed format, codec, resize, quality, metadata, audio/video and naming controls without accepting raw shell arguments.
- Originals remain untouched by default; outputs are staged, re-probed and atomically finalized.
- Every item reports progress, cancellation, output size delta, failure reason and destination.

## Platform decision

macOS 14. Prefer ImageIO/Core Image/AVFoundation for native paths. Use an isolated, reproducibly built FFmpeg helper for broad codecs and containers.

## Proposed symbol

`arrow.triangle.2.circlepath`
