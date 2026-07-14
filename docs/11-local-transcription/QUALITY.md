# Quality and verification

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
- Module remains unregistered until the gate is complete.
