# Architecture

## Ownership and boundaries

- TranscriptionEngine.xpc/dedicated helper owns whisper context, VAD and inference; host owns queue, models, review and output files.
- New Foundation-only DropThingsTranscriptionKit owns versioned host/helper messages and transcript/model schemas.
- DropThingsMediaKit/Platform Media owns probe, track selection and normalized PCM generation shared with Media Converter.
- Model store uses .partial downloads, cryptographic checksum, atomic install and active-job leases.
- Raw immutable transcript result is separate from optional user-edited revision; default logs redact all content.

## Primary pipeline

`intake → probe/track → decode to owned 16 kHz mono PCM → optional VAD → helper model lease/load → segment events → validated result → atomic TXT/MD/SRT/VTT/JSON → cleanup`

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

- Pin exact whisper.cpp/model/VAD artifacts, versions, checksums, licenses and build flags.
- Do not claim resume unless a real checkpoint format exists; interrupted jobs restart honestly.
- Core ML is optional until generation/distribution is reproducible.
- Do not add diarization without separate model/license/privacy research.
