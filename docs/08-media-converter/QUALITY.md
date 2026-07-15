# Quality and verification

## Safety invariants

- Drop/select mixed image, audio and video batches and see compatibility before starting.
- Simple presets cover Web Image, Transparent Web, Email, Smaller Video, Audio Only and Audio for Transcription.
- Advanced mode exposes typed format, codec, resize, quality, metadata, audio/video and naming controls without accepting raw shell arguments.
- Originals remain untouched by default; outputs are staged, re-probed and atomically finalized.
- Every item reports progress, cancellation, output size delta, failure reason and destination.

## Automated and fault tests

- Preset migrations, output naming with hostile Unicode paths, resize/crop math, metadata policy and capability validation.
- Failure injection at probe, temporary creation, disk full, start, cancellation, writer, re-probe and final move.
- FFmpeg arguments are arrays; test spaces, quotes, newlines and leading dashes.
- Manual matrix: alpha/animated/profiled images; MP3/M4A/WAV/FLAC/Opus; MP4/MOV/MKV/WebM; corrupt and multitrack media.
- 1,000 start/cancel cycles leave no helper/child process; 24-hour mixed queue leaves no growing temporary storage.

## Manual matrix

- Permission deny, grant and revoke paths relevant to the product.
- Normal files/content plus corrupt, missing, huge and hostile-name cases.
- App termination, sleep/wake, device/destination changes and low disk/memory.
- Keyboard-only, VoiceOver, Reduce Motion and high-contrast behavior.
- Debug and Release builds, packaging/signature and migration from existing user
  settings.

## Evidence required

- Hardware, macOS and Xcode versions.
- Full `swift test --parallel` result.
- Debug and Release Xcode build results.
- CPU, memory, elapsed time and resource/temp inventories for long-running work.
- Screenshots of empty, normal, active, degraded, failure and recovery states.
- Known limitations and unsupported capabilities.

## Release gate

- No safety invariant lacks evidence.
- Full suite and product-specific matrices pass.
- No user content appears in default logs.
- Seven days of owner daily use for the core workflow.
- Documentation and research ledger match the exact shipped implementation.
- Module remains unregistered until the gate is complete.
