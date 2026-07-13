# Implementation plan

## Phase 0 — disposable feasibility spike

- [ ] Add `NSAudioCaptureUsageDescription` on a spike branch/worktree only.
- [ ] Enumerate active audio processes and map bundle IDs.
- [ ] Create one private process tap + aggregate device for a test app, mute the
  original, apply gain, replay to current output, and tear everything down.
- [ ] Measure latency/CPU, check echo/duplication, and test permission denial,
  app quit, device switch, module stop, and crash cleanup.
- [ ] Record hardware/OS results; discard spike code unless it meets architecture.

Gate: normal audio always returns without reboot/Audio MIDI cleanup. Otherwise
stop and revise architecture before product work.

## Phase 1 — isolated safe mixer

- [ ] Create helper/XPC target and versioned desired/observed protocol.
- [ ] Implement process monitor, stable identities, transactional tap resources,
  gain ramp, soft limiter, safe bypass, and owned orphan cleanup.
- [ ] Build host supervision, permission states, one-app UI, and settings storage.
- [ ] Keep real-time callback allocation/lock/log free; add counters off-thread.

Gate: one controlled app runs for 24 hours across quit/relaunch and helper restart
with no echo, stuck silence, orphan device, leak, or unsafe volume burst.

## Phase 2 — full per-app mixer lifecycle

- [ ] Multiple concurrent apps, mute/solo, pin/ignore, meters, persistence.
- [ ] Device/process/default-output listeners and state reconciliation.
- [ ] Sleep/wake, sample-rate/buffer change, permission revoke, crash-loop cutoff.
- [ ] Bounded diagnostics and reset/restore-normal-audio actions.

Gate: application/hardware matrix passes and 7 daily-use days are clean.

## Phase 3 — per-app routing

- [ ] Enumerate/categorize output devices by UID and capabilities.
- [ ] Route one app to one device, default-follow, disconnect fallback, reconnect
  restore, and crossfade where necessary.
- [ ] Add multi-device only after clock/latency policy and drift tests exist.

Gate: no device switch produces echo, stuck route, or full-volume transient.

## Phase 4 — EQ and boost

- [ ] Pure biquad math/processor tests and neutral identity response.
- [ ] 10-band EQ, preset persistence, smooth parameter swap, limiter/headroom.
- [ ] Controlled boost with explicit opt-in and clipping indication.

Gate: frequency-response fixtures, long-run denormal/NaN protection, and CPU
budget pass on the owner's lowest-powered supported Mac.

## Phase 5 — advanced FineTune parity

- [ ] User EQ presets and automation/URL commands.
- [ ] AutoEQ import/search with separate dataset/license review.
- [ ] Loudness compensation/equal-loudness processing.
- [ ] Hardware/software volume selection, DDC, hidden/device inspector, Bluetooth,
  input/alert volume, media keys, and multi-output — each separately gated.

Gate: feature-specific specs/tests/research added before code; “FineTune has it”
alone is not an implementation requirement.
