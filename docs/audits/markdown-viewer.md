# Audit — Markdown Viewer module

Module: `modules.markdown-viewer` (`Sources/DropThingsModules/MarkdownViewer/`)

## Purpose

A small native window that opens any `.md` file, lets the user **read**
the rendered GitHub-Flavored Markdown (tables, fenced code with syntax
highlighting, nested lists, task lists, images, strikethrough, autolinks),
and **edit** the source side-by-side with a live preview. Summonable via
a global hotkey, the menu-bar primary action, drag-and-drop of a `.md`
file onto the window, or an "Open…" button inside the window.

## Permissions

- `requiredPermissions: []`. None.
- File access is granted per-file by `NSOpenPanel` or by drag-and-drop
  (AppKit hands the app a URL the user explicitly dropped). No
  security-scoped bookmarks are stored, so the app cannot silently read
  those files again after relaunch unless the user reopens them.
- The "recent files" list persists display metadata (name + bookmark of
  the parent dir is **not** persisted; only the absolute path string is
  stored, so tapping a recent entry that no longer exists shows a clear
  error instead of re-granting access).

## Data model

`MarkdownViewerSettings` (Codable, JSON blob under
`modules.markdown-viewer.settings`):

- `hotkeyEnabled: Bool` (default true)
- `hotkey: GlobalHotkey.Definition?` (default `⌥⌘M`, id `501`)
- `theme: MarkdownTheme` (`.auto` / `.light` / `.dark`, default `.auto`)
- `fontSize: Int` (12…24, default 14)
- `layout: MarkdownLayout` (`.split` / `.editor` / `.preview`, default
  `.split`)
- `showLineNumbers: Bool` (default false)
- `openFinderSelectionWithHotkey: Bool` (default false) — opt-in; when on
  and Finder is frontmost, the hotkey reads Finder's selection via
  AppleScript and opens the selected `.md` file(s) as tabs. Triggers
  macOS' Automation prompt for Finder the first time.
- `recentFiles: [RecentFile]` capped at 8

`RecentFile`:

- `id: UUID`
- `url: URL` (absolute path; not a security-scoped bookmark)
- `name: String` (basename, for display)
- `lastOpened: Date`

`MarkdownDocument` (in-memory, `ObservableObject`, not persisted):

- `id: UUID` (stable identity for SwiftUI `ForEach`)
- `url: URL?`
- `text: String`
- `isDirty: Bool`
- `isLoading: Bool`
- `loadError: String?`

The module owns `openDocuments: [MarkdownDocument]` with an
`activeDocumentIndex`; the window renders one tab per document.

## States

- `off` — disabled.
- `running` — hotkey registered, window controller ready (window not
  necessarily visible).
- `degraded(reason:)` — hotkey conflict, or last file failed to load.
  The window can still open; only the global shortcut is unavailable
  in the conflict case.
- No `needsPermission`, no `unavailable`, no `failed` for v1.

## Edge cases

- **Hotkey conflict** → `.degraded` with a rebind hint; the in-window
  "Open…" button still works.
- **File no longer exists** (recent entry) → `loadError` shown inline;
  recent entry is removed on the next successful open of a different
  file.
- **Unsaved changes** → close prompts to save / discard / cancel.
- **Window close with several dirty tabs** → resolves each tab before the
  window closes; canceling any prompt keeps the window open.
- **Drag-and-drop of a non-`.md` file** → ignored with a brief inline
  notice; the window keeps its current document.
- **Very large file** (> 5 MB) → loaded synchronously but preview render
  is debounced 200 ms after the last keystroke to keep typing smooth.
- **Drag text directly (no file)** → opens as an untitled document so
  the user can paste-and-preview Markdown that did not come from disk.
- **Theme `.auto`** follows `NSApp.effectiveAppearance` and updates the
  preview live when the system appearance changes.

## Manual checks

See `docs/manual-checks.md` § 9.

Standard commands: ⌘O Open, ⌘S Save, ⇧⌘S Save As, ⌘W close active tab,
⇧⌘W close the viewer window. Cut/copy/paste, undo/redo, select all, and Find
remain native `NSTextView` behaviors.

## Tests

Pure logic only:

- `MarkdownViewerSettings` round-trip (defaults, custom values, missing
  fields decode to defaults).
- `recentFiles` cap enforcement.
- `defaultMarkdownViewerHotkey` is included in the shipped-default
  chord uniqueness test.
- Document load/save success, dirty-state clearing, failed-load errors, and
  accepted Markdown extensions.
