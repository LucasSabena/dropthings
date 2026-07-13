# Product contract

## Core mixer

- Discover currently active output-audio processes and map them to applications.
- Per-app volume from silent to 100%; optional boost above 100% is a separate,
  clearly labeled control protected by limiter/headroom policy.
- Per-app mute, solo, and reset-to-default.
- Pin apps so settings can exist before audio starts; ignore apps to leave their
  audio completely untouched and tear down associated taps.
- Persist settings by bundle ID plus explicit fallback for processes without one.
- Live level meters are diagnostic/visual only and must not drive unsafe gain.

## Device controls and routing

- List output devices with stable UID, transport, availability, sample rate, and
  volume-control capability.
- Select the system/default output where supported.
- Route one app to one selected output or follow the system default.
- Restore per-app routing when a device reconnects; fall back safely when absent.
- Later: route to multiple devices with explicit synchronization/latency warning.
- Device hardware/software volume, DDC, Bluetooth connection management, and
  input/microphone control are advanced phases, not core mixer requirements.

## Processing

- Per-app 10-band EQ with neutral default and presets.
- Smooth parameter/gain changes to prevent clicks.
- Soft limiter before output; never market boost without clipping protection.
- Bypass must be bit-transparent enough for the supported pipeline and must tear
  down processing when an app is ignored.
- Later: user presets, AutoEQ profile import/search, headphone correction,
  loudness compensation, and ISO equal-loudness contours.

## Lifecycle and recovery

- Handle app audio start/stop, app quit/relaunch, device add/remove/default
  change, sample-rate change, sleep/wake, engine/helper crash, permission revoke,
  and DropThings/module stop.
- Startup cleanup removes only orphan resources owned by DropThings.
- On any uncertain failure, prefer restoring unprocessed direct system audio to
  retaining a broken tap.
- Disable/bypass is always available even when settings persistence fails.

## States and permissions

- Disabled, unavailable OS, needs System Audio Recording permission, starting,
  running, degraded per app/device, and failed engine with restart/bypass action.
- Add `NSAudioCaptureUsageDescription` before invoking taps.
- Prompt only when the user enables the module or explicitly starts the first
  controlled app; denial leaves normal audio untouched.

## Settings

- Versioned global, device, and per-app settings.
- Pinned/ignored apps, default gain, boost permission, routing fallback, EQ,
  hidden devices, meters, and advanced diagnostics.
- Never use app display names or transient AudioObjectIDs as persistent keys.

## Explicit non-goals for first release

- Recording audio to disk, microphone capture, streaming, analytics, or network
  upload.
- Private audio APIs, third-party virtual audio drivers, or kernel extensions.
- Claiming universal DAC/HDMI/DDC/Bluetooth support without tested evidence.
