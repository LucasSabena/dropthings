# Quality and verification

## Phase 1 automated evidence — 2026-07-14

- SwiftPM builds the new kit, Platform client, module UI and module tests.
- Automated coverage includes WAV structure/format/duration, transcript timing and
  schema validation, TXT/JSON encoding, output conflicts, curated manifest shape,
  settings sanitation and module availability lifecycle.
- The full 531-test `swift test` suite passed during the final 0.7.0 audit (one
  opt-in real-model fixture is skipped unless its model/audio paths are set).
- A real inference test passed against the upstream `samples/jfk.wav` fixture and
  the checksum-verified multilingual Tiny model using Metal.
- Unsigned (`CODE_SIGNING_ALLOWED=NO`) Debug and Apple Silicon Release app builds
  succeeded with the XPC helper and `whisper.framework` embedded inside it. The
  app, helper and framework all contain `arm64`; the helper links only
  the embedded framework plus Apple system/Swift libraries.

This is Phase 1 development evidence, not evidence that the later product phases
are complete. Signed distribution verification, Base/Small Spanish/English
measurements, cancellation/crash fault injection, long-media soak and accessibility
screenshots remain release evidence to collect before claiming the full product
definition of done.

## Beta hardening evidence — 2026-07-16

- Export tests cover repeated TXT+JSON output sets without overwrite or process traps.
- Module tests verify the Beta release stage and availability lifecycle.
- Queue progress is identity-gated so late callbacks cannot replace Completed, Failed or Cancelled.

## Safety invariants

- Select multiple common audio/video files, choose model/language/outputs and run a visible cancellable local queue.
- Model chooser explains actual disk/memory/speed tradeoffs, verifies checksums and lets users delete/import models.
- Outputs include TXT, Markdown, SRT, VTT and versioned JSON with timestamps.
- No audio, transcript, prompt or telemetry leaves the Mac.
- Helper crash, corrupt model or unsupported media cannot crash DropThings or falsely mark completion.

## Automated and fault tests

- Protocol version/event ordering, transcript timing/escaping/schema, output conflicts and model manifest/checksum/leases.
- Decode corrupt/no-audio/multitrack/very-long/silence media; helper crash during load/segment/finalize/cancel.
- Spanish Argentina, English and mixed-language quality samples with human reference where legally usable.
- Measure model load, peak memory, real-time factor, CPU/GPU, battery/thermal and low-memory behavior.
- 8-hour batch soak plus a real 2+ hour source; no temporary/model/process leak and no transcript in logs.

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
- Do not describe Phases 2–3 as shipped until this gate is complete for that scope.
