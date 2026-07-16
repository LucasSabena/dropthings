# Architecture

## Ownership

- `DropThingsModules/CommandPalette` owns query coordination, ranking,
  calculator parsing, history, result models, and panel presentation.
- `DropThingsPlatform` owns AppKit/Spotlight/Launch Services/Quick Look adapters.
- `DropThingsCore` continues to own `CommandDescriptor`, module registration,
  settings persistence, logging, and health. Do not add a general search
  abstraction to Core until a second real module needs it.
- `DropThingsDesignSystem` owns tokens and reusable controls, not search logic.

## Proposed types

Names may change, responsibilities may not be merged.

- `PaletteQueryCoordinator`: starts/cancels provider work for one query
  generation and publishes snapshots on the main actor.
- `PaletteLocalSearchProviding`: module-private provider seam used by the app,
  command/system, calculator, and web providers. Providers receive immutable
  query context and return plain `PaletteResult` values.
- `PaletteResult`: immutable value containing stable ID, kind, title, subtitle,
  icon descriptor, score inputs, and actions.
- `PaletteRanker`: pure deterministic scoring and stable sorting.
- `ApplicationCatalog`: Platform adapter that discovers and observes `.app`
  bundles, returning plain values.
- `SpotlightFileSearch`: Platform adapter around `NSMetadataQuery` or MDQuery;
  owns notification lifetimes and query cancellation.
- `CalculatorEngine`: pure tokenizer, parser, AST evaluator, and formatter.
- `PaletteHistoryStore`: bounded, versioned records using `SettingsStore`.
- `WebSearchEngine`: pure HTTPS URL construction for an explicit user query.
- `PalettePanelController`: panel lifecycle, active-display placement, focus,
  Spaces behavior, and event monitors.

## Query flow

1. Opening the palette renders cached apps, commands, and recent items before
   starting external work.
2. Text changes increment a query generation and debounce file search only.
3. Local providers calculate off the main actor and return quickly.
4. File results arrive asynchronously and are discarded if their generation is
   stale.
5. The ranker merges provider snapshots; SwiftUI receives one immutable list.
6. Executing an action records history only after the action reports success.
   Web queries are deliberately excluded so raw search text is not persisted.

App and command snapshots are cached between keystrokes. They are rebuilt only
when the application catalog, module command set, or relevant settings change;
calculator and web results remain query-specific. Result construction and
ranking run in detached work so typing does not parse calculator expressions or
sort the catalog on the main actor.

## Concurrency rules

- UI state and panel lifecycle are `@MainActor`.
- Providers never mutate shared arrays from background queues.
- Cancellation is required; generation checks are a second line of defense.
- Spotlight notifications and observers must be removed on cancellation/stop.
- Icons and thumbnails load lazily and must not reorder results when they arrive.
- Quick Look thumbnail requests are cancelled with their Swift task and use the
  shared bounded thumbnail cache. Directories use the workspace icon fallback.

## Panel placement

- Determine target screen from the mouse location, falling back to the key/main
  window screen and then `NSScreen.main`.
- Recalculate on every invocation and after display configuration changes.
- Use visible frame, not full frame, so menu bar, Dock, and notches are respected.
- The panel must join the active Space and work as a full-screen auxiliary
  surface. Do not persist absolute screen coordinates.
- While visible, reposition after `didChangeScreenParametersNotification` so a
  display attach/detach or layout change cannot strand the panel off-screen.

## Application catalog lifecycle

The Platform catalog scans only configured application roots, validates real
application bundles, filters helper bundles, deduplicates by bundle identifier
and canonical path, and caches snapshots by the complete root set. Opening the
palette reads that cache. Narrow directory monitors invalidate and rescan after
application-directory changes; settings that only pin or hide apps reuse the
existing snapshot.

## File search boundary

`NSMetadataQuery` is the first implementation because it queries Spotlight and
supports live updates. Encapsulate it behind `SpotlightFileSearching` so tests
use a fake. Never expose `NSMetadataItem` to the module layer.

## Web search boundary — 2026-07-13

Web search is an opt-in local URL-construction provider. It performs no request
while ranking or typing. On explicit execution, `PaletteWorkspace` asks
`NSWorkspace` to open the HTTPS URL with either the chosen browser bundle or the
system default. Launch Services targets an existing browser process when one is
running; final tab-versus-window placement remains the browser's policy. No
browser scripting, history access, cookies, or Automation permission is used.

## Failure boundaries

- A failed provider returns a typed diagnostic and an empty snapshot.
- Calculator parse failures are normal “not a calculation” outcomes.
- An unavailable Spotlight index does not prevent app/command/calculator search.
- Failed result actions keep the palette open and display an inline error.

## Keyboard ownership and transient panels — 2026-07-16

- Local keyboard monitors must match the owning panel's window number as well
  as key-window status. `orderOut` does not dismantle an `NSHostingView`, so an
  unscoped monitor can otherwise keep consuming `C`, arrows, Return, or Escape
  after its panel is hidden.
- `TransientSurfaceCoordinator` in Core coordinates the Command Palette, File
  Shelf, Clipboard History, and Smart Clipboard without module-to-module
  imports. Presenting one dismisses the other registered surfaces.
- The app shell dismisses all registered transient surfaces when DropThings
  resigns active. This uses `orderOut` rather than `hidesOnDeactivate`, because
  AppKit automatically restores a merely deactivated panel when the app becomes
  active again.
