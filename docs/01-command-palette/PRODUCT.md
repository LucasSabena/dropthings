# Product contract

## In scope

### Root search

- Empty query: recent and frequently used results, grouped sparingly.
- Text query: merge results from all enabled providers into one ranked list.
- Result kinds: application, module command, file, folder, calculation, and
  system action.
- Results update incrementally; slow providers never blank fast results.
- Search is accent-insensitive and case-insensitive and supports fuzzy token
  matching, initials, aliases, and word boundaries.

### Applications

- Discover user, system, and explicitly configured application locations.
- Deduplicate by canonical bundle URL/bundle identifier.
- Hide helpers, login items, and invalid bundles by default.
- Launch or activate with Return; reveal in Finder and copy path from actions.

### Files and folders

- Query the existing Spotlight metadata index; do not crawl the whole disk on
  each query and do not build a private content index in the first release.
- Default scope: user home plus mounted local volumes visible to Spotlight.
- Support filename and optional content search as separate settings.
- Actions: open, reveal in Finder, Quick Look, copy path, open containing folder,
  and open with the default application.
- Explain that excluded, unindexed, remote-only, and permission-protected files
  may not appear.

### Calculations

- Arithmetic: parentheses, unary signs, `+ - * / % ^`.
- Common functions: `sqrt`, `abs`, `min`, `max`, `round`, `floor`, `ceil`.
- Constants: `pi` and `e`.
- Copy result with Return; never evaluate arbitrary Swift, JavaScript, shell, or
  `NSExpression` input.
- Locale-aware decimal input may be normalized, while persisted history stores
  a locale-independent representation.

### DropThings and system actions

- Every enabled module may contribute existing `CommandDescriptor` values.
- Disabled modules may contribute only an explicit “Open module settings” item.
- Curated system actions must use public APIs or narrow Platform adapters.
- Destructive actions such as trash emptying, logout, restart, or shutdown
  require a confirmation step and are not part of the first slice.

### Ranking and history

- Base score includes provider priority, exact/prefix/token/fuzzy match,
  filename/app-name quality, and Spotlight relevance where available.
- Local history adds recency and frequency without permanently burying new
  results.
- History stays on device, has a clear/reset control, and stores stable result
  identifiers rather than raw file contents.
- Tie-breaking is stable and covered by tests.

## States

- Disabled: no hotkey, index activity, observers, or history writes.
- Running: all configured providers healthy.
- Degraded: one provider failed; the rest remain usable and the failure is shown
  in settings, not as a modal over search.
- Unavailable: a feature requires a newer macOS version; other providers work.
- Error: panel itself cannot open or the hotkey cannot register; settings offer
  recovery.

## Settings

- Global shortcut.
- Included providers and their scopes.
- File-content search toggle.
- Include hidden files toggle.
- App/file exclusion paths.
- Maximum results per provider.
- Clear usage history and restore defaults.
- Settings are a versioned `Codable` model with explicit migrations.

## Explicit non-goals

- Raycast AI, accounts, sync, teams, store, React extension runtime, or cloud.
- Searching arbitrary content inside every third-party app.
- Browser tabs/history until a separate, explicitly permissioned integration is
  requested.
- A shell command runner.
- A replacement Spotlight indexer in the first release.
