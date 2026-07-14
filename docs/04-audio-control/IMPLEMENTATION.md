# Implementation plan

## Current implementation status — 2026-07-13

The Phase 1 code slice is implemented and buildable, but the hardware gates are
not waived. It is not evidence of FineTune parity and does not authorize
removing FineTune. Automated checks cover protocol/settings/safety/lifecycle;
the permission prompt, audible loopback, latency, CPU, long-run, and application
matrix remain owner-hardware work listed in `QUALITY.md`.

The independent module menu-bar vertical slice is implemented end to end:

- [x] Generic optional module presentation contract.
- [x] Persisted per-module `Show in menu bar` preference and settings control.
- [x] App-shell `NSStatusItem`/`NSPopover` ownership with deterministic teardown.
- [x] Audio popover with output selection, master volume/mute, app mixer,
  per-app route menu, empty/error/loading states, settings, and quit.
- [x] Core Audio adapter for default output and hardware volume/mute.
- [x] VoiceOver labels/values, keyboard-operable native controls, template icon,
  semantic colors, shared spacing/type/size tokens, and Reduce Motion handling.
- [x] Debug-only deterministic visual-QA launch path; synthetic state is absent
  from Release builds.

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

- [x] Create helper/XPC target and versioned desired/observed protocol.
- [x] Implement process monitor, stable identities, transactional tap resources,
  gain ramp, soft limiter, safe bypass, and owned orphan cleanup.
- [x] Build host supervision, unavailable/failure states, multi-app UI, and
  versioned settings storage. System Audio Recording is deliberately handled at
  first tap start because macOS exposes no public preflight API.
- [x] Keep real-time callback allocation/lock/log free; add atomic peak/overload
  counters consumed off-thread.

Gate: one controlled app runs for 24 hours across quit/relaunch and helper restart
with no echo, stuck silence, orphan device, leak, or unsafe volume burst.

Gate status: **not passed**. Do not advance the release claim or uninstall
FineTune until the manual evidence below exists.

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
