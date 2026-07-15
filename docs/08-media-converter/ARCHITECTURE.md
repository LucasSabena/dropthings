# Architecture

## Ownership and boundaries

- DropThingsModules/MediaConverter owns queue UI, presets, history and coordination.
- New Foundation-only DropThingsMediaKit owns format IDs, probe/result DTOs, presets, naming, validation and typed FFmpeg argument construction.
- DropThingsPlatform/Media owns ImageIO/Core Image/AVFoundation adapters, security scope, disk checks and process supervision.
- An XPC/dedicated helper owns FFmpeg execution so codec crashes cannot terminate DropThings.
- Core FileActionRegistry exposes Convert/Inspect actions without any module importing Media Converter.

## Primary pipeline

`intake → security scope → probe → preset validation → conflict/disk preflight → temporary output → encode/remux → output re-probe → atomic move → result → cleanup`

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

- FFmpeg must be pinned and reproducibly built; publish exact source, configure line, patches, checksums and notices.
- Do not expose a setting the chosen backend ignores.
- Do not finalize an output before successful re-probe.
- Replace-original stays disabled until rollback/recovery is proven.
