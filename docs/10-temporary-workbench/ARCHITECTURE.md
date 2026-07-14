# Architecture

## Ownership and boundaries

- One board document controller owns file coordination, autosave, undo, recovery and window lifecycle.
- TemporaryWorkbench module owns board library, canvas, tools, inspectors and settings.
- Platform/Documents owns bookmarks, coordinated package IO, Quick Look/file icons and optional URL metadata.
- Board model uses stable IDs, typed item payloads, transforms, z-order, groups/frames, asset index and versioned schema.
- A spatial index culls/hit-tests visible items; full-resolution images are not decoded for offscreen thumbnails.

## Primary pipeline

`intake/paste → placeholder → embed/link asset → semantic board operation → coalesced autosave/recovery → atomic package replacement → thumbnail/search index`

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

- Autosave must never write every pointer sample or replace a valid package with a partial one.
- Unknown future item types should be preserved or opened read-only, not silently discarded.
- Undo/image memory needs strict budgets and downsampling.
- Do not commit private/client assets as fixtures.
