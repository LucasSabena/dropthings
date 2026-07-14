# Product contract

## Outcome

A local visual thinking space for images, text, files, links, sketches and reusable project boards—more studio wall than formal design editor.

## Required capabilities

- Text cards, sticky notes, images, file cards, URL cards, rectangles, ellipses, lines, arrows, frames and freehand strokes.
- Infinite-feeling bounded coordinates, pan/zoom, lasso, multi-select, resize, z-order, group, lock, align/distribute and optional grid/snap.
- Named frames for moodboards/review sections, board search, Outline sidebar and simple presentation mode.
- Embedded assets by default for portability; explicit linked assets with Missing/Modified/Locate states.
- Temporary boards autosave in DropThings storage and can be promoted with Keep as Project.
- Portable .dropboard package with manifest.json, board.json, Assets, Previews and Recovery.
- Private board-fragment clipboard type with standard text/image fallbacks.
- PNG/PDF export using tiled rendering for very large sparse boards.

## Entry points

- Module primary action opens the dedicated product surface.
- Command Palette exposes only deterministic, previewable commands.
- Compatible file actions are published/consumed through a Core-owned registry.
- Module settings remain in the normal DropThings settings hierarchy.

## Permissions and privacy

No system permission for normal use. Security-scoped bookmarks only for explicitly linked external files; optional explicit URL metadata fetch.

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

- Real-time collaboration, accounts, comments or cloud sync.
- Full Figma/Illustrator replacement, advanced vector paths, typography engine, masks or production slices.
- Excalidraw file compatibility, copied competitor UI/code or AI moodboard generation.
