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
- `PaletteSearchProvider`: private module protocol with stable identifier,
  supported query mode, and async result stream/return value.
- `PaletteResult`: immutable value containing stable ID, kind, title, subtitle,
  icon descriptor, score inputs, and actions.
- `PaletteRanker`: pure deterministic scoring and stable sorting.
- `ApplicationCatalog`: Platform adapter that discovers and observes `.app`
  bundles, returning plain values.
- `SpotlightFileSearch`: Platform adapter around `NSMetadataQuery` or MDQuery;
  owns notification lifetimes and query cancellation.
- `CalculatorEngine`: pure tokenizer, parser, AST evaluator, and formatter.
- `PaletteHistoryStore`: bounded, versioned records using `SettingsStore`.
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

## Concurrency rules

- UI state and panel lifecycle are `@MainActor`.
- Providers never mutate shared arrays from background queues.
- Cancellation is required; generation checks are a second line of defense.
- Spotlight notifications and observers must be removed on cancellation/stop.
- Icons and thumbnails load lazily and must not reorder results when they arrive.

## Panel placement

- Determine target screen from the mouse location, falling back to the key/main
  window screen and then `NSScreen.main`.
- Recalculate on every invocation and after display configuration changes.
- Use visible frame, not full frame, so menu bar, Dock, and notches are respected.
- The panel must join the active Space and work as a full-screen auxiliary
  surface. Do not persist absolute screen coordinates.

## File search boundary

`NSMetadataQuery` is the first implementation because it queries Spotlight and
supports live updates. Encapsulate it behind `SpotlightFileSearching` so tests
use a fake. Never expose `NSMetadataItem` to the module layer.

## Failure boundaries

- A failed provider returns a typed diagnostic and an empty snapshot.
- Calculator parse failures are normal “not a calculation” outcomes.
- An unavailable Spotlight index does not prevent app/command/calculator search.
- Failed result actions keep the palette open and display an inline error.
