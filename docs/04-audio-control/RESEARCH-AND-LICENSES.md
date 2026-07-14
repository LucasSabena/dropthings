# Research and licenses

Last researched: 2026-07-13.

## Primary technical sources

- Apple “Capturing system audio with Core Audio taps” sample. Requires macOS
  14.2+, `NSAudioCaptureUsageDescription`, and System Audio Recording permission:
  <https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps>
- Apple `CATapDescription`:
  <https://developer.apple.com/documentation/coreaudio/catapdescription>
- Apple `AudioHardwareCreateProcessTap`:
  <https://developer.apple.com/documentation/coreaudio/audiohardwarecreateprocesstap(_:_:)>
- Apple `AudioHardwareProcess`:
  <https://developer.apple.com/documentation/coreaudio/audiohardwareprocess>
- Apple aggregate device model:
  <https://developer.apple.com/documentation/coreaudio/audiohardwareaggregatedevice>
- Apple Core Audio property listeners:
  <https://developer.apple.com/documentation/coreaudio/audiohardwareobject/addlistener(forproperties:dispatchqueue:)>

The official Apple sample archive was downloaded and inspected on 2026-07-13 to
verify the public tap/aggregate/IOProc lifecycle. Its `LICENSE.txt` is an MIT-like
permissive license, copyright Apple Inc. 2024. No sample source file was copied;
the DropThings helper was implemented independently against the documented API
contract, uses no recording path, and has a different transactional/XPC design.

## Now Playing compatibility research — 2026-07-14

- Apple’s public `MPRemoteCommandCenter` API lets an app receive commands for
  its own playback; it does not expose the active session of other apps.
- The owner explicitly approved a compatibility exception for the private
  `/System/Library/PrivateFrameworks/MediaRemote.framework` on 2026-07-14.
  The implementation dynamically resolves the small set of read/transport
  symbols at runtime in the XPC helper. It is omitted from the real-time path
  and fails closed (no media card/controls) when unavailable.
- `ungive/media-control`, revision `3ac3d4bdf862c7b5399b4fba4df5689f5c38609a`,
  BSD-3-Clause, was inspected for compatibility behavior and symbols. No source
  or headers were copied; DropThings uses an independently written, narrow
  dynamic wrapper. Its README warns that this private-framework approach may
  break across macOS releases.

## FineTune inspection

- Repository: <https://github.com/ronitsingh10/FineTune>
- Inspected commit: `2285279d36d3f8115c1c2d4aecd904f1bdf96a51`.
- License: GNU GPL version 3, copyright Ronit Singh 2026.
- Snapshot scale: 205 Swift files, approximately 41,567 Swift lines.
- Declared requirement: macOS 15+ and audio capture permission.
- Relevant areas inspected: `Audio/Engine` (tap controller/resources, crash guard,
  crossfade, echo/orphan cleanup, limiter), `Audio/Monitors`, `Audio/EQ`,
  `Audio/Loudness`, `Audio/DDC`, device extensions, permission, coordination, and
  settings/views.
- Product inventory observed: per-app volume/boost/mute/pin/ignore, device
  routing and multi-output, reconnect restore, EQ/presets/AutoEQ/loudness, input
  and alert volume, DDC/software volume, inspector, Bluetooth, media/menu-bar
  behaviors, and automation URLs.

## Reuse decision

The root project is relicensed to GPL-3.0-only so GPLv3 FineTune code can be
selectively incorporated into the combined private program. Do not copy the
whole app. DropThings has different lifecycle, module, settings, and process-
isolation requirements; adapt only verified pieces after the feasibility spike.

Relicensing audit on 2026-07-13: repository history reports only Lucas Sabena
(two email identities) as commit author. The owner explicitly requested the
license change. If a later audit finds independently copyrighted contributions,
obtain their consent or exclude/rewrite that code before conveying the project
under the new license.

The GPL permits private modification/use without publishing. If DropThings or a
binary containing FineTune-derived code is ever conveyed to another person or
made public, the combined covered work and corresponding source must be offered
under GPLv3 terms. See GNU's FAQ:
<https://www.gnu.org/licenses/gpl-faq.en.html#GPLRequireSourcePostedPublic>.

This is a project compliance decision, not legal advice.

## Repository-wide third-party baseline retained after the docs reset

These dependencies predate the four replacement products and remain part of
the GPL-covered distribution under their compatible original notices:

- Sparkle 2.9.3, revision `d46d456107feacc80711b21847b82b07bd9fb46e`,
  updater framework, permissive license plus bundled external notices. Its full
  license ships inside the resolved Sparkle artifact/framework.
- Marked 12.0.2, MIT, vendored at
  `Sources/DropThingsModules/MarkdownViewer/Resources/marked.min.js`; full notice
  remains beside it as `marked.LICENSE`.
- Highlight.js 11.9.0 (`f47103d4f1`), BSD-3-Clause, vendored at
  `Sources/DropThingsModules/MarkdownViewer/Resources/highlight.min.js`; full
  notice remains beside it as `highlight.LICENSE`.

Do not remove, replace, or update these dependencies without updating versions,
notices, security review, and this inventory. GPL-3.0-only does not erase their
copyright or attribution requirements.

## Reuse ledger

No FineTune source has been copied into DropThings as of 2026-07-13.

| DropThings file | FineTune source file | Commit | License | Modification |
| --- | --- | --- | --- | --- |
| _none_ | | | | |

Before copying: record the row, preserve copyright/GPL notices, add source
comments, keep the exact upstream commit, and note subsequent divergence.
AutoEQ data/code and any transitive resource require their own license review.
