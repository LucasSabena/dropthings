# Architecture

## Ownership and boundaries

- SessionRecorder module owns settings, source selection, suggestion policy, controller/history and module state.
- Platform/Recording owns ScreenCaptureKit, microphone adapter, common timeline/mixer, writer, device observation and permissions.
- MediaKit owns output format/settings, naming, probe/validation and optional post-conversion.
- One explicit engine actor—or XPC if the spike proves necessary—owns every capture/writer resource with transactional start/idempotent stop.
- Core FileActionRegistry provides Transcribe/Convert/Add actions; generic power assertion replaces any direct dependency on KeepAwakeModule.

## Primary pipeline

`explicit start → permission/device/disk preflight → acquire power assertion → owned session dir → start sources/writer → timestamped mix/write → pause/markers → stop → writer finish → output re-probe/atomic move → actions/history → teardown`

## Cross-module rule

Modules never import each other. Shared behavior belongs in Core, a justified
Foundation-only kit, or narrow Platform adapters. Actions disappear safely when a
target module is disabled or absent.

## Concurrency

- Main actor owns presentation and user-facing state only.
- Long media, inference, document and capture operations run off the main actor.
- Progress is throttled before reaching SwiftUI.
- Cancellation is explicit, idempotent and cleans only resources provably owned by
  the current job/document/session.
- Every long-running operation has a bounded shutdown path.

## Persistence and atomicity

- Version all persisted schemas.
- Write to owned temporary/staging locations first.
- Validate before atomic finalization.
- Startup cleanup uses ownership manifests/leases and never deletes unknown files.
- Unknown future data is preserved or opened read-only rather than silently lost.

## Diagnostics and privacy

Default diagnostics contain stable IDs, state, duration, sizes and error categories,
not clipboard text, transcripts, audio samples, board content or embedded metadata.
Sensitive paths are redacted where practical.

## Key risks

- Persistent status item cannot be hideable while recording; app shell may need a required-while-active visibility policy.
- System and mic must use sample/host timestamps and bounded drift correction—not UI arrival time.
- Suggestions remain off by default and only open preflight; they never request permission or create a file.
- Recording consent/law reminders should be neutral product copy, not legal advice.
