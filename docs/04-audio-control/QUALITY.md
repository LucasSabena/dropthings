# Quality and verification

## Safety invariants

- On failure, restore normal unprocessed audio before attempting convenience
  recovery.
- Never leave a process tap muting an app without an active verified output path.
- Never exceed configured gain/limiter ceiling because settings are corrupt.
- Never delete an audio device/tap not provably owned by DropThings.
- Never allocate, lock, log, block, or touch UI/files/network in an IO callback.

## Performance budgets

- Added round-trip latency target: under 20 ms on built-in output; measure and
  report actual device-dependent value.
- Helper CPU target with three stereo apps, neutral EQ: under 5% of one modern
  performance core during steady playback; record hardware.
- No sustained buffer underruns/overloads in a 24-hour run.
- UI meter publication capped (for example 20–30 Hz while visible, much lower or
  off while hidden); audio callback cadence never follows UI.
- Memory/resources remain stable through 1,000 app start/stop and 500 device
  reconciliation cycles in stress tests/fakes.

## Unit tests

- Gain conversion/ramping, limiter, biquad coefficients, EQ neutral/frequency
  response, NaN/Inf/denormal inputs, channel layouts, buffer boundaries.
- Desired/observed protocol coding/version mismatch/idempotent reconciliation.
- Stable app/device identity, settings migrations/corruption, pin/ignore/routing
  fallback, crash-loop policy, owned-resource matching.
- Lifecycle state machines and transactional reverse-order unwind.

## Integration/fault tests

- Fake HAL/tap/device interfaces for failure at every create/start/set/listener/
  stop/destroy step.
- Helper disconnect/crash before/after original mute, stale response generation,
  host restart, helper restart, permission revoke.
- Sample rate, buffer size, channel layout, default device, connect/disconnect,
  sleep/wake, app PID reuse, app without bundle ID.

## Manual application/device matrix

- [ ] Safari/Chrome media, Music/Spotify-like player, QuickTime/VLC, Messages/
  notification sound, video conference, game/Electron app, system/helper process.
- [ ] Built-in speakers, wired headphones, Bluetooth, HDMI/display, USB DAC;
  multi-output only when phase enabled.
- [ ] 44.1/48/96 kHz where supported, mono/stereo/multichannel observation.
- [ ] App quit/relaunch, rapid mute/volume, route switch during playback, device
  disconnect/reconnect, default change, sleep/wake, logout/relaunch.
- [ ] Permission deny/grant/revoke, helper kill/crash loop, DropThings force quit,
  startup orphan cleanup, reset/restore normal audio.
- [ ] Headphones at safe initial level for all boost/transient tests.

## Required evidence

- Hardware/OS/app/device versions.
- Latency, CPU, overload, and 24-hour run results.
- Audio resource inventory before/after fault tests.
- Automated results and known incompatibilities.
- Explicit owner approval before FineTune is uninstalled.

## Evidence log — 2026-07-13

Environment:

- macOS 26.5.2 (25F84), Xcode 26.6 (17F113).
- MacBook Air `Mac17,4`, Apple M5, 10 cores, 16 GB RAM.
- Default output observed: built-in MacBook Air speakers, 48 kHz.

Automated/build evidence:

- `swift test --filter 'Audio(SafetyPolicy|Protocol|EngineCrashPolicy|ControlSettings|ControlModule)Tests'`:
  11 tests passed, 0 failures.
- Latest full `swift test`: 361 tests passed, 0 failures.
- Debug and Release `xcodebuild -scheme AudioControlEngine ... build`: passed.
- Debug and Release `xcodebuild -scheme DropThings ... build`: passed; the resulting app contains
  `Contents/XPCServices/AudioControlEngine.xpc` and both bundles contain
  `NSAudioCaptureUsageDescription`.
- A local ad-hoc signed Debug bundle passed `codesign --verify --deep --strict`;
  its nested XPC service has identifier `app.dropthings.AudioControlEngine`.
- Launching the signed app with Audio Control enabled spawned the embedded XPC
  helper. Terminating the test host also terminated its helper; the post-test
  inventory remained 0 taps and 0 aggregate devices. No app control was changed,
  so this check intentionally did not prompt or process audible content.
- Read-only resource inventory before privileged testing: 0 process taps and 0
  aggregate devices. Compile/unit verification creates no audio resource.
- The existing unrelated AppKit actor-isolation warning and Xcode's no-AppIntents
  metadata warning remain; neither originates in Audio Control.
- Independent menu-bar preference tests cover defaults, persistence, and pruning.
- Audio module tests cover system output volume/mute delegation and persisted
  per-app routing desired state.
- Product Design visual QA compared the supplied FineTune capture with the
  native 480×520 rendered empty state. One P2 contrast issue on the unavailable
  output selector was fixed and recaptured; the final report is `design-qa.md`.

Hardware gate evidence still required:

- [ ] Test Now Playing metadata and transport controls with Spotify, Safari and
  a Chromium browser on the owner's macOS version. Confirm an unavailable or
  timed-out MediaRemote call merely hides the media card and never affects
  audio processing.
- [ ] With a Discord call and Spotify playback, confirm the owning app names
  remain visible through stream handoffs; confirm an idle row receives no tap
  and disappears when its app quits.
- [ ] Explicitly grant System Audio Recording from the built DropThings app.
- [ ] Confirm one-app gain/mute at a safe speaker/headphone level and verify
  normal audio after disable, app quit, helper kill, and DropThings force quit.
- [ ] Record tap/aggregate inventory before and after every failure case.
- [ ] Measure latency, CPU, overload count, and resource stability.
- [ ] Complete the 24-hour Phase 1 run, the Phase 2 matrix, and seven clean
  daily-use days before enabling later phases or removing FineTune.
