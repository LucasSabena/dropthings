# Architecture

## Ownership and boundaries

- DropThingsCore/Clipboard owns PasteboardHub, snapshots, subscriber lifecycle, origin tokens and redaction-safe metadata.
- DropThingsPlatform/Pasteboard owns NSPasteboard reads/writes, active-app/focus capture and optional safe paste adapter.
- SmartClipboard module owns deterministic classifiers, action registry, panel, settings and hotkey.
- Clipboard History is migrated to PasteboardHub before Smart Clipboard registration.
- Core FileActionRegistry supplies optional actions from other modules without direct imports.

## Primary pipeline

`pasteboard change → bounded typed snapshot → local classifiers → ordered compatible actions → preview → explicit copy/paste/open/create → origin-token loop prevention`

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

- Two pasteboard observers or content-hash-only deduplication will create races/duplicates.
- Accessibility must remain optional for basic use.
- Ambiguous strings must retain general text actions.
- Logs/crash diagnostics must contain only type, size and action IDs—not content.
