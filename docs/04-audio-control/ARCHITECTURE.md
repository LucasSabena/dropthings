# Architecture

## Mandatory process boundary

The real-time audio engine must run outside the main DropThings UI process as an
XPC service or dedicated bundled helper. The host owns product state/UI; the
helper owns taps, aggregate devices, IO callbacks, DSP, routing, and cleanup.
Choose the exact packaging after a minimal XPC/helper spike, but do not ship an
in-process final engine.

### Packaging decision — 2026-07-13

The engine is an embedded `AudioControlEngine.xpc` service with a macOS 15
deployment target. The host and helper share only the platform-neutral
`DropThingsAudioControlKit` SwiftPM product. XPC payloads are versioned JSON
`Data`, so the Objective-C XPC interface stays deliberately tiny and unknown
fields can be introduced compatibly. The app remains macOS 14-compatible and
shows Audio Control as unavailable below macOS 15.

The IO callback is implemented in Objective-C++ and owns a preallocated C++
state block containing only atomics. Swift/Objective-C objects, allocation,
locks, logging, file/network access, and dispatch are absent from the callback.
All Core Audio resource creation and teardown stays off the real-time thread.

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

## Independent module menu-bar surface — 2026-07-13

The menu-bar capability is a core/app-shell contract, not Audio Control-specific
AppKit code:

- `DropThingsModule.menuBarPresentation` optionally declares the SF Symbol,
  accessibility label, preferred size, default visibility, and compact view.
- `ModuleMenuBarPreferences` in Core persists explicit per-module choices as a
  single typed map under `core.modules.menu-bar-visibility`.
- `ModuleMenuBarController` in the app target owns every `NSStatusItem` and
  transient `NSPopover`, observes registry/preference changes, closes sibling
  popovers, and supplies the common settings/quit footer.
- A status item exists only while its module is registered, enabled, and visible
  by preference. A failed/degraded module keeps its item so recovery remains
  reachable; disabling the module removes it and releases the popover.
- Modules do not depend on one another and never own `NSStatusItem` lifecycle.

Audio Control supplies `AudioControlMenuBarView`. System default output and
hardware volume use the narrow `SystemAudioOutputControlling` Platform adapter;
per-app routing remains desired state reconciled by the isolated XPC engine.

## Desired-state protocol

The host sends versioned immutable desired state keyed by stable app/device IDs.
The helper responds with versioned observed state, per-resource health, meters,
and typed events. Reconnection is idempotent: resend full desired state instead
of replaying an unbounded command log.

Messages include protocol version, request/generation ID, and deadline. Unknown
new fields are tolerated where encoding permits; incompatible versions force
safe bypass and a clear unavailable state.

## Now Playing compatibility boundary — 2026-07-14

With explicit owner approval, the XPC helper dynamically loads the private
`MediaRemote` framework to read the system-wide active Now Playing session and
send play/pause/previous/next commands. This is the only practical no-extension
path for compatible Spotify and browser sessions (including YouTube/Netflix).
It is not an App Store-safe or OS-stable API. The wrapper is synchronous with a
short timeout, returns no media state when unavailable, and is isolated from
the real-time path; a failure must never affect audio processing or output.

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

The current helper creates private taps and private aggregate devices. Private
resources die with the helper, while aggregate UIDs use the
`app.dropthings.audio.` prefix plus session identity. A process tap uses
`mutedWhenTapped`, so the original route is not muted until the aggregate IOProc
is successfully reading. Construction failures call the same reverse-order
teardown as normal bypass: IOProc, aggregate, then tap.

## Process and device identity

- Runtime AudioObjectIDs are ephemeral.
- Apps persist by bundle ID; helper/system processes receive a documented
  composite fallback and are not auto-controlled unless explicitly pinned.
- Devices persist by Core Audio UID; disappearance retains desired routing but
  observed state uses safe fallback.
- Discovery groups all active Core Audio processes belonging to the same outer
  application bundle. This makes multi-process apps (for example Electron)
  one app row and passes every active process ID to the tap. Once discovered,
  an app row remains visible while its application is running, even if Core
  Audio transiently reports no output. Its tap is always torn down until output
  is active again.

## Recovery

- Helper crash/disconnect marks engine failed and offers restart; supervisor has
  bounded exponential backoff and crash-loop cutoff.
- Helper startup first performs safe owned-resource cleanup before applying state.
- Sleep begins controlled quiesce; wake rediscovers devices/processes and
  reconciles from desired state.
- Permission loss or protocol mismatch triggers safe bypass/cleanup.
- A failed process-tap/aggregate start is quarantined for that app for the
  current engine session. Periodic reconciliation must never retry it, because
  macOS can show the System Audio Recording permission prompt when an aggregate
  starts. Restarting the engine is the explicit retry action.
