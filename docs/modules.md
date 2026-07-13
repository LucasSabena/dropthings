# Shipping Modules

DropThings intentionally ships six maintained modules. `Package.swift`
excludes retired experiments from the shipping module target and its test
target. `AppServices` registers only the modules below and prunes persisted
enablement for anything no longer registered.

## File Shelf

A floating visual shelf for files, folders, text, and URLs in transit. It has
Finder-style multi-selection, list/grid layouts, collections, real thumbnails,
Quick Look, metadata, drag-out, and explicit batch actions.

- Code: `Sources/DropThingsModules/FileShelf/`
- Permission: none
- Default shortcut: `⌥⌘S`
- States: `off`, `running`, `degraded`

## Clipboard History

A searchable master/detail history for text, links, colors, images, videos,
audio, documents, and folders. Single-click previews; Return or Paste executes.
File-backed content uses Quick Look and rows support drag-out. History persists
under Application Support; unpinned entries default to 30 days/200 items and
raw image assets have a configurable 250 MB default limit.

- Code: `Sources/DropThingsModules/ClipboardHistory/`
- Permission: none
- Default shortcut: `⌥⌘V`
- States: `off`, `running`, `degraded`

## Color Picker

The native `NSColorSampler` provides the live eyedropper. Picking publishes a
native color plus configured HEX/RGB/HSL/SwiftUI/CSS text and shows compact
copy feedback. Favorites and rolling history remain local.

- Code: `Sources/DropThingsModules/ColorPicker/`
- Permission: none
- Default shortcut: `⌥⌘C`
- States: `off`, `running`, `degraded`

## Scroll Control

Adjusts scroll direction per device using a scroll-wheel-only `CGEvent` tap.
Trackpad, mouse wheel, and Magic Mouse can differ; speed and per-app overrides
are optional.

- Code: `Sources/DropThingsModules/ScrollControl/`
- Permission: Accessibility, requested only while enabling the module
- Default shortcut: none
- States: `off`, `needsPermission`, `running`, `degraded`

## Keep Awake

Holds a user-idle system sleep assertion indefinitely or for a selected
duration. Keeping the display awake is optional and off by default. Assertions
are released synchronously when stopped or when a timer expires.

- Code: `Sources/DropThingsModules/KeepAwake/`
- Permission: none
- Shortcut: none
- States: `off`, `running`, `degraded`

## Markdown Viewer

Opens any `.md` file and renders the full GitHub-Flavored Markdown
(tables, fenced code with syntax highlighting, task lists, images,
strikethrough, autolinks) in a live `WKWebView` preview powered by the
vendored `marked.js` (MIT) and `highlight.js` (BSD-3-Clause). The editor
is a plain `NSTextView`; the window supports split / editor-only /
preview-only layouts, drag-and-drop of `.md` files, and a recent-files
list. Files are opened via `NSOpenPanel` or drag-and-drop, so the core viewer
requires no TCC permission. The optional Finder-selection hotkey requests
Automation only when the user enables and invokes it.

- Code: `Sources/DropThingsModules/MarkdownViewer/`
- Permission: none
- Default shortcut: `⌥⌘M`
- States: `off`, `running`, `degraded`

## Retired experiments

Command Palette, Menu Bar Cleaner, Screenshot Region, Snippets, Text Tools, and
Window Snap are not registered, not visible, and excluded from the shipping
SwiftPM target. Their source remains temporarily in the repository only as
reference while follow-up cleanup decides whether to delete or redesign each
one independently.
