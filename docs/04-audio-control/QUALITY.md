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
