# Implementation plan

Every phase is a releasable vertical slice. Do not begin the next phase before
its gate passes.

## Phase 0 — baseline and seams

- [ ] Include CommandPalette and its Platform adapters in a testable build target
  instead of relying on current SwiftPM exclusions.
- [ ] Add baseline tests for existing filtering, hotkey lifecycle, and keyboard
  selection.
- [ ] Introduce `PaletteResult` and adapt `CommandDescriptor` without changing
  visible behavior.
- [ ] Add versioned settings and a migration from current hotkey settings.

Gate: clean build, tests run in CI/local command, existing palette behavior is
unchanged.

## Phase 1 — apps, commands, and panel reliability

- [ ] Implement cached application catalog and deduplication.
- [ ] Add token/fuzzy matching and deterministic ranking.
- [ ] Place the panel on the active display and active Space.
- [ ] Add app launch/activate and module command execution.
- [ ] Add provider-specific empty/degraded diagnostics in settings.

Gate: the user can disable Spotlight/Raycast app launching for one week without
a missed daily workflow.

## Phase 2 — calculator and local history

- [ ] Implement tokenizer/parser/evaluator with typed errors.
- [ ] Format results using current locale without ambiguous persisted values.
- [ ] Add bounded recency/frequency history and clear-history setting.
- [ ] Add copy result and action recording after success.

Gate: fuzz/property tests produce no crashes, and ranking fixtures remain stable.

## Phase 3 — Spotlight files and actions

- [ ] Implement cancellable `NSMetadataQuery` adapter.
- [ ] Add filename search first; content search behind a setting.
- [ ] Add Quick Look, open, reveal, copy path, and containing-folder actions.
- [ ] Add exclusions and explain Spotlight limitations.
- [ ] Add lazy icons/thumbnails with cancellation and cache bounds.

Gate: fast providers stay responsive during a cold Spotlight query and stale
results never appear after rapid typing.

## Phase 4 — replacement-quality polish

- [ ] Test multiple displays, scaled displays, Stage Manager, all Spaces, and
  full-screen apps.
- [ ] Tune ranking from anonymized local fixtures, not hard-coded personal paths.
- [ ] Add performance signposts and diagnostics.
- [ ] Complete manual matrix in `QUALITY.md`.

Gate: 14 consecutive days as the owner's default launcher with no fallback to
Spotlight/Raycast for in-scope behaviors.
