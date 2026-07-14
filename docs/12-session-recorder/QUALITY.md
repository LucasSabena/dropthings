# Quality and verification

## Safety invariants

- Explicitly record system audio, microphone or both with persistent visible indicator, elapsed time and Stop.
- Audio-only mode does not request/store screen frames.
- Call-app suggestions are opt-in, rate-limited and can never start recording.
- Outputs are staged, finalized, re-probed and recoverable after interruption.
- Completed recordings can be played, revealed, converted or explicitly queued for Local Transcription through Core actions.
- Stop, disable, quit, permission loss, sleep/wake or device failure leave no hidden capture resource.

## Automated and fault tests

- Transactional state machine, timeline monotonicity, pause policy, markers, output/history/recovery and suggestion never-start guarantee.
- Failure injection for permissions, stream/mic/writer start/append/finish, disk full, final probe/move and conversion fallback.
- Mic/device disconnect, Bluetooth/default output change, permission revoke, lock/sleep/wake and force quit.
- 1,000 short start/stop cycles return capture/process/file/power resources to baseline.
- 2-hour System, Mic and Both recordings plus 8-hour soak; measure drift, dropped buffers, CPU, memory, file growth and thermal state.

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
