# Product contract

## Outcome

A local content-aware action layer for the current clipboard that complements Clipboard History instead of duplicating it.

## Required capabilities

- Text: plain text, trim, whitespace/line normalization, case conversion, line sort/deduplicate, URL/Base64/HTML entity encode/decode and counts.
- URL: normalize, copy Markdown link, remove inspectable tracking parameters, QR, and explicit user-triggered title fetch.
- JSON: validate, pretty print, minify, optional sort keys and precise first parse error.
- Color: parse HEX/RGB/HSL/CSS and convert to HEX, RGB, HSL, CSS, SwiftUI and NSColor while preserving alpha.
- Files/images: reveal, copy names/paths, dimensions/size, save a representation, or invoke Media Converter/Workbench through Core actions.
- Pinned actions, Treat As… for ambiguous text, and sensitive preview hiding.
- Undo Copy restores the previous snapshot for a bounded period.

## Entry points

- Module primary action opens the dedicated product surface.
- Command Palette exposes only deterministic, previewable commands.
- Compatible file actions are published/consumed through a Core-owned registry.
- Module settings remain in the normal DropThings settings hierarchy.

## Permissions and privacy

No permission for inspect/copy actions. Optional paste automation may request Accessibility only when enabled.

All processing is local. User content is excluded from default diagnostics. Any
network action must be explicit, narrowly scoped and described before it runs.

## States

The implementation must represent disabled, starting, running, needs-permission,
degraded and failed states, plus product-specific per-job/document/session states.
A failure must remain actionable and must not silently discard work.

## Settings

Use a versioned typed settings model with migrations. Persist stable identifiers,
not localized names. Corrupt settings are sanitized or quarantined and cannot crash
module startup.

## Explicit non-goals for v1

- Cloud/LLM writing, summarization or translation.
- Password-manager replacement or secret sync.
- Silent global clipboard rewriting, automatic URL fetching or a second persistent history database.
