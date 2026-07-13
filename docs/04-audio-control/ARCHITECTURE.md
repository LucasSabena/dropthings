# Architecture

## Mandatory process boundary

The real-time audio engine must run outside the main DropThings UI process as an
XPC service or dedicated bundled helper. The host owns product state/UI; the
helper owns taps, aggregate devices, IO callbacks, DSP, routing, and cleanup.
Choose the exact packaging after a minimal XPC/helper spike, but do not ship an
in-process final engine.

Reasons: real-time callbacks have strict constraints, Core Audio/device faults
are unusually disruptive, and one utility module must not crash the whole hub.

## Ownership

- `DropThingsModules/AudioControl`: view models, user settings, desired state,
  permission/health presentation, and helper supervision.
- `DropThingsPlatform/Audio`: helper client, process/device discovery adapters,
  permission bridge, and DTO mapping.
- Bundled audio helper target: Core Audio tap/aggregate device lifetimes, IO,
  routing, DSP, meters, orphan cleanup, and atomic state reconciliation.
- Pure DSP/settings logic should live in a testable package target usable by the
  helper without importing SwiftUI/AppKit.

## Desired-state protocol

The host sends versioned immutable desired state keyed by stable app/device IDs.
The helper responds with versioned observed state, per-resource health, meters,
and typed events. Reconnection is idempotent: resend full desired state instead
of replaying an unbounded command log.

Messages include protocol version, request/generation ID, and deadline. Unknown
new fields are tolerated where encoding permits; incompatible versions force
safe bypass and a clear unavailable state.

## Audio graph per controlled app

Conceptual pipeline:

`process output → CATapDescription/process tap (mute original) → aggregate/input
IO → gain ramp → EQ/processing → soft limiter → selected output device(s)`.

Exact IO implementation may use Core Audio device IO and DSP buffers; avoid
adding AVAudioEngine merely for convenience unless latency/routing tests prove
it appropriate.

## Real-time rules

- IO callback: no allocation, locks, Objective-C/Swift reference traffic that may
  allocate, logging, file/network access, UI dispatch, or blocking calls.
- Parameters cross through preallocated atomic/ring-buffer state.
- Meters use lock-free bounded buffers and may drop updates.
- DSP state is prepared outside the callback and swapped safely.
- All errors become compact counters/events consumed off the real-time thread.

## Resource ownership

- One owner object per tap/aggregate device/IOProc with explicit lifecycle.
- Creation is transactional: if any step fails, unwind created resources in
  reverse order and leave original audio unmuted.
- Store generated resource UIDs with DropThings prefix and session identity.
- Startup orphan cleanup verifies ownership; never delete user-created aggregate
  devices or another application's taps.
- Ignore/bypass destroys the tap and processing path, not merely gain=1.

## Process and device identity

- Runtime AudioObjectIDs are ephemeral.
- Apps persist by bundle ID; helper/system processes receive a documented
  composite fallback and are not auto-controlled unless explicitly pinned.
- Devices persist by Core Audio UID; disappearance retains desired routing but
  observed state uses safe fallback.

## Recovery

- Helper crash/disconnect marks engine failed and offers restart; supervisor has
  bounded exponential backoff and crash-loop cutoff.
- Helper startup first performs safe owned-resource cleanup before applying state.
- Sleep begins controlled quiesce; wake rediscovers devices/processes and
  reconciles from desired state.
- Permission loss or protocol mismatch triggers safe bypass/cleanup.
