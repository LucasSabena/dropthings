# Implementation plan

Every phase is a releasable vertical slice. Do not begin the next phase before
its gate passes.

## Phase 0 — baseline and seams

- [x] Include CommandPalette and its Platform adapters in a testable build target
  instead of relying on current SwiftPM exclusions.
- [x] Add baseline tests for existing filtering, hotkey lifecycle, and keyboard
  selection.
- [x] Introduce `PaletteResult` and adapt `CommandDescriptor` without changing
  visible behavior.
- [x] Add versioned settings and a migration from current hotkey settings.

Gate: clean build, tests run in CI/local command, existing palette behavior is
unchanged.

## Phase 1 — apps, commands, and panel reliability

- [x] Implement cached application catalog and deduplication.
- [x] Add token/fuzzy matching and deterministic ranking.
- [x] Place the panel on the active display and active Space.
- [x] Add app launch/activate and module command execution.
- [x] Add provider-specific empty/degraded diagnostics in settings.

Gate: the user can disable Spotlight/Raycast app launching for one week without
a missed daily workflow.

## Phase 2 — calculator and local history

- [x] Implement tokenizer/parser/evaluator with typed errors.
- [x] Format results using current locale without ambiguous persisted values.
- [x] Add bounded recency/frequency history and clear-history setting.
- [x] Add copy result and action recording after success.

Gate: fuzz/property tests produce no crashes, and ranking fixtures remain stable.

## Phase 3 — Spotlight files and actions

- [x] Implement cancellable `NSMetadataQuery` adapter.
- [x] Add filename search first; content search behind a setting.
- [x] Add Quick Look, open, reveal, copy path, and containing-folder actions.
- [x] Add exclusions and explain Spotlight limitations.
- [x] Add lazy icons/thumbnails with cancellation and cache bounds.

## Phase 3.5 — launcher personalization and web handoff

- [x] Rank successfully opened applications from bounded local history.
- [x] Add pin/unpin actions and an application visibility picker.
- [x] Add an opt-in search-engine and browser picker.
- [x] Hand explicit HTTPS searches to the selected running browser process via
  Launch Services without browser scripting or query-history persistence.

Gate: fast providers stay responsive during a cold Spotlight query and stale
results never appear after rapid typing.

## Phase 4 — replacement-quality polish

- [ ] Test multiple displays, scaled displays, Stage Manager, all Spaces, and
  full-screen apps.
- [x] Tune ranking from anonymized local fixtures, not hard-coded personal paths.
- [x] Add performance signposts and diagnostics.
- [ ] Complete manual matrix in `QUALITY.md`.

Gate: 14 consecutive days as the owner's default launcher with no fallback to
Spotlight/Raycast for in-scope behaviors.
